import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inces_lms_app/models/programa.dart';
import 'package:inces_lms_app/repositories/curriculo_repository.dart';
import 'package:inces_lms_app/screens/admin/cpanel_programas_panel.dart';
import 'package:inces_lms_app/widgets/andamiaje.dart';

import 'support/fake_curriculo_gateway.dart';

/// Diagnóstico del Lote 2 — scroll en móvil (Redmi 10C, 360×740 dp).
///
/// Monta el panel **dentro de `ContenidoSeccion`**, que es su padre real, con
/// datos suficientes para desbordar el viewport, y comprueba que el contenido
/// llega a desplazarse. Si falla, reproduce el «no desliza» que se reportó a
/// mano y localiza la capa culpable sin adivinar.
void main() {
  const ventanaRedmi10C = Size(360, 740);

  Future<List<ProgramaConTotales>> programasDePrueba(int n) async {
    return List.generate(n, (i) {
      return ProgramaConTotales(
        id: 'prog-$i',
        codigo: 'CUR-TES-${i.toString().padLeft(2, '0')}',
        nombre: 'Programa de Prueba Número $i',
        tipo: TipoPrograma.cursoLibre,
        requierePasantia: false,
        activo: true,
        totalMaterias: 1,
        totalPeriodos: 1,
        cupo: 25,
        cuposOcupados: 0,
        mostrarDisponibilidad: true,
      );
    });
  }

  testWidgets('Cursos y PNA desliza a 360×740 dentro de ContenidoSeccion',
      (tester) async {
    tester.view.physicalSize = ventanaRedmi10C;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final gateway = FakeCurriculoGateway()
      ..programas = await programasDePrueba(8)
      ..totalProgramas = 8;
    final repo = CurriculoRepository(gateway: gateway);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: ContenidoSeccion(
              migas: const ['Inicio', 'Gestión académica', 'Cursos y PNA'],
              child: CpanelProgramasPanel(repositorio: repo),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final e1 = tester.takeException();
    // ignore: avoid_print
    print('EXCEPCIÓN EN CARGA: $e1');
    await tester.pumpAndSettle();
    final e2 = tester.takeException();
    // ignore: avoid_print
    print('EXCEPCIÓN TRAS SETTLE: $e2');

    // El primer programa es visible al abrir.
    expect(find.text('Programa de Prueba Número 0'), findsOneWidget);

    // Arrastra hacia arriba: el contenido debe desplazarse hasta que el
    // último programa entre en pantalla.
    // Arrastra hacia arriba de forma repetida (como haría un dedo): el
    // contenido debe desplazarse hasta que el último programa entre en
    // pantalla.
    for (var i = 0; i < 10 && find.text('Programa de Prueba Número 7').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    final e3 = tester.takeException();
    // ignore: avoid_print
    print('EXCEPCIÓN TRAS DRAG: $e3');

    expect(
      find.text('Programa de Prueba Número 7'),
      findsOneWidget,
      reason: 'Tras arrastrar 600 px el último programa debe ser visible; '
          'si no, la lista no desliza (el bug reportado en el Redmi 10C).',
    );
  });
}
