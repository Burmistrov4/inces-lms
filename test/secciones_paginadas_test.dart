import 'package:flutter_test/flutter_test.dart';
import 'package:inces_lms_app/models/seccion.dart';
import 'package:inces_lms_app/repositories/secciones_repository.dart';

import 'support/fake_secciones_gateway.dart';

/// **Paginado del catálogo de secciones.**
///
/// Nace de un defecto medido el 2026-10-29: el cuadrante y el horario PNA pedían
/// `limite: 150`, y el backend rechaza todo lo que pase de 100
/// (`esquemaListadoSecciones` → `.max(100)`). El resultado era un `400` que nadie
/// miraba y una rejilla que se quedaba en esqueletos para siempre —«el cuadrante
/// no funciona»— sin un solo mensaje.
///
/// Estas pruebas fijan las dos mitades del arreglo: que se pide **el máximo que
/// acepta el contrato** y que se **sigue pidiendo** hasta agotar el catálogo (un
/// centro con más de 100 secciones no puede quedarse con la rejilla a medias).
void main() {
  late FakeSeccionesGateway gateway;
  late SeccionesRepository repo;

  setUp(() {
    gateway = FakeSeccionesGateway();
    repo = SeccionesRepository(gateway: gateway);
  });

  /// Una página de [cuantos] secciones, numeradas desde [desde].
  PaginaSecciones pagina(int desde, int cuantos, {int total = 0}) => PaginaSecciones(
        secciones: [
          for (var i = desde; i < desde + cuantos; i++) seccionEjemplo(id: 'sec-$i'),
        ],
        total: total,
        limite: SeccionesRepository.limiteMaximoPorPagina,
        desplazamiento: desde,
      );

  test('pide el máximo del contrato (100) y no una cifra inventada', () async {
    gateway.paginaSegunDesplazamiento = (_, _) => pagina(0, 3);

    final resultado = await repo.listarTodasLasSecciones(soloActivas: true);

    expect(resultado.isSuccess, isTrue);
    expect(
      gateway.ultimoLimite,
      SeccionesRepository.limiteMaximoPorPagina,
      reason: 'el backend devuelve 400 por encima de 100 y la pantalla se queda cargando',
    );
    expect(
      gateway.ultimoLimite,
      lessThanOrEqualTo(100),
      reason: 'el contrato de la API no admite más de 100 por página',
    );
    expect(gateway.ultimoSoloActivas, isTrue);
  });

  test('recorre todas las páginas hasta la última incompleta', () async {
    // 100 + 30: la segunda página viene corta y ahí debe parar.
    gateway.paginaSegunDesplazamiento = (desplazamiento, _) => desplazamiento == 0
        ? pagina(0, 100)
        : pagina(100, 30);

    final resultado = await repo.listarTodasLasSecciones();

    expect(resultado.isSuccess, isTrue);
    expect(resultado.valueOrNull, hasLength(130));
    expect(
      gateway.llamadas.where((l) => l == 'listarSecciones'),
      hasLength(2),
      reason: 'una página llena no es el final del catálogo',
    );
    expect(gateway.ultimoDesplazamiento, 100);
  });

  test('se detiene al alcanzar el total declarado por el servidor', () async {
    // Página llena (100) pero el servidor dice que sólo hay 100: no hay que
    // pedir una segunda. Sin este corte, un `total` exacto provocaba un viaje de
    // más por cada carga.
    gateway.paginaSegunDesplazamiento = (desplazamiento, _) =>
        pagina(desplazamiento, 100, total: 100);

    final resultado = await repo.listarTodasLasSecciones();

    expect(resultado.valueOrNull, hasLength(100));
    expect(gateway.llamadas.where((l) => l == 'listarSecciones'), hasLength(1));
  });

  test('un fallo del gateway se convierte en Result fallido, no en excepción', () async {
    gateway.errorAlListar = Exception('400');

    final resultado = await repo.listarTodasLasSecciones();

    expect(resultado.isSuccess, isFalse);
  });
}
