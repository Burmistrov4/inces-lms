import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inces_lms_app/core/errors/app_exception.dart';
import 'package:inces_lms_app/core/gateways/aula_gateway.dart';
import 'package:inces_lms_app/screens/aspirante/estudiante_tareas_panel.dart';
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
          child: EstudianteTareasPanel(
            aulasGateway: gateway,
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

  final tareaFutura = TareaDeClase(
    id: 't-futura',
    seccionId: 'sec-soldadura',
    titulo: 'Cálculo de Amperaje SMAW',
    descripcion: 'Determinar rango de corriente según diámetro del electrodo',
    tipo: TipoTarea.tarea,
    puntosMaximos: 20.0,
    orden: 1,
    estado: EstadoTarea.publicado,
    fechaLimite: DateTime.now().add(const Duration(days: 5)).toIso8601String(),
  );

  final tareaVencida = TareaDeClase(
    id: 't-vencida',
    seccionId: 'sec-soldadura',
    titulo: 'Seguridad en Oxicorte',
    descripcion: 'Reporte de válvulas antirretroceso',
    tipo: TipoTarea.tarea,
    puntosMaximos: 20.0,
    orden: 2,
    estado: EstadoTarea.publicado,
    fechaLimite: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
  );

  final tareaCalificada = TareaDeClase(
    id: 't-calificada',
    seccionId: 'sec-soldadura',
    titulo: 'Unión a Tope 1G',
    descripcion: 'Inspección visual de penetración y socavado',
    tipo: TipoTarea.tarea,
    puntosMaximos: 20.0,
    orden: 3,
    estado: EstadoTarea.publicado,
    fechaLimite: DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
  );

  const entregaCalificada = Entrega(
    id: 'e-1',
    tareaId: 't-calificada',
    estado: EstadoEntrega.devuelta,
    esTardia: false,
    notaAsignada: 19.5,
    entregadaEn: '2026-10-10T12:00:00Z',
  );

  group('EstudianteTareasPanel · Hub To-Do de Aprendiz', () {
    testWidgets('muestra error si falla la lectura de aulas', (tester) async {
      final fake = FakeAulaGateway()
        ..errorAlListarAulas = const AppException(
          type: AppErrorType.red,
          message: 'Error al leer matrícula',
        );

      await montar(tester, gateway: fake);
      await asentar(tester);

      expect(find.text('Error al leer matrícula'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('muestra estado vacío amigable si no hay tareas asignadas',
        (tester) async {
      final fake = FakeAulaGateway()
        ..misAulasResultado = const MisAulas(esDocente: false, aulas: []);

      await montar(tester, gateway: fake);
      await asentar(tester);

      expect(find.text('¡Estás al día!'), findsOneWidget);
      expect(find.textContaining('No tienes tareas pendientes por entregar'), findsOneWidget);
    });

    testWidgets('clasifica tareas en Asignadas, Vencidas y Calificadas',
        (tester) async {
      final fake = FakeAulaGateway()
        ..misAulasResultado = const MisAulas(
          esDocente: false,
          aulas: [seccionSoldadura],
        )
        ..tareas = [tareaFutura, tareaVencida, tareaCalificada]
        ..entregas = [entregaCalificada];

      await montar(tester, gateway: fake);
      await asentar(tester);

      // Pestaña inicial: Asignadas
      expect(find.text('Cálculo de Amperaje SMAW'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('Seguridad en Oxicorte'), findsNothing);
      expect(find.text('Unión a Tope 1G'), findsNothing);

      // Cambiar a Vencidas
      await tester.tap(find.text('Sin entregar / Vencidas'));
      await tester.pump();

      expect(find.text('Seguridad en Oxicorte'), findsOneWidget);
      expect(find.text('Sin entregar · Vencida'), findsOneWidget);
      expect(find.text('Cálculo de Amperaje SMAW'), findsNothing);

      // Cambiar a Completadas y Calificadas
      await tester.tap(find.text('Completadas y Calificadas'));
      await tester.pump();

      expect(find.text('Unión a Tope 1G'), findsOneWidget);
      expect(find.text('Nota: 19.5 / 20'), findsOneWidget);
      expect(find.text('Seguridad en Oxicorte'), findsNothing);
    });

    testWidgets('pulsar «Ir al aula» llama a onNavegarA con «Mis aulas»',
        (tester) async {
      String? destinoNavegado;
      final fake = FakeAulaGateway()
        ..misAulasResultado = const MisAulas(
          esDocente: false,
          aulas: [seccionSoldadura],
        )
        ..tareas = [tareaFutura];

      await montar(
        tester,
        gateway: fake,
        onNavegarA: (d) => destinoNavegado = d,
      );
      await asentar(tester);

      final botonAbrir = find.text('Ir al aula');
      expect(botonAbrir, findsOneWidget);

      await tester.tap(botonAbrir);
      await tester.pump();

      expect(destinoNavegado, 'Mis aulas');
    });
  });
}
