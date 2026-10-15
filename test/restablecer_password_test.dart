import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inces_lms_app/core/errors/app_exception.dart';
import 'package:inces_lms_app/core/gateways/recuperacion_gateway.dart';
import 'package:inces_lms_app/models/recuperacion_password.dart';
import 'package:inces_lms_app/repositories/recuperacion_repository.dart';
import 'package:inces_lms_app/screens/restablecer_con_codigo_screen.dart';
import 'package:inces_lms_app/services/auth_service.dart';

import 'support/fake_gateway.dart';

void main() {
  // ---------------------------------------------------------------------------
  // El flujo de restablecimiento cubre dos caminos que convergen en la misma
  // llamada: el enlace del correo (sesión temporal) y el cambio voluntario
  // desde dentro de la app. Ambos llegan a `actualizarPassword`.
  // ---------------------------------------------------------------------------
  group('AuthService.restablecerPassword · camino feliz', () {
    test('cambia la contraseña cuando hay sesión', () async {
      final fake = FakeGateway()..tieneSesion = true;

      final resultado = await AuthService(
        gateway: fake,
      ).restablecerPassword('contrasena-nueva-123');

      expect(resultado.isSuccess, isTrue);
      expect(resultado.valueOrNull, isTrue);
      expect(fake.llamadas, contains('actualizarPassword'));
    });

    test('la longitud mínima son 8 caracteres, no 7', () async {
      final fake = FakeGateway()..tieneSesion = true;

      final resultado = await AuthService(
        gateway: fake,
      ).restablecerPassword('1234567');

      expect(resultado.isFailure, isTrue);
      expect(resultado.errorOrNull?.type, AppErrorType.validacion);
      // Falla rápido: no debe gastar una llamada de red.
      expect(fake.llamadas, isNot(contains('actualizarPassword')));
    });

    test('acepta exactamente 8 caracteres (borde inferior)', () async {
      final fake = FakeGateway()..tieneSesion = true;

      final resultado = await AuthService(
        gateway: fake,
      ).restablecerPassword('12345678');

      expect(resultado.isSuccess, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('AuthService.restablecerPassword · sin sesión', () {
    test('sin sesión falla con mensaje de enlace caducado', () async {
      // Un enlace de recuperación caducado deja al usuario sin sesión. El
      // mensaje tiene que explicarlo: si dijera «credenciales inválidas» el
      // usuario pensaría que se equivocó al escribir, no que llegó tarde.
      final fake = FakeGateway()..tieneSesion = false;

      final resultado = await AuthService(
        gateway: fake,
      ).restablecerPassword('contrasena-nueva-123');

      expect(resultado.isFailure, isTrue);
      expect(resultado.errorOrNull?.type, AppErrorType.credenciales);
      expect(
        resultado.errorOrNull?.message.toLowerCase(),
        contains('enlace'),
      );
      expect(fake.llamadas, isNot(contains('actualizarPassword')));
    });
  });

  // ---------------------------------------------------------------------------
  group('AuthService.restablecerPassword · propagación de fallos', () {
    test('si el gateway falla, el error llega tipado', () async {
      final fake = FakeGateway()
        ..tieneSesion = true
        ..errorAlActualizarPassword = const AppException(
          type: AppErrorType.servidor,
          message: 'Supabase rechazó la operación.',
        );

      final resultado = await AuthService(
        gateway: fake,
      ).restablecerPassword('contrasena-nueva-123');

      expect(resultado.isFailure, isTrue);
      expect(resultado.errorOrNull?.message, contains('rechazó'));
    });

    test('una contraseña de sólo espacios no cuenta como válida', () async {
      // 8 cadenas vacías miden 8, pero no son una contraseña. Sin esta guarda
      // el usuario podría fijar algo que no puede volver a teclear.
      final fake = FakeGateway()..tieneSesion = true;

      final resultado = await AuthService(
        gateway: fake,
      ).restablecerPassword('        ');

      expect(resultado.isFailure, isTrue);
      expect(resultado.errorOrNull?.type, AppErrorType.validacion);
      expect(fake.llamadas, isNot(contains('actualizarPassword')));
    });
  });

  // ---------------------------------------------------------------------------
  group('RestablecerConCodigoScreen · pruebas de interfaz y flujo dual', () {
    testWidgets('con sesión activa (enlace de correo Supabase), no pide código y actualiza con éxito', (tester) async {
      final fakeGateway = FakeGateway()..tieneSesion = true;
      final authService = AuthService(gateway: fakeGateway);
      final fakeRecupGateway = _FakeRecupGateway();
      final repo = RecuperacionRepository(gateway: fakeRecupGateway);

      await tester.pumpWidget(
        MaterialApp(
          home: RestablecerConCodigoScreen(
            authService: authService,
            repositorio: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el banner informativo de enlace verificado
      expect(find.textContaining('Enlace de recuperación verificado'), findsOneWidget);
      // No debe pedir código de recuperación por defecto
      expect(find.text('Código de recuperación'), findsNothing);

      // Ingresamos contraseña nueva y confirmación
      final passInputs = find.byType(TextFormField);
      expect(passInputs, findsNWidgets(2));

      await tester.enterText(passInputs.at(0), 'nuevaClave123');
      await tester.enterText(passInputs.at(1), 'nuevaClave123');
      await tester.pump();

      await tester.tap(find.text('Cambiar contraseña'));
      await tester.pumpAndSettle();

      // Verificamos que se llamó actualizarPassword en el gateway de auth
      expect(fakeGateway.llamadas, contains('actualizarPassword'));
      expect(find.text('Contraseña actualizada'), findsOneWidget);
      expect(find.text('Ir a iniciar sesión'), findsOneWidget);
    });

    testWidgets('sin sesión activa, pide código institucional y lo canjea contra el repositorio', (tester) async {
      final fakeGateway = FakeGateway()..tieneSesion = false;
      final authService = AuthService(gateway: fakeGateway);
      final fakeRecupGateway = _FakeRecupGateway();
      final repo = RecuperacionRepository(gateway: fakeRecupGateway);

      await tester.pumpWidget(
        MaterialApp(
          home: RestablecerConCodigoScreen(
            authService: authService,
            repositorio: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el campo para ingresar el código de 12 dígitos
      expect(find.text('Código de recuperación'), findsOneWidget);

      final inputs = find.byType(TextFormField);
      expect(inputs, findsNWidgets(3));

      await tester.enterText(inputs.at(0), 'ABCD-EFGH-JKMN');
      await tester.enterText(inputs.at(1), 'nuevaClave123');
      await tester.enterText(inputs.at(2), 'nuevaClave123');
      await tester.pump();

      await tester.tap(find.text('Cambiar contraseña'));
      await tester.pumpAndSettle();

      // Verificamos que se canjeó el código en el repositorio
      expect(fakeRecupGateway.codigoRecibido, equals('ABCDEFGHJKMN'));
      expect(fakeRecupGateway.passwordRecibida, equals('nuevaClave123'));
      expect(find.text('Contraseña actualizada'), findsOneWidget);
    });
  });
}

class _FakeRecupGateway implements RecuperacionGateway {
  String? codigoRecibido;
  String? passwordRecibida;
  bool lanzar = false;

  @override
  Future<CodigoRecuperacion> emitirCodigo(String usuarioId) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> canjearCodigo({
    required String codigo,
    required String password,
  }) async {
    if (lanzar) {
      throw const AppException.validacion('Código inválido o expirado.');
    }
    codigoRecibido = codigo;
    passwordRecibida = password;
    return true;
  }
}

