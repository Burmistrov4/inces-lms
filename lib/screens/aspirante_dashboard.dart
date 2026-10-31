import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/gateways/aula_gateway.dart';
import '../core/result.dart';
import '../models/archivo.dart';
import '../models/aspirante_model.dart';
import '../models/inscripcion.dart';
import '../providers/tema_provider.dart';
import '../repositories/aspirante_repository.dart';
import '../repositories/inscripcion_repository.dart';
import '../repositories/modulo_repository.dart';
import '../services/auth_service.dart';
import '../services/aula_service.dart';
import '../services/planilla_pdf_service.dart';
import '../services/supabase_service.dart';
import '../theme/inces_theme.dart';
import '../widgets/andamiaje.dart';
import '../widgets/comunes.dart';
import '../widgets/modulos_del_menu.dart';
import 'aspirante/estudiante_resumen_panel.dart';
import 'aspirante/estudiante_tareas_panel.dart';
import 'aspirante/marcar_asistencia_panel.dart';
import 'gestor_documental_panel.dart';
import 'mis_aulas_panel.dart';
import 'mis_inscripciones_panel.dart';
import 'perfil_panel.dart';
import '../widgets/walkthrough_interactivo.dart';
import '../widgets/guardia_toque.dart';
import '../widgets/asistente_brjula.dart';

/// Panel del aspirante y del estudiante.
///
/// Sigue usando [AspiranteRepository], que devuelve `Result`. Un fallo de red se
/// muestra como error con reintento, **nunca** como "no tienes ficha": ése era
/// el bug que ocultaba datos, y es la razón de que los tres estados (cargando,
/// error, vacío) estén separados aquí.
///
/// El Módulo 4 (Inscripciones y Cupos) añade dos secciones disponibles: el
/// catálogo de ofertas y "Mis inscripciones". Ambas usan [InscripcionesRepository]
/// y respetan la regla de negocio del backend: si `ofertaVigente == true` el
/// asiento está en asignación y no se puede solicitar, **aunque** queden cupos
/// libres (es la "doble venta" que el diseño evita).
class AspiranteDashboardScreen extends StatefulWidget {
  const AspiranteDashboardScreen({
    super.key,
    this.repositorio,
    this.auth,
    this.aulaGateway,
    this.aulasPropias,
    this.modulos,
    this.planillaService,
    this.seccionInicial,
  });

  final AspiranteRepository? repositorio;
  final AuthService? auth;

  /// De dónde sale el estado de `system_modules` que gobierna el menú.
  ///
  /// Opcional **sólo para las pruebas**, como el resto de puertas de este
  /// dashboard: en producción no se inyecta y se resuelve [ModuloRepository], que
  /// lee por PostgREST. Ver `lib/widgets/modulos_del_menu.dart` para por qué esa
  /// lectura la puede hacer un aprendiz y no sólo un administrador.
  final ModuloRepository? modulos;

  /// Servicio de descarga de la planilla propia. Se puede inyectar en pruebas;
  /// en producción usa el backend autenticado y el selector del navegador.
  final PlanillaPdfService? planillaService;

  /// La puerta del **contenido** del Aula Virtual (M6).
  ///
  /// Opcional **sólo para las pruebas**: en producción no se inyecta y el
  /// dashboard cae al servicio real (ver [_aulaContenido]). Se inyecta cuando una
  /// prueba quiere un doble en lugar de la red, o cuando quiere el listado **sin**
  /// aula abrible —para eso último basta con inyectar [aulasPropias] y dejar esta
  /// en `null`—.
  final AulaGateway? aulaGateway;

  /// De dónde sale el listado de secciones de «Mis aulas».
  ///
  /// Opcional para las pruebas. Sin él se usa [BackendAulaGateway], que lee
  /// `GET /api/v1/mi-horario`: esa ruta **sí** está congelada y responde a los
  /// dos roles, así que el listado es real aunque el contenido no lo sea aún.
  final AulasPropiasGateway? aulasPropias;
  final String? seccionInicial;

  @override
  State<AspiranteDashboardScreen> createState() =>
      _AspiranteDashboardScreenState();
}

class _AspiranteDashboardScreenState extends State<AspiranteDashboardScreen>
    with CargaDeModulos<AspiranteDashboardScreen> {
  late final AspiranteRepository _repo =
      widget.repositorio ?? AspiranteRepository();

  /// El estado real de `system_modules`, para que el menú no afirme que hay una
  /// sección al otro lado cuando el administrador apagó su módulo.
  late final ModuloRepository _modulosRepo =
      widget.modulos ?? ModuloRepository();

  @override
  ModuloRepository get repositorioDeModulos => _modulosRepo;
  late final AuthService _auth = widget.auth ?? AuthService();
  late final PlanillaPdfService _planillaService =
      widget.planillaService ?? PlanillaPdfService();
  final InscripcionesRepository _inscripciones = InscripcionesRepository();

  /// El listado de aulas de «Mis aulas».
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

  bool _cargando = true;
  bool _descargandoPlanilla = false;
  bool _descargandoExcel = false;
  AspiranteModel? _aspirante;
  Map<String, dynamic>? _versionPlanilla;
  String? _error;

  int _seleccionada = 0;
  final Map<String, Widget> _panelesCargados = {};

  // Orden de uso real del aprendiz, no orden de construcción: el aula y la
  // asistencia son lo que se abre todos los días; la inscripción, una vez.
  static const List<ItemNavegacion> _items = [
    // «Mis aulas» es la entrada al Aula Virtual (M6). El listado sale de
    // `/mi-horario` y el contenido del servicio real de M6: el módulo se enciende
    // o se apaga desde el cPanel, y **eso es exactamente lo que ahora se lee**.
    // Antes esta sección ignoraba el interruptor: con `m6_aula_virtual` apagado
    // seguía encendida y el clic devolvía 403.
    ItemNavegacion(
      icono: Icons.class_outlined,
      titulo: 'Mis aulas',
      categoria: 'Académico',
      modulo: 'm6_aula_virtual',
    ),
    // M7 — el estudiante marca su asistencia tecleando o escaneando el QR.
    //
    // Se ata a `m7_asistencia` **aunque `roles_permitidos` diga
    // `['docente','admin']`**: esa lista dice quién puede usar las rutas del
    // docente —abrir sesión, leer marcas, cerrar—, no quién ve el menú. El
    // aprendiz es quien marca, y si el administrador apaga el módulo, la sección
    // se apaga para todos. Ver la nota de `ItemNavegacion.modulo`.
    ItemNavegacion(
      icono: Icons.fact_check_outlined,
      titulo: 'Marcar asistencia',
      categoria: 'Académico',
      disponible: true,
      modulo: 'm7_asistencia',
    ),
    // «Mis tareas» es el gestor documental (M5) con el tipo de archivo de
    // entrega: sube a R2 y funciona sin aula abierta, así que depende de
    // `m5_archivos` y no de `m6_aula_virtual`.
    ItemNavegacion(
      icono: Icons.assignment_turned_in_outlined,
      titulo: 'Mis tareas',
      categoria: 'Académico',
      disponible: true,
      modulo: 'm5_archivos',
    ),
    ItemNavegacion(
      icono: Icons.explore_outlined,
      titulo: 'Inscribirme en un curso',
      etiquetaCorta: 'Inscribirme',
      categoria: 'Académico',
      modulo: 'm4_inscripciones',
    ),
    ItemNavegacion(
      icono: Icons.playlist_add_check_outlined,
      titulo: 'Mis inscripciones',
      etiquetaCorta: 'Inscripciones',
      categoria: 'Académico',
      modulo: 'm4_inscripciones',
    ),
    // Sin `modulo:`: la ficha propia no es un módulo que se apague. Si el
    // administrador apagara «inscripciones», el aprendiz seguiría necesitando
    // ver el estado de la suya.
    ItemNavegacion(
      icono: Icons.badge_outlined,
      titulo: 'Mi inscripción',
      etiquetaCorta: 'Inscripción',
      categoria: 'Mi cuenta',
    ),
    // Se enciende al llegar la ruta de listado (D17). Lo que todavía **no**
    // puede mostrar es contenido: un estudiante no sabe qué `entidadId`
    // corresponde a las guías de su módulo hasta que el Aula Virtual (M6) ate
    // cada guía a una sección. El panel lo dice en pantalla, en vez de fingir una
    // lista vacía por no haber archivos.
    ItemNavegacion(
      icono: Icons.folder_open_outlined,
      titulo: 'Guías y materiales',
      categoria: 'Académico',
      disponible: true,
      modulo: 'm5_archivos',
    ),
    // El aprendiz corrige su nombre desde el primer día: `profiles` se crea en
    // la misma transacción del alta (`handle_new_user()`, migración
    // `202609120001`), así que no hay que esperar a nada para poder editarlo.
    //
    // Es el **mismo panel** que usa el administrador (`lib/screens/perfil_panel.dart`),
    // no una copia: lo que se puede corregir —el nombre— no depende del rol.
    ItemNavegacion(
      icono: Icons.account_circle_outlined,
      titulo: 'Mi Perfil',
      etiquetaCorta: 'Perfil',
      categoria: 'Mi cuenta',
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.seccionInicial != null) {
      final idx = _items.indexWhere(
        (it) => it.titulo.toLowerCase() == widget.seccionInicial!.toLowerCase(),
      );
      if (idx != -1) _seleccionada = idx;
    }
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    final resultado = await _repo.obtenerMiFicha();

    // El estado de carga se libera antes del `return` por desmontaje: al revés,
    // un desmontaje durante la petición dejaría el indicador girando para
    // siempre en la siguiente visita a esta pantalla.
    if (mounted) setState(() => _cargando = false);
    if (!mounted) return;

    setState(() {
      switch (resultado) {
        case Success(value: final ficha):
          _aspirante = ficha;
          _panelesCargados.remove('Inscribirme en un curso');
          if (ficha != null && ficha.id != null) {
            try {
              SupabaseService.instance.client
                  .from('planilla_versiones')
                  .select('id, numero, estado, enviada_at, aprobada_at, planilla_observaciones(motivo, created_at)')
                  .eq('aspirante_id', ficha.id!)
                  .order('numero', ascending: false)
                  .limit(1)
                  .maybeSingle()
                  .then((v) {
                if (mounted && v != null) {
                  setState(() => _versionPlanilla = v);
                }
              });
            } catch (_) {}
          }
        case Failure(error: final fallo):
          _error = fallo.message;
      }
    });
  }

  Future<void> _descargarPlanilla() async {
    if (_descargandoPlanilla) return;
    setState(() => _descargandoPlanilla = true);

    final resultado = await _planillaService.descargarPlanillaPropia();
    if (!mounted) return;
    setState(() => _descargandoPlanilla = false);

    switch (resultado) {
      case PlanillaDescargada(:final nombreArchivo):
        mostrarAviso(
          context,
          'Tu planilla oficial se descargó ($nombreArchivo). Ya puedes abrirla o imprimirla.',
          exito: true,
        );
      case SinFichaDeAspirante():
        mostrarAviso(
          context,
          'No encontramos una ficha de inscripción para generar la planilla.',
          error: true,
        );
      case ConsultaFallida(:final mensaje):
        mostrarAviso(context, mensaje, error: true);
      case DescargaFallida():
        mostrarAviso(
          context,
          'No pudimos entregar el PDF al navegador. Inténtalo de nuevo.',
          error: true,
        );
    }
  }

  Future<void> _descargarPlanillaExcel() async {
    if (_descargandoExcel) return;
    setState(() => _descargandoExcel = true);

    final resultado = await _planillaService.descargarPlanillaPropiaXlsx();
    if (!mounted) return;
    setState(() => _descargandoExcel = false);

    switch (resultado) {
      case PlanillaDescargada(:final nombreArchivo):
        mostrarAviso(
          context,
          'Tu planilla en Excel se descargó ($nombreArchivo). Ya puedes abrirla y editarla.',
          exito: true,
        );
      case SinFichaDeAspirante():
        mostrarAviso(
          context,
          'No encontramos una ficha de inscripción para generar la planilla en Excel.',
          error: true,
        );
      case ConsultaFallida(:final mensaje):
        mostrarAviso(context, mensaje, error: true);
      case DescargaFallida():
        mostrarAviso(
          context,
          'No pudimos entregar el archivo Excel al navegador. Inténtalo de nuevo.',
          error: true,
        );
    }
  }

  Future<void> _cerrarSesion() async {
    await _auth.cerrarSesion();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushReplacementNamed('/login');
  }

  void _navegarA(String destino) {
    final idx = _items.indexWhere(
      (it) =>
          it.titulo.toLowerCase() == destino.toLowerCase() ||
          it.titulo.toLowerCase().contains(destino.toLowerCase()),
    );
    if (idx != -1) {
      setState(() => _seleccionada = idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nulable a propósito: en las pruebas este panel se monta sin proveedor de
    // tema. Ver el comentario equivalente en `admin_dashboard.dart`.
    final tema = context.watch<TemaProvider?>();

    return AndamiajeApp(
      // `menuConModulos` y no `_items`: el menú sale con el estado real de
      // `system_modules` aplicado encima, así que apagar `m6_aula_virtual` o
      // `m4_inscripciones` desde el cPanel se refleja aquí en vez de llevar a un
      // 403.
      items: menuConModulos(_items),
      seleccionado: _seleccionada,
      onSeleccionar: (indice) => setState(() => _seleccionada = indice),
      rolEtiqueta: 'Estudiante',
      correoUsuario: _auth.emailActual,
      periodoActivo: 'SA26-2',
      onCerrarSesion: _cerrarSesion,
      temaActual: tema?.modo,
      onCambiarTema: tema?.cambiar,
      asistente: AsistenteBrujula(
        rol: 'aspirante',
        etiquetaRol: 'Aprendiz',
        onNavegar: _navegarA,
      ),
      accionesEncabezado: [
        IconButton(
          tooltip: 'Inscribirme en un curso',
          icon: const Icon(Icons.explore_outlined, size: 20),
          onPressed: () => conGuardia(() => _navegarA('Inscribirme en un curso'), 'nav-Inscribirme en un curso'),
        ),
        IconButton(
          tooltip: 'Mis aulas',
          icon: const Icon(Icons.class_outlined, size: 20),
          onPressed: () => conGuardia(() => _navegarA('Mis aulas'), 'nav-Mis aulas'),
        ),
        IconButton(
          tooltip: 'Marcar asistencia',
          icon: const Icon(Icons.fact_check_outlined, size: 20),
          onPressed: () => conGuardia(() => _navegarA('Marcar asistencia'), 'nav-Marcar asistencia'),
        ),
        IconButton(
          tooltip: 'Descargar Planilla Oficial PDF',
          icon: const Icon(Icons.download_rounded, size: 20),
          onPressed: _descargarPlanilla,
        ),
        IconButton(
          tooltip: 'Guía Interactiva del Aprendiz',
          icon: const Icon(Icons.help_outline_rounded, size: 20),
          onPressed: () => conGuardia(
            () => WalkthroughInteractivoCard.mostrarModal(
              context,
              rol: RolWalkthrough.estudiante,
              onNavegarA: _navegarA,
            ),
            'walkthrough-estudiante',
          ),
        ),
      ],
      contenido: _contenido(),
    );
  }

  /// Contenido de la sección seleccionada.
  ///
  /// **`switch` por TÍTULO y no por índice**, igual que el cPanel. Estaba por
  /// índice, y eso ata la rama a la POSICIÓN del ítem: al insertar «Mis
  /// tareas» antes de «Guías y materiales», `case 4` habría pasado a abrir una
  /// sección distinta sin que nada avisara. Con el título, insertar o mover un
  /// ítem no cambia a dónde lleva.
  ///
  /// Es además lo que permite que `test/menu_alcanzable_test.dart` compruebe el
  /// contrato leyendo este archivo. Es la red que faltaba cuando R-22.
  ///
  /// La lista que se consulta aquí es la **efectiva** —con los módulos
  /// aplicados—, no `_items`: si el administrador apaga un módulo mientras el
  /// aprendiz está dentro de esa sección, el contenido tiene que dejar de
  /// pintarse.
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

    if (item.titulo == 'Mi inscripción') {
      _panelesCargados['Mi inscripción'] = _panelMiInscripcion();
    } else {
      _panelesCargados.putIfAbsent(item.titulo, () {
        switch (item.titulo) {
          case 'Mi inscripción':
            return _panelMiInscripcion();

          // El mismo panel que monta el administrador. Aquí no se le inyecta nada:
          // resuelve el servicio real, que es lo que un aprendiz necesita.
          case 'Mi Perfil':
            return ContenidoSeccion(
              migas: ['Inicio', item.categoria, item.titulo],
              child: const PerfilPanel(),
            );

          case 'Inscribirme en un curso':
            return PanelOfertas(
              repositorio: _inscripciones,
              programaAspirante: _aspirante?.programaNombre,
            );

          case 'Mis inscripciones':
            return PanelMisInscripciones(repositorio: _inscripciones);

          case 'Mis aulas':
            // Aula Virtual (M6): el listado de secciones viene de `/mi-horario`
            // —ruta congelada desde M3, una fila por sección— y cada tarjeta abre
            // el tablón y el trabajo de clase de esa sección, con el gestor
            // documental incrustado para subir las entregas.
            //
            // `_aulaContenido` —y no `widget.aulaGateway`— es lo que hace que en
            // producción la tarjeta se pueda pulsar: sin inyectar nada resuelve el
            // servicio real, y con algo inyectado respeta lo que pidió la prueba.
            return PanelMisAulas(
              gateway: _aulasPropias,
              aulaGateway: _aulaContenido,
              onNavegarA: _navegarA,
            );

          case 'Mis tareas':
            return ContenidoSeccion(
              migas: ['Inicio', item.categoria, item.titulo],
              child: DefaultTabController(
                length: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TabBar(
                      isScrollable: true,
                      tabs: [
                        Tab(
                          icon: Icon(Icons.assignment_turned_in_outlined),
                          text: 'Tareas',
                        ),
                        Tab(
                          icon: Icon(Icons.folder_shared_outlined),
                          text: 'Mis archivos',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                        children: [
                          SingleChildScrollView(
                            child: EstudianteTareasPanel(
                              aulasGateway: _aulasPropias,
                              aulaGateway: _aulaContenido,
                              onNavegarA: _navegarA,
                            ),
                          ),
                          const GestorDocumentalPanel(
                            entityType: TipoEntidadArchivo.taskSubmission,
                            subtitulo: 'Sube aquí los trabajos que te pida el docente.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );

          // (M7) El estudiante marca su asistencia con el código de la pizarra.
          case 'Marcar asistencia':
            return ContenidoSeccion(
              migas: ['Inicio', item.categoria, item.titulo],
              child: const MarcarAsistenciaPanel(),
            );

          case 'Guías y materiales':
            // Sin `entidadId`: todavía no hay una guía concreta que pedir, porque
            // M6 no ha creado la tabla que las sostiene. El panel funciona en modo
            // sólo-subida y lo explica en pantalla. Se monta igualmente para que el
            // día que M6 exista sólo haya que pasarle el id.
            return ContenidoSeccion(
              migas: ['Inicio', item.categoria, item.titulo],
              child: const GestorDocumentalPanel(
                entityType: TipoEntidadArchivo.teacherGuide,
                titulo: 'Guías y materiales',
                subtitulo: 'Las guías y el material que publique tu docente.',
              ),
            );

          default:
            // Secciones aún no construidas: se muestran atenuadas en el menú y, si
            // alguien llega aquí, un panel vacío que explica por qué.
            return ContenidoSeccion(
              migas: ['Inicio', item.categoria, item.titulo],
              child: PanelVacio(
                titulo: item.titulo,
                mensaje: 'Esta sección se habilitará cuando tu curso esté activo.',
                icono: item.icono,
              ),
            );
        }
      });
    }

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

  Widget _panelMiInscripcion() {
    return ContenidoSeccion(
      migas: const ['Inicio', 'Mi cuenta', 'Mi inscripción y planilla'],
      child: _cargando
          ? const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          : _error != null
              ? _panelError(_error!)
              : _aspirante == null
                  ? _panelVacio()
                  : SingleChildScrollView(child: _panelFicha(_aspirante!)),
    );
  }

  Widget _panelError(String mensaje) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_outlined,
                size: 30,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No pudimos cargar tu ficha',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panelVacio() {
    return const PanelVacio(
      titulo: 'Tu inscripción está en revisión',
      mensaje:
          'Cuando el centro formativo apruebe tu solicitud verás aquí tu curso '
          'y tu estado. Mientras esperas, puedes pedir cupo en otra sección '
          'desde «Inscribirme en un curso».',
      icono: Icons.pending_actions_outlined,
      nota:
          'Recibirás un correo cuando tu inscripción sea confirmada. Si no '
          'llega, revisa la carpeta de spam: el envío depende del dominio de '
          'correo configurado por el centro.',
    );
  }


  Future<void> _abrirEdicionAspirante(AspiranteModel asp) async {
    final telCtrl = TextEditingController(text: asp.telefono);
    final dirCtrl = TextEditingController(text: asp.direccion);
    final nivCtrl = TextEditingController(text: asp.nivelEducativo);

    final guardado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Actualizar Datos de Inscripción'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edita los datos que requieran corrección antes de guardar:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telCtrl,
                decoration: const InputDecoration(labelText: 'Teléfono de contacto'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dirCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Dirección de habitación'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nivCtrl,
                decoration: const InputDecoration(labelText: 'Nivel educativo'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Guardar y Reenviar'),
          ),
        ],
      ),
    );

    if (guardado != true || asp.id == null) return;

    try {
      await _repo.actualizar(asp.id!, {
        'telefono': telCtrl.text.trim(),
        'direccion': dirCtrl.text.trim(),
        'nivel_educativo': nivCtrl.text.trim(),
      });

      // Si estaba observada, crear versión REENVIADA
      if ((_versionPlanilla?['estado'] as String?) == 'OBSERVADA') {
        try {
          final numActual = (_versionPlanilla?['numero'] as num?)?.toInt() ?? 1;
          await SupabaseService.instance.client.from('planilla_versiones').insert({
            'aspirante_id': asp.id!,
            'numero': numActual + 1,
            'estado': 'REENVIADA',
            'datos_snapshot': {},
          });
        } catch (_) {}
      }

      if (mounted) {
        mostrarAviso(context, 'Datos actualizados correctamente.', exito: true);
        await _cargar();
      }
    } catch (e) {
      if (mounted) mostrarAviso(context, 'Error al actualizar datos: $e', error: true);
    }
  }
  Widget _panelFicha(AspiranteModel aspirante) {
    final theme = Theme.of(context);
    // El chip de «En revisión» cae sobre un tinte de su propio color, así que el
    // ámbar de relleno de `IncesTheme` no vale: da 1.81:1 en modo claro. Medido
    // el 2026-09-30.
    final par = PaletaInces.de(context).etiquetaDe(TonoEstado.advertencia);

    // D14: el nombre del programa ya no vive en la ficha —la columna se eliminó
    // y quedó `program_id` con clave foránea—, así que llega resuelto por JOIN
    // desde `miFicha()` (`select('*, programs(name)')`).
    //
    // `programaNombre` es nulo en cualquier ruta que no pida la relación
    // incrustada, y por eso hay respaldo: un nombre ausente no debe romper la
    // ficha, pero tampoco debe pasar por «no eligió nada».
    final nombrePrograma = aspirante.programaNombre;
    final curso = nombrePrograma == null || nombrePrograma.isEmpty
        ? 'Por asignar'
        : nombrePrograma;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EstudianteResumenPanel(
          aspirante: aspirante,
          onNavegarA: _navegarA,
          onDescargarPlanilla: _descargarPlanilla,
          onDescargarExcel: _descargarPlanillaExcel,
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 16),
        // Tarjeta de identidad con la cabecera de marca. Es la versión de
        // «perfil» del lenguaje visual que usan las tarjetas de módulo.
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 6,
                decoration: const BoxDecoration(
                  gradient: IncesTheme.degradadoMarca,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.12),
                      child: Text(
                        _iniciales(aspirante),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${aspirante.nombres} ${aspirante.apellidos}'
                                .trim(),
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Builder(
                            builder: (context) {
                              final estado = (_versionPlanilla?['estado'] as String?) ?? 'EN REVISIÓN';
                              final esAprobada = estado == 'APROBADA';
                              final esObservada = estado == 'OBSERVADA';
                              final colorFondo = esAprobada
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : esObservada
                                      ? Colors.orange.withValues(alpha: 0.18)
                                      : par.fondo;
                              final colorTexto = esAprobada
                                  ? Colors.green.shade800
                                  : esObservada
                                      ? Colors.orange.shade900
                                      : par.texto;
                              final etiqueta = esAprobada
                                  ? 'Planilla Aprobada Oficialmente'
                                  : esObservada
                                      ? 'Planilla Observada (Requiere corrección)'
                                      : 'En revisión';

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: colorFondo,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  etiqueta,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorTexto,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TituloSeccion('Datos de la solicitud'),
                _FilaDato(etiqueta: 'Cédula', valor: aspirante.cedula),
                _FilaDato(etiqueta: 'Nombres', valor: aspirante.nombres),
                _FilaDato(etiqueta: 'Apellidos', valor: aspirante.apellidos),
                _FilaDato(
                  etiqueta: 'Curso solicitado',
                  valor: curso,
                  esUltima: false,
                ),
                _FilaDato(etiqueta: 'Teléfono', valor: aspirante.telefono),
                _FilaDato(etiqueta: 'Dirección', valor: aspirante.direccion),
                _FilaDato(
                  etiqueta: 'Nivel educativo',
                  valor: aspirante.nivelEducativo,
                  esUltima: true,
                ),
                const SizedBox(height: 14),
                if ((_versionPlanilla?['estado'] as String?) == 'OBSERVADA') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 20, color: Colors.orange.shade900),
                            const SizedBox(width: 8),
                            Text(
                              'Corrección requerida por coordinación',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Builder(
                          builder: (_) {
                            final obs = (_versionPlanilla?['planilla_observaciones'] as List<dynamic>?) ?? const [];
                            final motivo = obs.isNotEmpty ? obs.last['motivo']?.toString() ?? '' : '';
                            return Text(
                              motivo.isNotEmpty ? 'Motivo: $motivo' : 'Por favor revisa y actualiza tus datos de contacto.',
                              style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _abrirEdicionAspirante(aspirante),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text((_versionPlanilla?['estado'] as String?) == 'OBSERVADA'
                          ? 'Corregir y reenviar planilla'
                          : 'Editar datos de planilla'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Nota: Se aconseja editar sólo si la administración te rechaza o solicita corregir algún dato.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TituloSeccion('Planilla oficial de inscripción'),
                const SizedBox(height: 6),
                Text(
                  'Descarga la planilla institucional con los datos de tu ficha, lista para revisar e imprimir.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('descargar-planilla-oficial'),
                      onPressed: _descargandoPlanilla ? null : _descargarPlanilla,
                      icon: _descargandoPlanilla
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(
                        _descargandoPlanilla
                            ? 'Generando PDF…'
                            : 'Descargar planilla oficial (PDF)',
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('descargar-planilla-excel'),
                      onPressed: _descargandoExcel ? null : _descargarPlanillaExcel,
                      icon: _descargandoExcel
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.table_chart_outlined),
                      label: Text(
                        _descargandoExcel
                            ? 'Generando Excel…'
                            : 'Descargar en Excel (.xlsx) editable',
                      ),
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

  /// Iniciales para el avatar. Si no hay nombre, cae a un icono genérico.
  static String _iniciales(AspiranteModel aspirante) {
    final nombre = aspirante.nombres.trim();
    final apellido = aspirante.apellidos.trim();

    final a = nombre.isEmpty ? '' : nombre[0];
    final b = apellido.isEmpty ? '' : apellido[0];

    final combinadas = '$a$b'.toUpperCase();
    return combinadas.isEmpty ? '?' : combinadas;
  }
}

/// Catálogo de ofertas de cupo del estudiante (Módulo 4, capa estudiante).
///
/// Regla de negocio visible en la UI: si `ofertaVigente == true` el asiento está
/// en asignación automática y el botón "Inscribirme" queda deshabilitado con la
/// etiqueta "Asiento en asignación", **aunque** `cuposDisponibles > 0`. No se
/// puede "robar" un cupo que el backend está asignando a quien viene de la cola.
class PanelOfertas extends StatefulWidget {
  const PanelOfertas({
    super.key,
    required this.repositorio,
    this.programaAspirante,
  });

  final InscripcionesRepository repositorio;
  final String? programaAspirante;

  @override
  State<PanelOfertas> createState() => _PanelOfertasState();
}

class _PanelOfertasState extends State<PanelOfertas> {
  bool _cargando = true;
  String? _error;
  List<OcupacionSeccion> _secciones = const [];
  final Set<String> _inscribiendo = {};

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

    final resultado = await widget.repositorio.obtenerOfertas();
    if (!mounted) return;

    setState(() {
      _cargando = false;
      switch (resultado) {
        case Success(value: final secciones):
          _secciones = secciones;
        case Failure(error: final fallo):
          _error = fallo.message;
      }
    });
  }

  String _limpiarSemilla(String texto) {
    return texto.replaceAll(RegExp(r'\s*\[SEMILLA\]\s*', caseSensitive: false), '').trim();
  }

  Future<void> _inscribirse(OcupacionSeccion o) async {
    final progSeccion = o.programaNombre != null ? _limpiarSemilla(o.programaNombre!) : null;
    final progAspirante = widget.programaAspirante != null ? _limpiarSemilla(widget.programaAspirante!) : null;

    final esDiferente = progAspirante != null &&
        progAspirante.isNotEmpty &&
        progSeccion != null &&
        progSeccion.isNotEmpty &&
        progAspirante.toLowerCase() != progSeccion.toLowerCase();

    if (esDiferente) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.help_outline_rounded, color: IncesTheme.azulPrimario),
              SizedBox(width: 8),
              Expanded(child: Text('Confirmar postulación en otra formación')),
            ],
          ),
          content: Text(
            'Tu registro inicial en el centro es para el oficio "$progAspirante".\n\n'
            'Estás a punto de solicitar cupo en "${_limpiarSemilla(o.materiaNombre ?? o.nombre)}", perteneciente a la formación "$progSeccion".\n\n'
            '¿Deseas confirmar tu solicitud de cupo para esta formación complementaria?',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Confirmar postulación'),
            ),
          ],
        ),
      );

      if (confirmar != true) return;
    }

    setState(() => _inscribiendo.add(o.seccionId));
    final resultado = await widget.repositorio.inscribirse(o.seccionId);
    if (!mounted) return;
    setState(() => _inscribiendo.remove(o.seccionId));

    resultado.when(
      success: (estado) {
        mostrarAviso(
          context,
          'Solicitud enviada. Estado: ${_etiquetaEstado(estado)}.',
          exito: true,
        );
        _cargar();
      },
      failure: (fallo) => mostrarAviso(context, fallo.message, error: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ContenidoSeccion(
      migas: const ['Inicio', 'Académico', 'Inscribirme en un curso'],
      child: EstadoPanel(
        cargando: _cargando,
        error: _error,
        onReintentar: _cargar,
        child: _contenido(),
      ),
    );
  }

  Widget _contenido() {
    final theme = Theme.of(context);
    final progAspirante = widget.programaAspirante != null ? _limpiarSemilla(widget.programaAspirante!) : null;

    if (_secciones.isEmpty) {
      return const PanelVacio(
        titulo: 'No hay secciones abiertas',
        mensaje:
            'Cuando el centro formativo habilite secciones con cupo las '
            'verás listadas aquí, con su disponibilidad en tiempo real.',
        icono: Icons.explore_outlined,
        nota:
            'Pedir cupo es sólo el primer paso: solicitas, el centro aprueba '
            'y después quedas matriculado. Si una sección se llena, entras en '
            'lista de espera y se te asignará un cupo en cuanto se libere. '
            'Mientras tanto, revisa «Mis inscripciones» para ver el estado de '
            'lo que ya pediste.',
      );
    }

    final tieneSeccionesDeMiPrograma = progAspirante != null &&
        progAspirante.isNotEmpty &&
        _secciones.any((s) =>
            s.programaNombre != null &&
            _limpiarSemilla(s.programaNombre!).toLowerCase() == progAspirante.toLowerCase());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloSeccion(
          'Inscribirme en un curso',
          subtitulo: '${plural(_secciones.length, 'sección', 'secciones')} en este período.',
          acciones: [
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _cargando ? null : _cargar,
              icon: const Icon(Icons.refresh_rounded, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (progAspirante != null && progAspirante.isNotEmpty && !tieneSeccionesDeMiPrograma) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: IncesTheme.azulPrimario.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: IncesTheme.azulPrimario.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: IncesTheme.azulPrimario,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tu formación seleccionada: $progAspirante',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'En el período académico actual no hay secciones abiertas para tu formación técnica específica. '
                        'Tu postulación se encuentra en lista de espera prioritaria para futuras aperturas. '
                        'Las opciones que aparecen a continuación corresponden a otras formaciones técnicas con cupo en el centro.',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          height: 1.45,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        // El ciclo completo, antes de la lista: sin él el aprendiz cree que
        // pulsar «Inscribirme» ya es estar matriculado, y no lo es.
        const AvisoEnLinea(
          texto:
              'Pedir cupo tiene tres pasos: solicitas aquí, el centro '
              'formativo aprueba tu solicitud y después quedas matriculado. '
              'Si la sección se llena antes de aprobarte, entras en lista de '
              'espera: se te guarda el turno y se te asigna un cupo en cuanto '
              'se libere uno. Puedes seguir el estado en «Mis inscripciones».',
          icono: Icons.route_outlined,
          tono: TonoAviso.info,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final o in _secciones) _tarjetaOferta(o),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tarjetaOferta(OcupacionSeccion o) {
    final theme = Theme.of(context);
    final conCupo = o.cuposDisponibles > 0;
    final puedeInscribirse = conCupo;
    final ocupado = _inscribiendo.contains(o.seccionId);

    final titulo = _limpiarSemilla(o.materiaNombre ?? o.nombre);
    final programa = o.programaNombre != null ? _limpiarSemilla(o.programaNombre!) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      ?programa,
                      o.periodo,
                    ].join(' · '),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Etiqueta(texto: 'Cupo ${o.resumenCupo}'),
                      Etiqueta(
                        texto: conCupo
                            ? '${o.cuposDisponibles} disponible(s)'
                            : 'Sin cupos',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (puedeInscribirse)
              FilledButton.icon(
                onPressed: ocupado ? null : () => _inscribirse(o),
                icon: ocupado
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_outlined, size: 16),
                label: Text(ocupado ? 'Enviando…' : 'Inscribirme'),
              )
            else
              FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.block_outlined, size: 16),
                label: const Text('Sin cupos'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Etiqueta en español de un estado, para los avisos de acción.
String _etiquetaEstado(EstadoInscripcion estado) => switch (estado) {
  EstadoInscripcion.enrolled => 'Matriculado',
  EstadoInscripcion.waitlisted => 'En lista de espera',
  EstadoInscripcion.dropped => 'Renunciado',
};

/// Fila de dato etiqueta/valor.
class _FilaDato extends StatelessWidget {
  const _FilaDato({
    required this.etiqueta,
    required this.valor,
    this.esUltima = false,
  });

  final String etiqueta;
  final String valor;
  final bool esUltima;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ancho mínimo de la etiqueta: sin él, «Cédula» y «Curso
              // solicitado» dejan los valores desalineados entre filas y la
              // lectura en columna se pierde.
              SizedBox(
                width: 150,
                child: Text(
                  etiqueta,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  valor.isEmpty ? '—' : valor,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        if (!esUltima) const Divider(height: 1),
      ],
    );
  }
}
