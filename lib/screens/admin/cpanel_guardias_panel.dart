import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';
import '../../core/gateways/cuadrante_gateway.dart';
import '../../core/reglas_cuadrante.dart';
import '../../core/result.dart';
import '../../models/cuadrante.dart';
import '../../repositories/cuadrante_repository.dart';
import '../../theme/inces_theme.dart';
import '../../widgets/comunes.dart';
import '../../widgets/cuadrante_grid.dart';
import 'cpanel_invitaciones_panel.dart';

/// Panel de guardias docentes (Módulo 3).
///
/// Una guardia es **una presencia**, no una clase: dice quién custodia qué
/// espacio, qué día y en qué bloque, **haya clase o no**. Por eso es su propia
/// tabla y no un tipo de clase, y por eso este panel existe aparte del
/// cuadrante: son dos cosas que se parecen en la rejilla y no en la realidad.
///
/// **Pertenece a un lapso (R-15).** Sin lapso, una guardia del lunes a primera
/// hora chocaría con las clases de cualquier lapso —el pasado, el vigente y el
/// que se está planificando—, así que el lapso no es un formalismo: es lo que
/// acota el chequeo a una agenda concreta. La pantalla abre en el lapso vigente
/// y **no inventa uno** cuando no lo hay: cuál está en curso es una decisión del
/// centro (R-19).
///
/// **De dónde salen los docentes, y por qué de ahí.** No hay una ruta de
/// catálogo de docentes: `GET /cuadrante` los devuelve junto a las aulas y al
/// lapso vigente, así que una sola llamada sirve la barra de filtros entera. La
/// alternativa —leer `profiles`— está descartada en el contrato (§6): la RLS es
/// por fila y no por columna, así que abrir la tabla para leer un nombre
/// entregaría cédula y correo de todo el claustro.
///
/// **Ninguna acción borra.** Archivar es `activa: false`, y el trigger sale
/// antes de comprobar cuando la guardia está inactiva: una guardia archivada no
/// ocupa a nadie, y sin esa salida temprana desactivarla seguiría bloqueando el
/// hueco que ya no usa. Reactivar, en cambio, **sí** puede chocar: el hueco pudo
/// ocuparlo otra presencia mientras tanto.
class CpanelGuardiasPanel extends StatefulWidget {
  const CpanelGuardiasPanel({
    super.key,
    this.repositorio,
    this.onNavegarA,
    this.vistaMatrizInicial = true,
  });

  final CuadranteRepository? repositorio;
  final void Function(String)? onNavegarA;
  final bool vistaMatrizInicial;

  @override
  State<CpanelGuardiasPanel> createState() => _CpanelGuardiasPanelState();
}

class _CpanelGuardiasPanelState extends State<CpanelGuardiasPanel> {
  late final CuadranteRepository _repo =
      widget.repositorio ?? CuadranteRepository();

  // --- Catálogos ------------------------------------------------------------

  List<Periodo> _periodos = const [];
  List<DocenteResumen> _docentes = const [];
  List<Aula> _aulas = const [];

  /// El lapso que se está mirando. `null` mientras el centro no haya declarado
  /// ninguno vigente y el usuario no haya elegido.
  String? _lapso;

  // --- Página ---------------------------------------------------------------

  List<Guardia> _guardias = const [];
  int _total = 0;
  int _desplazamiento = 0;

  String? _docenteFiltro;
  String? _aulaFiltro;
  int? _diaFiltro;
  int? _bloqueFiltro;
  bool? _activaFiltro;
  late bool _vistaMatriz = widget.vistaMatrizInicial;

  bool _cargando = true;
  String? _error;

  /// Identificador de la guardia cuya escritura está en curso. Se bloquea sólo
  /// esa fila: archivar una no debe impedir mirar las demás.
  String? _guardandoId;

  static const int _limite = CuadranteRepository.limitePorPagina;

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

    // --- Catálogo de lapsos ---
    final periodos = await _repo.listarPeriodos();
    if (!mounted) return;

    if (periodos case Failure<List<Periodo>>(:final error)) {
      setState(() {
        _cargando = false;
        _error = error.message;
      });
      return;
    }

    _periodos = (periodos as Success<List<Periodo>>).value;
    _lapso ??= _codigoVigente();

    // --- Docentes y aulas, de la rejilla ---
    //
    // Se pide con el lapso elegido, pero las dos listas que se aprovechan no
    // dependen de él: la rejilla las devuelve siempre, incluso cuando no hay
    // ninguno vigente. Eso es justo lo que permite pintar los filtros y decir
    // «no hay lapso vigente» en vez de quedarse en blanco.
    final cuadricula = await _repo.rejilla(periodo: _lapso);
    if (!mounted) return;

    if (cuadricula case Failure<RejillaCuadrante>(:final error)) {
      setState(() {
        _cargando = false;
        _error = error.message;
      });
      return;
    }

    final rejilla = (cuadricula as Success<RejillaCuadrante>).value;
    _docentes = rejilla.docentes;
    _aulas = rejilla.aulas;

    await _cargarPagina();
  }

  Future<void> _cargarPagina() async {
    final lapso = _lapso;

    if (lapso == null) {
      // No es un error: es que el centro todavía no ha declarado qué lapso está
      // en curso, y el sistema no elige por él.
      setState(() {
        _cargando = false;
        _guardias = const [];
        _total = 0;
      });
      return;
    }

    final limiteEfectivo = _vistaMatriz ? 100 : _limite;
    final resultado = await _repo.listarGuardias(
      periodo: lapso,
      docenteId: _docenteFiltro,
      aulaId: _aulaFiltro,
      dia: _diaFiltro,
      bloque: _bloqueFiltro,
      activa: _activaFiltro,
      limite: limiteEfectivo,
      desplazamiento: _vistaMatriz ? 0 : _desplazamiento,
    );

    if (!mounted) return;

    resultado.when(
      success: (pagina) => setState(() {
        _cargando = false;
        _guardias = pagina.guardias;
        _total = pagina.total;
      }),
      failure: (fallo) => setState(() {
        _cargando = false;
        _error = fallo.message;
      }),
    );
  }

  /// El código del lapso vigente, o `null` si el centro no ha declarado ninguno.
  String? _codigoVigente() {
    for (final periodo in _periodos) {
      if (periodo.vigente) return periodo.codigo;
    }
    return null;
  }

  /// Aplica un cambio de filtro y recarga desde la primera página.
  ///
  /// Volver al principio no es un detalle: quedarse en la página 4 con un filtro
  /// nuevo da una lista vacía que se lee como «no hay nada», cuando lo que pasa
  /// es que el resultado cabe en una página.
  void _refiltrar(void Function() cambio) {
    setState(() {
      cambio();
      _desplazamiento = 0;
    });
    _cargarPagina();
  }

  void _cambiarLapso(String? codigo) {
    if (codigo == null || codigo == _lapso) return;

    // Cambiar de lapso no recarga los catálogos: los docentes y las aulas del
    // centro son los mismos en todos los lapsos.
    setState(() {
      _lapso = codigo;
      _desplazamiento = 0;
    });
    _cargarPagina();
  }

  int get _desde => _total == 0 ? 0 : _desplazamiento + 1;
  int get _hasta =>
      _desplazamiento + _guardias.length > _total
          ? _total
          : _desplazamiento + _guardias.length;

  bool get _hayAnterior => _desplazamiento > 0;
  bool get _haySiguiente => _desplazamiento + _guardias.length < _total;

  bool get _filtrando =>
      _docenteFiltro != null ||
      _aulaFiltro != null ||
      _diaFiltro != null ||
      _bloqueFiltro != null ||
      _activaFiltro != null;

  /// El nombre del docente, o `null` si no está en el catálogo.
  ///
  /// Son dos huecos distintos y se dicen distinto. La rejilla devuelve las aulas
  /// **archivadas** a propósito —para que una celda no quede huérfana— pero de
  /// los docentes sólo devuelve los **activos**, así que una guardia de alguien
  /// desactivado después apunta a un id que ya no aparece. Y por R-21 el canal
  /// de invitación nunca capturó `nombres`/`apellidos`, así que el nombre puede
  /// llegar vacío aunque el docente exista.
  String? _nombreDelDocente(String id) {
    for (final docente in _docentes) {
      if (docente.id == id) return nombreDeDocente(docente.nombre);
    }
    return null;
  }

  String? _nombreDelAula(String id) {
    for (final aula in _aulas) {
      if (aula.id == id) return aula.nombre;
    }
    return null;
  }

  Future<void> _abrirFormulario({
    Guardia? existente,
    String? aulaIdInicial,
    int? diaInicial,
    int? bloqueInicial,
  }) async {
    final lapso = _lapso;
    if (lapso == null) return;

    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoGuardia(
        repo: _repo,
        periodo: lapso,
        docentes: _docentes,
        aulas: _aulas,
        existente: existente,
        aulaIdInicial: aulaIdInicial,
        diaInicial: diaInicial,
        bloqueInicial: bloqueInicial,
      ),
    );

    if (guardado != true || !mounted) return;
    if (existente == null) _desplazamiento = 0;
    await _cargarPagina();
  }

  Future<void> _alternarActiva(Guardia guardia) async {
    // Guarda de reentrada: dos pulsaciones rápidas lanzarían dos escrituras y la
    // segunda decidiría el estado final por azar.
    if (_guardandoId != null) return;

    setState(() => _guardandoId = guardia.id);

    final resultado = await _repo.actualizarGuardia(
      guardia.id,
      CambiosGuardia(activa: !guardia.activa),
    );

    if (!mounted) return;
    setState(() => _guardandoId = null);

    resultado.when(
      success: (actualizada) {
        mostrarAviso(
          context,
          actualizada.activa
              ? 'La guardia vuelve a estar activa. Ocupa otra vez su hueco.'
              : 'Guardia archivada. El hueco queda libre para otra presencia.',
          exito: true,
        );
        _cargarPagina();
      },
      // Reactivar puede chocar: el hueco pudo ocuparlo otra presencia mientras
      // la guardia estaba archivada, y el trigger vuelve a mirarlo en cuanto
      // `is_active` es verdadero.
      failure: (fallo) => mostrarAviso(context, _mensajeDeChoque(fallo), error: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cabecera(),
        const SizedBox(height: 12),
        _filtros(),
        const SizedBox(height: 16),
        // `Expanded` y no un `ListView` suelto: `ContenidoSeccion` entrega una
        // altura **acotada**, así que aquí se reparte en lugar de crecer.
        Expanded(
          child: EstadoPanel(
            cargando: _cargando,
            error: _error,
            onReintentar: _cargar,
            child: _vistaMatriz ? _matrizSemanal() : _lista(),
          ),
        ),
      ],
    );
  }

  Widget _cabecera() {
    final razon = _razonParaNoAsignar();

    final boton = FilledButton.icon(
      onPressed: razon == null ? () => _abrirFormulario() : null,
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('Asignar guardia'),
    );

    return TituloSeccion(
      'Guardias docentes',
      subtitulo: 'Rol de Guardia MTP / PNA - Pizarra de control de talleres y espacios. '
          'Quién custodia cada espacio por día y bloque, haya clase o no.',
      acciones: [
        if (widget.onNavegarA != null) ...[
          OutlinedButton.icon(
            onPressed: () => widget.onNavegarA?.call('Horarios de Clases'),
            icon: const Icon(Icons.calendar_month_outlined, size: 16),
            label: const Text('Horarios'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => widget.onNavegarA?.call('Espacios y Aulas'),
            icon: const Icon(Icons.meeting_room_outlined, size: 16),
            label: const Text('Aulas'),
          ),
          const SizedBox(width: 8),
        ],
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment<bool>(
              value: true,
              icon: Icon(Icons.grid_on_outlined, size: 16),
              label: Text('Matriz Semanal'),
            ),
            ButtonSegment<bool>(
              value: false,
              icon: Icon(Icons.view_list_outlined, size: 16),
              label: Text('Lista detallada'),
            ),
          ],
          selected: {_vistaMatriz},
          onSelectionChanged: (set) {
            setState(() => _vistaMatriz = set.first);
            _cargarPagina();
          },
        ),
        const SizedBox(width: 8),
        if (razon == null) boton else Tooltip(message: razon, child: boton),
      ],
    );
  }

  Widget _matrizSemanal() {
    if (_periodos.isEmpty) {
      return const PanelVacio(
        titulo: 'Todavía no hay lapsos registrados',
        mensaje: 'Una guardia pertenece siempre a un lapso: es lo que acota el '
            'chequeo de choques a una agenda concreta. Registra el lapso en '
            'curso en «Lapsos académicos» y vuelve a esta pantalla.',
        icono: Icons.event_note_outlined,
      );
    }

    if (_lapso == null) {
      return const PanelVacio(
        titulo: 'No hay ningún lapso vigente',
        mensaje: 'Elige un lapso en el filtro de arriba, o marca uno como '
            'vigente en «Lapsos académicos». Cuál está en curso es una '
            'decisión del centro, y el sistema no la toma por ti.',
        icono: Icons.play_circle_outline,
      );
    }

    if (_aulas.isEmpty) {
      return const PanelVacio(
        titulo: 'No hay espacios registrados',
        mensaje: 'Registra los talleres o aulas en «Espacios del centro» para armar el rol de guardias.',
        icono: Icons.meeting_room_outlined,
      );
    }

    final theme = Theme.of(context);
    final borderSide = BorderSide(color: theme.dividerColor.withValues(alpha: 0.6));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: borderSide,
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera: Días y turnos
              Container(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                child: Row(
                  children: [
                    Container(
                      width: 170,
                      height: 56,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(border: Border(right: borderSide, bottom: borderSide)),
                      child: Text(
                        'Espacio / Taller',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    for (var dia = 1; dia <= diaMaximo; dia++)
                      Container(
                        width: 280,
                        height: 56,
                        decoration: BoxDecoration(border: Border(right: borderSide, bottom: borderSide)),
                        child: Column(
                          children: [
                            Expanded(
                              flex: 26,
                              child: Container(
                                alignment: Alignment.center,
                                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                child: Text(
                                  diasDeLaSemana[dia],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 29,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(border: Border(right: borderSide)),
                                      child: const Text('Mañana (07:30-12)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      alignment: Alignment.center,
                                      child: const Text('Tarde (13:00-17:30)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Filas por espacio / aula
              for (final aula in _aulas)
                Container(
                  decoration: BoxDecoration(border: Border(bottom: borderSide)),
                  child: Row(
                    children: [
                      Container(
                        width: 170,
                        constraints: const BoxConstraints(minHeight: 64),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(border: Border(right: borderSide)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              aula.nombre,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            Text(
                              aula.tipo.etiqueta,
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      for (var dia = 1; dia <= diaMaximo; dia++)
                        Container(
                          width: 280,
                          constraints: const BoxConstraints(minHeight: 64),
                          decoration: BoxDecoration(border: Border(right: borderSide)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  constraints: const BoxConstraints(minHeight: 64),
                                  decoration: BoxDecoration(border: Border(right: borderSide)),
                                  child: _celdaMatriz(aula: aula, dia: dia, turno: Turno.manana),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  constraints: const BoxConstraints(minHeight: 64),
                                  child: _celdaMatriz(aula: aula, dia: dia, turno: Turno.tarde),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _celdaMatriz({required Aula aula, required int dia, required Turno turno}) {
    final guardias = _guardias.where((g) =>
        g.aulaId == aula.id &&
        g.dia == dia &&
        g.activa &&
        turnoDeBloque(g.bloque) == turno).toList();

    if (guardias.isEmpty) {
      return InkWell(
        onTap: () => _abrirFormulario(
          aulaIdInicial: aula.id,
          diaInicial: dia,
          bloqueInicial: turno == Turno.manana ? 1 : 7,
        ),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.add_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final g in guardias)
            InkWell(
              onTap: () => _abrirFormulario(existente: g),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: PaletaAulasCuadrante.colorGuardia.withValues(alpha: 0.15),
                  border: Border.all(color: PaletaAulasCuadrante.colorGuardia.withValues(alpha: 0.5), width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _nombreDelDocente(g.docenteId) ?? 'Docente asignado',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'B${g.bloque} (${horaLegibleDeBloque(g.bloque)})',
                      style: const TextStyle(fontSize: 10, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Por qué no se puede asignar todavía, o `null` si sí se puede.
  String? _razonParaNoAsignar() {
    if (_periodos.isEmpty) {
      return 'Registra un lapso antes: una guardia pertenece siempre a un lapso.';
    }
    if (_lapso == null) {
      return 'Elige un lapso, o marca uno como vigente en «Lapsos académicos».';
    }
    if (_docentes.isEmpty) {
      return 'No hay docentes activos a los que asignar la guardia.';
    }
    if (_aulas.isEmpty) {
      return 'Registra los espacios del centro: una guardia custodia un sitio '
          'concreto.';
    }
    return null;
  }

  Widget _filtros() {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Desplegable<String>(
          etiqueta: 'Lapso',
          ancho: 190,
          // Si el lapso elegido ya no está en el catálogo —lo borraron desde
          // otra pantalla— el desplegable se queda sin ítem que mostrar y
          // revienta al pintarlo. Se cae al vacío, que se ve y se puede
          // corregir.
          valor: _periodos.any((p) => p.codigo == _lapso) ? _lapso : null,
          opciones: [
            for (final periodo in _periodos)
              DropdownMenuItem(
                value: periodo.codigo,
                child: Text(
                  periodo.vigente
                      ? '${periodo.etiqueta} · vigente'
                      : periodo.etiqueta,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onCambiar: _cambiarLapso,
        ),
        _Desplegable<String?>(
          etiqueta: 'Docente',
          ancho: 230,
          valor: _docenteFiltro,
          opciones: [
            const DropdownMenuItem(value: null, child: Text('Todos')),
            for (final docente in _docentes)
              DropdownMenuItem(
                value: docente.id,
                child: Text(
                  nombreDeDocente(docente.nombre),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onCambiar: (valor) => _refiltrar(() => _docenteFiltro = valor),
        ),
        _Desplegable<String?>(
          etiqueta: 'Espacio',
          ancho: 200,
          valor: _aulaFiltro,
          opciones: [
            const DropdownMenuItem(value: null, child: Text('Todos')),
            for (final aula in _aulas)
              DropdownMenuItem(
                value: aula.id,
                child: Text(aula.nombre, overflow: TextOverflow.ellipsis),
              ),
          ],
          onCambiar: (valor) => _refiltrar(() => _aulaFiltro = valor),
        ),
        _Desplegable<int?>(
          etiqueta: 'Día',
          ancho: 140,
          valor: _diaFiltro,
          opciones: [
            const DropdownMenuItem(value: null, child: Text('Todos')),
            for (var dia = 1; dia <= diaMaximo; dia++)
              DropdownMenuItem(
                value: dia,
                child: Text(diasDeLaSemana[dia]),
              ),
          ],
          onCambiar: (valor) => _refiltrar(() => _diaFiltro = valor),
        ),
        _Desplegable<int?>(
          etiqueta: 'Bloque',
          ancho: 150,
          valor: _bloqueFiltro,
          opciones: [
            const DropdownMenuItem(value: null, child: Text('Todos')),
            for (var bloque = 1; bloque <= bloqueMaximo; bloque++)
              DropdownMenuItem(
                value: bloque,
                // El turno se enseña junto al bloque porque es lo que el bloque
                // significa: los seis primeros son la mañana.
                child: Text('B$bloque (${horaLegibleDeBloque(bloque)}) · ${turnoDeBloque(bloque).etiqueta}'),
              ),
          ],
          onCambiar: (valor) => _refiltrar(() => _bloqueFiltro = valor),
        ),
        _Desplegable<bool?>(
          etiqueta: 'Estado',
          ancho: 160,
          valor: _activaFiltro,
          opciones: const [
            DropdownMenuItem(value: null, child: Text('Todas')),
            DropdownMenuItem(value: true, child: Text('Activas')),
            DropdownMenuItem(value: false, child: Text('Archivadas')),
          ],
          onCambiar: (valor) => _refiltrar(() => _activaFiltro = valor),
        ),
        if (_total > 0)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '$_desde a $_hasta de $_total',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
      ],
    );
  }

  Widget _lista() {
    if (_periodos.isEmpty) {
      return const PanelVacio(
        titulo: 'Todavía no hay lapsos registrados',
        mensaje: 'Una guardia pertenece siempre a un lapso: es lo que acota el '
            'chequeo de choques a una agenda concreta. Registra el lapso en '
            'curso en «Lapsos académicos» y vuelve a esta pantalla.',
        icono: Icons.event_note_outlined,
      );
    }

    if (_lapso == null) {
      return const PanelVacio(
        titulo: 'No hay ningún lapso vigente',
        mensaje: 'Elige un lapso en el filtro de arriba, o marca uno como '
            'vigente en «Lapsos académicos». Cuál está en curso es una '
            'decisión del centro, y el sistema no la toma por ti.',
        icono: Icons.play_circle_outline,
      );
    }

    if (_guardias.isEmpty) {
      if (_filtrando) {
        return const PanelVacio(
          titulo: 'Ninguna guardia coincide con el filtro',
          mensaje: 'Prueba con otro día, otro bloque o quita el filtro de '
              'estado. Las guardias archivadas no aparecen salvo que las pidas.',
          icono: Icons.filter_alt_off_outlined,
        );
      }

      if (_aulas.isEmpty) {
        return const PanelVacio(
          titulo: 'No hay espacios registrados',
          mensaje: 'Una guardia custodia un sitio concreto: sin aulas, talleres '
              'ni zonas no hay nada que custodiar. Regístralos en «Espacios del '
              'centro».',
          icono: Icons.meeting_room_outlined,
        );
      }

      if (_docentes.isEmpty) {
        return const PanelVacio(
          titulo: 'No hay docentes activos',
          mensaje: 'El sistema sólo puede asignar una guardia a un docente con '
              'perfil activo. Los perfiles se crean invitándolos desde '
              '«Accesos».',
          icono: Icons.person_off_outlined,
        );
      }

      return PanelVacio(
        titulo: 'Todavía no hay guardias en este lapso',
        mensaje: 'Asigna la primera con «Asignar guardia». Las guardias se '
            'repiten por día y bloque, así que cada una es una presencia '
            'semanal.',
        icono: Icons.shield_outlined,
        nota: 'El sistema no siembra guardias de ejemplo: el reparto de '
            'custodia es una decisión del centro, y una guardia inventada '
            'bloquearía un hueco real.',
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: _guardias.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, indice) {
              final guardia = _guardias[indice];

              return _FilaGuardia(
                guardia: guardia,
                docente: _nombreDelDocente(guardia.docenteId),
                aula: _nombreDelAula(guardia.aulaId),
                guardando: _guardandoId == guardia.id,
                onEditar: () => _abrirFormulario(existente: guardia),
                onAlternar: () => _alternarActiva(guardia),
              );
            },
          ),
        ),
        // El pie sólo aparece cuando hay más de una página: con las guardias de
        // un lapso —unas decenas— unos botones muertos serían ruido.
        if (_hayAnterior || _haySiguiente) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _hayAnterior
                    ? () {
                        setState(() => _desplazamiento -= _limite);
                        _cargarPagina();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                label: const Text('Anteriores'),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: _haySiguiente
                    ? () {
                        setState(() => _desplazamiento += _limite);
                        _cargarPagina();
                      }
                    : null,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                label: const Text('Siguientes'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// El mensaje de una escritura fallida, con el choque de agenda dicho aparte.
///
/// El `409` del backend dice que el docente **o** el espacio ya están ocupados,
/// pero no dice cuál de los dos ni en qué hueco, y sin eso el administrador no
/// sabe qué mover. Se comprueba el **código** y no el tipo de error: `ApiClient`
/// clasifica todo `409` como `AppException.validacion`, así que el tipo no
/// distingue un choque de un dato mal formado.
String _mensajeDeChoque(AppException fallo) {
  if (esChoqueDeAgenda(fallo.code)) {
    return 'Ese docente o ese espacio ya están ocupados en ese bloque. Mueve '
        'la guardia a otro hueco, o libera el que ocupa.';
  }
  return fallo.message;
}

/// Un desplegable con etiqueta, controlado por [valor].
///
/// Se usa `DropdownButton` y no `DropdownButtonFormField` a propósito: el
/// segundo guarda su propio estado y no vuelve a leer `initialValue`, así que un
/// valor que cambia desde fuera —el lapso vigente, que sólo se conoce después de
/// la primera carga— se quedaría pintando la selección vieja.
class _Desplegable<T> extends StatelessWidget {
  const _Desplegable({
    required this.etiqueta,
    required this.valor,
    required this.opciones,
    required this.onCambiar,
    this.ancho = 200,
  });

  final String etiqueta;
  final T? valor;
  final List<DropdownMenuItem<T>> opciones;
  final ValueChanged<T?> onCambiar;
  final double ancho;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: ancho,
      child: InputDecorator(
        decoration: InputDecoration(isDense: true, labelText: etiqueta),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: valor,
            isExpanded: true,
            isDense: true,
            onChanged: onCambiar,
            items: opciones,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// Una fila del listado de guardias.
class _FilaGuardia extends StatelessWidget {
  const _FilaGuardia({
    required this.guardia,
    required this.docente,
    required this.aula,
    required this.guardando,
    required this.onEditar,
    required this.onAlternar,
  });

  final Guardia guardia;

  /// Nombre del docente ya resuelto, o `null` si su id no está en el catálogo.
  final String? docente;

  /// Nombre del espacio, o `null` si su id no está en el catálogo.
  final String? aula;

  final bool guardando;
  final VoidCallback onEditar;
  final VoidCallback onAlternar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final archivada = !guardia.activa;
    final notas = guardia.notas?.trim();
    final colorAula = PaletaAulasCuadrante.colorParaAula(guardia.aulaId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorAula
                    .withValues(alpha: archivada ? 0.05 : 0.16),
                borderRadius: BorderRadius.circular(IncesTheme.radioControl),
              ),
              child: Icon(
                Icons.shield_outlined,
                size: 19,
                color: archivada
                    ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                    : colorAula,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // Dos huecos distintos, dos mensajes distintos: «no está en
                    // el catálogo» y «está pero sin nombre» no son lo mismo.
                    docente ?? 'Docente no disponible',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: archivada
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // `Wrap` y no `Row`: el día, el bloque, el espacio y la
                  // insignia de archivada no caben en una línea en móvil.
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Etiqueta(
                        texto: '${_diaLegible()} · Bloque ${guardia.bloque}',
                      ),
                      Etiqueta(texto: guardia.turno.etiqueta),
                      if (horaLegibleDeBloque(guardia.bloque).isNotEmpty)
                        Etiqueta(
                          texto: horaLegibleDeBloque(guardia.bloque),
                        ),
                      Etiqueta(
                        texto: aula ?? 'Espacio no disponible',
                        color: colorAula,
                      ),
                      if (archivada) const Etiqueta(texto: 'Archivada'),
                    ],
                  ),
                  if (notas != null && notas.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      notas,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (guardando)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              IconButton(
                tooltip: 'Editar',
                onPressed: onEditar,
                icon: const Icon(Icons.edit_outlined, size: 18),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                tooltip: archivada ? 'Reactivar' : 'Archivar',
                onPressed: onAlternar,
                icon: Icon(
                  archivada ? Icons.restore_rounded : Icons.archive_outlined,
                  size: 18,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// El día en palabras. Un número fuera de rango se dice como es en vez de
  /// pintar un hueco: la base lo impide con `check (day_of_week between 1 and 6)`,
  /// así que verlo aquí significa que algo se desvió.
  String _diaLegible() => diaLegible(guardia.dia) ?? 'Día ${guardia.dia}';
}

/// Formulario de asignación y edición de una guardia.
///
/// Sirve para las dos cosas en vez de tener dos diálogos casi iguales: dos
/// copias del «mismo» formulario se desvían en cuanto alguien ajusta una.
class _DialogoGuardia extends StatefulWidget {
  const _DialogoGuardia({
    required this.repo,
    required this.periodo,
    required this.docentes,
    required this.aulas,
    this.existente,
    this.aulaIdInicial,
    this.diaInicial,
    this.bloqueInicial,
  });

  final CuadranteRepository repo;
  final String periodo;
  final List<DocenteResumen> docentes;
  final List<Aula> aulas;
  final Guardia? existente;
  final String? aulaIdInicial;
  final int? diaInicial;
  final int? bloqueInicial;

  @override
  State<_DialogoGuardia> createState() => _DialogoGuardiaState();
}

class _DialogoGuardiaState extends State<_DialogoGuardia> {
  late String? _docenteId = widget.existente?.docenteId;
  late String? _aulaId = widget.existente?.aulaId ?? widget.aulaIdInicial;
  late int _dia = widget.existente?.dia ?? widget.diaInicial ?? 1;
  late int _bloque = widget.existente?.bloque ?? widget.bloqueInicial ?? 1;

  late final TextEditingController _notasCtrl =
      TextEditingController(text: widget.existente?.notas ?? '');

  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.existente != null;

  List<DocenteResumen> get _docentesLimpios =>
      widget.docentes.where((d) => !d.esTestOSemilla).toList();

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _abrirInvitacionDocente() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invitar / Registrar nuevo docente'),
        content: const SizedBox(
          width: 520,
          height: 480,
          child: SingleChildScrollView(
            child: CpanelInvitacionesPanel(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirEditarBloqueActual() async {
    final horaActual = horaLegibleDeBloque(_bloque);
    final ctrl = TextEditingController(text: horaActual);
    final nuevoRango = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar horario Bloque $_bloque'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Turno: ${turnoDeBloque(_bloque).etiqueta}'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Franja horaria',
                hintText: 'ej. 07:30 - 08:15',
                prefixIcon: Icon(Icons.access_time),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (nuevoRango != null && nuevoRango.isNotEmpty) {
      actualizarHoraDeBloque(_bloque, nuevoRango);
      setState(() {});
    }
  }

  Widget _selectorDocente() {
    final docentes = _docentesLimpios;
    final docenteActual =
        docentes.where((d) => d.id == _docenteId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              'Docente custodio',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.person_add_alt, size: 15),
              label: const Text(
                '+ Invitar / Registrar docente',
                style: TextStyle(fontSize: 12),
              ),
              onPressed: _abrirInvitacionDocente,
            ),
          ],
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
            if (textEditingValue.text.isEmpty) {
              return docentes;
            }
            final q = textEditingValue.text.toLowerCase();
            return docentes.where((d) {
              final nom = d.nombre.toLowerCase();
              final em = d.email?.toLowerCase() ?? '';
              return nom.contains(q) || em.contains(q);
            });
          },
          onSelected: (DocenteResumen d) {
            setState(() => _docenteId = d.id);
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxHeight: 260, maxWidth: 440),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final option = options.elementAt(index);
                        final seleccionado = option.id == _docenteId;
                        return ListTile(
                          dense: true,
                          selected: seleccionado,
                          leading: CircleAvatar(
                            radius: 14,
                            child: Text(
                              (option.nombre.isNotEmpty
                                      ? option.nombre[0]
                                      : 'D')
                                  .toUpperCase(),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          title: Text(
                            nombreDeDocente(option.nombre),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: option.email != null &&
                                  option.email!.isNotEmpty
                              ? Text(option.email!,
                                  style: const TextStyle(fontSize: 11))
                              : null,
                          trailing: seleccionado
                              ? const Icon(Icons.check, size: 16)
                              : null,
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
          fieldViewBuilder:
              (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Buscar facilitador por nombre o correo...',
                prefixIcon: const Icon(Icons.search, size: 20),
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
    );
  }

  Future<void> _guardar() async {
    if (_guardando) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final resultado = _esEdicion ? await _guardarCambios() : await _crear();

    if (!mounted) return;
    setState(() => _guardando = false);

    resultado.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (fallo) => setState(() => _error = _mensajeDeChoque(fallo)),
    );
  }

  Future<Result<Guardia>> _crear() => widget.repo.crearGuardia(
        EntradaCrearGuardia(
          docenteId: _docenteId ?? '',
          aulaId: _aulaId ?? '',
          periodo: widget.periodo,
          dia: _dia,
          bloque: _bloque,
          notas: _notasCtrl.text,
        ),
      );

  Future<Result<Guardia>> _guardarCambios() {
    final antes = widget.existente!;
    final notas = _notasCtrl.text.trim();
    final teniaNotas = antes.notas?.trim().isNotEmpty ?? false;

    return widget.repo.actualizarGuardia(
      antes.id,
      CambiosGuardia(
        docenteId: _docenteId != antes.docenteId ? _docenteId : null,
        aulaId: _aulaId != antes.aulaId ? _aulaId : null,
        dia: _dia != antes.dia ? _dia : null,
        bloque: _bloque != antes.bloque ? _bloque : null,
        notas: notas.isNotEmpty ? notas : null,
        borrarNotas: notas.isEmpty && teniaNotas,
      ),
    );
  }

  DropdownMenuItem<String?> _itemAusente(String valor, String etiqueta) =>
      DropdownMenuItem(
        value: valor,
        child: Text('$etiqueta (no disponible)'),
      );

  List<DropdownMenuItem<String?>> _opcionesDeAula() {
    final actual = _aulaId;
    final falta = actual != null && !widget.aulas.any((a) => a.id == actual);

    return [
      const DropdownMenuItem(value: null, child: Text('Elige un espacio')),
      for (final aula in widget.aulas)
        DropdownMenuItem(
          value: aula.id,
          child: Text(
            aula.activa ? aula.nombre : '${aula.nombre} · archivado',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      if (falta) _itemAusente(actual, 'Espacio'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(_esEdicion ? 'Editar guardia' : 'Asignar guardia'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lapso ${widget.periodo}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              _selectorDocente(),
              const SizedBox(height: 14),
              _Desplegable<String?>(
                etiqueta: 'Espacio',
                ancho: double.infinity,
                valor: _aulaId,
                opciones: _opcionesDeAula(),
                onCambiar: (valor) => setState(() => _aulaId = valor),
              ),
              const SizedBox(height: 14),
              Builder(
                builder: (context) {
                  final apilar = MediaQuery.sizeOf(context).width < 500;
                  final campoDia = _Desplegable<int>(
                    etiqueta: 'Día',
                    ancho: double.infinity,
                    valor: _dia,
                    opciones: [
                      for (var dia = 1; dia <= diaMaximo; dia++)
                        DropdownMenuItem(
                          value: dia,
                          child: Text(diasDeLaSemana[dia]),
                        ),
                    ],
                    onCambiar: (valor) {
                      if (valor != null) setState(() => _dia = valor);
                    },
                  );

                  final campoBloque = _Desplegable<int>(
                    etiqueta: 'Bloque y Turno',
                    ancho: double.infinity,
                    valor: _bloque,
                    opciones: [
                      for (var bloque = 1; bloque <= bloqueMaximo; bloque++)
                        DropdownMenuItem(
                          value: bloque,
                          child: Text(
                            bloqueLegibleConTurno(bloque),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onCambiar: (valor) {
                      if (valor != null) setState(() => _bloque = valor);
                    },
                  );

                  final botonEditarHora = IconButton(
                    tooltip: 'Personalizar hora de este bloque',
                    icon: const Icon(Icons.edit_calendar_outlined, size: 20),
                    onPressed: _abrirEditarBloqueActual,
                  );

                  if (apilar) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        campoDia,
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: campoBloque),
                            const SizedBox(width: 4),
                            botonEditarHora,
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(flex: 4, child: campoDia),
                      const SizedBox(width: 8),
                      Expanded(flex: 6, child: campoBloque),
                      botonEditarHora,
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Bloque $_bloque · turno de ${turnoDeBloque(_bloque).etiqueta.toLowerCase()} '
                '(lo determina el bloque, no se elige).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _notasCtrl,
                maxLines: 3,
                maxLength: CuadranteRepository.largoMaximoNotas,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  hintText: 'Apertura del taller, custodia del pasillo…',
                  helperText: 'Opcional. Déjalo vacío para no dejar ninguna.',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
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
}
