/// Resumen de ocupación de un curso (programa) para el panel «Cursos y PNA».
///
/// Agrupa por **programa** (no por sección): el cupo es el del curso
/// (`programs.cupo`, D5) y los ocupados son los `ENROLLED` de todas sus
/// secciones. La lista `secciones` trae las secciones activas para que la
/// pantalla abra los diálogos de cola/inscritos por sección sin una segunda
/// llamada. Sale de `GET /api/v1/admin/cursos/resumen`.
enum EstadoVentanaInscripcion {
  abierta('ABIERTA'),
  cerrada('CERRADA'),
  proximaApertura('PROXIMA_APERTURA');

  const EstadoVentanaInscripcion(this.valorRemoto);

  /// Valor tal como lo devuelve el backend (UPPERCASE).
  final String valorRemoto;

  /// Convierte el valor del backend al enum, fallando si es desconocido.
  static EstadoVentanaInscripcion desde(String? valor) => switch (valor) {
        'ABIERTA' => abierta,
        'CERRADA' => cerrada,
        'PROXIMA_APERTURA' => proximaApertura,
        _ => throw FormatException(
            'Estado de ventana de inscripción desconocido: $valor'),
      };
}

/// Sección activa de un programa, con lo mínimo para abrir los diálogos de cupo.
class SeccionResumenCurso {
  const SeccionResumenCurso({
    required this.id,
    required this.nombre,
    this.periodo,
  });

  final String id;
  final String nombre;
  final String? periodo;

  factory SeccionResumenCurso.fromJson(Map<String, dynamic> json) =>
      SeccionResumenCurso(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        periodo: json['periodo'] as String?,
      );
}

/// Ocupación agregada de un curso (programa) para el panel «Cursos y PNA».
class ResumenCurso {
  const ResumenCurso({
    required this.programaId,
    required this.nombre,
    required this.cupo,
    required this.ocupados,
    required this.disponibles,
    required this.estadoInscripcion,
    this.inscripcionInicio,
    this.inscripcionFin,
    this.proximaApertura,
    required this.secciones,
  });

  final String programaId;
  final String nombre;
  final int cupo;
  final int ocupados;
  final int disponibles;
  final EstadoVentanaInscripcion estadoInscripcion;
  final String? inscripcionInicio;
  final String? inscripcionFin;
  final String? proximaApertura;
  final List<SeccionResumenCurso> secciones;

  factory ResumenCurso.fromJson(Map<String, dynamic> json) => ResumenCurso(
        programaId: json['programaId'] as String,
        nombre: json['nombre'] as String,
        cupo: json['cupo'] as int? ?? 0,
        ocupados: json['ocupados'] as int? ?? 0,
        disponibles: json['disponibles'] as int? ?? 0,
        estadoInscripcion:
            EstadoVentanaInscripcion.desde(json['estadoInscripcion'] as String?),
        inscripcionInicio: json['inscripcionInicio'] as String?,
        inscripcionFin: json['inscripcionFin'] as String?,
        proximaApertura: json['proximaApertura'] as String?,
        secciones: (json['secciones'] as List? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(SeccionResumenCurso.fromJson)
            .toList(),
      );
}
