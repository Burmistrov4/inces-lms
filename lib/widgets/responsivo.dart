/// Contrato responsive único, alineado con los **cinco breakpoints canónicos de
/// Material 3** (los mismos que usan las apps de Google).
///
/// **Por qué canónicos y no inventados.** Los umbrales de este archivo antes
/// eran 600/1024/1100, sacados de la práctica común. Funcionaban, pero
/// desalineaban el sistema del estándar con el que se mide cualquier aplicación
/// «responsive» hoy —y con el que el Jefe de Centro comparó la nuestra en la
/// demo del 2026-10-20—. Material 3 corta en cinco, no en tres:
///
/// | Ventana    | Ancho       | Navegación de Google        |
/// |------------|-------------|-----------------------------|
/// | `compact`  | < 600       | barra inferior + cajón      |
/// | `medium`   | 600 – 839   | **navigation rail**         |
/// | `expanded` | 840 – 1199  | menú lateral fijo           |
/// | `large`    | 1200 – 1599 | menú lateral + dos columnas |
/// | `xlarge`   | ≥ 1600      | igual, con ancho máximo      |
///
/// La regla que de verdad importa, y que este archivo existe para hacer cumplir:
/// **ningún widget puede exigir más ancho del que la ventana da sin envolverse
/// en scroll**. Cuando eso ocurre, el navegador escala la página entera —el
/// zoom al 80–90 % que hubo que aplicar en la demo— y el usuario pierde el
/// control del tamaño.
library;

import 'package:flutter/material.dart';

/// Las cinco ventanas canónicas de Material 3.
enum Ventana { compact, medium, expanded, large, xlarge }

/// La ventana que corresponde a un ancho. Es el criterio único: todo lo demás
/// de este archivo se deriva de aquí.
Ventana ventanaDeAncho(double ancho) {
  if (ancho < 600) return Ventana.compact;
  if (ancho < 840) return Ventana.medium;
  if (ancho < 1200) return Ventana.expanded;
  if (ancho < 1600) return Ventana.large;
  return Ventana.xlarge;
}

/// La ventana actual de la aplicación.
Ventana ventanaActual(BuildContext context) =>
    ventanaDeAncho(MediaQuery.sizeOf(context).width);

/// Ancho útil de la ventana.
///
/// Se mide sobre el `MediaQuery` y no sobre `constraints` a propósito: los
/// diálogos y las hojas modales se construyen antes de saber en qué caja van a
/// caer, y para ellos `constraints.maxWidth` miente (mide el diálogo, no la
/// ventana).
double anchoVentana(BuildContext context) => MediaQuery.sizeOf(context).width;

/// Alto útil, con el mismo criterio.
double altoVentana(BuildContext context) => MediaQuery.sizeOf(context).height;

// --- Los cinco predicados, con los umbrales canónicos ----------------------

bool esCompacto(BuildContext context) =>
    ventanaActual(context) == Ventana.compact;
bool esMedio(BuildContext context) => ventanaActual(context) == Ventana.medium;
bool esExpandido(BuildContext context) =>
    ventanaActual(context) == Ventana.expanded;
bool esGrande(BuildContext context) => ventanaActual(context) == Ventana.large;
bool esExtraGrande(BuildContext context) =>
    ventanaActual(context) == Ventana.xlarge;

/// ¿La ventana es al menos `expanded`? Para lo que sólo distingue «móvil» de
/// «escritorio», que es la mayoría de las decisiones.
bool esEscritorio(BuildContext context) {
  final v = ventanaActual(context);
  return v == Ventana.expanded || v == Ventana.large || v == Ventana.xlarge;
}

// --- Clases de ALTURA (Material 3 las define aparte del ancho) --------------
//
// **Por qué existen si casi todo se decide por ancho.** Material 3 clasifica
// ancho y altura por separado, y advierte de un caso que el ancho solo no ve:
// un teléfono en horizontal tiene ancho `medium` (600–839) pero altura
// `compact` (<480). Ahí el doble panel lado a lado no cabe en alto y hay que
// usar hoja inferior o apilar. Ignorarlo es el error clásico de un
// «responsive» que sólo mira el ancho —el mismo tipo de error que el zoom al
// 80–90 % de la demo.
//
// Umbrales canónicos (Android Developers, «Use window size classes»):
//   compact  < 480 · medium 480–899 · expanded ≥ 900

/// Las tres clases de altura de Material 3.
enum VentanaAltura { compacta, media, expandida }

/// La clase de altura que corresponde a un alto.
VentanaAltura alturaDeAlto(double alto) {
  if (alto < 480) return VentanaAltura.compacta;
  if (alto < 900) return VentanaAltura.media;
  return VentanaAltura.expandida;
}

/// La clase de altura actual de la aplicación.
VentanaAltura alturaActual(BuildContext context) =>
    alturaDeAlto(altoVentana(context));

/// ¿La ventana es baja (`compact` de altura, < 480)? Es el caso del teléfono en
/// horizontal, donde un panel lateral no debe robar alto al contenido.
bool esAlturaCompacta(BuildContext context) =>
    alturaActual(context) == VentanaAltura.compacta;

/// ¿Conviene un **doble panel lado a lado**?
///
/// Regla de Material 3: ancho al menos `expanded` (≥ 840) **y** altura al menos
/// `media` (≥ 480). Un teléfono en horizontal (ancho medium, altura compacta)
/// queda fuera a propósito: ahí el panel de apoyo va **debajo** o en **hoja
/// inferior**, no al lado.
///
/// Es distinto de [cabenDosPaneles], que conserva el umbral histórico de
/// 1100 px sin mirar la altura. Para código nuevo, éste es el correcto.
bool cabeDoblePanelLadoALado(BuildContext context) =>
    esEscritorio(context) && !esAlturaCompacta(context);

// --- Compatibilidad con lo que ya usa el sistema ---------------------------

/// **Umbral histórico de «caben dos paneles» (1100 px).**
///
/// Se mantiene con su valor y no se sustituye por `esGrande` (1200) a propósito:
/// cambiaría el comportamiento del panel lateral del gestor de archivos sin
/// haberlo medido en ese rango, y un umbral que ya decide algo no se mueve por
/// alineación estética. Para decidir «¿dos columnas?» en código nuevo, usar
/// [esGrande] o [esEscritorio].
bool cabenDosPaneles(BuildContext context) => anchoVentana(context) >= 1100;

/// Antes se llamaba `esAncho`; su equivalente ahora es [esEscritorio]. Se
/// conserva el nombre para no romper los archivos que ya lo usan mientras se
/// adaptan uno a uno.
bool esAncho(BuildContext context) => esEscritorio(context);

// --- Diálogos ---------------------------------------------------------------

/// Ancho máximo que un diálogo debe ocupar: nunca más del 92 % de la ventana ni
/// más de 560 px (a partir de ahí una fila de formulario pierde
/// escaneabilidad, y 560 es el ancho que los diálogos del sistema ya usaban).
double anchoDialogoSeguro(BuildContext context, double deseado) {
  final topeVentana = anchoVentana(context) * 0.92;
  return deseado < topeVentana ? deseado : topeVentana;
}

/// Envuelve un diálogo para que herede el ancho seguro.
///
/// Uso: sustituir `SizedBox(width: 420, height: 560, child: ...)` por
/// `contenidoDialogoSeguro(context, deseado: 420, alto: 560, child: ...)`.
/// El alto se respeta tal cual (el vertical sigue escrolleando dentro del
/// diálogo); sólo el ancho se acota.
Widget contenidoDialogoSeguro(
  BuildContext context, {
  required double deseado,
  double? alto,
  required Widget child,
}) {
  return SizedBox(
    width: anchoDialogoSeguro(context, deseado),
    height: alto,
    child: child,
  );
}

// --- Rejillas ---------------------------------------------------------------

/// Rejilla cuyo número de columnas se calcula del ancho disponible.
///
/// Sustituye a `GridView.count(crossAxisCount: 3)`: con columnas fijas, una
/// ventana de 390 px reparte tres tarjetas en 130 px cada una y el contenido
/// se ilegibiliza (o el grid desborda y escala la página). Con
/// [SliverGridDelegateWithMaxCrossAxisExtent], cada celda pide [anchoCelda] y
/// Flutter pone tantas columnas como quepan: 3–4 en escritorio, 2 en tableta,
/// 1 en teléfono. Es el comportamiento de las tarjetas de Google Drive.
SliverGridDelegateWithMaxCrossAxisExtent rejillaAdaptable({
  required double anchoCelda,
  double relacionAspecto = 1.0,
}) {
  return SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: anchoCelda,
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: relacionAspecto,
  );
}

/// Número de columnas que caben en [ancho] con celdas de [anchoCelda] como
/// mínimo. Nunca devuelve cero: una columna siempre existe.
int columnasQueCaben(double ancho, double anchoCelda) {
  if (ancho <= 0) return 1;
  final n = (ancho / anchoCelda).floor();
  return n < 1 ? 1 : n;
}

/// Reparte [hijos] en filas con tantas columnas como quepan, pidiendo a cada
/// celda al menos [anchoCelda] px.
///
/// **Qué problema resuelve.** Los tres paneles de resumen repetían el mismo
/// `LayoutBuilder` con umbrales **propios y distintos** (`ancho > 1100 ? 4`,
/// `> 1000 ? 3`, `> 900 ? 2`, `> 640 ? 2`, `> 600 ? 2`). Cinco números que
/// decidían lo mismo en cinco sitios: el síntoma exacto de que no había
/// contrato. Aquí el número de columnas lo decide [columnasQueCaben], que es
/// el único sitio que lo decide, y cada panel sólo aporta su [anchoCelda].
///
/// **Por qué `Wrap` y no `GridView`.** Estas rejillas viven dentro de un
/// `Column` que ya escrollea; un `GridView` sin altura acotada lanzaría
/// «Vertical viewport was given unbounded height». `Wrap` mide a sus hijos y
/// crece, que es justo lo que hace falta.
///
/// En una sola columna (teléfono) devuelve un `Column` con la separación
/// vertical pedida, en vez de un `Wrap` de un elemento por fila: mismo
/// resultado visual, sin el coste de envolver.
Widget rejillaDeTarjetas({
  required List<Widget> hijos,
  required double anchoCelda,
  double separacion = 16,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final ancho = constraints.maxWidth;
      final columnas = columnasQueCaben(ancho, anchoCelda);

      if (columnas <= 1) {
        return Column(
          children: [
            for (var i = 0; i < hijos.length; i++) ...[
              hijos[i],
              if (i < hijos.length - 1) SizedBox(height: separacion),
            ],
          ],
        );
      }

      final anchoHijo = (ancho - (columnas - 1) * separacion) / columnas;
      return Wrap(
        spacing: separacion,
        runSpacing: separacion,
        children: [
          for (final hijo in hijos) SizedBox(width: anchoHijo, child: hijo),
        ],
      );
    },
  );
}

// --- Lectura en pantallas grandes -------------------------------------------

/// Ancho máximo del contenido, el mismo criterio que usa Google.
///
/// **Por qué un máximo.** Estirar una columna de texto o una tabla a 2560 px
/// hace que la línea de lectura sea demasiado larga para el ojo y que la
/// interfaz parezca desparramada. Google centra su contenido en ~1280 px incluso
/// en monitores enormes; es la razón por la que Drive y Gmail se ven «estrechos»
/// en pantalla grande y nadie lo percibe como un defecto.
double get anchoContenidoMax => 1280;

/// Centra el contenido y le pone el ancho máximo de lectura.
///
/// En ventanas pequeñas no hace nada (el contenido ocupa todo el ancho, que es
/// lo correcto). En pantallas grandes, lo mantiene legible y centrado.
Widget contenidoCentrado(Widget hijo) {
  // El tope se escribe como literal y no como `anchoContenidoMax` porque un
  // getter no es expresión constante: el `const` de arriba no compilaría. El
  // valor es el mismo 1280; el getter queda para quien lo necesite fuera de un
  // contexto `const`.
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1280),
      child: hijo,
    ),
  );
}

/// ¿Caben dos columnas (lista + detalle)? Umbral `expanded` de Material 3: por
/// debajo, el panel de detalle roba más de la mitad del ancho útil y la lista
/// sufre.
bool cabenDosColumnas(BuildContext context) => esEscritorio(context);
