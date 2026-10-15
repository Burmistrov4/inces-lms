import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';

/// Cliente HTTP del backend stateless (Fastify).
///
/// El frontend Flutter habla directo con Supabase para lo del día a día, pero las
/// operaciones que exigen privilegios de servicio —crear un docente por
/// invitación, promover roles— pasan por este backend, que sí tiene la llave
/// `service_role`. La app sólo manda el JWT de sesión del usuario; el backend
/// valida el rol admin.
///
/// Incluye políticas de resiliencia frente a cold starts de Render:
///  - Timeout explícito de 22 segundos para evitar bloqueos indefinidos del navegador.
///  - Reintento transparente en lecturas GET ante reinicios o cortes transitorios.
///  - Función de calentamiento en segundo plano ([calentarBackend]).
///  - Manejo seguro de respuestas 502/503/504 en formato HTML para no romper el parser JSON.
class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
      : _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _http;
  final String _baseUrl;

  /// Tiempo de espera límite por petición antes de disparar excepción de red.
  static const Duration tiempoEsperaDefault = Duration(seconds: 22);

  static bool _calentando = false;

  /// Dispara una consulta de salud (`GET /salud`) en segundo plano para despertar
  /// el contenedor en Render si se encontraba suspendido por inactividad.
  static Future<void> calentarBackend([String? baseUrl]) async {
    if (_calentando) return;
    _calentando = true;
    try {
      final base = (baseUrl ?? AppConfig.apiBaseUrl).trim();
      if (base.isEmpty) return;
      final uri = Uri.parse('$base/salud');
      final cliente = http.Client();
      await cliente.get(uri).timeout(const Duration(seconds: 15));
      cliente.close();
    } catch (_) {
      // El calentamiento es silencioso; nunca interrumpe el flujo del usuario.
    } finally {
      _calentando = false;
    }
  }

  Future<Map<String, dynamic>> post(
    String ruta, {
    Map<String, dynamic>? cuerpo,
    String? token,
    Map<String, String>? encabezadosExtra,
    Duration tiempoEspera = tiempoEsperaDefault,
  }) async {
    try {
      final respuesta = await _http
          .post(
            _resolver(ruta),
            headers: {
              if (cuerpo != null) 'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
              ...?encabezadosExtra,
            },
            body: cuerpo == null ? null : jsonEncode(cuerpo),
          )
          .timeout(tiempoEspera);

      return _procesar(respuesta, ruta);
    } on TimeoutException {
      throw const AppException(
        type: AppErrorType.red,
        message:
            'El servidor está tardando más de lo habitual en responder (puede '
            'estar iniciando). Por favor intenta de nuevo en unos segundos.',
      );
    }
  }

  /// Actualización parcial (PATCH) de un recurso.
  Future<Map<String, dynamic>> patch(
    String ruta, {
    Map<String, dynamic>? cuerpo,
    String? token,
    Map<String, String>? encabezadosExtra,
    Duration tiempoEspera = tiempoEsperaDefault,
  }) async {
    try {
      final respuesta = await _http
          .patch(
            _resolver(ruta),
            headers: {
              if (cuerpo != null) 'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
              ...?encabezadosExtra,
            },
            body: cuerpo == null ? null : jsonEncode(cuerpo),
          )
          .timeout(tiempoEspera);

      return _procesar(respuesta, ruta);
    } on TimeoutException {
      throw const AppException(
        type: AppErrorType.red,
        message:
            'El servidor está tardando más de lo habitual en responder (puede '
            'estar iniciando). Por favor intenta de nuevo en unos segundos.',
      );
    }
  }

  /// Reemplazo (PUT) de un recurso o de una de sus facetas.
  Future<Map<String, dynamic>> put(
    String ruta, {
    Map<String, dynamic>? cuerpo,
    String? token,
    Map<String, String>? encabezadosExtra,
    Duration tiempoEspera = tiempoEsperaDefault,
  }) async {
    try {
      final respuesta = await _http
          .put(
            _resolver(ruta),
            headers: {
              if (cuerpo != null) 'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
              ...?encabezadosExtra,
            },
            body: cuerpo == null ? null : jsonEncode(cuerpo),
          )
          .timeout(tiempoEspera);

      return _procesar(respuesta, ruta);
    } on TimeoutException {
      throw const AppException(
        type: AppErrorType.red,
        message:
            'El servidor está tardando más de lo habitual en responder (puede '
            'estar iniciando). Por favor intenta de nuevo en unos segundos.',
      );
    }
  }

  /// Lectura (GET) con reintento automático opcional ante arranque en frío.
  Future<Map<String, dynamic>> get(
    String ruta, {
    String? token,
    Map<String, String>? parametros,
    Map<String, String>? encabezadosExtra,
    Duration tiempoEspera = tiempoEsperaDefault,
    bool permitirReintento = true,
  }) async {
    Future<http.Response> ejecutarPeticion() {
      return _http
          .get(
            _resolver(ruta, parametros),
            headers: {
              if (token != null) 'Authorization': 'Bearer $token',
              ...?encabezadosExtra,
            },
          )
          .timeout(tiempoEspera);
    }

    try {
      final respuesta = await ejecutarPeticion();
      return _procesar(respuesta, ruta);
    } on TimeoutException {
      throw const AppException(
        type: AppErrorType.red,
        message:
            'El servidor está tardando más de lo habitual en responder (puede '
            'estar iniciando). Por favor intenta de nuevo en unos segundos.',
      );
    } catch (e) {
      // Si la primera petición falló por reset de conexión de Render en cold start,
      // reintentar una sola vez con pequeña pausa antes de dar error.
      if (permitirReintento) {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        return get(
          ruta,
          token: token,
          parametros: parametros,
          encabezadosExtra: encabezadosExtra,
          tiempoEspera: tiempoEspera,
          permitirReintento: false,
        );
      }
      rethrow;
    }
  }

  /// Lectura binaria (GET) que devuelve los bytes en crudo.
  Future<Uint8List> getBytes(
    String ruta, {
    String? token,
    Map<String, String>? parametros,
    Map<String, String>? encabezadosExtra,
    Duration tiempoEspera = tiempoEsperaDefault,
  }) async {
    http.Response respuesta;
    try {
      respuesta = await _http
          .get(
            _resolver(ruta, parametros),
            headers: {
              if (token != null) 'Authorization': 'Bearer $token',
              ...?encabezadosExtra,
            },
          )
          .timeout(tiempoEspera);
    } on TimeoutException {
      throw const AppException(
        type: AppErrorType.red,
        message:
            'La descarga está tardando más de lo habitual. Por favor reintenta en unos instantes.',
      );
    }

    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
      return respuesta.bodyBytes;
    }

    String mensaje = 'Ocurrió un error inesperado. Inténtalo de nuevo.';
    String? codigo;
    final texto = respuesta.body.trim();
    if (texto.isNotEmpty && texto.startsWith('{')) {
      try {
        final cuerpo = jsonDecode(texto);
        if (cuerpo is Map<String, dynamic>) {
          final error = cuerpo['error'];
          if (error is Map<String, dynamic>) {
            mensaje = (error['mensaje'] as String?) ?? mensaje;
            codigo = error['codigo'] as String?;
          }
        }
      } catch (_) {}
    } else if (respuesta.statusCode >= 500) {
      mensaje =
          'El servidor del INCES se encuentra iniciando o temporalmente ocupado (HTTP ${respuesta.statusCode}).';
    }

    throw AppException(
      type: _clasificar(respuesta.statusCode, codigo),
      message: mensaje,
      code: codigo,
      technical: 'HTTP ${respuesta.statusCode} en $ruta',
    );
  }

  /// Borrado (DELETE) de un recurso.
  Future<Map<String, dynamic>> delete(
    String ruta, {
    String? token,
    Map<String, String>? encabezadosExtra,
    Duration tiempoEspera = tiempoEsperaDefault,
  }) async {
    try {
      final respuesta = await _http
          .delete(
            _resolver(ruta),
            headers: {
              if (token != null) 'Authorization': 'Bearer $token',
              ...?encabezadosExtra,
            },
          )
          .timeout(tiempoEspera);

      return _procesar(respuesta, ruta);
    } on TimeoutException {
      throw const AppException(
        type: AppErrorType.red,
        message:
            'El servidor está tardando más de lo habitual en responder. Por favor intenta de nuevo.',
      );
    }
  }

  /// Construye la URL completa y comprueba que hay base configurada.
  Uri _resolver(String ruta, [Map<String, String>? parametros]) {
    final base = _baseUrl.trim();
    if (base.isEmpty) {
      throw const AppException(
        type: AppErrorType.servidor,
        message:
            'Falta la configuración del servidor (API_BASE_URL). No se puede '
            'contactar al backend.',
      );
    }

    final limpios = <String, String>{
      for (final entrada in (parametros ?? const <String, String>{}).entries)
        if (entrada.value.trim().isNotEmpty) entrada.key: entrada.value.trim(),
    };

    return Uri.parse('$base$ruta').replace(
      queryParameters: limpios.isEmpty ? null : limpios,
    );
  }

  Map<String, dynamic> _procesar(http.Response respuesta, String ruta) {
    final texto = respuesta.body.trim();
    Map<String, dynamic> cuerpo = <String, dynamic>{};

    final contentType = respuesta.headers['content-type'] ?? '';
    final esHtml = contentType.contains('text/html') ||
        texto.startsWith('<!DOCTYPE') ||
        texto.startsWith('<html');

    if (esHtml) {
      throw AppException(
        type: AppErrorType.servidor,
        message:
            'El servidor respondió con contenido HTML en lugar de datos JSON en $ruta.',
        technical: 'Respuesta HTML en $ruta (HTTP ${respuesta.statusCode})',
      );
    }

    if (texto.isNotEmpty && texto.startsWith('{')) {
      try {
        final decodificado = jsonDecode(texto);
        if (decodificado is Map<String, dynamic>) {
          cuerpo = decodificado;
        }
      } catch (_) {
        cuerpo = <String, dynamic>{};
      }
    }

    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
      return cuerpo;
    }

    final error = cuerpo['error'] as Map<String, dynamic>?;
    final mensajeServidor = error?['mensaje'] as String?;
    final codigo = error?['codigo'] as String?;

    // Tratamiento especial de errores de Gateway o contenedores despertando (502, 503, 504)
    // cuando el backend no respondió con su propio JSON estructurado.
    if ((respuesta.statusCode == 502 ||
            respuesta.statusCode == 503 ||
            respuesta.statusCode == 504) &&
        (mensajeServidor == null || mensajeServidor.trim().isEmpty)) {
      throw AppException(
        type: AppErrorType.servidor,
        message:
            'El servidor del INCES está iniciando sus servicios en la nube. '
            'Por favor reintenta en unos instantes.',
        code: 'SERVIDOR_INICIANDO',
        technical: 'HTTP ${respuesta.statusCode} en $ruta',
      );
    }

    final mensaje = mensajeServidor ??
        (respuesta.statusCode >= 500
            ? 'Ocurrió un inconveniente temporal en el servidor. Inténtalo de nuevo.'
            : 'Ocurrió un error inesperado. Inténtalo de nuevo.');

    throw AppException(
      type: _clasificar(respuesta.statusCode, codigo),
      message: mensaje,
      code: codigo,
      technical: 'HTTP ${respuesta.statusCode} en $ruta',
    );
  }

  AppErrorType _clasificar(int status, String? codigo) {
    if (codigo == 'ESQUEMA_DESACTUALIZADO') {
      return AppErrorType.esquemaDesactualizado;
    }

    switch (status) {
      case 400:
      case 409:
      case 410:
      case 413:
      case 422:
        return AppErrorType.validacion;
      case 401:
      case 403:
        return AppErrorType.permisos;
      default:
        return AppErrorType.servidor;
    }
  }
}
