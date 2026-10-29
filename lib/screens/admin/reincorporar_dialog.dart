import 'package:flutter/material.dart';

import '../../core/result.dart';
import '../../models/inscripcion.dart';
import '../../repositories/inscripcion_repository.dart';
import '../../widgets/comunes.dart';
import '../../widgets/responsivo.dart';

/// Diálogo para reincorporar a alguien dado de baja en **una** sección.
///
/// Reincorpora a un estudiante dado de baja. El backend lo permite aunque la
/// sección quede por encima de su capacidad (`sobrecupo`), por eso el aviso lo
/// deja claro antes de confirmar.
///
/// **Antes pedía dos UUIDs por teclado** («ID del estudiante», «ID de la
/// sección»). Existía, compilaba, pasaba sus pruebas y **no se podía usar**:
/// ningún administrador conoce el uuid de un estudiante. Un control que no puede
/// funcionar es peor que uno ausente: ocupa sitio y promete algo.
///
/// Ahora se **elige**, y la lista de candidatos no es una comodidad: es la única
/// que puede funcionar. `reincorporar_inscripcion` exige que el estudiante
/// **tenga historial en esa sección** —a quien nunca cursó se le responde 404
/// `SIN_HISTORIAL_EN_SECCION`—, así que los únicos elegibles son los `DROPPED`
/// de la sección que el administrador ya tenía delante. Un buscador libre de
/// estudiantes habría invitado a un error que el backend rechaza por diseño.
///
/// La sección **no se pregunta**: llega por parámetro desde la tarjeta que se
/// pulsó. Es la misma razón por la que la exportación va por tarjeta —un diálogo
/// que preguntara «¿cuál sección?» sería un paso de más para algo que la pantalla
/// ya sabe— y, además, es lo que permite acotar los candidatos a esa sección.
class DialogoReincorporar extends StatefulWidget {
  const DialogoReincorporar({
    super.key,
    required this.repo,
    required this.seccionId,
    required this.seccionNombre,
  });

  final AdminInscripcionesRepository repo;
  final String seccionId;
  final String seccionNombre;

  @override
  State<DialogoReincorporar> createState() => _DialogoReincorporarState();
}

class _DialogoReincorporarState extends State<DialogoReincorporar> {
  List<InscripcionDetallada> _candidatos = const [];
  String? _estudianteId;
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarCandidatos();
  }

  /// Los únicos reincorporables de la sección: los que ya cursaron y se dieron
  /// de baja. `ENROLLED` ya está dentro, `WAITLISTED` nunca entró y `PENDING_BID`
  /// tiene una oferta viva; ninguno de los tres tiene una baja que revertir.
  static List<InscripcionDetallada> _bajasDe(List<InscripcionDetallada> todas) =>
      todas.where((i) => i.estado == EstadoInscripcion.dropped).toList();

  Future<void> _cargarCandidatos() async {
    final resultado =
        await widget.repo.obtenerInscripcionesDeSeccion(widget.seccionId);
    if (!mounted) return;

    setState(() {
      _cargando = false;
      switch (resultado) {
        case Success(value: final todas):
          _candidatos = _bajasDe(todas);
        case Failure(error: final fallo):
          _error = fallo.message;
      }
    });
  }

  Future<void> _guardar() async {
    if (_guardando || _estudianteId == null) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final resultado = await widget.repo.reincorporar(
      estudianteId: _estudianteId!,
      seccionId: widget.seccionId,
    );
    if (!mounted) return;
    setState(() => _guardando = false);

    resultado.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (fallo) => setState(() => _error = fallo.message),
    );
  }

  /// Etiqueta de un candidato: la resuelve el modelo (`etiquetaEstudiante`):
  /// nombre → correo → «Sin nombre registrado». El UUID nunca es etiqueta de
  /// usuario, y con un nombre vacío la fila se quedaba en blanco porque `??`
  /// no salta con una cadena vacía.
  static String _etiquetaCandidato(InscripcionDetallada i) =>
      i.etiquetaEstudiante;

  @override
  Widget build(BuildContext context) {
    final puedeGuardar = !_guardando && _estudianteId != null;

    return AlertDialog(
      title: const Text('Reincorporar estudiante'),
      content: SizedBox(
        width: anchoDialogoSeguro(context, 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AvisoEnLinea(
                texto: 'Reincorpora a alguien dado de baja. Puede dejar la '
                    'sección por encima de su capacidad: úsalo tras ampliar el '
                    'cupo o cuando la demanda lo justifica.',
                icono: Icons.info_outline,
                tono: TonoAviso.advertencia,
              ),
              const SizedBox(height: 14),
              Text(
                'Sección: ${widget.seccionNombre}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              _selectorCandidato(),
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
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: puedeGuardar ? _guardar : null,
          child: Text(_guardando ? 'Guardando…' : 'Reincorporar'),
        ),
      ],
    );
  }

  Widget _selectorCandidato() {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }

    if (_candidatos.isEmpty) {
      // No es un error: es la respuesta. Una sección sin bajas no tiene a quién
      // reincorporar, y el botón de confirmar queda deshabilitado —mejor eso que
      // un desplegable vacío que parece una avería—.
      return const AvisoEnLinea(
        texto: 'En esta sección no hay nadie dado de baja, así que no hay a '
            'quién reincorporar.',
        icono: Icons.info_outline,
        tono: TonoAviso.info,
      );
    }

    // `DropdownButton` y no `DropdownButtonFormField`: el primero recibe el
    // valor por `value` y se repinta al cambiarlo, mientras que el segundo lo
    // toma como `initialValue` de un `FormField` y **no propaga un cambio**
    // posterior. Con `DropdownButtonFormField` la selección no se vería hasta
    // cerrar y reabrir, que es la trampa documentada de `TextFormField`.
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Estudiante dado de baja',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _estudianteId,
          isExpanded: true,
          isDense: true,
          hint: const Text('Elige a quién reincorporar'),
          items: [
            for (final candidato in _candidatos)
              DropdownMenuItem(
                value: candidato.estudianteId,
                child: Text(
                  _etiquetaCandidato(candidato),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _guardando
              ? null
              : (valor) => setState(() => _estudianteId = valor),
        ),
      ),
    );
  }
}

/// Abre [DialogoReincorporar]. Devuelve `true` si se reincorporó, para que el
/// llamador refresque la ocupación.
Future<bool?> mostrarReincorporar({
  required BuildContext context,
  required AdminInscripcionesRepository repo,
  required String seccionId,
  required String seccionNombre,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => DialogoReincorporar(
      repo: repo,
      seccionId: seccionId,
      seccionNombre: seccionNombre,
    ),
  );
}
