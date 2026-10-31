import 'package:flutter_test/flutter_test.dart';
import 'package:inces_lms_app/core/reglas_cuadrante.dart';
import 'package:inces_lms_app/models/cuadrante.dart';

/// El turno nocturno (bloques 13–17), abierto en el centro el 2026-10-31.
///
/// Antes de la migración `202610310001_turno_nocturno`, `turno_de_bloque`
/// respondía «TARDE» para **todo** lo que pasara de 6 y las dos tablas cerraban
/// el bloque en 12: un bloque 13 era imposible de guardar. Peor, si se hubiera
/// permitido, la rejilla lo habría pintado a la una de la tarde.
void main() {
  group('turno nocturno', () {
    test('la frontera de turnos tiene tres tramos', () {
      expect(turnoDeBloque(1), Turno.manana);
      expect(turnoDeBloque(6), Turno.manana);
      expect(turnoDeBloque(7), Turno.tarde);
      expect(turnoDeBloque(12), Turno.tarde);
      expect(turnoDeBloque(13), Turno.noche);
      expect(turnoDeBloque(17), Turno.noche);
    });

    test('el día llega al bloque 17', () {
      expect(bloqueMaximo, 17);
      expect(bloqueValido(17), isTrue);
      expect(bloqueValido(18), isFalse);
    });

    test('cada turno tiene sus bloques, sin solaparse ni dejar huecos', () {
      final manana = bloquesDelTurno(Turno.manana);
      final tarde = bloquesDelTurno(Turno.tarde);
      final noche = bloquesDelTurno(Turno.noche);

      expect(manana, [1, 2, 3, 4, 5, 6]);
      expect(tarde, [7, 8, 9, 10, 11, 12]);
      expect(noche, [13, 14, 15, 16, 17]);

      final todos = [...manana, ...tarde, ...noche];
      expect(todos.length, bloqueMaximo);
      expect(todos.toSet().length, todos.length, reason: 'sin repetidos');
    });

    test('la noche se lee en horario de tarde-noche, no de madrugada', () {
      // El rótulo viejo dejaba «Tarde 01:00 - 01:45» y había que deducir el
      // meridiano; con la noche el riesgo es peor: 06:00 sin meridiano puede
      // leerse como las seis de la mañana.
      expect(horaConMeridianoDeBloque(13), '06:00 - 06:45 p. m.');
      expect(horaConMeridianoDeBloque(17), '09:00 - 09:45 p. m.');
      expect(horaConMeridianoDeBloque(1), '07:30 - 08:15 a. m.');
    });

    test('el turno se traduce al vocabulario del backend', () {
      expect(Turno.noche.valorApi, 'NOCHE');
      expect(Turno.noche.etiqueta, 'Noche');
      expect(Turno.desdeApi('NOCHE', bloque: 14), Turno.noche);
      // Sin dato del servidor, se deriva del bloque.
      expect(Turno.desdeApi(null, bloque: 14), Turno.noche);
    });
  });
}
