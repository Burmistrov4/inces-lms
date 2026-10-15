import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/formulario_inscripcion.dart';

void main() {
  group('AspiranteFormScreen · persistencia de borrador', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('restaura automáticamente los datos guardados en el borrador',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'borrador_inscripcion_inces_v1': jsonEncode({
          'primer_nombre': 'Carlos',
          'primer_apellido': 'Pérez',
          'cedula': 'V-28123456',
          '__paso__': 0,
        }),
      });

      await montarFormulario(tester);
      await tester.pumpAndSettle();

      // Debe mostrar el aviso de que los datos fueron restaurados
      expect(
        find.text('Hemos restaurado tus datos guardados automáticamente.'),
        findsOneWidget,
      );

      // Los campos restaurados deben tener el valor cargado
      expect(find.text('Carlos'), findsAtLeastNWidgets(1));
      expect(find.text('Pérez'), findsAtLeastNWidgets(1));
    });

    testWidgets('botón Limpiar remueve el borrador y reinicia el formulario',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'borrador_inscripcion_inces_v1': jsonEncode({
          'primer_nombre': 'Carlos',
          '__paso__': 0,
        }),
      });

      await montarFormulario(tester);
      await tester.pumpAndSettle();

      expect(find.text('Limpiar'), findsOneWidget);
      await tester.tap(find.text('Limpiar'));
      await tester.pumpAndSettle();

      // El aviso desaparece y el campo se vacía
      expect(
        find.text('Hemos restaurado tus datos guardados automáticamente.'),
        findsNothing,
      );
      expect(find.text('Carlos'), findsNothing);

      // En SharedPreferences la clave se borró
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('borrador_inscripcion_inces_v1'), isFalse);
    });
  });
}
