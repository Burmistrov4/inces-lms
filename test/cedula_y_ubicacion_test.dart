import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inces_lms_app/models/inscripcion_campo.dart';
import 'package:inces_lms_app/widgets/campos_planilla/campo_cedula.dart';
import 'package:inces_lms_app/widgets/campos_planilla/cedula_input_formatter.dart';
import 'package:inces_lms_app/widgets/campos_planilla/constructor_direccion_inteligente.dart';

void main() {
  group('CedulaInputFormatter', () {
    test('formatea correctamente con puntos de millar estilo venezolano', () {
      expect(CedulaInputFormatter.formatearNumero('123456'), '123.456');
      expect(CedulaInputFormatter.formatearNumero('1234567'), '1.234.567');
      expect(CedulaInputFormatter.formatearNumero('14852369'), '14.852.369');
      expect(CedulaInputFormatter.formatearNumero('123456789'), '123.456.789');
    });

    test('limpia caracteres no numéricos al vuelo', () {
      expect(CedulaInputFormatter.soloDigitos('V-14.852.369'), '14852369');
      expect(CedulaInputFormatter.soloDigitos('e 81 234 567'), '81234567');
      expect(CedulaInputFormatter.soloDigitos('abc123xyz'), '123');
    });

    test('extrae prefijo de nacionalidad si viene presente', () {
      expect(CedulaInputFormatter.extraerPrefijo('V-14852369'), 'V');
      expect(CedulaInputFormatter.extraerPrefijo('v 14852369'), 'V');
      expect(CedulaInputFormatter.extraerPrefijo('E-81234567'), 'E');
      expect(CedulaInputFormatter.extraerPrefijo('P-987654'), 'P');
      expect(CedulaInputFormatter.extraerPrefijo('J-123456789'), 'J');
      expect(CedulaInputFormatter.extraerPrefijo('14852369'), isNull);
    });
  });

  group('CampoCedula Widget', () {
    CampoInscripcion campo(String codigo) {
      return CampoInscripcion(
        codigo: codigo,
        etiqueta: 'Cédula de identidad',
        grupo: 'Datos personales',
        tipo: TipoCampoInscripcion.texto,
        orden: 1,
        obligatorio: true,
      );
    }

    testWidgets('renderiza con selector de prefijo y campo de texto', (tester) async {
      String? valorCapturado;
      String? prefijoCapturado;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampoCedula(
              campo: campo('cedula'),
              valor: null,
              prefijoInicial: 'V',
              etiqueta: 'Cédula de identidad',
              onPrefijoCambio: (p) => prefijoCapturado = p,
              onCambio: (v) => valorCapturado = v?.toString(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('V-'), findsOneWidget);

      // Escribir dígitos
      await tester.enterText(find.byType(TextFormField), '14852369');
      await tester.pump();

      // Verifica que sube el valor canónico
      expect(valorCapturado, 'V-14852369');
    });
  });

  group('ConstructorDireccionInteligente Widget', () {
    CampoInscripcion campo(String codigo) {
      return CampoInscripcion(
        codigo: codigo,
        etiqueta: 'Dirección de habitación',
        grupo: 'Ubicación y contacto',
        tipo: TipoCampoInscripcion.texto,
        orden: 2,
        obligatorio: true,
      );
    }

    testWidgets('los dos campos están a la vista: dirección y punto de referencia',
        (tester) async {
      String? valorCapturado;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConstructorDireccionInteligente(
                campo: campo('direccion'),
                valor: null,
                etiqueta: 'Dirección de habitación',
                onCambio: (v) => valorCapturado = v?.toString(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Los dos campos existen **sin pulsar nada**: el punto de referencia es el
      // dato que hace la dirección encontrable, y esconderlo detrás de un
      // desplegable hacía que casi nadie lo llenara.
      final campos = find.byType(TextFormField);
      expect(campos, findsNWidgets(2));
      expect(find.text('Punto de referencia (opcional)'), findsOneWidget);

      await tester.enterText(
        campos.first,
        'Urb. La Isabelica, Sector 3, Vereda 12, Casa 4',
      );
      await tester.pump();

      expect(valorCapturado, 'Urb. La Isabelica, Sector 3, Vereda 12, Casa 4');

      await tester.enterText(campos.at(1), 'Frente al CDI');
      await tester.pump();

      // Debe consolidar dirección y referencia en el único renglón que imprime
      // la Planilla Oficial.
      expect(
        valorCapturado,
        'Urb. La Isabelica, Sector 3, Vereda 12, Casa 4 (Ref: Frente al CDI)',
      );
    });

    testWidgets('los chips insertan el prefijo y no borran lo ya escrito',
        (tester) async {
      String? valorCapturado;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConstructorDireccionInteligente(
                campo: campo('direccion'),
                valor: null,
                etiqueta: 'Dirección de habitación',
                onCambio: (v) => valorCapturado = v?.toString(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'Calle 5');
      await tester.pump();

      await tester.tap(find.text('Urb. '));
      await tester.pump();

      // El prefijo entra **en el cursor**, con la coma que separa: lo escrito
      // sigue ahí y no queda «Calle 5Urb.».
      expect(valorCapturado, 'Calle 5, Urb.');
    });
  });
}
