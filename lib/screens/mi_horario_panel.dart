import 'package:flutter/material.dart';

import '../core/reglas_cuadrante.dart';
import '../models/cuadrante.dart';
import '../repositories/cuadrante_repository.dart';
import '../widgets/comunes.dart';
import '../widgets/cuadrante_grid.dart';

/// Horario del que mira: clases y, si es docente, guardias.
///
/// Una sola pantalla para los dos roles porque la separación la hace la RLS: el
/// backend devuelve las clases del llamante y, si es estudiante, deja `guardias`
/// vacío. Aquí no hay lógica de rol salvo avisar cuando el perfil no tiene rol
/// asignado —el `403 PERFIL_SIN_ROL`—, que es un estado real y no un fallo.
///
/// Es de **sólo lectura** a propósito: desde aquí no se mueve nada, porque
/// cambiar un horario es decisión de coordinación, no del propio docente.
class MiHorarioPanel extends StatefulWidget {
  const MiHorarioPanel({super.key, this.repositorio});

  final CuadranteRepository? repositorio;

  @override
  State<MiHorarioPanel> createState() => _MiHorarioPanelState();
}

class _MiHorarioPanelState extends State<MiHorarioPanel> {
  late final CuadranteRepository _repo =
      widget.repositorio ?? CuadranteRepository();

  MiHorario? _horario;
  bool _cargando = true;
  String? _error;
  bool _sinRol = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
      _sinRol = false;
    });

    final resultado = await _repo.miHorario();
    if (!mounted) return;

    resultado.when(
      success: (horario) => setState(() {
        _cargando = false;
        _horario = horario;
      }),
      failure: (fallo) => setState(() {
        _cargando = false;
        _sinRol = fallo.code == codigoPerfilSinRol;
        _error = _sinRol ? null : fallo.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esEstudiante = _horario?.rol == 'estudiante';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloSeccion(
          'Mi horario',
          subtitulo: esEstudiante
              ? 'Tus clases de este lapso, organizadas por día y bloque.'
              : 'Tus clases y guardias de este lapso, organizadas por día y '
                  'bloque.',
        ),
        const SizedBox(height: 12),
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
    if (_sinRol) {
      return const PanelVacio(
        titulo: 'Tu perfil aún no tiene un rol asignado',
        mensaje: 'El horario se construye a partir de tu rol. Pídele al '
            'Administrador Maestro que asigne el tuyo y vuelve: tu horario '
            'aparecerá aquí.',
        icono: Icons.person_outline_outlined,
        nota: 'Mientras tanto, el sistema no puede saber qué clases ni guardias '
            'son tuyas.',
      );
    }

    final horario = _horario;
    if (horario == null || horario.vacio) {
      return PanelVacio(
        titulo: 'No tienes clases asignadas en este lapso',
        mensaje: horario?.sinPeriodo ?? false
            ? 'Marca un lapso como vigente en coordinación y tu horario se '
                'llenará solo.'
            : 'Cuando te asignen secciones o guardias, aparecerán en su día y '
                'bloque.',
        icono: Icons.calendar_month_outlined,
        nota: horario?.periodo != null ? 'Lapso: ${horario!.periodo}' : null,
      );
    }

    final celdas = <String, List<Widget>>{};
    for (final entrada in agruparClases(horario.clases, chip: _chipClase)
        .entries) {
      celdas[entrada.key] = entrada.value;
    }
    for (final entrada in agruparGuardias(horario.guardias, chip: _chipGuardia)
        .entries) {
      celdas.putIfAbsent(entrada.key, () => []).addAll(entrada.value);
    }

    final theme = Theme.of(context);
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Clases (color por aula / taller asignado)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: PaletaAulasCuadrante.colorGuardia,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Guardias Docentes',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(child: CuadranteGrid(celdas: celdas)),
      ],
    );
  }

  Widget _chipClase(ClaseCuadrante clase) {
    final materia = clase.materia.isNotEmpty ? clase.materia : 'Clase';
    final subtitulo = clase.aula.isNotEmpty
        ? '${clase.aula} · ${clase.seccion}'
        : clase.seccion;
    final colorAula = PaletaAulasCuadrante.colorParaAula(clase.aulaId);
    return ChipCuadrante(
      titulo: materia,
      subtitulo: subtitulo,
      color: colorAula,
      etiquetaAula: clase.aula.isNotEmpty ? clase.aula : null,
      destacado: true,
      onTap: null,
    );
  }

  Widget _chipGuardia(Guardia guardia) {
    final aula = guardia.aulaId.isNotEmpty
        ? guardia.aulaId
        : 'Espacio no disponible';
    final colorAula = PaletaAulasCuadrante.colorParaAula(guardia.aulaId);
    return ChipCuadrante(
      titulo: 'Guardia',
      subtitulo: aula,
      color: colorAula,
      etiquetaAula: aula,
      esGuardia: true,
      onTap: null,
    );
  }
}
