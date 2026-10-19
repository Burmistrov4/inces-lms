import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/aspirante_model.dart';
import '../../theme/inces_theme.dart';
import '../../widgets/barra_acciones_superiores.dart';
import '../../widgets/comunes.dart';

/// Panel de resumen académico del Aprendiz / Estudiante.
///
/// Presenta una visión integral de su estado formativo: programa asignado,
/// acceso instantáneo para marcar asistencia en clase mediante QR o código
/// numérico, acceso a aulas virtuales, gestor de entregas y avisos del centro.
class EstudianteResumenPanel extends StatelessWidget {
  const EstudianteResumenPanel({
    super.key,
    this.aspirante,
    this.onNavegarA,
    this.onDescargarPlanilla,
    this.onDescargarExcel,
  });

  /// Ficha del estudiante con sus datos de matrícula.
  final AspiranteModel? aspirante;

  /// Permite saltar a una pestaña del dashboard de estudiante.
  final void Function(String tituloSeccion)? onNavegarA;

  /// Permite descargar el comprobante oficial en PDF.
  final VoidCallback? onDescargarPlanilla;

  /// Permite descargar la planilla en formato Excel (.xlsx).
  final VoidCallback? onDescargarExcel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;

    final nombre = aspirante?.nombres.trim().isNotEmpty == true
        ? aspirante!.nombres.trim()
        : 'Aprendiz';

    final programa = aspirante?.programaNombre?.trim().isNotEmpty == true
        ? aspirante!.programaNombre!.trim()
        : 'Programa Técnico en Asignación';

    final cedula = aspirante != null && aspirante!.cedula.isNotEmpty
        ? 'C.I. ${aspirante!.cedula}'
        : 'Ficha activa';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BarraAccionesSuperiores.estudiante(
            onOfertasCupos: () => onNavegarA?.call('Ofertas de cupos'),
            onMisAulas: () => onNavegarA?.call('Mis aulas'),
            onAsistencia: () => onNavegarA?.call('Asistencia'),
            onDescargarPlanilla: onDescargarPlanilla,
            onDescargarExcel: onDescargarExcel,
          ),
          _construirCabecera(theme, esOscuro, nombre, programa, cedula),
          const SizedBox(height: 20),
          _construirMetricas(programa),
          const SizedBox(height: 24),
          _construirAccionesPrioritarias(theme),
          const SizedBox(height: 24),
          _construirAvisosAcademicos(theme),
          const SizedBox(height: 20),
          _construirPie(theme),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cabecera
  // ---------------------------------------------------------------------------

  Widget _construirCabecera(
    ThemeData theme,
    bool esOscuro,
    String nombre,
    String programa,
    String cedula,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
          border: Border.all(color: theme.colorScheme.outline),
          boxShadow: [
            BoxShadow(
              color: IncesTheme.azulPrimario.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/area_juvenil.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: esOscuro
                      ? IncesTheme.superficieOscura
                      : IncesTheme.azulPrimario,
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.90),
                      Colors.black.withValues(alpha: 0.75),
                      IncesTheme.azulPrimario.withValues(alpha: 0.60),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -10,
              bottom: -20,
              child: Opacity(
                opacity: 0.16,
                child: const Icon(
                  Icons.school_rounded,
                  size: 140,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: IncesTheme.exito.withValues(alpha: 0.5),
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
                              'APRENDIZ REGULAR · $cedula',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: IncesTheme.exito,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: IncesTheme.advertencia,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'SEDE LA ISABELICA',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: IncesTheme.azulPrimario,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.30),
                          ),
                        ),
                        child: Text(
                          'Período SA26-2',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '¡Bienvenido, $nombre!',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Especialidad: $programa · CFS Nacional de Soldadura «Rafael Urdaneta». '
                    'Accede a tus asignaturas, sube tareas y marca tu asistencia.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 3,
                        decoration: BoxDecoration(
                          color: IncesTheme.advertencia,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Container(
                        width: 24,
                        height: 3,
                        decoration: BoxDecoration(
                          color: IncesTheme.azulSecundario,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Container(
                        width: 24,
                        height: 3,
                        decoration: BoxDecoration(
                          color: IncesTheme.rojoInces,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Métricas
  // ---------------------------------------------------------------------------

  Widget _construirMetricas(String programa) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final columnas = ancho > 1000
            ? 3
            : ancho > 600
                ? 2
                : 1;

        final items = [
          TarjetaMetrica(
            etiqueta: 'Programa técnico',
            valor: programa.length > 20 ? '${programa.substring(0, 18)}...' : programa,
            icono: Icons.school_rounded,
            tono: TonoEstado.info,
          ),
          const TarjetaMetrica(
            etiqueta: 'Asistencia en aula',
            valor: 'Control activo',
            icono: Icons.fact_check_rounded,
            tono: TonoEstado.exito,
          ),
          const TarjetaMetrica(
            etiqueta: 'Campus Virtual',
            valor: 'Activo',
            icono: Icons.devices_rounded,
            tono: TonoEstado.info,
          ),
        ];

        if (columnas == 1) {
          return Column(
            children: [
              for (final item in items) ...[
                item,
                const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final item in items)
              SizedBox(
                width: (ancho - (columnas - 1) * 16) / columnas,
                child: item,
              ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Acciones prioritarias
  // ---------------------------------------------------------------------------

  Widget _construirAccionesPrioritarias(ThemeData theme) {
    final paleta = PaletaInces.deBrillo(theme.brightness);
    final acciones = [
      _EstudianteAccionData(
        titulo: 'Marcar Asistencia a Clase',
        descripcion: 'Ingresar el código de 6 dígitos de la pizarra o escanear el QR proyectado.',
        icono: Icons.fact_check_outlined,
        seccionDestino: 'Asistencia',
        color: IncesTheme.azulPrimario,
      ),
      _EstudianteAccionData(
        titulo: 'Mis Aulas Virtuales',
        descripcion: 'Consultar el tablón de anuncios, clases teóricas y tareas del docente.',
        icono: Icons.class_outlined,
        seccionDestino: 'Mis aulas',
        color: paleta.exito,
      ),
      _EstudianteAccionData(
        titulo: 'Mis Entregas y Tareas',
        descripcion: 'Revisar tareas asignadas, fechas límite, entregas pendientes y notas oficiales obtenidas.',
        icono: Icons.assignment_turned_in_outlined,
        seccionDestino: 'Mis entregas',
        color: paleta.enlace,
      ),
      _EstudianteAccionData(
        titulo: 'Mi Expediente y Planilla',
        descripcion: 'Verificar los datos de registro y descargar la planilla oficial institucional.',
        icono: Icons.badge_outlined,
        seccionDestino: 'Mi expediente',
        color: paleta.advertencia,
      ),
      _EstudianteAccionData(
        titulo: 'Ofertas de Cupos',
        descripcion: 'Explorar las secciones académicas abiertas e inscribirse en nuevos cursos.',
        icono: Icons.explore_outlined,
        seccionDestino: 'Ofertas de cupos',
        color: IncesTheme.azulSecundario,
      ),
      _EstudianteAccionData(
        titulo: 'Mi Perfil de Usuario',
        descripcion: 'Actualizar nombres y verificar credenciales de acceso al sistema.',
        icono: Icons.account_circle_outlined,
        seccionDestino: 'Mi Perfil',
        color: paleta.neutro,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Herramientas del Aprendiz',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Accesos directos',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final ancho = constraints.maxWidth;
            final columnas = ancho > 1000
                ? 3
                : ancho > 640
                    ? 2
                    : 1;

            if (columnas == 1) {
              return Column(
                children: [
                  for (final item in acciones) ...[
                    _construirTarjetaAccion(item, theme),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            }

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final item in acciones)
                  SizedBox(
                    width: (ancho - (columnas - 1) * 16) / columnas,
                    child: _construirTarjetaAccion(item, theme),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _construirTarjetaAccion(_EstudianteAccionData data, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: InkWell(
        onTap: () => onNavegarA?.call(data.seccionDestino),
        borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(IncesTheme.radioControl),
                ),
                child: Icon(data.icono, color: data.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.titulo,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.descripcion,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Avisos académicos
  // ---------------------------------------------------------------------------

  Widget _construirAvisosAcademicos(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: IncesTheme.azulPrimario.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        border: Border.all(
          color: IncesTheme.azulPrimario.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: IncesTheme.azulPrimario,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compromiso Formativo y Normas del Taller',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: IncesTheme.azulPrimario,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'El reglamento del INCES exige un mínimo del 75% de asistencia presencial '
                  'para la certificación oficial. Recuerde registrar su asistencia al inicio '
                  'de cada sesión y consultar en «Mis aulas» las instrucciones de seguridad '
                  'industrial correspondientes a su taller.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirPie(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'CFS Nacional de Soldadura «Rafael Urdaneta» · Portal del Aprendiz · v1.2.4 · Prod 2026',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class _EstudianteAccionData {
  const _EstudianteAccionData({
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.seccionDestino,
    required this.color,
  });

  final String titulo;
  final String descripcion;
  final IconData icono;
  final String seccionDestino;
  final Color color;
}
