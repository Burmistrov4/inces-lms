import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inces_lms_app/theme/inces_theme.dart';
import 'package:inces_lms_app/widgets/barra_acciones_superiores.dart';

void main() {
  group('BarraAccionesSuperiores · renderizado y disparadores', () {
    testWidgets('renderiza botones de acción e insignias institucionales', (tester) async {
      bool inscribirPulsado = false;
      bool asignarClasePulsado = false;
      bool verAulasPulsado = false;
      bool reportePulsado = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: IncesTheme.claro(),
          home: Scaffold(
            body: BarraAccionesSuperiores(
              onInscribirAspirante: () => inscribirPulsado = true,
              onAsignarClase: () => asignarClasePulsado = true,
              onVerAulas: () => verAulasPulsado = true,
              onGenerarReporte: () => reportePulsado = true,
            ),
          ),
        ),
      );

      expect(find.text('+ Inscribir Aspirante'), findsOneWidget);
      expect(find.text('+ Asignar Clase'), findsOneWidget);
      expect(find.text('Ver Aulas'), findsOneWidget);
      expect(find.text('Generar Reporte'), findsOneWidget);
      expect(find.text('Período: SA26-2'), findsOneWidget);
      expect(find.text('Sistema: 100% En Línea'), findsOneWidget);

      await tester.tap(find.text('+ Inscribir Aspirante'));
      await tester.pump();
      expect(inscribirPulsado, isTrue);

      await tester.tap(find.text('+ Asignar Clase'));
      await tester.pump();
      expect(asignarClasePulsado, isTrue);

      await tester.tap(find.text('Ver Aulas'));
      await tester.pump();
      expect(verAulasPulsado, isTrue);

      await tester.tap(find.text('Generar Reporte'));
      await tester.pump();
      expect(reportePulsado, isTrue);
    });

    testWidgets('mostrarDialogoReportes abre el modal de opciones de reportes', (tester) async {
      bool verInscripcionesLlamado = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: IncesTheme.claro(),
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  BarraAccionesSuperiores.mostrarDialogoReportes(
                    context,
                    onVerInscripciones: () => verInscripcionesLlamado = true,
                  );
                },
                child: const Text('Abrir Modal'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Abrir Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Generación de Reportes'), findsOneWidget);
      expect(find.text('Inscripciones y Cupos Oficiales'), findsOneWidget);
      expect(find.text('Horarios y Ocupación de Espacios'), findsOneWidget);
      expect(find.text('Trazabilidad de Accesos y Seguridad'), findsOneWidget);

      await tester.tap(find.text('Inscripciones y Cupos Oficiales'));
      await tester.pumpAndSettle();
      expect(verInscripcionesLlamado, isTrue);
    });

    testWidgets('BarraAccionesSuperiores.docente renderiza botones propios del instructor', (tester) async {
      bool aulasPulsado = false;
      bool asistenciaPulsado = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: IncesTheme.claro(),
          home: Scaffold(
            body: BarraAccionesSuperiores.docente(
              onMisAulas: () => aulasPulsado = true,
              onAsistencia: () => asistenciaPulsado = true,
              onCalificaciones: () {},
              onMiHorario: () {},
            ),
          ),
        ),
      );

      expect(find.text('Mis Aulas'), findsOneWidget);
      expect(find.text('Pasar lista'), findsOneWidget);
      expect(find.text('Calificaciones'), findsOneWidget);
      expect(find.text('Mi Horario'), findsOneWidget);
      expect(find.text('Portal Docente: En Línea'), findsOneWidget);

      await tester.tap(find.text('Mis Aulas'));
      await tester.pump();
      expect(aulasPulsado, isTrue);

      await tester.tap(find.text('Pasar lista'));
      await tester.pump();
      expect(asistenciaPulsado, isTrue);
    });

    testWidgets('BarraAccionesSuperiores.estudiante renderiza botones propios del aprendiz', (tester) async {
      bool ofertasPulsado = false;
      bool planillaPulsado = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: IncesTheme.claro(),
          home: Scaffold(
            body: BarraAccionesSuperiores.estudiante(
              onOfertasCupos: () => ofertasPulsado = true,
              onMisAulas: () {},
              onAsistencia: () {},
              onDescargarPlanilla: () => planillaPulsado = true,
            ),
          ),
        ),
      );

      expect(find.text('Ofertas de Cupos'), findsOneWidget);
      expect(find.text('Mis Aulas'), findsOneWidget);
      expect(find.text('Marcar Asistencia'), findsOneWidget);
      expect(find.text('Planilla PDF'), findsOneWidget);
      expect(find.text('Portal Aprendiz: En Línea'), findsOneWidget);

      await tester.tap(find.text('Ofertas de Cupos'));
      await tester.pump();
      expect(ofertasPulsado, isTrue);

      await tester.tap(find.text('Planilla PDF'));
      await tester.pump();
      expect(planillaPulsado, isTrue);
    });
  });
}
