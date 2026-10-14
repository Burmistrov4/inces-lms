import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/inces_theme.dart';
import '../../widgets/comunes.dart';

/// Panel de resumen y control docente.
///
/// Ofrece al instructor una visión inmediata de sus tareas prioritarias:
/// toma de asistencia en vivo, acceso rápido a sus aulas, revisión de su
/// horario de clases y recomendaciones operativas para la evaluación formativa.
class DocenteResumenPanel extends StatelessWidget {
  const DocenteResumenPanel({
    super.key,
    this.onNavegarA,
  });

  /// Permite navegar a una pestaña del dashboard docente.
  final void Function(String tituloSeccion)? onNavegarA;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _construirCabecera(theme, esOscuro),
          const SizedBox(height: 20),
          _construirMetricas(),
          const SizedBox(height: 24),
          _construirAccionesPrioritarias(theme),
          const SizedBox(height: 24),
          _construirOrientacionPedagogica(theme),
          const SizedBox(height: 20),
          _construirPie(theme),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cabecera
  // ---------------------------------------------------------------------------

  Widget _construirCabecera(ThemeData theme, bool esOscuro) {
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
                'assets/images/area_metalmecanica.jpg',
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
                  Icons.badge_rounded,
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
                              'PORTAL DOCENTE ACTIVO',
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
                          'CUERPO DE FACILITADORES',
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
                          'Lapso SA26-2',
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
                    'Panel de Control del Instructor',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Gestión de asignaturas, pase de lista con QR dinámico, tablón de clase '
                    'y evaluación continua en el CFS «Rafael Urdaneta».',
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

  Widget _construirMetricas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final columnas = ancho > 1000
            ? 3
            : ancho > 600
                ? 2
                : 1;

        final items = [
          const TarjetaMetrica(
            etiqueta: 'Asistencia en vivo',
            valor: 'QR + 6 dígitos',
            icono: Icons.qr_code_scanner_rounded,
            tono: TonoEstado.exito,
          ),
          const TarjetaMetrica(
            etiqueta: 'Aula Virtual',
            valor: 'Tablón y Tareas',
            icono: Icons.class_rounded,
            tono: TonoEstado.info,
          ),
          const TarjetaMetrica(
            etiqueta: 'Materiales R2',
            valor: 'Nube institucional',
            icono: Icons.cloud_done_rounded,
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
      _DocenteAccionData(
        titulo: 'Tomar Asistencia QR',
        descripcion: 'Abrir sesión proyectable en pizarra con código efímero y verificación WebSocket.',
        icono: Icons.fact_check_outlined,
        seccionDestino: 'Asistencia',
        color: IncesTheme.azulPrimario,
      ),
      _DocenteAccionData(
        titulo: 'Mis Aulas Virtuales',
        descripcion: 'Acceder a las secciones, publicar anuncios y gestionar tareas prácticas.',
        icono: Icons.dashboard_outlined,
        seccionDestino: 'Mis aulas',
        color: paleta.exito,
      ),
      _DocenteAccionData(
        titulo: 'Consultar Mi Horario',
        descripcion: 'Revisar la distribución semanal de bloques académicos y guardias asignadas.',
        icono: Icons.calendar_month_outlined,
        seccionDestino: 'Mi horario',
        color: paleta.enlace,
      ),
      _DocenteAccionData(
        titulo: 'Revisar Calificaciones',
        descripcion: 'Asentar notas en borrador, revisar entregas y devolver calificaciones oficiales.',
        icono: Icons.grading_rounded,
        seccionDestino: 'Calificaciones',
        color: paleta.info,
      ),
      _DocenteAccionData(
        titulo: 'Material de Apoyo',
        descripcion: 'Subir guías pedagógicas y diagramas técnicos directamente a Cloudflare R2.',
        icono: Icons.folder_open_outlined,
        seccionDestino: 'Material de apoyo',
        color: paleta.advertencia,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Acciones de Clase',
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
                'Herramientas del docente',
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
            final columnas = ancho > 900
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
                    width: (ancho - 16) / 2,
                    child: _construirTarjetaAccion(item, theme),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _construirTarjetaAccion(_DocenteAccionData data, ThemeData theme) {
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
  // Orientación pedagógica
  // ---------------------------------------------------------------------------

  Widget _construirOrientacionPedagogica(ThemeData theme) {
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
            Icons.school_outlined,
            color: IncesTheme.azulPrimario,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calificación y Retroalimentación Integral',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: IncesTheme.azulPrimario,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Para calificar entregas de aprendices, diríjase a «Mis aulas», '
                  'seleccione la sección y acceda a la pestaña «Trabajo de Clase». '
                  'Allí podrá asentar notas de 0 a 20 con comentarios técnicos detallados.',
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
          'CFS Nacional de Soldadura «Rafael Urdaneta» · Cuerpo Docente · v0.1.0',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class _DocenteAccionData {
  const _DocenteAccionData({
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
