import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/gateways/aula_gateway.dart';
import '../../core/result.dart';
import '../../theme/inces_theme.dart';
import '../../theme/temas_formacion.dart';
import '../../widgets/comunes.dart';

/// Categoría de tareas en el To-Do hub del aprendiz (modelo Google Classroom).
enum CategoriaTareaEstudiante {
  asignadas,
  vencidas,
  completadas;

  String get etiqueta {
    switch (this) {
      case CategoriaTareaEstudiante.asignadas:
        return 'Asignadas';
      case CategoriaTareaEstudiante.vencidas:
        return 'Sin entregar / Vencidas';
      case CategoriaTareaEstudiante.completadas:
        return 'Completadas y Calificadas';
    }
  }

  IconData get icono {
    switch (this) {
      case CategoriaTareaEstudiante.asignadas:
        return Icons.assignment_outlined;
      case CategoriaTareaEstudiante.vencidas:
        return Icons.warning_amber_rounded;
      case CategoriaTareaEstudiante.completadas:
        return Icons.check_circle_outline_rounded;
    }
  }
}

/// Elemento combinado de tarea de clase con su aula y entrega del aprendiz.
class ItemTareaEstudiante {
  const ItemTareaEstudiante({
    required this.tarea,
    required this.aula,
    this.entrega,
  });

  final TareaDeClase tarea;
  final AulaResumen aula;
  final Entrega? entrega;

  DateTime? get fechaLimite =>
      tarea.fechaLimite != null ? DateTime.tryParse(tarea.fechaLimite!) : null;

  bool get estaVencida {
    if (fechaLimite == null) return false;
    return DateTime.now().isAfter(fechaLimite!);
  }

  bool get estaEntregadaODevuelta {
    if (entrega == null) return false;
    return entrega!.estado == EstadoEntrega.entregada ||
        entrega!.estado == EstadoEntrega.devuelta;
  }

  CategoriaTareaEstudiante get categoria {
    if (estaEntregadaODevuelta) {
      return CategoriaTareaEstudiante.completadas;
    }
    if (estaVencida) {
      return CategoriaTareaEstudiante.vencidas;
    }
    return CategoriaTareaEstudiante.asignadas;
  }
}

/// Panel de Tareas y Pendientes del Aprendiz (estilo Google Classroom / INCES).
///
/// Agrupa en un solo lugar todas las tareas evaluativas de las diversas aulas
/// en que está matriculado el estudiante, organizándolas en tres pestañas:
/// 1. Asignadas (en plazo).
/// 2. Sin entregar (vencidas).
/// 3. Completadas (entregadas o ya calificadas con su nota oficial).
class EstudianteTareasPanel extends StatefulWidget {
  const EstudianteTareasPanel({
    super.key,
    required this.aulasGateway,
    this.aulaGateway,
    this.onNavegarA,
  });

  final AulasPropiasGateway aulasGateway;
  final AulaGateway? aulaGateway;
  final void Function(String seccion)? onNavegarA;

  @override
  State<EstudianteTareasPanel> createState() => _EstudianteTareasPanelState();
}

class _EstudianteTareasPanelState extends State<EstudianteTareasPanel> {
  bool _cargando = true;
  String? _error;
  List<ItemTareaEstudiante> _items = const [];
  CategoriaTareaEstudiante _categoriaSeleccionada =
      CategoriaTareaEstudiante.asignadas;

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

    final resAulas = await Result.guard(() => widget.aulasGateway.misAulas());
    if (!mounted) return;

    if (resAulas.isFailure) {
      setState(() {
        _cargando = false;
        _error = resAulas.errorOrNull?.message ?? 'Error al cargar aulas';
      });
      return;
    }

    final misAulas = resAulas.valueOrNull!;
    if (misAulas.aulas.isEmpty || widget.aulaGateway == null) {
      setState(() {
        _cargando = false;
        _items = const [];
      });
      return;
    }

    final resEntregas =
        await Result.guard(() => widget.aulaGateway!.misEntregas());
    if (!mounted) return;

    final entregasPorTarea = <String, Entrega>{};
    if (resEntregas.isSuccess) {
      for (final e in resEntregas.valueOrNull ?? <Entrega>[]) {
        entregasPorTarea[e.tareaId] = e;
      }
    }

    final listaFinal = <ItemTareaEstudiante>[];

    for (final aula in misAulas.aulas) {
      final resTrabajo = await Result.guard(
        () => widget.aulaGateway!.trabajoDeClase(aula.seccionId),
      );
      if (resTrabajo.isSuccess) {
        final tareas = resTrabajo.valueOrNull ?? <TareaDeClase>[];
        for (final t in tareas) {
          if (t.tipo.seCalifica) {
            listaFinal.add(
              ItemTareaEstudiante(
                tarea: t,
                aula: aula,
                entrega: entregasPorTarea[t.id],
              ),
            );
          }
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _cargando = false;
      _items = listaFinal;
    });
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
        titulo: 'No se pudieron cargar las tareas',
        mensaje: _error!,
        onReintentar: _cargar,
      );
    }

    final asignadas = _items
        .where((i) => i.categoria == CategoriaTareaEstudiante.asignadas)
        .toList();
    final vencidas = _items
        .where((i) => i.categoria == CategoriaTareaEstudiante.vencidas)
        .toList();
    final completadas = _items
        .where((i) => i.categoria == CategoriaTareaEstudiante.completadas)
        .toList();

    final listaActiva = switch (_categoriaSeleccionada) {
      CategoriaTareaEstudiante.asignadas => asignadas,
      CategoriaTareaEstudiante.vencidas => vencidas,
      CategoriaTareaEstudiante.completadas => completadas,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _construirCabecera(theme, esOscuro),
        const SizedBox(height: 16),
        _construirSelectorPestanas(
          asignadas.length,
          vencidas.length,
          completadas.length,
          theme,
        ),
        const SizedBox(height: 20),
        if (listaActiva.isEmpty)
          _construirVacio(theme)
        else
          for (final item in listaActiva) ...[
            _construirTarjetaTarea(item, theme),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _construirCabecera(ThemeData theme, bool esOscuro) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: esOscuro
            ? IncesTheme.superficieOscura
            : IncesTheme.superficieClara,
        borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: IncesTheme.azulPrimario.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(IncesTheme.radioControl),
            ),
            child: const Icon(
              Icons.checklist_rounded,
              color: IncesTheme.azulPrimario,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tareas y Actividades Pendientes',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Supervisa tus asignaciones de todas tus aulas, plazos límite y calificaciones recibidas.',
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
    );
  }

  Widget _construirSelectorPestanas(
    int totalAsignadas,
    int totalVencidas,
    int totalCompletadas,
    ThemeData theme,
  ) {
    final paleta = PaletaInces.de(context);

    // **Wrap y no Row con scroll horizontal.** Medido el 2026-10-22: con
    // tres pestanas la tercera («Completadas y Calificadas») quedaba en x=434,
    // fuera de la pantalla de 390. Envolverlas las muestra todas.
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _botonPestana(
          categoria: CategoriaTareaEstudiante.asignadas,
          conteo: totalAsignadas,
          colorActivo: IncesTheme.azulPrimario,
          theme: theme,
        ),
        _botonPestana(
          categoria: CategoriaTareaEstudiante.vencidas,
          conteo: totalVencidas,
          colorActivo: paleta.error,
          theme: theme,
        ),
        _botonPestana(
          categoria: CategoriaTareaEstudiante.completadas,
          conteo: totalCompletadas,
          colorActivo: paleta.exito,
          theme: theme,
        ),
      ],
    );
  }

  Widget _botonPestana({
    required CategoriaTareaEstudiante categoria,
    required int conteo,
    required Color colorActivo,
    required ThemeData theme,
  }) {
    final seleccionada = _categoriaSeleccionada == categoria;

    return InkWell(
      onTap: () => setState(() => _categoriaSeleccionada = categoria),
      borderRadius: BorderRadius.circular(IncesTheme.radioControl),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: seleccionada
              ? colorActivo.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(IncesTheme.radioControl),
          border: Border.all(
            color: seleccionada
                ? colorActivo.withValues(alpha: 0.4)
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              categoria.icono,
              size: 16,
              color: seleccionada
                  ? colorActivo
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              categoria.etiqueta,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: seleccionada ? FontWeight.w700 : FontWeight.w500,
                color: seleccionada
                    ? colorActivo
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: seleccionada
                    ? colorActivo
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$conteo',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: seleccionada ? Colors.white : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirVacio(ThemeData theme) {
    final (titulo, mensaje) = switch (_categoriaSeleccionada) {
      CategoriaTareaEstudiante.asignadas => (
        '¡Estás al día!',
        'No tienes tareas pendientes por entregar. Las tareas aparecen aquí '
            'cuando tu docente las publique en «Mis aulas»; si todavía no '
            'tienes curso, pide tu cupo en «Inscribirme en un curso».'
      ),
      CategoriaTareaEstudiante.vencidas => (
        '¡Excelente desempeño!',
        'No tienes ninguna tarea atrasada ni vencida.'
      ),
      CategoriaTareaEstudiante.completadas => (
        'Sin tareas completadas aún',
        'Cuando envíes tus entregas y el docente las revise, tus calificaciones aparecerán aquí.'
      ),
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          children: [
            Icon(
              _categoriaSeleccionada.icono,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirTarjetaTarea(ItemTareaEstudiante item, ThemeData theme) {
    final paleta = PaletaInces.de(context);
    final area = AreaFormativa.resolver(item.aula.materia);
    final fecha = item.fechaLimite;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: area.colorPrimario.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: area.colorPrimario.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(area.icono, size: 12, color: area.colorPrimario),
                      const SizedBox(width: 4),
                      Text(
                        item.aula.etiqueta,
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
                _construirInsigniaEstado(item, paleta),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.tarea.titulo,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (item.tarea.descripcion.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.tarea.descripcion.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Etiqueta(
                  texto: '${item.tarea.puntosMaximos.toStringAsFixed(0)} pts',
                ),
                const SizedBox(width: 8),
                if (fecha != null)
                  Etiqueta(
                    texto: 'Vence: ${formatearFechaHora(fecha)}',
                  ),
                const Spacer(),
                if (widget.onNavegarA != null)
                  TextButton.icon(
                    onPressed: () => widget.onNavegarA!('Mis aulas'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Abrir en Aula'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirInsigniaEstado(
    ItemTareaEstudiante item,
    PaletaInces paleta,
  ) {
    if (item.entrega?.estado == EstadoEntrega.devuelta &&
        item.entrega?.notaAsignada != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: paleta.exito.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: paleta.exito.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 14, color: paleta.exito),
            const SizedBox(width: 4),
            Text(
              'Nota: ${item.entrega!.notaAsignada!.toStringAsFixed(1)} / ${item.tarea.puntosMaximos.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: paleta.exito,
              ),
            ),
          ],
        ),
      );
    }

    if (item.entrega?.estado == EstadoEntrega.entregada) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: paleta.info.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: paleta.info.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt_rounded, size: 14, color: paleta.info),
            const SizedBox(width: 4),
            Text(
              'Entregada',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: paleta.info,
              ),
            ),
          ],
        ),
      );
    }

    if (item.estaVencida) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: paleta.error.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: paleta.error.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 14, color: paleta.error),
            const SizedBox(width: 4),
            Text(
              'Sin entregar · Vencida',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: paleta.error,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: paleta.advertencia.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: paleta.advertencia.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pending_actions_rounded, size: 14, color: paleta.advertencia),
          const SizedBox(width: 4),
          Text(
            'Pendiente',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: paleta.advertencia,
            ),
          ),
        ],
      ),
    );
  }
}
