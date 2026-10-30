import 'package:flutter/material.dart';

import '../models/cuadrante.dart';
import '../theme/inces_theme.dart';

/// Rejilla de días × bloques, compartida por el cuadrante del administrador y el
/// horario del docente/estudiante.
///
/// Es la misma matriz en los dos sitios —filas = bloques 1–12, columnas = días
/// lunes…sábado— y por eso vive aquí y no duplicada: dos copias de la «misma»
/// rejilla se desvían en cuanto alguien ajusta una (ya pasó con los azules del
/// login). El widget sólo dibuja el esqueleto; el contenido de cada celda lo
/// aporta el panel que lo usa, en forma de *chips*.
///
/// La franja de la tarde (bloques 7–12) se marca con un divisor y un fondo
/// tenue, usando [bloquesDeManana] para no escribir la frontera en dos sitios.
class CuadranteGrid extends StatelessWidget {
  const CuadranteGrid({
    super.key,
    required this.celdas,
    this.onCeldaTap,
    this.diaFiltro,
    this.mostrarSelectorDias = true,
    this.horizontalController,
    this.compacto = false,
  });

  /// **Modo panel-deslizante.** Si es `true`, la rejilla se pinta con altura
  /// natural (sin `Expanded` ni `ListView` propio) para que **el panel completo**
  /// sea el que desliza.
  ///
  /// Existe porque en un teléfono la cabecera del panel —título, selector de
  /// período, botones, guía y fichas de día— se come la pantalla entera: con un
  /// panel rígido (`Column` + `Expanded`) la rejilla recibe altura cero y no hay
  /// nada que arrastrar. Medido en Redmi 10C el 2026-10-30: «no puedes deslizar
  /// ni para arriba ni para abajo». El patrón ya estaba resuelto en Guardias
  /// Docentes, que por eso es el único panel que sí funcionaba en el móvil.
  final bool compacto;

  /// Contenido de cada celda, por clave `'$dia-$bloque'`.
  final Map<String, List<Widget>> celdas;

  /// Controlador de desplazamiento horizontal opcional para navegar entre días.
  final ScrollController? horizontalController;

  /// Acción interactiva al pulsar sobre una celda (ej. celda vacía para asignar clase).
  final void Function(int dia, int bloque)? onCeldaTap;

  /// **Filtro de día.** `null` = toda la semana. Con un día concreto la rejilla
  /// muestra solo ese día (en lista, que se lee mejor que una columna suelta).
  final int? diaFiltro;

  /// Si es `false`, omite el selector interno de chips cuando ya existe un [SelectorDeDias]
  /// externo en el panel, evitando chips de días repetidos.
  final bool mostrarSelectorDias;

  static String clave(int dia, int bloque) => '$dia-$bloque';

  /// Ancho de la columna de bloques («B1 / 7:00») de la tabla.
  static const double anchoGutter = 116;

  /// Ancho mínimo con el que una columna de día se lee sin apretarse.
  static const double anchoMinimoDia = 140;

  /// Tope de ancho de columna: más ancho desperdicia y desalinea la lectura.
  static const double anchoMaximoDia = 168;

  /// ¿La semana cabe como tabla con [anchoDisponible] y [dias] columnas?
  ///
  /// Es la pregunta que decide la FORMA, y por eso vive aquí y no duplicada en
  /// cada panel: si el panel pinta controles de desplazamiento horizontal, tiene
  /// que saber si hay tabla que desplazar. Medido el 2026-10-29: a 390 px la
  /// tabla necesita 116 + 6·140 = 956 px, así que arrastrar era la única forma
  /// de ver el jueves y el resto —«el cuadrante no se puede usar en el teléfono»
  /// (N2)—. Un día suelto tampoco cuenta como tabla: una columna sola se lee
  /// peor que la lista de bloques.
  static bool cabeComoTabla(double anchoDisponible, int dias) {
    if (dias <= 1) return false;
    return (anchoDisponible - anchoGutter) / dias >= anchoMinimoDia;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // **Filtro de dia:** null = semana completa; un numero = solo ese dia.
    final dias = diaFiltro == null
        ? [for (var d = 1; d <= diaMaximo; d++) d]
        : [diaFiltro!];
    final bloques = [for (var b = 1; b <= bloqueMaximo; b++) b];

    final borde = theme.colorScheme.outline.withValues(alpha: 0.25);

    final hijos = <TableRow>[
      TableRow(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        ),
        children: [
          const _CeldaCabecera(texto: 'Bloque / Hora'),
          for (final dia in dias)
            _CeldaCabecera(texto: diasDeLaSemana[dia]),
        ],
      ),
      for (final bloque in bloques)
        TableRow(
          decoration: bloque > bloquesDeManana
              ? BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer
                      .withValues(alpha: bloque % 2 == 0 ? 0.22 : 0.14),
                )
              : (bloque % 2 == 0
                  ? BoxDecoration(
                      color:
                          theme.colorScheme.primary.withValues(alpha: 0.04),
                    )
                  : null),
          children: [
            _CeldaGutter(bloque: bloque),
            for (final dia in dias)
              _CeldaContenido(
                hijos: celdas[clave(dia, bloque)] ?? const [],
                esDivisorTurno: bloque == bloquesDeManana + 1,
                borde: borde,
                onTap: onCeldaTap != null ? () => onCeldaTap!(dia, bloque) : null,
              ),
          ],
        ),
    ];

    // **B5 — dos formas, no una tabla estirada.** Medido el 2026-10-22: la
    // rejilla fija (116 + 6x168 = 1124 px) desbordaba 750 px a 390 y 136 px a
    // 1280. Por debajo de 1200 px se muestra **selector de dia + lista
    // vertical** (lo que cabe en un telefono); desde 1200, la tabla con ancho
    // de columna adaptativo, que cabe sin scroll horizontal.
    return LayoutBuilder(
      builder: (context, restricciones) {
        final anchoDia = ((restricciones.maxWidth - anchoGutter) / dias.length)
            .clamp(anchoMinimoDia, anchoMaximoDia)
            .toDouble();

        // **La forma la decide el ancho, no la plataforma.** Por debajo del
        // mínimo legible se pinta selector de día + lista de bloques (lo que
        // cabe en un teléfono); a partir de ahí, la tabla con columnas
        // adaptativas, que ya no necesita arrastrar.
        //
        // Antes sólo se cambiaba de forma si se había filtrado a un día, así que
        // con «Todo» seleccionado en un 390 el usuario recibía una tabla de
        // 956 px dentro de una pantalla de 390: se veían lunes y martes y el
        // resto quedaba a dos arrastres —lo que el usuario describió como «hay
        // que usar la computadora»—.
        if (!cabeComoTabla(restricciones.maxWidth, dias.length)) {
          return _CuadrantePorDia(
            celdas: celdas,
            dias: dias,
            onCeldaTap: onCeldaTap,
            // Si el panel ya pinta su `SelectorDeDias`, dos filas de fichas
            // idénticas confunden más que ayudan.
            mostrarSelectorDias: mostrarSelectorDias && dias.length > 1,
            compacto: compacto,
          );
        }
        return Scrollbar(
          controller: horizontalController,
          thumbVisibility: dias.length > 3,
          child: SingleChildScrollView(
            controller: horizontalController,
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: Table(
                border: TableBorder.all(color: borde, width: 1),
                defaultColumnWidth: FixedColumnWidth(anchoDia),
                columnWidths: const {
                  0: FixedColumnWidth(anchoGutter),
                },
                children: hijos,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Cabecera de día o de la columna de bloques.
class _CeldaCabecera extends StatelessWidget {
  const _CeldaCabecera({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 38,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        texto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Gutter izquierdo: número de bloque, con el turno en el primero de cada franja.
class _CeldaGutter extends StatelessWidget {
  const _CeldaGutter({required this.bloque});

  final int bloque;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final turno = turnoDeBloque(bloque);
    final hora = horaConMeridianoDeBloque(bloque);
    final esManana = turno == Turno.manana;
    final colorTurno = esManana ? theme.colorScheme.primary : theme.colorScheme.tertiary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: colorTurno.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'B$bloque',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorTurno,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  turno.etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: colorTurno,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          // La franja horaria se encoge si no cabe, en vez de desbordar.
          // Medido el 2026-10-29: al añadir el meridiano («01:00 - 01:45 p. m.»)
          // la columna de bloques del modo lista desbordaba 3,2 px a 360 y el
          // `Row` de arriba se pintaba con la franja amarilla de error.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              hora,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CeldaContenido extends StatelessWidget {
  const _CeldaContenido({
    required this.hijos,
    this.esDivisorTurno = false,
    required this.borde,
    this.onTap,
  });

  final List<Widget> hijos;
  final bool esDivisorTurno;
  final Color borde;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contenedor = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.all(5),
      // El divisor de turno es un realce visual, no una regla nueva: separa la
      // mañana de la tarde sin que el usuario tenga que contar bloques.
      decoration: esDivisorTurno
          ? BoxDecoration(
              border: Border(top: BorderSide(color: borde, width: 2)),
            )
          : null,
      child: hijos.isEmpty
          ? (onTap != null
              ? Center(
                  child: Tooltip(
                    message: 'Toca para asignar una clase en este bloque',
                    child: Icon(
                      Icons.add_rounded,
                      // El icono ocupa lo que la celda: a 16 px y con alfa 0.28
                      // parecía una celda muerta y no un botón — reportado el
                      // 2026-10-30: «el botón de más no es inteligente, no ocupa
                      // todo el espacio que debería». El área táctil ya era toda
                      // la celda (el InkWell la envuelve); lo que no se veía era
                      // la invitación.
                      size: 22,
                      color: theme.colorScheme.primary.withValues(alpha: 0.45),
                    ),
                  ),
                )
              : const SizedBox.shrink())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < hijos.length; i++) ...[
                  if (i > 0) const SizedBox(height: 4),
                  hijos[i],
                ],
              ],
            ),
    );

    if (onTap == null || hijos.isNotEmpty) {
      return contenedor;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      hoverColor: theme.colorScheme.primary.withValues(alpha: 0.08),
      child: contenedor,
    );
  }
}

/// Paleta armónica e institucional para diferenciar espacios físicos (aulas, talleres)
/// y guardias en el cuadrante y horarios.
class PaletaAulasCuadrante {
  const PaletaAulasCuadrante._();

  /// Doce colores armoniosos para aulas y talleres, legibles en temas claro y oscuro.
  static const List<Color> colores = IncesTheme.coloresAulasCuadrante;

  /// Color distintivo para las guardias docentes (custodia y presencia institucional).
  static const Color colorGuardia = IncesTheme.colorGuardiaCuadrante;

  /// Obtiene el color correspondiente a un identificador o nombre de aula.
  static Color colorParaAula(String? aulaId) {
    final idx = indiceColorDeAula(aulaId);
    return colores[idx];
  }
}

/// Chip de una celda: una clase o una guardia.
///
/// `destacado` lo usa la clase (llena el aula de la que es dueña); la guardia va
/// sin fondo para distinguirse a la vista. El `onTap` es opcional: las guardias
/// en el cuadrante son de sólo lectura (se editan en su propio panel), y un chip
/// sin `onTap` se pinta como una tarjeta muda.
class ChipCuadrante extends StatelessWidget {
  const ChipCuadrante({
    super.key,
    required this.titulo,
    required this.subtitulo,
    this.color,
    this.etiquetaAula,
    this.esGuardia = false,
    this.destacado = false,
    this.onTap,
  });

  final String titulo;
  final String subtitulo;
  final Color? color;
  final String? etiquetaAula;
  final bool esGuardia;
  final bool destacado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;
    final acento = color ??
        (esGuardia
            ? PaletaAulasCuadrante.colorGuardia
            : theme.colorScheme.primary);

    final contenido = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (esGuardia) ...[
                Icon(
                  Icons.shield_outlined,
                  size: 13,
                  color: acento,
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            subtitulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (etiquetaAula != null && etiquetaAula!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: acento.withValues(alpha: esOscuro ? 0.28 : 0.16),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                etiquetaAula!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: acento,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    final tarjeta = Container(
      decoration: BoxDecoration(
        color: destacado
            ? acento.withValues(alpha: esOscuro ? 0.18 : 0.08)
            : (esGuardia
                ? acento.withValues(alpha: esOscuro ? 0.10 : 0.04)
                : null),
        border: Border.all(
          color: destacado
              ? acento.withValues(alpha: esOscuro ? 0.65 : 0.45)
              : (esGuardia
                  ? acento.withValues(alpha: esOscuro ? 0.45 : 0.30)
                  : bordeSuave(theme)),
          width: destacado ? 1.4 : 1.0,
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3.5,
              decoration: BoxDecoration(
                color: acento,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(7),
                  bottomLeft: Radius.circular(7),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 3.5),
            child: contenido,
          ),
        ],
      ),
    );

    if (onTap == null) return tarjeta;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: tarjeta,
      ),
    );
  }

  static Color bordeSuave(ThemeData theme) =>
      theme.colorScheme.outline.withValues(alpha: 0.35);
}

/// Agrupa las clases por celda para alimentar a [CuadranteGrid].
Map<String, List<Widget>> agruparClases(
  List<ClaseCuadrante> clases, {
  required Widget Function(ClaseCuadrante) chip,
}) {
  final mapa = <String, List<Widget>>{};
  for (final clase in clases) {
    final clave = CuadranteGrid.clave(clase.dia, clase.bloque);
    (mapa[clave] ??= []).add(chip(clase));
  }
  return mapa;
}

/// Agrupa las guardias por celda para alimentar a [CuadranteGrid].
Map<String, List<Widget>> agruparGuardias(
  List<Guardia> guardias, {
  required Widget Function(Guardia) chip,
}) {
  final mapa = <String, List<Widget>>{};
  for (final guardia in guardias) {
    final clave = CuadranteGrid.clave(guardia.dia, guardia.bloque);
    (mapa[clave] ??= []).add(chip(guardia));
  }
  return mapa;
}


/// **B5 — la rejilla en vertical, para pantallas estrechas.**
///
/// Medido el 2026-10-22: la tabla de dias x bloques (1124 px fijos) desbordaba
/// 750 px a 390 y obligaba a arrastrar en un telefono. En vez de estirar una
/// tabla, se cambia de forma: **selector de dia** y los 12 bloques de ese dia
/// en una lista vertical. Es el patron que usa Google en Calendario/Classroom
/// en movil.
class _CuadrantePorDia extends StatefulWidget {
  const _CuadrantePorDia({
    required this.celdas,
    required this.dias,
    this.onCeldaTap,
    this.mostrarSelectorDias = true,
    this.compacto = false,
  });

  /// Contenido de cada celda, por clave '$dia-$bloque'.
  final Map<String, List<Widget>> celdas;

  /// Dias a mostrar. Con mas de uno se pintan las fichas para elegir.
  final List<int> dias;

  final void Function(int dia, int bloque)? onCeldaTap;

  final bool mostrarSelectorDias;

  /// Altura natural en vez de lista con scroll propio (ver `CuadranteGrid.compacto`).
  final bool compacto;

  @override
  State<_CuadrantePorDia> createState() => _CuadrantePorDiaState();
}

class _CuadrantePorDiaState extends State<_CuadrantePorDia> {
  late int _dia;

  @override
  void initState() {
    super.initState();
    _dia = _primerDiaConContenido();
  }

  int _primerDiaConContenido() {
    for (final d in widget.dias) {
      for (var b = 1; b <= bloqueMaximo; b++) {
        if ((widget.celdas[CuadranteGrid.clave(d, b)] ?? const []).isNotEmpty) {
          return d;
        }
      }
    }
    return widget.dias.first;
  }

  bool _tieneContenido(int dia) {
    for (var b = 1; b <= bloqueMaximo; b++) {
      if ((widget.celdas[CuadranteGrid.clave(dia, b)] ?? const []).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borde = theme.colorScheme.outline.withValues(alpha: 0.25);

    // Cuando no se muestra el selector interno y hay varios días (modo 'Todo' sin duplicar filtros),
    // desplegamos todos los días secuencialmente con un separador claro.
    final mostrarTodosSecuenciales = !widget.mostrarSelectorDias && widget.dias.length > 1;

    // Las filas se construyen aparte porque sirven a las dos formas: `ListView`
    // (scroll propio) o `Column` de altura natural (`compacto`).
    final filas = <Widget>[
      if (mostrarTodosSecuenciales)
        for (final dia in widget.dias) ...[
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borde),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  diasDeLaSemana[dia],
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          for (var bloque = 1; bloque <= bloqueMaximo; bloque++)
            _filaBloque(theme, borde, dia, bloque),
        ]
      else
        for (var bloque = 1; bloque <= bloqueMaximo; bloque++)
          _filaBloque(theme, borde, widget.dias.length == 1 ? widget.dias.first : _dia, bloque),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.mostrarSelectorDias && widget.dias.length > 1) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final dia in widget.dias)
                ChoiceChip(
                  label: Text(diasDeLaSemana[dia]),
                  selected: dia == _dia,
                  onSelected: (_) => setState(() => _dia = dia),
                  avatar: _tieneContenido(dia) && dia != _dia
                      ? Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        // Bloques: lista con scroll propio, o columna de altura natural cuando
        // el panel entero es el que desliza (`compacto`).
        if (widget.compacto)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: filas,
          )
        else
          Expanded(
            child: ListView(children: filas),
          ),
      ],
    );
  }

  Widget _filaBloque(ThemeData theme, Color borde, int dia, int bloque) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borde)),
        color: bloque > bloquesDeManana
            ? theme.colorScheme.tertiaryContainer
                .withValues(alpha: bloque % 2 == 0 ? 0.22 : 0.14)
            : (bloque % 2 == 0
                ? theme.colorScheme.primary.withValues(alpha: 0.04)
                : null),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: CuadranteGrid.anchoGutter,
            child: _CeldaGutter(bloque: bloque),
          ),
          Expanded(
            child: InkWell(
              onTap: widget.onCeldaTap != null
                  ? () => widget.onCeldaTap!(dia, bloque)
                  : null,
              child: Container(
                constraints: const BoxConstraints(minHeight: 60),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _contenido(dia, bloque),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _contenido(int dia, int bloque) {
    final hijos =
        widget.celdas[CuadranteGrid.clave(dia, bloque)] ?? const <Widget>[];
    if (hijos.isEmpty) {
      return [
        Text(
          'Libre',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ];
    }
    return hijos;
  }
}

/// **Filtro de día (Todo | Lun…Sáb), compartido por Horarios y Guardias.**
///
/// Medido el 2026-10-22: en Guardias no había forma de ver un solo día (solo
/// «Lun–Vie / Lun–Sáb») y en Horarios el selector sólo aparecía en móvil. Este
/// control es el mismo en los dos paneles: `Todo` muestra la semana completa y
/// un día concreto enfoca ese día. El punto marca los días que tienen contenido.
class SelectorDeDias extends StatelessWidget {
  const SelectorDeDias({
    super.key,
    required this.seleccionado,
    required this.onCambio,
    this.diasConContenido = const {},
  });

  /// `null` = toda la semana.
  final int? seleccionado;

  final ValueChanged<int?> onCambio;

  /// Días que tienen al menos una clase o guardia (para el punto).
  final Set<int> diasConContenido;

  static const _cortos = <int, String>{
    1: 'Lun',
    2: 'Mar',
    3: 'Mié',
    4: 'Jue',
    5: 'Vie',
    6: 'Sáb',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget ficha(String etiqueta, int? dia) {
      final activo = seleccionado == dia;
      final tiene = dia != null && diasConContenido.contains(dia);
      return ChoiceChip(
        label: Text(etiqueta),
        selected: activo,
        onSelected: (_) => onCambio(dia),
        avatar: tiene && !activo
            ? Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ficha('Todo', null),
        for (var d = 1; d <= diaMaximo; d++) ficha(_cortos[d] ?? 'D$d', d),
      ],
    );
  }
}
