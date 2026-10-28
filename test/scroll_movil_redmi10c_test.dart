import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inces_lms_app/models/cuadrante.dart';
import 'package:inces_lms_app/models/programa.dart';
import 'package:inces_lms_app/repositories/cuadrante_repository.dart';
import 'package:inces_lms_app/repositories/curriculo_repository.dart';
import 'package:inces_lms_app/screens/admin/cpanel_cuadrante_panel.dart';
import 'package:inces_lms_app/screens/admin/cpanel_programas_panel.dart';
import 'package:inces_lms_app/theme/inces_theme.dart';
import 'package:inces_lms_app/widgets/andamiaje.dart';
import 'package:inces_lms_app/widgets/cuadrante_grid.dart';

import 'support/fake_curriculo_gateway.dart';
import 'support/fake_cuadrante_gateway.dart';

/// Diagnóstico del Lote 2 — scroll en móvil (Redmi 10C, 360×740 dp).
///
/// Cada panel se monta **dentro de `ContenidoSeccion`**, que es su padre real.
/// Si un módulo «no desliza» en el dispositivo, este archivo debe reproducirlo
/// antes de tocar código: el fallo (o la excepción de layout) localiza la capa
/// culpable sin adivinar.
void main() {
  const ventanaRedmi10C = Size(360, 740);

  Future<void> sinExcepcionesDeLayout(WidgetTester tester, String etapa) async {
    final e = tester.takeException();
    expect(
      e,
      isNull,
      reason: 'Excepción de layout en «$etapa»: $e',
    );
  }

  group('Cursos y PNA', () {
    testWidgets('la lista desliza a 360×740 dentro de ContenidoSeccion',
        (tester) async {
      tester.view.physicalSize = ventanaRedmi10C;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final programas = List.generate(
        8,
        (i) => ProgramaConTotales(
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
        ),
      );
      final gateway = FakeCurriculoGateway()
        ..programas = programas
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
      await tester.pumpAndSettle();
      await sinExcepcionesDeLayout(tester, 'carga');

      expect(find.text('Programa de Prueba Número 0'), findsOneWidget);

      // Arrastra hacia arriba de forma repetida (como haría un dedo): el
      // contenido debe desplazarse hasta que el último programa entre en
      // pantalla.
      for (var i = 0;
          i < 10 &&
              find.text('Programa de Prueba Número 7').evaluate().isEmpty;
          i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      await sinExcepcionesDeLayout(tester, 'arrastre');

      expect(
        find.text('Programa de Prueba Número 7'),
        findsOneWidget,
        reason: 'Tras arrastrar el último programa debe ser visible; '
            'si no, la lista no desliza (el bug reportado en el Redmi 10C).',
      );
    });
  });

  group('Cuadrante de Horarios', () {
    late FakeCuadranteGateway gateway;
    late CuadranteRepository repo;

    setUp(() {
      gateway = FakeCuadranteGateway();
      repo = CuadranteRepository(gateway: gateway);
    });

    ClaseCuadrante claseEn(int dia, int bloque) => ClaseCuadrante(
          id: 'c-$dia-$bloque',
          seccionId: 's1',
          docenteId: 'd1',
          aulaId: 'a1',
          dia: dia,
          bloque: bloque,
          turno: bloque <= 6 ? Turno.manana : Turno.tarde,
          activa: true,
          periodo: 'SA26-2',
          programaId: 'prog1',
          programa: 'Soldadura',
          materiaId: 'm1',
          materia: 'Soldadura por Arco',
          seccion: 'SC-01',
          aula: 'Taller A',
          docente: 'Luis Márquez',
        );

    testWidgets('la rejilla desliza verticalmente a 360×740', (tester) async {
      tester.view.physicalSize = ventanaRedmi10C;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Semana completa: clase en cada día y en el bloque 1 (mañana) y el 12
      // (tarde), para que la rejilla tenga contenido arriba y abajo.
      gateway.periodos = [
        const Periodo(id: 'p1', codigo: 'SA26-2', activo: true, vigente: true),
      ];
      gateway.rejillaDevuelta = RejillaCuadrante(
        periodo: 'SA26-2',
        aulas: const [
          Aula(
            id: 'a1',
            nombre: 'Taller A',
            capacidad: 12,
            esTaller: true,
            activa: true,
          ),
        ],
        docentes: const [DocenteResumen(id: 'd1', nombre: 'Luis Márquez')],
        clases: [
          for (var dia = 1; dia <= 6; dia++) ...[
            claseEn(dia, 1),
            claseEn(dia, 12),
          ],
        ],
        guardias: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: IncesTheme.claro(),
          home: Scaffold(
            body: SafeArea(
              child: ContenidoSeccion(
                migas: const ['Inicio', 'Control de aulas', 'Cuadrante'],
                child: CpanelCuadrantePanel(repositorio: repo),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // DIAG: sin captura

      // La rejilla semanal existe (no el modo «por día»).
      expect(find.byType(CuadranteGrid), findsOneWidget);

      // Arrastra hacia arriba sobre la rejilla: el contenido vertical debe
      // desplazarse. Se mide la posición de un chip de la mañana antes y
      // después.
      final rejilla = find.byType(CuadranteGrid);
      final centro = tester.getCenter(rejilla);
      // Posición vertical de un chip de la última fila (bloque 12, tarde):
      // sólo visible si la rejilla desliza.
      final chipTarde = find.text('Soldadura por Arco').last;
      final antes = tester.getRect(chipTarde).top;

      for (var i = 0; i < 6; i++) {
        await tester.dragFrom(centro, const Offset(0, -350));
        await tester.pumpAndSettle();
        if (tester.getRect(chipTarde).top < antes - 150) break;
      }
      // DIAG: se deja consumir al framework para ver el dump completo

      final despues = tester.getRect(chipTarde).top;
      expect(
        despues,
        lessThan(antes - 100),
        reason: 'La rejilla debe desplazarse verticalmente con el dedo; '
            'si su contenido no se mueve, el «no desliza» del Redmi 10C '
            'está reproducido aquí.',
      );
    });
  });
}
