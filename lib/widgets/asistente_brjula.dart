import 'package:flutter/material.dart';

import '../core/ayuda/brjula_conocimiento.dart';

/// **Brújula** — el asistente del INCES LMS.
///
/// Aparece como un botón flotante en todas las pantallas y se abre en una hoja
/// que no estorba: pregunta, responde en dos frases y, cuando hay una pantalla
/// concreta, la abre con un botón. Se cierra con la X, con el fondo o con Escape.
///
/// **Por qué no estorba.** En móvil ocupa el ancho completo y se puede arrastrar
/// hacia abajo; en escritorio es una tarjeta de 520 px. El botón es pequeño y
/// discreto a propósito: la aplicación debería explicarse sola, y Brújula es la
/// red de seguridad, no la interfaz.
class AsistenteBrujula extends StatefulWidget {
  const AsistenteBrujula({
    super.key,
    required this.rol,
    this.onNavegar,
    this.etiquetaRol,
  });

  /// `admin`, `docente` o `aspirante`/`estudiante`. Decide qué respuestas se
  /// ofrecen: al aprendiz no se le explica cómo cerrar un período.
  final String rol;

  /// Abre una sección por su título exacto, el mismo que usa el menú.
  final void Function(String tituloSeccion)? onNavegar;

  /// Nombre legible del perfil, para el saludo.
  final String? etiquetaRol;

  @override
  State<AsistenteBrujula> createState() => _AsistenteBrujulaState();
}

class _AsistenteBrujulaState extends State<AsistenteBrujula> {
  final TextEditingController _consulta = TextEditingController();
  List<EntradaAyuda> _resultados = const [];

  List<EntradaAyuda> get _disponibles => brjulaConocimiento
      .where((e) => e.sirvePara(widget.rol))
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _resultados = _disponibles;
  }

  @override
  void dispose() {
    _consulta.dispose();
    super.dispose();
  }

  /// Puntúa por coincidencia de palabras. Se queda con lo que puntúa > 0 y, si
  /// nada coincide, **no inventa**: devuelve vacío y la hoja lo dice.
  void _buscar(String texto) {
    final q = normalizar(texto);
    if (q.isEmpty) {
      setState(() => _resultados = _disponibles);
      return;
    }

    final palabras = q.split(' ').where((p) => p.length > 2).toList();
    final puntuadas = <(int, EntradaAyuda)>[];

    for (final e in _disponibles) {
      var puntos = 0;
      final titulo = normalizar(e.titulo);
      final claves = e.claves.map(normalizar).toList();

      for (final p in palabras) {
        if (titulo.contains(p)) puntos += 3;
        for (final c in claves) {
          if (c == p) {
            puntos += 3;
          } else if (c.contains(p)) {
            puntos += 2;
          }
        }
      }
      if (puntos > 0) puntuadas.add((puntos, e));
    }

    puntuadas.sort((a, b) => b.$1.compareTo(a.$1));
    setState(() => _resultados = puntuadas.map((p) => p.$2).toList());
  }

  void _abrir(EntradaAyuda entrada) {
    Navigator.of(context).pop();
    final destino = entrada.destino;
    if (destino != null) widget.onNavegar?.call(destino);
  }

  void _abrirHoja() {
    _consulta.clear();
    _resultados = _disponibles;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setEstadoHoja) {
          final alto = MediaQuery.of(ctx).size.height;
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: alto * 0.82),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const _IconoBrujula(),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Brújula',
                                  style: Theme.of(ctx).textTheme.titleMedium,
                                ),
                                Text(
                                  'Te llevo a donde necesites${widget.etiquetaRol != null ? ' · ${widget.etiquetaRol}' : ''}',
                                  style: Theme.of(ctx).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _consulta,
                        autofocus: true,
                        onChanged: (v) {
                          _buscar(v);
                          setEstadoHoja(() {});
                        },
                        decoration: const InputDecoration(
                          hintText: '¿Qué quieres hacer?',
                          prefixIcon: Icon(Icons.search_rounded, size: 18),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Flexible(
                        child: _resultados.isEmpty
                            ? _SinRespuesta(consulta: _consulta.text)
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: _resultados.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final e = _resultados[i];
                                  return _TarjetaAyuda(
                                    entrada: e,
                                    onAbrir: () => _abrir(e),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      // Discreto: la app debe explicarse sola; esto es la red de seguridad.
      tooltip: 'Brújula · ayuda',
      heroTag: 'brjula-${widget.rol}',
      onPressed: _abrirHoja,
      child: const Icon(Icons.explore_outlined, size: 20),
    );
  }
}

class _IconoBrujula extends StatelessWidget {
  const _IconoBrujula();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: tema.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.explore_outlined,
        size: 19,
        color: tema.colorScheme.primary,
      ),
    );
  }
}

class _TarjetaAyuda extends StatelessWidget {
  const _TarjetaAyuda({required this.entrada, required this.onAbrir});

  final EntradaAyuda entrada;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final tieneDestino = entrada.destino != null;

    return Container(
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tema.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entrada.titulo,
            style: tema.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            entrada.respuesta,
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          if (tieneDestino) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: onAbrir,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text('Ir a ${entrada.destino}'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Cuando no hay coincidencia, se dice. Inventar un módulo que no existe es la
/// forma más rápida de que alguien pierda cinco minutos buscándolo.
class _SinRespuesta extends StatelessWidget {
  const _SinRespuesta({required this.consulta});

  final String consulta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.help_outline_rounded,
            size: 28,
            color: tema.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'No tengo una respuesta para «${consulta.trim()}».',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Prueba con «horario», «tarea», «notas», «inscripción» o «aula». '
            'Si tampoco, pregunta en administración.',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
