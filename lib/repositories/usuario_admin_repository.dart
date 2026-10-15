import '../core/network/api_client.dart';
import '../core/result.dart';
import '../models/usuario_admin.dart';
import '../services/supabase_service.dart';

class UsuariosAdminRepository {
  UsuariosAdminRepository({
    ApiClient? api,
    this.tokenResolver,
  })  : _api = api ?? ApiClient();
  final ApiClient _api;
  final String? Function()? tokenResolver;
  String? get _token {
    if (tokenResolver != null) return tokenResolver!();
    try {
      return SupabaseService.instance.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }
  Future<Result<PaginaUsuarios>> listar({
    String? rol,
    bool? activo,
    String? busqueda,
    int limite = 25,
    int desplazamiento = 0,
  }) => Result.guard(() async {
    try {
      final j = await _api.get(
        '/api/v1/admin/usuarios',
        token: _token,
        parametros: {
          if (rol != null && rol.isNotEmpty) 'rol': rol,
          if (activo != null) 'activo': activo.toString(),
          if (busqueda != null && busqueda.trim().isNotEmpty)
            'busqueda': busqueda.trim(),
          'limite': '$limite',
          'desplazamiento': '$desplazamiento',
        },
      );
      if (j.containsKey('usuarios') && j['usuarios'] is List) {
        return PaginaUsuarios.fromJson(j);
      }
    } catch (_) {
      // Si la API remota tarda en despertar o hay proxy en transición, consultamos Supabase directamente.
    }

    final client = SupabaseService.instance.client;
    var q = client.from('profiles').select();
    if (rol != null && rol.isNotEmpty) {
      q = q.eq('rol', rol);
    }
    if (activo != null) {
      q = q.eq('active', activo);
    }
    if (busqueda != null && busqueda.trim().isNotEmpty) {
      final b = busqueda.trim();
      q = q.or('email.ilike.%$b%,nombres.ilike.%$b%,apellidos.ilike.%$b%');
    }
    final todos = await q.order('created_at', ascending: false);
    final lista = todos as List<dynamic>;
    final total = lista.length;
    final sublista = lista.skip(desplazamiento).take(limite);

    final usuarios = sublista.map((f) {
      final m = f as Map<String, dynamic>;
      return UsuarioAdmin(
        id: m['id']?.toString() ?? '',
        email: m['email']?.toString() ?? '',
        cedula: m['cedula']?.toString(),
        nombres: m['nombres']?.toString() ?? '',
        apellidos: m['apellidos']?.toString() ?? '',
        rol: m['rol']?.toString() ?? 'estudiante',
        activo: m['active'] == true,
      );
    }).toList();

    return PaginaUsuarios(
      usuarios: usuarios,
      total: total,
      limite: limite,
      desplazamiento: desplazamiento,
    );
  });
  Future<Result<UsuarioAdmin>> cambiarRol({
    required String id,
    required String rol,
  }) => Result.guard(() async {
    final j = await _api.patch(
      '/api/v1/admin/usuarios/$id/rol',
      token: _token,
      cuerpo: {'rol': rol},
    );
    return UsuarioAdmin.fromJson(j['perfil'] as Map<String, dynamic>);
  });
}
