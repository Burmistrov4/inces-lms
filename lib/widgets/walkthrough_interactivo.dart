import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/inces_theme.dart';

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
    this.claveStorage = 'inces_walkthrough_admin_completado',
  });

  final void Function(String seccion) onNavegarA;
  final String claveStorage;

  @override
  State<WalkthroughInteractivoCard> createState() =>
      _WalkthroughInteractivoCardState();
}

class _WalkthroughInteractivoCardState
    extends State<WalkthroughInteractivoCard> {
  int _pasoActual = 0;
  bool _oculto = false;
  bool _inicializado = false;

  static const List<PasoWalkthrough> _pasos = [
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
          'Supervisa las solicitudes enviadas por los aspirantes en línea, asigna turnos por sección y gestiona las colas de espera con control estricto de cupos.',
      icono: Icons.how_to_reg_outlined,
      seccionDestino: 'Inscripciones y Cupos',
      textoBoton: 'Supervisar Inscripciones',
    ),
    PasoWalkthrough(
      etiquetaCategoria: 'Paso 4 de 5 · Talento Docente y Accesos',
      titulo: 'Invitar Facilitadores y Asignar Roles',
      descripcion:
          'Genera enlaces de invitación seguros para que los docentes se registren, asigna roles de coordinación y administra los accesos al personal autorizado.',
      icono: Icons.people_outline,
      seccionDestino: 'Usuarios y Roles',
      textoBoton: 'Gestionar Usuarios y Roles',
    ),
    PasoWalkthrough(
      etiquetaCategoria: 'Paso 5 de 5 · Biblioteca Digital y Aulas',
      titulo: 'Gestor Documental (R2 + Google Drive)',
      descripcion:
          'Organiza manuales técnicos en Cloudflare R2 y vincula carpetas o videos de Google Drive directamente a cada especialidad y aula virtual para docentes y aprendices.',
      icono: Icons.folder_open_outlined,
      seccionDestino: 'Gestor de Archivos (R2)',
      textoBoton: 'Abrir Gestor Documental',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _cargarEstado();
  }

  Future<void> _cargarEstado() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completado = prefs.getBool(widget.claveStorage) ?? false;
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
      await prefs.setBool(widget.claveStorage, true);
    } catch (_) {}
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

    if (_oculto) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _reiniciar,
            icon: const Icon(Icons.help_outline_rounded, size: 16),
            label: const Text('Ver Guía de Gestión (Walkthrough)'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    }

    final paso = _pasos[_pasoActual];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: esOscuro ? IncesTheme.superficieOscura : Colors.white,
        borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: IncesTheme.sombraTarjeta(theme.brightness),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      tooltip: 'Ocultar guía temporalmente',
                      onPressed: _marcarCompletado,
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
                      children: List.generate(_pasos.length, (i) {
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
                    if (_pasoActual < _pasos.length - 1)
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
