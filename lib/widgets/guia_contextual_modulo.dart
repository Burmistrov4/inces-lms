import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/inces_theme.dart';
import 'responsivo.dart';

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

  Future<void> _mostrarGuiaEnBottomSheet(BuildContext context) async {
    final theme = Theme.of(context);
    final paleta = PaletaInces.de(context);
    final esOscuro = theme.brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: paleta.info.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icono, color: paleta.info, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        const SizedBox(height: 6),
                        Text(
                          widget.titulo,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: paleta.textoPrincipal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.subtitulo,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: paleta.textoSecundario,
                  height: 1.4,
                ),
              ),
              if (widget.pasos.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                for (final paso in widget.pasos) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: esOscuro
                          ? paleta.superficieSutil
                          : paleta.superficie,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: paleta.borde),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: paleta.info.withValues(alpha: 0.15),
                          child: Text(
                            '${paso.numero}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: paleta.info,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                paso.titulo,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: paleta.textoPrincipal,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                paso.descripcion,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: paleta.textoSecundario,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  _marcarComoVisto();
                  Navigator.of(ctx).pop();
                },
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text('¡Entendido, gracias!'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_inicializado) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final paleta = PaletaInces.de(context);
    final esOscuro = theme.brightness == Brightness.dark;
    // «Móvil» es la ventana `compact` de Material 3 (< 600). El 768 de antes
    // trataba una tableta de 700 px como móvil y encogía la guía sin necesidad.
    final esMovil = esCompacto(context);

    if (_oculto) {
      // Botón flotante o discreto para consultar la guía nuevamente si se desea
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            ),
            onPressed: () {
              if (esMovil) {
                _mostrarGuiaEnBottomSheet(context);
              } else {
                _reabrirGuia();
              }
            },
            icon: Icon(Icons.help_outline_rounded, size: 15, color: paleta.info),
            label: Text(
              '¿Cómo usar este módulo?',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: paleta.info,
              ),
            ),
          ),
        ),
      );
    }

    // En pantallas angostas (móviles/tablets verticales), la guía debe ser ultra-compacta
    // de una sola línea para no comerse la altura de las tablas y cuadrantes semanales.
    if (esMovil) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: esOscuro
              ? paleta.superficieSutil
              : paleta.info.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(IncesTheme.radioControl),
          border: Border.all(
            color: paleta.info.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(widget.icono, size: 16, color: paleta.info),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: paleta.textoPrincipal,
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              ),
              onPressed: () => _mostrarGuiaEnBottomSheet(context),
              child: const Text('Ver guía', style: TextStyle(fontSize: 11)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.close_rounded, size: 16),
              tooltip: 'Ocultar guía',
              onPressed: _marcarComoVisto,
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            if (_expandido && widget.pasos.isNotEmpty) ...[
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
