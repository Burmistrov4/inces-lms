import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';
import '../../core/gateways/cuadrante_gateway.dart';
import '../../core/reglas_cuadrante.dart';
import '../../models/cuadrante.dart';
import '../../repositories/cuadrante_repository.dart';
import '../../widgets/comunes.dart';
import '../../widgets/cuadrante_grid.dart';
import '../../widgets/guia_contextual_modulo.dart';
import 'cpanel_invitaciones_panel.dart';

/// Rejilla maestra del cuadrante (Módulo 3).
///
/// Es el corazón del módulo: una matriz de **días × bloques** donde cada celda
/// muestra las clases y guardias de ese hueco. Las aulas no son una dimensión
/// propia de la rejilla —una clase ya sabe en qué aula está—, así que cada chip
/// lleva su aula como etiqueta en vez de pedir una tercera columna que no
/// cabría.
///
/// El lapso se elige en la cabecera. Por defecto es el **vigente**, porque el
/// cuadrante «del centro» es el vigente; si no lo hay, se ofrece el primero y se
/// avisa. Sin aulas no se puede armar —una clase sin aula no existe—, y sin
/// lapsos tampoco.
///
/// ## La creación de una clase y por qué necesita una sección
///
/// `crearClase` exige `seccionId`: la clase cuelga de una sección, y de ella se
/// deriva el período. Este panel no trae el catálogo de secciones —eso es el
/// módulo Currículo—, así que las secciones disponibles para crear son las que ya
/// tienen clases **en este lapso**. No es un capricho: evita prometer una clase
/// en una sección que la base no conoce. Cuando el currículo aporte su listado,
/// bastará con enchufarlo aquí.
class CpanelCuadrantePanel extends StatefulWidget {
  const CpanelCuadrantePanel({
    super.key,
    this.repositorio,
    this.onNavegarA,
  });

  final CuadranteRepository? repositorio;
  final void Function(String)? onNavegarA;

  @override
  State<CpanelCuadrantePanel> createState() => _CpanelCuadrantePanelState();
}

class _CpanelCuadrantePanelState extends State<CpanelCuadrantePanel> {
  late final CuadranteRepository _repo =
      widget.repositorio ?? CuadranteRepository();

  List<Periodo> _periodos = const [];
  String? _lapso;
  bool _hayVigente = false;

  List<ClaseCuadrante> _clases = const [];
  List<Guardia> _guardias = const [];
  List<Aula> _aulas = const [];
  List<DocenteResumen> _docentes = const [];

  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarPeriodos();
  }

  /// Carga primero el catálogo de lapsos para fijar el vigente por defecto; la
  /// rejilla necesita saber qué lapso pintar antes de pedirla.
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
    if (!mounted) return;

    resultado.when(
      success: (rejilla) => setState(() {
        _cargando = false;
        _clases = rejilla.clases;
        _guardias = rejilla.guardias;
        _aulas = rejilla.aulas;
        _docentes = rejilla.docentes;
      }),
      failure: (fallo) => setState(() {
        _cargando = false;
        _error = fallo.message;
      }),
    );
  }

  /// Las secciones disponibles para crear, sacadas de las clases ya existentes en
  /// este lapso. Ver el comentario de la clase sobre por qué no hay catálogo.
  Map<String, String> get _seccionesDisponibles {
    final mapa = <String, String>{};
    for (final clase in _clases) {
      if (clase.seccionId.isNotEmpty && !mapa.containsKey(clase.seccionId)) {
        mapa[clase.seccionId] = clase.seccion.isNotEmpty
            ? '${clase.programa} · ${clase.seccion}'
            : clase.seccionId;
      }
    }
    return mapa;
  }

  String? _razonParaNoAsignar() {
    if (_lapso == null) return 'Elige un lapso antes de asignar una clase.';
    if (_aulas.isEmpty) return 'Registra los espacios del centro primero.';
    if (_docentes.isEmpty) {
      return 'No hay docentes activos a los que asignar la clase.';
    }
    if (_seccionesDisponibles.isEmpty) {
      return 'Crea primero una clase desde el currículo: la sección se necesita '
          'para ubicar ésta.';
    }
    return null;
  }

  Future<void> _abrirCreacion({int? diaInicial, int? bloqueInicial}) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoClase(
        repo: _repo,
        aulas: _aulas,
        docentes: _docentes,
        secciones: _seccionesDisponibles,
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
      builder: (_) => _DialogoClase(
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

  Future<void> _abrirEditorDeBloques() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _DialogoEditarHorasBloques(
        onGuardado: () => setState(() {}),
      ),
    );
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
          claveStorage: 'cuadrante_horarios_cpanel',
          icono: Icons.calendar_month_outlined,
          titulo: '¿Cómo asignar clases y gestionar los horarios?',
          subtitulo: 'Esta matriz representa la semana formativa del CFS Rafael Urdaneta. '
              'Las columnas son los días (Lunes a Sábado) y las filas son los bloques de mañana y tarde.',
          pasos: [
            PasoGuiaContextual(
              numero: 1,
              titulo: 'Asignar clase en celda libre',
              descripcion: 'Toca cualquier celda con el icono (+) o pulsa «Asignar clase» arriba a la derecha.',
            ),
            PasoGuiaContextual(
              numero: 2,
              titulo: 'Elegir sección, aula y facilitador',
              descripcion: 'Selecciona la sección del curso, el aula o taller asignado y el facilitador responsable.',
            ),
            PasoGuiaContextual(
              numero: 3,
              titulo: 'Diferenciación de turnos',
              descripcion: 'Los bloques 1 a 6 corresponden a la mañana (azul) y 7 a 12 a la tarde (ámbar).',
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
      label: const Text('Asignar clase'),
    );

    return TituloSeccion(
      'Horarios de Clases',
      subtitulo: 'Planificación y distribución semanal de clases por día y bloque. '
          'Toca una clase para editarla o pulsa en cualquier bloque libre para asignar una nueva.',
      acciones: [
        if (_periodos.isNotEmpty) _selectorDeLapso(),
        const SizedBox(width: 8),
        if (widget.onNavegarA != null) ...[
          OutlinedButton.icon(
            onPressed: () => widget.onNavegarA?.call('Espacios y Aulas'),
            icon: const Icon(Icons.meeting_room_outlined, size: 16),
            label: const Text('Aulas'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => widget.onNavegarA?.call('Guardias Docentes'),
            icon: const Icon(Icons.shield_outlined, size: 16),
            label: const Text('Guardias'),
          ),
          const SizedBox(width: 8),
        ],
        OutlinedButton.icon(
          onPressed: _abrirEditorDeBloques,
          icon: const Icon(Icons.schedule_outlined, size: 18),
          label: const Text('Horas de bloques'),
        ),
        const SizedBox(width: 8),
        if (razon == null)
          boton
        else
          Tooltip(message: razon, child: boton),
      ],
    );
  }

  Widget _selectorDeLapso() {
    return SizedBox(
      width: 200,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Lapso',
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
        texto: 'Ningún lapso está marcado como vigente. Se muestra '
            '«$_lapso»; márcalo vigente en «Lapsos académicos» para fijar el '
            'cuadrante del centro.',
        icono: Icons.flag_outlined,
        tono: TonoAviso.advertencia,
      ),
    );
  }

  Widget _cuerpo() {
    if (_periodos.isEmpty) {
      return const PanelVacio(
        titulo: 'Todavía no hay lapsos registrados',
        mensaje: 'El cuadrante se organiza por lapso. Registra uno en '
            '«Lapsos académicos» y vuelve: la rejilla se armará con sus clases '
            'y guardias.',
        icono: Icons.calendar_month_outlined,
        nota: 'El sistema no trae lapsos de ejemplo a propósito.',
      );
    }

    if (_aulas.isEmpty) {
      return const PanelVacio(
        titulo: 'No hay espacios registrados',
        mensaje: 'Una clase necesita un aula, un taller o una zona donde '
            'dictarse. Hasta que registres los espacios del centro, el '
            'cuadrante no se puede armar.',
        icono: Icons.meeting_room_outlined,
        nota: 'Regístralos en «Espacios del centro». El catálogo se carga aquí '
            'automáticamente.',
      );
    }

    if (_clases.isEmpty && _guardias.isEmpty) {
      return PanelVacio(
        titulo: 'Este lapso aún no tiene clases ni guardias',
        mensaje: 'La rejilla está lista. Asigna la primera clase y aparecerá en '
            'su día y bloque.',
        icono: Icons.grid_view_outlined,
        nota: _razonParaNoAsignar(),
      );
    }

    return _rejilla();
  }

  Widget _rejilla() {
    final theme = Theme.of(context);

    final celdas = <String, List<Widget>>{};
    for (final entrada in agruparClases(_clases, chip: _chipClase).entries) {
      celdas[entrada.key] = entrada.value;
    }
    for (final entrada in agruparGuardias(_guardias, chip: _chipGuardia).entries) {
      celdas.putIfAbsent(entrada.key, () => []).addAll(entrada.value);
    }

    // Orden estable: clases primero, guardias debajo, dentro de cada celda.
    for (final lista in celdas.values) {
      lista.sort((a, b) => a.runtimeType.toString().compareTo(
            b.runtimeType.toString(),
          ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Leyenda(
                color: theme.colorScheme.primary,
                relleno: true,
                texto: 'Clases (color por aula asignada)',
              ),
              const _Leyenda(
                color: PaletaAulasCuadrante.colorGuardia,
                relleno: false,
                texto: 'Guardias (sólo lectura aquí)',
              ),
            ],
          ),
        ),
        Expanded(
          child: CuadranteGrid(
            celdas: celdas,
            onCeldaTap: _razonParaNoAsignar() == null
                ? (dia, bloque) =>
                    _abrirCreacion(diaInicial: dia, bloqueInicial: bloque)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _chipClase(ClaseCuadrante clase) {
    final docente = nombreDeDocente(clase.docente);
    final colorAula = PaletaAulasCuadrante.colorParaAula(clase.aulaId);
    return ChipCuadrante(
      titulo: clase.materia.isNotEmpty ? clase.materia : 'Clase',
      subtitulo: '${clase.aula} · $docente',
      color: colorAula,
      etiquetaAula: clase.aula,
      destacado: true,
      onTap: () => _abrirEdicion(clase),
    );
  }

  Widget _chipGuardia(Guardia guardia) {
    final aula = _aulas.where((a) => a.id == guardia.aulaId).firstOrNull;
    final colorAula = PaletaAulasCuadrante.colorParaAula(guardia.aulaId);
    return ChipCuadrante(
      titulo: 'Guardia',
      subtitulo: aula?.nombre ?? 'Espacio no disponible',
      color: colorAula,
      etiquetaAula: aula?.nombre,
      esGuardia: true,
      onTap: null,
    );
  }
}

/// Leyenda de la rejilla.
class _Leyenda extends StatelessWidget {
  const _Leyenda({
    required this.color,
    required this.texto,
    this.relleno = true,
  });

  final Color color;
  final String texto;
  final bool relleno;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: relleno ? color.withValues(alpha: 0.5) : null,
            border: Border.all(
              color: color.withValues(alpha: 0.6),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Diálogo de alta y edición de una clase del cuadrante.
///
/// `clase` en `null` ⇒ creación; si no, edición. En edición la sección no se
/// toca (es la identidad de la clase); sólo se mueve de aula/bloque/día, se
/// cambia el docente o se archiva. En creación sí se elige la sección, porque es
/// lo que falta para ubicar la clase.
class _DialogoClase extends StatefulWidget {
  const _DialogoClase({
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
  State<_DialogoClase> createState() => _DialogoClaseState();
}

class _DialogoClaseState extends State<_DialogoClase> {
  late String? _seccionId = widget.clase?.seccionId;
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

    if (!_esEdicion && _seccionId == null) {
      setState(() => _error = 'Elige la sección a la que pertenece la clase.');
      return;
    }
    if (_aulaId == null) {
      setState(() => _error = 'Elige el espacio donde se dicta.');
      return;
    }
    if (_docenteId == null) {
      setState(() => _error = 'Elige el docente que la imparte.');
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
              docenteId: _docenteId!,
              aulaId: _aulaId!,
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
      return 'Ese docente o ese espacio ya están ocupados en ese bloque. Mueve '
          'la clase a otro hueco, o libera el que ocupa.';
    }
    return fallo.message;
  }

  List<DocenteResumen> get _docentesLimpios =>
      widget.docentes.where((d) => !d.esTestOSemilla).toList();

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
              'Docente / Facilitador',
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_esEdicion ? 'Editar clase' : 'Asignar clase'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_esEdicion)
                _Desplegable<String>(
                  etiqueta: 'Sección',
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
              if (!_esEdicion) const SizedBox(height: 12),
              _Desplegable<String>(
                etiqueta: 'Espacio',
                ancho: double.infinity,
                valor: _aulaId,
                opciones: [
                  for (final aula in widget.aulas)
                    DropdownMenuItem(
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
              _selectorDocente(),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 4,
                    child: _Desplegable<int>(
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
                    flex: 6,
                    child: _Desplegable<int>(
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
                  IconButton(
                    tooltip: 'Personalizar hora de este bloque',
                    icon: const Icon(Icons.edit_calendar_outlined, size: 20),
                    onPressed: _abrirEditarBloqueActual,
                  ),
                ],
              ),
              if (_esEdicion) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _activa,
                  onChanged: (v) => setState(() => _activa = v),
                  title: const Text('Clase activa'),
                  subtitle: Text(
                    _activa
                        ? 'Aparece en el cuadrante.'
                        : 'Archivada: no se muestra, pero no se borra.',
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
}

/// Diálogo para configurar y editar las horas de los 12 bloques académicos.
class _DialogoEditarHorasBloques extends StatefulWidget {
  const _DialogoEditarHorasBloques({required this.onGuardado});
  final VoidCallback onGuardado;

  @override
  State<_DialogoEditarHorasBloques> createState() =>
      _DialogoEditarHorasBloquesState();
}

class _DialogoEditarHorasBloquesState extends State<_DialogoEditarHorasBloques> {
  late final Map<int, TextEditingController> _controllers = {
    for (var b = 1; b <= 12; b++)
      b: TextEditingController(text: horaLegibleDeBloque(b)),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _guardar() {
    for (var b = 1; b <= 12; b++) {
      final t = _controllers[b]?.text.trim() ?? '';
      if (t.isNotEmpty) {
        actualizarHoraDeBloque(b, t);
      }
    }
    widget.onGuardado();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configurar Horarios de Bloques'),
      content: SizedBox(
        width: 480,
        height: 480,
        child: ListView(
          children: [
            const Text(
              'Personaliza las franjas horarias de inicio y fin para los 12 bloques académicos (CFS Rafael Urdaneta).',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text(
              'Turno Mañana (Bloques 1 al 6)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            for (var b = 1; b <= 6; b++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _controllers[b],
                  decoration: InputDecoration(
                    labelText: 'Bloque $b (Mañana)',
                    isDense: true,
                    prefixIcon: const Icon(Icons.access_time, size: 18),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'Turno Tarde (Bloques 7 al 12)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            for (var b = 7; b <= 12; b++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _controllers[b],
                  decoration: InputDecoration(
                    labelText: 'Bloque $b (Tarde)',
                    isDense: true,
                    prefixIcon: const Icon(Icons.access_time, size: 18),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardar,
          child: const Text('Guardar horarios'),
        ),
      ],
    );
  }
}

/// Desplegable con etiqueta, que sí relee el valor desde fuera (a diferencia de
/// `DropdownButtonFormField`, que guarda su propio estado y no reacciona cuando
/// el valor cambia por otro lado).
class _Desplegable<T> extends StatelessWidget {
  const _Desplegable({
    required this.etiqueta,
    required this.valor,
    required this.opciones,
    required this.onChanged,
    this.ancho,
  });

  final String etiqueta;
  final T? valor;
  final List<DropdownMenuItem<T>> opciones;
  final ValueChanged<T?> onChanged;
  final double? ancho;

  @override
  Widget build(BuildContext context) {
    final child = InputDecorator(
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
    );
    return ancho == null ? child : SizedBox(width: ancho, child: child);
  }
}
