import 'package:flutter_test/flutter_test.dart';
import 'package:inces_lms_app/models/usuario_admin.dart';

/// Pruebas de las etiquetas de usuario del panel de Usuarios y Roles.
///
/// `nombreCompleto` ya caía al correo cuando el nombre está vacío —el patrón
/// correcto, que las cuentas de la siembra ejercitan de verdad (medido el
/// 2026-10-13: 56 de 64 perfiles son `@semilla.invalid`). Lo que se añade aquí
/// es `esCuentaDemo`, para que el panel etiquete esas cuentas en vez de
/// dejarlas pasar por oferta real.
void main() {
  UsuarioAdmin usuario({
    String nombres = '',
    String apellidos = '',
    String email = 'alguien@inces.gob.ve',
  }) =>
      UsuarioAdmin(
        id: 'u-1',
        email: email,
        cedula: null,
        nombres: nombres,
        apellidos: apellidos,
        rol: 'estudiante',
        activo: true,
      );

  group('nombreCompleto', () {
    test('con nombre, lo enseña', () {
      expect(usuario(nombres: 'Ana', apellidos: 'Pérez').nombreCompleto,
          'Ana Pérez');
    });

    test('sin nombre, cae al correo', () {
      expect(usuario().nombreCompleto, 'alguien@inces.gob.ve');
    });
  });

  group('esCuentaDemo', () {
    test('las cuentas @semilla.invalid son de demostración', () {
      expect(usuario(email: 'aspirante3@semilla.invalid').esCuentaDemo, isTrue);
    });

    test('el dominio real no lo es', () {
      expect(usuario().esCuentaDemo, isFalse);
    });

    test('no distingue mayúsculas', () {
      expect(usuario(email: 'Aspirante3@Semilla.Invalid').esCuentaDemo, isTrue);
    });

    test('ni siquiera con espacios alrededor', () {
      expect(usuario(email: '  aspirante3@semilla.invalid  ').esCuentaDemo,
          isTrue);
    });
  });
}
