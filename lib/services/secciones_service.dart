import '../core/errors/app_exception.dart';
import '../core/gateways/secciones_gateway.dart';
import '../core/cache_lecturas.dart';
import '../core/network/api_client.dart';
import '../models/seccion.dart';
import 'supabase_service.dart';

/// Implementación HTTP de [SeccionesGateway] contra el backend Fastify.
///
/// Comparte con `BackendInscripcionGateway` el patrón (URL prefijada por la
/// API, JWT de la sesión) pero **no** la responsabilidad: aquí se modela la
/// sección, no la inscripción. Reutiliza [SupabaseService] por la sesión.
/// Desenvuelve el sobre `{ seccion: {...} }` que devuelven las rutas de alta y
/// edición de grupos.
///
/// **Por qué existe.** `POST /admin/secciones` responde `201 { seccion }` y
/// `PATCH /admin/secciones/{id}` responde `{ seccion }`. Pasar ese sobre a
/// `Seccion.fromJson` hace que el modelo busque `id` en el sobre, no lo
/// encuentre y reviente con un cast: el grupo **se crea**, y la pantalla dice
/// «Ocurrió un error inesperado». Medido el 2026-10-31 en producción: `POST
/// /api/v1/admin/secciones` devolvió 201 y el diálogo mostró el error genérico.
///
/// Si el cuerpo no trae el sobre se devuelve tal cual: así la función sirve
/// también para un despliegue que responda el objeto plano.
Map<String, dynamic> desenvolverSeccion(Map<String, dynamic> respuesta) {
  final crudo = respuesta['seccion'];
  return crudo is Map ? crudo.cast<String, dynamic>() : respuesta;
}

class BackendSeccionesGateway implements SeccionesGateway {
  BackendSeccionesGateway({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  String? get _tokenSesion =>
      SupabaseService.instance.auth.currentSession?.accessToken;

  @override
  Future<PaginaSecciones> listarSecciones({
    bool soloActivas = false,
    int limite = 50,
    int desplazamiento = 0,
  }) async {
    // **Cache compartida.** Medido el 2026-10-23: esta ruta se pedia 30 veces
    // en una corrida, todas con la misma URL.
    final clave =
        'secciones:${[soloActivas, limite, desplazamiento].join('|')}';
    final respuesta = await cacheDeLecturas.leer<Map<String, dynamic>>(
      clave,
      ttl: const Duration(seconds: 45),
      fn: () => _api.get(
        '/api/v1/admin/secciones',
        token: _tokenSesion,
        parametros: {
          // **El nombre es `activa`, no `soloActivas`.** Medido el 2026-10-29:
          // `esquemaListadoSecciones` declara `activa: 'true' | 'false'`, y Zod
          // descarta en silencio las claves que no conoce, así que el filtro
          // viajaba con un nombre que nadie leía y el panel recibía también las
          // secciones archivadas. `activa=false` significa «sólo inactivas», de
          // modo que el filtro sólo se envía cuando se quiere.
          if (soloActivas) 'activa': 'true',
          'limite': '$limite',
          'desplazamiento': '$desplazamiento',
        },
      ),
    );
    return PaginaSecciones(
      secciones: ((respuesta['secciones'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(Seccion.fromJson)
          .toList(),
      total: (respuesta['total'] as int?) ?? 0,
      limite: (respuesta['limite'] as int?) ?? limite,
      desplazamiento: (respuesta['desplazamiento'] as int?) ?? desplazamiento,
    );
  }

  @override
  @override
  Future<String> matricular(String seccionId, String estudianteId) async {
    final respuesta = await _api.post(
      '/api/v1/admin/aulas/${Uri.encodeComponent(seccionId)}/matricular',
      cuerpo: {'estudianteId': estudianteId},
      token: _tokenSesion,
    );

    final estado = respuesta['estado'];
    if (estado is! String || estado.isEmpty) {
      throw const AppException.validacion(
        'El servidor no confirmó la matrícula. Vuelve a intentarlo.',
      );
    }
    return estado;
  }

  @override
  Future<String> darDeBaja(
    String seccionId,
    String estudianteId, {
    required String motivo,
  }) async {
    // El motivo va en la query y no en el cuerpo: un `DELETE` con cuerpo lo
    // pierden algunos clientes y proxies. `ApiClient.delete` no acepta
    // parámetros, así que la query se arma aquí.
    final consulta = Uri(queryParameters: {'motivo': motivo}).query;
    final respuesta = await _api.delete(
      '/api/v1/admin/aulas/${Uri.encodeComponent(seccionId)}'
      '/matricular/${Uri.encodeComponent(estudianteId)}?$consulta',
      token: _tokenSesion,
    );

    final estado = respuesta['estado'];
    if (estado is! String || estado.isEmpty) {
      throw const AppException.validacion(
        'El servidor no confirmó la baja. Vuelve a intentarlo.',
      );
    }
    return estado;
  }

  @override
  Future<Seccion> crearSeccion(Seccion borrador) async {
    final cuerpo = <String, dynamic>{
      'programaId': borrador.programaId,
      'materiaId': borrador.materiaId,
      'periodo': borrador.periodo,
      'nombre': borrador.nombre,
      if (borrador.cupoMaximo != null) 'cupoMaximo': borrador.cupoMaximo,
    };
    final respuesta = await _api.post(
      '/api/v1/admin/secciones',
      cuerpo: cuerpo,
      token: _tokenSesion,
    );
    // La lista cacheada ya no tiene la seccion nueva.
    cacheDeLecturas.invalidarPorPrefijo('secciones');
    return Seccion.fromJson(desenvolverSeccion(respuesta));
  }

  @override
  Future<Seccion> actualizarSeccion(String id, CambiosSeccion cambios) async {
    final cuerpo = cambios.toJson();
    if (cuerpo.isEmpty) {
      throw AppException.validacion(
        'Indica al menos un cambio (nombre, cupo o activa).',
      );
    }
    final respuesta = await _api.patch(
      '/api/v1/admin/secciones/$id',
      cuerpo: cuerpo,
      token: _tokenSesion,
    );
    return Seccion.fromJson(desenvolverSeccion(respuesta));
  }

  @override
  Future<({Seccion seccion, bool creada})> resolverGrupo({
    required String programaId,
    required String materiaId,
    required String periodo,
  }) async {
    final respuesta = await _api.post(
      '/api/v1/admin/grupos/resolver',
      cuerpo: {
        'programaId': programaId,
        'materiaId': materiaId,
        'periodo': periodo,
      },
      token: _tokenSesion,
    );

    // La respuesta viene envuelta: `{ seccion, creada }`. Se desenvuelve aquí
    // y no con `Seccion.fromJson(respuesta)` porque eso leería `id` del sobre y
    // reventaría con un cast: el grupo se creó y la pantalla diría «error».
    final seccionJson = desenvolverSeccion(respuesta);

    // El catálogo cacheado ya no sabe de este grupo.
    cacheDeLecturas.invalidarPorPrefijo('secciones');

    return (
      seccion: Seccion.fromJson(seccionJson),
      creada: respuesta['creada'] as bool? ?? false,
    );
  }
}