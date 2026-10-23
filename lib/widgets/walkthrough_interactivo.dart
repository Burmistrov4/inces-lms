import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/inces_theme.dart';

/// Roles soportados por el recorrido guiado interactivo.
enum RolWalkthrough {
  admin,
  docente,
  estudiante,
}

/// Un paso interactivo del recorrido guiado para la gestión del sistema.
class PasoWalkthrough {
  const PasoWalkthrough({
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.seccionDestino,
    required this.textoBoton,
    required this.etiquetaCategoria,
  });

  final String titulo;
  final String descripcion;
  final IconData icono;
  final String seccionDestino;
  final String textoBoton;
  final String etiquetaCategoria;
}

/// Walkthrough interactivo y moderno estilo Binance / apps inteligentes.
/// Guía paso a paso al usuario en la gestión y administración de la plataforma.
class WalkthroughInteractivoCard extends StatefulWidget {
  const WalkthroughInteractivoCard({
    super.key,
    required this.onNavegarA,
    this.rol = RolWalkthrough.admin,
    this.claveStorage,
    this.enModal = false,
  });

  final void Function(String seccion) onNavegarA;
  final RolWalkthrough rol;
  final String? claveStorage;
  final bool enModal;

  /// Abre el recorrido guiado interactivo en un diálogo modal accesible desde cualquier pantalla.
  static Future<void> mostrarModal(
    BuildContext context, {
    RolWalkthrough rol = RolWalkthrough.admin,
    required void Function(String seccion) onNavegarA,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: WalkthroughInteractivoCard(
              rol: rol,
              enModal: true,
              onNavegarA: (seccion) {
                Navigator.of(ctx).pop();
                onNavegarA(seccion);
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<WalkthroughInteractivoCard> createState() =>
      _WalkthroughInteractivoCardState();
}

class _WalkthroughInteractivoCardState
    extends State<WalkthroughInteractivoCard> {
  int _pasoActual = 0;
  bool _oculto = false;
  bool _inicializado = false;

  String get _claveEfectiva =>
      widget.claveStorage ??
      switch (widget.rol) {
        RolWalkthrough.admin => 'inces_walkthrough_admin_completado',
        RolWalkthrough.docente => 'inces_walkthrough_docente_completado',
        RolWalkthrough.estudiante => 'inces_walkthrough_estudiante_completado',
      };

  List<PasoWalkthrough> get _pasos => switch (widget.rol) {
        RolWalkthrough.admin => _pasosAdmin,
        RolWalkthrough.docente => _pasosDocente,
        RolWalkthrough.estudiante => _pasosEstudiante,
      };

  static const List<PasoWalkthrough> _pasosAdmin = [
    PasoWalkthrough(
      etiquetaCategoria: 'Paso 1 de 5 · Planificación Académica',
      titulo: 'Configurar Lapsos y Aulas de Clases',
      descripcion:
          'Comienza definiendo el lapso académico en curso (ej. SA26-2) y registra las aulas y talleres técnicos donde se impartirán las actividades formativas del centro.',
      icono: Icons.calendar_month_outlined,
      seccionDestino: 'Lapsos Académicos',
      textoBoton: 'Ir a Lapsos Académicos',
    ),
    PasoWalkthrough(
      etiquetaCategoria: 'Paso 2 de 5 · Estructura Curricular',
      titulo: 'Cargar Oferta Formativa y Pensum',
      descripcion:
          'Verifica los programas de formación técnica (Soldadura, Gastronomía, Informática, etc.) y asigna las materias o módulos correspondientes en el asistente curricular.',
      icono: Icons.menu_book_outlined,
      seccionDestino: 'Programas Académicos',
      textoBoton: 'Ver Programas y Pensum',
    ),
    PasoWalkthrough(
      etiquetaCategoria: 'Paso 3 de 5 · Admisión y Matrícula',
      titulo: 'Gestión de Inscripciones y Cupos',
      descripcion:
          'Supervisa las solicitudes enviadas por los aspirantes en línea, asigna turnos por sección y gestiona las colas de espera con control estricto de cupos y emisión de Planilla Oficial.',
      icono: Icons.how_to_reg_outlined,
      seccionDestino: 'Inscripciones y Cupos',
      textoBoton: 'Supervisar Inscripciones',
    ),
    PasoWalkthrough(
      etiquetaCategoria: 'Paso 4 de 5 · Talento Docente y Testing',
      titulo: 'Invitar Profesores por Correo y Asignar Roles',
      descripcion:
          'Genera invitaciones por correo electrónico para que los instructores activen su cuenta, fijen su contraseña y realicen pruebas de evaluación en los talleres.',
      icono: Icons.mark_email_read_outlined,
      seccionDestino: 'Usuarios y Roles',
      textoBoton: 'Gestionar Usuarios y Roles',
    ),
    PasoWalkthrough(
      etiquetaCategoria: 'Paso 5 de 5 · Biblioteca Digital y Aulas',
      titulo: 'Gestor Documental (Cloudflare R2 + Google Drive)',
      descripcion:
          'Organiza manuales técnicos en Cloudflare R2 y vincula carpetas o videos de Google Drive directamente a cada especialidad y aula virtual para docentes y aprendices.',
      icono: Icons.folder_open_outlined,
      seccionDestino: 'Cloud CFS',
      textoBoton: 'Abrir Gestor Documental',
    ),
  ];

  static const List<PasoWalkthrough> _pasosDocente = [
    PasoWalkthrough(
      etiquetaCategoria: 'Paso 1 de 5 · Aula Virtual',
      titulo: 'Gestionar Mis Aulas y Secciones',
      descripcion:
          'Accede a los cursos y grupos prácticos asignados en el taller técnico de soldadura, publica avisos y dinamiza el tablón de clases.',
      icono: Icons.class_outlined,
      seccionDestino: 'Mis aulas',
      textoBoton: 'Ir a Mis Aulas',
    ),
    PasoWalkthrough(
      etiquetaCategoria: 'Paso 2 de 5 · Asistencia Técnica',
      titulo: 'Apertura de Sesión y Control de Asistencia',
      descripcion:
          'Inicia las jornadas de clase generando un código numérico temporal de 6 dígitos o el código QR dinámico para el registro presencial de los aprendices en el taller.',
      icono: Icons.fact_check_outlined,
      seccionDestino: 'Asistencia',
      textoBoton: 'Control de Asistencia',
    ),
    PasoWalkthrough(
      etiquetaCategoria: 'Paso 3 de 5 · Evaluación Práctica',
      titulo: 'Calificaciones y Corrección de Tareas',
      descripcion:
          'Evalúa las entregas formativas, revisa evidencias fotográficas de cordones de soldadura y califica con retroalimentación personalizada.',
      icono: Icons.grading_outlined,
      seccionDestino: 'Calificaciones',
      textoBoton: 'Ver Calificaciones',
    ),
    PasoWalkthrough(
      etiquetaCategoria: 'Paso 4 de 5 · Biblioteca de Taller',
      titulo: 'Material de Apoyo y Guías Técnicas',
      descripcion:
          'Carga guías de seguridad industrial, planos y normas técnicas en Cloudflare R2 para consulta inmediata de los aprendices en el aula.',
      icono: Icons.folder_open_outlined,
      seccionDestino: 'Material de apoyo',
      textoBoton: 'Material de Apoyo',
    ),
    PasoWalkthrough(
      etiquetaCategoria: 'Paso 5 de 5 · Planificación',
      titulo: 'Consulta de Horarios y Guardias',
      descripcion:
          'Supervisa tu cuadrante semanal con los bloques de instrucción en taller y turnos de guardia asignados por la jefatura del CFS.',
      icono: Icons.calendar_month_outlined,
      seccionDestino: 'Mi horario',
      textoBoton: 'Consultar Mi Horario',
    ),
  ];

  static const List<PasoWalkthrough> _pasosEstudiante = [
    PasoWalkthrough(
      etiquetaCategoria: 'Paso 1 de 5 · Identificación Institucional',
      titulo: 'Mi Expediente y Planilla Oficial',
      descripcion:
          'Verifica tus datos de matrícula y descarga tu Planilla Oficial de Inscripción con calibración técnica y código QR de validación institucional.',
      icono: Icons.badge_outlined,
      seccionDestino: 'Mi Expediente',
      textoBoton: 'Ver Mi Expediente',
    ),
    PasoWalkthrough(
      etiquetaCategoria: 'Paso 2 de 5 · Aula Virtual',
      titulo: 'Mis Aulas y Tablón de Actividades',
      descripcion:
          'Entra a tus cursos técnicos de soldadura, consulta anuncios de los profesores y revisa las fechas límites de entregas.',
      icono: Icons.class_outlined,
      seccionDestino: 'Mis aulas',
      textoBoton: 'Abrir Mis Aulas',
    ),
    PasoWalkthrough(
      etiquetaCategoria: 'Paso 3 de 5 · Evidencias Prácticas',
      titulo: 'Subir Tareas y Evidencias de Taller',
      descripcion:
          'Sube fotos claras de tus probetas, piezas y cordones de soldadura o documentos técnicos para la evaluación continua del instructor.',
      icono: Icons.assignment_turned_in_outlined,
      seccionDestino: 'Mis entregas',
      textoBoton: 'Subir Mis Entregas',
    ),
    PasoWalkthrough(
      etiquetaCategoria: 'Paso 4 de 5 · Presencia en Taller',
      titulo: 'Registro de Asistencia Diaria',
      descripcion:
          'Registra tu asistencia en el taller introduciendo el código diario de 6 dígitos que te dé el profesor o escaneando el código QR con tu teléfono.',
      icono: Icons.fact_check_outlined,
      seccionDestino: 'Asistencia',
      textoBoton: 'Marcar Asistencia',
    ),
    PasoWalkthrough(
      etiquetaCategoria: 'Paso 5 de 5 · Recursos de Estudio',
      titulo: 'Descarga de Manuales y Guías Técnicas',
      descripcion:
          'Accede a los manuales oficiales de soldadura por arco y normas de seguridad industrial cargadas por tus facilitadores.',
      icono: Icons.folder_open_outlined,
      seccionDestino: 'Material de apoyo',
      textoBoton: 'Ver Material de Apoyo',
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.enModal) {
      _oculto = false;
      _inicializado = true;
    } else {
      _cargarEstado();
    }
  }

  Future<void> _cargarEstado() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completado = prefs.getBool(_claveEfectiva) ?? false;
      if (mounted) {
        setState(() {
          _oculto = completado;
          _inicializado = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _inicializado = true);
      }
    }
  }

  Future<void> _marcarCompletado() async {
    setState(() => _oculto = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_claveEfectiva, true);
    } catch (_) {}
    if (widget.enModal && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _reiniciar() {
    setState(() {
      _oculto = false;
      _pasoActual = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_inicializado) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;

    if (_oculto && !widget.enModal) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _reiniciar,
            icon: const Icon(Icons.help_outline_rounded, size: 16),
            label: const Text('Ver Guía Interactiva (Walkthrough)'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    }

    final pasos = _pasos;
    if (_pasoActual >= pasos.length) _pasoActual = 0;
    final paso = pasos[_pasoActual];

    return Container(
      margin: widget.enModal ? EdgeInsets.zero : const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: esOscuro ? IncesTheme.superficieOscura : Colors.white,
        borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: widget.enModal ? null : IncesTheme.sombraTarjeta(theme.brightness),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: IncesTheme.degradadoAzul,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.school_outlined, size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            paso.etiquetaCategoria,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: widget.enModal ? 'Cerrar guía' : 'Ocultar guía temporalmente',
                      onPressed: () {
                        if (widget.enModal) {
                          Navigator.of(context, rootNavigator: true).pop();
                        } else {
                          _marcarCompletado();
                        }
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(IncesTheme.radioControl),
                      ),
                      child: Icon(paso.icono, color: theme.colorScheme.primary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            paso.titulo,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            paso.descripcion,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              height: 1.45,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Indicadores de puntos (Dots)
                    Row(
                      children: List.generate(pasos.length, (i) {
                        final activo = i == _pasoActual;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 6),
                          width: activo ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: activo
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const Spacer(),
                    if (_pasoActual > 0)
                      TextButton(
                        onPressed: () => setState(() => _pasoActual--),
                        child: const Text('Anterior'),
                      ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: () => widget.onNavegarA(paso.seccionDestino),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: Text(paso.textoBoton),
                    ),
                    const SizedBox(width: 8),
                    if (_pasoActual < pasos.length - 1)
                      FilledButton(
                        onPressed: () => setState(() => _pasoActual++),
                        child: const Text('Siguiente'),
                      )
                    else
                      FilledButton(
                        onPressed: _marcarCompletado,
                        child: const Text('Completar Guía'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
