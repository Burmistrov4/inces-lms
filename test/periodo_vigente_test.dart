import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:inces_lms_app/core/network/api_client.dart';
import 'package:inces_lms_app/models/cuadrante.dart';
import 'package:inces_lms_app/repositories/cuadrante_repository.dart';
import 'package:inces_lms_app/services/cuadrante_service.dart';

import 'support/fake_cuadrante_gateway.dart';

/// El período de la cabecera, leído por cualquier rol.
///
/// ## El defecto que estas pruebas fijan
///
/// Los tres paneles pedían el lapso de su cabecera a `GET /api/v1/admin/periodos`.
/// En docente y estudiante esa petición devolvía **403 SOLO_ADMIN** en cada
/// apertura del panel; el cliente lo tapaba con un respaldo a PostgREST, así que
/// la insignia se pintaba bien y el fallo sólo se veía en la consola y en el
/// registro del servidor. Medido con Playwright contra producción el 2026-11-18.
///
/// La prueba del gateway es la que importa: fija **a qué ruta se pide**, que es
/// exactamente lo que estaba mal. La del repositorio fija que un fallo llegue
/// como `Failure` y no como un `null` silencioso.
void main() {
  group('gateway — la ruta no es la de administración', () {
    test('pide /api/v1/periodo-vigente con el token de la sesión', () async {
      final pedidas = <String>[];
      String? autorizacion;

      final cliente = MockClient((peticion) async {
        pedidas.add(peticion.url.path);
        autorizacion = peticion.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'periodo': {
              'id': '11111111-2222-3333-4444-555555555555',
              'codigo': 'INCES26-3',
              'nombre': 'INCES 26-3',
              'fechaInicio': '2026-10-01',
              'fechaFin': '2027-02-15',
              'activo': true,
              'vigente': true,
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final gateway = BackendCuadranteGateway(
        api: ApiClient(httpClient: cliente, baseUrl: 'https://api.ejemplo.test'),
        tokenSesion: () => 'token-de-prueba',
      );

      final periodo = await gateway.obtenerPeriodoVigente();

      // Lo que se está midiendo: la ruta. `/admin/periodos` es la que producía
      // el 403 SOLO_ADMIN en dos de los tres roles.
      expect(pedidas, ['/api/v1/periodo-vigente']);
      expect(autorizacion, 'Bearer token-de-prueba');
      expect(periodo?.codigo, 'INCES26-3');
      expect(periodo?.vigente, isTrue);
    });

    test('sin lapso declarado devuelve null, no un período inventado', () async {
      final cliente = MockClient(
        (_) async => http.Response(
          jsonEncode({'periodo': null}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      final gateway = BackendCuadranteGateway(
        api: ApiClient(httpClient: cliente, baseUrl: 'https://api.ejemplo.test'),
        tokenSesion: () => 'token-de-prueba',
      );

      expect(await gateway.obtenerPeriodoVigente(), isNull);
    });

    test('un 403 no se convierte en un período: se propaga', () async {
      final cliente = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'codigo': 'SOLO_ADMIN', 'mensaje': 'Reservado al administrador.'},
          }),
          403,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      final gateway = BackendCuadranteGateway(
        api: ApiClient(httpClient: cliente, baseUrl: 'https://api.ejemplo.test'),
        tokenSesion: () => 'token-de-prueba',
      );

      // Si esto pasara, el dashboard volvería a pintar una cabecera sin saber
      // por qué: el silencio es justo lo que ocultó el defecto durante días.
      await expectLater(gateway.obtenerPeriodoVigente(), throwsA(anything));
    });
  });

  group('repositorio', () {
    test('delega en el gateway y devuelve el lapso vigente', () async {
      final gateway = FakeCuadranteGateway()
        ..periodoVigente = const Periodo(
          id: '11111111-2222-3333-4444-555555555555',
          codigo: 'INCES26-3',
          activo: true,
          vigente: true,
        );
      final repo = CuadranteRepository(gateway: gateway);

      final resultado = await repo.obtenerPeriodoVigente();

      expect(resultado.isSuccess, isTrue);
      expect(resultado.valueOrNull?.codigo, 'INCES26-3');
      expect(gateway.llamadas, contains('obtenerPeriodoVigente'));
    });

    test('un fallo del gateway llega como Failure, no como null', () async {
      final gateway = FakeCuadranteGateway()..errorAlObtenerPeriodoVigente = Exception('sin red');
      final repo = CuadranteRepository(gateway: gateway);

      final resultado = await repo.obtenerPeriodoVigente();

      expect(resultado.isFailure, isTrue);
      expect(resultado.errorOrNull, isNotNull);
    });

    test('un centro sin lapsos devuelve success(null)', () async {
      final gateway = FakeCuadranteGateway()..periodoVigente = null;
      final repo = CuadranteRepository(gateway: gateway);

      final resultado = await repo.obtenerPeriodoVigente();

      expect(resultado.isSuccess, isTrue);
      expect(resultado.valueOrNull, isNull);
    });
  });
}
