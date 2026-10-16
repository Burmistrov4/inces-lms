import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inces_lms_app/models/cuadrante.dart';
import 'package:inces_lms_app/theme/inces_theme.dart';
import 'package:inces_lms_app/widgets/cuadrante_grid.dart';

void main() {
  group('PaletaAulasCuadrante y modelos de cuadrante', () {
    test('indiceColorDeAula devuelve índices acotados de 0 a 11 de forma determinista', () {
      expect(indiceColorDeAula(null), 0);
      expect(indiceColorDeAula(''), 0);
      expect(indiceColorDeAula('   '), 0);

      final idx1 = indiceColorDeAula('aula-soldadura-1');
      final idx2 = indiceColorDeAula('aula-soldadura-1');
      expect(idx1, equals(idx2));
      expect(idx1, greaterThanOrEqualTo(0));
      expect(idx1, lessThan(12));

      final idxMecanica = indiceColorDeAula('taller-mecanica');
      expect(idxMecanica, greaterThanOrEqualTo(0));
      expect(idxMecanica, lessThan(12));
    });

    test('PaletaAulasCuadrante.colorParaAula retorna un color consistente', () {
      final color1 = PaletaAulasCuadrante.colorParaAula('aula-soldadura-1');
      final color2 = PaletaAulasCuadrante.colorParaAula('aula-soldadura-1');
      expect(color1, equals(color2));
      expect(PaletaAulasCuadrante.colores, contains(color1));

      final colorNulo = PaletaAulasCuadrante.colorParaAula(null);
      expect(colorNulo, equals(PaletaAulasCuadrante.colores[0]));
    });

    test('Aula, Guardia y ClaseCuadrante exponen indiceColor correctamente', () {
      const aula = Aula(
        id: 'aula-101',
        nombre: 'Aula de Teoría 101',
        capacidad: 25,
        esTaller: false,
        activa: true,
      );
      expect(aula.indiceColor, equals(indiceColorDeAula('aula-101')));

      const guardia = Guardia(
        id: 'g-1',
        docenteId: 'prof-1',
        aulaId: 'aula-101',
        periodo: 'SA26-2',
        dia: 1,
        bloque: 2,
        turno: Turno.manana,
        activa: true,
      );
      expect(guardia.indiceColor, equals(indiceColorDeAula('aula-101')));

      const clase = ClaseCuadrante(
        id: 'c-1',
        seccionId: 'sec-1',
        docenteId: 'prof-1',
        aulaId: 'aula-101',
        dia: 1,
        bloque: 2,
        turno: Turno.manana,
        activa: true,
        periodo: 'SA26-2',
        programaId: 'prog-1',
        programa: 'Soldadura Universal',
        materiaId: 'mat-1',
        materia: 'Oxicorte',
        seccion: 'U-01',
        aula: 'Taller 1',
        docente: 'Prof. Carlos',
      );
      expect(clase.indiceColor, equals(indiceColorDeAula('aula-101')));
    });

    testWidgets('ChipCuadrante renderiza badge de aula y distinción de guardia', (tester) async {
      final colorPrueba = PaletaAulasCuadrante.colorParaAula('aula-101');

      await tester.pumpWidget(
        MaterialApp(
          theme: IncesTheme.claro(),
          home: Scaffold(
            body: Column(
              children: [
                ChipCuadrante(
                  titulo: 'Soldadura Eléctrica',
                  subtitulo: 'Taller 1 · Prof. Lorenzo',
                  color: colorPrueba,
                  etiquetaAula: 'Taller 1',
                  destacado: true,
                ),
                const ChipCuadrante(
                  titulo: 'Guardia',
                  subtitulo: 'Pasillo Central',
                  esGuardia: true,
                  etiquetaAula: 'Pasillo Central',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Soldadura Eléctrica'), findsOneWidget);
      expect(find.text('Taller 1 · Prof. Lorenzo'), findsOneWidget);
      expect(find.text('Taller 1'), findsOneWidget);

      expect(find.text('Guardia'), findsOneWidget);
      expect(find.text('Pasillo Central'), findsNWidgets(2)); // subtítulo y etiqueta
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });
  });
}
