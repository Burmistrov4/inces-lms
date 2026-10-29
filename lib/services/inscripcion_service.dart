import '../core/errors/app_exception.dart';
import '../core/gateways/inscripcion_gateway.dart';
import '../core/cache_lecturas.dart';
import '../core/network/api_client.dart';
import '../models/inscripcion.dart';
import '../models/resumen_curso.dart';
import 'supabase_service.dart';

/// Implementación de [InscripcionGateway] contra el backend Fastify.
///
/// Las rutas de admin exigen el JWT de sesión del usuario (para que el backend
/// valide rol admin). Las de estudiante también lo usan para identificarlo.
class BackendInscripcionGateway implements InscripcionGateway {
  BackendInscripcionGateway({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Token de sesión del usuario actual, para autenticar la ruta.
  String? get _tokenSesion =>
      SupabaseService.instance.auth.currentSession?.accessToken;

  @override
  Future<List<OcupacionSeccion>> obtenerOfertas({bool soloConCupo = false}) async {
    // **Cache compartida.** Se invalida tras inscribirse, renunciar o aceptar.
    final clave = 'ofertas:${soloConCupo ? 'cupo' : 'todas'}';
    final respuesta = await cacheDeLecturas.leer<Map<String, dynamic>>(
      clave,
      ttl: const Duration(seconds: 45),
      fn: () => _api.get(
        '/api/v1/ofertas',
        token: _tokenSesion,
        parametros: soloConCupo ? {'soloConCupo': 'true'} : null,
      ),
    );
    final secciones =
        (respuesta['secciones'] as List?)?.cast<Map<String, dynamic>>();
    return secciones?.map(OcupacionSeccion.fromJson).toList() ?? const [];
  }

  @override
  Future<List<InscripcionDetallada>> obtenerMisInscripciones() async {
    // **Cache compartida.** Se invalida tras inscribirse, renunciar o aceptar:
    // si no, el estudiante veria «no inscrito» justo despues de inscribirse.
    final respuesta = await cacheDeLecturas.leer<Map<String, dynamic>>(
      'mis-inscripciones',
      ttl: const Duration(seconds: 45),
      fn: () => _api.get('/api/v1/mis-inscripciones', token: _tokenSesion),
    );
    final inscripciones =
        (respuesta['inscripciones'] as List?)?.cast<Map<String, dynamic>>();
    return inscripciones?.map(InscripcionDetallada.fromJson).toList() ??
        const [];
  }

  /// Lo que una escritura de inscripciones deja obsoleto.
  ///
  /// Cachear lecturas sólo sirve si lo que se escribe invalida lo que se lee:
  /// sin esto, el estudiante vería «no inscrito» durante los 45 s del TTL
  /// justo después de inscribirse.
  void _invalidarInscripciones() {
    cacheDeLecturas.invalidarPorPrefijo('ofertas');
    cacheDeLecturas.invalidarPorPrefijo('mis-inscripciones');
    cacheDeLecturas.invalidarPorPrefijo('ocupacion');
    cacheDeLecturas.invalidarPorPrefijo('resumen-cursos');
  }

  @override
  Future<EstadoInscripcion> inscribirse(String seccionId) async {
    final respuesta = await _api.post(
      '/api/v1/inscripciones',
      cuerpo: {'seccionId': seccionId},
      token: _tokenSesion,
    );
    _invalidarInscripciones();
    return EstadoInscripcion.desde(respuesta['estado'] as String?);
  }

  @override
  Future<EstadoInscripcion> renunciar(String seccionId) async {
    // POST sin cuerpo: la sección viaja en la ruta. El cliente NO debe mandar
    // `Content-Type: application/json` (trampa FST_ERR_CTP_EMPTY_JSON_BODY).
    final respuesta = await _api.post(
      '/api/v1/inscripciones/$seccionId/renunciar',
      token: _tokenSesion,
    );
    _invalidarInscripciones();
    return EstadoInscripcion.desde(respuesta['estado'] as String?);
  }

  @override
  Future<EstadoInscripcion> aceptarOferta(String seccionId) async {
    final respuesta = await _api.post(
      '/api/v1/inscripciones/$seccionId/aceptar',
      token: _tokenSesion,
    );
    _invalidarInscripciones();
    return EstadoInscripcion.desde(respuesta['estado'] as String?);
  }

  @override
  Future<List<OcupacionSeccion>> obtenerOcupacion({bool soloConCupo = false}) async {
    // **Cache compartida.** Medido el 2026-10-23: 37 peticiones en una corrida.
    // Se invalida tras cada escritura de cupos (ver [promoverSiguiente]).
    final clave = 'ocupacion:${soloConCupo ? 'cupo' : 'todas'}';
    final respuesta = await cacheDeLecturas.leer<Map<String, dynamic>>(
      clave,
      ttl: const Duration(seconds: 45),
      fn: () => _api.get(
        '/api/v1/admin/ocupacion',
        token: _tokenSesion,
        parametros: soloConCupo ? {'soloConCupo': 'true'} : null,
      ),
    );
    final secciones =
        (respuesta['secciones'] as List?)?.cast<Map<String, dynamic>>();
    return secciones?.map(OcupacionSeccion.fromJson).toList() ?? const [];
  }

  @override
  Future<InscripcionDetallada> promoverSiguiente(String seccionId) async {
    // POST sin cuerpo. Devuelve `{ promovida, mensaje }`; `promovida: null`
    // significa «no había nadie a quien promover» (cola vacía, llena o con
    // oferta viva), que es un caso normal y no un error.
    final respuesta = await _api.post(
      '/api/v1/admin/secciones/$seccionId/promover',
      token: _tokenSesion,
    );
    final promovida = respuesta['promovida'] as Map<String, dynamic>?;
    if (promovida == null) {
      throw AppException.validacion(
        'No se promovió a nadie: la cola está vacía, la sección está llena '
        'o ya hay una oferta de cupo en el aire.',
      );
    }
    _invalidarInscripciones();
    return InscripcionDetallada.fromJson(promovida);
  }

  @override
  Future<int> expirarOfertas() async {
    final respuesta = await _api.post(
      '/api/v1/admin/inscripciones/expirar',
      token: _tokenSesion,
    );
    return (respuesta['vencidas'] as int?) ?? 0;
  }

  @override
  Future<List<InscripcionDetallada>> obtenerCola(String seccionId) async {
    final respuesta = await _api.get(
      '/api/v1/admin/secciones/$seccionId/cola',
      token: _tokenSesion,
    );
    return ((respuesta['cola'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(InscripcionDetallada.fromJson)
        .toList();
  }

  @override
  Future<List<InscripcionDetallada>> obtenerInscripcionesDeSeccion(
      String seccionId) async {
    final respuesta = await _api.get(
      '/api/v1/admin/secciones/$seccionId/inscripciones',
      token: _tokenSesion,
    );
    return ((respuesta['inscripciones'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(InscripcionDetallada.fromJson)
        .toList();
  }

  @override
  Future<EstadoInscripcion> reincorporar({
    required String estudianteId,
    required String seccionId,
  }) async {
    final respuesta = await _api.post(
      '/api/v1/admin/inscripciones/reincorporar',
      cuerpo: {'estudianteId': estudianteId, 'seccionId': seccionId},
      token: _tokenSesion,
    );
    return EstadoInscripcion.desde(respuesta['estado'] as String?);
  }

  @override
  Future<List<ResumenCurso>> obtenerResumenCursos() async {
    // **Cache compartida.** Misma táctica que [obtenerOcupacion]: el resumen por
    // programa agrega cupos/ocupados y la ventana de inscripción, y se invalida
    // tras cada escritura de cupos (ver [promoverSiguiente] / [reincorporar]).
    final respuesta = await cacheDeLecturas.leer<Map<String, dynamic>>(
      'resumen-cursos',
      ttl: const Duration(seconds: 45),
      fn: () => _api.get(
        '/api/v1/admin/cursos/resumen',
        token: _tokenSesion,
      ),
    );
    final cursos =
        (respuesta['cursos'] as List?)?.cast<Map<String, dynamic>>();
    return cursos?.map(ResumenCurso.fromJson).toList() ?? const [];
  }
}
