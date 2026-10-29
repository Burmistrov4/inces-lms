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
          if (soloActivas) 'soloActivas': 'true',
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
    return Seccion.fromJson(respuesta);
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
    return Seccion.fromJson(respuesta);
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
    final crudo = respuesta['seccion'];
    final seccionJson = crudo is Map
        ? crudo.cast<String, dynamic>()
        : respuesta;

    // El catálogo cacheado ya no sabe de este grupo.
    cacheDeLecturas.invalidarPorPrefijo('secciones');

    return (
      seccion: Seccion.fromJson(seccionJson),
      creada: respuesta['creada'] as bool? ?? false,
    );
  }
}