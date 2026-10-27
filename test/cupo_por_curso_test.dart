import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inces_lms_app/core/cache_lecturas.dart';
import 'package:inces_lms_app/core/gateways/aspirante_gateway.dart';
import 'package:inces_lms_app/models/aspirante_model.dart';
import 'package:inces_lms_app/models/inscripcion_campo.dart';
import 'package:inces_lms_app/models/programa.dart';
import 'package:inces_lms_app/repositories/aspirante_repository.dart';
import 'package:inces_lms_app/repositories/curriculo_repository.dart';
import 'package:inces_lms_app/screens/admin/cpanel_programas_panel.dart';
import 'package:inces_lms_app/screens/landing_page.dart';

import 'support/fake_curriculo_gateway.dart';

class _FakeAspiranteGateway implements AspiranteGateway {
  List<OpcionCampo> programas = const [];

  @override
  Future<List<OpcionCampo>> programasDisponibles() async => programas;

  @override
  Future<Map<String, dynamic>?> periodoVigente() async => null;

  @override
  Future<AspiranteModel?> porCedula(String cedula) async => null;

  @override
  Future<List<AspiranteModel>> todos() async => const [];

  @override
  Future<AspiranteModel?> porId(String id) async => null;

  @override
  Future<AspiranteModel?> miFicha() async => null;

  @override
  Future<AspiranteModel> crear(AspiranteModel m) async => m;

  @override
  Future<AspiranteModel> actualizar(String id, Map<String, dynamic> d) async =>
      throw UnimplementedError();

  @override
  Future<void> eliminar(String id) async {}

  @override
  Future<String> precheck({required String cedula, required String email}) async => 'OK';

  @override
  Future<bool> existeEmail(String email) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    cacheDeLecturas.invalidarTodo();
  });

  group('D5 — Cupo por curso, no global', () {
    testWidgets('Tarjeta de curso en Landing muestra cupos disponibles cuando está activa',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeGateway = _FakeAspiranteGateway()
        ..programas = const [
          OpcionCampo(
            valor: 'prog-1',
            etiqueta: 'Soldadura Básica',
            cupo: 15,
            cuposDisponibles: 12,
            mostrarDisponibilidad: true,
          ),
          OpcionCampo(
            valor: 'prog-2',
            etiqueta: 'Electricidad Industrial',
            cupo: 20,
            cuposDisponibles: 20,
            mostrarDisponibilidad: false,
          ),
        ];

      final repo = AspiranteRepository(gateway: fakeGateway);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LandingPage(aspiranteRepository: repo),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Quedan 12 de 15 cupos'),
        500,
        scrollable: find.byType(Scrollable).first,
      );

      // Debe mostrar los cupos del curso 1
      expect(find.text('Quedan 12 de 15 cupos'), findsOneWidget);

      // El curso 2 tiene mostrarDisponibilidad: false, no debe mostrar su contador
      expect(find.text('Quedan 20 cupos'), findsNothing);
    });

    testWidgets('Panel de programas muestra X de Y cupos y estado de visibilidad',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeGateway = FakeCurriculoGateway()
        ..programas = [
          const ProgramaConTotales(
            id: 'prog-1',
            codigo: 'CUR-SOL-01',
            nombre: 'Soldadura Básica Universal',
            tipo: TipoPrograma.cursoLibre,
            requierePasantia: false,
            activo: true,
            totalMaterias: 1,
            totalPeriodos: 1,
            cupo: 15,
            cuposOcupados: 3,
            mostrarDisponibilidad: true,
          ),
          const ProgramaConTotales(
            id: 'prog-2',
            codigo: 'CUR-ELE-01',
            nombre: 'Electricidad Básica',
            tipo: TipoPrograma.cursoLibre,
            requierePasantia: false,
            activo: true,
            totalMaterias: 1,
            totalPeriodos: 1,
            cupo: 25,
            cuposOcupados: 0,
            mostrarDisponibilidad: false,
          ),
        ]
        ..totalProgramas = 2;

      final repo = CurriculoRepository(gateway: fakeGateway);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CpanelProgramasPanel(repositorio: repo),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica formato "X de Y cupos"
      expect(find.text('3 de 15 cupos'), findsOneWidget);
      expect(find.text('0 de 25 cupos'), findsOneWidget);

      // Verifica indicador cuando está oculta la disponibilidad
      expect(find.text('Cupos ocultos'), findsOneWidget);
    });

    testWidgets('Diálogo de edición de programa permite cambiar el cupo y visibilidad',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeGateway = FakeCurriculoGateway()
        ..programas = [
          const ProgramaConTotales(
            id: 'prog-1',
            codigo: 'CUR-SOL-01',
            nombre: 'Soldadura Básica Universal',
            tipo: TipoPrograma.cursoLibre,
            requierePasantia: false,
            activo: true,
            totalMaterias: 1,
            totalPeriodos: 1,
            cupo: 25,
            cuposOcupados: 0,
            mostrarDisponibilidad: true,
          ),
        ]
        ..totalProgramas = 1;

      final repo = CurriculoRepository(gateway: fakeGateway);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CpanelProgramasPanel(repositorio: repo),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Abrir diálogo de edición de programa
      final btnEditar = find.byIcon(Icons.edit_note_outlined).first;
      await tester.tap(btnEditar);
      await tester.pumpAndSettle();

      // Diálogo abierto
      expect(find.text('Editar programa formativo'), findsOneWidget);
      expect(find.text('Cupo máximo del curso'), findsOneWidget);
      expect(find.text('Disponibilidad de cupos visible'), findsOneWidget);

      // Modificar cupo a 15
      final campoCupo = find.byKey(const Key('campo-cupo-programa'));
      await tester.enterText(campoCupo, '15');
      await tester.pumpAndSettle();

      // Guardar cambios
      final btnGuardar = find.widgetWithText(FilledButton, 'Guardar cambios');
      await tester.tap(btnGuardar);
      await tester.pumpAndSettle();

      // Verificar que el gateway recibió el cambio
      expect(fakeGateway.ultimosCambios?.cupo, equals(15));
    });
  });
}
