import 'dart:typed_data';

import '../core/gateways/planilla_gateway.dart';
import '../core/network/api_client.dart';
import '../models/inscripcion_campo.dart';
import 'supabase_service.dart';

/// Implementación de [PlanillaGateway] contra el backend Fastify.
///
/// Va por HTTP y **no** contra Supabase directo, que es la regla del proyecto:
/// el `23514` que nombra los campos que faltan lo produce un trigger y sólo el
/// backend lo puede convertir en un mensaje accionable. Además, el catálogo es
/// público, así que no tiene sentido atarlo a una sesión de Supabase.
class BackendPlanillaGateway implements PlanillaGateway {
  BackendPlanillaGateway({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Token de sesión, sólo para la escritura. La lectura del catálogo es pública
  /// y viaja **sin** `Authorization` a propósito: si el token caducó, el
  /// formulario de inscripción tiene que seguir pudiendo pintarse.
  String? get _tokenSesion =>
      SupabaseService.instance.auth.currentSession?.accessToken;

  @override
  Future<CatalogoInscripcion> campos() async {
    try {
      final respuesta = await _api.get('/api/v1/inscripcion/campos');
      final catalogo = CatalogoInscripcion.fromJson(respuesta);
      if (catalogo.campos.isNotEmpty) {
        return catalogo;
      }
    } catch (_) {
      // Si la API remota está en suspensión o el endpoint falla, recurrimos a Supabase directo.
    }

    try {
      final cliente = SupabaseService.instance.client;
      final filas = await cliente
          .from('inscripcion_campos')
          .select('codigo,etiqueta,grupo,tipo,obligatorio,orden,opciones,fuente,condicion,ayuda')
          .eq('activo', true)
          .order('orden', ascending: true)
          .order('codigo', ascending: true);

      if (filas.isNotEmpty) {
        return CatalogoInscripcion(
          filas.map(CampoInscripcion.fromJson).toList(),
        );
      }
    } catch (_) {
      // Si ambos fallan, devolvemos catálogo vacío sin romper la aplicación.
    }

    return const CatalogoInscripcion([]);
  }

  @override
  Future<PlanillaInscripcion> guardar(PlanillaInscripcion planilla) async {
    final respuesta = await _api.put(
      '/api/v1/yo/planilla',
      cuerpo: {'planilla': planilla},
      token: _tokenSesion,
    );

    final guardada = respuesta['planilla'];
    return guardada is Map<String, dynamic> ? guardada : <String, dynamic>{};
  }

  @override
  Future<Uint8List> descargarPdf() async {
    // El PDF viaja binario; por eso se usa [ApiClient.getBytes] y no [get]. El
    // token es el de la sesión activa, igual que en [guardar]: el backend saca
    // el usuario del JWT, no del cuerpo.
    return _api.getBytes(
      '/api/v1/yo/planilla/pdf',
      token: _tokenSesion,
    );
  }

  @override
  Future<Uint8List> descargarXlsx() async {
    return _api.getBytes(
      '/api/v1/yo/planilla/xlsx',
      token: _tokenSesion,
    );
  }
}
