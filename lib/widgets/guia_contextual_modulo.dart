import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/inces_theme.dart';

/// Un ítem o paso dentro de una guía contextual de módulo.
class PasoGuiaContextual {
  const PasoGuiaContextual({
    required this.numero,
    required this.titulo,
    required this.descripcion,
    this.icono = Icons.check_circle_outline_rounded,
  });

  final int numero;
  final String titulo;
  final String descripcion;
  final IconData icono;
}

/// Banner inteligente y contextual de descubrimiento de funciones (Contextual In-App Guidance).
///
/// Se presenta de forma sutil y amigable en la parte superior de cada módulo cuando
/// el usuario ingresa por primera vez, explicando en lenguaje accesible (no técnico)
/// el objetivo institucional del área y los pasos para usarla.
///
/// Permite cerrarse ("Entendido") persistiendo el estado en [SharedPreferences],
/// y puede reactivarse en cualquier momento mediante un botón de ayuda contextual.
class GuiaContextualModulo extends StatefulWidget {
  const GuiaContextualModulo({
    super.key,
    required this.claveStorage,
    required this.titulo,
    required this.subtitulo,
    required this.pasos,
    this.icono = Icons.school_outlined,
  });

  /// Identificador único para recordar si el usuario ya vio y cerró la guía.
  final String claveStorage;

  /// Título claro y amigable del módulo.
  final String titulo;

  /// Explicación accesible sobre el propósito del módulo.
  final String subtitulo;

  /// Pasos recomendados de acción.
  final List<PasoGuiaContextual> pasos;

  /// Icono representativo.
  final IconData icono;

  @override
  State<GuiaContextualModulo> createState() => _GuiaContextualModuloState();
}

class _GuiaContextualModuloState extends State<GuiaContextualModulo> {
  bool _oculto = false;
  bool _expandido = false;
  bool _inicializado = false;

  @override
  void initState() {
    super.initState();
    _verificarEstado();
  }

  Future<void> _verificarEstado() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final visto = prefs.getBool('guia_vistas_${widget.claveStorage}') ?? false;
      if (mounted) {
        setState(() {
          _oculto = visto;
          _inicializado = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _inicializado = true;
        });
      }
    }
  }

  Future<void> _marcarComoVisto() async {
    setState(() => _oculto = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('guia_vistas_${widget.claveStorage}', true);
    } catch (_) {}
  }

  void _reabrirGuia() {
    setState(() {
      _oculto = false;
      _expandido = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_inicializado) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final paleta = PaletaInces.de(context);
    final esOscuro = theme.brightness == Brightness.dark;

    if (_oculto) {
      // Botón flotante o discreto para consultar la guía nuevamente si se desea
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextButton.icon(
            onPressed: _reabrirGuia,
            icon: Icon(Icons.help_outline_rounded, size: 16, color: paleta.info),
            label: Text(
              '¿Cómo usar este módulo?',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: paleta.info,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: esOscuro
            ? paleta.superficieSutil
            : paleta.info.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        border: Border.all(
          color: paleta.info.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: paleta.info.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.icono, color: paleta.info, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: paleta.info.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'GUÍA RÁPIDA DE USO',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: paleta.info,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.titulo,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: paleta.textoPrincipal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitulo,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: paleta.textoSecundario,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Cerrar guía',
                  onPressed: _marcarComoVisto,
                ),
              ],
            ),
            if (_expandido || widget.pasos.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final paso in widget.pasos)
                    Container(
                      constraints: const BoxConstraints(minWidth: 200, maxWidth: 360),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: paleta.superficie,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: paleta.borde),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: paleta.info.withValues(alpha: 0.15),
                            child: Text(
                              '${paso.numero}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: paleta.info,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  paso.titulo,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: paleta.textoPrincipal,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  paso.descripcion,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: paleta.textoSecundario,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _expandido = !_expandido),
                  child: Text(
                    _expandido ? 'Ver menos' : 'Ver pasos detallados',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _marcarComoVisto,
                  child: const Text('Entendido', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
