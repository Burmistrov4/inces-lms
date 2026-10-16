import 'package:flutter/material.dart';

import '../models/cuadrante.dart';

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
  });

  /// Contenido de cada celda, por clave `'$dia-$bloque'`.
  final Map<String, List<Widget>> celdas;

  /// Acción interactiva al pulsar sobre una celda (ej. celda vacía para asignar clase).
  final void Function(int dia, int bloque)? onCeldaTap;

  static String clave(int dia, int bloque) => '$dia-$bloque';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dias = [for (var d = 1; d <= diaMaximo; d++) d];
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Table(
          border: TableBorder.all(color: borde, width: 1),
          defaultColumnWidth: const FixedColumnWidth(168),
          columnWidths: const {
            0: FixedColumnWidth(116),
          },
          children: hijos,
        ),
      ),
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
    final hora = horaLegibleDeBloque(bloque);
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
              Text(
                turno.etiqueta,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: colorTurno,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            hora,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.2,
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
                    message: 'Clic para asignar clase aquí',
                    child: Icon(
                      Icons.add_circle_outline_rounded,
                      size: 16,
                      color: theme.colorScheme.primary.withValues(alpha: 0.28),
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
  static const List<Color> colores = [
    Color(0xFF0284C7), // Azul Primario INCES (Taller Soldadura 1)
    Color(0xFF0D9488), // Verde Azulado / Teal (Taller Mecánica)
    Color(0xFFD97706), // Ámbar / Ocre Técnico (Aula Teórica A1)
    Color(0xFF7C3AED), // Violeta / Púrpura (Laboratorio Computación)
    Color(0xFF059669), // Esmeralda Formativo (Aula Magna)
    Color(0xFFEA580C), // Naranja Industrial (Taller Metalmecánico)
    Color(0xFF4F46E5), // Índigo Metalúrgico (Laboratorio Ensayos)
    Color(0xFFDB2777), // Magenta / Rosa Técnico (Aula B2)
    Color(0xFF0891B2), // Cian CFS (Taller Soldadura 2)
    Color(0xFF65A30D), // Lima Formación (Aula C1)
    Color(0xFF9333EA), // Púrpura Institucional (Aula D1)
    Color(0xFF2563EB), // Azul Real (Taller Electricidad)
  ];

  /// Color distintivo para las guardias docentes (custodia y presencia institucional).
  static const Color colorGuardia = Color(0xFF6366F1);

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
