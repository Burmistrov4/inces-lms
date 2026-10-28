import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';
import '../../core/gateways/cuadrante_gateway.dart';
import '../../core/reglas_cuadrante.dart';
import '../../models/cuadrante.dart';
import '../../repositories/cuadrante_repository.dart';
import '../../repositories/curriculo_repository.dart';
import '../../repositories/secciones_repository.dart';
import '../../widgets/comunes.dart';
import '../../widgets/cuadrante_grid.dart';
import '../../widgets/guia_contextual_modulo.dart';

/// Panel de Horario PNA — Programa Nacional de Aprendizaje (D3, D4).
///
/// Pantalla dedicada exclusivamente a los aprendices del PNA (`CUR-INT-01`).
///
/// Invariante de negocio D4:
/// - **Materia** es OBLIGATORIA.
/// - **Docente** es OBLIGATORIO.
/// - **Espacio/Aula** es OPCIONAL (se puede cursar en aula fija, taller rotativo o aula compartida).
class CpanelPnaPanel extends StatefulWidget {
  const CpanelPnaPanel({
    super.key,
    this.repositorio,
    this.onNavegarA,
  });

  final CuadranteRepository? repositorio;
  final void Function(String)? onNavegarA;

  @override
  State<CpanelPnaPanel> createState() => _CpanelPnaPanelState();
}

class _CpanelPnaPanelState extends State<CpanelPnaPanel> {
  late final CuadranteRepository _repo =
      widget.repositorio ?? CuadranteRepository();
  late final SeccionesRepository _seccionesRepo = SeccionesRepository();
  late final CurriculoRepository _curriculoRepo = CurriculoRepository();

  List<Periodo> _periodos = const [];
  String? _lapso;
  int? _diaFiltro;
  bool _hayVigente = false;

  List<ClaseCuadrante> _clases = const [];
  List<Aula> _aulas = const [];
  List<DocenteResumen> _docentes = const [];
  Map<String, String> _seccionesPnaCatalogo = const {};

  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarPeriodos();
  }

  Future<void> _cargarPeriodos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    final resultado = await _repo.listarPeriodos();
    if (!mounted) return;

    resultado.when(
      success: (periodos) {
        _periodos = periodos;
        final vigente = periodos.where((p) => p.vigente).firstOrNull;
        _hayVigente = vigente != null;
        _lapso = vigente?.codigo ?? periodos.firstOrNull?.codigo;
        _cargarRejilla();
      },
      failure: (fallo) => setState(() {
        _cargando = false;
        _error = fallo.message;
      }),
    );
  }

  Future<void> _cargarRejilla() async {
    if (_lapso == null) {
      setState(() {
        _cargando = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    final resultado = await _repo.rejilla(periodo: _lapso);
    await _cargarSeccionesPnaCatalogo();
    if (!mounted) return;

    resultado.when(
      success: (rejilla) => setState(() {
        _cargando = false;
        _clases = rejilla.clases;
        _aulas = rejilla.aulas;
        _docentes = rejilla.docentes;
      }),
      failure: (fallo) => setState(() {
        _cargando = false;
        _error = fallo.message;
      }),
    );
  }

  Future<void> _cargarSeccionesPnaCatalogo() async {
    try {
      final resProg = await _curriculoRepo.listarProgramas(limite: 100);
      final progMap = <String, String>{};
      if (resProg.isSuccess) {
        for (final p in resProg.valueOrNull!.programas) {
          progMap[p.id] = p.nombre;
        }
      }

      final resMat = await _curriculoRepo.listarMaterias(limite: 200);
      final matMap = <String, String>{};
      if (resMat.isSuccess) {
        for (final m in resMat.valueOrNull!.materias) {
          matMap[m.id] = m.nombre;
        }
      }

      final resSec = await _seccionesRepo.listarSecciones(soloActivas: true, limite: 150);
      if (resSec.isSuccess) {
        final mapa = <String, String>{};
        for (final s in resSec.valueOrNull!.secciones) {
          if (_lapso != null && s.periodo != _lapso) continue;
          final progNombre = progMap[s.programaId] ?? s.programaId;
          final esPna = esProgramaPNA(progNombre) ||
              s.programaId.toLowerCase().contains('cur-int-01') ||
              s.programaId.toLowerCase().contains('pna');
          if (esPna) {
            final matNombre = matMap[s.materiaId];
            final etiqueta = matNombre != null && matNombre.isNotEmpty
                ? '$progNombre · Secc. ${s.nombre} ($matNombre)'
                : '$progNombre · Secc. ${s.nombre}';
            mapa[s.id] = etiqueta;
          }
        }
        _seccionesPnaCatalogo = mapa;
      }
    } catch (_) {}
  }

  List<ClaseCuadrante> get _clasesPna => _clases
      .where((c) =>
          esProgramaPNA(c.programa) ||
          esProgramaPNA(c.materia) ||
          c.programaId.toLowerCase().contains('cur-int-01'))
      .toList();

  Map<String, String> get _seccionesPnaDisponibles {
    final mapa = <String, String>{..._seccionesPnaCatalogo};
    for (final clase in _clases) {
      if (clase.seccionId.isNotEmpty &&
          !mapa.containsKey(clase.seccionId) &&
          (esProgramaPNA(clase.programa) ||
              clase.programaId.toLowerCase().contains('cur-int-01'))) {
        mapa[clase.seccionId] = clase.seccion.isNotEmpty
            ? '${clase.programa} · ${clase.seccion}'
            : clase.seccionId;
      }
    }
    // Separación estricta PNA: no mezclar secciones de cursos ordinarios
    return mapa;
  }

  String? _razonParaNoAsignar() {
    if (_lapso == null) return 'Elige un período antes de asignar una materia.';
    if (_docentes.isEmpty) {
      return 'No hay docentes registrados a los que asignar la materia.';
    }
    return null;
  }

  Future<void> _abrirCreacion({int? diaInicial, int? bloqueInicial}) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoMateriaPNA(
        repo: _repo,
        aulas: _aulas,
        docentes: _docentes,
        secciones: _seccionesPnaDisponibles,
        periodo: _lapso ?? '',
        diaInicial: diaInicial,
        bloqueInicial: bloqueInicial,
      ),
    );
    if (guardado != true || !mounted) return;
    await _cargarRejilla();
  }

  Future<void> _abrirEdicion(ClaseCuadrante clase) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoMateriaPNA(
        repo: _repo,
        clase: clase,
        aulas: _aulas,
        docentes: _docentes,
        secciones: const {},
        periodo: _lapso ?? '',
      ),
    );
    if (guardado != true || !mounted) return;
    await _cargarRejilla();
  }

  @override
  Widget build(BuildContext context) {
    final razon = _razonParaNoAsignar();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cabecera(razon),
        if (_lapso != null && !_hayVigente) _avisoSinVigente(),
        const SizedBox(height: 8),
        const GuiaContextualModulo(
          claveStorage: 'horario_pna_cpanel',
          icono: Icons.school_outlined,
          titulo: 'Horario PNA — Programa Nacional de Aprendizaje',
          subtitulo:
              'Aquí se planifican los bloques formativos para aprendices del PNA (14-18 años). '
              'A diferencia del Horario Ordinario y MTP, aquí la materia y el docente son obligatorios.',
          pasos: [
            PasoGuiaContextual(
              numero: 1,
              titulo: 'Asignar materia PNA',
              descripcion:
                  'Toca cualquier celda con (+) o pulsa «Asignar materia PNA».',
            ),
            PasoGuiaContextual(
              numero: 2,
              titulo: 'Materia y docente obligatorios',
              descripcion:
                  'Indica la materia formativa y el facilitador responsable.',
            ),
            PasoGuiaContextual(
              numero: 3,
              titulo: 'Espacio físico opcional',
              descripcion:
                  'El aula o taller es opcional según la rotación de prácticas en CFS La Isabelica.',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: EstadoPanel(
            cargando: _cargando,
            error: _error,
            onReintentar: _cargarPeriodos,
            child: _cuerpo(),
          ),
        ),
      ],
    );
  }

  Widget _cabecera(String? razon) {
    final boton = FilledButton.icon(
      onPressed: razon == null ? _abrirCreacion : null,
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('Asignar materia PNA'),
    );

    return TituloSeccion(
      'Horario PNA',
      subtitulo:
          'Planificación del Programa Nacional de Aprendizaje (CUR-INT-01). '
          'Materia y docente obligatorios; espacio/taller opcional.',
      acciones: [
        if (_periodos.isNotEmpty) _selectorDeLapso(),
        const SizedBox(width: 8),
        if (widget.onNavegarA != null) ...[
          OutlinedButton.icon(
            onPressed: () => widget.onNavegarA?.call('Cuadrante de Horarios'),
            icon: const Icon(Icons.calendar_month_outlined, size: 16),
            label: const Text('Horario Ordinario'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => widget.onNavegarA?.call('Guardias Docentes'),
            icon: const Icon(Icons.shield_outlined, size: 16),
            label: const Text('Horario MTP'),
          ),
          const SizedBox(width: 8),
        ],
        if (razon == null) boton else Tooltip(message: razon, child: boton),
      ],
    );
  }

  Widget _selectorDeLapso() {
    return SizedBox(
      width: 200,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Período',
          isDense: true,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            isDense: true,
            value: _lapso,
            items: [
              for (final p in _periodos)
                DropdownMenuItem(
                  value: p.codigo,
                  child: Text(
                    p.vigente ? '${p.etiqueta} (vigente)' : p.etiqueta,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (valor) {
              if (valor == null || valor == _lapso) return;
              setState(() => _lapso = valor);
              _cargarRejilla();
            },
          ),
        ),
      ),
    );
  }

  Widget _avisoSinVigente() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AvisoEnLinea(
        texto: 'Ningún período está marcado como vigente. Se muestra '
            '«$_lapso»; márcalo vigente en «Período» para fijar el horario del centro.',
        icono: Icons.flag_outlined,
        tono: TonoAviso.advertencia,
      ),
    );
  }

  Widget _cuerpo() {
    if (_periodos.isEmpty) {
      return const PanelVacio(
        titulo: 'Todavía no hay períodos registrados',
        mensaje: 'Registra un período académico para planificar el horario PNA.',
        icono: Icons.calendar_month_outlined,
      );
    }

    final pnaClases = _clasesPna;
    if (pnaClases.isEmpty) {
      return PanelVacio(
        titulo: 'Este período aún no tiene materias PNA asignadas',
        mensaje:
            'La rejilla PNA está lista. Pulsa «Asignar materia PNA» o toca una celda libre para programar.',
        icono: Icons.school_outlined,
        nota: _razonParaNoAsignar(),
      );
    }

    return _rejilla(pnaClases);
  }

  Widget _rejilla(List<ClaseCuadrante> pnaClases) {
    final celdas = <String, List<Widget>>{};
    for (final entrada in agruparClases(pnaClases, chip: _chipClasePna).entries) {
      celdas[entrada.key] = entrada.value;
    }

    final diasConContenido = <int>{};
    for (final entrada in celdas.entries) {
      final dia = int.tryParse(entrada.key.split('-').first);
      if (dia != null && entrada.value.isNotEmpty) diasConContenido.add(dia);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectorDeDias(
          seleccionado: _diaFiltro,
          onCambio: (dia) => setState(() => _diaFiltro = dia),
          diasConContenido: diasConContenido,
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.school, size: 14, color: Colors.teal),
                    SizedBox(width: 6),
                    Text(
                      'PNA: Materia y Docente asignados (Espacio opcional)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: CuadranteGrid(
            celdas: celdas,
            diaFiltro: _diaFiltro,
            mostrarSelectorDias: false,
            onCeldaTap: _razonParaNoAsignar() == null
                ? (dia, bloque) =>
                    _abrirCreacion(diaInicial: dia, bloqueInicial: bloque)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _chipClasePna(ClaseCuadrante clase) {
    final docente = nombreDeDocente(clase.docente);
    final materia = clase.materia.isNotEmpty ? clase.materia : 'Materia PNA';
    final subtitulo = clase.aula.isNotEmpty ? '$docente · ${clase.aula}' : '$docente · (Sin aula)';
    return ChipCuadrante(
      titulo: materia,
      subtitulo: subtitulo,
      color: Colors.teal,
      etiquetaAula: clase.aula.isNotEmpty ? clase.aula : 'PNA',
      destacado: true,
      onTap: () => _abrirEdicion(clase),
    );
  }
}

/// Diálogo modal para asignar o editar una materia en el Horario PNA.
class _DialogoMateriaPNA extends StatefulWidget {
  const _DialogoMateriaPNA({
    required this.repo,
    this.clase,
    required this.aulas,
    required this.docentes,
    required this.secciones,
    required this.periodo,
    this.diaInicial,
    this.bloqueInicial,
  });

  final CuadranteRepository repo;
  final ClaseCuadrante? clase;
  final List<Aula> aulas;
  final List<DocenteResumen> docentes;
  final Map<String, String> secciones;
  final String periodo;
  final int? diaInicial;
  final int? bloqueInicial;

  @override
  State<_DialogoMateriaPNA> createState() => _DialogoMateriaPNAState();
}

class _DialogoMateriaPNAState extends State<_DialogoMateriaPNA> {
  late String? _seccionId = widget.clase?.seccionId ?? widget.secciones.keys.firstOrNull;
  late String? _aulaId = widget.clase?.aulaId;
  late String? _docenteId = widget.clase?.docenteId;
  late int _dia = widget.clase?.dia ?? widget.diaInicial ?? 1;
  late int _bloque = widget.clase?.bloque ?? widget.bloqueInicial ?? 1;
  late bool _activa = widget.clase?.activa ?? true;

  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.clase != null;

  Future<void> _guardar() async {
    if (_guardando) return;

    // Validación dura D4 para PNA:
    if (!_esEdicion && (_seccionId == null || _seccionId!.trim().isEmpty)) {
      setState(() => _error = 'Elige o registra una sección para la materia PNA.');
      return;
    }
    if (_docenteId == null || _docenteId!.trim().isEmpty) {
      setState(() => _error = 'El horario PNA exige asignar un docente.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final resultado = _esEdicion
        ? await widget.repo.actualizarClase(
            widget.clase!.id,
            CambiosClase(
              aulaId: _aulaId != widget.clase!.aulaId ? _aulaId : null,
              docenteId:
                  _docenteId != widget.clase!.docenteId ? _docenteId : null,
              dia: _dia != widget.clase!.dia ? _dia : null,
              bloque: _bloque != widget.clase!.bloque ? _bloque : null,
              activa: _activa != widget.clase!.activa ? _activa : null,
            ),
          )
        : await widget.repo.crearClase(
            EntradaCrearClase(
              seccionId: _seccionId!,
              docenteId: _docenteId,
              aulaId: _aulaId,
              dia: _dia,
              bloque: _bloque,
            ),
          );

    if (!mounted) return;
    setState(() => _guardando = false);

    resultado.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (fallo) => setState(() => _error = _mensajeDe(fallo)),
    );
  }

  String _mensajeDe(AppException fallo) {
    if (esChoqueDeAgenda(fallo.code)) {
      return 'Ese docente o ese espacio ya están ocupados en ese bloque. '
          'Mueve la materia a otro bloque o libera el espacio.';
    }
    return fallo.message;
  }

  List<DocenteResumen> get _docentesLimpios =>
      widget.docentes.where((d) => !d.esTestOSemilla).toList();

  @override
  Widget build(BuildContext context) {
    final docentes = _docentesLimpios;
    final docenteActual =
        docentes.where((d) => d.id == _docenteId).firstOrNull;

    return AlertDialog(
      title: Text(_esEdicion ? 'Editar materia PNA' : 'Asignar materia PNA'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_esEdicion && widget.secciones.isNotEmpty)
                _DesplegablePna<String>(
                  etiqueta: 'Programa / Sección PNA',
                  ancho: double.infinity,
                  valor: _seccionId,
                  opciones: [
                    for (final entrada in widget.secciones.entries)
                      DropdownMenuItem(
                        value: entrada.key,
                        child: Text(
                          entrada.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _seccionId = v),
                ),
              if (!_esEdicion && widget.secciones.isNotEmpty)
                const SizedBox(height: 12),
              // Facilitador (OBLIGATORIO)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Docente / Facilitador (Obligatorio)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Autocomplete<DocenteResumen>(
                    initialValue: TextEditingValue(
                      text: docenteActual != null
                          ? nombreDeDocente(docenteActual.nombre)
                          : '',
                    ),
                    displayStringForOption: (d) => nombreDeDocente(d.nombre),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) return docentes;
                      final q = textEditingValue.text.toLowerCase();
                      return docentes.where((d) =>
                          d.nombre.toLowerCase().contains(q) ||
                          (d.email?.toLowerCase().contains(q) ?? false));
                    },
                    onSelected: (DocenteResumen d) =>
                        setState(() => _docenteId = d.id),
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Buscar facilitador por nombre...',
                          prefixIcon: const Icon(Icons.person_search, size: 20),
                          suffixIcon: controller.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    controller.clear();
                                    setState(() => _docenteId = null);
                                  },
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Espacio físico (OPCIONAL)
              _DesplegablePna<String?>(
                etiqueta: 'Aula / Taller (Opcional)',
                ancho: double.infinity,
                valor: _aulaId,
                opciones: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sin aula asignada (opcional)',
                        style: TextStyle(fontStyle: FontStyle.italic)),
                  ),
                  for (final aula in widget.aulas)
                    DropdownMenuItem<String?>(
                      value: aula.id,
                      child: Text(
                        aula.nombre,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _aulaId = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DesplegablePna<int>(
                      etiqueta: 'Día',
                      ancho: double.infinity,
                      valor: _dia,
                      opciones: [
                        for (var d = 1; d <= diaMaximo; d++)
                          DropdownMenuItem(
                            value: d,
                            child: Text(diasDeLaSemana[d]),
                          ),
                      ],
                      onChanged: (v) => setState(() => _dia = v ?? _dia),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DesplegablePna<int>(
                      etiqueta: 'Bloque',
                      ancho: double.infinity,
                      valor: _bloque,
                      opciones: [
                        for (var b = 1; b <= bloqueMaximo; b++)
                          DropdownMenuItem(
                            value: b,
                            child: Text(
                              bloqueLegibleConTurno(b),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _bloque = v ?? _bloque),
                    ),
                  ),
                ],
              ),
              if (_esEdicion) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Materia activa en cuadrante'),
                  value: _activa,
                  onChanged: (v) => setState(() => _activa = v),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
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
          child: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_esEdicion ? 'Guardar cambios' : 'Asignar materia'),
        ),
      ],
    );
  }
}

class _DesplegablePna<T> extends StatelessWidget {
  const _DesplegablePna({
    required this.etiqueta,
    required this.ancho,
    required this.valor,
    required this.opciones,
    required this.onChanged,
  });

  final String etiqueta;
  final double ancho;
  final T? valor;
  final List<DropdownMenuItem<T>> opciones;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: etiqueta,
          isDense: true,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            isExpanded: true,
            isDense: true,
            value: valor,
            items: opciones,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
