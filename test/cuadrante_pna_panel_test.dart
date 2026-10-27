import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inces_lms_app/models/cuadrante.dart';
import 'package:inces_lms_app/repositories/cuadrante_repository.dart';
import 'package:inces_lms_app/screens/admin/cpanel_pna_panel.dart';
import 'package:inces_lms_app/theme/inces_theme.dart';
import 'package:inces_lms_app/widgets/andamiaje.dart';
import 'package:inces_lms_app/widgets/cuadrante_grid.dart';

import 'support/fake_cuadrante_gateway.dart';

/// Pruebas del panel de Horario PNA — Programa Nacional de Aprendizaje (D3, D4).
void main() {
  late FakeCuadranteGateway gateway;
  late CuadranteRepository repo;

  setUp(() {
    gateway = FakeCuadranteGateway();
    repo = CuadranteRepository(gateway: gateway);
  });

  Future<Object?> montar(WidgetTester tester, Widget panel) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: IncesTheme.claro(),
        home: Scaffold(
          body: ContenidoSeccion(
            migas: const ['Inicio', 'Horario PNA'],
            child: panel,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    return tester.takeException();
  }

  void sembrarCatalogo() {
    gateway.periodos = [
      const Periodo(
        id: 'p1',
        codigo: '2026-1',
        activo: true,
        vigente: true,
      ),
    ];
    gateway.rejillaDevuelta = const RejillaCuadrante(
      periodo: '2026-1',
      aulas: [
        Aula(
          id: 'a1',
          nombre: 'Taller de Soldadura Cabina A',
          capacidad: 15,
          esTaller: true,
          activa: true,
        ),
      ],
      docentes: [
        DocenteResumen(id: 'd1', nombre: 'Carlos Facilitador'),
      ],
    );
  }

  group('CpanelPnaPanel', () {
    testWidgets('se monta y muestra título Horario PNA y estado vacío cuando no hay clases',
        (tester) async {
      sembrarCatalogo();
      await montar(tester, CpanelPnaPanel(repositorio: repo));

      expect(find.text('Horario PNA'), findsOneWidget);
      expect(
        find.text('Este período aún no tiene materias PNA asignadas'),
        findsOneWidget,
      );
      expect(find.text('Asignar materia PNA'), findsOneWidget);
    });

    testWidgets('pinta clases PNA en la rejilla cuando existen en el período',
        (tester) async {
      sembrarCatalogo();
      gateway.rejillaDevuelta = const RejillaCuadrante(
        periodo: '2026-1',
        clases: [
          ClaseCuadrante(
            id: 'c-pna-1',
            seccionId: 'sec-pna',
            docenteId: 'd1',
            aulaId: 'a1',
            dia: 1,
            bloque: 2,
            turno: Turno.manana,
            activa: true,
            periodo: '2026-1',
            programaId: 'cur-int-01',
            programa: 'PNA - Formación Dual',
            materiaId: 'mat-1',
            materia: 'Seguridad Industrial PNA',
            seccion: 'PNA-01',
            aula: 'Taller de Soldadura Cabina A',
            docente: 'Carlos Facilitador',
          ),
        ],
        aulas: [
          Aula(
            id: 'a1',
            nombre: 'Taller de Soldadura Cabina A',
            capacidad: 15,
            esTaller: true,
            activa: true,
          ),
        ],
        docentes: [
          DocenteResumen(id: 'd1', nombre: 'Carlos Facilitador'),
        ],
      );

      await montar(tester, CpanelPnaPanel(repositorio: repo));

      expect(find.byType(CuadranteGrid), findsOneWidget);
      expect(find.text('Seguridad Industrial PNA'), findsOneWidget);
      expect(find.textContaining('Carlos Facilitador'), findsOneWidget);
    });

    testWidgets('abre el diálogo para asignar materia PNA', (tester) async {
      sembrarCatalogo();
      await montar(tester, CpanelPnaPanel(repositorio: repo));

      await tester.tap(find.text('Asignar materia PNA'));
      await tester.pumpAndSettle();

      expect(find.text('Asignar materia PNA'), findsAtLeast(1));
      expect(find.textContaining('Docente / Facilitador (Obligatorio)'), findsOneWidget);
      expect(find.textContaining('Aula / Taller (Opcional)'), findsOneWidget);
    });
  });
}
