import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/gateways/aula_gateway.dart';
import '../../core/result.dart';
import '../../theme/inces_theme.dart';
import '../../theme/temas_formacion.dart';
import '../../widgets/comunes.dart';
import '../libro_calificaciones_panel.dart';

/// Centro de calificaciones y revisión docente (estilo Google Classroom / INCES).
///
/// Permite al facilitador consultar en un solo lugar todas las secciones que
/// tiene asignadas, ver qué tareas evaluativas existen y acceder de inmediato
/// al [LibroCalificacionesPanel] de cada una para asentar notas en borrador y
/// devolver calificaciones oficiales a los aprendices.
class DocenteCalificacionesPanel extends StatefulWidget {
  const DocenteCalificacionesPanel({
    super.key,
    required this.gateway,
    this.aulaGateway,
    this.onNavegarA,
  });

  /// Fuente del listado de secciones del docente (`/mi-horario`).
  final AulasPropiasGateway gateway;

  /// Puerta del contenido de tareas y calificaciones del aula virtual (M6).
  final AulaGateway? aulaGateway;

  /// Permite saltar a otra sección del panel docente (por ejemplo, «Mis aulas»).
  final void Function(String seccion)? onNavegarA;

  @override
  State<DocenteCalificacionesPanel> createState() =>
      _DocenteCalificacionesPanelState();
}

class _DocenteCalificacionesPanelState
    extends State<DocenteCalificacionesPanel> {
  bool _cargando = true;
  String? _error;
  List<AulaResumen> _aulas = const [];
  String? _seccionSeleccionadaId;

  /// Tareas en memoria organizadas por el ID de la sección.
  final Map<String, List<TareaDeClase>> _tareasPorSeccion = {};
  final Set<String> _cargandoSecciones = {};

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

    final resultado = await Result.guard(() => widget.gateway.misAulas());
    if (!mounted) return;

    if (resultado.isFailure) {
      setState(() {
        _cargando = false;
        _error = resultado.errorOrNull?.message ?? 'Error al cargar secciones';
      });
      return;
    }

    final misAulas = resultado.valueOrNull!;
    _aulas = misAulas.aulas;

    setState(() {
      _cargando = false;
    });

    // Cargar en paralelo las tareas de las secciones
    if (widget.aulaGateway != null) {
      for (final aula in _aulas) {
        _cargarTareasDeSeccion(aula.seccionId);
      }
    }
  }

  Future<void> _cargarTareasDeSeccion(String seccionId) async {
    if (widget.aulaGateway == null) return;
    setState(() => _cargandoSecciones.add(seccionId));

    final resultado = await Result.guard(
      () => widget.aulaGateway!.trabajoDeClase(seccionId),
    );
    if (!mounted) return;

    setState(() {
      _cargandoSecciones.remove(seccionId);
      if (resultado.isSuccess) {
        _tareasPorSeccion[seccionId] = resultado.valueOrNull ?? const [];
      }
    });
  }

  Future<void> _abrirLibro(TareaDeClase tarea, String seccionId) async {
    if (widget.aulaGateway == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El libro de calificaciones requiere conexión activa al aula virtual.',
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LibroCalificacionesPanel(
          tareaId: tarea.id,
          tareaTitulo: tarea.titulo,
          gateway: widget.aulaGateway!,
          onCambio: () => _cargarTareasDeSeccion(seccionId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;

    if (_cargando) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return ErrorConReintento(
        titulo: 'No se pudieron cargar las secciones',
        mensaje: _error!,
        onReintentar: _cargar,
      );
    }

    if (_aulas.isEmpty) {
      return const PanelVacio(
        titulo: 'Sin secciones asignadas',
        mensaje: 'No tienes secciones asignadas en este período académico. '
            'Cuando la coordinación registre tus cursos en el cuadrante, '
            'podrás calificar las tareas desde aquí.',
        icono: Icons.grading_outlined,
      );
    }

    // Filtrar secciones a mostrar
    final seccionesAMostrar = _seccionSeleccionadaId == null
        ? _aulas
        : _aulas.where((a) => a.seccionId == _seccionSeleccionadaId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _construirCabecera(theme, esOscuro),
        const SizedBox(height: 16),
        if (_aulas.length > 1) ...[
          _construirFiltroSecciones(theme),
          const SizedBox(height: 16),
        ],
        for (final aula in seccionesAMostrar) ...[
          _construirTarjetaSeccion(aula, theme, esOscuro),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _construirCabecera(ThemeData theme, bool esOscuro) {
    var totalTareasCalificables = 0;
    for (final tareas in _tareasPorSeccion.values) {
      totalTareasCalificables += tareas.where((t) => t.tipo.seCalifica).length;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: esOscuro
            ? IncesTheme.superficieOscura
            : IncesTheme.superficieClara,
        borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: IncesTheme.azulPrimario.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(IncesTheme.radioControl),
                ),
                child: const Icon(
                  Icons.grading_rounded,
                  color: IncesTheme.azulPrimario,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Centro de Calificaciones y Entregas',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Revisa trabajos de clase, asigna notas en borrador y devuelve evaluaciones a tus estudiantes.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar tareas',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _cargar,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _construirMiniMetrica(
                'Secciones activas',
                '${_aulas.length}',
                Icons.class_outlined,
                theme,
              ),
              const SizedBox(width: 16),
              _construirMiniMetrica(
                'Tareas evaluativas',
                '$totalTareasCalificables',
                Icons.assignment_outlined,
                theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirMiniMetrica(
    String etiqueta,
    String valor,
    IconData icono,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(IncesTheme.radioControl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$etiqueta: ',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            valor,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirFiltroSecciones(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            selected: _seccionSeleccionadaId == null,
            label: Text('Todas las secciones (${_aulas.length})'),
            onSelected: (_) => setState(() => _seccionSeleccionadaId = null),
          ),
          const SizedBox(width: 8),
          for (final aula in _aulas) ...[
            FilterChip(
              selected: _seccionSeleccionadaId == aula.seccionId,
              label: Text(
                aula.materia.isNotEmpty
                    ? '${aula.materia} (${aula.seccion})'
                    : aula.etiqueta,
              ),
              onSelected: (_) => setState(
                () => _seccionSeleccionadaId =
                    _seccionSeleccionadaId == aula.seccionId
                        ? null
                        : aula.seccionId,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _construirTarjetaSeccion(
    AulaResumen aula,
    ThemeData theme,
    bool esOscuro,
  ) {
    final area = AreaFormativa.resolver(aula.materia);
    final estaCargando = _cargandoSecciones.contains(aula.seccionId);
    final todasTareas = _tareasPorSeccion[aula.seccionId] ?? const [];
    final tareasCalificables =
        todasTareas.where((t) => t.tipo.seCalifica).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: area.colorPrimario.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: area.colorPrimario.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(area.icono, size: 14, color: area.colorPrimario),
                      const SizedBox(width: 6),
                      Text(
                        area.etiqueta,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: area.colorPrimario,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (estaCargando)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    '${tareasCalificables.length} tarea(s) activa(s)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              aula.etiqueta,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            if (widget.aulaGateway == null) ...[
              const AvisoEnLinea(
                texto:
                    'Para ver y calificar las tareas se requiere inyección de contenido del aula virtual.',
                tono: TonoAviso.info,
              ),
            ] else if (estaCargando) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else if (tareasCalificables.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(IncesTheme.radioControl),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.assignment_late_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No hay tareas evaluativas creadas en esta sección.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (widget.onNavegarA != null)
                      TextButton.icon(
                        // No abre un segundo formulario: lleva al aula, que es
                        // donde se crean las tareas. La etiqueta lo dice para
                        // que el salto no se lea como un botón roto.
                        onPressed: () => widget.onNavegarA!('Aulas Virtuales'),
                        icon: const Icon(Icons.add_circle_outline, size: 16),
                        label: const Text('Crear tarea en el aula'),
                      ),
                  ],
                ),
              ),
            ] else ...[
              for (final tarea in tareasCalificables) ...[
                _construirFilaTarea(tarea, aula.seccionId, theme),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _construirFilaTarea(
    TareaDeClase tarea,
    String seccionId,
    ThemeData theme,
  ) {
    final paleta = PaletaInces.de(context);
    final fechaVencimiento = tarea.fechaLimite != null
        ? DateTime.tryParse(tarea.fechaLimite!)
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(IncesTheme.radioControl),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: IncesTheme.azulPrimario.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(IncesTheme.radioControl),
            ),
            child: Icon(
              tarea.tipo == TipoTarea.pregunta
                  ? Icons.quiz_outlined
                  : Icons.assignment_outlined,
              color: IncesTheme.azulPrimario,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tarea.titulo,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (tarea.descripcion.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    tarea.descripcion.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Etiqueta(
                      texto: '${tarea.puntosMaximos.toStringAsFixed(0)} pts',
                    ),
                    if (fechaVencimiento != null)
                      Etiqueta(
                        texto: 'Vence: ${formatearFechaHora(fechaVencimiento)}',
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => _abrirLibro(tarea, seccionId),
            icon: const Icon(Icons.grading_rounded, size: 16),
            label: const Text('Calificar'),
            style: FilledButton.styleFrom(
              backgroundColor: paleta.enlace,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
