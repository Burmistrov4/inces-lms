import 'package:flutter_test/flutter_test.dart';
import 'package:inces_lms_app/core/reglas_cuadrante.dart';
import 'package:inces_lms_app/models/cuadrante.dart';

/// La clase del PNA se reconocía por el **nombre** del programa.
///
/// El programa del PNA se llama «Curso Introductorio (14-17 años)»: no contiene
/// «pna» ni «aprendizaje», así que la heurística decía que no era PNA. Resultado
/// medido el 2026-10-31: el docente Alcides tenía su bloque guardado en
/// INCES26-3 (lunes, bloque 1) y la rejilla decía «este período aún no tiene
/// materias PNA asignadas».
///
/// La vista ya traía `program_code`; lo que faltaba era leerlo.
void main() {
  /// Una fila de `v_cuadrante_clases` tal como la devuelve la API.
  Map<String, dynamic> filaVista() => <String, dynamic>{
        'id': '11111111-1111-4111-8111-111111111111',
        'period_code': 'INCES26-3',
        'program_id': 'e0e83910-1567-4559-ad0b-3a3457300b08',
        'program_code': 'CUR-INT-01',
        'program_name': 'Curso Introductorio (14-17 años)',
        'subject_id': '2924cfe6-4e41-4dcb-abb9-dfc16738cca1',
        'subject_name': 'Metalurgia y Materiales',
        'section_id': 'b5794eaa-b869-4480-97aa-68e5abcbed85',
        'section_name': 'INT-A',
        'teacher_id': '8b4cdfad-cb5a-482d-9d9d-8b64deefdbf9',
        'teacher_name': 'alcides armando mencias parra',
        'classroom_id': null,
        'classroom_name': null,
        'is_workshop': false,
        'day_of_week': 1,
        'day_name': 'lunes',
        'block': 1,
        'turno': 'MAÑANA',
        'is_active': true,
      };

  group('la clase del PNA se reconoce por su código', () {
    test('el modelo lee program_code de la vista', () {
      final clase = ClaseCuadrante.fromJson(filaVista());
      expect(clase.programaCodigo, 'CUR-INT-01');
    });

    test('mirando sólo el nombre NO se reconocía — la causa del fallo', () {
      final clase = ClaseCuadrante.fromJson(filaVista());
      // El nombre no delata nada: de ahí que la rejilla saliera vacía.
      expect(esProgramaPNA(clase.programa), isFalse);
      // El código sí.
      expect(esProgramaPNA(clase.programaCodigo), isTrue);
    });

    test('un programa ordinario no se confunde con el PNA', () {
      final fila = filaVista()
        ..['program_code'] = 'SEM-SOL-01'
        ..['program_name'] = 'Soldadura';
      final clase = ClaseCuadrante.fromJson(fila);
      expect(esProgramaPNA(clase.programaCodigo), isFalse);
      expect(esProgramaPNA(clase.programa), isFalse);
    });
  });
}
