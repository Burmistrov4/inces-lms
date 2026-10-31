import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/gateways/aula_gateway.dart';
import '../../models/materia.dart';
import '../../models/programa.dart';
import '../../models/seccion.dart';
import '../../repositories/curriculo_repository.dart';
import '../../repositories/secciones_repository.dart';
import '../../services/aula_service.dart';
import '../aula_virtual_dashboard.dart';
import 'dialogo_aprendices.dart';
import '../../widgets/comunes.dart';

/// Panel «Aulas Virtuales» del administrador.
///
/// **La puerta que faltaba.** El administrador creaba cursos, materias y
/// secciones, pero no tenía dónde ver el Aula Virtual (M6) que viven dentro de
/// cada sección: «Mis aulas» es del docente y lista sus asignaciones. Este
/// panel lista **todas** las secciones del centro y abre el aula de cada una
/// en modo docente — añadir anuncios, tareas y evaluar.
///
/// Los nombres de programa y materia se resuelven en local a partir de los
/// catálogos (dos lecturas paginadas), sin tocar el backend: la sección trae
/// los identificadores y el panel ya los sabe pintar.
class CpanelAulasVirtualesPanel extends StatefulWidget {
  const CpanelAulasVirtualesPanel({
    super.key,
    this.seccionesRepo,
    this.curriculoRepo,
    this.aulaGateway,
    this.onNavegarA,
  });

  final SeccionesRepository? seccionesRepo;
  final CurriculoRepository? curriculoRepo;
  final AulaGateway? aulaGateway;
  final void Function(String)? onNavegarA;

  @override
  State<CpanelAulasVirtualesPanel> createState() =>
      _CpanelAulasVirtualesPanelState();
}

class _CpanelAulasVirtualesPanelState extends State<CpanelAulasVirtualesPanel> {
  late final SeccionesRepository _seccionesRepo =
      widget.seccionesRepo ?? SeccionesRepository();
  late final CurriculoRepository _curriculoRepo =
      widget.curriculoRepo ?? CurriculoRepository();

  bool _cargando = true;
  String? _error;

  List<Seccion> _secciones = const [];
  Map<String, String> _nombresProgramas = const {};
  Map<String, String> _nombresMaterias = const {};

  /// Sección con el aula abierta en pantalla. Null = listado.
  Seccion? _abierta;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    final secciones = await _seccionesRepo.listarSecciones(limite: 100);
    if (!mounted) return;
    final falloSecciones = secciones.when(
      success: (_) => null,
      failure: (f) => f.message,
    );
    if (falloSecciones != null) {
      setState(() {
        _cargando = false;
        _error = falloSecciones;
      });
      return;
    }

    // Catálogos para resolver nombres. Un fallo aquí no tumba el panel: se
    // degradan las etiquetas al identificador y la aula sigue abriendo.
    final programas = await _curriculoRepo.listarProgramas(limite: 100);
    final materias = await _curriculoRepo.listarMaterias(limite: 100);
    if (!mounted) return;

    final listaSecciones = secciones.when(
      success: (p) => p.secciones,
      failure: (_) => const <Seccion>[],
    );
    final nombresProgramas = <String, String>{
      for (final p in (programas.when(
        success: (p) => p.programas,
        failure: (_) => const <ProgramaConTotales>[],
      )))
        p.id: p.nombre,
    };
    final nombresMaterias = <String, String>{
      for (final m in (materias.when(
        success: (p) => p.materias,
        failure: (_) => const <Materia>[],
      )))
        m.id: m.nombre,
    };

    setState(() {
      _secciones = listaSecciones;
      _nombresProgramas = nombresProgramas;
      _nombresMaterias = nombresMaterias;
      _cargando = false;
    });
  }

  String _etiquetaDe(Seccion s) {
    final materia = _nombresMaterias[s.materiaId] ?? 'Materia';
    return '$materia (${s.nombre})';
  }

  String _subtituloDe(Seccion s) {
    final programa = _nombresProgramas[s.programaId] ?? s.programaId;
    return '$programa · ${s.periodo}';
  }

  @override
  Widget build(BuildContext context) {
    final abierta = _abierta;
    if (abierta != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _abierta = null;
                _cargar();
              }),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Volver a las aulas'),
            ),
          ),
          Expanded(
            child: AulaVirtualDashboardScreen(
              seccionId: abierta.id,
              seccionNombre: _etiquetaDe(abierta),
              gateway: widget.aulaGateway ?? BackendAulaGateway(),
              esDocente: true,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloSeccion(
          'Aulas Virtuales',
          subtitulo: 'El aula de cada sección del centro: anuncios, tareas y '
              'entregas. Toca una para abrirla y gestionarla.',
        ),
        Expanded(
          child: EstadoPanel(
            cargando: _cargando,
            error: _error,
            onReintentar: _cargar,
            child: _lista(),
          ),
        ),
      ],
    );
  }

  Widget _lista() {
    if (_secciones.isEmpty) {
      return const Center(
        child: SingleChildScrollView(
          child: PanelVacio(
            titulo: 'No hay secciones con aula virtual',
            mensaje: 'El aula virtual vive dentro de cada sección. Crea una '
                'sección en «Cuadrante de Horarios» o «Espacios y Aulas» y su '
                'aula aparecerá aquí.',
            icono: Icons.school_outlined,
          ),
        ),
      );
    }

    final activas = _secciones.where((s) => s.activa).toList();
    final archivadas = _secciones.where((s) => !s.activa).toList()
      ..sort((a, b) => b.periodo.compareTo(a.periodo));

    return ListView(
      children: [
        for (final s in activas) _tarjeta(s),
        if (archivadas.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              'Archivadas (${archivadas.length})',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          for (final s in archivadas) _tarjeta(s, archivada: true),
        ],
      ],
    );
  }

  Widget _tarjeta(Seccion s, {bool archivada = false}) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        enabled: !archivada,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(
            Icons.school_outlined,
            size: 18,
            color: archivada
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.primary,
          ),
        ),
        title: Text(
          _etiquetaDe(s),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: archivada ? theme.colorScheme.onSurfaceVariant : null,
          ),
        ),
        subtitle: Text(
          // **El código, a la vista.** Es lo que el docente dicta en clase y lo
          // que el administrador lee por teléfono; esconderlo en un detalle es
          // esconder la función. Se muestra en las activas: en una archivada no
          // sirve para entrar.
          archivada
              ? '${_subtituloDe(s)} · archivada'
              : (s.codigoAula == null || s.codigoAula!.isEmpty)
                  ? _subtituloDe(s)
                  : '${_subtituloDe(s)} · código ${s.codigoAula}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: archivada
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quién está en el aula, y los botones para meter o sacar.
                  IconButton(
                    icon: const Icon(Icons.group_outlined, size: 18),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Aprendices del aula',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => DialogoAprendices(
                        seccionId: s.id,
                        etiquetaAula: _etiquetaDe(s),
                        seccionesRepo: _seccionesRepo,
                      ),
                    ),
                  ),
                  if (s.codigoAula != null && s.codigoAula!.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Copiar el código de aula',
                      onPressed: () async {
                        final codigo = s.codigoAula!;
                        await Clipboard.setData(ClipboardData(text: codigo));
                        if (!mounted) return;
                        mostrarAviso(
                          context,
                          'Código $codigo copiado. Dictalo en clase.',
                          exito: true,
                        );
                      },
                    ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
        onTap: archivada
            ? null
            : () => setState(() => _abierta = s),
      ),
    );
  }
}
