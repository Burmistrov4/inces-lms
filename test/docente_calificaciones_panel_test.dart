import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inces_lms_app/core/errors/app_exception.dart';
import 'package:inces_lms_app/core/gateways/aula_gateway.dart';
import 'package:inces_lms_app/screens/docente/docente_calificaciones_panel.dart';
import 'package:inces_lms_app/screens/libro_calificaciones_panel.dart';
import 'package:inces_lms_app/theme/inces_theme.dart';

import 'support/fake_aula_gateway.dart';

Future<void> montar(
  WidgetTester tester, {
  required FakeAulaGateway gateway,
  bool conPuertaDeContenido = true,
  void Function(String)? onNavegarA,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: IncesTheme.claro(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: DocenteCalificacionesPanel(
            gateway: gateway,
            aulaGateway: conPuertaDeContenido ? gateway : null,
            onNavegarA: onNavegarA,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> asentar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  const seccionSoldadura = AulaResumen(
    seccionId: 'sec-soldadura',
    materia: 'Soldadura Básica',
    seccion: 'U-01',
    programa: 'Soldadura Universal',
  );

  const seccionHerreria = AulaResumen(
    seccionId: 'sec-herreria',
    materia: 'Herrería y Forja',
    seccion: 'H-02',
    programa: 'Metalmecánica',
  );

  const tareaPractica = TareaDeClase(
    id: 't-1',
    seccionId: 'sec-soldadura',
    titulo: 'Práctica SMAW 1G',
    descripcion: 'Cordón de raíz en posición plana con electrodo 6013',
    tipo: TipoTarea.tarea,
    puntosMaximos: 20.0,
    orden: 1,
    estado: EstadoTarea.publicado,
    fechaLimite: '2026-11-15T23:59:59Z',
  );

  const materialLectura = TareaDeClase(
    id: 'mat-1',
    seccionId: 'sec-soldadura',
    titulo: 'Manual de Seguridad Industrial',
    descripcion: 'Normas de uso de careta y equipo de protección',
    tipo: TipoTarea.material,
    puntosMaximos: 0.0,
    orden: 2,
    estado: EstadoTarea.publicado,
  );

  group('DocenteCalificacionesPanel · Estados y Carga', () {
    testWidgets('muestra error y botón de reintentar si falla la lectura de aulas',
        (tester) async {
      final fake = FakeAulaGateway()
        ..errorAlListarAulas = const AppException(
          type: AppErrorType.red,
          message: 'Error de conexión con el centro',
        );

      await montar(tester, gateway: fake);
      await asentar(tester);

      expect(find.text('Error de conexión con el centro'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('muestra panel vacío si no hay secciones asignadas',
        (tester) async {
      final fake = FakeAulaGateway()
        ..misAulasResultado = const MisAulas(esDocente: true, aulas: []);

      await montar(tester, gateway: fake);
      await asentar(tester);

      expect(find.text('Sin secciones asignadas'), findsOneWidget);
    });

    testWidgets('renderiza cabecera, métricas e insignia de área formativa',
        (tester) async {
      final fake = FakeAulaGateway()
        ..misAulasResultado = const MisAulas(
          esDocente: true,
          aulas: [seccionSoldadura],
        )
        ..tareas = [tareaPractica, materialLectura];

      await montar(tester, gateway: fake);
      await asentar(tester);

      expect(find.text('Centro de Calificaciones y Entregas'), findsOneWidget);
      expect(find.text('Metalmecánica e Industria'), findsOneWidget);
      expect(find.text('Soldadura Básica · U-01 · Soldadura Universal'), findsOneWidget);
      // Sólo la tarea evaluativa debe aparecer como calificable
      expect(find.text('Práctica SMAW 1G'), findsOneWidget);
      expect(find.text('20 pts'), findsOneWidget);
      expect(find.text('Calificar'), findsOneWidget);
      // El material informativo NO debe listarse como tarea calificable
      expect(find.text('Manual de Seguridad Industrial'), findsNothing);
    });

    testWidgets('permite filtrar entre secciones cuando hay más de una',
        (tester) async {
      final fake = FakeAulaGateway()
        ..misAulasResultado = const MisAulas(
          esDocente: true,
          aulas: [seccionSoldadura, seccionHerreria],
        )
        ..tareas = [tareaPractica];

      await montar(tester, gateway: fake);
      await asentar(tester);

      expect(find.text('Todas las secciones (2)'), findsOneWidget);
      expect(find.text('Soldadura Básica (U-01)'), findsOneWidget);
      expect(find.text('Herrería y Forja (H-02)'), findsOneWidget);

      // Ambas secciones se ven inicialmente
      expect(find.text('Soldadura Básica · U-01 · Soldadura Universal'), findsOneWidget);
      expect(find.text('Herrería y Forja · H-02 · Metalmecánica'), findsOneWidget);

      // Al pulsar filtro de Herrería, sólo se muestra esa sección
      await tester.tap(find.text('Herrería y Forja (H-02)'));
      await tester.pump();

      expect(find.text('Herrería y Forja · H-02 · Metalmecánica'), findsOneWidget);
      expect(find.text('Soldadura Básica · U-01 · Soldadura Universal'), findsNothing);
    });

    testWidgets('pulsar «Calificar» abre el LibroCalificacionesPanel',
        (tester) async {
      final fake = FakeAulaGateway()
        ..misAulasResultado = const MisAulas(
          esDocente: true,
          aulas: [seccionSoldadura],
        )
        ..tareas = [tareaPractica];

      await montar(tester, gateway: fake);
      await asentar(tester);

      final botonCalificar = find.text('Calificar');
      expect(botonCalificar, findsOneWidget);

      await tester.tap(botonCalificar);
      await asentar(tester);

      expect(find.byType(LibroCalificacionesPanel), findsOneWidget);
    });
  });
}
