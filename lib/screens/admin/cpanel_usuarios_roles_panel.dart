import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/recuperacion_password.dart';
import '../../models/usuario_admin.dart';
import '../../repositories/recuperacion_repository.dart';
import '../../repositories/usuario_admin_repository.dart';
import '../../theme/inces_theme.dart';
import '../../widgets/comunes.dart';
import '../../core/refresco_secciones.dart';
import 'cpanel_invitaciones_panel.dart';

class CpanelUsuariosRolesPanel extends StatefulWidget {
  const CpanelUsuariosRolesPanel({
    super.key,
    this.repo,
    this.repoRecuperacion,
  });

  final UsuariosAdminRepository? repo;
  final RecuperacionRepository? repoRecuperacion;

  @override
  State<CpanelUsuariosRolesPanel> createState() =>
      _CpanelUsuariosRolesPanelState();
}

class _CpanelUsuariosRolesPanelState extends State<CpanelUsuariosRolesPanel>
    with RefrescoAlVolver<CpanelUsuariosRolesPanel> {
  late final _repo = widget.repo ?? UsuariosAdminRepository();
  late final _repoRecuperacion =
      widget.repoRecuperacion ?? RecuperacionRepository();
  final _busqueda = TextEditingController();
  PaginaUsuarios? _pagina;
  String? _rol;
  bool? _activo;
  /// Si el formulario de invitación está desplegado.
  ///
  /// **`false` a propósito.** Medido el 2026-10-24: el panel abría con el
  /// formulario ocupando el pliegue y la lista de usuarios debajo. La prueba
  /// «Usuarios y Roles expone gestión real, no sólo invitaciones» fallaba por
  /// eso: el campo de búsqueda ni siquiera llegaba a construirse.
  bool _mostrarInvitacion = false;
  bool _ocultarCuentasDemo = true;
  bool _cargando = true;
  String? _error;
  Timer? _debounce;
  int _paginaActual = 0;
  static const _limite = 25;

  /// Una operación administrativa a la vez.
  ///
  /// `cambiarRol` y `restablecer` son mutaciones: dos pulsaciones seguidas
  /// lanzarían dos peticiones y la segunda decidiría sobre un estado que ya
  /// cambió. Bloquear el doble envío es lo barato y lo que el usuario espera.
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (mounted) {
      setState(() {
        // **Refresco en segundo plano:** si ya hay datos no se vuelve a mostrar
        // el esqueleto; se conserva lo que hay hasta que llegue lo nuevo.
        _cargando = silencioso ? false : true;
      });
    }
    final r = await _repo.listar(
      rol: _rol,
      activo: _activo,
      busqueda: _busqueda.text,
      limite: _limite,
      desplazamiento: _paginaActual * _limite,
    );
    if (!mounted) return;
    r.when(
      success: (p) => setState(() {
        _pagina = p;
        _error = null;
        _cargando = false;
        marcarCarga();
      }),
      failure: (e) => setState(() {
        _error = e.message;
        _cargando = false;
      }),
    );
  }

  @override
  String get seccion => 'Usuarios y Roles';

  @override
  Future<void> refrescarEnSegundoPlano() => _cargar(silencioso: true);

  void _buscar(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _paginaActual = 0;
      _cargar();
    });
  }

  /// Emite un código temporal para que el usuario restablezca su contraseña.
  ///
  /// **El administrador no ve ni elige la contraseña**: sólo entrega el código.
  /// El código se muestra una sola vez porque no se guarda en claro en ninguna
  /// parte; si se pierde, se emite otro (lo que anula el anterior).
  ///
  /// La verificación de identidad es un procedimiento institucional —presencial,
  /// con la cédula— que el sistema no puede sustituir. Por eso el diálogo lo dice
  /// explícitamente en vez de dar a entender que basta con pulsar un botón.
  Future<void> _restablecer(UsuarioAdmin u) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);

    final r = await _repoRecuperacion.emitirCodigo(u.id);
    if (!mounted) return;
    setState(() => _ocupado = false);

    r.when(
      success: (codigo) => _mostrarCodigo(u, codigo),
      failure: (fallo) => mostrarAviso(context, fallo.message),
    );
  }

  void _mostrarCodigo(UsuarioAdmin u, CodigoRecuperacion c) {
    showDialog<void>(
      context: context,
      // No se cierra al tocar fuera: el código no se puede volver a consultar y
      // un toque accidental lo perdería.
      barrierDismissible: false,
      builder: (contexto) => AlertDialog(
        title: const Text('Código de restablecimiento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Para ${u.nombreCompleto} — ${c.email}'),
            const SizedBox(height: 16),
            SelectableText(
              c.codigo,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Entrégalo en persona o por el canal interno del centro. '
              'Caduca en 30 minutos y sólo sirve una vez.\n\n'
              'No se ha enviado por correo: esta pantalla es la única vez que el '
              'código es visible.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: c.codigo));
              if (contexto.mounted) {
                mostrarAviso(contexto, 'Código copiado.', exito: true);
              }
            },
            child: const Text('Copiar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _cambiarRol(UsuarioAdmin u) async {
    if (_ocupado) return;
    final nuevo = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoRol(actual: u.rol),
    );
    if (!mounted || nuevo == null || nuevo == u.rol) return;
    if (nuevo == 'admin') {
      final ok =
          await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Otorgar administrador'),
              content: Text(
                '${u.nombreCompleto} tendrá acceso completo al cPanel. ¿Continuar?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirmar'),
                ),
              ],
            ),
          ) ??
          false;
      if (!ok) return;
    }
    setState(() => _ocupado = true);
    final r = await _repo.cambiarRol(id: u.id, rol: nuevo);
    if (!mounted) return;
    setState(() => _ocupado = false);
    r.when(
      success: (_) {
        mostrarAviso(
          context,
          nuevo == 'admin'
              ? 'Administrador otorgado correctamente.'
              : 'Rol actualizado correctamente.',
          exito: true,
        );
        _cargar();
      },
      failure: (e) => mostrarAviso(context, e.message),
    );
  }

  Future<void> _cambiarEstado(UsuarioAdmin u, bool nuevoEstado) async {
    if (_ocupado) return;
    final accion = nuevoEstado ? 'activar' : 'desactivar (archivar)';
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('${nuevoEstado ? 'Activar' : 'Desactivar'} usuario'),
            content: Text(
              '¿Estás seguro de que deseas $accion la cuenta de ${u.nombreCompleto}?'
              '${!nuevoEstado ? '\n\nEl usuario no podrá iniciar sesión ni aparecerá en los selectores de docentes y estudiantes activos.' : ''}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    setState(() => _ocupado = true);
    final r = await _repo.cambiarEstado(id: u.id, activo: nuevoEstado);
    if (!mounted) return;
    setState(() => _ocupado = false);
    r.when(
      success: (_) {
        mostrarAviso(
          context,
          nuevoEstado
              ? 'Usuario activado correctamente.'
              : 'Usuario desactivado correctamente.',
          exito: true,
        );
        _cargar();
      },
      failure: (e) => mostrarAviso(context, e.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _pagina;
    final todos = p?.usuarios ?? const <UsuarioAdmin>[];
    final users = _ocultarCuentasDemo
        ? todos.where((u) => !u.esCuentaDemo).toList()
        : todos;
    final pages = ((p?.total ?? 0) / _limite).ceil();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const TituloSeccion(
          'Usuarios y Roles',
          subtitulo: 'Gestiona usuarios, roles y acceso administrativo.',
        ),
        const SizedBox(height: 16),
        _ResumenUsuarios(total: p?.total ?? 0, usuarios: users),
        const SizedBox(height: 16),
        if (_mostrarInvitacion) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(IncesTheme.radioControl),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.mark_email_read_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invitación de Profesores para Registro y Testing',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Puedes invitar a profesores ingresando sus datos abajo: el sistema envía un correo formal con el enlace de activación único (válido 48h). Una vez activada su cuenta, el docente podrá iniciar sesión para testing en el aula virtual y aparecerá en la tabla de usuarios registrados.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.4,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ExpansionTile(
          initiallyExpanded: true,
          title: const Text('Invitar docente'),
          subtitle: const Text(
            'Emite la invitación por correo electrónico. El enlace generado también queda listo para entrega directa o pruebas rápidas.',
          ),
          leading: const Icon(Icons.person_add_alt_1_outlined),
          children: [
            // Sin padding horizontal a propósito. El panel está dimensionado
            // para el ancho que le da `ContenidoSeccion`; recortarlo 16 px por
            // lado lo dejaba en 311 px a 375 de ventana y el formulario
            // desbordaba 5 px. El propio barrido responsive lo cazó.
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: CpanelInvitacionesPanel(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const AvisoEnLinea(
          texto: 'Para incorporar a otro administrador: invítalo arriba (entra '
              'como docente) y después usa «Cambiar rol» en su fila. El sistema '
              'no permite quedarse sin administradores.',
        ),
        const SizedBox(height: 16),
        ] else ...[
        // **La invitación es una acción, no el contenido por defecto.**
        // Medido el 2026-10-24: el panel se llamaba «Usuarios y Roles» pero
        // abría con el formulario de invitación ocupando toda la pantalla, y la
        // lista de usuarios —lo que se viene a hacer— quedaba debajo del pliegue.
        // Un panel de gestión abre con lo que gestiona; invitar se pide cuando
        // se quiere.
        Card(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          child: ListTile(
            leading: const Icon(Icons.person_add_alt_1_rounded),
            title: const Text('Invitar docente'),
            subtitle: const Text(
              'Emite una invitación por correo con enlace de activación.',
            ),
            trailing: FilledButton.tonal(
              onPressed: () => setState(() => _mostrarInvitacion = true),
              child: const Text('Invitar'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // **Barra de busqueda a todo el ancho, en su propia fila.**
                // Patron de Google (Material 3 SearchBar): el campo de texto
                // tiene su propia fila y los filtros van debajo, envueltos.
                // Medido el 2026-10-22: antes compartia fila con los
                // desplegables y habia dos copias de los filtros (estrecho/ancho).
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // `ListenableBuilder` para que el boton de limpiar aparezca
                    // y desaparezca sin hacer setState en cada tecla.
                    ListenableBuilder(
                      listenable: _busqueda,
                      builder: (context, _) => TextField(
                        controller: _busqueda,
                        onChanged: _buscar,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          labelText: 'Buscar usuario',
                          hintText: 'Nombre, correo o cedula',
                          suffixIcon: _busqueda.text.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Limpiar busqueda',
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _busqueda.clear();
                                    _buscar('');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              DropdownButton<String?>(
                                value: _rol,
                                hint: const Text('Todos los roles'),
                                items: const [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Todos los roles'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'admin',
                                    child: Text('Administradores'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'docente',
                                    child: Text('Docentes'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'estudiante',
                                    child: Text('Estudiantes'),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() {
                                    _rol = v;
                                    _paginaActual = 0;
                                  });
                                  _cargar();
                                },
                              ),
                              DropdownButton<bool?>(
                                value: _activo,
                                hint: const Text('Estado'),
                                items: const [
                                  DropdownMenuItem<bool?>(
                                    value: null,
                                    child: Text('Todos'),
                                  ),
                                  DropdownMenuItem(
                                    value: true,
                                    child: Text('Activos'),
                                  ),
                                  DropdownMenuItem(
                                    value: false,
                                    child: Text('Inactivos'),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() {
                                    _activo = v;
                                    _paginaActual = 0;
                                  });
                                  _cargar();
                                },
                              ),
                              IconButton(
                                onPressed: _cargando ? null : _cargar,
                                tooltip: 'Actualizar',
                                icon: const Icon(Icons.refresh),
                              ),
                              FilterChip(
                                label: const Text('Ocultar pruebas'),
                                selected: _ocultarCuentasDemo,
                                onSelected: (v) => setState(() => _ocultarCuentasDemo = v),
                              ),
                            ],
                          ),
                  ],
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: AvisoEnLinea(
                      tono: TonoAviso.peligro,
                      icono: Icons.error_outline,
                      texto: _error!,
                    ),
                  ),
                if (_cargando || _ocupado)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 12),
                if (users.isEmpty && !_cargando)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No hay usuarios que coincidan con los filtros.',
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Menos de 900 px de ancho: tarjetas, no tabla.
                      // El DataTable con celdas fijas (250 + 220 px mínimo)
                      // obligaba a hacer zoom al 80-90 % para verse completo —
                      // medido en la demo ante el Jefe de Centro, 2026-10-20. En
                      // ventana estrecha cada usuario es una tarjeta; en ancha
                      // sigue siendo tabla con scroll horizontal controlado.
                      if (constraints.maxWidth < 900) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: users
                              .map(
                                (u) => _TarjetaUsuario(
                                  usuario: u,
                                  onCambiarRol: () => _cambiarRol(u),
                                  onRestablecer: () => _restablecer(u),
                                  onCambiarEstado: () =>
                                      _cambiarEstado(u, !u.activo),
                                ),
                              )
                              .toList(),
                        );
                      }
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                      dataRowMinHeight: 68,
                      dataRowMaxHeight: 84,
                      columns: const [
                        DataColumn(label: Text('Usuario')),
                        DataColumn(label: Text('Correo')),
                        DataColumn(label: Text('Rol')),
                        DataColumn(label: Text('Estado')),
                        DataColumn(label: Text('Acciones')),
                      ],
                      rows: users
                          .map(
                            (u) => DataRow(
                              cells: [
                                DataCell(
                                  SizedBox(
                                    width: 250,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 17,
                                          backgroundColor: u.esCuentaDemo
                                              ? Theme.of(context).colorScheme.secondaryContainer
                                              : Theme.of(context).colorScheme.primaryContainer,
                                          child: Text(
                                            (u.nombres.isNotEmpty
                                                    ? u.nombres[0]
                                                    : (u.email.isNotEmpty ? u.email[0] : 'U'))
                                                .toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: u.esCuentaDemo
                                                  ? Theme.of(context).colorScheme.onSecondaryContainer
                                                  : Theme.of(context).colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                u.nombreCompleto,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              if (u.cedula != null && u.cedula!.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  'C.I. ${u.cedula}',
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                              if (u.esCuentaDemo) ...[
                                                const SizedBox(height: 2),
                                                const Etiqueta(
                                                  texto: 'Cuenta de demostración',
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 220,
                                    child: Text(
                                      u.email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(_RolChip(u.rol)),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: u.activo
                                              ? Colors.green.shade600
                                              : Colors.grey.shade500,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(u.activo ? 'Activo' : 'Inactivo'),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Cambiar rol',
                                        onPressed: () => _cambiarRol(u),
                                        icon: const Icon(
                                          Icons.manage_accounts_outlined,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Restablecer contraseña',
                                        onPressed: () => _restablecer(u),
                                        icon: const Icon(Icons.key_outlined),
                                      ),
                                      IconButton(
                                        tooltip: u.activo
                                            ? 'Desactivar usuario'
                                            : 'Activar usuario',
                                        onPressed: () => _cambiarEstado(u, !u.activo),
                                        icon: Icon(
                                          u.activo
                                              ? Icons.person_off_outlined
                                              : Icons.person_add_alt_outlined,
                                          color: u.activo
                                              ? Colors.amber.shade800
                                              : Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                        ),
                      );
                    },
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Página ${_paginaActual + 1} de ${pages < 1 ? 1 : pages}',
                    ),
                    IconButton(
                      onPressed: _paginaActual == 0 || _cargando
                          ? null
                          : () {
                              setState(() {
                                _paginaActual--;
                              });
                              _cargar();
                            },
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      onPressed:
                          _cargando || pages < 1 || _paginaActual + 1 >= pages
                          ? null
                          : () {
                              setState(() {
                                _paginaActual++;
                              });
                              _cargar();
                            },
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResumenUsuarios extends StatelessWidget {
  const _ResumenUsuarios({required this.usuarios, required this.total});
  final List<UsuarioAdmin> usuarios;
  final int total;
  @override
  Widget build(BuildContext c) {
    int n(String r) => usuarios.where((u) => u.rol == r).length;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children:
          [
                ['Usuarios', total, Icons.people_outline],
                [
                  'Administradores',
                  n('admin'),
                  Icons.admin_panel_settings_outlined,
                ],
                ['Docentes', n('docente'), Icons.school_outlined],
                ['Estudiantes', n('estudiante'), Icons.person_outline],
              ]
              .map(
                (x) => SizedBox(
                  width: 180,
                  child: Card(
                    child: Padding(
                      // **Fila propia en vez de `ListTile`.** Medido el
                      // 2026-10-23 a 390 px: el `ListTile` gasta 40 px de icono
                      // y 32 de padding, y a «Administradores» le quedaban ~80
                      // px: se partía en «Administrador» + «es». Con esta fila
                      // le sobran ~30 px y cabe entera.
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(x[2] as IconData, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  (x[1] as int).toString(),
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  x[0] as String,
                                  maxLines: 2,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: Theme.of(c)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }
}

class _RolChip extends StatelessWidget {
  const _RolChip(this.rol);
  final String rol;
  @override
  Widget build(BuildContext c) => Chip(
    label: Text(switch (rol) {
      'admin' => 'Administrador',
      'docente' => 'Docente',
      _ => 'Estudiante',
    }),
  );
}

class _DialogoRol extends StatefulWidget {
  const _DialogoRol({required this.actual});
  final String actual;
  @override
  State<_DialogoRol> createState() => _DialogoRolState();
}

class _DialogoRolState extends State<_DialogoRol> {
  late String rol;
  @override
  void initState() {
    super.initState();
    rol = widget.actual;
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: const Text('Cambiar rol'),
    content: DropdownButtonFormField<String>(
      initialValue: rol,
      items: const [
        DropdownMenuItem(value: 'admin', child: Text('Administrador')),
        DropdownMenuItem(value: 'docente', child: Text('Docente')),
        DropdownMenuItem(value: 'estudiante', child: Text('Estudiante')),
      ],
      onChanged: (v) {
        if (v != null) setState(() => rol = v);
      },
      decoration: const InputDecoration(labelText: 'Nuevo rol'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(c, rol),
        child: const Text('Guardar'),
      ),
    ],
  );
}

/// Tarjeta de un usuario para ventanas estrechas (< 900 px).
///
/// **Por qué existe.** La tabla fija no cabía sin zoom (demo del 2026-10-20);
/// esta tarjeta es la misma información apilada, con las tres acciones a un
/// toque. Comparte el contenido del `DataTable` para que ninguna de las dos
/// vistas sepa algo que la otra no muestre.
class _TarjetaUsuario extends StatelessWidget {
  const _TarjetaUsuario({
    required this.usuario,
    required this.onCambiarRol,
    required this.onRestablecer,
    required this.onCambiarEstado,
  });

  final UsuarioAdmin usuario;
  final VoidCallback onCambiarRol;
  final VoidCallback onRestablecer;
  final VoidCallback onCambiarEstado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: usuario.esCuentaDemo
                      ? theme.colorScheme.secondaryContainer
                      : theme.colorScheme.primaryContainer,
                  child: Text(
                    (usuario.nombres.isNotEmpty
                            ? usuario.nombres[0]
                            : (usuario.email.isNotEmpty
                                ? usuario.email[0]
                                : 'U'))
                        .toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: usuario.esCuentaDemo
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usuario.nombreCompleto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (usuario.cedula != null &&
                          usuario.cedula!.isNotEmpty)
                        Text(
                          'C.I. ${usuario.cedula}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                _RolChip(usuario.rol),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              usuario.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: usuario.activo
                        ? Colors.green.shade600
                        : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(width: 6),
                Text(usuario.activo ? 'Activo' : 'Inactivo'),
                if (usuario.esCuentaDemo) ...[
                  const SizedBox(width: 8),
                  const Etiqueta(texto: 'Cuenta de demostración'),
                ],
                const Spacer(),
                IconButton(
                  tooltip: 'Cambiar rol',
                  visualDensity: VisualDensity.compact,
                  onPressed: onCambiarRol,
                  icon: const Icon(Icons.manage_accounts_outlined),
                ),
                IconButton(
                  tooltip: 'Restablecer contraseña',
                  visualDensity: VisualDensity.compact,
                  onPressed: onRestablecer,
                  icon: const Icon(Icons.key_outlined),
                ),
                IconButton(
                  tooltip: usuario.activo
                      ? 'Desactivar usuario'
                      : 'Activar usuario',
                  visualDensity: VisualDensity.compact,
                  onPressed: onCambiarEstado,
                  icon: Icon(
                    usuario.activo
                        ? Icons.person_off_outlined
                        : Icons.person_add_alt_outlined,
                    color: usuario.activo
                        ? Colors.amber.shade800
                        : Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
