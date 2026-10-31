import 'package:flutter/material.dart';

import '../../models/inscripcion.dart';
import '../../models/usuario_admin.dart';
import '../../repositories/inscripcion_repository.dart';
import '../../repositories/secciones_repository.dart';
import '../../repositories/usuario_admin_repository.dart';
import '../../widgets/comunes.dart';
import '../../widgets/responsivo.dart';

/// Los aprendices de un aula: ver quién está, meter a uno y dar de baja.
///
/// **Por qué existe.** Hasta ahora la única forma de meter a un alumno en un
/// aula era la inscripción formal, y la única de sacarlo era que él renunciara.
/// El administrador no tenía ni lista ni botones: para saber quién estaba
/// tenía que abrir la planilla.
///
/// Dos reglas que se ven en la pantalla y no se negocian:
/// - **Dar de baja no borra**: el alumno conserva su expediente y su planilla, y
///   se le pide un motivo que queda auditado con quién lo hizo.
/// - **Matricular no crea cuentas**: sólo se puede añadir a quien ya existe; para
///   el resto está la invitación.
class DialogoAprendices extends StatefulWidget {
  const DialogoAprendices({
    super.key,
    required this.seccionId,
    required this.etiquetaAula,
    required this.seccionesRepo,
    this.inscripcionesRepo,
    this.usuariosRepo,
  });

  final String seccionId;
  final String etiquetaAula;
  final SeccionesRepository seccionesRepo;

  /// Se inyectan para las pruebas; en producción se construyen solos.
  final AdminInscripcionesRepository? inscripcionesRepo;
  final UsuariosAdminRepository? usuariosRepo;

  @override
  State<DialogoAprendices> createState() => _DialogoAprendicesState();
}

class _DialogoAprendicesState extends State<DialogoAprendices> {
  late final AdminInscripcionesRepository _inscripciones =
      widget.inscripcionesRepo ?? AdminInscripcionesRepository();
  late final UsuariosAdminRepository _usuarios =
      widget.usuariosRepo ?? UsuariosAdminRepository();

  final TextEditingController _busquedaCtrl = TextEditingController();

  List<InscripcionDetallada> _matriculados = const [];
  List<UsuarioAdmin> _resultados = const [];
  bool _cargando = true;
  bool _buscando = false;

  /// Incluir las cuentas de siembra (`@semilla.invalid`).
  ///
  /// **Por qué está aquí.** El buscador pedía al servidor sin `incluirDemo`, que
  /// es el valor por defecto, así que en un centro que aún no tiene aprendices
  /// reales la lista salía siempre vacía y la pantalla parecía rota. Medido el
  /// 2026-10-31: los únicos perfiles de estudiante eran de siembra, y ni el
  /// listado ni la búsqueda mostraban nada.
  bool _incluirDemo = false;

  /// Ya se pidió algo al servidor: sirve para no decir «no hay» antes de tiempo.
  bool _consultado = false;
  String? _error;
  String? _aviso;

  @override
  void initState() {
    super.initState();
    _cargarMatriculados();
    // Se listan los primeros aprendices sin escribir nada: una caja de búsqueda
    // que no responde hasta la segunda letra se lee como un buscador roto.
    _buscar('');
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarMatriculados() async {
    final resultado =
        await _inscripciones.obtenerInscripcionesDeSeccion(widget.seccionId);
    if (!mounted) return;

    resultado.when(
      success: (lista) => setState(() {
        _matriculados = lista;
        _cargando = false;
        _error = null;
      }),
      failure: (fallo) => setState(() {
        _cargando = false;
        _error = fallo.message;
      }),
    );
  }

  Future<void> _buscar(String texto) async {
    final limpio = texto.trim();

    setState(() => _buscando = true);
    final resultado = await _usuarios.listar(
      rol: 'estudiante',
      // Con una sola letra se consulta igual: el filtro del servidor es `ilike`
      // y devolver diez coincidencias es mejor que no devolver nada. Con la caja
      // vacía se listan los primeros, para que se vea que el buscador existe.
      busqueda: limpio.isNotEmpty ? limpio : null,
      incluirDemo: _incluirDemo,
      limite: 10,
    );
    if (!mounted) return;

    resultado.when(
      success: (pagina) => setState(() {
        _buscando = false;
        _consultado = true;
        // Quien ya está dentro no se ofrece: el servidor lo rechazaría con un
        // 409 y la pantalla estaría proponiendo algo imposible.
        final dentro = _matriculados
            .where((i) => i.estado != EstadoInscripcion.dropped)
            .map((i) => i.estudianteId)
            .toSet();
        _resultados = pagina.usuarios
            .where((u) => !dentro.contains(u.id))
            .toList(growable: false);
      }),
      failure: (fallo) => setState(() {
        _buscando = false;
        _error = fallo.message;
      }),
    );
  }

  Future<void> _matricular(UsuarioAdmin alumno) async {
    final resultado = await widget.seccionesRepo.matricular(
      seccionId: widget.seccionId,
      estudianteId: alumno.id,
    );
    if (!mounted) return;

    resultado.when(
      success: (_) {
        setState(() {
          _aviso = '${alumno.nombreCompleto} quedó matriculado.';
          _resultados = const [];
        });
        _busquedaCtrl.clear();
        _cargarMatriculados();
      },
      failure: (fallo) => setState(() => _error = fallo.message),
    );
  }

  Future<void> _darDeBaja(InscripcionDetallada inscripcion) async {
    final motivoCtrl = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dar de baja'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vas a dar de baja a '
                '${inscripcion.estudianteNombre ?? 'este aprendiz'}. '
                'Su expediente y su planilla se conservan: la baja cambia el '
                'estado, no borra nada.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: motivoCtrl,
                autofocus: true,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Motivo de la baja',
                  helperText: 'Queda en la auditoría con tu nombre.',
                  counterText: '',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(motivoCtrl.text),
            child: const Text('Dar de baja'),
          ),
        ],
      ),
    );

    if (motivo == null || !mounted) return;

    final resultado = await widget.seccionesRepo.darDeBaja(
      seccionId: widget.seccionId,
      estudianteId: inscripcion.estudianteId,
      motivo: motivo,
    );
    if (!mounted) return;

    resultado.when(
      success: (_) {
        setState(() => _aviso = 'Baja registrada. Sus datos se conservan.');
        _cargarMatriculados();
      },
      failure: (fallo) => setState(() => _error = fallo.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: anchoDialogoSeguro(context, 720),
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Aprendices · ${widget.etiquetaAula}',
                      style: tema.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _busquedaCtrl,
                onChanged: _buscar,
                decoration: InputDecoration(
                  labelText: 'Añadir un aprendiz',
                  hintText: 'Busca por nombre, correo o cédula',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                  suffixIcon: _buscando
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _incluirDemo
                            ? 'Mostrando también cuentas de prueba (@semilla)'
                            : 'Sólo cuentas reales',
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: _incluirDemo,
                      onChanged: (v) {
                        setState(() => _incluirDemo = v);
                        _buscar(_busquedaCtrl.text);
                      },
                    ),
                  ],
                ),
              ),
              // Decir por qué no hay nada es parte del arreglo: antes la caja
              // simplemente no respondía y parecía rota.
              if (_consultado && _resultados.isEmpty && !_buscando) ...[
                const SizedBox(height: 6),
                Text(
                  _busquedaCtrl.text.trim().isEmpty
                      ? (_incluirDemo
                          ? 'No hay aprendices registrados todavía. Se crean desde «Usuarios y Roles» o con una invitación.'
                          : 'No hay aprendices reales todavía: las únicas cuentas de estudiante son de prueba. Activa el interruptor de arriba para verlas.')
                      : 'Ningún aprendiz coincide con «${_busquedaCtrl.text.trim()}».',
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (_resultados.isNotEmpty) ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _resultados.length,
                    itemBuilder: (_, i) {
                      final alumno = _resultados[i];
                      return ListTile(
                        dense: true,
                        title: Text(alumno.nombreCompleto),
                        subtitle: Text(alumno.email),
                        trailing: TextButton(
                          onPressed: () => _matricular(alumno),
                          child: const Text('Matricular'),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (_aviso != null) ...[
                const SizedBox(height: 8),
                AvisoEnLinea(texto: _aviso!),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: tema.colorScheme.error),
                ),
              ],
              const Divider(height: 24),
              Expanded(
                child: _cargando
                    ? const Center(child: CircularProgressIndicator())
                    : _matriculados.isEmpty
                        ? const Center(
                            child: Text('Este aula todavía no tiene aprendices.'),
                          )
                        : ListView.builder(
                            itemCount: _matriculados.length,
                            itemBuilder: (_, i) {
                              final inscripcion = _matriculados[i];
                              final deBaja =
                                  inscripcion.estado == EstadoInscripcion.dropped;
                              return ListTile(
                                dense: true,
                                title: Text(
                                  inscripcion.estudianteNombre ??
                                      inscripcion.estudianteId,
                                ),
                                subtitle: Text(
                                  deBaja ? 'De baja · conserva su registro' : 'Matriculado',
                                  style: deBaja
                                      ? TextStyle(
                                          color: tema.colorScheme.onSurfaceVariant,
                                        )
                                      : null,
                                ),
                                trailing: deBaja
                                    ? null
                                    : IconButton(
                                        tooltip: 'Dar de baja',
                                        icon: const Icon(
                                          Icons.person_remove_outlined,
                                          size: 18,
                                        ),
                                        onPressed: () => _darDeBaja(inscripcion),
                                      ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
