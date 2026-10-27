import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/tema_provider.dart';
import '../core/refresco_secciones.dart';
import '../repositories/modulo_repository.dart';
import '../services/auth_service.dart';
import '../theme/inces_theme.dart';
import '../widgets/andamiaje.dart';
import '../widgets/barra_acciones_superiores.dart';
import '../widgets/comunes.dart';
import '../widgets/modulos_del_menu.dart';
import 'admin/admin_resumen_panel.dart';
import 'admin/cpanel_auditoria_accesos_panel.dart';
import 'admin/cpanel_auditoria_panel.dart';
import 'admin/cpanel_modulos_panel.dart';
import 'admin/cpanel_parametros_panel.dart';
import 'admin/cpanel_usuarios_roles_panel.dart';
import 'admin/cpanel_programas_panel.dart';
// Los cuatro paneles de M3, juntos: aulas y lapsos son **prerrequisitos** del
// cuadrante, y guardias comparte su rejilla. Se importan los tres últimos
// porque hasta ahora no los importaba nadie — ver la nota de `_items`.
import 'admin/cpanel_aulas_panel.dart';
import 'admin/cpanel_cuadrante_panel.dart';
import 'admin/cpanel_guardias_panel.dart';
import 'admin/cpanel_pna_panel.dart';
import 'admin/cpanel_lapsos_panel.dart';
import 'admin/cpanel_inscripcion_campos_panel.dart';
import 'admin/cpanel_inscripciones_panel.dart';
import 'admin/cpanel_secciones_panel.dart';
import 'admin/cpanel_explorador_archivos_panel.dart';
import '../widgets/walkthrough_interactivo.dart';
import '../widgets/guardia_toque.dart';
import 'perfil_panel.dart';

/// cPanel del Administrador Maestro.
///
/// ## Qué cambió respecto a la versión anterior
///
/// Antes era un `Row` con una lista de secciones y un `IndexedStack`. Funcionaba,
/// pero se presentaba como un formulario: había que leer cada etiqueta para
/// saber qué se podía hacer. Ahora la estructura es la de un panel de control:
///
///  · El menú agrupa por **categoría con sentido para el usuario**
///    (*Gestión Académica*, *Control de Aulas*, *Administración del Sistema*) en
///    lugar de una lista plana. La categoría responde a «¿qué estoy intentando
///    hacer?», que es como piensa quien administra un centro.
///  · Las **migas de pan** y el **encabezado con rol y período** dan contexto
///    permanente. Antes, la única señal de dónde estabas era el título.
///  · Las secciones sin construir se marcan con un icono y **no son pulsables**.
///    Antes se podía entrar a una pantalla que sólo decía «pendiente», lo que
///    hace dudar de si la aplicación está rota.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, this.auth, this.modulos});

  final AuthService? auth;

  /// De dónde sale el estado de `system_modules` que gobierna el menú.
  ///
  /// Aquí no es una comodidad: este panel es el que **enciende y apaga** los
  /// módulos, y hasta ahora el menú no lo sabía. Opcional **sólo para las
  /// pruebas**; en producción se resuelve [ModuloRepository].
  final ModuloRepository? modulos;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with CargaDeModulos<AdminDashboardScreen> {
  late final AuthService _auth = widget.auth ?? AuthService();

  late final ModuloRepository _modulosRepo =
      widget.modulos ?? ModuloRepository();

  @override
  ModuloRepository get repositorioDeModulos => _modulosRepo;

  int _seleccionada = 0;
  final Map<String, Widget> _panelesCargados = {};

  /// Las secciones, con su categoría.
  ///
  /// El orden de esta lista es el orden del menú: primero lo construido —que es
  /// a lo que se entra—, y después lo planificado. Al revés, tres de cada cuatro
  /// clics caerían en una sección que no existe.
  static const List<ItemNavegacion> _items = [
    // 1. Preparar el período
    ItemNavegacion(
      icono: Icons.dashboard_customize_outlined,
      titulo: 'Centro de Mando',
      etiquetaCorta: 'Inicio',
      categoria: 'Preparar el período',
      modulo: 'm0_cpanel',
    ),
    ItemNavegacion(
      icono: Icons.event_note_outlined,
      titulo: 'Período',
      etiquetaCorta: 'Período',
      categoria: 'Preparar el período',
      disponible: true,
      modulo: 'm3_cuadrante',
    ),
    ItemNavegacion(
      icono: Icons.menu_book_outlined,
      titulo: 'Programas Académicos',
      etiquetaCorta: 'Programas',
      categoria: 'Preparar el período',
      modulo: 'm2_curriculo',
    ),
    ItemNavegacion(
      icono: Icons.class_outlined,
      titulo: 'Secciones del Período',
      etiquetaCorta: 'Secciones',
      categoria: 'Preparar el período',
      disponible: true,
      modulo: 'm3_cuadrante',
    ),
    ItemNavegacion(
      icono: Icons.settings_outlined,
      titulo: 'Configuración del Centro',
      etiquetaCorta: 'Ajustes',
      categoria: 'Preparar el período',
      modulo: 'm0_cpanel',
    ),
    ItemNavegacion(
      icono: Icons.tune_outlined,
      titulo: 'Módulos del Sistema',
      etiquetaCorta: 'Módulos',
      categoria: 'Preparar el período',
      modulo: 'm0_cpanel',
    ),

    // 2. Inscribir
    ItemNavegacion(
      icono: Icons.confirmation_number_outlined,
      titulo: 'Inscripciones y Cupos',
      etiquetaCorta: 'Inscripciones',
      categoria: 'Inscribir',
      disponible: true,
      modulo: 'm4_inscripciones',
    ),
    ItemNavegacion(
      icono: Icons.edit_note_outlined,
      titulo: 'Campos de Inscripción',
      etiquetaCorta: 'Planilla',
      categoria: 'Inscribir',
      disponible: true,
      modulo: 'm4_inscripciones',
    ),

    // 3. Dar clase
    ItemNavegacion(
      icono: Icons.calendar_month_outlined,
      titulo: 'Cuadrante de Horarios',
      etiquetaCorta: 'Horarios',
      categoria: 'Dar clase',
      disponible: true,
      modulo: 'm3_cuadrante',
    ),
    ItemNavegacion(
      icono: Icons.school_outlined,
      titulo: 'Horario PNA',
      etiquetaCorta: 'PNA',
      categoria: 'Dar clase',
      disponible: true,
      modulo: 'm3_cuadrante',
    ),
    ItemNavegacion(
      icono: Icons.shield_outlined,
      titulo: 'Guardias Docentes',
      etiquetaCorta: 'MTP',
      categoria: 'Dar clase',
      disponible: true,
      modulo: 'm3_cuadrante',
    ),
    ItemNavegacion(
      icono: Icons.meeting_room_outlined,
      titulo: 'Espacios y Aulas',
      etiquetaCorta: 'Espacios',
      categoria: 'Dar clase',
      disponible: true,
      modulo: 'm3_cuadrante',
    ),

    // 4. Archivos
    ItemNavegacion(
      icono: Icons.folder_shared_outlined,
      titulo: 'Archivos del Centro',
      etiquetaCorta: 'Archivos',
      categoria: 'Archivos',
      disponible: true,
      modulo: 'm0_cpanel',
    ),

    // 5. Personas
    ItemNavegacion(
      icono: Icons.people_outline,
      titulo: 'Usuarios y Roles',
      etiquetaCorta: 'Usuarios',
      categoria: 'Personas',
      modulo: 'm1_onboarding',
    ),

    // 6. Registro de accesos
    ItemNavegacion(
      icono: Icons.history_outlined,
      titulo: 'Historial de Configuración',
      etiquetaCorta: 'Historial',
      categoria: 'Registro de accesos',
      modulo: 'm0_cpanel',
    ),
    ItemNavegacion(
      icono: Icons.fingerprint_outlined,
      titulo: 'Registro de Inicios de Sesión / Accesos',
      etiquetaCorta: 'Accesos',
      categoria: 'Registro de accesos',
      modulo: 'm0_cpanel',
    ),

    // 7. Mi cuenta
    ItemNavegacion(
      icono: Icons.account_circle_outlined,
      titulo: 'Mi Perfil',
      etiquetaCorta: 'Perfil',
      categoria: 'Mi cuenta',
      disponible: true,
    ),
  ];

  /// Período mostrado en el encabezado.
  ///
  /// Está escrito a mano a propósito y **no** leído de `system_settings`: ese
  /// parámetro existe (`periodo_activo`), pero leerlo aquí obligaría al
  /// dashboard a cargar todo el catálogo de parámetros antes de pintar. Cuando
  /// se construya el módulo de currículo, el período pasará a ser una selección
  /// real; hasta entonces un valor fijo comunica mejor que un hueco.
  /// El lapso vigente es `SA26-2` (ver system_settings.periodo_activo, fijado por
  /// la migración 202609180003). Cuando el módulo de currículo lo lea de ahí, este
  /// literal desaparece.
  static const String _periodoActivo = 'SA26-2';

  Future<void> _cerrarSesion() async {
    await _auth.cerrarSesion();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushReplacementNamed('/login');
  }

  void _navegarA(String destino) {
    final idx = _items.indexWhere(
      (it) =>
          it.titulo.toLowerCase() == destino.toLowerCase() ||
          it.titulo.toLowerCase().contains(destino.toLowerCase()) ||
          (destino.toLowerCase().contains('auditor') &&
              it.titulo.toLowerCase().contains('configuraci')) ||
          (destino.toLowerCase().contains('accesos') &&
              it.titulo.toLowerCase().contains('accesos')) ||
          (destino.toLowerCase().contains('cuadrante') &&
              it.titulo.toLowerCase().contains('horarios')),
    );
    if (idx != -1) {
      setState(() {
        _seleccionada = idx;
        // **Aviso de cambio de seccion.** Los paneles que mezclan
        // `RefrescoAlVolver` recargan en segundo plano si sus datos pasaron del
        // umbral: volver a una seccion es instantaneo, pero no muestra datos
        // viejos.
        RefrescoSecciones.notificar(menuConModulos(_items)[idx].titulo);
      });
    }
  }

  String get _tituloSeccion => _items[_seleccionada].titulo;

  @override
  Widget build(BuildContext context) {
    // Nulable a propósito: el panel se monta en pruebas sin proveedor de tema
    // —`aula_produccion_test.dart`, `menu_gobernado_por_modulos_test.dart`— y
    // ahí no hay ninguno. `provider` encuentra el proveedor cuando existe y
    // devuelve `null` cuando no, así que el mismo código sirve en la aplicación
    // y en la prueba. Con el tipo no nulable, esas pruebas fallarían al montar.
    final tema = context.watch<TemaProvider?>();

    return AndamiajeApp(
      // `menuConModulos` y no `_items`: el menú sale con el estado real de
      // `system_modules` aplicado encima. Apagar un módulo desde este mismo
      // panel —la sección de arriba— se refleja aquí.
      items: menuConModulos(_items),
      seleccionado: _seleccionada,
      onSeleccionar: (indice) {
        setState(() => _seleccionada = indice);
        RefrescoSecciones.notificar(menuConModulos(_items)[indice].titulo);
      },
      rolEtiqueta: 'Administrador Maestro',
      correoUsuario: _auth.emailActual,
      periodoActivo: _periodoActivo,
      onCerrarSesion: _cerrarSesion,
      temaActual: tema?.modo,
      onCambiarTema: tema?.cambiar,
      accionesEncabezado: [
        IconButton(
          tooltip: 'Inscripciones y Cupos',
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
          onPressed: () => conGuardia(() => _navegarA('Inscripciones y Cupos'), 'nav-Inscripciones y Cupos'),
        ),
        IconButton(
          tooltip: 'Cuadrante de Horarios',
          icon: const Icon(Icons.calendar_month_rounded, size: 20),
          onPressed: () => conGuardia(() => _navegarA('Cuadrante de Horarios'), 'nav-Cuadrante de Horarios'),
        ),
        IconButton(
          tooltip: 'Espacios y Aulas',
          icon: const Icon(Icons.meeting_room_outlined, size: 20),
          onPressed: () => conGuardia(() => _navegarA('Espacios y Aulas'), 'nav-Espacios y Aulas'),
        ),
        IconButton(
          tooltip: 'Guía Interactiva (Walkthrough)',
          icon: const Icon(Icons.help_outline_rounded, size: 20),
          onPressed: () => conGuardia(
            () => WalkthroughInteractivoCard.mostrarModal(
              context,
              rol: RolWalkthrough.admin,
              onNavegarA: _navegarA,
            ),
            'walkthrough-admin',
          ),
        ),
        IconButton(
          tooltip: 'Generar Reporte',
          icon: const Icon(Icons.summarize_outlined, size: 20),
          onPressed: () => conGuardia(
            () => BarraAccionesSuperiores.mostrarDialogoReportes(
              context,
              onVerInscripciones: () => _navegarA('Inscripciones y Cupos'),
              onVerHorarios: () => _navegarA('Cuadrante de Horarios'),
              onVerAccesos: () =>
                  _navegarA('Registro de Inicios de Sesión / Accesos'),
            ),
            'reportes-admin',
          ),
          ),
      ],
      contenido: _contenido(),
    );
  }

  Widget _contenido() {
    final item = menuConModulos(_items)[_seleccionada];

    // Alcanzable sólo si el módulo se apagó **después** de entrar: el menú ya no
    // deja pulsar una sección apagada, así que esto no viene de un clic sino de
    // un estado que cambió. Sin esta guarda el menú diría «apagado» y el
    // contenido seguiría pintando el panel del módulo apagado — peor que no
    // poder entrar, porque parece que la decisión del administrador no sirvió.
    if (!item.disponible) {
      return ContenidoSeccion(
        migas: ['Inicio', item.categoria, item.titulo],
        child: PanelVacio(
          titulo: item.titulo,
          mensaje: item.pendiente ?? 'Esta sección no está disponible.',
          icono: item.icono,
        ),
      );
    }

    _panelesCargados.putIfAbsent(item.titulo, () {
      switch (item.titulo) {
        case 'Centro de Mando':
          return ContenidoSeccion(
            migas: const ['Inicio', 'Administración del sistema', 'Centro de Mando'],
            child: SingleChildScrollView(
              child: AdminResumenPanel(
                repositorioModulos: _modulosRepo,
                onNavegarA: _navegarA,
              ),
            ),
          );
        case 'Módulos del Sistema':
          return ContenidoSeccion(
            migas: const ['Inicio', 'Administración del sistema', 'Módulos'],
            child: CpanelModulosPanel(
              onNavegarA: _navegarA,
              mostrarResumenEjecutivo: false,
            ),
          );
        case 'Configuración del Centro':
          return const ContenidoSeccion(
            migas: ['Inicio', 'Administración del sistema', 'Configuración del Centro'],
            child: CpanelParametrosPanel(),
          );
        case 'Historial de Configuración':
          return const ContenidoSeccion(
            migas: ['Inicio', 'Administración del sistema', 'Historial de Configuración'],
            child: CpanelAuditoriaPanel(),
          );
        case 'Registro de Inicios de Sesión / Accesos':
          return const ContenidoSeccion(
            migas: ['Inicio', 'Administración del sistema', 'Accesos'],
            child: CpanelAuditoriaAccesosPanel(),
          );
        case 'Usuarios y Roles':
          return const ContenidoSeccion(
            migas: ['Inicio', 'Administración del sistema', 'Usuarios y Roles'],
            child: CpanelUsuariosRolesPanel(),
          );
        case 'Programas Académicos':
          return const ContenidoSeccion(
            migas: ['Inicio', 'Gestión académica', 'Programas Académicos'],
            child: CpanelProgramasPanel(),
          );
        case 'Inscripciones y Cupos':
          return ContenidoSeccion(
            migas: const ['Inicio', 'Gestión académica', 'Inscripciones y Cupos'],
            child: CpanelInscripcionesPanel(onNavegarA: _navegarA),
          );
        case 'Campos de Inscripción':
          return ContenidoSeccion(
            migas: const ['Inicio', 'Gestión académica', 'Campos de Inscripción'],
            child: CpanelInscripcionCamposPanel(onNavegarA: _navegarA),
          );
        case 'Secciones del Período':
          return const ContenidoSeccion(
            migas: ['Inicio', 'Gestión académica', 'Secciones del Período'],
            child: CpanelSeccionesPanel(),
          );
        case 'Período':
          return const ContenidoSeccion(
            migas: ['Inicio', 'Gestión académica', 'Período'],
            child: CpanelLapsosPanel(),
          );
        case 'Archivos del Centro':
          return const ContenidoSeccion(
            migas: ['Inicio', 'Gestión académica', 'Archivos del Centro'],
            child: CpanelExploradorArchivosPanel(),
          );
        case 'Cuadrante de Horarios':
          return ContenidoSeccion(
            migas: const ['Inicio', 'Control de aulas', 'Cuadrante de Horarios'],
            child: CpanelCuadrantePanel(onNavegarA: _navegarA),
          );
        case 'Horario PNA':
          return ContenidoSeccion(
            migas: const ['Inicio', 'Control de aulas', 'Horario PNA'],
            child: CpanelPnaPanel(onNavegarA: _navegarA),
          );
        case 'Espacios y Aulas':
          return ContenidoSeccion(
            migas: const ['Inicio', 'Control de aulas', 'Espacios'],
            child: CpanelAulasPanel(onNavegarA: _navegarA),
          );
        case 'Guardias Docentes':
          return ContenidoSeccion(
            migas: const ['Inicio', 'Control de aulas', 'Guardias'],
            child: CpanelGuardiasPanel(onNavegarA: _navegarA),
          );
        case 'Mi Perfil':
          return const ContenidoSeccion(
            migas: ['Inicio', 'Mi cuenta', 'Mi Perfil'],
            child: PerfilPanel(),
          );
        default:
          return Padding(
            padding: const EdgeInsets.all(24),
            child: MigasDePan(partes: ['Inicio', _tituloSeccion]),
          );
      }
    });

    return Stack(
      children: [
        for (final entry in _panelesCargados.entries)
          Offstage(
            offstage: entry.key != item.titulo,
            child: TickerMode(
              enabled: entry.key == item.titulo,
              child: entry.value,
            ),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
//  Tarjetas y rejillas del panel
// -----------------------------------------------------------------------------

/// Rejilla adaptativa de tarjetas.
///
/// El número de columnas se calcula por ancho disponible y no por un `breakpoint`
/// fijo: así funciona en móvil, tableta y monitor sin tres ramas distintas.
class RejillaTarjetas extends StatelessWidget {
  const RejillaTarjetas({
    super.key,
    required this.children,
    this.anchoMinimo = 260,
    this.espaciado = 16,
  });

  final List<Widget> children;
  final double anchoMinimo;
  final double espaciado;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        final columnas = (restricciones.maxWidth / anchoMinimo)
            .floor()
            .clamp(1, 4);

        return Wrap(
          spacing: espaciado,
          runSpacing: espaciado,
          children: [
            for (final hijo in children)
              SizedBox(
                // Se resta el espaciado que consumen los huecos entre columnas,
                // no sólo el ancho de las tarjetas: sin eso la última columna
                // desborda por unos píxeles y el `Wrap` baja una tarjeta de más.
                width: (restricciones.maxWidth -
                        (espaciado * (columnas - 1))) /
                    columnas,
                child: hijo,
              ),
          ],
        );
      },
    );
  }
}

/// Métricas rápidas del panel de módulos.
///
/// Se calcula aquí, a partir de la lista cargada, en lugar de pedir un endpoint
/// de estadísticas: son cuatro cifras derivadas de datos que ya están en
/// memoria, y una petición extra para contarlos sería trabajo redundante.
///
/// La cuarta tarjeta no es «Protegidos» sino **«Auditoría hoy»**, y no es un
/// capricho: el requisito del Command Center pedía cuatro cifras de un vistazo,
/// y las otras tres (totales, activos, apagados) se derivan del mismo dato, así
/// que una cuarta del mismo tipo no añadía nada. `Últimos cambios` sí aporta:
/// responde a «¿alguien tocó algo últimamente?», que es la pregunta que se hace
/// al abrir el panel sospechando un problema.
class MetricasModulos extends StatelessWidget {
  const MetricasModulos({
    super.key,
    required this.total,
    required this.activos,
    required this.criticos,
    required this.cambiosRecientes,
  });

  final int total;
  final int activos;

  /// Módulos con candado (hoy, sólo `m0_cpanel`). Se muestra en el subtítulo de
  /// la tarjeta de protegidos.
  final int criticos;

  /// Cambios de configuración registrados en la auditoría reciente.
  final int cambiosRecientes;

  @override
  Widget build(BuildContext context) {
    return RejillaTarjetas(
      anchoMinimo: 200,
      children: [
        TarjetaMetrica(
          etiqueta: 'Módulos totales',
          valor: '$total',
          icono: Icons.widgets_outlined,
        ),
        TarjetaMetrica(
          etiqueta: 'Activos',
          valor: '$activos',
          icono: Icons.toggle_on_outlined,
          tono: TonoEstado.exito,
        ),
        // «Apagados» usaba `paleta.textoApagado` y ahora usa el tono neutro: son
        // el mismo valor en los dos brillos, y un tono no puede equivocarse de
        // contrato —el gris apagado es un rol de texto, no de chip—.
        TarjetaMetrica(
          etiqueta: 'Apagados',
          valor: '${total - activos}',
          icono: Icons.toggle_off_outlined,
          tono: TonoEstado.neutro,
        ),
        TarjetaMetrica(
          etiqueta: 'Auditoría hoy',
          valor: '$cambiosRecientes',
          icono: Icons.history_outlined,
          tono: TonoEstado.error,
        ),
      ],
    );
  }
}
