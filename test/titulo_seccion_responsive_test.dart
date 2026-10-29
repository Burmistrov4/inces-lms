import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inces_lms_app/theme/inces_theme.dart';
import 'package:inces_lms_app/widgets/comunes.dart';

/// Guardia de layout de [TituloSeccion] en pantalla estrecha.
///
/// **Por qué un archivo propio.** `TituloSeccion` lo usan 21 pantallas y **12
/// le pasan `acciones:`**, incluido el encabezado del andamiaje
/// (`andamiaje.dart`) y los dashboards de aspirante y docente. El fallo que
/// estas pruebas fijan no era de una pantalla: era del widget compartido, y
/// por eso un test que montara un panel concreto lo habría dejado pasar en los
/// otros once.
///
/// **El fallo, para que no se reintroduzca.** Las acciones se metían en la
/// `Row` como hijos **no flexibles**, así que se quedaban con su ancho natural
/// mientras el título sí era `Expanded`. A 375 px los botones no cabían y
/// ocurrían dos cosas a la vez: la `Row` desbordaba horizontalmente, y —peor,
/// porque no se ve— el `Expanded` del título se quedaba con ancho cero, así
/// que el subtítulo envolvía una letra por línea y la cabecera terminaba
/// **más alta que la pantalla**. El desborde horizontal tapaba al vertical.
///
/// Medido antes del arreglo: `A RenderFlex overflowed by 175 pixels on the
/// right` (y 1174 px hacia abajo en el panel que lo contenía).
///
/// **Cambio de contrato del 2026-10-29.** En pantalla estrecha el subtítulo ya
/// no se dibuja: se pliega en un icono de información con `Tooltip`. Medido
/// sobre la captura real de 390×844 de «Cursos y PNA», el subtítulo ocupaba
/// **tres líneas (~50 px)** antes del contenido, y el panel arrancaba con el
/// 53 % de la pantalla gastado en cabecera, migas, título y filtros. Las
/// pruebas de abajo fijan el contrato nuevo: **no se pierde información**
/// (sigue en el tooltip) pero deja de costar altura.
void main() {
  const movil = Size(375, 812);
  const escritorio = Size(1440, 900);

  /// Un subtítulo largo **a propósito**: es el que revela el colapso del
  /// `Expanded`. Con un texto corto el fallo no se manifiesta.
  const subtituloLargo =
      'Ocupación de cada sección, ofertas en el aire y acciones de cupo. '
      'Amplía la capacidad antes de «Promover siguiente».';

  Future<void> montar(WidgetTester tester, Size tamano) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: IncesTheme.claro(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: TituloSeccion(
              'Inscripciones y Cupos',
              subtitulo: subtituloLargo,
              acciones: [
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.hourglass_disabled_outlined, size: 17),
                  label: const Text('Expirar ofertas'),
                ),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 17),
                  label: const Text('Reincorporar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('TituloSeccion · acciones en pantalla estrecha', () {
    testWidgets('a 375 px no desborda y el subtítulo se pliega', (tester) async {
      await montar(tester, movil);

      expect(tester.takeException(), isNull,
          reason: 'TituloSeccion desborda a 375 px');

      // El subtítulo deja de ocupar tres líneas...
      expect(
        find.text(subtituloLargo),
        findsNothing,
        reason: 'en estrecho el subtítulo no debe dibujarse como texto',
      );

      // ...pero la explicación NO se pierde: vive en el tooltip del icono.
      final icono = find.byIcon(Icons.info_outline_rounded);
      expect(icono, findsOneWidget);

      final tooltip = tester.widget<Tooltip>(
        find.ancestor(of: icono, matching: find.byType(Tooltip)),
      );
      expect(
        tooltip.message,
        subtituloLargo,
        reason: 'plegar el subtítulo no puede borrarlo: sigue a un toque',
      );

      // Y la cabecera vuelve a ser una franja, no media pantalla.
      final alto = tester.getSize(find.byType(TituloSeccion)).height;
      expect(
        alto,
        lessThan(160),
        reason: 'la cabecera mide $alto px: el subtítulo volvió a ocupar '
            'espacio o el título se quedó sin ancho',
      );
    });

    testWidgets('a 1440 px el subtítulo se lee entero', (tester) async {
      await montar(tester, escritorio);
      expect(tester.takeException(), isNull);
      expect(find.text(subtituloLargo), findsOneWidget);
    });

    testWidgets('a 1440 px no desborda y sigue en una sola fila',
        (tester) async {
      await montar(tester, escritorio);
      expect(tester.takeException(), isNull);

      // En escritorio título y acciones comparten fila: el borde superior de
      // ambas cosas debe estar a la misma altura (±). Si alguien "arreglara"
      // el móvil apilando **siempre**, esto lo delataría como regresión de
      // escritorio.
      final arribaTitulo = tester.getTopLeft(find.text('INSCRIPCIONES Y CUPOS')).dy;
      final arribaBoton = tester.getTopLeft(find.text('Reincorporar')).dy;
      expect(
        (arribaTitulo - arribaBoton).abs(),
        lessThan(24),
        reason: 'en escritorio las acciones deben ir en la misma fila que el '
            'título, no debajo',
      );
    });

    testWidgets('sin acciones no cambia el layout', (tester) async {
      tester.view.physicalSize = movil;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: IncesTheme.claro(),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: TituloSeccion('Solo título'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SOLO TÍTULO'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
