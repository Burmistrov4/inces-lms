import '../core/cache_lecturas.dart';
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
  }) {
    // **Cache compartida.** Medido el 2026-10-23: `/admin/usuarios?limite=25`
    // se pedia 31 veces en una corrida, todas con la misma URL.
    final clave =
        'usuarios:${[rol, activo, busqueda, limite, desplazamiento].join('|')}';
    return cacheDeLecturas.leer<Result<PaginaUsuarios>>(
      clave,
      ttl: const Duration(seconds: 45),
      fn: () => _listarSinCache(
        rol: rol,
        activo: activo,
        busqueda: busqueda,
        limite: limite,
        desplazamiento: desplazamiento,
      ),
    );
  }

  Future<Result<PaginaUsuarios>> _listarSinCache({
    String? rol,
    bool? activo,
    String? busqueda,
    int limite = 25,
    int desplazamiento = 0,
  }) => Result.guard(() async {
    // **Sin reserva a Supabase directo.** Medido el 2026-10-25: aquí había un
    // `catch (_) {}` vacío que, si la API fallaba, consultaba `profiles` por
    // debajo. Tres problemas, todos graves:
    //
    //   1. **Un fallo de red se vestía de «lista vacía».** El `catch` se tragaba
    //      el error y la consulta directa podía devolver cero filas —la RLS
    //      limita `profiles` al propio usuario salvo para el admin—, así que el
    //      administrador veía «no hay usuarios» cuando lo que había era un
    //      servidor caído. Un fallo que no se puede leer desde fuera es el peor
    //      bug de todos.
    //   2. **La paginación era mentira.** Hacía `skip`/`take` sobre *todos* los
    //      perfiles en el cliente: el total no era el total y cada página
    //      descargaba la tabla entera.
    //   3. **Era el único repositorio que se saltaba el backend.** Los demás
    //      hablan por un gateway (`archivos_repository`, `aspirante_repository`,
    //      `modulo_repository`, …). Éste llegó a importar `ApiClient` además,
    //      que es otra inconsistencia.
    //
    // El comentario decía «si la API remota tarda en despertar». Render free
    // tarda, pero **no falla**: devuelve lento. Y si algún día falla, el usuario
    // debe ver el error y reintentar, no una lista vacía que parece la verdad.
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
    return PaginaUsuarios.fromJson(j);
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

  Future<Result<UsuarioAdmin>> cambiarEstado({
    required String id,
    required bool activo,
  }) => Result.guard(() async {
    // Igual que en `_listarSinCache`: **sin reserva muda a Supabase**. Medido el
    // 2026-10-25. Aquí era todavía peor, porque es una **escritura**: si la API
    // fallaba, el `catch` vacío probaba el `update` directo y, si la RLS lo
    // rechazaba, el error llegaba tarde y sin contexto. Activar o desactivar una
    // cuenta es la operación más delicada del panel; no puede tener un camino
    // oculto. Un solo camino, el del backend, que es el que audita.
    final j = await _api.patch(
      '/api/v1/admin/usuarios/$id/estado',
      token: _token,
      cuerpo: {'activo': activo},
    );
    return UsuarioAdmin.fromJson(j['perfil'] as Map<String, dynamic>);
  });
}
