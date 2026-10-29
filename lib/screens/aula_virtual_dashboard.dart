import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/gateways/aula_gateway.dart';
import '../core/gateways/selector_archivos.dart';
import '../core/result.dart';
import '../models/archivo.dart';
import '../repositories/archivos_repository.dart';
import '../theme/inces_theme.dart';
import '../theme/temas_formacion.dart';
import '../widgets/andamiaje.dart';
import '../widgets/comunes.dart';
import 'crear_anuncio_panel.dart';
import 'crear_tarea_panel.dart';
import 'gestor_documental_panel.dart';
import 'libro_calificaciones_panel.dart';

/// Aula Virtual de una sección (Módulo 6).
///
/// Una sección de M3 —con su roster de M4 y sus docentes de M3— es el «curso»
/// (D-1). Esta pantalla le da dos pestañas:
///
///  * **Tablón** — el feed de anuncios, más reciente primero.
///  * **Trabajo de clase** — las tareas y materiales, y para el estudiante el
///    estado de **su** entrega en cada una.
///
/// ## El punto de esta pantalla
///
/// Para el estudiante, abrir una tarea muestra el [GestorDocumentalPanel] de M5
/// atado a **su** entrega: el `entidadId` es el `m6_entregas.id`. Ésa es la
/// unión que M5 no podía expresar —`files_metadata.entidad_id` era un UUID sin
/// tabla que lo respaldara— y que M6 cierra (§3.3, D-8). El estudiante sube su
/// trabajo **desde el aula**, sin salir a otra pantalla.
///
/// ## Qué decide el rol, y qué no
///
/// [esDocente] sólo decide **presentación**: qué se pide y qué se pinta. **No es
/// autorización.** Quien puede ver o escribir lo decide la RLS y las RPC
/// `security definer` en la base (ADR-003). Si el docente no viera el panel de
/// entrega del alumno sólo por este booleano, la regla viviría en el cliente —y
/// un cliente se cambia—.
///
/// ## El puerto, no el servicio
///
/// La pantalla consume `AulaGateway`, y en producción recibe
/// `BackendAulaGateway`: la implementación HTTP real, en
/// `lib/services/aula_service.dart`, que cubre las doce operaciones contra
/// `/api/v1/aula/*`. `resolverPuertaDeContenido` la devuelve cuando el llamante
/// no inyecta nada, y los tres dashboards no inyectan nada.
///
/// Aquí decía que esa implementación «está pendiente a propósito» y que sólo se
/// le pasaba el doble de `test/support/fake_aula_gateway.dart`. **Envejeció.**
/// Una nota de «falta hacer X» sobre algo ya hecho no es inocua: hace que quien
/// lea el archivo crea que el aula sólo funciona contra un doble, y que el
/// problema esté en otro sitio.
class AulaVirtualDashboardScreen extends StatefulWidget {
  const AulaVirtualDashboardScreen({
    super.key,
    required this.seccionId,
    required this.seccionNombre,
    required this.gateway,
    this.esDocente = false,
    this.archivosRepositorio,
    this.selectorArchivos,
  });

  final String seccionId;

  /// Nombre visible de la sección (materia + lapso), ya resuelto por quien la
  /// abre. La pantalla no lo deduce: no conoce el catálogo de M2/M3.
  final String seccionNombre;

  final AulaGateway gateway;

  /// `true` ⇒ vista del docente. Ver la nota de la clase: es presentación, no
  /// autorización.
  final bool esDocente;

  /// El gestor documental de M5 que se incrusta en el detalle de la tarea.
  ///
  /// Se inyecta —y no se construye dentro— por la misma razón que en M5: la
  /// implementación real hace red y el doble de pruebas no. Sin este hueco, la
  /// prueba del `entidadId` sería imposible.
  final ArchivosRepository? archivosRepositorio;

  /// El diálogo de archivos del navegador. Se inyecta porque su implementación
  /// real no compila en la VM de `flutter test`.
  final SelectorDeArchivos? selectorArchivos;

  @override
  State<AulaVirtualDashboardScreen> createState() =>
      _AulaVirtualDashboardScreenState();
}

class _AulaVirtualDashboardScreenState
    extends State<AulaVirtualDashboardScreen> {
  // --- Tablón ---------------------------------------------------------------
  bool _cargandoTablon = true;
  String? _errorTablon;
  List<Anuncio> _anuncios = const [];

  // --- Trabajo de clase -----------------------------------------------------
  bool _cargandoTrabajo = true;
  String? _errorTrabajo;
  List<TareaDeClase> _tareas = const [];

  /// La entrega del estudiante por `tareaId`. Es el cruce que pinta el estado en
  /// cada tarjeta: `misEntregas()` no viene indexado, así que se indexa aquí.
  Map<String, Entrega> _entregasPorTarea = const {};

  bool _cargandoEntregas = false;
  String? _errorEntregas;

  /// La tarea abierta, si la hay. `null` ⇒ se ven las pestañas; no `null` ⇒ se
  /// ve el detalle. Se resuelve con estado y no empujando una ruta para que el
  /// detalle herede la altura acotada de [ContenidoSeccion] y el gestor
  /// documental (que es un `ListView`) reciba un alto finito sin trucos.
  TareaDeClase? _tareaAbierta;

  /// Ids de entrega con una acción en curso. Es un conjunto y no una bandera:
  /// dos entregas podrían estar ocupadas a la vez y cada botón debe reflejar
  /// sólo la suya.
  final Set<String> _ocupadas = <String>{};

  /// ¿Sigue cargando lo que la pestaña de trabajo necesita?
  ///
  /// Se mezclan tarea y entregas **para el estudiante**: pintar una tarjeta sin
  /// su estado de entrega y luego cambiarlo es peor que esperar un instante. El
  /// docente no pide entregas (esa ruta es del alumno), así que para él sólo
  /// cuenta la tarea.
  bool get _cargandoClase =>
      _cargandoTrabajo || (!widget.esDocente && _cargandoEntregas);

  @override
  void initState() {
    super.initState();
    _cargarTablon();
    _cargarTrabajo();
    // El docente no llama a `mis-entregas`: la ruta es del alumno y devolvería
    // 403. No es una optimización, es respetar el contrato de §6.
    if (!widget.esDocente) _cargarEntregas();
  }

  // ── Carga ──────────────────────────────────────────────────────────────────

  Future<void> _cargarTablon() async {
    setState(() {
      _cargandoTablon = true;
      _errorTablon = null;
    });

    final resultado =
        await Result.guard(() => widget.gateway.tablon(widget.seccionId));
    if (!mounted) return;

    setState(() {
      _cargandoTablon = false;
      resultado.when(
        success: (lista) => _anuncios = lista,
        failure: (fallo) => _errorTablon = fallo.message,
      );
    });
  }

  Future<void> _cargarTrabajo() async {
    setState(() {
      _cargandoTrabajo = true;
      _errorTrabajo = null;
    });

    final resultado =
        await Result.guard(() => widget.gateway.trabajoDeClase(widget.seccionId));
    if (!mounted) return;

    setState(() {
      _cargandoTrabajo = false;
      resultado.when(
        success: (lista) => _tareas = lista,
        failure: (fallo) => _errorTrabajo = fallo.message,
      );
    });
  }

  Future<void> _cargarEntregas() async {
    setState(() {
      _cargandoEntregas = true;
      _errorEntregas = null;
    });

    final resultado = await Result.guard(() => widget.gateway.misEntregas());
    if (!mounted) return;

    setState(() {
      _cargandoEntregas = false;
      resultado.when(
        success: (lista) => _entregasPorTarea = {
          for (final entrega in lista) entrega.tareaId: entrega,
        },
        failure: (fallo) => _errorEntregas = fallo.message,
      );
    });
  }

  // ── Acciones del estudiante ────────────────────────────────────────────────

  Future<void> _entregar(Entrega entrega) async {
    if (_ocupadas.contains(entrega.id)) return;

    setState(() => _ocupadas.add(entrega.id));

    final resultado =
        await Result.guard(() => widget.gateway.entregar(entrega.id));

    // El estado de carga se libera **antes** del `return` por desmontaje: al
    // revés, un desmontaje durante la petición dejaría el botón bloqueado para
    // siempre en la siguiente visita.
    if (!mounted) {
      _ocupadas.remove(entrega.id);
      return;
    }

    setState(() {
      _ocupadas.remove(entrega.id);
      resultado.when(
        success: (actualizada) =>
            _entregasPorTarea = {..._entregasPorTarea, actualizada.tareaId: actualizada},
        failure: (_) {},
      );
    });

    resultado.when(
      success: (_) => mostrarAviso(context, 'Tarea entregada.', exito: true),
      failure: (fallo) => mostrarAviso(context, fallo.message, error: true),
    );
  }

  Future<void> _reclamar(Entrega entrega) async {
    if (_ocupadas.contains(entrega.id)) return;

    setState(() => _ocupadas.add(entrega.id));

    final resultado =
        await Result.guard(() => widget.gateway.reclamar(entrega.id));

    if (!mounted) {
      _ocupadas.remove(entrega.id);
      return;
    }

    setState(() {
      _ocupadas.remove(entrega.id);
      resultado.when(
        success: (actualizada) =>
            _entregasPorTarea = {..._entregasPorTarea, actualizada.tareaId: actualizada},
        failure: (_) {},
      );
    });

    resultado.when(
      success: (_) => mostrarAviso(
        context,
        'Entrega reclamada: ya puedes volver a subir tu trabajo.',
        exito: true,
      ),
      failure: (fallo) => mostrarAviso(context, fallo.message, error: true),
    );
  }

  // ── Acciones del docente ────────────────────────────────────────────────────

  Future<void> _crearAnuncio() async {
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CrearAnuncioPanel(
          seccionId: widget.seccionId,
          gateway: widget.gateway,
          onGuardado: _cargarTablon,
        ),
      ),
    );
    if (creado == true && mounted) _cargarTablon();
  }

  Future<void> _crearTarea() async {
    final creada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CrearTareaPanel(
          seccionId: widget.seccionId,
          gateway: widget.gateway,
          onGuardado: _cargarTrabajo,
        ),
      ),
    );
    if (creada == true && mounted) _cargarTrabajo();
  }

  Future<void> _abrirLibro(TareaDeClase tarea) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LibroCalificacionesPanel(
          tareaId: tarea.id,
          tareaTitulo: tarea.titulo,
          gateway: widget.gateway,
          onCambio: _cargarTrabajo,
        ),
      ),
    );
  }

  // ── Interfaz ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tarea = _tareaAbierta;

    return ContenidoSeccion(
      migas: const ['Inicio', 'Académico', 'Aula Virtual'],
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TituloSeccion(
              widget.seccionNombre,
              subtitulo: 'Aula Virtual · tablón y trabajo de clase',
            ),
            const SizedBox(height: 8),
            if (tarea == null) ...[
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Tablón'),
                  Tab(text: 'Trabajo de Clase'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    Builder(builder: (tabCtx) => _tablon(tabCtx)),
                    _trabajoDeClase(),
                  ],
                ),
              ),
            ] else
              Expanded(child: _detalleDeTarea(tarea)),
          ],
        ),
      ),
    );
  }

  // ── Tablón ─────────────────────────────────────────────────────────────────

  // **Una sola lista desplazable.** Antes era un Column con Expanded: en
  // pantallas bajas los bloques fijos (banner, entregas, caja de anuncio)
  // desbordaban ~900 px y el contenido quedaba inaccesible. Ahora todo el
  // tablón desliza, como el resto de los módulos.
  Widget _tablon(BuildContext tabContext) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        _cabeceraGoogleClassroom(),
        const SizedBox(height: 14),
        _bloqueProximasEntregas(tabContext),
        if (widget.esDocente) _cajaNuevoAnuncio(),
        const SizedBox(height: 4),
        ..._contenidoTablonComoLista(),
      ],
    );
  }

  Widget _bloqueProximasEntregas(BuildContext tabContext) {
    final theme = Theme.of(tabContext);
    final area = AreaFormativa.resolver(widget.seccionNombre);

    if (widget.esDocente) {
      final totalTareas = _tareas.where((t) => t.tipo.seCalifica).length;
      final totalMateriales = _tareas.where((t) => !t.tipo.seCalifica).length;

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
          side: BorderSide(color: theme.colorScheme.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: area.colorPrimario.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.assignment_outlined,
                  size: 20,
                  color: area.colorPrimario,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Actividades del Curso',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${plural(totalTareas, 'tarea evaluativa', 'tareas evaluativas')} · ${plural(totalMateriales, 'material de lectura', 'materiales de lectura')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => DefaultTabController.of(tabContext).animateTo(1),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Ver trabajo'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final tareasCalificables = _tareas.where((t) => t.tipo.seCalifica).toList();
    final pendientes = tareasCalificables.where((t) {
      final entrega = _entregasPorTarea[t.id];
      return entrega == null ||
          entrega.estado == EstadoEntrega.asignada ||
          entrega.estado == EstadoEntrega.reclamada;
    }).toList();

    DateTime? proximoVencimiento;
    for (final t in pendientes) {
      if (t.fechaLimite != null) {
        final f = DateTime.tryParse(t.fechaLimite!);
        if (f != null && f.isAfter(DateTime.now())) {
          if (proximoVencimiento == null || f.isBefore(proximoVencimiento)) {
            proximoVencimiento = f;
          }
        }
      }
    }

    final hayPendientes = pendientes.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (hayPendientes
                        ? IncesTheme.advertencia
                        : IncesTheme.exito)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                hayPendientes
                    ? Icons.pending_actions_rounded
                    : Icons.task_alt_rounded,
                size: 20,
                color: hayPendientes
                    ? IncesTheme.advertencia
                    : IncesTheme.exito,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Próximas entregas',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hayPendientes
                        ? (proximoVencimiento != null
                            ? 'Próximo vencimiento: ${formatearFechaHora(proximoVencimiento)}'
                            : plural(pendientes.length, 'asignación pendiente', 'asignaciones pendientes'))
                        : '¡Todo al día! No tienes entregas pendientes',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => DefaultTabController.of(tabContext).animateTo(1),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(hayPendientes ? 'Revisar' : 'Consultar'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cajaNuevoAnuncio() {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        onTap: _cargandoTablon ? null : _crearAnuncio,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          // Wrap permite que el botón baje de línea en pantallas estrechas
          // sin necesidad de LayoutBuilder. Evita el desbordamiento de 10px.
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: const Icon(
                      Icons.campaign_outlined,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Anuncia algo a tu sección...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: _cargandoTablon ? null : _crearAnuncio,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nuevo anuncio'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cabeceraGoogleClassroom() {
    final area = AreaFormativa.resolver(widget.seccionNombre);

    return ClipRRect(
      borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 125),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
          boxShadow: [
            BoxShadow(
              color: area.colorPrimario.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Fotografía vocacional de fondo de alta resolución
            Positioned.fill(
              child: Image.asset(
                area.rutaImagenAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            // Degradado institucional de alto contraste para legibilidad perfecta
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.88),
                      Colors.black.withValues(alpha: 0.70),
                      area.colorPrimario.withValues(alpha: 0.55),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -10,
              bottom: -22,
              child: Opacity(
                opacity: 0.20,
                child: Icon(
                  area.icono,
                  size: 130,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(area.icono, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            area.etiqueta,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Espacio de Aprendizaje Virtual',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'CFS Nacional de Soldadura «Rafael Urdaneta» · La Isabelica',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// El contenido del tablón como **hijos de la lista** del tablón, no como
  /// un scrollable propio: listas dentro de listas se comían los gestos.
  List<Widget> _contenidoTablonComoLista() {
    if (_cargandoTablon) {
      return const [
        SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    // Un fallo de carga se cuenta **sin** vaciar la pantalla: las pestañas
    // siguen ahí y la otra sigue funcionando. Es la diferencia entre un feed
    // incompleto y una pantalla muerta.
    if (_errorTablon != null) {
      return [
        AvisoEnLinea(
          tono: TonoAviso.peligro,
          icono: Icons.cloud_off_outlined,
          texto: 'No pudimos cargar el tablón: $_errorTablon',
        ),
      ];
    }

    if (_anuncios.isEmpty) {
      return const [
        PanelVacio(
          titulo: 'Todavía no hay anuncios',
          mensaje: 'Cuando el docente publique algo en el tablón de esta '
              'sección, aparecerá aquí.',
          icono: Icons.campaign_outlined,
        ),
      ];
    }

    // **Sin reordenar.** El servidor ya entrega el feed de más reciente a más
    // antiguo; un segundo criterio de orden aquí sería una segunda fuente de
    // verdad que se desvía de la del feed en cuanto una cambie.
    return [for (final anuncio in _anuncios) _tarjetaAnuncio(anuncio)];
  }

  Widget _tarjetaAnuncio(Anuncio anuncio) {
    final theme = Theme.of(context);
    final titulo = anuncio.titulo
        .replaceAll(RegExp(r'\s*\[SEMILLA\]\s*', caseSensitive: false), '')
        .trim();
    var cuerpo = anuncio.cuerpo;
    if (cuerpo.contains('Anuncio creado por el sembrado') ||
        cuerpo.contains('El tablón de M6 ya tiene contenido')) {
      cuerpo =
          'Bienvenidos al espacio virtual de aprendizaje. Aquí encontrarás '
          'las orientaciones del facilitador, materiales de estudio y asignaciones '
          'prácticas para el desarrollo de tus competencias técnicas.';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.campaign_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(titulo, style: theme.textTheme.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(cuerpo, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Etiqueta(
              texto: formatearFechaHora(DateTime.tryParse(anuncio.publicadoEn ?? '')),
            ),
          ],
        ),
      ),
    );
  }

  String _sanitizarTituloTarea(String raw) {
    var t = raw.replaceAll(RegExp(r'\s*\[SEMILLA\]\s*', caseSensitive: false), '').trim();
    if (t.contains('Tarea E2E [ciclo]')) {
      final partes = t.split('Tarea E2E [ciclo]');
      final sufijo = partes.length > 1 ? partes[1].trim() : '';
      final cod = sufijo.length > 4 ? sufijo.substring(sufijo.length - 4) : sufijo;
      t = 'Práctica Técnica de Taller #$cod';
    }
    return t;
  }

  // ── Trabajo de clase ───────────────────────────────────────────────────────

  Widget _trabajoDeClase() {
    final contenido = _contenidoTrabajo();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.esDocente)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _cargandoClase ? null : _crearTarea,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nueva tarea'),
            ),
          )
        else
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: IncesTheme.azulPrimario.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: IncesTheme.azulPrimario.withValues(alpha: 0.20),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.assignment_turned_in_rounded,
                  color: IncesTheme.azulPrimario,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Para consignar tu práctica técnica, pulsa en «Entregar trabajo», '
                    'adjunta tus evidencias (fotos de piezas y cordones de soldadura, informes o planos) y confirma el envío.',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      height: 1.4,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Expanded(child: contenido),
      ],
    );
  }

  Widget _contenidoTrabajo() {
    if (_cargandoClase) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorTrabajo != null) {
      return ListView(
        children: [
          AvisoEnLinea(
            tono: TonoAviso.peligro,
            icono: Icons.cloud_off_outlined,
            texto: 'No pudimos cargar el trabajo de clase: $_errorTrabajo',
          ),
        ],
      );
    }

    return ListView(
      children: [
        // Un fallo de las entregas no impide ver las tareas: se avisa y se
        // siguen pintando, sólo que sin el estado de cada una.
        if (_errorEntregas != null) ...[
          AvisoEnLinea(
            tono: TonoAviso.advertencia,
            icono: Icons.assignment_late_outlined,
            texto: 'No pudimos cargar tus entregas: $_errorEntregas El estado de '
                'cada tarea no se puede mostrar ahora mismo.',
          ),
          const SizedBox(height: 12),
        ],
        if (_tareas.isEmpty)
          const PanelVacio(
            titulo: 'Todavía no hay trabajo de clase',
            mensaje: 'Cuando el docente publique una tarea o un material, '
                'aparecerá aquí.',
            icono: Icons.assignment_outlined,
          )
        else
          for (final tarea in _tareas) _tarjetaTarea(tarea),
      ],
    );
  }

  Widget _tarjetaTarea(TareaDeClase tarea) {
    final theme = Theme.of(context);
    final entrega = widget.esDocente ? null : _entregasPorTarea[tarea.id];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Abrir el detalle es lo que lleva al gestor documental del alumno.
        onTap: () => setState(() => _tareaAbierta = tarea),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_iconoTipo(tarea.tipo), size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _sanitizarTituloTarea(tarea.titulo),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tarea.descripcion,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Etiqueta(texto: _etiquetaTipo(tarea.tipo)),
                  // **Un material no lleva puntos ni fecha.** El modelo trae
                  // `puntosMaximos == 0` y `fechaLimite == null` por diseño, y
                  // pintarlos sería un «0 pts» y una fecha vacía sobre material
                  // de lectura: una mentira sobre lo que la tarea es.
                  if (tarea.tipo.seCalifica) ...[
                    Etiqueta(texto: '${_formatoPuntos(tarea.puntosMaximos)} pts'),
                    if (tarea.fechaLimite != null)
                      Etiqueta(
                        texto:
                            'Vence ${formatearFechaHora(DateTime.tryParse(tarea.fechaLimite!))}',
                      ),
                  ],
                  if (entrega != null) _insigniaEntrega(entrega, tarea),
                ],
              ),
              if (widget.esDocente)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _abrirLibro(tarea),
                      icon: const Icon(Icons.grading_outlined, size: 16),
                      label: const Text('Calificar'),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: () => setState(() => _tareaAbierta = tarea),
                      icon: Icon(
                        entrega?.estado == EstadoEntrega.entregada ||
                                entrega?.estado == EstadoEntrega.devuelta
                            ? Icons.check_circle_outline_rounded
                            : Icons.upload_file_rounded,
                        size: 16,
                      ),
                      label: Text(
                        entrega?.estado == EstadoEntrega.entregada
                            ? 'Ver mi entrega enviada'
                            : entrega?.estado == EstadoEntrega.devuelta
                                ? 'Ver calificación y comentarios'
                                : 'Entregar trabajo',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Insignia del estado de la entrega del estudiante.
  ///
  /// «Faltante» —no entregó y venció— **se deriva aquí**, no se lee de un campo:
  /// el backend no guarda un estado «faltante» a propósito (§4.3), así que la UI
  /// lo compone con el reloj. Es la única forma de que un alumno que entregue
  /// tarde deje de aparecer como faltante sin que nadie reescriba una fila.
  Widget _insigniaEntrega(Entrega entrega, TareaDeClase tarea) {
    final vencidaSinEntregar = entrega.estado == EstadoEntrega.asignada &&
        tarea.fechaLimite != null &&
        DateTime.now().isAfter(DateTime.tryParse(tarea.fechaLimite!) ?? DateTime.now());

    // El color sale de la paleta, y no de `IncesTheme` ni del `ColorScheme`. Los
    // acentos de `IncesTheme` son de **relleno**: como letra sobre su propio
    // tinte, el ámbar da 1.81:1 en claro. Y `colorScheme.primary` —el azul de
    // marca— da 8.29:1 en claro pero **1.99:1 en oscuro**, porque en oscuro el
    // primario es `#0059B3` y sobre un tinte oscuro no se lee. Medido el
    // 2026-09-30.
    final paleta = PaletaInces.de(context);
    final (color, texto) = switch (entrega.estado) {
      EstadoEntrega.asignada => (paleta.advertencia, 'Pendiente'),
      EstadoEntrega.entregada => (paleta.exito, 'Entregada'),
      EstadoEntrega.devuelta => (paleta.info, 'Devuelta'),
      EstadoEntrega.reclamada => (paleta.neutro, 'Reclamada'),
    };

    final etiquetaNota = entrega.estado == EstadoEntrega.devuelta &&
            entrega.notaAsignada != null
        ? ' · ${_formatoNota(entrega.notaAsignada!)} pts'
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconoEntrega(entrega.estado), size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            '$texto$etiquetaNota',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          // La tarea vencida sin entregar sigue siendo «Pendiente», pero se
          // marca: el estado real —no entregada— y el aviso de que ya venció son
          // dos cosas distintas y el alumno necesita las dos.
          if (vencidaSinEntregar) ...[
            const SizedBox(width: 6),
            Text(
              '· Vencida',
              // Cae sobre el tinte **ámbar** del chip —no sobre el suyo—, así que
              // se mide contra ése: 4.92:1 en el peor de los dos fondos. Medido
              // el 2026-09-30. El rojo de marca daba 2.74:1 en oscuro.
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: paleta.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Detalle de una tarea ───────────────────────────────────────────────────

  Widget _detalleDeTarea(TareaDeClase tarea) {
    final theme = Theme.of(context);
    final entrega = widget.esDocente ? null : _entregasPorTarea[tarea.id];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _tareaAbierta = null),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Volver al trabajo de clase'),
          ),
        ),
        const SizedBox(height: 4),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_sanitizarTituloTarea(tarea.titulo), style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                // La descripción se acota a unas líneas: el detalle comparte una
                // altura **acotada** con el gestor documental de abajo (que es
                // un `ListView`), y una cabecera que creciera sin límite lo
                // empujaría fuera de la pantalla.
                Text(
                  tarea.descripcion,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Etiqueta(texto: _etiquetaTipo(tarea.tipo)),
                    if (tarea.tipo.seCalifica) ...[
                      Etiqueta(texto: '${_formatoPuntos(tarea.puntosMaximos)} pts'),
                      if (tarea.fechaLimite != null)
                        Etiqueta(
                          texto: 'Vence ${formatearFechaHora(DateTime.tryParse(tarea.fechaLimite!))}',
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _cuerpoDetalle(tarea, entrega)),
      ],
    );
  }

  Widget _cuerpoDetalle(TareaDeClase tarea, Entrega? entrega) {
    // Docente: su panel de entrega del alumno no existe (esa vista es del
    // estudiante); en su lugar abre el libro de calificaciones de esta tarea,
    // que es donde califica y devuelve. La acción está aquí —y no sólo en la
    // tarjeta— porque desde el detalle ya tiene la tarea enfocada.
    if (widget.esDocente) {
      return ListView(
        children: [
          FilledButton.icon(
            onPressed: () => _abrirLibro(tarea),
            icon: const Icon(Icons.grading_outlined, size: 18),
            label: const Text('Ver libro de calificaciones'),
          ),
          const SizedBox(height: 12),
          const AvisoEnLinea(
            icono: Icons.info_outline,
            texto: 'Desde aquí calificas las entregas de esta tarea y las '
                'devuelves a tus estudiantes. Una vez devuelta, la nota deja de '
                'ser borrador y el alumno la ve.',
          ),
        ],
      );
    }

    // Estudiante sin entrega: no debería pasar (los placeholders se crean al
    // publicar, D-7), así que en vez de fingir un estado se dice.
    if (entrega == null) {
      return ListView(
        children: const [
          AvisoEnLinea(
            tono: TonoAviso.advertencia,
            icono: Icons.assignment_late_outlined,
            texto: 'Esta tarea todavía no tiene una entrega tuya asignada, así '
                'que aún no puedes subir el trabajo. Vuelve a intentarlo más '
                'tarde o avisa a tu docente.',
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _barraDeEntrega(entrega),
        const SizedBox(height: 12),
        // **Aquí está el objetivo de la fase.** El `entidadId` es el
        // `m6_entregas.id`: es la unión que deja al docente ver esta entrega
        // desde las políticas de M6 sobre `files_metadata` (§3.3). Pasar
        // cualquier otro id —el de la tarea, por ejemplo— colgaría el archivo
        // de una entidad que no existe para el docente, sin dar error.
        Expanded(
          child: GestorDocumentalPanel(
            entityType: TipoEntidadArchivo.taskSubmission,
            entidadId: entrega.id,
            titulo: 'Evidencias de la entrega',
            subtitulo:
                'Fotografías de piezas o cordones de soldadura, planos o informes técnicos (PDF, JPG, PNG)',
            repositorio: widget.archivosRepositorio,
            selector: widget.selectorArchivos,
          ),
        ),
      ],
    );
  }

  /// Estado de la entrega y, si procede, la acción de entregar o reclamar.
  Widget _barraDeEntrega(Entrega entrega) {
    final ocupada = _ocupadas.contains(entrega.id);

    // La acción depende del estado: `ASIGNADA`/`RECLAMADA` se entregan,
    // `ENTREGADA` se reclama, y una `DEVUELTA` ya no admite ninguna (el docente
    // cerró el ciclo). Devolver `null` en vez de un botón deshabilitado evita
    // ofrecer una acción que no existe.
    final (accion, etiqueta) = switch (entrega.estado) {
      EstadoEntrega.asignada => (_entregar, 'Entregar tarea'),
      EstadoEntrega.reclamada => (_entregar, 'Volver a entregar'),
      EstadoEntrega.entregada => (_reclamar, 'Reclamar entrega'),
      EstadoEntrega.devuelta => (null, ''),
    };

    final nota = entrega.estado == EstadoEntrega.devuelta &&
            entrega.notaAsignada != null
        ? 'Nota: ${_formatoNota(entrega.notaAsignada!)} pts.'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AvisoEnLinea(
          tono: switch (entrega.estado) {
            EstadoEntrega.asignada => TonoAviso.advertencia,
            EstadoEntrega.entregada => TonoAviso.exito,
            EstadoEntrega.devuelta => TonoAviso.info,
            EstadoEntrega.reclamada => TonoAviso.advertencia,
          },
          icono: _iconoEntrega(entrega.estado),
          texto: [
            _etiquetaEntregaLarga(entrega.estado),
            if (entrega.esTardia) 'La entregaste después de la fecha límite.',
            ?nota,
          ].join(' '),
        ),
        if (accion != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: ocupada ? null : () => accion(entrega),
              icon: ocupada
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text(ocupada ? 'Procesando…' : etiqueta),
            ),
          ),
        ],
      ],
    );
  }

  // ── Etiquetas y utilidades ─────────────────────────────────────────────────

  IconData _iconoTipo(TipoTarea tipo) => switch (tipo) {
        TipoTarea.tarea => Icons.assignment_outlined,
        TipoTarea.material => Icons.menu_book_outlined,
        TipoTarea.pregunta => Icons.help_outline,
      };

  String _etiquetaTipo(TipoTarea tipo) => switch (tipo) {
        TipoTarea.tarea => 'Tarea',
        TipoTarea.material => 'Material',
        TipoTarea.pregunta => 'Pregunta',
      };

  IconData _iconoEntrega(EstadoEntrega estado) => switch (estado) {
        EstadoEntrega.asignada => Icons.schedule_outlined,
        EstadoEntrega.entregada => Icons.check_circle_outline,
        EstadoEntrega.devuelta => Icons.assignment_turned_in_outlined,
        EstadoEntrega.reclamada => Icons.undo_outlined,
      };

  String _etiquetaEntregaLarga(EstadoEntrega estado) => switch (estado) {
        EstadoEntrega.asignada => 'Pendiente de entrega.',
        EstadoEntrega.entregada => 'Entregada.',
        EstadoEntrega.devuelta => 'Devuelta por el docente.',
        EstadoEntrega.reclamada => 'Reclamada: puedes volver a subirla.',
      };

  /// Puntos sin decimales de adorno: «20 pts» y no «20,0 pts».
  String _formatoPuntos(double puntos) => _formatoNota(puntos);

  /// Nota en la escala 0–20, con coma decimal y sin ceros de relleno.
  String _formatoNota(double nota) {
    if (nota == nota.roundToDouble()) return nota.toStringAsFixed(0);
    return nota.toStringAsFixed(1).replaceAll('.', ',');
  }
}
