import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inces_lms_app/models/archivo.dart';
import 'package:inces_lms_app/models/materia.dart';
import 'package:inces_lms_app/models/cuadrante.dart';
import 'package:inces_lms_app/models/programa.dart';
import 'package:inces_lms_app/repositories/archivos_repository.dart';
import 'package:inces_lms_app/models/seccion.dart';
import 'package:inces_lms_app/repositories/cuadrante_repository.dart';
import 'package:inces_lms_app/repositories/secciones_repository.dart';
import 'package:inces_lms_app/repositories/curriculo_repository.dart';
import 'package:inces_lms_app/screens/admin/cpanel_aulas_panel.dart';
import 'package:inces_lms_app/screens/admin/cpanel_aulas_virtuales_panel.dart';
import 'package:inces_lms_app/screens/admin/cpanel_cuadrante_panel.dart';
import 'package:inces_lms_app/screens/admin/cpanel_explorador_archivos_panel.dart';
import 'package:inces_lms_app/screens/admin/cpanel_guardias_panel.dart';
import 'package:inces_lms_app/screens/admin/cpanel_pna_panel.dart';
import 'package:inces_lms_app/screens/admin/cpanel_programas_panel.dart';
import 'package:inces_lms_app/screens/gestor_documental_panel.dart';
import 'package:inces_lms_app/theme/inces_theme.dart';
import 'package:inces_lms_app/widgets/andamiaje.dart';
import 'package:inces_lms_app/widgets/cuadrante_grid.dart';

import 'support/fake_archivos_gateway.dart';
import 'support/fake_secciones_gateway.dart';
import 'support/fake_curriculo_gateway.dart';
import 'support/fake_selector_archivos.dart';
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
    expect(e, isNull, reason: 'Excepción de layout en «$etapa»: $e');
  }

  group('Cursos y PNA', () {
    testWidgets('la lista desliza a 360×740 dentro de ContenidoSeccion', (
      tester,
    ) async {
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
      for (
        var i = 0;
        i < 10 && find.text('Programa de Prueba Número 7').evaluate().isEmpty;
        i++
      ) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      await sinExcepcionesDeLayout(tester, 'arrastre');

      expect(
        find.text('Programa de Prueba Número 7'),
        findsOneWidget,
        reason:
            'Tras arrastrar el último programa debe ser visible; '
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
      await sinExcepcionesDeLayout(tester, 'carga');

      // La rejilla semanal existe (no el modo «por día»).
      expect(find.byType(CuadranteGrid), findsOneWidget);

      // **La forma cambió a este ancho y la prueba cambia con ella.** Desde el
      // 2026-10-29, a 360 px la rejilla no pinta la tabla de 956 px: pinta la
      // lista de bloques del día (ver `CuadranteGrid.cabeComoTabla`). Lo que se
      // sigue comprobando es lo mismo que reportó el usuario —que **desliza con
      // el dedo**—, ahora midiendo que el bloque 12, que arranca fuera de
      // pantalla, llega a verse.
      final rejilla = find.byType(CuadranteGrid);
      final centro = tester.getCenter(rejilla);
      final bloque12 = find.text('B12');

      for (var i = 0; i < 8; i++) {
        if (bloque12.evaluate().isNotEmpty) break;
        await tester.dragFrom(centro, const Offset(0, -350));
        await tester.pumpAndSettle();
      }
      await sinExcepcionesDeLayout(tester, 'arrastre vertical');

      expect(
        bloque12,
        // `findsWidgets` y no `findsOneWidget`: en modo compacto la lista pinta
        // los seis días seguidos, así que B12 existe una vez por día. Lo que la
        // prueba afirma es que se llega al final del día arrastrando.
        findsWidgets,
        reason:
            'La rejilla debe desplazarse verticalmente con el dedo hasta el '
            'final del día; si su contenido no se mueve, el «no desliza» del '
            'Redmi 10C está reproducido aquí.',
      );
    });
  });

  group('Horario PNA', () {
    late FakeCuadranteGateway gateway;
    late CuadranteRepository repo;

    setUp(() {
      gateway = FakeCuadranteGateway();
      repo = CuadranteRepository(gateway: gateway);
    });

    ClaseCuadrante clasePnaEn(int dia, int bloque) => ClaseCuadrante(
      id: 'c-pna-$dia-$bloque',
      seccionId: 'sec-pna',
      docenteId: 'd1',
      aulaId: 'a1',
      dia: dia,
      bloque: bloque,
      turno: bloque <= 6 ? Turno.manana : Turno.tarde,
      activa: true,
      periodo: '2026-1',
      programaId: 'cur-int-01',
      programa: 'PNA - Formación Dual',
      materiaId: 'mat-1',
      materia: 'Seguridad Industrial PNA',
      seccion: 'PNA-01',
      aula: 'Taller de Soldadura Cabina A',
      docente: 'Carlos Facilitador',
    );

    testWidgets('la rejilla PNA desliza verticalmente a 360×740', (
      tester,
    ) async {
      tester.view.physicalSize = ventanaRedmi10C;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      gateway.periodos = [
        const Periodo(id: 'p1', codigo: '2026-1', activo: true, vigente: true),
      ];
      gateway.rejillaDevuelta = RejillaCuadrante(
        periodo: '2026-1',
        aulas: const [
          Aula(
            id: 'a1',
            nombre: 'Taller de Soldadura Cabina A',
            capacidad: 15,
            esTaller: true,
            activa: true,
          ),
        ],
        docentes: const [
          DocenteResumen(id: 'd1', nombre: 'Carlos Facilitador'),
        ],
        clases: [
          for (var dia = 1; dia <= 6; dia++) ...[
            clasePnaEn(dia, 1),
            clasePnaEn(dia, 12),
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
                migas: const ['Inicio', 'Control de aulas', 'Horario PNA'],
                child: CpanelPnaPanel(repositorio: repo),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await sinExcepcionesDeLayout(tester, 'carga');

      expect(find.byType(CuadranteGrid), findsOneWidget);

      final rejilla = find.byType(CuadranteGrid);
      final centro = tester.getCenter(rejilla);
      // Mismo cambio de forma que en el cuadrante: a este ancho se pinta la
      // lista de bloques del día, así que se mide que el final del día llegue a
      // verse al arrastrar.
      final bloque12 = find.text('B12');

      for (var i = 0; i < 8; i++) {
        if (bloque12.evaluate().isNotEmpty) break;
        await tester.dragFrom(centro, const Offset(0, -350));
        await tester.pumpAndSettle();
      }
      await sinExcepcionesDeLayout(tester, 'arrastre vertical');

      expect(
        bloque12,
        findsWidgets,
        reason: 'La rejilla PNA debe desplazarse verticalmente con el dedo.',
      );
    });
  });

  group('Guardias Docentes (matriz semanal)', () {
    late FakeCuadranteGateway gateway;
    late CuadranteRepository repo;

    setUp(() {
      gateway = FakeCuadranteGateway();
      repo = CuadranteRepository(gateway: gateway);
    });

    testWidgets('la matriz de guardias desliza verticalmente a 360×740', (
      tester,
    ) async {
      tester.view.physicalSize = ventanaRedmi10C;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      gateway.periodos = [
        const Periodo(id: 'p1', codigo: 'SA26-2', activo: true, vigente: true),
      ];
      gateway.rejillaDevuelta = const RejillaCuadrante(
        periodo: 'SA26-2',
        aulas: [
          Aula(
            id: 'a1',
            nombre: 'Taller A',
            capacidad: 12,
            esTaller: true,
            activa: true,
          ),
        ],
        docentes: [DocenteResumen(id: 'd1', nombre: 'Luis Márquez')],
      );
      gateway.guardias = const [
        Guardia(
          id: 'g1',
          docenteId: 'd1',
          aulaId: 'a1',
          periodo: 'SA26-2',
          dia: 1,
          bloque: 1,
          turno: Turno.manana,
          activa: true,
        ),
        Guardia(
          id: 'g2',
          docenteId: 'd1',
          aulaId: 'a1',
          periodo: 'SA26-2',
          dia: 6,
          bloque: 12,
          turno: Turno.tarde,
          activa: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: IncesTheme.claro(),
          home: Scaffold(
            body: SafeArea(
              child: ContenidoSeccion(
                migas: const [
                  'Inicio',
                  'Control de aulas',
                  'Guardias Docentes (MTP)',
                ],
                child: CpanelGuardiasPanel(repositorio: repo),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1) El contenido de la matriz (dentro de su scroll vertical propio)
      //    debe desplazarse al arrastrar sobre ella.
      // Punto visible sobre la matriz: la matriz arranca bajo la cabecera,
      // así que su centro absoluto puede quedar fuera del viewport.
      const centro = Offset(180, 500);
      final chipTarde = find.text('Luis Márquez').last;
      final antesChip = tester.getRect(chipTarde).top;
      for (var i = 0; i < 8; i++) {
        await tester.dragFrom(centro, const Offset(0, -350));
        await tester.pumpAndSettle();
        if (tester.getRect(chipTarde).top < antesChip - 150) break;
      }
      await sinExcepcionesDeLayout(tester, 'arrastre de la matriz');
      expect(
        tester.getRect(chipTarde).top,
        lessThan(antesChip - 100),
        reason:
            'La matriz de guardias debe desplazar su contenido verticalmente.',
      );

      // 2) En móvil el panel completo también desliza: arrastrando desde la
      //    zona de filtros, la cabecera sale de pantalla. Se vuelve arriba
      //    primero (el paso 1 pudo dejar el panel al tope del scroll).
      final titulo = find.text('GUARDIAS DOCENTES (MTP)');
      expect(titulo, findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await tester.dragFrom(const Offset(180, 400), const Offset(0, 800));
        await tester.pumpAndSettle();
        if (tester.getRect(titulo).top >= 0) break;
      }
      final antesTitulo = tester.getRect(titulo).top;
      final centroFiltros = Offset(
        tester.getCenter(titulo).dx,
        tester.getCenter(titulo).dy + 120,
      );
      for (var i = 0; i < 6; i++) {
        await tester.dragFrom(centroFiltros, const Offset(0, -350));
        await tester.pumpAndSettle();
        if (tester.getRect(titulo).top < antesTitulo - 100) break;
      }
      await sinExcepcionesDeLayout(tester, 'arrastre del panel');
      expect(
        tester.getRect(find.text('GUARDIAS DOCENTES (MTP)')).top,
        lessThan(antesTitulo - 100),
        reason: 'El panel de guardias debe desplazarse verticalmente en móvil.',
      );
    });
  });

  group('Espacios y Aulas', () {
    late FakeCuadranteGateway gateway;
    late CuadranteRepository repo;

    setUp(() {
      gateway = FakeCuadranteGateway();
      repo = CuadranteRepository(gateway: gateway);
    });

    testWidgets('la lista de aulas desliza a 360×740', (tester) async {
      tester.view.physicalSize = ventanaRedmi10C;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      gateway.periodos = [
        const Periodo(id: 'p1', codigo: 'SA26-2', activo: true, vigente: true),
      ];
      gateway.aulas = [
        for (var i = 0; i < 8; i++)
          Aula(
            id: 'a-$i',
            nombre: 'Espacio de Prueba Número $i',
            capacidad: 15,
            esTaller: i.isEven,
            activa: true,
          ),
      ];
      gateway.totalAulas = 8;

      await tester.pumpWidget(
        MaterialApp(
          theme: IncesTheme.claro(),
          home: Scaffold(
            body: SafeArea(
              child: ContenidoSeccion(
                migas: const ['Inicio', 'Control de aulas', 'Espacios'],
                child: CpanelAulasPanel(repositorio: repo),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await sinExcepcionesDeLayout(tester, 'carga');

      expect(find.text('Espacio de Prueba Número 0'), findsOneWidget);

      for (
        var i = 0;
        i < 10 && find.text('Espacio de Prueba Número 7').evaluate().isEmpty;
        i++
      ) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      await sinExcepcionesDeLayout(tester, 'arrastre');

      expect(
        find.text('Espacio de Prueba Número 7'),
        findsOneWidget,
        reason: 'La lista de aulas debe deslizar hasta el último espacio.',
      );
    });
  });

  group('Archivos del Centro (explorador)', () {
    testWidgets('la lista de archivos desliza a 360×740', (tester) async {
      tester.view.physicalSize = ventanaRedmi10C;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final gateway = FakeArchivosGateway()
        ..archivosMios = [
          for (var i = 0; i < 10; i++)
            archivoEjemplo(
              id: 'arch-$i',
              nombreOriginal: 'Archivo de Prueba Número $i.pdf',
              entityType: TipoEntidadArchivo.driveFile,
              estado: EstadoArchivo.confirmed,
              tamanoBytes: 1024 * (i + 1),
            ),
        ];

      await tester.pumpWidget(
        MaterialApp(
          theme: IncesTheme.claro(),
          home: Scaffold(
            body: SafeArea(
              child: ContenidoSeccion(
                migas: const ['Inicio', 'Gestión académica', 'Archivos'],
                child: CpanelExploradorArchivosPanel(
                  repositorio: ArchivosRepository(gateway: gateway),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // El GridView es perezoso: los archivos están bajo el banner
      // informativo, así que se arrastra desde un punto visible y luego se
      // comprueba el último.
      for (
        var i = 0;
        i < 14 &&
            find.text('Archivo de Prueba Número 9.pdf').evaluate().isEmpty;
        i++
      ) {
        await tester.dragFrom(const Offset(180, 600), const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      await sinExcepcionesDeLayout(tester, 'arrastre');

      expect(
        find.text('Archivo de Prueba Número 9.pdf'),
        findsOneWidget,
        reason: 'La lista de archivos debe deslizar hasta el último.',
      );
    });
  });

  group('Gestor documental (tarjeta de archivo)', () {
    testWidgets('desliza a 360×740 con archivos confirmados', (tester) async {
      tester.view.physicalSize = ventanaRedmi10C;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final gateway = FakeArchivosGateway()
        ..archivosListados = [
          for (var i = 0; i < 8; i++)
            archivoEjemplo(
              id: 'doc-$i',
              nombreOriginal: 'Documento de Prueba Número $i.pdf',
              estado: EstadoArchivo.confirmed,
              tamanoBytes: 248_512 + i,
              confirmadoEn: '2026-09-18T12:05:00.000Z',
            ),
        ];

      await tester.pumpWidget(
        MaterialApp(
          theme: IncesTheme.claro(),
          home: Scaffold(
            body: SafeArea(
              child: ContenidoSeccion(
                child: GestorDocumentalPanel(
                  entityType: TipoEntidadArchivo.taskSubmission,
                  entidadId: 'tarea-1',
                  repositorio: ArchivosRepository(gateway: gateway),
                  selector: FakeSelectorDeArchivos(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (
        var i = 0;
        i < 12 &&
            find.text('Documento de Prueba Número 7.pdf').evaluate().isEmpty;
        i++
      ) {
        await tester.dragFrom(const Offset(180, 600), const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      await sinExcepcionesDeLayout(tester, 'arrastre');

      expect(
        find.text('Documento de Prueba Número 7.pdf'),
        findsOneWidget,
        reason: 'El gestor documental debe deslizar hasta el último archivo.',
      );
    });
  });

  group('Aulas Virtuales (admin)', () {
    testWidgets('lista secciones, desliza y abre el aula a 360×740',
        (tester) async {
      tester.view.physicalSize = ventanaRedmi10C;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final secciones = FakeSeccionesGateway()
        ..paginaDevuelta = PaginaSecciones(
          secciones: [
            for (var i = 0; i < 8; i++)
              Seccion(
                id: 'sec-$i',
                programaId: 'prog-1',
                materiaId: 'mat-1',
                periodo: 'SA26-2',
                nombre: 'S${i + 1}',
                codigoAula: 'COD${(i + 1).toString().padLeft(5, 'A')}',
                cupoMaximo: 20,
                activa: true,
              ),
          ],
          total: 8,
          limite: 50,
          desplazamiento: 0,
        );
      final curriculo = FakeCurriculoGateway()
        ..programas = const [
          ProgramaConTotales(
            id: 'prog-1',
            codigo: 'CUR-TES-01',
            nombre: 'Programa de Prueba',
            tipo: TipoPrograma.cursoLibre,
            requierePasantia: false,
            activo: true,
            totalMaterias: 1,
            totalPeriodos: 1,
          ),
        ]
        ..totalProgramas = 1
        ..materias = const [
          Materia(
            id: 'mat-1',
            codigo: 'MAT-TES-01',
            nombre: 'Materia de Prueba',
            horasAcademicas: 40,
          ),
        ]
        ..totalMaterias = 1;

      await tester.pumpWidget(
        MaterialApp(
          theme: IncesTheme.claro(),
          home: Scaffold(
            body: SafeArea(
              child: ContenidoSeccion(
                migas: const ['Inicio', 'Dar clase', 'Aulas Virtuales'],
                child: CpanelAulasVirtualesPanel(
                  seccionesRepo: SeccionesRepository(gateway: secciones),
                  curriculoRepo: CurriculoRepository(gateway: curriculo),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await sinExcepcionesDeLayout(tester, 'carga');

      // Nombres resueltos desde los catálogos.
      expect(find.text('Materia de Prueba (S1)'), findsOneWidget);

      // El código de aula se lee en la tarjeta: es lo que el docente dicta.
      expect(find.textContaining('código CODAAAA1'), findsOneWidget);

      // La lista desliza hasta la última sección.
      for (var i = 0;
          i < 10 && find.text('Materia de Prueba (S8)').evaluate().isEmpty;
          i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      await sinExcepcionesDeLayout(tester, 'arrastre');
      expect(find.text('Materia de Prueba (S8)'), findsOneWidget);

      // Volver arriba: la lista es perezosa y S1 ya se desmontó al fondo.
      for (var i = 0;
          i < 10 && find.text('Materia de Prueba (S1)').evaluate().isEmpty;
          i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, 600));
        await tester.pumpAndSettle();
      }

      // Abrir el aula de la primera sección: aparece la puerta de vuelta.
      await tester.tap(find.text('Materia de Prueba (S1)').first);
      await tester.pumpAndSettle();
            await sinExcepcionesDeLayout(tester, 'apertura del aula');

      expect(find.text('Volver a las aulas'), findsOneWidget);
    });
  });
}