import 'package:flutter_test/flutter_test.dart';
import 'package:inces_lms_app/models/seccion.dart';
import 'package:inces_lms_app/services/secciones_service.dart';

/// El sobre `{ seccion: {...} }` de las rutas de alta y edición.
///
/// **De dónde sale esta prueba.** El 2026-10-31, en producción, el dueño intentó
/// crear un grupo desde el cuadrante: `POST /api/v1/admin/secciones` devolvió
/// **201** (el grupo se creó de verdad) y la pantalla mostró «Ocurrió un error
/// inesperado». La causa era pasar el sobre entero a `Seccion.fromJson`, que
/// buscaba `id` en el sobre y no lo encontraba.
void main() {
  final seccionJson = <String, dynamic>{
    'id': '7f3c1c9e-0000-4000-8000-000000000001',
    'programaId': 'c1000000-0000-4000-8000-000000000001',
    'materiaId': 'c2000000-0000-4000-8000-000000000002',
    'periodo': 'INCES26-3',
    'nombre': 'grupo1',
    'activa': true,
    'cupoMaximo': 25,
  };

  group('desenvolverSeccion', () {
    test('saca la sección del sobre de la respuesta', () {
      final cuerpo = <String, dynamic>{'seccion': seccionJson};
      final seccion = Seccion.fromJson(desenvolverSeccion(cuerpo));

      expect(seccion.id, seccionJson['id']);
      expect(seccion.nombre, 'grupo1');
      expect(seccion.periodo, 'INCES26-3');
    });

    test('tolera un cuerpo plano, sin sobre', () {
      // Un despliegue que responda el objeto directo no debe romperse.
      final seccion = Seccion.fromJson(desenvolverSeccion(seccionJson));
      expect(seccion.id, seccionJson['id']);
    });

    test('el sobre NO se puede leer como sección: por eso hacía falta', () {
      // Si alguien vuelve a pasar `respuesta` a `Seccion.fromJson`, esto lo
      // explica: el `id` del sobre no existe.
      final cuerpo = <String, dynamic>{'seccion': seccionJson};
      expect(cuerpo['id'], isNull);
      expect(cuerpo['seccion'], isA<Map<String, dynamic>>());
    });
  });
}
