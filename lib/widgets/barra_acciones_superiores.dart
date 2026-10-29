import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/inces_theme.dart';
import 'guardia_toque.dart';

/// Barra de acciones rápidas y panel superior del Dashboard institucional.
///
/// Proporciona accesos directos de alta visibilidad para la gestión académica
/// cotidiana (+ Inscribir Aspirante, + Asignar Clase, Ver Aulas, Generar Reporte),
/// junto con la insignia de período académico activo y el estado operativo del nodo.
class BarraAccionesSuperiores extends StatelessWidget {
  const BarraAccionesSuperiores({
    super.key,
    this.onInscribirAspirante,
    this.onAsignarClase,
    this.onVerAulas,
    this.onGenerarReporte,
    this.onVerLapsos,
    this.onVerModulos,
    this.acciones,
    this.periodo = 'SA26-2',
    this.estadoSistema = 'Sistema: 100% En Línea',
  });

  /// Barra superior de acciones para el portal Docente.
  factory BarraAccionesSuperiores.docente({
    Key? key,
    VoidCallback? onMisAulas,
    VoidCallback? onAsistencia,
    VoidCallback? onCalificaciones,
    VoidCallback? onMiHorario,
    VoidCallback? onVerLapsos,
    String periodo = 'SA26-2',
    String estadoSistema = 'Portal Docente: En Línea',
  }) {
    return BarraAccionesSuperiores(
      key: key,
      periodo: periodo,
      estadoSistema: estadoSistema,
      onVerLapsos: onVerLapsos,
      acciones: [
        if (onMisAulas != null)
          FilledButton.icon(
            onPressed: () => conGuardia(onMisAulas, 'barra-MisAulas'),
            icon: const Icon(Icons.class_outlined, size: 15),
            label: const Text('Mis Aulas'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (onAsistencia != null)
          FilledButton.tonalIcon(
            onPressed: () => conGuardia(onAsistencia, 'barra-Asistencia'),
            icon: const Icon(Icons.fact_check_outlined, size: 15),
            label: const Text('Pasar lista'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (onCalificaciones != null)
          OutlinedButton.icon(
            onPressed: () => conGuardia(onCalificaciones, 'barra-Calificaciones'),
            icon: const Icon(Icons.grading_outlined, size: 15),
            label: const Text('Calificaciones'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              textStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (onMiHorario != null)
          OutlinedButton.icon(
            onPressed: () => conGuardia(onMiHorario, 'barra-MiHorario'),
            icon: const Icon(Icons.calendar_month_outlined, size: 15),
            label: const Text('Mi Horario'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              textStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  /// Barra superior de acciones para el portal Estudiante / Aprendiz.
  factory BarraAccionesSuperiores.estudiante({
    Key? key,
    VoidCallback? onOfertasCupos,
    VoidCallback? onMisAulas,
    VoidCallback? onAsistencia,
    VoidCallback? onDescargarPlanilla,
    VoidCallback? onDescargarExcel,
    VoidCallback? onVerLapsos,
    String periodo = 'SA26-2',
    String estadoSistema = 'Portal Aprendiz: En Línea',
  }) {
    return BarraAccionesSuperiores(
      key: key,
      periodo: periodo,
      estadoSistema: estadoSistema,
      onVerLapsos: onVerLapsos,
      acciones: [
        if (onOfertasCupos != null)
          FilledButton.icon(
            onPressed: () => conGuardia(onOfertasCupos, 'barra-OfertasCupos'),
            icon: const Icon(Icons.explore_outlined, size: 15),
            label: const Text('Ofertas de Cupos'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (onMisAulas != null)
          FilledButton.tonalIcon(
            onPressed: () => conGuardia(onMisAulas, 'barra-MisAulas'),
            icon: const Icon(Icons.class_outlined, size: 15),
            label: const Text('Mis Aulas'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (onAsistencia != null)
          OutlinedButton.icon(
            onPressed: () => conGuardia(onAsistencia, 'barra-Asistencia'),
            icon: const Icon(Icons.fact_check_outlined, size: 15),
            label: const Text('Marcar Asistencia'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              textStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (onDescargarPlanilla != null)
          OutlinedButton.icon(
            onPressed: () => conGuardia(onDescargarPlanilla, 'barra-DescargarPlanilla'),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
            label: const Text('Planilla PDF'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              textStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (onDescargarExcel != null)
          OutlinedButton.icon(
            onPressed: () => conGuardia(onDescargarExcel, 'barra-DescargarExcel'),
            icon: const Icon(Icons.table_chart_outlined, size: 15),
            label: const Text('Planilla Excel'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              textStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  final VoidCallback? onInscribirAspirante;
  final VoidCallback? onAsignarClase;
  final VoidCallback? onVerAulas;
  final VoidCallback? onGenerarReporte;
  final VoidCallback? onVerLapsos;
  final VoidCallback? onVerModulos;
  final List<Widget>? acciones;
  final String periodo;
  final String estadoSistema;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: esOscuro
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.40)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final esEstrecho = constraints.maxWidth < 720;

          final insignias = Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Estado del sistema con pulso verde
              InkWell(
                onTap: () => conGuardia(onVerModulos, 'barra-VerModulos'),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: IncesTheme.exito.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: IncesTheme.exito.withValues(alpha: 0.40),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: IncesTheme.exito,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        estadoSistema,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: IncesTheme.exito,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Insignia de período académico
              InkWell(
                onTap: () => conGuardia(onVerLapsos, 'barra-VerLapsos'),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Período: $periodo',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );

          final itemsAccion = acciones ??
              [
                if (onInscribirAspirante != null)
                  FilledButton.icon(
                    onPressed: () => conGuardia(onInscribirAspirante, 'barra-InscribirAspirante'),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 15),
                    label: const Text('+ Inscribir Aspirante'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (onAsignarClase != null)
                  FilledButton.tonalIcon(
                    onPressed: () => conGuardia(onAsignarClase, 'barra-AsignarClase'),
                    icon: const Icon(Icons.add_to_photos_rounded, size: 15),
                    label: const Text('+ Asignar Clase'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (onVerAulas != null)
                  OutlinedButton.icon(
                    onPressed: () => conGuardia(onVerAulas, 'barra-VerAulas'),
                    icon: const Icon(Icons.meeting_room_outlined, size: 15),
                    label: const Text('Ver Aulas'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      textStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (onGenerarReporte != null)
                  OutlinedButton.icon(
                    onPressed: () => conGuardia(onGenerarReporte, 'barra-GenerarReporte'),
                    icon: const Icon(Icons.summarize_outlined, size: 15),
                    label: const Text('Generar Reporte'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      textStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ];

          final botonesAccion = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: itemsAccion,
          );

          if (esEstrecho) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                insignias,
                const SizedBox(height: 10),
                botonesAccion,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              insignias,
              const SizedBox(width: 12),
              Flexible(child: botonesAccion),
            ],
          );
        },
      ),
    );
  }

  /// Despliega el diálogo modal institucional para generar y consultar reportes.
  static void mostrarDialogoReportes(
    BuildContext context, {
    VoidCallback? onVerHorarios,
    VoidCallback? onVerInscripciones,
    VoidCallback? onVerAccesos,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);

        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.analytics_outlined,
                  color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 10),
              const Text('Generación de Reportes'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Selecciona el reporte consolidado que deseas consultar o exportar '
                    'para la coordinación del CFS Nacional de Soldadura «Rafael Urdaneta»:',
                    style: theme.textTheme.bodyMedium,
                  ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.confirmation_number_outlined),
                  title: const Text('Cursos y Cupos Oficiales'),
                  subtitle: const Text(
                      'Postulaciones de aspirantes, cupos ofertados y colas de espera.'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onVerInscripciones?.call();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Horarios y Ocupación de Espacios'),
                  subtitle: const Text(
                      'Matriz de bloques académicos, turnos y asignación de talleres.'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onVerHorarios?.call();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security_outlined),
                  title: const Text('Trazabilidad de Accesos y Seguridad'),
                  subtitle: const Text(
                      'Historial de inicio de sesión, IP y eventos de auditoría.'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onVerAccesos?.call();
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}
