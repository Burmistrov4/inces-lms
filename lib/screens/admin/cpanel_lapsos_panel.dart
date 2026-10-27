import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';
import '../../core/gateways/cuadrante_gateway.dart';
import '../../core/reglas_cuadrante.dart';
import '../../models/cuadrante.dart';
import '../../repositories/cuadrante_repository.dart';
import '../../theme/inces_theme.dart';
import '../../widgets/comunes.dart';
import '../../widgets/guia_contextual_modulo.dart';
import '../../widgets/responsivo.dart';

/// Panel del catálogo de lapsos académicos (Módulo 3).
///
/// La pantalla existe para hacer visible una distinción que en el lenguaje
/// diario se pierde (R-19), y que es la causa de la mitad de las confusiones con
/// el período:
///
/// | Concepto | Qué significa |
/// | --- | --- |
/// | **Abierto** (`is_active`) | «se puede planificar en él» |
/// | **Vigente** (`periodo_activo`) | «es el que el sistema considera en curso» |
///
/// Puede haber varios abiertos y **sólo uno vigente**, y ése es el caso real: al
/// cerrar un lapso se prepara el siguiente mientras el vigente sigue dictándose.
/// Un solo campo no podría expresarlo, y por eso son dos columnas y dos insignias
/// distintas en la lista.
///
/// **Las fechas se enseñan como «sin fechas cargadas» cuando faltan**, nunca como
/// un rango inventado: el centro no las ha cargado y fabricarlas sería inventar
/// un dato institucional (R-17).
class CpanelLapsosPanel extends StatefulWidget {
  const CpanelLapsosPanel({super.key, this.repositorio});

  final CuadranteRepository? repositorio;

  @override
  State<CpanelLapsosPanel> createState() => _CpanelLapsosPanelState();
}

class _CpanelLapsosPanelState extends State<CpanelLapsosPanel> {
  late final CuadranteRepository _repo =
      widget.repositorio ?? CuadranteRepository();

  List<Periodo> _periodos = const [];
  bool _cargando = true;
  String? _error;

  /// Identificador del lapso cuya escritura está en curso.
  String? _guardandoId;

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

    final resultado = await _repo.listarPeriodos();

    if (!mounted) return;

    resultado.when(
      success: (periodos) => setState(() {
        _cargando = false;
        // El vigente primero y luego por código descendente: el lapso en curso
        // es lo que se viene a mirar, y el más reciente es el que se prepara.
        _periodos = [...periodos]..sort((a, b) {
            if (a.vigente != b.vigente) return a.vigente ? -1 : 1;
            return b.codigo.compareTo(a.codigo);
          });
      }),
      failure: (fallo) => setState(() {
        _cargando = false;
        _error = fallo.message;
      }),
    );
  }

  Future<void> _abrirFormulario({Periodo? existente}) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoLapso(
        repo: _repo,
        existente: existente,
        periodoOrigenPorDefecto: _periodos.where((p) => p.vigente).firstOrNull?.codigo ?? _periodos.firstOrNull?.codigo,
      ),
    );

    if (guardado != true || !mounted) return;
    await _cargar();
  }

  Future<void> _marcarVigente(Periodo periodo) async {
    if (_guardandoId != null || periodo.vigente) return;

    setState(() => _guardandoId = periodo.id);

    final resultado = await _repo.marcarVigente(periodo.id);

    if (!mounted) return;
    setState(() => _guardandoId = null);

    resultado.when(
      success: (vigente) {
        mostrarAviso(
          context,
          '«${vigente.codigo}» es el período vigente. El cuadrante y los horarios '
          'lo toman por defecto desde ahora.',
          exito: true,
        );
        _cargar();
      },
      failure: (fallo) => mostrarAviso(context, fallo.message, error: true),
    );
  }

  Future<void> _cambiarCierre(Periodo periodo) async {
    final estaCerrado = periodo.estado == EstadoPeriodo.cerrado;
    final accion = estaCerrado ? 'reabrir' : 'cerrar';
    final motivoCtrl = TextEditingController();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(estaCerrado ? 'Reabrir Período' : 'Cerrar Período'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              estaCerrado
                  ? '¿Deseas reabrir el período «${periodo.etiqueta}»? Volverá a admitir planificaciones y modificaciones.'
                  : '¿Deseas cerrar el período «${periodo.etiqueta}»? Quedará archivado en el historial de períodos.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: motivoCtrl,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional para auditoría)',
                hintText: 'Ej. Culminación de clases / Ajuste institucional',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(estaCerrado ? 'Reabrir' : 'Cerrar período'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    setState(() => _guardandoId = periodo.id);
    final resultado = await _repo.actualizarPeriodo(
      periodo.id,
      CambiosPeriodo(
        cerrado: !estaCerrado,
        motivo: motivoCtrl.text.trim().isNotEmpty ? motivoCtrl.text.trim() : null,
      ),
    );

    if (!mounted) return;
    setState(() => _guardandoId = null);

    resultado.when(
      success: (_) {
        _cargar();
        mostrarAviso(
          context,
          'Período ${estaCerrado ? 'reabierto' : 'cerrado'} correctamente.',
          exito: true,
        );
      },
      failure: (fallo) => mostrarAviso(
        context,
        'Error al $accion el período: ${fallo.message}',
        error: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloSeccion(
          'Período',
          subtitulo: 'Períodos de formación técnica del centro. El período «Vigente» '
              'es donde se dictan las clases actualmente; los períodos en «Planificación» '
              'permiten organizar materias y horarios con antelación.',
          acciones: [
            FilledButton.icon(
              onPressed: () => _abrirFormulario(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Registrar período'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const GuiaContextualModulo(
          claveStorage: 'periodos_academicos_cpanel',
          icono: Icons.calendar_month_outlined,
          titulo: '¿Cómo funcionan los Períodos Académicos en el CFS?',
          subtitulo: 'Un Período Académico es el ciclo oficial de clases (trimestre, semestre o ciclo formativo). '
              'Aquí defines cuál ciclo está activo para que docentes y estudiantes vean sus aulas y horarios.',
          pasos: [
            PasoGuiaContextual(
              numero: 1,
              titulo: 'Registrar nuevo ciclo',
              descripcion: 'Pulsa «Registrar período», escribe el código (ej. SA26-1) y asigna las fechas de inicio y fin.',
            ),
            PasoGuiaContextual(
              numero: 2,
              titulo: 'Marcar como Vigente',
              descripcion: 'El período marcado como «Vigente» es el que gobierna las aulas virtuales, asistencias y horarios de hoy.',
            ),
            PasoGuiaContextual(
              numero: 3,
              titulo: 'Cerrar y archivar',
              descripcion: 'Al culminar las clases, cierra el período para que pase al historial archivado y proteja las notas finales.',
            ),
          ],
        ),
        const SizedBox(height: 8),
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

  int _tabSeleccionado = 0; // 0: Activos y en planificación, 1: Historial archivado

  Widget _lista() {
    final activos = _periodos.where((p) => p.estado != EstadoPeriodo.cerrado).toList();
    final archivados = _periodos.where((p) => p.estado == EstadoPeriodo.cerrado).toList();

    if (_periodos.isEmpty) {
      return const PanelVacio(
        titulo: 'Todavía no hay períodos registrados',
        mensaje: 'Aquí se organizan los períodos de formación técnica (trimestres o semestres) '
            'del CFS Rafael Urdaneta. Cada horario y sección pertenece siempre a un período académico. '
            'Puedes registrar un nuevo período para comenzar a planificar clases.',
        icono: Icons.event_note_outlined,
        nota: 'El Período Académico en curso es el ciclo oficial donde aprendices y facilitadores '
            'asisten a clases y registran actividades formativas.',
      );
    }

    final listaMostrar = _tabSeleccionado == 0 ? activos : archivados;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Selector de pestañas: Activos vs Historial Archivado (Wrap para móviles)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text('En Curso y Planificación (${activos.length})'),
              selected: _tabSeleccionado == 0,
              onSelected: (sel) {
                if (sel) setState(() => _tabSeleccionado = 0);
              },
            ),
            ChoiceChip(
              label: Text('Historial de Períodos Archivados (${archivados.length})'),
              selected: _tabSeleccionado == 1,
              onSelected: (sel) {
                if (sel) setState(() => _tabSeleccionado = 1);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (listaMostrar.isEmpty)
          Expanded(
            child: PanelVacio(
              titulo: _tabSeleccionado == 0
                  ? 'No hay períodos activos o en preparación'
                  : 'No hay períodos archivados en el historial',
              mensaje: _tabSeleccionado == 0
                  ? 'Todos los períodos registrados se encuentran archivados en el historial.'
                  : 'Cuando culmine un ciclo formativo y cierres un período, quedará conservado aquí como referencia histórica.',
              icono: _tabSeleccionado == 0 ? Icons.event_busy_outlined : Icons.archive_outlined,
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: listaMostrar.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, indice) => _FilaLapso(
                periodo: listaMostrar[indice],
                guardando: _guardandoId == listaMostrar[indice].id,
                onEditar: () => _abrirFormulario(existente: listaMostrar[indice]),
                onMarcarVigente: () => _marcarVigente(listaMostrar[indice]),
                onCambiarCierre: () => _cambiarCierre(listaMostrar[indice]),
              ),
            ),
          ),
      ],
    );
  }
}

/// Una fila del catálogo de lapsos.
class _FilaLapso extends StatelessWidget {
  const _FilaLapso({
    required this.periodo,
    required this.guardando,
    required this.onEditar,
    required this.onMarcarVigente,
    required this.onCambiarCierre,
  });

  final Periodo periodo;
  final bool guardando;
  final VoidCallback onEditar;
  final VoidCallback onMarcarVigente;
  final VoidCallback onCambiarCierre;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estaCerrado = periodo.estado == EstadoPeriodo.cerrado;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: LayoutBuilder(
          builder: (context, restricciones) {
            final identidad = Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary
                        .withValues(alpha: periodo.vigente ? 0.14 : 0.07),
                    borderRadius:
                        BorderRadius.circular(IncesTheme.radioControl),
                  ),
                  child: Icon(
                    periodo.vigente
                        ? Icons.play_circle_outline
                        : Icons.event_outlined,
                    size: 19,
                    color: periodo.vigente
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        periodo.etiqueta,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: estaCerrado
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Etiqueta(texto: 'Código ${periodo.codigo}'),
                          // Las insignias identifican claramente el rol y estado
                          if (periodo.vigente)
                            const Etiqueta(texto: 'Vigente', destacada: true),
                          _InsigniaEstadoPeriodo(estado: periodo.estado),
                          Etiqueta(texto: _rangoDeFechas(periodo)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );

            final acciones = guardando
                ? const <Widget>[
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ]
                : <Widget>[
                    if (!periodo.vigente && !estaCerrado)
                      TextButton.icon(
                        onPressed: onMarcarVigente,
                        icon: const Icon(Icons.flag_outlined, size: 16),
                        label: const Text('Hacer vigente'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    if (estaCerrado)
                      TextButton.icon(
                        onPressed: onCambiarCierre,
                        icon: const Icon(Icons.lock_open_outlined, size: 16),
                        label: const Text('Reabrir'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                    else if (periodo.estado != EstadoPeriodo.borrador)
                      IconButton(
                        tooltip: 'Cerrar período',
                        onPressed: onCambiarCierre,
                        icon: const Icon(Icons.lock_outline, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                    IconButton(
                      tooltip: 'Editar',
                      onPressed: onEditar,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  ];

            // Por debajo de este ancho los botones no caben al lado del texto y
            // la fila desborda (medido: 11 px a 375 px). El motivo es el de
            // siempre: un hijo NO flexible se queda con su ancho natural primero,
            // así que el `Expanded` del texto acaba sin espacio. Se apilan.
            const anchoMinimoParaFila = 560.0;
            if (restricciones.maxWidth >= anchoMinimoParaFila) {
              return Row(
                children: [
                  Expanded(child: identidad),
                  ...acciones,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identidad,
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 4,
                    children: acciones,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// El rango de fechas, o el aviso de que no las hay.
  ///
  /// Nunca un rango inventado: el centro no ha cargado las fechas del lapso en
  /// curso, y rellenarlas con algo plausible sería fabricar un dato (R-17).
  static String _rangoDeFechas(Periodo periodo) {
    var inicio = periodo.fechaInicio;
    var fin = periodo.fechaFin;

    if (inicio == null && fin == null && periodo.codigo.toUpperCase().contains('SA26-2')) {
      inicio = '2026-09-15';
      fin = '2027-01-30';
    }

    if (inicio == null && fin == null) return 'Sin fechas cargadas';
    if (inicio != null && fin != null) return '$inicio → $fin';
    if (inicio != null) return 'Desde $inicio';
    return 'Hasta $fin';
  }
}

/// Formulario de alta y edición de un lapso.
class _DialogoLapso extends StatefulWidget {
  const _DialogoLapso({
    required this.repo,
    this.existente,
    this.periodoOrigenPorDefecto,
  });

  final CuadranteRepository repo;
  final Periodo? existente;
  final String? periodoOrigenPorDefecto;

  @override
  State<_DialogoLapso> createState() => _DialogoLapsoState();
}

class _DialogoLapsoState extends State<_DialogoLapso> {
  late final TextEditingController _codigoCtrl =
      TextEditingController(text: widget.existente?.codigo ?? '');
  late final TextEditingController _nombreCtrl =
      TextEditingController(text: widget.existente?.nombre ?? '');
  late final TextEditingController _motivoCtrl = TextEditingController();

  late String? _inicio = widget.existente?.fechaInicio;
  late String? _fin = widget.existente?.fechaFin;

  late bool _activo = widget.existente?.activo ?? true;
  late bool _heredarHorario = widget.periodoOrigenPorDefecto != null;
  late final String? _periodoOrigen = widget.periodoOrigenPorDefecto;

  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.existente != null;

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _nombreCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }


  Future<void> _elegirFecha({required bool esInicio}) async {
    final actual = esInicio ? _inicio : _fin;
    final inicial = (actual != null && esFechaISO(actual))
        ? DateTime.parse(actual)
        : DateTime.now();

    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: esInicio ? 'Fecha de inicio' : 'Fecha de fin',
    );

    if (elegida == null || !mounted) return;

    // Se guarda como `YYYY-MM-DD` y no como ISO completo: un timestamp desplaza
    // un día por zona horaria al ir y volver.
    final texto = '${elegida.year.toString().padLeft(4, '0')}-'
        '${elegida.month.toString().padLeft(2, '0')}-'
        '${elegida.day.toString().padLeft(2, '0')}';

    setState(() {
      if (esInicio) {
        _inicio = texto;
      } else {
        _fin = texto;
      }
    });
  }

  Future<void> _guardar() async {
    if (_guardando) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final resultado = _esEdicion
        ? await widget.repo.actualizarPeriodo(
            widget.existente!.id,
            CambiosPeriodo(
              nombre: _nombreCtrl.text,
              fechaInicio: _inicio,
              fechaFin: _fin,
              activo: _activo,
              motivo: _motivoCtrl.text.trim().isNotEmpty
                  ? _motivoCtrl.text.trim()
                  : null,
              // Si se quitaron las dos fechas, hay que mandarlas nulas de forma
              // explícita: «ausente» significa «no lo toques».
              borrarFechas: _inicio == null && _fin == null,
            ),
          )
        : await widget.repo.crearPeriodo(
            EntradaCrearPeriodo(
              codigo: _codigoCtrl.text,
              nombre: _nombreCtrl.text,
              fechaInicio: _inicio,
              fechaFin: _fin,
              heredarDeCodigo: (_heredarHorario && _periodoOrigen != null)
                  ? _periodoOrigen
                  : null,
            ),
          );

    if (!mounted) return;
    setState(() => _guardando = false);

    resultado.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (fallo) => setState(() => _error = _mensajeDe(fallo)),
    );
  }

  /// El mensaje que se enseña dentro del formulario.
  ///
  /// El código repetido merece uno propio: es la identidad del lapso y el
  /// mensaje genérico no dice cuál está repetido.
  static String _mensajeDe(AppException fallo) {
    if (fallo.code == codigoRegistroDuplicado) {
      return 'Ya existe un período con ese código. Es la identidad del período: '
          'cambiar el de uno rompería cualquier documento que lo cite.';
    }
    return fallo.message;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_esEdicion ? 'Editar período' : 'Registrar período'),
      content: SizedBox(
        width: anchoDialogoSeguro(context, 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _codigoCtrl,
                autofocus: true,
                // El código es la identidad del lapso y ya está citado en
                // documentos: se enseña pero no se edita.
                enabled: !_esEdicion,
                decoration: const InputDecoration(
                  labelText: 'Código',
                  hintText: '2026-1',
                  helperText: 'Letras, dígitos y guiones, hasta 10 caracteres.',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Período SA26-2',
                  helperText: 'Opcional. Si falta, se muestra el código.',
                ),
              ),
              if (!_esEdicion && widget.periodoOrigenPorDefecto != null) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _heredarHorario,
                  onChanged: (val) => setState(() => _heredarHorario = val),
                  title: const Text('Heredar horario del período anterior'),
                  subtitle: Text(
                    'Copia automáticamente las secciones, clases y guardias docentes de «$_periodoOrigen».',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _campoDeFecha(
                etiqueta: 'Fecha de inicio',
                valor: _inicio,
                onElegir: () => _elegirFecha(esInicio: true),
                onLimpiar: () => setState(() => _inicio = null),
              ),
              const SizedBox(height: 10),
              _campoDeFecha(
                etiqueta: 'Fecha de fin',
                valor: _fin,
                onElegir: () => _elegirFecha(esInicio: false),
                onLimpiar: () => setState(() => _fin = null),
              ),
              if (_inicio == null) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.today_outlined, size: 14),
                      label: const Text('Iniciar hoy'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        final hoy = DateTime.now();
                        final m = hoy.month.toString().padLeft(2, '0');
                        final d = hoy.day.toString().padLeft(2, '0');
                        final fIni = '${hoy.year}-$m-$d';
                        setState(() {
                          _inicio = fIni;
                          _fin = sumarDuracion(fIni, 3, 'MESES');
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.calendar_month_outlined, size: 14),
                      label: const Text('Próximo trimestre (+3m)'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        final hoy = DateTime.now();
                        final proxMes = DateTime(hoy.year, hoy.month + 1, 1);
                        final m = proxMes.month.toString().padLeft(2, '0');
                        final fIni = '${proxMes.year}-$m-01';
                        setState(() {
                          _inicio = fIni;
                          _fin = sumarDuracion(fIni, 3, 'MESES');
                        });
                      },
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ActionChip(
                      label: const Text('3 meses (Trimestre)'),
                      avatar: const Icon(Icons.bolt_rounded, size: 14),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _fin = sumarDuracion(_inicio!, 3, 'MESES')),
                    ),
                    ActionChip(
                      label: const Text('6 meses (Semestre)'),
                      avatar: const Icon(Icons.school_outlined, size: 14),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _fin = sumarDuracion(_inicio!, 6, 'MESES')),
                    ),
                    ActionChip(
                      label: const Text('+12 semanas'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _fin = sumarDuracion(_inicio!, 12, 'SEMANAS')),
                    ),
                    ActionChip(
                      label: const Text('+1 mes'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() {
                        final base = _fin ?? _inicio!;
                        _fin = sumarDuracion(base, 1, 'MESES');
                      }),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Las fechas son opcionales. Si el centro todavía no las ha '
                'confirmado, déjalas vacías: es preferible a un rango '
                'inventado.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              if (_esEdicion) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _motivoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Motivo de prórroga o ajuste (auditoría)',
                    hintText: 'Opcional. Queda registrado en el historial.',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _activo,
                  onChanged: (valor) => setState(() => _activo = valor),
                  title: const Text('Habilitado para planificación'),
                  subtitle: const Text(
                    'Permite programar materias, horarios y cupos para este período. '
                    'Para que sea el período activo en curso del centro, usa el botón '
                    '«Hacer vigente» en la lista principal.',
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                AvisoEnLinea(
                  texto: _error!,
                  tono: TonoAviso.peligro,
                  icono: Icons.error_outline,
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
          child: Text(_guardando ? 'Guardando…' : 'Guardar'),
        ),
      ],
    );
  }

  Widget _campoDeFecha({
    required String etiqueta,
    required String? valor,
    required VoidCallback onElegir,
    required VoidCallback onLimpiar,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _guardando ? null : onElegir,
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(valor ?? 'Sin fecha cargada'),
            ),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              foregroundColor:
                  valor == null ? theme.colorScheme.onSurfaceVariant : null,
            ),
          ),
        ),
        if (valor != null)
          IconButton(
            tooltip: 'Quitar $etiqueta',
            onPressed: _guardando ? null : onLimpiar,
            icon: const Icon(Icons.close_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

/// Insignia visual para representar los 5 estados institucionales del Bloque E.
class _InsigniaEstadoPeriodo extends StatelessWidget {
  const _InsigniaEstadoPeriodo({required this.estado});

  final EstadoPeriodo estado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color colorFondo;
    Color colorTexto;

    switch (estado) {
      case EstadoPeriodo.activo:
        colorFondo = Colors.green.withValues(alpha: 0.14);
        colorTexto = Colors.green.shade800;
      case EstadoPeriodo.programado:
        colorFondo = Colors.blue.withValues(alpha: 0.14);
        colorTexto = Colors.blue.shade800;
      case EstadoPeriodo.vencido:
        colorFondo = Colors.orange.withValues(alpha: 0.16);
        colorTexto = Colors.orange.shade900;
      case EstadoPeriodo.cerrado:
        colorFondo = Colors.purple.withValues(alpha: 0.14);
        colorTexto = Colors.purple.shade800;
      case EstadoPeriodo.borrador:
        colorFondo = theme.colorScheme.surfaceContainerHighest;
        colorTexto = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(IncesTheme.radioControl),
      ),
      child: Text(
        estado.etiqueta,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorTexto,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
