import 'package:flutter_test/flutter_test.dart';
import 'package:inces_lms_app/models/cuadrante.dart';

/// **La hora que se lee en la rejilla tiene que decir de qué lado del día está.**
///
/// `horasDeBloque` guarda los rangos sin meridiano: «01:00 - 01:45» sirve igual
/// para la madrugada que para la tarde. En un horario eso no se sostiene, y se vio
/// leyendo la rejilla a 820 px el 2026-10-29: el bloque 7 aparecía como «Tarde
/// 01:00 - 01:45» y había que deducir que era la una de la tarde.
void main() {
  test('la mañana se marca con a. m. y la tarde con p. m.', () {
    expect(horaConMeridianoDeBloque(1), '07:30 - 08:15 a. m.');
    expect(horaConMeridianoDeBloque(6), '11:15 - 12:00 a. m.');
    expect(horaConMeridianoDeBloque(7), '01:00 - 01:45 p. m.');
    expect(horaConMeridianoDeBloque(12), '04:45 - 05:30 p. m.');
  });

  test('el dato en crudo no se toca: el formulario de horas lo reutiliza', () {
    // Si `horaLegibleDeBloque` empezara a devolver el meridiano, el administrador
    // lo guardaría al editar las horas y al reeditarlas aparecería dos veces.
    expect(horaLegibleDeBloque(7), '01:00 - 01:45');
    expect(horaConMeridianoDeBloque(7), isNot(horaLegibleDeBloque(7)));
  });

  test('no duplica el meridiano si el rango ya lo trae', () {
    final original = horasDeBloque[3];
    addTearDown(() => horasDeBloque[3] = original!);
    horasDeBloque[3] = '09:00 - 09:45 a. m.';
    expect(horaConMeridianoDeBloque(3), '09:00 - 09:45 a. m.');
  });

  test('un bloque fuera de rango devuelve vacío en vez de inventar una hora', () {
    expect(horaConMeridianoDeBloque(0), '');
    // El 13 dejó de estar fuera de rango con el turno nocturno (2026-10-31);
    // el techo ahora es 17, así que el primero que no existe es el 18.
    expect(horaConMeridianoDeBloque(18), '');
  });
}
