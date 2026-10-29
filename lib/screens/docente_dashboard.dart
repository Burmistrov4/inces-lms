import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/gateways/aula_gateway.dart';
import '../models/archivo.dart';
import '../providers/tema_provider.dart';
import '../repositories/modulo_repository.dart';
import '../services/auth_service.dart';
import '../services/aula_service.dart';
import '../widgets/andamiaje.dart';
import '../widgets/comunes.dart';
import '../widgets/modulos_del_menu.dart';
import 'docente/asistencia_qr_panel.dart';
import 'docente/docente_calificaciones_panel.dart';
import 'gestor_documental_panel.dart';
import 'mi_horario_panel.dart';
import 'mis_aulas_panel.dart';
import '../widgets/walkthrough_interactivo.dart';
import '../widgets/guardia_toque.dart';

/// Panel del docente.
///
/// Comparte el andamiaje con el panel del administrador —mismo encabezado,
/// mismo menú, mismas migas— en lugar de montar su propio `Scaffold`. Es lo que
/// hace que la aplicación se lea como **una** plataforma con distintos permisos,
/// y no como pantallas sueltas cosidas.
///
/// Las secciones apagadas se muestran atenuadas y **no pulsables**, y su tooltip
/// explica por qué: así quien usa el panel entiende qué falta, en vez de
/// sospechar que la aplicación está rota.
///
/// Ese tooltip era **genérico** —«pendiente de construir»— y sobre
/// «Calificaciones» era, además, **falso**: calificar existe desde M6 y está a
/// un clic, dentro de cada aula (`aula_virtual_dashboard.dart`, botón
/// «Calificar» de cada tarea). El texto sale ahora de `ItemNavegacion.pendiente`
/// y para esa sección dice dónde está. Una sección gris sin explicación no se
/// distingue de una plataforma incompleta, y el docente que la mira concluye que
/// el sistema no califica.
class DocenteDashboardScreen extends StatefulWidget {
  const DocenteDashboardScreen({
    super.key,
    this.auth,
    this.aulaGateway,
    this.aulasPropias,
    this.modulos,
  });

  final AuthService? auth;

  /// De dónde sale el estado de `system_modules` que gobierna el menú.
  ///
  /// Opcional **sólo para las pruebas**, como el resto de puertas de este
  /// dashboard: en producción no se inyecta y se resuelve [ModuloRepository], que
  /// lee por PostgREST. Ver `lib/widgets/modulos_del_menu.dart` para por qué esa
  /// lectura la puede hacer un docente y no sólo un administrador.
  final ModuloRepository? modulos;

  /// La puerta del **contenido** del Aula Virtual (M6).
  ///
  /// Opcional **sólo para las pruebas**: en producción no se inyecta y el
  /// dashboard cae al servicio real (ver [_aulaContenido]). Se inyecta cuando una
  /// prueba quiere un doble en lugar de la red, o cuando quiere el listado **sin**
  /// aula abrible —para eso último basta con inyectar [aulasPropias] y dejar esta
  /// en `null`—.
  final AulaGateway? aulaGateway;

  /// De dónde sale el listado de secciones de «Aulas Virtuales».
  ///
  /// Opcional para las pruebas. Sin él se usa [BackendAulaGateway], que lee
  /// `GET /api/v1/mi-horario`: es la misma ruta que alimenta «Mi horario», y
  /// para un docente trae sus secciones además de sus guardias. Las guardias
  /// **no** se listan como aulas: una guardia es una presencia de custodia, no
  /// una clase con tablón ni trabajo de clase.
  final AulasPropiasGateway? aulasPropias;

  @override
  State<DocenteDashboardScreen> createState() => _DocenteDashboardScreenState();
}

class _DocenteDashboardScreenState extends State<DocenteDashboardScreen>
    with CargaDeModulos<DocenteDashboardScreen> {
  late final AuthService _auth = widget.auth ?? AuthService();

  /// El estado real de `system_modules`, para que el menú no afirme que hay una
  /// sección al otro lado cuando el administrador apagó su módulo.
  late final ModuloRepository _modulosRepo =
      widget.modulos ?? ModuloRepository();

  @override
  ModuloRepository get repositorioDeModulos => _modulosRepo;

  /// El listado de aulas de «Aulas Virtuales».
  ///
  /// Cae al gateway de contenido cuando se inyecta —un [AulaGateway] **es** un
  /// [AulasPropiasGateway], así que vale como fuente del listado— y si no, a la
  /// implementación real contra `/mi-horario`.
  late final AulasPropiasGateway _aulasPropias =
      widget.aulasPropias ?? widget.aulaGateway ?? BackendAulaGateway();

  /// La puerta del **contenido** del aula que recibe `PanelMisAulas`.
  ///
  /// Es lo que hace que en producción —sin inyectar nada— la tarjeta del aula se
  /// pueda pulsar. **No es `widget.aulaGateway ?? BackendAulaGateway()`**: ver
  /// [resolverPuertaDeContenido], que explica por qué ese `??` rompería las
  /// pruebas de widget que piden un listado sin aula abrible.
  late final AulaGateway? _aulaContenido = resolverPuertaDeContenido(
    inyectada: widget.aulaGateway,
    listadoInyectado: widget.aulasPropias,
  );

  int _seleccionada = 0;
  final Map<String, Widget> _panelesCargados = {};

  static const List<ItemNavegacion> _items = [
    ItemNavegacion(
      icono: Icons.dashboard_outlined,
      titulo: 'Aulas Virtuales',
      etiquetaCorta: 'Aulas',
      categoria: 'Control de aulas',
      modulo: 'm6_aula_virtual',
    ),
    ItemNavegacion(
      icono: Icons.fact_check_outlined,
      titulo: 'Pasar lista',
      etiquetaCorta: 'Lista',
      categoria: 'Control de aulas',
      disponible: true,
      modulo: 'm7_asistencia',
    ),
    ItemNavegacion(
      icono: Icons.grading_outlined,
      titulo: 'Calificaciones',
      etiquetaCorta: 'Notas',
      categoria: 'Control de aulas',
      disponible: true,
      modulo: 'm6_aula_virtual',
    ),
    ItemNavegacion(
      icono: Icons.folder_open_outlined,
      titulo: 'Guías y materiales',
      etiquetaCorta: 'Guías',
      categoria: 'Recursos',
      disponible: true,
      modulo: 'm5_archivos',
    ),
    ItemNavegacion(
      icono: Icons.calendar_month_outlined,
      titulo: 'Mi horario',
      categoria: 'Recursos',
      disponible: true,
      modulo: 'm3_cuadrante',
    ),
  ];

  static const String _periodoActivo = 'SA26-2';

  Future<void> _cerrarSesion() async {
    await _auth.cerrarSesion();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushReplacementNamed('/login');
  }

  /// Nombres anteriores de una sección, para que un renombrado no deje muerta
  /// una navegación interna.
  ///
  /// **Por qué existe.** Medido el 2026-10-29: cuando «Mis aulas» pasó a
  /// «Aulas Virtuales», tres accesos del propio panel siguieron llamando con el
  /// nombre viejo. [_navegarA] no los encuentra y **no hace nada, en silencio**
  /// —sin error, sin log, sin cambio de pantalla—, que es la peor forma de
  /// romper un botón: parece que no responde el gesto. El alias convierte ese
  /// no-op mudo en el destino correcto mientras queden llamadores antiguos.
  static const Map<String, String> _aliasDeNavegacion = {
    'Mis aulas': 'Aulas Virtuales',
  };

  void _navegarA(String destino) {
    final buscado = (_aliasDeNavegacion[destino] ?? destino).toLowerCase();
    final idx = _items.indexWhere(
      (it) =>
          it.titulo.toLowerCase() == buscado ||
          it.titulo.toLowerCase().contains(buscado),
    );
    if (idx != -1) {
      setState(() => _seleccionada = idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nulable a propósito: `aula_produccion_test.dart` y
    // `menu_gobernado_por_modulos_test.dart` montan este panel sin proveedor de
    // tema, y el panel tiene que seguir montándose. Ver el comentario
    // equivalente en `admin_dashboard.dart`.
    final tema = context.watch<TemaProvider?>();

    return AndamiajeApp(
      // `menuConModulos` y no `_items`: el menú sale con el estado real de
      // `system_modules` aplicado encima, así que apagar `m6_aula_virtual` o
      // `m7_asistencia` desde el cPanel se refleja aquí en vez de llevar a un
      // 403.
      items: menuConModulos(_items),
      seleccionado: _seleccionada,
      onSeleccionar: (indice) => setState(() => _seleccionada = indice),
      rolEtiqueta: 'Docente',
      correoUsuario: _auth.emailActual,
      periodoActivo: _periodoActivo,
      onCerrarSesion: _cerrarSesion,
      temaActual: tema?.modo,
      onCambiarTema: tema?.cambiar,
      accionesEncabezado: [
        // **Sólo dos atajos, y ninguno duplica el menú.** Aquí había cuatro
        // iconos —Mis aulas, Asistencia, Calificaciones, Mi horario— que
        // repetían lo que ya ofrece el menú lateral, el rail y, en móvil, la
        // barra inferior de `AndamiajeApp`: cinco destinos compitiendo por el
        // mismo ancho en una pantalla de 390 px. Se deja el acceso a la
        // planilla de asistencia —la acción de clase que no puede esperar a
        // abrir el cajón— y la ayuda, que no es una sección.
        IconButton(
          tooltip: 'Pasar lista',
          icon: const Icon(Icons.fact_check_outlined, size: 20),
          onPressed: () => conGuardia(() => _navegarA('Pasar lista'), 'nav-Pasar lista'),
        ),
        IconButton(
          tooltip: 'Guía Interactiva Docente',
          icon: const Icon(Icons.help_outline_rounded, size: 20),
          onPressed: () => conGuardia(
            () => WalkthroughInteractivoCard.mostrarModal(
              context,
              rol: RolWalkthrough.docente,
              onNavegarA: _navegarA,
            ),
            'walkthrough-docente',
          ),
        ),
      ],
      contenido: _contenido(),
    );
  }

  /// Contenido de la sección seleccionada.
  ///
  /// **`switch` por TÍTULO y no por índice**, igual que el cPanel. El índice ata
  /// la rama a la POSICIÓN del ítem: insertar una sección en medio desplaza
  /// todas las siguientes y el `case 3` pasa a abrir otro panel sin que nada
  /// avise. Con el título, mover un ítem no cambia a dónde lleva.
  ///
  /// Es además lo que permite que `test/menu_alcanzable_test.dart` compruebe el
  /// contrato leyendo este archivo: compara las ramas `case 'X'` con las
  /// secciones que tienen `disponible: true`, y esa comparación sólo se puede
  /// hacer si las ramas nombran los títulos. Es la red que faltaba cuando R-22.
  ///
  /// La lista que se consulta aquí es la **efectiva** —con los módulos
  /// aplicados—, no `_items`: si el administrador apaga un módulo mientras el
  /// docente está dentro de esa sección, el contenido tiene que dejar de
  /// pintarse. El menú ya no deja volver a pulsarla, pero quedarse dentro es
  /// posible, y pintar el panel de un módulo apagado haría parecer que el
  /// interruptor no sirvió.
  Widget _contenido() {
    final item = menuConModulos(_items)[_seleccionada];

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
        case 'Aulas Virtuales':
          // El Aula Virtual (M6) es el destino de la primera sección. El listado
          // de secciones es real —sale de `/mi-horario`, la misma ruta que
          // alimenta «Mi horario»— y cada tarjeta abre el tablón y el trabajo de
          // clase de esa sección.
          //
          // **La rama y el título del menú se renombran juntos o no se renombra
          // ninguno.** Medido el 2026-10-29: el Lote 5 cambió el título a
          // «Aulas Virtuales» y dejó esta rama como `case 'Mis aulas'`, así que
          // el `switch` caía en el `default` y el docente veía «Esta sección
          // está pendiente de construir» en su primer apartado. Lo cazaron seis
          // pruebas (`aula_produccion`, `menu_alcanzable` y
          // `menu_gobernado_por_modulos`); ninguna prueba de panel lo habría
          // visto, porque el panel estaba bien: lo que faltaba era la puerta.
          //
          // `_aulaContenido` —y no `widget.aulaGateway`— es lo que hace que en
          // producción la tarjeta se pueda pulsar: sin inyectar nada resuelve el
          // servicio real, y con algo inyectado respeta lo que pidió la prueba.
          return PanelMisAulas(
            gateway: _aulasPropias,
            aulaGateway: _aulaContenido,
            onNavegarA: _navegarA,
            // El título del panel sigue al del menú: si el menú dice «Aulas
            // Virtuales», el encabezado y las migas no pueden decir «Mis aulas».
            titulo: item.titulo,
          );

        case 'Pasar lista':
          return ContenidoSeccion(
            migas: ['Inicio', item.categoria, item.titulo],
            child: const AsistenciaQrPanel(),
          );

        case 'Calificaciones':
          return ContenidoSeccion(
            migas: ['Inicio', item.categoria, item.titulo],
            child: DocenteCalificacionesPanel(
              gateway: _aulasPropias,
              aulaGateway: _aulaContenido,
              onNavegarA: _navegarA,
            ),
          );

        case 'Mi horario':
          return ContenidoSeccion(
            migas: ['Inicio', item.categoria, item.titulo],
            child: MiHorarioPanel(),
          );

        case 'Guías y materiales':
          return ContenidoSeccion(
            migas: ['Inicio', item.categoria, item.titulo],
            child: const GestorDocumentalPanel(
              entityType: TipoEntidadArchivo.teacherGuide,
              subtitulo: 'Sube guías y material para tus estudiantes. Lo que '
                  'subas aquí lo ven ellos en su sección «Material de apoyo» '
                  'del panel de aprendiz, y queda guardado en el almacenamiento '
                  'del centro.',
            ),
          );

        default:
          return ContenidoSeccion(
            migas: ['Inicio', item.categoria, item.titulo],
            child: PanelVacio(
              titulo: item.titulo,
              mensaje: 'Esta sección está pendiente de construir.',
              icono: item.icono,
            ),
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
