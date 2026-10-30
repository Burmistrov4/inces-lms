import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/gateways/curriculo_gateway.dart';
import '../../core/reglas_curriculo.dart';
import '../../core/result.dart';
import '../../models/pensum.dart';
import '../../models/programa.dart';
import '../../models/resumen_curso.dart';
import '../../repositories/curriculo_repository.dart';
import '../../repositories/inscripcion_repository.dart';
import '../../services/hacer_export_service.dart';
import '../../services/planilla_admin_pdf_service.dart';
import '../../theme/inces_theme.dart';
import 'cpanel_inscripciones_cola_dialog.dart';
import 'cpanel_inscripciones_inscritos_dialog.dart';
import 'reincorporar_dialog.dart';
import '../../widgets/comunes.dart';
import '../../core/refresco_secciones.dart';
import '../../widgets/responsivo.dart';
import 'asistente_curriculo_screen.dart';

/// Panel de programas académicos (Módulo 2).
///
/// Es la puerta de entrada al asistente de tres pasos. La lista no se limita a
/// mostrar programas: avisa de los que están **vacíos**, porque un programa sin
/// materias no se puede activar —el backend lo rechaza con un 400 desde el
/// trigger diferido— y descubrirlo al pulsar el interruptor es tarde.
///
/// **Ninguna acción borra.** Archivar es desactivar: un `DELETE` se llevaría por
/// delante el histórico de secciones y notas que apunta al programa.
class CpanelProgramasPanel extends StatefulWidget {
  const CpanelProgramasPanel({
    super.key,
    this.repositorio,
    this.repositorioInscripciones,
  });

  final CurriculoRepository? repositorio;
  final AdminInscripcionesRepository? repositorioInscripciones;

  @override
  State<CpanelProgramasPanel> createState() => _CpanelProgramasPanelState();
}

class _CpanelProgramasPanelState extends State<CpanelProgramasPanel>
    with RefrescoAlVolver<CpanelProgramasPanel> {
  late final CurriculoRepository _repo =
      widget.repositorio ?? CurriculoRepository();

  /// Repositorio de inscripciones: el resumen por curso absorbe «Inscripciones y
  /// Cupos» dentro de este único módulo «Cursos y PNA».
  late final AdminInscripcionesRepository _repoInscripciones =
      widget.repositorioInscripciones ?? AdminInscripcionesRepository();
  late final HacerExportService _exportacion = HacerExportService();
  late final PlanillaAdminPdfService _planillaAdmin = PlanillaAdminPdfService();

  final _busquedaCtrl = TextEditingController();
  Timer? _debounce;

  TipoPrograma? _tipo = TipoPrograma.cursoLibre;
  String _tabVista = 'cursos';
  bool? _activo;
  int _desplazamiento = 0;

  List<ProgramaConTotales> _programas = const [];
  int _total = 0;
  bool _cargando = true;
  String? _error;

  /// Resumen de ocupación por programa (de `GET /api/v1/admin/cursos/resumen`),
  /// indexado por `programaId`. Es complementario: si falla, las tarjetas
  /// muestran el cupo del propio programa.
  Map<String, ResumenCurso> _resumenPorPrograma = const {};

  /// Identificador del programa cuya activación está en curso. Se bloquea sólo
  /// esa fila: el guardado de un programa no debe impedir mirar los demás.
  String? _guardandoId;
  bool _mostrarAyuda = false;

  static const int _limite = CurriculoRepository.limitePorPagina;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    setState(() {
      // **Refresco en segundo plano:** si ya hay datos no se vuelve a mostrar el
      // esqueleto; se conserva lo que hay hasta que llegue lo nuevo.
      _cargando = silencioso ? false : true;
      if (!silencioso) _error = null;
    });

    final resultado = await _repo.listarProgramas(
      tipo: _tipo,
      activo: _activo,
      busqueda: _busquedaCtrl.text,
      limite: _limite,
      desplazamiento: _desplazamiento,
    );
    // El resumen por programa es complementario (ver `_resumenPorPrograma`): si
    // falla, las tarjetas siguen mostrando el cupo del propio programa.
    final resumenResult = await _repoInscripciones.obtenerResumenCursos();
    if (!mounted) return;

    resultado.when(
      success: (pagina) {
        _programas = pagina.programas;
        _total = pagina.total;
        marcarCarga();
      },
      failure: (fallo) => _error = fallo.message,
    );

    switch (resumenResult) {
      case Success(value: final cursos):
        _resumenPorPrograma = {for (final c in cursos) c.programaId: c};
      case Failure():
        _resumenPorPrograma = const {};
    }

    setState(() => _cargando = false);
  }

  @override
  String get seccion => 'Cursos y PNA';

  @override
  Future<void> refrescarEnSegundoPlano() => _cargar(silencioso: true);

  void _buscar(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _desplazamiento = 0;
      _cargar();
    });
  }

  void _cambiarFiltro({
    TipoPrograma? tipo,
    bool? activo,
    bool limpiarTipo = false,
    bool limpiarActivo = false,
  }) {
    setState(() {
      if (limpiarTipo) {
        _tipo = null;
        _tabVista = 'todos';
      } else if (tipo != null) {
        _tipo = tipo;
        _tabVista = tipo == TipoPrograma.cursoLibre
            ? 'cursos'
            : (tipo == TipoPrograma.carrera ? 'pna' : 'todos');
      }
      if (limpiarActivo) {
        _activo = null;
      } else if (activo != null) {
        _activo = activo;
      }
      _desplazamiento = 0;
    });
    _cargar();
  }

  int get _desde => _total == 0 ? 0 : _desplazamiento + 1;
  int get _hasta => _desplazamiento + _programas.length > _total
      ? _total
      : _desplazamiento + _programas.length;

  bool get _hayAnterior => _desplazamiento > 0;
  bool get _haySiguiente => _desplazamiento + _programas.length < _total;

  Future<void> _abrirAsistente() async {
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AsistenteCurriculoScreen(repositorio: _repo),
      ),
    );

    if (creado != true || !mounted) return;
    _desplazamiento = 0;
    await _cargar();
  }

  String? _abriendoPensumId;

  Future<void> _editarPensum(ProgramaConTotales programa) async {
    if (_abriendoPensumId != null) return;
    setState(() => _abriendoPensumId = programa.id);
    try {
      final resultado = await _repo.detallePrograma(programa.id);
      if (!mounted) return;

      final detalle = resultado.valueOrNull;
      if (detalle == null) {
        mostrarAviso(
          context,
          resultado.errorOrNull?.message ?? 'No pudimos cargar el pensum.',
          error: true,
        );
        return;
      }

      final guardado = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => AsistenteCurriculoScreen(
            repositorio: _repo,
            detalleInicial: detalle,
          ),
        ),
      );

      if (guardado != true || !mounted) return;
      await _cargar();
    } finally {
      if (mounted) setState(() => _abriendoPensumId = null);
    }
  }

  Future<void> _alternarActivo(ProgramaConTotales programa) async {
    if (_guardandoId != null) return;

    final quiereActivar = !programa.activo;

    // Se comprueba aquí, con la razón a la vista, en vez de dejar que el
    // administrador pulse y reciba un 400 que ya se podía prever: publicar un
    // programa sin materias lo rechaza el trigger diferido del backend.
    if (quiereActivar &&
        !puedeActivarse(totalMaterias: programa.totalMaterias)) {
      mostrarAviso(
        context,
        '«${programa.codigo}» no tiene materias. Añade el pensum antes de '
        'activarlo.',
        error: true,
      );
      return;
    }

    setState(() => _guardandoId = programa.id);

    final resultado = await _repo.actualizarPrograma(
      programa.id,
      CambiosPrograma(activo: quiereActivar),
    );

    if (mounted) setState(() => _guardandoId = null);
    if (!mounted) return;

    resultado.when(
      success: (actualizado) {
        setState(() {
          _programas = [
            for (final p in _programas)
              if (p.id == actualizado.id)
                ProgramaConTotales(
                  id: p.id,
                  codigo: actualizado.codigo,
                  nombre: actualizado.nombre,
                  tipo: actualizado.tipo,
                  requierePasantia: actualizado.requierePasantia,
                  activo: actualizado.activo,
                  totalMaterias: p.totalMaterias,
                  totalPeriodos: p.totalPeriodos,
                  creadoEn: p.creadoEn,
                  actualizadoEn: actualizado.actualizadoEn,
                )
              else
                p,
          ];
        });
        mostrarAviso(
          context,
          actualizado.activo
              ? '«${actualizado.codigo}» activado.'
              : '«${actualizado.codigo}» archivado.',
          exito: true,
        );
      },
      failure: (fallo) => mostrarAviso(context, fallo.message, error: true),
    );
  }

  Future<void> _verDetalle(ProgramaConTotales programa) async {
    final resultado = await _repo.detallePrograma(programa.id);
    if (!mounted) return;

    final detalle = resultado.valueOrNull;
    if (detalle == null) {
      mostrarAviso(
        context,
        resultado.errorOrNull?.message ?? 'No pudimos cargar el programa.',
        error: true,
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => _DialogoDetallePrograma(
        detalle: detalle,
        onEditarPensum: () {
          Navigator.of(context).pop();
          _editarPensum(programa);
        },
      ),
    );
  }

  Future<void> _editarPrograma(ProgramaConTotales programa) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoEditarPrograma(repo: _repo, programa: programa),
    );
    if (guardado == true && mounted) {
      mostrarAviso(context, 'Programa actualizado correctamente.', exito: true);
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        // En el teléfono desliza el panel entero (ver `CuadranteGrid.compacto` y
        // Guardias, que ya lo hacía). Sin esto, cabecera + filtros + franja de
        // resumen se comen la pantalla y la lista se queda sin altura.
        final compacto =
            restricciones.maxWidth < 600 || restricciones.maxHeight < 700;

        final cuerpo = EstadoPanel(
          cargando: _cargando,
          error: _error,
          onReintentar: _cargar,
          // Este panel **sí** tiene barra de busqueda y filtros, así que el
          // esqueleto los pinta: coincide con lo que va a aparecer.
          esqueleto: const EsqueletoLista(conBarraFiltros: true),
          child: _lista(compacto: compacto),
        );

        final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloSeccion(
          'Cursos y PNA',
          subtitulo: 'Cursos ordinarios y formación técnica PNA. Modifica cupos, duración y materias formativas.',
          acciones: [
            IconButton(
              tooltip: _mostrarAyuda
                  ? 'Ocultar guía de pensum'
                  : 'Ver guía de pensum',
              icon: Icon(
                _mostrarAyuda ? Icons.info_rounded : Icons.info_outline_rounded,
                size: 20,
              ),
              onPressed: () => setState(() => _mostrarAyuda = !_mostrarAyuda),
            ),
            FilledButton.icon(
              onPressed: _abrirAsistente,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nuevo curso / PNA'),
            ),
          ],
        ),
        if (_mostrarAyuda) ...[
          const SizedBox(height: 8),
          AvisoEnLinea(
            texto:
                'Cada curso y programa PNA tiene su pensum: las materias y el período en que '
                'se dictan. Puedes editar los datos del curso con el lápiz y gestionar sus materias '
                'con «Gestionar pensum». Un programa sin materias no se puede publicar.',
            onCerrar: () => setState(() => _mostrarAyuda = false),
          ),
        ],
        const SizedBox(height: 10),
        _filtros(),
        const SizedBox(height: 10),
        if (_resumenPorPrograma.isNotEmpty) ...[
          _FranjaResumen(resumen: _resumenPorPrograma.values.toList()),
          const SizedBox(height: 10),
        ],
        if (compacto) cuerpo else Expanded(child: cuerpo),
      ],
        );

        return compacto
            ? SingleChildScrollView(child: contenido)
            : contenido;
      },
    );
  }

  Widget _filtros() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final selectorTipo = SegmentedButton<String>(
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          segments: const [
            ButtonSegment<String>(
              value: 'cursos',
              icon: Icon(Icons.auto_stories_outlined, size: 15),
              label: Text('Cursos'),
            ),
            ButtonSegment<String>(
              value: 'pna',
              icon: Icon(Icons.school_outlined, size: 15),
              label: Text('PNA (Aprendices)'),
            ),
            ButtonSegment<String>(
              value: 'todos',
              icon: Icon(Icons.apps_outlined, size: 15),
              label: Text('Todos'),
            ),
          ],
          selected: {_tabVista},
          onSelectionChanged: (set) {
            final nuevo = set.first;
            setState(() {
              _tabVista = nuevo;
              if (nuevo == 'cursos') {
                _tipo = TipoPrograma.cursoLibre;
              } else if (nuevo == 'pna') {
                _tipo = TipoPrograma.carrera;
              } else {
                _tipo = null;
              }
              _desplazamiento = 0;
            });
            _cargar();
          },
        );

        final campoBusqueda = ListenableBuilder(
          listenable: _busquedaCtrl,
          builder: (context, _) => TextField(
            controller: _busquedaCtrl,
            onChanged: _buscar,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              hintText: 'Buscar por código o nombre',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _busquedaCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _busquedaCtrl.clear();
                        _buscar('');
                      },
                    )
                  : null,
            ),
          ),
        );

        final dropdownEstado = SizedBox(
          width: ancho < 520 ? 135 : 180,
          child: DropdownButtonFormField<bool?>(
            initialValue: _activo,
            isExpanded: true,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              labelText: 'Estado',
            ),
            items: const [
              DropdownMenuItem(
                value: null,
                child: Text(
                  'Todos los estados',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: true,
                child: Text(
                  'Publicados / Vigentes',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: false,
                child: Text('En borrador', overflow: TextOverflow.ellipsis),
              ),
            ],
            onChanged: (valor) {
              if (valor == null) {
                _cambiarFiltro(limpiarActivo: true);
              } else {
                _cambiarFiltro(activo: valor);
              }
            },
          ),
        );

        if (ancho >= 760) {
          return Row(
            children: [
              selectorTipo,
              const SizedBox(width: 12),
              Expanded(child: campoBusqueda),
              const SizedBox(width: 12),
              dropdownEstado,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: selectorTipo),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: campoBusqueda),
                const SizedBox(width: 8),
                dropdownEstado,
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _lista({bool compacto = false}) {
    if (_programas.isEmpty) {
      // Desplazable y no un `Expanded` a secas: el estado vacío tiene su propia
      // altura y estirarlo hasta llenar la sección dejaría una tarjeta enorme
      // con el texto perdido arriba.
      return Center(
        child: SingleChildScrollView(
          child: PanelVacio(
            titulo: 'No hay programas que mostrar',
            mensaje: _total == 0 && _filtrosActivos
                ? 'Ningún programa coincide con los filtros aplicados. Prueba a '
                      'quitarlos.'
                : 'Todavía no se ha registrado ningún programa académico. Crea '
                      'el primero con el asistente: los datos del programa y su '
                      'pensum se guardan en una sola operación.',
            icono: Icons.menu_book_outlined,
            nota: 'Un programa sin materias no se puede activar.',
          ),
        ),
      );
    }

    final lista = ListView.separated(
      // En compacto la lista va dentro del scroll del panel: sin `shrinkWrap`
      // quedaría pidiendo altura infinita, y con él toma la de su contenido.
      shrinkWrap: compacto,
      physics: compacto ? const NeverScrollableScrollPhysics() : null,
      itemCount: _programas.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _TarjetaPrograma(
        programa: _programas[i],
        resumen: _resumenPorPrograma[_programas[i].id],
        repoInscripciones: _repoInscripciones,
        exportacion: _exportacion,
        planilla: _planillaAdmin,
        onAccion: () => _cargar(silencioso: true),
        guardando: _guardandoId == _programas[i].id,
        abriendoPensum: _abriendoPensumId == _programas[i].id,
        onVer: () => _verDetalle(_programas[i]),
        onEditarPrograma: () => _editarPrograma(_programas[i]),
        onEditarPensum: () => _editarPensum(_programas[i]),
        onAlternarActivo: () => _alternarActivo(_programas[i]),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compacto) lista else Expanded(child: lista),
        // **La barra de páginas sólo cuando hay más de una.** Medido el
        // 2026-10-29 en la captura de 390 px: con 6 cursos en una sola página, la
        // fila «1–6 de 6» y sus dos flechas ocupaban ~44 px fijos **sin ofrecer
        // nada** —ninguno de los dos botones se podía pulsar— y se sumaban al
        // encabezado y a los filtros hasta dejar el primer curso casi fuera de
        // pantalla. Cuando hay una sola página, la barra no informa: estorba.
        if (_hayAnterior || _haySiguiente) ...[
          const SizedBox(height: 12),
          _paginacion(),
        ],
      ],
    );
  }

  bool get _filtrosActivos =>
      _tipo != null || _activo != null || _busquedaCtrl.text.trim().isNotEmpty;

  Widget _paginacion() {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          '$_desde–$_hasta de $_total',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Página anterior',
          onPressed: _hayAnterior
              ? () {
                  setState(() => _desplazamiento -= _limite);
                  _cargar();
                }
              : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          tooltip: 'Página siguiente',
          onPressed: _haySiguiente
              ? () {
                  setState(() => _desplazamiento += _limite);
                  _cargar();
                }
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
//  Fila de programa
// -----------------------------------------------------------------------------

class _TarjetaPrograma extends StatelessWidget {
  const _TarjetaPrograma({
    required this.programa,
    this.resumen,
    required this.repoInscripciones,
    required this.exportacion,
    required this.planilla,
    required this.onAccion,
    required this.guardando,
    this.abriendoPensum = false,
    required this.onVer,
    required this.onEditarPrograma,
    required this.onEditarPensum,
    required this.onAlternarActivo,
  });

  final ProgramaConTotales programa;
  final ResumenCurso? resumen;
  final AdminInscripcionesRepository repoInscripciones;
  final HacerExportService exportacion;
  final PlanillaAdminPdfService planilla;
  final VoidCallback onAccion;
  final bool guardando;
  final bool abriendoPensum;
  final VoidCallback onVer;
  final VoidCallback onEditarPrograma;
  final VoidCallback onEditarPensum;
  final VoidCallback onAlternarActivo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paleta = PaletaInces.de(context);
    final parIcono = paleta.etiquetaDe(TonoEstado.info);
    final vacio = programa.estaVacio;

    final icono = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: parIcono.fondo,
        borderRadius: BorderRadius.circular(IncesTheme.radioControl),
      ),
      child: Icon(
        programa.tipo == TipoPrograma.carrera
            ? Icons.school_outlined
            : Icons.auto_stories_outlined,
        size: 18,
        color: parIcono.texto,
      ),
    );
    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                programa.nombre,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: _Etiqueta(texto: programa.codigo, tono: TonoEstado.neutro),
            ),
            if (vacio) ...[
              const SizedBox(width: 6),
              Flexible(
                child: const _Etiqueta(
                  texto: 'Sin pensum',
                  tono: TonoEstado.error,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Etiqueta(
              texto: programa.tipo == TipoPrograma.cursoLibre
                  ? 'Curso Ordinario'
                  : 'PNA (Aprendices)',
              tono: TonoEstado.info,
            ),
            _Etiqueta(
              texto: programa.activo ? 'Vigente / Activo' : 'En borrador',
              tono: programa.activo ? TonoEstado.exito : TonoEstado.neutro,
            ),
            if (programa.requierePasantia)
              const _Etiqueta(texto: 'Con pasantía', tono: TonoEstado.info),
            if (programa.duracionLegible != null)
              _Etiqueta(
                texto: programa.duracionLegible!,
                tono: TonoEstado.info,
              ),
            // El resumen por programa (panel «Cursos y PNA» absorbe «Inscripciones
            // y Cupos») trae cupo/ocupados/disponibles y la ventana de
            // inscripción. Si no está disponible, se cae al cupo del programa.
            if (resumen != null)
              _Etiqueta(
                texto: '${resumen!.ocupados} de ${resumen!.cupo} cupos · '
                    '${resumen!.disponibles} libres',
                tono: TonoEstado.info,
              )
            else
              _Etiqueta(
                texto: '${programa.cuposOcupados} de ${programa.cupo ?? 25} cupos',
                tono: TonoEstado.info,
              ),
            if (resumen != null)
              _Etiqueta(
                texto: _textoEstadoVentana(resumen!.estadoInscripcion),
                tono: _tonoEstadoVentana(resumen!.estadoInscripcion),
              ),
            if (programa.inscripcionFin != null)
              _Etiqueta(
                texto: 'Inscripciones hasta ${_fechaCorta(programa.inscripcionFin!)}',
                tono: TonoEstado.exito,
              ),
            if (programa.proximaApertura != null)
              _Etiqueta(
                texto: 'Nueva apertura: ${_fechaCorta(programa.proximaApertura!)}',
                tono: TonoEstado.neutro,
              ),
            if (!programa.mostrarDisponibilidad)
              const _Etiqueta(texto: 'Cupos ocultos', tono: TonoEstado.neutro),
            Text(
              '${programa.totalMaterias} '
              '${programa.totalMaterias == 1 ? 'materia' : 'materias'}'
              ' · ${programa.totalPeriodos} '
              '${programa.totalPeriodos == 1 ? 'período' : 'períodos'}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        if (resumen != null && resumen!.secciones.isNotEmpty) ...[
          const Divider(height: 1),
          const SizedBox(height: 6),
          Text(
            'Grupos / Secciones',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          for (final s in resumen!.secciones)
            _FilaSeccionCupo(
              seccion: s,
              repo: repoInscripciones,
              exportacion: exportacion,
              planilla: planilla,
              onAccion: onAccion,
            ),
        ],
        const SizedBox(height: 6),
        // En angosto el botón no cabe en la misma línea que el aviso:
        // su ancho intrínseco (~250 px) desbordaba la Row (medido:
        // +129 px a 360). Dos líneas bajo 480 px, una arriba.
        LayoutBuilder(
          builder: (context, c) {
            final enColumna = c.maxWidth < 480;
            final aviso = Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 15,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Requiere pensum para recibir inscripciones',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
            final boton = Padding(
              padding: EdgeInsets.only(top: enColumna ? 6 : 0),
              child: FilledButton.tonalIcon(
                onPressed: abriendoPensum ? null : onEditarPensum,
                icon: abriendoPensum
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    : const Icon(Icons.playlist_add_rounded, size: 15),
                label: const Text('Cargar pensum'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
            final gestionar = TextButton.icon(
              onPressed: abriendoPensum ? null : onEditarPensum,
              icon: abriendoPensum
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : const Icon(Icons.menu_book_rounded, size: 15),
              label: const Text('Gestionar pensum'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                textStyle: const TextStyle(fontSize: 12),
              ),
            );

            if (!vacio) {
              final textoAsignadas = Text(
                '${programa.totalMaterias} ${programa.totalMaterias == 1 ? 'materia' : 'materias'} asignadas',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              );
              // En angosto el botón «Gestionar pensum» no cabe junto al texto
              // (min ~145 px): se apila en vez de desbordar.
              return enColumna
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [textoAsignadas, gestionar],
                    )
                  : Row(children: [Expanded(child: textoAsignadas), gestionar]);
            }
            if (enColumna) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [aviso, boton],
              );
            }
            return Row(children: [aviso, boton]);
          },
        ),
      ],
    );

    final publicar = guardando
        ? const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : Tooltip(
            message: vacio && !programa.activo
                ? 'Sin materias: añade el pensum primero'
                : programa.activo
                ? 'Archivar'
                : 'Publicar',
            child: Switch(
              value: programa.activo,
              onChanged: (_) => onAlternarActivo(),
            ),
          );
    final editar = IconButton(
      tooltip: 'Editar datos del curso / PNA',
      onPressed: onEditarPrograma,
      icon: const Icon(Icons.edit_outlined, size: 20),
    );
    final ver = IconButton(
      tooltip: 'Ver pensum',
      onPressed: onVer,
      icon: const Icon(Icons.visibility_outlined, size: 19),
    );

    // **La columna lateral de acciones se retira en pantallas angostas.**
    // Medido a 360 (Redmi 10C): icono + switch + lápiz + ojo dejaban la
    // columna de texto con ~102 px útiles — el contenido no cabía y la fila
    // desbordaba. En angosto, editar/ver bajan a una fila propia.
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: LayoutBuilder(
          builder: (context, c) {
            final enColumna = c.maxWidth < 420;
            if (!enColumna) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  icono,
                  const SizedBox(width: 12),
                  Expanded(child: contenido),
                  const SizedBox(width: 4),
                  publicar,
                  editar,
                  ver,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    icono,
                    const SizedBox(width: 12),
                    Expanded(child: contenido),
                    const SizedBox(width: 4),
                    publicar,
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [editar, ver],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Etiqueta de estado de un programa: una palabra sobre un tinte.
///
/// Recibe un **tono**, no un color. Antes recibía un `Color` y por ahí entraban
/// tanto los acentos de relleno de `IncesTheme` como el `colorScheme.primary` del
/// tema: el ámbar daba 1.81:1 sobre su propio tinte en claro y el primario de
/// oscuro, 1.99:1. Con un tono el color no se puede elegir mal — lo resuelve
/// `PaletaInces` con el brillo montado, y el 12 % del tinte se decide en un solo
/// sitio. Medido el 2026-09-30.
/// Fecha `YYYY-MM-DD` del backend a `d/m` para chips compactos.
String _fechaCorta(String iso) {
  final partes = iso.split('-');
  if (partes.length != 3) return iso;
  final d = int.tryParse(partes[2]);
  final m = int.tryParse(partes[1]);
  if (d == null || m == null) return iso;
  return '$d/$m';
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, required this.tono});

  final String texto;
  final TonoEstado tono;

  @override
  Widget build(BuildContext context) {
    final par = PaletaInces.de(context).etiquetaDe(tono);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: par.fondo,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        texto,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: par.texto,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
//  Detalle del programa
// -----------------------------------------------------------------------------

/// Franja de métricas agregadas del resumen por programa (cupo global del
/// módulo «Cursos y PNA», que absorbió «Inscripciones y Cupos»).
class _FranjaResumen extends StatelessWidget {
  const _FranjaResumen({required this.resumen});

  final List<ResumenCurso> resumen;

  @override
  Widget build(BuildContext context) {
    final secciones = resumen.fold<int>(0, (s, r) => s + r.secciones.length);
    final ocupados = resumen.fold<int>(0, (s, r) => s + r.ocupados);
    final disponibles = resumen.fold<int>(0, (s, r) => s + r.disponibles);

    return LayoutBuilder(
      builder: (context, restricciones) {
        final ancho = restricciones.maxWidth >= 480
            ? 200.0
            : (restricciones.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: ancho,
              child: TarjetaMetrica(
                etiqueta: 'Grupos activos',
                valor: '$secciones',
                icono: Icons.explore_outlined,
              ),
            ),
            SizedBox(
              width: ancho,
              child: TarjetaMetrica(
                etiqueta: 'Cupos ocupados',
                valor: '$ocupados',
                icono: Icons.people_outline,
              ),
            ),
            SizedBox(
              width: ancho,
              child: TarjetaMetrica(
                etiqueta: 'Cupos disponibles',
                valor: '$disponibles',
                icono: Icons.event_seat_outlined,
                tono: TonoEstado.exito,
              ),
            ),
          ],
        );
      },
    );
  }
}

String _textoEstadoVentana(EstadoVentanaInscripcion e) => switch (e) {
      EstadoVentanaInscripcion.abierta => 'Inscripción abierta',
      EstadoVentanaInscripcion.cerrada => 'Inscripción cerrada',
      EstadoVentanaInscripcion.proximaApertura => 'Próxima apertura',
    };

TonoEstado _tonoEstadoVentana(EstadoVentanaInscripcion e) => switch (e) {
      EstadoVentanaInscripcion.abierta => TonoEstado.exito,
      EstadoVentanaInscripcion.cerrada => TonoEstado.neutro,
      EstadoVentanaInscripcion.proximaApertura => TonoEstado.info,
    };

/// Fila de una sección dentro de la tarjeta del programa: nombre + acciones de
/// cupo reutilizadas del antiguo panel «Inscripciones y Cupos» (ver
/// `cpanel_inscripciones_cola_dialog`, `..._inscritos_dialog`, `reincorporar_dialog`).
class _FilaSeccionCupo extends StatefulWidget {
  const _FilaSeccionCupo({
    required this.seccion,
    required this.repo,
    required this.exportacion,
    required this.planilla,
    required this.onAccion,
  });

  final SeccionResumenCurso seccion;
  final AdminInscripcionesRepository repo;
  final HacerExportService exportacion;
  final PlanillaAdminPdfService planilla;
  final VoidCallback onAccion;

  @override
  State<_FilaSeccionCupo> createState() => _FilaSeccionCupoState();
}

class _FilaSeccionCupoState extends State<_FilaSeccionCupo> {
  bool _promoviendo = false;
  bool _exportando = false;

  static const ButtonStyle _estilo = ButtonStyle(
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  Future<void> _promover() async {
    if (_promoviendo) return;
    setState(() => _promoviendo = true);
    final resultado = await widget.repo.promoverSiguiente(widget.seccion.id);
    if (!mounted) return;
    setState(() => _promoviendo = false);
    resultado.when(
      success: (promovida) {
        mostrarAviso(
          context,
          'Promovido ${promovida.etiquetaEstudiante}: ya tiene su asiento.',
          exito: true,
        );
        widget.onAccion();
      },
      failure: (fallo) => mostrarAviso(context, fallo.message, error: true),
    );
  }

  Future<void> _exportar() async {
    if (_exportando) return;
    setState(() => _exportando = true);
    final resultado = await widget.exportacion.exportarSeccion(
      seccionId: widget.seccion.id,
      periodo: widget.seccion.periodo ?? '',
      seccion: widget.seccion.nombre,
      materia: null,
    );
    if (!mounted) return;
    setState(() => _exportando = false);

    // `switch` sobre un `sealed`: si el servicio gana un desenlace nuevo, esto
    // deja de compilar en vez de dejar caer el caso al vacío.
    switch (resultado) {
      case ConsultaFallida(mensaje: final mensaje):
        mostrarAviso(context, mensaje, error: true);
      case DescargaFallida():
        mostrarAviso(
          context,
          'No se pudo descargar el archivo. Inténtalo de nuevo.',
          error: true,
        );
      case NadaQueExportar(seccion: final nombre):
        mostrarAviso(
          context,
          'La sección «$nombre» no tiene matriculados todavía: no hay '
          'nómina que exportar.',
        );
      case NominaDescargada(nombreArchivo: final nombre, matriculados: final total):
        mostrarAviso(
          context,
          'Nómina exportada: $total matriculados en «$nombre».',
          exito: true,
        );
    }
  }

  Future<void> _reincorporar() async {
    final hecho = await mostrarReincorporar(
      context: context,
      repo: widget.repo,
      seccionId: widget.seccion.id,
      seccionNombre: widget.seccion.nombre,
    );
    if (hecho == true && mounted) widget.onAccion();
  }

  void _verCola() => mostrarColaDeSeccion(
        context: context,
        repo: widget.repo,
        seccionId: widget.seccion.id,
        seccionNombre: widget.seccion.nombre,
      );

  void _verInscritos() => mostrarInscritosDeSeccion(
        context: context,
        repo: widget.repo,
        planilla: widget.planilla,
        seccionId: widget.seccion.id,
        seccionNombre: widget.seccion.nombre,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.groups_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.seccion.nombre,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.seccion.periodo != null)
                Text(
                  widget.seccion.periodo!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: _verCola,
                icon: const Icon(Icons.list_alt_outlined, size: 15),
                label: const Text('Ver cola'),
                style: _estilo,
              ),
              OutlinedButton.icon(
                onPressed: _verInscritos,
                icon: const Icon(Icons.badge_outlined, size: 15),
                label: const Text('Ver inscritos'),
                style: _estilo,
              ),
              OutlinedButton.icon(
                onPressed: _exportando ? null : _exportar,
                icon: _exportando
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined, size: 15),
                label: Text(_exportando ? 'Exportando…' : 'Exportar HACER'),
                style: _estilo,
              ),
              OutlinedButton.icon(
                onPressed: _reincorporar,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 15),
                label: const Text('Reincorporar'),
                style: _estilo,
              ),
              FilledButton.icon(
                onPressed: _promoviendo ? null : _promover,
                icon: _promoviendo
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward_outlined, size: 15),
                label: Text(_promoviendo ? 'Promoviendo…' : 'Promover siguiente'),
                style: _estilo,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DialogoDetallePrograma extends StatelessWidget {
  const _DialogoDetallePrograma({
    required this.detalle,
    required this.onEditarPensum,
  });

  final DetallePrograma detalle;
  final VoidCallback onEditarPensum;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              detalle.programa.nombre,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _Etiqueta(texto: detalle.programa.codigo, tono: TonoEstado.neutro),
        ],
      ),
      content: SizedBox(
        width: anchoDialogoSeguro(context, 560),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text(
                    '${detalle.totalMaterias} materias',
                    style: theme.textTheme.labelSmall,
                  ),
                  Text(
                    '${detalle.totalPeriodos} períodos',
                    style: theme.textTheme.labelSmall,
                  ),
                  Text(
                    '${detalle.totalHoras} horas',
                    style: theme.textTheme.labelSmall,
                  ),
                  Text(
                    'Creado: ${formatearFechaHora(detalle.programa.creadoEn)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // `editable` viene calculado del backend y es la Regla 2 hecha
              // dato: con secciones activas del período vigente, el pensum no se
              // toca. Se explica aquí para que el administrador no crea que el
              // botón está roto.
              if (!detalle.editable) ...[
                AvisoEnLinea(
                  tono: TonoAviso.advertencia,
                  icono: Icons.lock_outline,
                  texto:
                      'Pensum bloqueado: hay ${detalle.seccionesActivas} '
                      'secciones activas del período vigente cursando este '
                      'programa. Añadir materias sí está permitido; quitarlas o '
                      'reordenarlas, no.',
                ),
                const SizedBox(height: 16),
              ],

              if (detalle.pensum.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'El pensum está vacío.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final grupo in detalle.pensum) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Período ${grupo.periodo}',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  for (final materia in grupo.materias)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4, left: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              materia.nombre,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          Text(
                            '${materia.codigo} · ${materia.horasAcademicas} h',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        OutlinedButton.icon(
          onPressed: onEditarPensum,
          icon: const Icon(Icons.edit_outlined, size: 17),
          label: const Text('Editar pensum'),
        ),
      ],
    );
  }
}

/// Modal para editar los datos y metadatos de un programa formativo.
class _DialogoEditarPrograma extends StatefulWidget {
  const _DialogoEditarPrograma({required this.repo, required this.programa});

  final CurriculoRepository repo;
  final ProgramaConTotales programa;

  @override
  State<_DialogoEditarPrograma> createState() => _DialogoEditarProgramaState();
}

class _DialogoEditarProgramaState extends State<_DialogoEditarPrograma> {
  final _forma = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl = TextEditingController(
    text: widget.programa.nombre,
  );
  late bool _requierePasantia = widget.programa.requierePasantia;
  late final TextEditingController _duracionValorCtrl = TextEditingController(
    text: widget.programa.duracionValor?.toString() ?? '',
  );
  late String _duracionUnidad = widget.programa.duracionUnidad ?? 'MESES';
  late final TextEditingController _cupoCtrl = TextEditingController(
    text: (widget.programa.cupo ?? 25).toString(),
  );
  late bool _mostrarDisponibilidad = widget.programa.mostrarDisponibilidad;
  late DateTime? _inscripcionInicio = widget.programa.inscripcionInicio != null
      ? DateTime.tryParse(widget.programa.inscripcionInicio!)
      : null;
  late DateTime? _inscripcionFin = widget.programa.inscripcionFin != null
      ? DateTime.tryParse(widget.programa.inscripcionFin!)
      : null;
  late DateTime? _proximaApertura = widget.programa.proximaApertura != null
      ? DateTime.tryParse(widget.programa.proximaApertura!)
      : null;

  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _duracionValorCtrl.dispose();
    _cupoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!_forma.currentState!.validate()) return;

    final duracionTexto = _duracionValorCtrl.text.trim();
    int? duracionVal;
    if (duracionTexto.isNotEmpty) {
      duracionVal = int.tryParse(duracionTexto);
    }

    final cupoTexto = _cupoCtrl.text.trim();
    final cupoVal = int.tryParse(cupoTexto);

    setState(() {
      _guardando = true;
      _error = null;
    });

    final cambios = CambiosPrograma(
      nombre: _nombreCtrl.text.trim() != widget.programa.nombre
          ? _nombreCtrl.text.trim()
          : null,
      requierePasantia: _requierePasantia != widget.programa.requierePasantia
          ? _requierePasantia
          : null,
      duracionValor: duracionVal,
      duracionUnidad: duracionVal != null ? _duracionUnidad : null,
      cupo: cupoVal != widget.programa.cupo ? cupoVal : null,
      mostrarDisponibilidad:
          _mostrarDisponibilidad != widget.programa.mostrarDisponibilidad
          ? _mostrarDisponibilidad
          : null,
      inscripcionInicio: _fechaIso(_inscripcionInicio) !=
              widget.programa.inscripcionInicio
          ? _fechaIso(_inscripcionInicio)
          : null,
      inscripcionFin: _fechaIso(_inscripcionFin) != widget.programa.inscripcionFin
          ? _fechaIso(_inscripcionFin)
          : null,
      proximaApertura: _fechaIso(_proximaApertura) !=
              widget.programa.proximaApertura
          ? _fechaIso(_proximaApertura)
          : null,
    );

    if (cambios.vacio) {
      Navigator.of(context).pop(false);
      return;
    }

    final resultado = await widget.repo.actualizarPrograma(
      widget.programa.id,
      cambios,
    );
    if (!mounted) return;
    setState(() => _guardando = false);

    resultado.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (fallo) => setState(() => _error = fallo.message),
    );
  }

  String? _fechaIso(DateTime? d) =>
      d == null
          ? null
          : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _campoFecha({
    required String etiqueta,
    required DateTime? valor,
    required ValueChanged<DateTime?> onElegir,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _elegirFecha(etiqueta, onElegir),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: etiqueta,
          isDense: true,
          suffixIcon: valor == null
              ? const Icon(Icons.calendar_today_outlined, size: 18)
              : IconButton(
                  tooltip: 'Quitar fecha',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: () => onElegir(null),
                ),
        ),
        child: Text(
          valor == null
              ? 'Sin fecha'
              : '${valor.day}/${valor.month}/${valor.year}',
          style: TextStyle(
            color: valor == null
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : null,
          ),
        ),
      ),
    );
  }

  Future<void> _elegirFecha(
    String etiqueta,
    ValueChanged<DateTime?> onElegir,
  ) async {
    final ahora = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: ahora,
      firstDate: DateTime(ahora.year - 1),
      lastDate: DateTime(ahora.year + 5),
      helpText: etiqueta,
    );
    if (elegida != null) onElegir(elegida);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar programa formativo'),
      content: SizedBox(
        width: anchoDialogoSeguro(context, 480),
        child: SingleChildScrollView(
          child: Form(
            key: _forma,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Código: ${widget.programa.codigo}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Tipo: ${widget.programa.tipo.etiqueta}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del programa',
                    hintText: 'ej. Soldadura Básica Universal',
                    isDense: true,
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Indica el nombre' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: _duracionValorCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duración (número)',
                          hintText: 'ej. 6',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 6,
                      child: DropdownButtonFormField<String>(
                        initialValue: _duracionUnidad,
                        decoration: const InputDecoration(
                          labelText: 'Unidad de duración',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'MESES',
                            child: Text('Meses'),
                          ),
                          DropdownMenuItem(
                            value: 'SEMANAS',
                            child: Text('Semanas'),
                          ),
                          DropdownMenuItem(value: 'DIAS', child: Text('Días')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _duracionUnidad = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 14),
                      label: const Text('2 Semanas'),
                      onPressed: () {
                        setState(() {
                          // Suma sobre lo que ya hay: pulsar dos veces «+3 Meses» deben ser 6.
                          _duracionValorCtrl.text = '${(int.tryParse(_duracionValorCtrl.text) ?? 0) + 2}';
                          _duracionUnidad = 'SEMANAS';
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 14),
                      label: const Text('4 Semanas'),
                      onPressed: () {
                        setState(() {
                          // Suma sobre lo que ya hay: pulsar dos veces «+3 Meses» deben ser 6.
                          _duracionValorCtrl.text = '${(int.tryParse(_duracionValorCtrl.text) ?? 0) + 4}';
                          _duracionUnidad = 'SEMANAS';
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 14),
                      label: const Text('1 Mes'),
                      onPressed: () {
                        setState(() {
                          // Suma sobre lo que ya hay: pulsar dos veces «+3 Meses» deben ser 6.
                          _duracionValorCtrl.text = '${(int.tryParse(_duracionValorCtrl.text) ?? 0) + 1}';
                          _duracionUnidad = 'MESES';
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 14),
                      label: const Text('2 Meses'),
                      onPressed: () {
                        setState(() {
                          // Suma sobre lo que ya hay: pulsar dos veces «+3 Meses» deben ser 6.
                          _duracionValorCtrl.text = '${(int.tryParse(_duracionValorCtrl.text) ?? 0) + 2}';
                          _duracionUnidad = 'MESES';
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 14),
                      label: const Text('3 Meses'),
                      onPressed: () {
                        setState(() {
                          // Suma sobre lo que ya hay: pulsar dos veces «+3 Meses» deben ser 6.
                          _duracionValorCtrl.text = '${(int.tryParse(_duracionValorCtrl.text) ?? 0) + 3}';
                          _duracionUnidad = 'MESES';
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 14),
                      label: const Text('6 Meses'),
                      onPressed: () {
                        setState(() {
                          // Suma sobre lo que ya hay: pulsar dos veces «+3 Meses» deben ser 6.
                          _duracionValorCtrl.text = '${(int.tryParse(_duracionValorCtrl.text) ?? 0) + 6}';
                          _duracionUnidad = 'MESES';
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Requiere pasantías'),
                  subtitle: const Text(
                    'Fase práctica laboral en taller o empresa',
                  ),
                  value: _requierePasantia,
                  onChanged: (v) => setState(() => _requierePasantia = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('campo-cupo-programa'),
                  controller: _cupoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cupo máximo del curso',
                    hintText: 'ej. 25',
                    isDense: true,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Indica el cupo';
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 0) {
                      return 'El cupo debe ser un entero ≥ 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _campoFecha(
                  etiqueta: 'Abren inscripciones',
                  valor: _inscripcionInicio,
                  onElegir: (d) => setState(() => _inscripcionInicio = d),
                ),
                const SizedBox(height: 12),
                _campoFecha(
                  etiqueta: 'Cierran inscripciones',
                  valor: _inscripcionFin,
                  onElegir: (d) => setState(() => _inscripcionFin = d),
                ),
                const SizedBox(height: 12),
                _campoFecha(
                  etiqueta: 'Próxima apertura',
                  valor: _proximaApertura,
                  onElegir: (d) => setState(() => _proximaApertura = d),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Disponibilidad de cupos visible'),
                  subtitle: const Text(
                    'Muestra los cupos restantes en landing y portal',
                  ),
                  value: _mostrarDisponibilidad,
                  onChanged: (v) => setState(() => _mostrarDisponibilidad = v),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
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
