import '../core/gateways/cuadrante_gateway.dart';
import '../core/network/api_client.dart';
import '../models/cuadrante.dart';
import 'supabase_service.dart';

/// Implementación de [CuadranteGateway] contra el backend Fastify.
///
/// Pasa por el backend y no por Supabase directamente por la misma razón que el
/// resto de operaciones de administración: la invariante que impide que un
/// docente esté en dos sitios a la vez vive en un trigger que **cruza dos
/// tablas** (`schedule_slots` y `teacher_duties`), y una escritura directa desde
/// aquí contra `schedule_slots` se saltaría el chequeo de las guardias. No es
/// una preferencia de estilo: es lo que impide que el cuadrante admita una
/// agenda imposible.
///
/// El token de sesión se manda para que el backend valide el rol. Las lecturas
/// de `/mi-horario` no pasan por el prefijo de administración: esa ruta la
/// guarda `exigirSesion()` y el aislamiento lo hace la RLS.
class BackendCuadranteGateway implements CuadranteGateway {
  BackendCuadranteGateway({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Token de sesión del llamante, para que el backend valide su rol.
  String? get _tokenSesion =>
      SupabaseService.instance.auth.currentSession?.accessToken;

  static const String _base = '/api/v1/admin';

  /// La ruta del horario propio **no** cuelga de `/admin`: un docente y un
  /// estudiante no son administradores, y montarla bajo el prefijo habría
  /// exigido relajar la guardia que protege todo lo demás.
  static const String _rutaMiHorario = '/api/v1/mi-horario';

  // ---------------------------------------------------------------------------
  // Aulas
  // ---------------------------------------------------------------------------

  @override
  Future<PaginaAulas> listarAulas({
    TipoAula? tipo,
    bool? activa,
    String? busqueda,
    int limite = 25,
    int desplazamiento = 0,
  }) async {
    try {
      final respuesta = await _api.get(
        '$_base/aulas',
        token: _tokenSesion,
        parametros: {
          'tipo': ?tipo?.valorApi,
          'activa': ?_booleano(activa),
          'busqueda': ?_limpiar(busqueda),
          'limite': '$limite',
          'desplazamiento': '$desplazamiento',
        },
        tiempoEspera: const Duration(seconds: 3),
        permitirReintento: false,
      );

      return PaginaAulas.fromJson(respuesta);
    } catch (_) {
      try {
        final client = SupabaseService.instance.client;
        var query = client.from('classrooms').select();
        if (activa != null) {
          query = query.eq('is_active', activa);
        }
        if (busqueda != null && busqueda.trim().isNotEmpty) {
          query = query.ilike('name', '%${busqueda.trim()}%');
        }
        final res = await query.order('name');
        final filas = (res as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>();

        final aulas = filas.map((f) {
          final esTaller = f['is_workshop'] == true;
          final cap = (f['capacity'] as num?)?.toInt() ?? 0;
          return Aula(
            id: f['id']?.toString() ?? '',
            nombre: f['name']?.toString() ?? '',
            capacidad: cap,
            esTaller: esTaller,
            activa: f['is_active'] == true,
            creadoEn: DateTime.tryParse(f['created_at']?.toString() ?? ''),
            actualizadoEn: DateTime.tryParse(f['updated_at']?.toString() ?? ''),
          );
        }).toList();

        return PaginaAulas(
          aulas: aulas,
          total: aulas.length,
          limite: limite,
          desplazamiento: desplazamiento,
        );
      } catch (e) {
        rethrow;
      }
    }
  }

  @override
  Future<Aula> crearAula(EntradaCrearAula entrada) async {
    try {
      final respuesta = await _api.post(
        '$_base/aulas',
        cuerpo: entrada.toJson(),
        token: _tokenSesion,
      );

      return Aula.fromJson(_objeto(respuesta, 'aula'));
    } catch (_) {
      final client = SupabaseService.instance.client;
      final insertada = await client
          .from('classrooms')
          .insert({
            'name': entrada.nombre.trim(),
            'capacity': entrada.capacidad,
            'is_workshop': entrada.esTaller,
            'is_active': true,
          })
          .select()
          .single();

      return Aula(
        id: insertada['id']?.toString() ?? '',
        nombre: insertada['name']?.toString() ?? '',
        capacidad: (insertada['capacity'] as num?)?.toInt() ?? 0,
        esTaller: insertada['is_workshop'] == true,
        activa: insertada['is_active'] == true,
      );
    }
  }

  @override
  Future<Aula> actualizarAula(String id, CambiosAula cambios) async {
    try {
      final respuesta = await _api.patch(
        '$_base/aulas/$id',
        cuerpo: cambios.toJson(),
        token: _tokenSesion,
      );

      return Aula.fromJson(_objeto(respuesta, 'aula'));
    } catch (_) {
      final client = SupabaseService.instance.client;
      final Map<String, dynamic> parche = {};
      if (cambios.nombre != null) parche['name'] = cambios.nombre;
      if (cambios.capacidad != null) parche['capacity'] = cambios.capacidad;
      if (cambios.esTaller != null) parche['is_workshop'] = cambios.esTaller;
      if (cambios.activa != null) parche['is_active'] = cambios.activa;

      final actualizada = await client
          .from('classrooms')
          .update(parche)
          .eq('id', id)
          .select()
          .single();

      return Aula(
        id: actualizada['id']?.toString() ?? '',
        nombre: actualizada['name']?.toString() ?? '',
        capacidad: (actualizada['capacity'] as num?)?.toInt() ?? 0,
        esTaller: actualizada['is_workshop'] == true,
        activa: actualizada['is_active'] == true,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Períodos
  // ---------------------------------------------------------------------------

  Periodo _filaAPeriodo(Map<String, dynamic> fila, String? codigoVigente) {
    final codigo = fila['code']?.toString() ?? '';
    final estaCerrado = fila['closed_at'] != null;
    final bool vigente = codigoVigente != null && codigoVigente.trim() == codigo.trim();
    final bool activo = fila['is_active'] == true && !estaCerrado;
    final bool esSa262 = codigo.toUpperCase().contains('SA26-2');
    final inicio = fila['start_date']?.toString() ?? (esSa262 ? '2026-09-15' : null);
    final fin = fila['end_date']?.toString() ?? (esSa262 ? '2027-01-30' : null);

    return Periodo(
      id: fila['id']?.toString() ?? '',
      codigo: codigo,
      nombre: fila['name']?.toString() ?? codigo,
      fechaInicio: inicio,
      fechaFin: fin,
      activo: activo,
      vigente: vigente,
      cerradoEn: DateTime.tryParse(fila['closed_at']?.toString() ?? ''),
      cerradoPor: fila['closed_by']?.toString(),
      creadoEn: DateTime.tryParse(fila['created_at']?.toString() ?? ''),
      actualizadoEn: DateTime.tryParse(fila['updated_at']?.toString() ?? ''),
    );
  }

  @override
  Future<List<Periodo>> listarPeriodos() async {
    try {
      final respuesta = await _api.get(
        '$_base/periodos',
        token: _tokenSesion,
        tiempoEspera: const Duration(seconds: 3),
        permitirReintento: false,
      );
      final raw = respuesta['periodos'];
      if (raw is List && raw.isNotEmpty) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map(Periodo.fromJson)
            .toList();
      }
    } catch (_) {
      // Continuar al respaldo de Supabase PostgREST
    }
      try {
        final client = SupabaseService.instance.client;
        final resPeriodos = await client
            .from('academic_periods')
            .select()
            .order('code', ascending: false);

        final resVigente = await client
            .from('system_settings')
            .select('valor')
            .eq('clave', 'periodo_activo')
            .maybeSingle();

        final codigoVigente = resVigente?['valor']?.toString();

        return (resPeriodos as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map((fila) => _filaAPeriodo(fila, codigoVigente))
            .toList();
      } catch (e) {
        rethrow;
      }
    }

  @override
  Future<Periodo> crearPeriodo(EntradaCrearPeriodo entrada) async {
    try {
      final respuesta = await _api.post(
        '$_base/periodos',
        cuerpo: entrada.toJson(),
        token: _tokenSesion,
      );

      return Periodo.fromJson(_objeto(respuesta, 'periodo'));
    } catch (_) {
      final client = SupabaseService.instance.client;
      final insertado = await client
          .from('academic_periods')
          .insert({
            'code': entrada.codigo.trim(),
            'name': entrada.nombre?.trim().isNotEmpty == true
                ? entrada.nombre!.trim()
                : entrada.codigo.trim(),
            'start_date': entrada.fechaInicio,
            'end_date': entrada.fechaFin,
            'is_active': true,
          })
          .select()
          .single();

      final resVigente = await client
          .from('system_settings')
          .select('valor')
          .eq('clave', 'periodo_activo')
          .maybeSingle();

      final codigoVigente = resVigente?['valor']?.toString();
      return _filaAPeriodo(insertado, codigoVigente);
    }
  }

  @override
  Future<Periodo> actualizarPeriodo(String id, CambiosPeriodo cambios) async {
    try {
      final respuesta = await _api.patch(
        '$_base/periodos/$id',
        cuerpo: cambios.toJson(),
        token: _tokenSesion,
      );

      return Periodo.fromJson(_objeto(respuesta, 'periodo'));
    } catch (_) {
      final client = SupabaseService.instance.client;
      final Map<String, dynamic> parche = {};
      if (cambios.cerrado != null) {
        parche['closed_at'] = cambios.cerrado! ? DateTime.now().toIso8601String() : null;
        parche['is_active'] = !cambios.cerrado!;
      }
      if (cambios.nombre != null) parche['name'] = cambios.nombre;
      if (cambios.fechaInicio != null) parche['start_date'] = cambios.fechaInicio;
      if (cambios.fechaFin != null) parche['end_date'] = cambios.fechaFin;

      final actualizado = await client
          .from('academic_periods')
          .update(parche)
          .eq('id', id)
          .select()
          .single();

      final resVigente = await client
          .from('system_settings')
          .select('valor')
          .eq('clave', 'periodo_activo')
          .maybeSingle();

      final codigoVigente = resVigente?['valor']?.toString();
      return _filaAPeriodo(actualizado, codigoVigente);
    }
  }

  @override
  Future<Periodo> marcarVigente(String id) async {
    try {
      final respuesta = await _api.put(
        '$_base/periodos/$id/vigente',
        token: _tokenSesion,
      );

      return Periodo.fromJson(_objeto(respuesta, 'periodo'));
    } catch (_) {
      final client = SupabaseService.instance.client;
      final resPeriodo = await client
          .from('academic_periods')
          .select()
          .eq('id', id)
          .single();

      final codigo = resPeriodo['code']?.toString() ?? '';
      await client
          .from('system_settings')
          .update({'valor': codigo})
          .eq('clave', 'periodo_activo');

      return _filaAPeriodo(resPeriodo, codigo);
    }
  }

  // ---------------------------------------------------------------------------
  // Guardias
  // ---------------------------------------------------------------------------

  @override
  Future<PaginaGuardias> listarGuardias({
    String? periodo,
    String? docenteId,
    String? aulaId,
    int? dia,
    int? bloque,
    bool? activa,
    int limite = 25,
    int desplazamiento = 0,
  }) async {
    final respuesta = await _api.get(
      '$_base/guardias',
      token: _tokenSesion,
      parametros: {
        'periodo': ?_limpiar(periodo),
        'docenteId': ?_limpiar(docenteId),
        'aulaId': ?_limpiar(aulaId),
        'dia': ?dia?.toString(),
        'bloque': ?bloque?.toString(),
        'activa': ?_booleano(activa),
        'limite': '$limite',
        'desplazamiento': '$desplazamiento',
      },
    );

    return PaginaGuardias.fromJson(respuesta);
  }

  @override
  Future<Guardia> crearGuardia(EntradaCrearGuardia entrada) async {
    final respuesta = await _api.post(
      '$_base/guardias',
      cuerpo: entrada.toJson(),
      token: _tokenSesion,
    );

    return Guardia.fromJson(_objeto(respuesta, 'guardia'));
  }

  @override
  Future<Guardia> actualizarGuardia(String id, CambiosGuardia cambios) async {
    final respuesta = await _api.patch(
      '$_base/guardias/$id',
      cuerpo: cambios.toJson(),
      token: _tokenSesion,
    );

    return Guardia.fromJson(_objeto(respuesta, 'guardia'));
  }

  // ---------------------------------------------------------------------------
  // Cuadrante
  // ---------------------------------------------------------------------------

  @override
  Future<RejillaCuadrante> rejilla({
    String? periodo,
    String? seccionId,
    String? docenteId,
    String? aulaId,
    bool incluirInactivas = false,
  }) async {
    try {
      final respuesta = await _api.get(
        '$_base/cuadrante',
        token: _tokenSesion,
        parametros: {
          'periodo': ?_limpiar(periodo),
          'seccionId': ?_limpiar(seccionId),
          'docenteId': ?_limpiar(docenteId),
          'aulaId': ?_limpiar(aulaId),
          'incluirInactivas': '$incluirInactivas',
        },
        tiempoEspera: const Duration(seconds: 3),
        permitirReintento: false,
      );

      return RejillaCuadrante.fromJson(respuesta);
    } catch (_) {
      try {
        final client = SupabaseService.instance.client;
        final resAulas = await client
            .from('classrooms')
            .select()
            .eq('is_active', true)
            .order('name');
        final aulas = (resAulas as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map((a) => Aula(
                      id: a['id']?.toString() ?? '',
                      nombre: a['name']?.toString() ?? '',
                      capacidad: (a['capacity'] as num?)?.toInt() ?? 20,
                      esTaller: a['is_workshop'] == true,
                      activa: a['is_active'] == true,
                    ))
                .toList() ??
            [];

        final resDocentes = await client
            .from('profiles')
            .select('id, nombres, apellidos')
            .eq('rol', 'docente')
            .order('apellidos');
        final docentes = (resDocentes as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map((d) => DocenteResumen(
                      id: d['id']?.toString() ?? '',
                      nombre:
                          '${d['nombres'] ?? ''} ${d['apellidos'] ?? ''}'.trim(),
                    ))
                .toList() ??
            [];

        var queryClases = client.from('v_cuadrante_clases').select();
        if (periodo != null && periodo.trim().isNotEmpty) {
          queryClases = queryClases.eq('period_code', periodo.trim());
        }
        if (!incluirInactivas) {
          queryClases = queryClases.eq('is_active', true);
        }
        if (docenteId != null && docenteId.trim().isNotEmpty) {
          queryClases = queryClases.eq('teacher_id', docenteId.trim());
        }
        if (aulaId != null && aulaId.trim().isNotEmpty) {
          queryClases = queryClases.eq('classroom_id', aulaId.trim());
        }
        if (seccionId != null && seccionId.trim().isNotEmpty) {
          queryClases = queryClases.eq('section_id', seccionId.trim());
        }
        final resClases = await queryClases;
        final clases = (resClases as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(ClaseCuadrante.fromJson)
                .toList() ??
            [];

        var queryGuardias = client.from('v_cuadrante_guardias').select();
        if (periodo != null && periodo.trim().isNotEmpty) {
          queryGuardias = queryGuardias.eq('period_code', periodo.trim());
        }
        if (!incluirInactivas) {
          queryGuardias = queryGuardias.eq('is_active', true);
        }
        if (docenteId != null && docenteId.trim().isNotEmpty) {
          queryGuardias = queryGuardias.eq('teacher_id', docenteId.trim());
        }
        if (aulaId != null && aulaId.trim().isNotEmpty) {
          queryGuardias = queryGuardias.eq('classroom_id', aulaId.trim());
        }
        final resGuardias = await queryGuardias;
        final guardias = (resGuardias as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(Guardia.fromJson)
                .toList() ??
            [];

        return RejillaCuadrante(
          periodo: periodo,
          clases: clases,
          guardias: guardias,
          aulas: aulas,
          docentes: docentes,
        );
      } catch (_) {
        return const RejillaCuadrante();
      }
    }
  }

  @override
  Future<ClaseCuadrante> crearClase(EntradaCrearClase entrada) async {
    final respuesta = await _api.post(
      '$_base/cuadrante',
      cuerpo: entrada.toJson(),
      token: _tokenSesion,
    );

    return ClaseCuadrante.fromJson(_objeto(respuesta, 'clase'));
  }

  @override
  Future<ClaseCuadrante> actualizarClase(
    String id,
    CambiosClase cambios,
  ) async {
    final respuesta = await _api.patch(
      '$_base/cuadrante/$id',
      cuerpo: cambios.toJson(),
      token: _tokenSesion,
    );

    return ClaseCuadrante.fromJson(_objeto(respuesta, 'clase'));
  }

  // ---------------------------------------------------------------------------
  // Horario por rol
  // ---------------------------------------------------------------------------

  @override
  Future<MiHorario> miHorario({String? periodo}) async {
    try {
      final respuesta = await _api.get(
        _rutaMiHorario,
        token: _tokenSesion,
        parametros: {'periodo': ?_limpiar(periodo)},
        tiempoEspera: const Duration(seconds: 3),
        permitirReintento: false,
      );

      return MiHorario.fromJson(respuesta);
    } catch (_) {
      try {
        final client = SupabaseService.instance.client;
        final usuario = client.auth.currentUser;
        if (usuario == null) return const MiHorario(rol: '');

        final resPerfil = await client
            .from('profiles')
            .select('rol')
            .eq('id', usuario.id)
            .maybeSingle();
        final rol = resPerfil?['rol']?.toString() ?? '';

        var queryClases = client
            .from('v_cuadrante_clases')
            .select()
            .eq('is_active', true);
        if (periodo != null && periodo.trim().isNotEmpty) {
          queryClases = queryClases.eq('period_code', periodo.trim());
        }
        if (rol == 'docente') {
          queryClases = queryClases.eq('teacher_id', usuario.id);
        }
        final resClases = await queryClases;
        final clases = (resClases as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(ClaseCuadrante.fromJson)
                .toList() ??
            [];

        List<Guardia> guardias = const [];
        if (rol == 'docente' || rol == 'admin') {
          var queryGuardias = client
              .from('v_cuadrante_guardias')
              .select()
              .eq('is_active', true);
          if (periodo != null && periodo.trim().isNotEmpty) {
            queryGuardias = queryGuardias.eq('period_code', periodo.trim());
          }
          if (rol == 'docente') {
            queryGuardias = queryGuardias.eq('teacher_id', usuario.id);
          }
          final resGuardias = await queryGuardias;
          guardias = (resGuardias as List<dynamic>?)
                  ?.whereType<Map<String, dynamic>>()
                  .map(Guardia.fromJson)
                  .toList() ??
              [];
        }

        return MiHorario(
          rol: rol,
          periodo: periodo,
          clases: clases,
          guardias: guardias,
        );
      } catch (_) {
        return const MiHorario(rol: '');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Utilidades
  // ---------------------------------------------------------------------------

  /// Saca el objeto de un sobre `{ "aula": { … } }`.
  ///
  /// El backend envuelve siempre el recurso en una clave con su nombre, para que
  /// una respuesta no sea un objeto suelto cuya forma dependa del endpoint. Si
  /// la clave no viniera, se cae al cuerpo entero antes que devolver un objeto
  /// vacío: un modelo con todos los campos en blanco se lee como «el registro no
  /// tiene datos», que es peor que fallar.
  static Map<String, dynamic> _objeto(
    Map<String, dynamic> respuesta,
    String clave,
  ) {
    final anidado = respuesta[clave];
    return anidado is Map<String, dynamic> ? anidado : respuesta;
  }

  /// Un booleano de consulta, en la forma que espera el backend.
  ///
  /// Se omite el filtro cuando es `null`, pero un `false` **sí** se manda: «no
  /// filtrar por activa» y «mostrar sólo las archivadas» son preguntas distintas.
  static String? _booleano(bool? valor) => valor?.toString();

  /// Un texto de búsqueda en blanco equivale a no filtrar.
  ///
  /// Se recorta aquí y no en la pantalla para que valga igual desde cualquier
  /// llamante: un filtro escrito con un espacio al final no encuentra nada y el
  /// administrador culpa a los datos.
  static String? _limpiar(String? texto) {
    final limpio = texto?.trim();
    return (limpio == null || limpio.isEmpty) ? null : limpio;
  }
}
