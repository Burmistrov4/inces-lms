import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inces_lms_app/models/inscripcion.dart';
import 'package:inces_lms_app/repositories/inscripcion_repository.dart';
import 'package:inces_lms_app/screens/aspirante_dashboard.dart';
import 'package:inces_lms_app/screens/mis_inscripciones_panel.dart';
import 'package:inces_lms_app/theme/inces_theme.dart';

import 'support/fake_inscripcion_gateway.dart';

/// Monta un panel del aspirante y espera la carga inicial.
///
/// Igual que en `cpanel_test.dart`: `MaterialApp` con el tema institucional y
/// `Scaffold(body: panel)`. No se usa `pumpAndSettle` durante la carga porque el
/// indicador de progreso es una animación infinita.
Future<void> montarPanel(WidgetTester tester, Widget panel) async {
  await tester.pumpWidget(
    MaterialApp(theme: IncesTheme.claro(), home: Scaffold(body: panel)),
  );
  await tester.pump();
  await tester.pump();
}

/// Deja pasar el tiempo para que el SnackBar se cierre solo (sin temporizadores
/// pendientes al terminar el test).
Future<void> cerrarAvisos(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 8));
  await tester.pump();
}

/// Busca un botón cuyo `label` contiene el texto indicado, aunque esté
/// construido con el constructor `.icon` (su runtimeType es un subtipo privado
/// `_FilledButtonWithIcon`, así que `find.widgetWithText` —que usa `byType`
/// interno— no lo encuentra).
Finder botonFilled(String texto) =>
    find.ancestor(of: find.text(texto), matching: find.bySubtype<FilledButton>());

Finder botonOutlined(String texto) =>
    find.ancestor(of: find.text(texto), matching: find.bySubtype<OutlinedButton>());

void main() {
  group('PanelOfertas (catálogo del estudiante)', () {
    testWidgets('sin secciones abiertas muestra el panel vacío', (tester) async {
      final repo = InscripcionesRepository(
        gateway: FakeInscripcionGateway()..ofertasDevueltas = const [],
      );
      await montarPanel(tester, PanelOfertas(repositorio: repo));
      expect(find.text('No hay secciones abiertas'), findsOneWidget);
    });

    testWidgets('con cupo y sin oferta vigente habilita «Inscribirme»',
        (tester) async {
      final fake = FakeInscripcionGateway()
        ..ofertasDevueltas = [
          ocupacionSeccionEjemplo(
            id: 'sec-1',
            cuposDisponibles: 2,
            cuposOcupados: 3,
            ofertaVigente: false,
          ),
        ];
      final repo = InscripcionesRepository(gateway: fake);
      await montarPanel(tester, PanelOfertas(repositorio: repo));

      final finder = botonFilled('Inscribirme');
      expect(finder, findsOneWidget);
      expect(tester.widget<FilledButton>(finder).onPressed, isNotNull);
      expect(find.text('Asiento en asignación'), findsNothing);
    });

    testWidgets('sin cupos y sin oferta vigente muestra «Sin cupos» deshabilitado',
        (tester) async {
      final fake = FakeInscripcionGateway()
        ..ofertasDevueltas = [
          ocupacionSeccionEjemplo(
            id: 'sec-1',
            cuposDisponibles: 0,
            cuposOcupados: 5,
            ofertaVigente: false,
          ),
        ];
      final repo = InscripcionesRepository(gateway: fake);
      await montarPanel(tester, PanelOfertas(repositorio: repo));

      final finder = botonFilled('Sin cupos');
      expect(finder, findsOneWidget);
      expect(tester.widget<FilledButton>(finder).onPressed, isNull);
      expect(botonFilled('Inscribirme'), findsNothing);
    });

    testWidgets('al pulsar «Inscribirme» delega la sección al repositorio',
        (tester) async {
      final fake = FakeInscripcionGateway()
        ..ofertasDevueltas = [
          ocupacionSeccionEjemplo(
            id: 'sec-1',
            cuposDisponibles: 2,
            cuposOcupados: 3,
            ofertaVigente: false,
          ),
        ];
      final repo = InscripcionesRepository(gateway: fake);
      await montarPanel(tester, PanelOfertas(repositorio: repo));

      await tester.tap(botonFilled('Inscribirme'));
      await tester.pump();
      await cerrarAvisos(tester);

      expect(fake.llamadas, contains('inscribirse:sec-1'));
    });
  });

  group('PanelMisInscripciones (Mis inscripciones)', () {
    testWidgets('sin inscripciones muestra el panel vacío', (tester) async {
      final repo = InscripcionesRepository(
        gateway: FakeInscripcionGateway()..misInscripcionesDevueltas = const [],
      );
      await montarPanel(tester, PanelMisInscripciones(repositorio: repo));
      expect(find.text('Aún no tienes inscripciones'), findsOneWidget);
    });

    testWidgets('WAITLISTED muestra la posición en la cola y «Renunciar»',
        (tester) async {
      final fake = FakeInscripcionGateway()
        ..misInscripcionesDevueltas = [
          inscripcionDetalladaEjemplo(
            seccionId: 'sec-1',
            estado: EstadoInscripcion.waitlisted,
            posicionEnCola: 3,
          ),
        ];
      final repo = InscripcionesRepository(gateway: fake);
      await montarPanel(tester, PanelMisInscripciones(repositorio: repo));

      expect(find.text('Lugar 3 en la cola'), findsOneWidget);
      expect(botonOutlined('Renunciar'), findsOneWidget);
      expect(botonFilled('Aceptar cupo'), findsNothing);
    });

    testWidgets('WAITLISTED sin posición muestra «En lista de espera»',
        (tester) async {
      final fake = FakeInscripcionGateway()
        ..misInscripcionesDevueltas = [
          inscripcionDetalladaEjemplo(
            seccionId: 'sec-1',
            estado: EstadoInscripcion.waitlisted,
            posicionEnCola: null,
          ),
        ];
      final repo = InscripcionesRepository(gateway: fake);
      await montarPanel(tester, PanelMisInscripciones(repositorio: repo));

      expect(find.text('En lista de espera'), findsOneWidget);
    });

    testWidgets('ENROLLED muestra confirmación y permite renunciar', (tester) async {
      final fake = FakeInscripcionGateway()
        ..misInscripcionesDevueltas = [
          inscripcionDetalladaEjemplo(
            seccionId: 'sec-1',
            estado: EstadoInscripcion.enrolled,
          ),
        ];
      final repo = InscripcionesRepository(gateway: fake);
      await montarPanel(tester, PanelMisInscripciones(repositorio: repo));

      expect(botonOutlined('Renunciar'), findsOneWidget);
      expect(find.text('Tienes tu asiento confirmado en esta sección.'),
          findsOneWidget);
    });

    testWidgets('DROPPED conserva la fila como historial', (tester) async {
      final fake = FakeInscripcionGateway()
        ..misInscripcionesDevueltas = [
          inscripcionDetalladaEjemplo(
            seccionId: 'sec-1',
            estado: EstadoInscripcion.dropped,
          ),
        ];
      final repo = InscripcionesRepository(gateway: fake);
      await montarPanel(tester, PanelMisInscripciones(repositorio: repo));

      expect(find.text('Renunciaste a este cupo. La fila se conserva como '
          'historial.'),
          findsOneWidget);
    });

    testWidgets('al pulsar «Renunciar» delega la sección al repositorio',
        (tester) async {
      final fake = FakeInscripcionGateway()
        ..misInscripcionesDevueltas = [
          inscripcionDetalladaEjemplo(
            seccionId: 'sec-1',
            estado: EstadoInscripcion.waitlisted,
            posicionEnCola: 2,
          ),
        ];
      final repo = InscripcionesRepository(gateway: fake);
      await montarPanel(tester, PanelMisInscripciones(repositorio: repo));

      await tester.tap(botonOutlined('Renunciar'));
      await tester.pump();
      await cerrarAvisos(tester);

      expect(fake.llamadas, contains('renunciar:sec-1'));
    });
  });

  group('PanelMisInscripciones · estados y presentación', () {
    /// El color base de una insignia, leído del `Icon` que la pinta.
    Color? colorDeIcono(WidgetTester tester, IconData icono) =>
        tester.widget<Icon>(find.byIcon(icono).first).color;

    testWidgets('ENROLLED va en verde y WAITLISTED en azul', (tester) async {
      final fake = FakeInscripcionGateway()
        ..misInscripcionesDevueltas = [
          inscripcionDetalladaEjemplo(
            seccionId: 'sec-mat',
            materia: 'Matriculada',
            estado: EstadoInscripcion.enrolled,
          ),
          inscripcionDetalladaEjemplo(
            seccionId: 'sec-cola',
            materia: 'Cola',
            estado: EstadoInscripcion.waitlisted,
            posicionEnCola: 4,
          ),
        ];
      await montarPanel(
        tester,
        PanelMisInscripciones(
          repositorio: InscripcionesRepository(gateway: fake),
        ),
      );

      final paleta = PaletaInces.deBrillo(Brightness.light);
      expect(
        colorDeIcono(tester, Icons.check_circle_outline),
        paleta.exito,
      );
      expect(
        colorDeIcono(tester, Icons.people_outline),
        paleta.info,
      );
    });

    testWidgets('los matriculados se pintan por ENCIMA de la cola', (tester) async {
      final fake = FakeInscripcionGateway()
        ..misInscripcionesDevueltas = [
          inscripcionDetalladaEjemplo(
            seccionId: 'sec-cola',
            materia: 'Cola',
            estado: EstadoInscripcion.waitlisted,
            posicionEnCola: 2,
          ),
          inscripcionDetalladaEjemplo(
            seccionId: 'sec-mat',
            materia: 'Matriculada',
            estado: EstadoInscripcion.enrolled,
          ),
        ];
      await montarPanel(
        tester,
        PanelMisInscripciones(
          repositorio: InscripcionesRepository(gateway: fake),
        ),
      );

      final yMat = tester.getTopLeft(find.text('Matriculada')).dy;
      final yCola = tester.getTopLeft(find.text('Cola')).dy;

      expect(
        yMat,
        lessThan(yCola),
        reason: 'el matriculado debe leerse antes que la espera',
      );
    });

    testWidgets('con varias tarjetas el panel no desborda la altura acotada',
        (tester) async {
      final fake = FakeInscripcionGateway()
        ..misInscripcionesDevueltas = [
          inscripcionDetalladaEjemplo(
            seccionId: 'sec-1',
            materia: 'Alfa',
            estado: EstadoInscripcion.dropped,
          ),
          inscripcionDetalladaEjemplo(
            seccionId: 'sec-2',
            materia: 'Beta',
            estado: EstadoInscripcion.waitlisted,
            posicionEnCola: 1,
          ),
          inscripcionDetalladaEjemplo(
            seccionId: 'sec-3',
            materia: 'Gamma',
            estado: EstadoInscripcion.enrolled,
          ),
        ];
      await montarPanel(
        tester,
        PanelMisInscripciones(
          repositorio: InscripcionesRepository(gateway: fake),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
