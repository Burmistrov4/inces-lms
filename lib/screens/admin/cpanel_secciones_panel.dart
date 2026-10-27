import 'package:flutter/material.dart';

import '../../core/result.dart';
import '../../models/seccion.dart';
import '../../repositories/curriculo_repository.dart';
import '../../repositories/secciones_repository.dart';
import '../../core/refresco_secciones.dart';
import '../../widgets/comunes.dart';
import '../../widgets/responsivo.dart';

/// Panel de CRUD de secciones (Módulo 4: Inscripciones y Cupos).
///
/// El catálogo es la base de todo lo demás: sin secciones no hay cupos que
/// gestionar. Aquí el administrador da de alta los grupos del lapso
/// (programa + materia + nombre corto + capacidad) y archiva los que ya no
/// se ofrecen. El archivado es reversible (PATCH con `activa: true`); no
/// hay borrado, porque una sección borrada se llevaría el historial de
/// inscripciones.
class CpanelSeccionesPanel extends StatefulWidget {
  const CpanelSeccionesPanel({super.key, this.repositorio});

  final SeccionesRepository? repositorio;

  @override
  State<CpanelSeccionesPanel> createState() => _CpanelSeccionesPanelState();
}

class _CpanelSeccionesPanelState extends State<CpanelSeccionesPanel>
    with RefrescoAlVolver<CpanelSeccionesPanel> {
  late final SeccionesRepository _repo =
      widget.repositorio ?? SeccionesRepository();
  late final CurriculoRepository _curriculoRepo = CurriculoRepository();

  Map<String, String> _programasNombres = {};
  Map<String, String> _materiasNombres = {};

  PaginaSecciones _pagina = const PaginaSecciones(
    secciones: [],
    total: 0,
    limite: 50,
    desplazamiento: 0,
  );
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  String get seccion => 'Secciones del Período';

  /// Vuelve a pedir los datos sin pantalla de carga. El panel sigue mostrando
  /// lo que tenia hasta que llega lo nuevo.
  @override
  Future<void> refrescarEnSegundoPlano() => _cargar(silencioso: true);

  Future<void> _cargar({bool silencioso = false}) async {
    // En silencio no se pinta la pantalla de carga: lo que ya se ve se queda
    // hasta que llegue lo nuevo. Es la mitad del patron stale-while-revalidate.
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }

    try {
      final progRes = await _curriculoRepo.listarProgramas(limite: 100);
      final matRes = await _curriculoRepo.listarMaterias(limite: 200);
      if (progRes.isSuccess) {
        _programasNombres = {
          for (final p in progRes.valueOrNull!.programas) p.id: p.nombre,
        };
      }
      if (matRes.isSuccess) {
        _materiasNombres = {
          for (final m in matRes.valueOrNull!.materias) m.id: m.nombre,
        };
      }
    } catch (_) {}

    final resultado = await _repo.listarSecciones();
    if (!mounted) return;
    setState(() {
      _cargando = false;
      switch (resultado) {
        case Success(value: final pagina):
          marcarCarga();
          _pagina = pagina;
        case Failure(error: final fallo):
          _error = fallo.message;
      }
    });
  }

  String _nombrePrograma(String id) =>
      _programasNombres[id] ?? (id.length <= 8 ? id : id.substring(0, 8));

  String _nombreMateria(String id) =>
      _materiasNombres[id] ?? (id.length <= 8 ? id : id.substring(0, 8));

  Future<void> _abrirCrear() async {
    final creada = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoCrearSeccion(repo: _repo),
    );
    if (creada == true && mounted) _cargar();
  }

  Future<void> _abrirEditar(Seccion s) async {
    final editada = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoEditarSeccion(
        repo: _repo,
        seccion: s,
        nombrePrograma: _nombrePrograma(s.programaId),
        nombreMateria: _nombreMateria(s.materiaId),
      ),
    );
    if (editada == true && mounted) _cargar();
  }

  Future<void> _archivar(Seccion s) async {
    final confirma = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Archivar sección'),
        content: Text(
          '«${s.nombre}» quedará archivada y dejará de aceptar '
          'inscripciones nuevas. No se pierde el historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );
    if (confirma != true) return;

    final resultado = await _repo.actualizarSeccion(
      s.id,
      const CambiosSeccion(activa: false),
    );
    if (!mounted) return;
    resultado.when(
      success: (_) => _cargar(),
      failure: (fallo) =>
          mostrarAviso(context, fallo.message, error: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloSeccion(
          'Secciones del Período',
          subtitulo: 'Catálogo de grupos del período. Archivar retira la '
              'sección del catálogo sin perder su historial.',
          acciones: [
            FilledButton.icon(
              onPressed: _abrirCrear,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nueva sección'),
            ),
          ],
        ),
        Expanded(
          child: EstadoPanel(
            cargando: _cargando,
            error: _error,
            onReintentar: _cargar,
            child: _cuerpo(),
          ),
        ),
      ],
    );
  }

  Widget _cuerpo() {
    if (_pagina.secciones.isEmpty) {
      return const PanelVacio(
        titulo: 'No hay secciones registradas',
        mensaje: 'Cuando el centro registre las secciones del período, las '
            'verás aquí con su capacidad y su estado de archivado.',
        icono: Icons.explore_outlined,
      );
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Total: ${_pagina.total}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final s in _pagina.secciones) _filaSeccion(s),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _alternarActiva(Seccion s) async {
    if (s.activa) {
      await _archivar(s);
    } else {
      final resultado = await _repo.actualizarSeccion(
        s.id,
        const CambiosSeccion(activa: true),
      );
      if (!mounted) return;
      resultado.when(
        success: (_) => _cargar(),
        failure: (fallo) => mostrarAviso(context, fallo.message, error: true),
      );
    }
  }

  Widget _filaSeccion(Seccion s) {
    final theme = Theme.of(context);
    final cupo = s.cupoMaximo == null
        ? 'Cupo: global'
        : s.cupoMaximo == 0
            ? 'Cupo: sin cupos'
            : 'Cupo: ${s.cupoMaximo}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.nombre,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Período ${s.periodo} · ${_nombrePrograma(s.programaId)} '
                    '· ${_nombreMateria(s.materiaId)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Etiqueta(texto: cupo),
                      Etiqueta(
                        texto: s.activa ? 'Activa' : 'Archivada',
                        destacada: !s.activa,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Editar sección',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _abrirEditar(s),
            ),
            IconButton(
              tooltip: s.activa ? 'Archivar' : 'Reactivar',
              icon: Icon(
                s.activa
                    ? Icons.archive_outlined
                    : Icons.unarchive_outlined,
                size: 20,
              ),
              onPressed: () => _alternarActiva(s),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo para crear una sección.
///
/// Pide los identificadores en crudo porque el catálogo con desplegables
/// depende de R-17/R-18 (fechas del lapso e inventario de aulas), aún
/// pendientes. Mantener la entrada manual ahora evita construir una pantalla
/// que va a quedar vacía la mitad del tiempo.
class _DialogoCrearSeccion extends StatefulWidget {
  const _DialogoCrearSeccion({required this.repo});

  final SeccionesRepository repo;

  @override
  State<_DialogoCrearSeccion> createState() => _DialogoCrearSeccionState();
}

class _DialogoCrearSeccionState extends State<_DialogoCrearSeccion> {
  final _forma = GlobalKey<FormState>();
  final _programa = TextEditingController();
  final _materia = TextEditingController();
  final _periodo = TextEditingController(text: 'SA26-2');
  final _nombre = TextEditingController();
  final _cupo = TextEditingController(text: '25');
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _programa.dispose();
    _materia.dispose();
    _periodo.dispose();
    _nombre.dispose();
    _cupo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!_forma.currentState!.validate()) return;

    final cupoTexto = _cupo.text.trim();
    int? cupoMaximo;
    if (cupoTexto.isNotEmpty) {
      cupoMaximo = int.tryParse(cupoTexto);
      if (cupoMaximo == null || cupoMaximo < 0) {
        setState(() => _error = 'El cupo debe ser un entero ≥ 0.');
        return;
      }
    } else {
      cupoMaximo = 25;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final resultado = await widget.repo.crearSeccion(Seccion.crear(
      programaId: _programa.text.trim(),
      materiaId: _materia.text.trim(),
      periodo: _periodo.text.trim(),
      nombre: _nombre.text.trim(),
      cupoMaximo: cupoMaximo,
    ));
    if (!mounted) return;

    resultado.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (fallo) => setState(() {
        _guardando = false;
        _error = fallo.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva sección'),
      content: SizedBox(
        width: anchoDialogoSeguro(context, 460),
        child: SingleChildScrollView(
          child: Form(
            key: _forma,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _campo(_programa, 'ID de programa', validadorUuid: true),
                const SizedBox(height: 10),
                _campo(_materia, 'ID de materia', validadorUuid: true),
                const SizedBox(height: 10),
                _campo(
                  _periodo,
                  'Código de período (p. ej. SA26-2)',
                  validadorNoVacio: true,
                  validadorLargoMax: 10,
                ),
                const SizedBox(height: 10),
                _campo(
                  _nombre,
                  'Nombre corto (≤ 5 caracteres)',
                  validadorNoVacio: true,
                  validadorLargoMax: 5,
                ),
                const SizedBox(height: 10),
                _campo(
                  _cupo,
                  'Cupo (vacío = cupo global del centro)',
                  esCupo: true,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  AvisoEnLinea(
                    texto: _error!,
                    icono: Icons.error_outline,
                    tono: TonoAviso.peligro,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _guardando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_guardando ? 'Creando…' : 'Crear sección'),
        ),
      ],
    );
  }

  Widget _campo(
    TextEditingController controlador,
    String etiqueta, {
    bool validadorUuid = false,
    bool validadorNoVacio = false,
    int? validadorLargoMax,
    bool esCupo = false,
  }) {
    return TextFormField(
      controller: controlador,
      decoration: InputDecoration(
        labelText: etiqueta,
        isDense: true,
      ),
      validator: (v) {
        final s = v?.trim() ?? '';
        if (validadorNoVacio && s.isEmpty) return 'Obligatorio.';
        if (validadorLargoMax != null && s.length > validadorLargoMax) {
          return 'Máximo $validadorLargoMax caracteres.';
        }
        if (validadorUuid && !_esUuidLargo(s)) return 'Identificador inválido.';
        if (esCupo && s.isNotEmpty && (int.tryParse(s) == null || int.parse(s) < 0)) {
          return 'Cupo debe ser un entero ≥ 0, o vacío.';
        }
        return null;
      },
    );
  }

  /// Un UUID válido mide 36 caracteres. No exigimos formato exacto, sólo
  /// una longitud razonable para no dejar pasar un texto cualquiera.
  bool _esUuidLargo(String s) => s.length >= 8;
}

class _DialogoEditarSeccion extends StatefulWidget {
  const _DialogoEditarSeccion({
    required this.repo,
    required this.seccion,
    required this.nombrePrograma,
    required this.nombreMateria,
  });

  final SeccionesRepository repo;
  final Seccion seccion;
  final String nombrePrograma;
  final String nombreMateria;

  @override
  State<_DialogoEditarSeccion> createState() => _DialogoEditarSeccionState();
}

class _DialogoEditarSeccionState extends State<_DialogoEditarSeccion> {
  final _forma = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _cupo;
  late bool _activa;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.seccion.nombre);
    _cupo = TextEditingController(
      text: widget.seccion.cupoMaximo != null
          ? widget.seccion.cupoMaximo.toString()
          : '',
    );
    _activa = widget.seccion.activa;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _cupo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_forma.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });

    final sCupo = _cupo.text.trim();
    final bool vaciarCupo = sCupo.isEmpty;
    final int? cupoValor = vaciarCupo ? null : int.tryParse(sCupo);

    final resultado = await widget.repo.actualizarSeccion(
      widget.seccion.id,
      CambiosSeccion(
        nombre: _nombre.text.trim(),
        cupoMaximo: cupoValor,
        vaciarCupoMaximo: vaciarCupo,
        activa: _activa,
      ),
    );

    if (!mounted) return;
    resultado.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (fallo) => setState(() {
        _guardando = false;
        _error = fallo.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Editar sección'),
      content: SizedBox(
        width: anchoDialogoSeguro(context, 480),
        child: SingleChildScrollView(
          child: Form(
            key: _forma,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Programa: ${widget.nombrePrograma}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Materia: ${widget.nombreMateria}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Período: ${widget.seccion.periodo}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nombre,
                  decoration: const InputDecoration(
                    labelText: 'Nombre corto (ej. A, B, SA, SC)',
                    isDense: true,
                  ),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return 'Obligatorio.';
                    if (s.length > 5) return 'Máximo 5 caracteres.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cupo,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cupo máximo (vacío = cupo global del centro)',
                    hintText: 'Dejar vacío para heredar cupo global',
                    isDense: true,
                  ),
                  validator: (s) {
                    final v = s?.trim() ?? '';
                    if (v.isNotEmpty && (int.tryParse(v) == null || int.parse(v) < 0)) {
                      return 'Cupo debe ser un entero ≥ 0, o vacío.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Sección activa'),
                  subtitle: Text(
                    _activa
                        ? 'Acepta inscripciones y se muestra en el catálogo'
                        : 'Archivada (no acepta inscripciones nuevas)',
                    style: theme.textTheme.bodySmall,
                  ),
                  value: _activa,
                  onChanged: (val) => setState(() => _activa = val),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  AvisoEnLinea(
                    texto: _error!,
                    icono: Icons.error_outline,
                    tono: TonoAviso.peligro,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_guardando ? 'Guardando…' : 'Guardar cambios'),
        ),
      ],
    );
  }
}