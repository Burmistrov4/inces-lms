import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';
import '../../core/gateways/cuadrante_gateway.dart';
import '../../core/reglas_cuadrante.dart';
import '../../models/cuadrante.dart';
import '../../models/seccion.dart';
import '../../repositories/cuadrante_repository.dart';
import '../../repositories/curriculo_repository.dart';
import '../../repositories/secciones_repository.dart';
import '../../widgets/comunes.dart';
import '../../widgets/cuadrante_grid.dart';
import '../../widgets/guia_contextual_modulo.dart';
import '../../widgets/responsivo.dart';
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
  late final SeccionesRepository _seccionesRepo = SeccionesRepository();
  late final CurriculoRepository _curriculoRepo = CurriculoRepository();

  List<Periodo> _periodos = const [];
  String? _lapso;

  /// **Filtro de dia de la rejilla.** null = semana completa.
  int? _diaFiltro;
  bool _hayVigente = false;

  List<ClaseCuadrante> _clases = const [];
  List<Guardia> _guardias = const [];
  List<Aula> _aulas = const [];
  List<DocenteResumen> _docentes = const [];
  Map<String, String> _seccionesCatalogo = const {};

  bool _cargando = true;
  String? _error;
  final ScrollController _scrollHorizontalCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _cargarPeriodos();
  }

  @override
  void dispose() {
    _scrollHorizontalCtrl.dispose();
    super.dispose();
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
    await _cargarSeccionesCatalogo();
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

  /// Carga todas las secciones activas y resuelve los nombres de sus cursos y materias.
  Future<void> _cargarSeccionesCatalogo() async {
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

      final resSec = await _seccionesRepo.listarTodasLasSecciones(soloActivas: true);
      if (resSec.isSuccess) {
        final mapa = <String, String>{};
        for (final s in resSec.valueOrNull!) {
          if (_lapso != null && s.periodo != _lapso) continue;
          final progNombre = progMap[s.programaId] ?? s.programaId;
          final matNombre = matMap[s.materiaId];
          final esPna = esProgramaPNA(progNombre) ||
              s.programaId.toLowerCase().contains('cur-int-01') ||
              s.programaId.toLowerCase().contains('pna') ||
              (matNombre != null && esProgramaPNA(matNombre));
          if (esPna) continue;
          final etiqueta = matNombre != null && matNombre.isNotEmpty
              ? '$progNombre · Secc. ${s.nombre} ($matNombre)'
              : '$progNombre · Secc. ${s.nombre}';
          mapa[s.id] = etiqueta;
        }
        _seccionesCatalogo = mapa;
      }
    } catch (_) {}
  }

  /// Secciones disponibles para asignar: combina el catálogo general de secciones
  /// activas de la base de datos con las que ya tienen clases en el período.
  Map<String, String> get _seccionesDisponibles {
    final mapa = <String, String>{..._seccionesCatalogo};
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
    if (_lapso == null) return 'Elige un período antes de asignar una clase.';
    if (_aulas.isEmpty) return 'Registra los espacios del centro primero.';
    if (_docentes.isEmpty) {
      return 'No hay docentes activos a los que asignar la clase.';
    }
    if (_seccionesDisponibles.isEmpty) {
      // **Sin nombrar un apartado.** Medido el 2026-10-29: decía «Crea primero
      // una sección en “Secciones del Período”», pero ese apartado ya no existe
      // en el menú desde D11 y su panel quedó sin punto de entrada. Mandar al
      // usuario a un sitio que no está es peor que no mandarlo a ninguno.
      return 'Crea primero una sección para poder asignarle un horario.';
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
        // El diálogo puede crear el grupo que falta (curso + materia) sin
        // sacar al administrador de esta pantalla.
        seccionesRepo: _seccionesRepo,
        curriculoRepo: _curriculoRepo,
        diaInicial: diaInicial,
        bloqueInicial: bloqueInicial,
      ),
    );
    if (guardado != true || !mounted) return;
    await _cargarRejilla();
    // Si se creó un grupo dentro del diálogo, el catálogo tiene que verlo.
    await _cargarSeccionesCatalogo();
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
      builder: (ctx) => DialogoEditarHorasBloques(
        onGuardado: () => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final razon = _razonParaNoAsignar();

    return LayoutBuilder(
      builder: (context, restricciones) {
        // **Un solo scroll en el móvil.** Medido en Redmi 10C el 2026-10-30: la
        // cabecera (título, selector de período, cuatro botones, guía y fichas
        // de día) llenaba la pantalla y, con el panel rígido, la rejilla recibía
        // altura cero — «no puedes deslizar ni para arriba ni para abajo».
        // Guardias Docentes ya resolvía esto así y es el único panel que el
        // usuario describe como utilizable en el teléfono; se copia el patrón,
        // no se inventa otro.
        final compacto =
            restricciones.maxWidth < 600 || restricciones.maxHeight < 700;

        final cuerpo = EstadoPanel(
          cargando: _cargando,
          error: _error,
          onReintentar: _cargarPeriodos,
          child: _cuerpo(compacto: compacto),
        );

        final contenido = Column(
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
        if (compacto) cuerpo else Expanded(child: cuerpo),
      ],
        );

        return compacto
            ? SingleChildScrollView(child: contenido)
            : contenido;
      },
    );
  }

  Widget _cabecera(String? razon) {
    final boton = FilledButton.icon(
      onPressed: razon == null ? _abrirCreacion : null,
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('Asignar clase'),
    );

    return TituloSeccion(
      // **Un solo nombre.** El menú dice «Cuadrante de Horarios» y el panel
      // decía «Horario Ordinario»: dos etiquetas para la misma pantalla, y el
      // usuario tuvo que preguntar cuál era. Se queda la del menú, que es la que
      // el personal ve y busca; cuando se decida un nombre más llano («Horario
      // de Clases»), se cambia en los dos sitios a la vez y no en uno.
      'Cuadrante de Horarios',
      subtitulo: 'Planificación semanal de cursos regulares (sección obligatoria; materia y espacio opcionales). '
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
            onPressed: () => widget.onNavegarA?.call('Guardias Docentes (MTP)'),
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
            '«$_lapso»; márcalo vigente en «Período» para fijar el '
            'cuadrante del centro.',
        icono: Icons.flag_outlined,
        tono: TonoAviso.advertencia,
      ),
    );
  }

  Widget _cuerpo({bool compacto = false}) {
    if (_periodos.isEmpty) {
      return const PanelVacio(
        titulo: 'Todavía no hay períodos registrados',
        mensaje: 'El cuadrante se organiza por período. Registra uno en '
            '«Período» y vuelve: la rejilla se armará con sus clases '
            'y guardias.',
        icono: Icons.calendar_month_outlined,
        nota: 'El sistema no trae períodos de ejemplo a propósito.',
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
        titulo: 'Este período aún no tiene clases ni guardias',
        mensaje: 'La rejilla está lista. Asigna la primera clase y aparecerá en '
            'su día y bloque.',
        icono: Icons.grid_view_outlined,
        nota: _razonParaNoAsignar(),
      );
    }

    return _rejilla(compacto: compacto);
  }

  Widget _rejilla({bool compacto = false}) {
    final theme = Theme.of(context);

    final clasesOrdinarias = _clases
        .where((c) => !esProgramaPNA(c.programa) && !esProgramaPNA(c.materia))
        .toList();
    final celdas = <String, List<Widget>>{};
    for (final entrada in agruparClases(clasesOrdinarias, chip: _chipClase).entries) {
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

    // Dias que tienen algo, para el punto del selector.
    final diasConContenido = <int>{};
    for (final entrada in celdas.entries) {
      final dia = int.tryParse(entrada.key.split('-').first);
      if (dia != null && entrada.value.isNotEmpty) diasConContenido.add(dia);
    }

    return LayoutBuilder(
      builder: (context, restricciones) {
        // Los botones «Anterior/Siguiente» desplazan la TABLA en horizontal.
        // Cuando la rejilla se pinta como lista por día —pantalla estrecha— no
        // hay nada que desplazar: quedarían dos botones que no hacen nada.
        final hayTabla = CuadranteGrid.cabeComoTabla(restricciones.maxWidth, diaMaximo);
        return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SelectorDeDias(
              seleccionado: _diaFiltro,
              onCambio: (dia) => setState(() => _diaFiltro = dia),
              diasConContenido: diasConContenido,
            ),
            if (_diaFiltro == null && hayTabla)
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onPressed: () {
                      if (_scrollHorizontalCtrl.hasClients) {
                        _scrollHorizontalCtrl.animateTo(
                          (_scrollHorizontalCtrl.offset - 250).clamp(0, _scrollHorizontalCtrl.position.maxScrollExtent),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                    icon: const Icon(Icons.chevron_left, size: 18),
                    label: const Text('Anterior'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onPressed: () {
                      if (_scrollHorizontalCtrl.hasClients) {
                        _scrollHorizontalCtrl.animateTo(
                          (_scrollHorizontalCtrl.offset + 250).clamp(0, _scrollHorizontalCtrl.position.maxScrollExtent),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                    icon: const Text('Siguiente'),
                    label: const Icon(Icons.chevron_right, size: 18),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 10),
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
        if (compacto)
          CuadranteGrid(
            celdas: celdas,
            diaFiltro: _diaFiltro,
            mostrarSelectorDias: false,
            compacto: true,
            onCeldaTap: _razonParaNoAsignar() == null
                ? (dia, bloque) =>
                    _abrirCreacion(diaInicial: dia, bloqueInicial: bloque)
                : null,
          )
        else
          Expanded(
            child: CuadranteGrid(
              celdas: celdas,
              diaFiltro: _diaFiltro,
              mostrarSelectorDias: false,
              horizontalController: _scrollHorizontalCtrl,
              onCeldaTap: _razonParaNoAsignar() == null
                  ? (dia, bloque) =>
                      _abrirCreacion(diaInicial: dia, bloqueInicial: bloque)
                  : null,
            ),
          ),
      ],
        );
      },
    );
  }

  Widget _chipClase(ClaseCuadrante clase) {
    final docente = nombreDeDocente(clase.docente);
    final colorAula = PaletaAulasCuadrante.colorParaAula(clase.aulaId);
    final nombreCurso = clase.programa.isNotEmpty
        ? clase.programa
        : (clase.seccion.isNotEmpty ? clase.seccion : 'Curso');
    final titulo = clase.materia.isNotEmpty ? clase.materia : nombreCurso;
    final subtitulo = clase.aula.isNotEmpty
        ? (clase.materia.isNotEmpty ? '${clase.aula} · $docente' : '$docente · ${clase.aula}')
        : docente;
    return ChipCuadrante(
      titulo: titulo,
      subtitulo: subtitulo,
      color: colorAula,
      etiquetaAula: clase.aula.isNotEmpty ? clase.aula : null,
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
        // Flexible: el texto de la leyenda desbordaba 43 px a 360 — un Row de
        // ancho mínimo dentro de un Wrap no parte la línea si su hijo es
        // inflexible.
        Flexible(
          child: Text(
            texto,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
    this.seccionesRepo,
    this.curriculoRepo,
    this.diaInicial,
    this.bloqueInicial,
  });

  final CuadranteRepository repo;
  final ClaseCuadrante? clase;
  final List<Aula> aulas;
  final List<DocenteResumen> docentes;
  final Map<String, String> secciones;
  final String periodo;
  final SeccionesRepository? seccionesRepo;
  final CurriculoRepository? curriculoRepo;
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

  /// Copia local del catálogo: si el diálogo crea un grupo, tiene que aparecer
  /// en el desplegable **sin cerrar y volver a abrir**. La lista del padre es
  /// inmutable desde aquí, y recargarla obligaría a perder lo ya elegido.
  late final Map<String, String> _secciones = Map.of(widget.secciones);

  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.clase != null;

  Future<void> _guardar() async {
    if (_guardando) return;

    if (!_esEdicion && _seccionId == null) {
      setState(() => _error = 'Elige el curso y la materia de la clase.');
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
      return 'Ese docente o ese espacio ya están ocupados en ese bloque. Mueve '
          'la clase a otro hueco, o libera el que ocupa.';
    }
    return fallo.message;
  }

  /// Abre el creador de grupos y, si crea uno, lo deja **elegido** en el
  /// desplegable sin cerrar este diálogo ni perder lo que ya estaba puesto.
  Future<void> _crearGrupo() async {
    final creado = await showDialog<_GrupoCreado>(
      context: context,
      builder: (_) => _DialogoNuevoGrupo(
        periodo: widget.periodo,
        seccionesRepo: widget.seccionesRepo,
        curriculoRepo: widget.curriculoRepo,
      ),
    );

    if (creado == null || !mounted) return;

    setState(() {
      _secciones[creado.id] = creado.etiqueta;
      _seccionId = creado.id;
      _error = null;
    });
  }

  List<DocenteResumen> get _docentesLimpios =>
      widget.docentes.where((d) => !d.esTestOSemilla).toList();

  Future<void> _abrirInvitacionDocente() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invitar / Registrar nuevo docente'),
        content: SizedBox(
          width: anchoDialogoSeguro(context, 520),
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
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_esEdicion) ...[
                _Desplegable<String>(
                  etiqueta: 'Curso · materia (grupo)',
                  ancho: double.infinity,
                  valor: _seccionId,
                  opciones: [
                    for (final entrada in _secciones.entries)
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
                // **La puerta que faltaba.** Antes había que salir a otro
                // módulo a crear la «sección» y volver; el panel nunca decía
                // dónde. Ahora el grupo se crea aquí mismo eligiendo curso y
                // materia.
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _guardando ? null : _crearGrupo,
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text('Falta el curso o la materia: crearlo aquí'),
                  ),
                ),
              ],
              if (!_esEdicion) const SizedBox(height: 12),
              _Desplegable<String?>(
                etiqueta: 'Espacio (opcional)',
                ancho: double.infinity,
                valor: _aulaId,
                opciones: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sin espacio asignado (opcional)', style: TextStyle(fontStyle: FontStyle.italic)),
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
              _selectorDocente(),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  // El umbral canónico vive en `responsivo.dart` (Material 3): apilar es
                  // cosa de la ventana `compact`, < 600. El 500 de antes era un
                  // umbral propio que se desviaba del contrato sin que nada lo
                  // supiera.
                  final apilar = esCompacto(context);
                  final campoDia = _Desplegable<int>(
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
                  );

                  final campoBloque = _Desplegable<int>(
                    etiqueta: 'Bloque y Turno',
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
class DialogoEditarHorasBloques extends StatefulWidget {
  const DialogoEditarHorasBloques({super.key, required this.onGuardado});
  final VoidCallback onGuardado;

  @override
  State<DialogoEditarHorasBloques> createState() =>
      _DialogoEditarHorasBloquesState();
}

class _DialogoEditarHorasBloquesState extends State<DialogoEditarHorasBloques> {
  late final Map<int, TextEditingController> _controllers = {
    for (var b = 1; b <= 12; b++)
      b: TextEditingController(text: horaLegibleDeBloque(b)),
  };
  bool _cascadaAutomatica = true;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _ajustarEnCascada(int bloqueModificado) {
    if (!_cascadaAutomatica) return;
    final texto = _controllers[bloqueModificado]?.text.trim() ?? '';
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})$').firstMatch(texto);
    if (match == null) return;

    final h1 = int.parse(match.group(1)!);
    final m1 = int.parse(match.group(2)!);
    var h2 = int.parse(match.group(3)!);
    final m2 = int.parse(match.group(4)!);

    final esTarde = bloqueModificado >= 7;
    final es12h = (h1 < 12 && esTarde) || (h1 <= 12 && h2 < h1);

    var startMin = h1 * 60 + m1;
    var endMin = h2 * 60 + m2;
    if (endMin <= startMin && es12h) {
      endMin += 12 * 60;
    }
    final duracion = endMin - startMin;
    if (duracion <= 0 || duracion > 240) return;

    final maxBloqueTurno = bloqueModificado <= 6 ? 6 : 12;
    var prevEnd = endMin;

    for (var b = bloqueModificado + 1; b <= maxBloqueTurno; b++) {
      final nextStart = prevEnd;
      final nextEnd = nextStart + duracion;

      final startStr = _minutosAString(nextStart, es12h: es12h);
      final endStr = _minutosAString(nextEnd, es12h: es12h);

      _controllers[b]?.text = '$startStr - $endStr';
      prevEnd = nextEnd;
    }
  }

  String _minutosAString(int minutosTotales, {required bool es12h}) {
    var minNorm = minutosTotales % (24 * 60);
    var horas = minNorm ~/ 60;
    final mins = minNorm % 60;
    if (es12h) {
      if (horas > 12) {
        horas -= 12;
      } else if (horas == 0) {
        horas = 12;
      }
    }
    final hStr = horas.toString().padLeft(2, '0');
    final mStr = mins.toString().padLeft(2, '0');
    return '$hStr:$mStr';
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
        width: anchoDialogoSeguro(context, 480),
        height: 520,
        child: ListView(
          children: [
            const Text(
              'Personaliza las franjas horarias de inicio y fin para los 12 bloques académicos (CFS Rafael Urdaneta).',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _cascadaAutomatica,
              onChanged: (v) => setState(() => _cascadaAutomatica = v),
              title: const Text(
                'Ajuste inteligente en cascada',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: const Text(
                'Al editar un bloque, ajusta los bloques siguientes sin solapamiento.',
                style: TextStyle(fontSize: 11.5),
              ),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.restore, size: 14),
                  label: const Text('Estándar INCES (07:30 - 17:30)'),
                  onPressed: () {
                    final defaults = [
                      '07:30 - 08:15',
                      '08:15 - 09:00',
                      '09:00 - 09:45',
                      '10:00 - 10:45',
                      '10:45 - 11:30',
                      '11:30 - 12:15',
                      '13:00 - 13:45',
                      '13:45 - 14:30',
                      '14:30 - 15:15',
                      '15:30 - 16:15',
                      '16:15 - 17:00',
                      '17:00 - 17:45',
                    ];
                    for (var i = 1; i <= 12; i++) {
                      _controllers[i]?.text = defaults[i - 1];
                    }
                    setState(() {});
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.nightlight_outlined, size: 14),
                  label: const Text('Vespertino / Nocturno (13:00 - 20:30)'),
                  onPressed: () {
                    final evening = [
                      '13:00 - 13:45',
                      '13:45 - 14:30',
                      '14:30 - 15:15',
                      '15:30 - 16:15',
                      '16:15 - 17:00',
                      '17:00 - 17:45',
                      '17:45 - 18:30',
                      '18:30 - 19:15',
                      '19:15 - 20:00',
                      '20:00 - 20:45',
                      '20:45 - 21:30',
                      '21:30 - 22:15',
                    ];
                    for (var i = 1; i <= 12; i++) {
                      _controllers[i]?.text = evening[i - 1];
                    }
                    setState(() {});
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.bedtime_outlined, size: 14),
                  label: const Text('Nocturno INCES (17:30 - 21:45)'),
                  onPressed: () {
                    final nocturno = [
                      '17:30 - 18:15',
                      '18:15 - 19:00',
                      '19:00 - 19:45',
                      '19:45 - 20:30',
                      '20:30 - 21:15',
                      '21:15 - 22:00',
                      '22:00 - 22:45',
                      '22:45 - 23:30',
                      '17:30 - 18:15',
                      '18:15 - 19:00',
                      '19:00 - 19:45',
                      '19:45 - 20:30',
                    ];
                    for (var i = 1; i <= 12; i++) {
                      _controllers[i]?.text = nocturno[i - 1];
                    }
                    setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                  onChanged: (_) => _ajustarEnCascada(b),
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
                  onChanged: (_) => _ajustarEnCascada(b),
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

/// Lo que devuelve [_DialogoNuevoGrupo] al crear un grupo.
class _GrupoCreado {
  const _GrupoCreado({required this.id, required this.etiqueta});

  final String id;
  final String etiqueta;
}

/// Crea el «grupo» (la sección) que falta, **sin salir del cuadrante**.
///
/// **Por qué existe.** Medido el 2026-10-29 con el propietario: para asignar una
/// clase había que elegir una «sección» que antes había que crear en otro
/// módulo —y que desde D11 ya no tiene entrada en el menú—, mientras el
/// desplegable sólo mostraba el nombre del curso. La queja textual fue «no se
/// sabe qué curso se va a dar». Aquí se elige **curso + materia**, que es lo que
/// un horario necesita de verdad, y el sistema resuelve el grupo por debajo con
/// un nombre automático. «Sección» deja de ser algo que el administrador tenga
/// que gestionar: pasa a ser un detalle interno.
class _DialogoNuevoGrupo extends StatefulWidget {
  const _DialogoNuevoGrupo({
    required this.periodo,
    this.seccionesRepo,
    this.curriculoRepo,
  });

  final String periodo;
  final SeccionesRepository? seccionesRepo;
  final CurriculoRepository? curriculoRepo;

  @override
  State<_DialogoNuevoGrupo> createState() => _DialogoNuevoGrupoState();
}

class _DialogoNuevoGrupoState extends State<_DialogoNuevoGrupo> {
  late final SeccionesRepository _secRepo =
      widget.seccionesRepo ?? SeccionesRepository();
  late final CurriculoRepository _curRepo =
      widget.curriculoRepo ?? CurriculoRepository();
  final TextEditingController _nombreCtrl = TextEditingController(text: 'ÚNICA');

  Map<String, String> _programas = const {};
  Map<String, String> _materias = const {};
  String? _programaId;
  String? _materiaId;
  bool _cargandoProgramas = true;
  bool _cargandoMaterias = false;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarProgramas();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarProgramas() async {
    final res = await _curRepo.listarProgramas(limite: 100);
    if (!mounted) return;
    res.when(
      success: (pagina) => setState(() {
        _programas = {for (final p in pagina.programas) p.id: p.nombre};
        _cargandoProgramas = false;
      }),
      failure: (fallo) => setState(() {
        _cargandoProgramas = false;
        _error = 'No pudimos cargar los cursos: ${fallo.message}';
      }),
    );
  }

  /// Las materias salen del **pensum del curso**: es lo que de verdad se dicta.
  Future<void> _cargarMaterias(String programaId) async {
    setState(() {
      _programaId = programaId;
      _materiaId = null;
      _materias = const {};
      _cargandoMaterias = true;
      _error = null;
    });

    final res = await _curRepo.detallePrograma(programaId);
    if (!mounted) return;

    res.when(
      success: (detalle) => setState(() {
        _materias = {
          for (final grupo in detalle.pensum)
            for (final materia in grupo.materias) materia.materiaId: materia.nombre,
        };
        _cargandoMaterias = false;
      }),
      failure: (fallo) => setState(() {
        _cargandoMaterias = false;
        _error = 'No pudimos leer el pensum: ${fallo.message}';
      }),
    );
  }

  Future<void> _crear() async {
    if (_guardando) return;
    if (_programaId == null || _materiaId == null) {
      setState(() => _error = 'Elige el curso y la materia.');
      return;
    }

    final nombre = _nombreCtrl.text.trim().isEmpty
        ? 'ÚNICA'
        : _nombreCtrl.text.trim().toUpperCase();

    setState(() {
      _guardando = true;
      _error = null;
    });

    final res = await _secRepo.crearSeccion(
      Seccion.crear(
        programaId: _programaId!,
        materiaId: _materiaId!,
        periodo: widget.periodo,
        nombre: nombre,
      ),
    );

    if (!mounted) return;

    res.when(
      success: (seccion) => Navigator.of(context).pop(
        _GrupoCreado(
          id: seccion.id,
          etiqueta: '${_programas[_programaId] ?? 'Curso'} · Secc. $nombre '
              '(${_materias[_materiaId]})',
        ),
      ),
      failure: (fallo) {
        // **El grupo ya existía.** Medido el 2026-10-30 contra la API real: el
        // alta de un grupo repetido devuelve 409 `REGISTRO_DUPLICADO`, y el
        // diálogo lo mostraba como «Ocurrió un error inesperado» dejando al
        // administrador sin salida — cuando el grupo que quería **ya estaba
        // creado**. Ahora se resuelve el que existe y se sigue.
        if (fallo.esConflicto) {
          _reusarGrupoExistente();
          return;
        }
        setState(() {
          _guardando = false;
          _error = fallo.message;
        });
      },
    );
  }

  /// Cierra el diálogo con el grupo que ya existe para ese curso y materia.
  Future<void> _reusarGrupoExistente() async {
    final existente = await _secRepo.resolverGrupo(
      programaId: _programaId!,
      materiaId: _materiaId!,
      periodo: widget.periodo,
    );
    if (!mounted) return;
    existente.when(
      success: (r) => Navigator.of(context).pop(
        _GrupoCreado(
          id: r.seccion.id,
          etiqueta: '${_programas[_programaId] ?? 'Curso'} · Secc. '
              '${r.seccion.nombre} (${_materias[_materiaId]})',
        ),
      ),
      failure: (fallo) => setState(() {
        _guardando = false;
        _error = fallo.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear curso · materia'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: _cargandoProgramas
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Esto crea el grupo que falta para el período '
                      '«${widget.periodo}». No tienes que ir a otro módulo.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    _Desplegable<String>(
                      etiqueta: 'Curso',
                      ancho: double.infinity,
                      valor: _programaId,
                      opciones: [
                        for (final entrada in _programas.entries)
                          DropdownMenuItem(
                            value: entrada.key,
                            child: Text(entrada.value,
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) _cargarMaterias(v);
                      },
                    ),
                    const SizedBox(height: 12),
                    _Desplegable<String>(
                      etiqueta: _cargandoMaterias
                          ? 'Materia (cargando pensum…)'
                          : 'Materia',
                      ancho: double.infinity,
                      valor: _materiaId,
                      opciones: [
                        for (final entrada in _materias.entries)
                          DropdownMenuItem(
                            value: entrada.key,
                            child: Text(entrada.value,
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => setState(() => _materiaId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nombreCtrl,
                      textCapitalization: TextCapitalization.characters,
                      // **Tope real, no adorno.** `sections.name` es `varchar(5)`
                      // y el contrato lo valida: escribir «Soldadura Grupo
                      // Prueba» devolvía «Los datos enviados no son válidos» y el
                      // grupo no se creaba. El límite se ve mientras se escribe
                      // en vez de aparecer como error al guardar.
                      maxLength: 5,
                      decoration: const InputDecoration(
                        labelText: 'Etiqueta del grupo',
                        helperText: 'Un identificador corto: «A», «B», «M1». Si '
                            'sólo habrá uno, deja «ÚNICA».',
                        counterText: '',
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando || _programaId == null || _materiaId == null
              ? null
              : _crear,
          child: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Crear y usar'),
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
