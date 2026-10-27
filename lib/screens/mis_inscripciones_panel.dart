import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/result.dart';
import '../models/inscripcion.dart';
import '../repositories/inscripcion_repository.dart';
import '../theme/inces_theme.dart';
import '../widgets/andamiaje.dart';
import '../widgets/comunes.dart';

/// «Mis inscripciones» del estudiante — Módulo 4, capa estudiante.
///
/// **Qué muestra.** Una tarjeta por inscripción, con su estado en el ciclo de
/// cupos del backend: `ENROLLED` (con asiento), `PENDING_BID` (el sistema le
/// ofreció un cupo y espera respuesta), `WAITLISTED` (en la cola, con su
/// posición) y `DROPPED` (renunció; la fila se conserva como historial).
///
/// **El código de color no es decorativo: es la jerarquía de urgencia.** Un
/// estado que exige una acción **con fecha límite** tiene que gritar; uno que
/// sólo informa tiene que callar. Por eso:
///
///   · `PENDING_BID` → **ámbar** (`PaletaInces.advertencia`). Es el único estado
///     que caduca: si el alumno no lo ve, pierde el cupo y vuelve a la cola.
///   · `ENROLLED` → **verde** (`PaletaInces.exito`). Resuelto, nada que hacer.
///   · `WAITLISTED` → **azul** (`PaletaInces.info`). Espera informativa: hay una
///     posición, pero no hay nada que pulsar salvo renunciar.
///   · `DROPPED` → **gris** (`ColorScheme.onSurfaceVariant`). Historial apagado.
///
/// Los tres acentos de estado son los de `PaletaInces` y **no** los de
/// `IncesTheme` porque el chip los pinta como letra sobre su propio tinte, y ahí
/// los colores de relleno no llegan a AA en ninguno de los dos brillos. Medido el
/// 2026-09-30: verde 2.65:1 en claro, ámbar 1.81:1 en claro, azul 2.54:1 en
/// oscuro.
///
/// **Por qué los colores estaban al revés, y qué costaba.** La versión anterior
/// pintaba `WAITLISTED` en ámbar y `PENDING_BID` en azul: el estado pasivo
/// gritaba y el urgente susurraba. No rompía ninguna prueba —ninguna afirmaba
/// sobre el color— pero es exactamente el fallo que cuesta un cupo, porque el
/// alumno que mira la lista no ve cuál de las filas le está pidiendo algo.
///
/// **El orden también es urgencia.** [_ordenadas] pone primero lo que exige
/// acción, y no el orden que devuelva el servidor.
///
/// **Por qué vive en su propio archivo.** El panel del estudiante
/// (`aspirante_dashboard.dart`) es navegación: un menú, un `switch` por título y
/// el cableado de cada sección. Este panel es la lógica de un ciclo de estados
/// con cuenta regresiva, acciones en vuelo y orden por urgencia. Estaban en el
/// mismo archivo y crecían por razones distintas.
class PanelMisInscripciones extends StatefulWidget {
  const PanelMisInscripciones({super.key, required this.repositorio});

  final InscripcionesRepository repositorio;

  @override
  State<PanelMisInscripciones> createState() => _PanelMisInscripcionesState();
}

class _PanelMisInscripcionesState extends State<PanelMisInscripciones> {
  bool _cargando = true;
  String? _error;
  List<InscripcionDetallada> _inscripciones = const [];

  /// Secciones con una acción en vuelo (renunciar).
  final Set<String> _actuando = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    final resultado = await widget.repositorio.obtenerMisInscripciones();
    if (!mounted) return;

    setState(() {
      _cargando = false;
      switch (resultado) {
        case Success(value: final lista):
          _inscripciones = lista;
        case Failure(error: final fallo):
          _error = fallo.message;
      }
    });
  }

  Future<void> _renunciar(InscripcionDetallada i) async {
    setState(() => _actuando.add(i.seccionId));
    final resultado = await widget.repositorio.renunciar(i.seccionId);
    if (!mounted) return;
    setState(() => _actuando.remove(i.seccionId));

    resultado.when(
      success: (_) {
        mostrarAviso(context, 'Renunciaste a este cupo.', exito: true);
        _cargar();
      },
      failure: (fallo) => mostrarAviso(context, fallo.message, error: true),
    );
  }

  /// Las inscripciones ordenadas por estado (ENROLLED, WAITLISTED, DROPPED).
  List<InscripcionDetallada> get _ordenadas {
    final conIndice = _inscripciones.indexed.toList();

    conIndice.sort((a, b) {
      final porUrgencia = _urgencia(a.$2.estado).compareTo(_urgencia(b.$2.estado));
      return porUrgencia != 0 ? porUrgencia : a.$1.compareTo(b.$1);
    });

    return [for (final (_, inscripcion) in conIndice) inscripcion];
  }

  static int _urgencia(EstadoInscripcion estado) => switch (estado) {
        EstadoInscripcion.enrolled => 0,
        EstadoInscripcion.waitlisted => 1,
        EstadoInscripcion.dropped => 2,
      };

  @override
  Widget build(BuildContext context) {
    return ContenidoSeccion(
      migas: const ['Inicio', 'Académico', 'Mis inscripciones'],
      // `EstadoPanel` es el manejo de error del proyecto: mientras carga, un
      // indicador; si falló, «No pudimos cargar esta sección» con un botón
      // «Reintentar»; y nunca una pantalla roja. El mensaje del fallo es el que
      // dio el backend, no un texto genérico.
      child: EstadoPanel(
        cargando: _cargando,
        error: _error,
        onReintentar: _cargar,
        child: _contenido(),
      ),
    );
  }

  Widget _contenido() {
    if (_inscripciones.isEmpty) {
      return const PanelVacio(
        titulo: 'Aún no tienes inscripciones',
        mensaje:
            'Cuando solicites un cupo —o el sistema te asigne uno desde la '
            'lista de espera— lo verás aquí, con su estado en tiempo real.',
        icono: Icons.playlist_add_check_outlined,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloSeccion(
          'Mis inscripciones',
          subtitulo:
              '${plural(_inscripciones.length, 'inscripción', 'inscripciones')}.',
          acciones: [
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _cargando ? null : _cargar,
              icon: const Icon(Icons.refresh_rounded, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // `Flexible` y no el scroll suelto. **En un `Column`, un hijo no
        // flexible recibe la altura del eje principal como *ilimitada***, así
        // que el `SingleChildScrollView` se dimensionaba a su contenido entero
        // en vez de a lo que sobra, y desbordaba el alto acotado que le entrega
        // `ContenidoSeccion`. Con `Flexible` (ajuste holgado, no `Expanded`)
        // recibe la altura restante y desplaza dentro.
        //
        // Medido: dos tarjetas más el aviso de cabecera desbordaban **52 px** a
        // 800×600. Lo destaparon —de rebote— las dos pruebas de urgencia, que
        // montan dos inscripciones; las de una sola pasaban. El aviso de
        // cabecera que se añadió arriba fue lo que terminó de desbordar una
        // estructura que ya estaba al límite.
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final i in _ordenadas) _tarjetaInscripcion(i),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tarjetaInscripcion(InscripcionDetallada i) {
    final theme = Theme.of(context);
    final ocupado = _actuando.contains(i.seccionId);
    final titulo = (i.materiaNombre ?? i.seccionNombre)
        .replaceAll(RegExp(r'\s*\[SEMILLA\]\s*', caseSensitive: false), '')
        .trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (i.programaNombre != null)
                            i.programaNombre!
                                .replaceAll(
                                  RegExp(r'\s*\[SEMILLA\]\s*', caseSensitive: false),
                                  '',
                                )
                                .trim(),
                          i.periodo
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _InsigniaEstado(i.estado),
              ],
            ),
            const SizedBox(height: 12),

            // Contexto y acciones específicos de cada estado.
            if (i.estado.enCola) ...[
              if (i.posicionEnCola != null)
                Etiqueta(texto: 'Lugar ${i.posicionEnCola} en la cola')
              else
                const Etiqueta(texto: 'En lista de espera'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: ocupado ? null : () => _renunciar(i),
                  icon: ocupado
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.exit_to_app_outlined, size: 16),
                  label: Text(ocupado ? 'Renunciando…' : 'Renunciar'),
                ),
              ),
            ] else if (i.estado.estaAdentro) ...[
              const AvisoEnLinea(
                texto: 'Tienes tu asiento confirmado en esta sección.',
                icono: Icons.check_circle_outline,
                tono: TonoAviso.exito,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: ocupado ? null : () => _renunciar(i),
                  icon: ocupado
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.exit_to_app_outlined, size: 16),
                  label: Text(ocupado ? 'Renunciando…' : 'Renunciar'),
                ),
              ),
            ] else ...[
              // DROPPED: se conserva la fila como historial, sin acción.
              const AvisoEnLinea(
                texto: 'Renunciaste a este cupo. La fila se conserva como historial.',
                icono: Icons.info_outline,
                tono: TonoAviso.info,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Insignia de color del estado de una inscripción.
class _InsigniaEstado extends StatelessWidget {
  const _InsigniaEstado(this.estado);

  final EstadoInscripcion estado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paleta = PaletaInces.de(context);
    final (color, texto, icono) = switch (estado) {
      EstadoInscripcion.enrolled =>
        (paleta.exito, 'Matriculado', Icons.check_circle_outline),
      EstadoInscripcion.waitlisted =>
        (paleta.info, 'En cola', Icons.people_outline),
      EstadoInscripcion.dropped => (
        theme.colorScheme.onSurfaceVariant,
        'Renunciado',
        Icons.do_not_disturb_on_outlined,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            texto,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
