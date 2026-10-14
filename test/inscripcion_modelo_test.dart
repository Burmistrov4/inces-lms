import 'package:flutter_test/flutter_test.dart';

import 'support/fake_inscripcion_gateway.dart';

/// Pruebas de las etiquetas de estudiante del panel de administración
/// (`etiquetaEstudiante` y `esCuentaDemo`).
///
/// **El defecto que fijan.** Medido el 2026-10-13 contra la nube: 57 de 64
/// perfiles tenían nombres y apellidos vacíos, y 56 de ellos usan el dominio
/// `semilla.invalid` (TLD reservado para dominios inválidos, RFC 2606): son las
/// cuentas de la siembra. Antes, la fila de esos inscritos se pintaba con
/// `nombre ?? estudianteId`, así que **el UUID quedaba como etiqueta de
/// usuario** —ruido que nadie puede verificar— y con un nombre vacío (que el
/// backend emitía como `''` antes de `nombreVisible`) la fila se quedaba
/// **en blanco**, porque `??` sólo salta con `null`, no con una cadena vacía.
///
/// Estas pruebas corren en la VM sin montar widgets: la regla vive en el modelo,
/// y la pantalla sólo la consume.
void main() {
  group('etiquetaEstudiante', () {
    test('con nombre, lo enseña', () {
      final i = inscripcionDetalladaEjemplo(estudianteNombre: 'Ana Pérez');
      expect(i.etiquetaEstudiante, 'Ana Pérez');
    });

    test('sin nombre, usa el correo —nunca el UUID', () {
      final i = inscripcionDetalladaEjemplo(
        estudianteNombre: null,
        estudianteEmail: 'alguien@inces.gob.ve',
        estudianteId: '3f2a9c61-1111-4222-8333-abcdefabcdef',
      );
      expect(i.etiquetaEstudiante, 'alguien@inces.gob.ve');
      expect(i.etiquetaEstudiante, isNot(contains('3f2a9c61')));
    });

    test('sin nombre ni correo, dice que no hay nombre', () {
      final i = inscripcionDetalladaEjemplo(
        estudianteNombre: null,
        estudianteEmail: null,
      );
      expect(i.etiquetaEstudiante, 'Sin nombre registrado');
    });

    test('un nombre de sólo espacios no cuenta como nombre', () {
      final i = inscripcionDetalladaEjemplo(
        estudianteNombre: '   ',
        estudianteEmail: 'alguien@inces.gob.ve',
      );
      expect(i.etiquetaEstudiante, 'alguien@inces.gob.ve');
    });
  });

  group('esCuentaDemo', () {
    test('las cuentas @semilla.invalid son de demostración', () {
      final i = inscripcionDetalladaEjemplo(
        estudianteEmail: 'aspirante7@semilla.invalid',
      );
      expect(i.esCuentaDemo, isTrue);
    });

    test('el dominio real no lo es', () {
      final i = inscripcionDetalladaEjemplo(
        estudianteEmail: 'alguien@inces.gob.ve',
      );
      expect(i.esCuentaDemo, isFalse);
    });

    test('sin correo no se puede afirmar que sea demo', () {
      final i = inscripcionDetalladaEjemplo(estudianteEmail: null);
      expect(i.esCuentaDemo, isFalse);
    });

    test('no distingue mayúsculas: la marca se compara normalizada', () {
      final i = inscripcionDetalladaEjemplo(
        estudianteEmail: 'Aspirante7@SEMILLA.INVALID',
      );
      expect(i.esCuentaDemo, isTrue);
    });
  });
}
