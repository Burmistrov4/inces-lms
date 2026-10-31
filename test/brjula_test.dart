import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inces_lms_app/core/ayuda/brjula_conocimiento.dart';
import 'package:inces_lms_app/widgets/asistente_brjula.dart';

/// **Brújula** tiene que responder breve, llevar a un sitio que existe y no
/// romperse en un teléfono.
void main() {
  Widget montar({String rol = 'admin', Size tamano = const Size(1280, 800)}) {
    return MediaQuery(
      data: MediaQueryData(size: tamano),
      child: MaterialApp(
        home: Scaffold(
          body: const SizedBox.shrink(),
          floatingActionButton: AsistenteBrujula(rol: rol),
        ),
      ),
    );
  }

  testWidgets('el botón abre y busca respuestas', (tester) async {
    await tester.pumpWidget(montar());
    expect(find.byType(AsistenteBrujula), findsOneWidget);

    await tester.tap(find.byTooltip('Brújula · ayuda'));
    await tester.pumpAndSettle();

    expect(find.text('Brújula'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'horario');
    await tester.pumpAndSettle();

    // «Asignar una clase en el horario» y «Ver mi horario» contienen horario.
    expect(find.textContaining('horario', findRichText: true), findsWidgets);
  });

  testWidgets('no inventa: sin coincidencia lo dice', (tester) async {
    await tester.pumpWidget(montar());
    await tester.tap(find.byTooltip('Brújula · ayuda'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'xyzzy qwerty');
    await tester.pumpAndSettle();

    expect(find.textContaining('No tengo una respuesta'), findsOneWidget);
  });

  testWidgets('en un móvil de 360 px la hoja no desborda', (tester) async {
    await tester.pumpWidget(montar(tamano: const Size(360, 800)));
    await tester.tap(find.byTooltip('Brújula · ayuda'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Brújula'), findsOneWidget);
  });

  group('lo que ofrece depende del perfil', () {
    test('al aprendiz no se le habla de cerrar períodos', () {
      final paraAprendiz = brjulaConocimiento.where((e) => e.sirvePara('aspirante'));
      final titulos = paraAprendiz.map((e) => e.titulo).toList();

      expect(titulos, contains('Ver mis tareas y entregar'));
      expect(titulos, isNot(contains('Abrir un período nuevo')));
    });

    test('al administrador sí', () {
      final paraAdmin = brjulaConocimiento.where((e) => e.sirvePara('admin'));
      expect(
        paraAdmin.map((e) => e.titulo),
        contains('Abrir un período nuevo'),
      );
    });
  });
}
