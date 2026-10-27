import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/config/app_config.dart';
import '../theme/inces_theme.dart';
import 'comunes.dart';
import 'guardia_toque.dart';
import 'responsivo.dart';

/// Ítem del menú lateral, con su categoría.
class ItemNavegacion {
  const ItemNavegacion({
    required this.icono,
    required this.titulo,
    required this.categoria,
    this.etiquetaCorta,
    this.disponible = true,
    this.pendiente,
    this.modulo,
  });

  final IconData icono;
  final String titulo;

  /// Etiqueta CORTA para la barra inferior (`compact`), donde cinco destinos
  /// tienen ~78 px cada uno y un título largo se amontona.
  ///
  /// **Por qué existe.** Medido el 2026-10-21 en la captura a 390 px: con
  /// [titulo] («Módulos del Sistema», «Historial de Configuración») la barra
  /// inferior se veía amontonada e ilegible. Material 3 resuelve esto con
  /// etiquetas de una o dos palabras («Módulos», «Historial»), que es lo que
  /// hacen las apps de Google. Si es `null`, se usa [titulo].
  final String? etiquetaCorta;

  /// Agrupador visible en el menú: *Gestión Académica*, *Control de Aulas*…
  final String categoria;

  /// `false` ⇒ la sección no es pulsable. Se muestra atenuada y sin acción, en
  /// vez de llevar a una pantalla vacía.
  ///
  /// Lo que declara esta bandera es **si la pantalla existe**, que es un hecho
  /// del código. Que el módulo del que depende esté encendido es un hecho
  /// **del servidor** y se aplica encima en tiempo de ejecución — ver [modulo].
  final bool disponible;

  /// Por qué está apagada, cuando **no** es «todavía no existe».
  ///
  /// `null` ⇒ el tooltip cae al mensaje genérico («pendiente de construir»). Se
  /// usa para la sección que **sí existe** pero vive en otro sitio: sin esto el
  /// menú afirmaría que falta algo que está construido, y quien lo busca no lo
  /// encuentra. El caso real es «Calificaciones» en el panel del docente: el
  /// libro de notas existe desde M6 y está a un clic, dentro de cada aula.
  ///
  /// **No puede contener paréntesis.** `test/menu_alcanzable_test.dart` delimita
  /// cada `ItemNavegacion(…)` con el primer `),` que encuentra, y un paréntesis
  /// dentro del texto cortaría el bloque por la mitad.
  final String? pendiente;

  /// Clave del módulo de `system_modules` que gobierna esta sección, o `null`.
  ///
  /// `null` ⇒ la sección no depende de ningún módulo conmutable (el perfil
  /// propio, la ficha del aspirante): apagarla no es una opción del cPanel.
  ///
  /// Cuando tiene valor, el estado real de ese módulo decide si la sección es
  /// pulsable. Antes esa decisión **no existía**: los tres dashboards escribían
  /// `disponible:` a mano y nadie leía `system_modules`, así que apagar
  /// `m6_aula_virtual` desde el cPanel dejaba «Mis aulas» encendida y el clic
  /// devolvía **403**. El menú afirmaba que había algo al otro lado.
  ///
  /// La traducción de clave a «está apagado» la hace
  /// `aplicarEstadoDeModulos` en `lib/widgets/modulos_del_menu.dart`, que es
  /// también donde vive la razón de que un módulo **desconocido** no apague
  /// nada.
  ///
  /// Sólo se mira `habilitado`, **nunca** `roles_permitidos`: esa lista dice
  /// quién puede usar las rutas del módulo, no quién puede ver el menú.
  /// `m7_asistencia` la tiene en `['docente','admin']` y aun así el aprendiz
  /// necesita su sección para marcar — es el rol que marca (D19).
  final String? modulo;

  /// Copia apagada por culpa de su módulo, con el motivo ya redactado.
  ///
  /// Existe en vez de un `copyWith` porque el motivo y la bandera van juntos
  /// siempre: un `copyWith` permitiría apagar la sección y dejar el motivo
  /// viejo, o al revés, y esas dos combinaciones no significan nada.
  ItemNavegacion apagadoPorModulo(String motivo) => ItemNavegacion(
        icono: icono,
        titulo: titulo,
        categoria: categoria,
        disponible: false,
        pendiente: motivo,
        modulo: modulo,
      );
}

/// Andamiaje de la aplicación: barra lateral replegable, encabezado y contenido.
///
/// Existe para que el dashboard del administrador, el del docente y el del
/// estudiante compartan una sola estructura. Antes cada uno montaba su propio
/// `Scaffold` con sus colores, y por eso se veían como tres aplicaciones
/// distintas.
class AndamiajeApp extends StatefulWidget {
  const AndamiajeApp({
    super.key,
    required this.items,
    required this.seleccionado,
    required this.onSeleccionar,
    required this.rolEtiqueta,
    required this.contenido,
    this.nombreUsuario,
    this.correoUsuario,
    this.periodoActivo,
    this.accionesEncabezado = const [],
    this.onCerrarSesion,
    this.temaActual,
    this.onCambiarTema,
  });

  final List<ItemNavegacion> items;
  final int seleccionado;
  final ValueChanged<int> onSeleccionar;
  final String rolEtiqueta;
  final Widget contenido;

  final String? nombreUsuario;
  final String? correoUsuario;
  final String? periodoActivo;
  final List<Widget> accionesEncabezado;
  final VoidCallback? onCerrarSesion;

  /// Tema vigente, para marcar cuál está elegido en el selector del pie.
  ///
  /// Nulable por el mismo motivo que [onCambiarTema]: quien no ofrece el
  /// selector no tiene por qué declarar un tema.
  final ThemeMode? temaActual;

  /// Cambia el tema de la aplicación.
  ///
  /// **`null` ⇒ el selector no se dibuja.** Es la convención que ya usa
  /// [onCerrarSesion], y aquí no es un detalle de estilo: hay pruebas que montan
  /// este andamiaje **sin ningún proveedor de tema** —`menu_alcanzable_test.dart`
  /// lo monta con un `SizedBox` de contenido, y `aula_produccion_test.dart` y
  /// `menu_gobernado_por_modulos_test.dart` montan el panel del docente, que lo
  /// incluye—. Un selector incondicional obligaría a todas ellas a inventarse un
  /// proveedor para poder montar el widget que están probando, y la prueba
  /// mediría otra cosa.
  final ValueChanged<ThemeMode>? onCambiarTema;

  @override
  State<AndamiajeApp> createState() => _AndamiajeAppState();
}

class _AndamiajeAppState extends State<AndamiajeApp> {
  /// El menú arranca replegado en pantallas medianas para dar más sitio al
  /// contenido, y extendido en las grandes.
  bool _replegado = false;
  bool _inicializado = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // El antiguo `_anchoEscritorio = 900` se retiró: la frontera entre menú fijo
  // y navegación adaptativa la decide ahora `ventanaActual(context)`
  // (`responsivo.dart`), con los umbrales canónicos de Material 3 —840 para
  // `expanded`—. Dejarlo aquí sería un segundo umbral que se desvía.

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inicializado) return;
    _inicializado = true;

    // Sólo se calcula una vez. Si se recalculara en cada `build`, cambiar el
    // tamaño de la ventana revertiría el replegado que el usuario eligió.
    final ancho = MediaQuery.sizeOf(context).width;
    _replegado = ancho < 1280;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ventana = ventanaActual(context);
    // `medium` y por debajo: el menú lateral fijo no cabe sin robar ancho.
    // En `medium` se sustituye por un **rail**; en `compact`, por una barra de
    // navegación inferior —que es donde Google pone los destinos en el móvil— y
    // el cajón queda para el resto de secciones y para el pie (tema, sesión).
    // **Rail también en `expanded` (840–1199).** Medido el 2026-10-21: con el
    // menú permanente de 280 px a 840, el contenido quedaba en 1 columna y el
    // sidebar se veía como una columna entera. Material 3 pide *rail* en
    // `expanded` y menú permanente sólo en `large`/`xlarge` (≥1200). El rail
    // (≈80 px) deja ~760 px de contenido a 840 → 2 columnas.
    final usaRail =
        ventana == Ventana.medium || ventana == Ventana.expanded;
    final usaBarraInferior = ventana == Ventana.compact;
    final menuLateralFijo =
        ventana == Ventana.large || ventana == Ventana.xlarge;

    // Los destinos de la barra inferior: los cuatro primeros disponibles y,
    // si hay más, un quinto «Más» que abre el cajón. Es la misma regla de
    // Material 3 para la barra inferior (máximo cinco destinos).
    final disponibles = widget.items
        .where((i) => i.disponible)
        .toList(growable: false);
    final destinoBarra = disponibles.take(4).toList(growable: false);
    final hayMas = disponibles.length > destinoBarra.length;

    return Scaffold(
      key: _scaffoldKey,
      drawer: !menuLateralFijo
          ? Drawer(
              width: IncesTheme.anchoMenu,
              backgroundColor: theme.colorScheme.surface,
              child: _MenuLateral(
                items: widget.items,
                seleccionado: widget.seleccionado,
                replegado: false,
                onSeleccionar: (i) {
                  widget.onSeleccionar(i);
                  Navigator.of(context).pop();
                },
                onCerrarSesion: widget.onCerrarSesion,
                rolEtiqueta: widget.rolEtiqueta,
                correoUsuario: widget.correoUsuario,
                temaActual: widget.temaActual,
                onCambiarTema: widget.onCambiarTema,
              ),
            )
          : null,
      // El cajón se abre desde el encabezado en `compact`; en `medium` lo abre
      // el propio rail, así que ahí no hace falta el botón del encabezado.
      body: Row(
        children: [
          if (usaRail)
            _RailNavegacion(
              items: widget.items,
              seleccionado: widget.seleccionado,
              onSeleccionar: widget.onSeleccionar,
              onAbrirCajon: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          if (menuLateralFijo)
            _MenuLateral(
              items: widget.items,
              seleccionado: widget.seleccionado,
              replegado: _replegado,
              onSeleccionar: widget.onSeleccionar,
              onCerrarSesion: widget.onCerrarSesion,
              rolEtiqueta: widget.rolEtiqueta,
              correoUsuario: widget.correoUsuario,
              temaActual: widget.temaActual,
              onCambiarTema: widget.onCambiarTema,
              onAlternarReplegado: () =>
                  setState(() => _replegado = !_replegado),
            ),
          Expanded(
            child: Column(
              children: [
                EncabezadoInstitucional(
                  rolEtiqueta: widget.rolEtiqueta,
                  nombreUsuario: widget.nombreUsuario,
                  correoUsuario: widget.correoUsuario,
                  periodoActivo: widget.periodoActivo,
                  acciones: widget.accionesEncabezado,
                  // Este `context` pertenece al estado que está por encima
                  // del `Scaffold`; `Scaffold.of(context)` no puede encontrarlo
                  // desde aquí y falla al pulsar el menú en móvil. La clave
                  // apunta al Scaffold real, tanto en móvil como al
                  // redimensionar.
                  onAbrirMenu: menuLateralFijo
                      ? null
                      : () => _scaffoldKey.currentState?.openDrawer(),
                ),
                // **Transición al cambiar de sección: fade-through, la canónica
                // de Material 3** para destinos de primer nivel. Antes el panel
                // nuevo aparecía de golpe: el salto se leía como un fallo, no
                // como navegación. El fade-through (fundido de salida, leve
                // escala, fundido de entrada) es lo que usan Drive, Gmail y
                // Classroom, y es la que hace que el cambio se sienta smooth en
                // vez de instantáneo.
                //
                // La clave es el índice de la sección: sin ella, dos paneles del
                // mismo tipo no se considerarían distintos y no habría nada que
                // animar. El coste es que el panel se reconstruye al entrar —
                // que es lo que ya ocurría, porque cada sección es otro widget.
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (current, previous) => Stack(
                      children: [
                        ...previous.map((h) => Positioned.fill(child: h)),
                        if (current != null) Positioned.fill(child: current),
                      ],
                    ),
                    // `FadeThroughTransition` no está pública en este SDK, así
                    // que la animación se compone a mano con lo que sí es
                    // público y produce el mismo efecto: fundido de entrada con
                    // una escala que arranca en 0.97. La escala es sutil a
                    // propósito —basta para que el panel «llegue» en vez de
                    // «aparecer», y no roba ni un píxel de legibilidad.
                    transitionBuilder: (hijo, animacion) {
                      final escala = Tween<double>(
                        begin: 0.97,
                        end: 1,
                      ).animate(
                        CurvedAnimation(
                          parent: animacion,
                          curve: Curves.easeOutCubic,
                        ),
                      );
                      return FadeTransition(
                        opacity: animacion,
                        child: ScaleTransition(
                          scale: escala,
                          child: hijo,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey('seccion-${widget.seleccionado}'),
                      child: ventana == Ventana.xlarge
                          ? contenidoCentrado(widget.contenido)
                          : widget.contenido,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          usaBarraInferior && (destinoBarra.length + (hayMas ? 1 : 0) >= 2)
              ? _BarraInferiorNavegacion(
                  destinos: destinoBarra,
                  hayMas: hayMas,
                  seleccionado: widget.seleccionado,
                  items: disponibles,
                  onSeleccionar: widget.onSeleccionar,
                  onAbrirCajon: () => _scaffoldKey.currentState?.openDrawer(),
                )
              : null,
    );
  }
}

/// Barra de navegación inferior: los destinos de `compact` (< 600 px).
///
/// **Por qué existe.** En el móvil, un menú lateral es un destino escondido
/// detrás de un botón: cada cambio de sección cuesta dos toques. Google pone
/// los destinos principales abajo, siempre visibles, y deja el cajón para el
/// resto —perfil, tema, cerrar sesión—. Es el patrón de Material 3 para
/// ventana `compact`, y es lo que hacía falta aquí: el andamiaje sólo tenía
/// «fijo o cajón», así que en el teléfono todo estaba escondido.
///
/// El quinto destino es «Más», no un quinto ítem: la barra inferior admite como
/// máximo cinco destinos, y el centro tiene más de cinco secciones.
class _BarraInferiorNavegacion extends StatelessWidget {
  const _BarraInferiorNavegacion({
    required this.destinos,
    required this.hayMas,
    required this.seleccionado,
    required this.items,
    required this.onSeleccionar,
    required this.onAbrirCajon,
  });

  final List<ItemNavegacion> destinos;
  final bool hayMas;
  final int seleccionado;
  final List<ItemNavegacion> items;
  final ValueChanged<int> onSeleccionar;
  final VoidCallback onAbrirCajon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NavigationBar(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      destinations: [
        for (final item in destinos)
          NavigationDestination(
            icon: Icon(item.icono),
            // Etiqueta corta en la barra: cinco destinos a 390 px son ~78 px
            // cada uno; un título largo se amontona (medido 2026-10-21).
            label: item.etiquetaCorta ?? item.titulo,
            tooltip: item.titulo,
          ),
        if (hayMas)
          const NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            label: 'Más',
          ),
      ],
      // Si la sección elegida está entre los cuatro de la barra, se marca. Si
      // no, se marca «Más» —el destino que abre el cajón donde sí está—, que es
      // lo que hace Google cuando estás en una sección que no cabe en la barra.
      // `NavigationBar` no admite «ninguno», así que «Más» es la forma honesta
      // de no marcar un destino que no es el actual.
      selectedIndex: seleccionado < destinos.length
          ? seleccionado
          : destinos.length,
      onDestinationSelected: (indice) {
        if (hayMas && indice == destinos.length) {
          onAbrirCajon();
          return;
        }
        final item = destinos[indice];
        onSeleccionar(items.indexOf(item));
      },
    );
  }
}

/// Rail de navegación: los destinos de `medium` (600 – 839 px).
///
/// **Por qué existe y no el cajón.** A ese ancho, el menú lateral fijo roba
/// demasiado y el cajón esconde demasiado. El rail es el término medio de
/// Material 3: iconos siempre visibles, etiquetas debajo, y un botón arriba que
/// abre el cajón con el resto de la aplicación (pie de tema, sesión y las
/// secciones que no caben como destino).
class _RailNavegacion extends StatelessWidget {
  const _RailNavegacion({
    required this.items,
    required this.seleccionado,
    required this.onSeleccionar,
    required this.onAbrirCajon,
  });

  final List<ItemNavegacion> items;
  final int seleccionado;
  final ValueChanged<int> onSeleccionar;
  final VoidCallback onAbrirCajon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NavigationRail(
      backgroundColor: theme.colorScheme.surface,
      selectedIndex: seleccionado < items.length ? seleccionado : null,
      onDestinationSelected: onSeleccionar,
      // Rail SOLO iconos (≈80 px), no «rail extendido» con etiquetas (≈256 px).
      // Medido el 2026-10-21: con `labelType.all` el rail ocupaba casi lo mismo
      // que el menú permanente y el contenido seguía apretado. Material 3 usa
      // el rail compacto de iconos; las etiquetas completas están en el cajón
      // (hamburguesa) y en los tooltips.
      labelType: NavigationRailLabelType.none,
      leading: IconButton(
        tooltip: 'Abrir menú completo',
        icon: const Icon(Icons.menu_rounded),
        onPressed: onAbrirCajon,
      ),
      destinations: [
        for (final item in items)
          if (item.disponible)
            NavigationRailDestination(
              icon: Icon(item.icono),
              label: Text(item.titulo),
            ),
      ],
    );
  }
}

/// Menú lateral, por categorías y replegable.
class _MenuLateral extends StatelessWidget {
  const _MenuLateral({
    required this.items,
    required this.seleccionado,
    required this.replegado,
    required this.onSeleccionar,
    required this.rolEtiqueta,
    this.correoUsuario,
    this.onCerrarSesion,
    this.onAlternarReplegado,
    this.temaActual,
    this.onCambiarTema,
  });

  final List<ItemNavegacion> items;
  final int seleccionado;
  final bool replegado;
  final ValueChanged<int> onSeleccionar;
  final String rolEtiqueta;
  final String? correoUsuario;
  final VoidCallback? onCerrarSesion;
  final VoidCallback? onAlternarReplegado;
  final ThemeMode? temaActual;
  final ValueChanged<ThemeMode>? onCambiarTema;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;

    // Las categorías se derivan de los ítems, en orden de aparición. Así añadir
    // un módulo nuevo a una categoría existente no exige tocar este archivo.
    final categorias = <String, List<int>>{};
    for (var i = 0; i < items.length; i++) {
      categorias.putIfAbsent(items[i].categoria, () => []).add(i);
    }

    return AnimatedContainer(
      // La animación del ancho es lo que hace que replegar se sienta fluido en
      // vez de instantáneo. 200 ms es lo bastante corto para no estorbar.
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: replegado ? IncesTheme.anchoMenuReplegado : IncesTheme.anchoMenu,
      decoration: BoxDecoration(
        color: esOscuro
            ? IncesTheme.superficieOscura
            : IncesTheme.superficieClara,
        border: Border(right: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Cabecera del menú: identidad y botón de replegado -------------
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: replegado ? 12 : 16,
                vertical: 16,
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: IncesTheme.degradadoAzul,
                      borderRadius:
                          BorderRadius.circular(IncesTheme.radioControl),
                    ),
                    child: Text(
                      'I',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (!replegado) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'INCES LMS',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'La Isabelica',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onAlternarReplegado != null)
                      IconButton(
                        tooltip: 'Replegar menú',
                        onPressed: onAlternarReplegado,
                        iconSize: 18,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),

            // --- Ítems, agrupados por categoría --------------------------------
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final entrada in categorias.entries) ...[
                    if (!replegado)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: Text(
                          entrada.key.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 8),
                    for (final indice in entrada.value)
                      _ItemMenu(
                        item: items[indice],
                        seleccionado: seleccionado == indice,
                        replegado: replegado,
                        onTap: () => onSeleccionar(indice),
                      ),
                  ],
                ],
              ),
            ),

            // --- Pie: tema, replegar (cuando no hay cabecera) y cerrar sesión --
            const Divider(height: 1),
            if (replegado && onAlternarReplegado != null)
              IconButton(
                tooltip: 'Desplegar menú',
                onPressed: onAlternarReplegado,
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
              ),
            // El tema va aquí, en el pie, y no en el encabezado: es una
            // preferencia del usuario, no una acción del contexto de trabajo, y
            // el encabezado ya lleva el período activo y las acciones de la
            // sección. En el pie queda visible desde **todas** las pantallas,
            // que es la condición que se pidió para poder ponerlo.
            if (onCambiarTema != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: _SelectorDeTema(
                  actual: temaActual ?? ThemeMode.system,
                  onCambiar: onCambiarTema!,
                  replegado: replegado,
                ),
              ),
            if (onCerrarSesion != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton.icon(
                  onPressed: onCerrarSesion,
                  icon: Icon(
                    Icons.logout_rounded,
                    size: 17,
                    color: theme.colorScheme.error,
                  ),
                  label: replegado
                      ? const SizedBox.shrink()
                      : Text(
                          'Cerrar sesión',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.error,
                          ),
                        ),
                  style: TextButton.styleFrom(
                    alignment: replegado
                        ? Alignment.center
                        : Alignment.centerLeft,
                    padding: EdgeInsets.symmetric(
                      horizontal: replegado ? 0 : 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                replegado ? 4 : 16,
                4,
                replegado ? 4 : 16,
                12,
              ),
              child: replegado
                  ? Center(
                      child: Tooltip(
                        message: AppConfig.versionLabel,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'v${AppConfig.version}',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Row(
                           children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: IncesTheme.versionActiva,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'INCES LMS v${AppConfig.version}',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Text(
                            'CFS Rafael Urdaneta · v${AppConfig.version} (2026)',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  const _ItemMenu({
    required this.item,
    required this.seleccionado,
    required this.replegado,
    required this.onTap,
  });

  final ItemNavegacion item;
  final bool seleccionado;
  final bool replegado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final color = seleccionado
        ? theme.colorScheme.primary
        : item.disponible
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45);

    final contenido = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      margin: EdgeInsets.symmetric(horizontal: replegado ? 8 : 10, vertical: 2),
      padding: EdgeInsets.symmetric(
        horizontal: replegado ? 0 : 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        // El fondo del ítem activo es tenue y no el azul pleno: con azul sólido
        // el texto blanco compite con la franja de marca del encabezado.
        color: seleccionado
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(IncesTheme.radioControl),
        border: seleccionado
            ? Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.25),
              )
            : null,
      ),
      child: Row(
        mainAxisAlignment:
            replegado ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(item.icono, size: 18, color: color),
          if (!replegado) ...[
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                item.titulo,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight:
                      seleccionado ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            if (!item.disponible)
              Icon(
                Icons.construction_outlined,
                size: 13,
                color: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.45),
              ),
          ],
        ],
      ),
    );

    // El mensaje de una sección apagada sale de `item.pendiente` cuando lo hay.
    // «pendiente de construir» es la verdad **por defecto**, pero no siempre lo
    // es —«Calificaciones» del docente existe y vive dentro del aula—, y un
    // mensaje falso sobre algo construido manda al usuario a buscar lo que ya
    // tiene. Replegado manda el título: el icono suelto no comunica nada y ahí
    // la etiqueta no se ve.
    final conTooltip = replegado || !item.disponible
        ? Tooltip(
            message: replegado
                ? item.titulo
                : item.pendiente ?? '${item.titulo} — pendiente de construir',
            child: contenido,
          )
        : contenido;

    // Una sección sin construir no es pulsable: llegar a una pantalla vacía es
    // peor que no poder entrar.
    if (!item.disponible) return conTooltip;

    return InkWell(
      // **Guardia anti rebote.** Dos pulsaciones seguidas sobre el mismo
      // elemento del menú lanzaban dos cambios de sección (y, si la sección
      // abre un diálogo al montar, dos diálogos apilados). La clave es el
      // título del ítem: dos ítems distintos no se sabotan entre sí y el
      // rebote sobre el mismo sí se come. Medido el 2026-10-20 en la demo
      // Lorenzo–Jefe de Centro.
      onTap: () => conGuardia(onTap, 'menu-${item.titulo}'),
      borderRadius: BorderRadius.circular(IncesTheme.radioControl),
      child: conTooltip,
    );
  }
}

// -----------------------------------------------------------------------------
//  Selector de tema
// -----------------------------------------------------------------------------

/// Icono y etiqueta de cada modo de tema.
///
/// Es un `switch` **exhaustivo** y no un `Map`: si Flutter añade un
/// `ThemeMode`, esto deja de compilar. Con un `Map` habría que acordarse de
/// añadir la entrada, y olvidarlo daría un modo sin nombre ni icono —un
/// desplegable con una fila en blanco— sin que nada avisara.
({IconData icono, String etiqueta}) _describirTema(ThemeMode modo) {
  switch (modo) {
    case ThemeMode.system:
      return (icono: Icons.brightness_auto_rounded, etiqueta: 'Sistema');
    case ThemeMode.light:
      return (icono: Icons.light_mode_rounded, etiqueta: 'Claro');
    case ThemeMode.dark:
      return (icono: Icons.dark_mode_rounded, etiqueta: 'Oscuro');
  }
}

/// Selector del tema de la aplicación, para el pie de la barra lateral.
///
/// Un `PopupMenuButton` y no tres botones seguidos: el pie ya tiene el botón de
/// replegar y el de cerrar sesión, y una fila de tres controles de tema ahí
/// competiría con ellos. El menú enseña los tres modos de una vez y marca el
/// vigente, que es lo que hace falta para saber en cuál se está.
///
/// **Sin un solo color literal.** Todos salen de `Theme.of(context)` o del tema
/// heredado, que es la regla que dejó el Bloque B: un `Color(0x…)` escrito aquí
/// se vería bien en un tema y mal en el otro, y
/// `test/theme_literales_test.dart` lo delata.
class _SelectorDeTema extends StatelessWidget {
  const _SelectorDeTema({
    required this.actual,
    required this.onCambiar,
    required this.replegado,
  });

  final ThemeMode actual;
  final ValueChanged<ThemeMode> onCambiar;
  final bool replegado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vigente = _describirTema(actual);

    return PopupMenuButton<ThemeMode>(
      // El tooltip nombra el modo vigente porque replegado sólo se ve el icono,
      // y un icono suelto no dice en cuál se está. Usa la misma etiqueta que la
      // vista desplegada para no crear dos vocabularios para lo mismo.
      tooltip: 'Tema: ${vigente.etiqueta}',
      onSelected: onCambiar,
      // La posición por defecto (`over`) coloca el menú **encima** del botón.
      // Para un elemento del pie es lo correcto: abriéndolo hacia abajo se
      // saldría de la ventana en cuanto la barra llegara al borde inferior.
      itemBuilder: (context) => [
        for (final modo in ThemeMode.values)
          PopupMenuItem<ThemeMode>(
            value: modo,
            child: _OpcionDeTema(
              descripcion: _describirTema(modo),
              seleccionado: modo == actual,
            ),
          ),
      ],
      // Se pasa `child` en vez de `icon` para poder cambiar la forma según el
      // replegado: con `icon`, `PopupMenuButton` dibuja siempre un `IconButton`
      // cuadrado y en la barra desplegada quedaría un icono suelto sin la
      // etiqueta que sí tienen los ítems del menú.
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: replegado ? 0 : 12,
          vertical: 10,
        ),
        child: replegado
            ? Icon(
                vigente.icono,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              )
            : Row(
                children: [
                  Icon(
                    vigente.icono,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      vigente.etiqueta,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.unfold_more_rounded,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Una fila del menú de temas: icono, etiqueta y marca del vigente.
class _OpcionDeTema extends StatelessWidget {
  const _OpcionDeTema({required this.descripcion, required this.seleccionado});

  final ({IconData icono, String etiqueta}) descripcion;
  final bool seleccionado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          descripcion.icono,
          size: 17,
          // `onSurfaceVariant` y no `onSurface`: el menú lo pinta Flutter con su
          // propio color de superficie, y este par es el que el esquema de
          // Material garantiza legible sobre él en los dos temas.
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            descripcion.etiqueta,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: seleccionado ? FontWeight.w600 : FontWeight.w500,
              // Sin color propio cuando no está seleccionado: así hereda el del
              // menú, que es el que el tema define para su superficie. Fijarlo
              // aquí obligaría a acertar con el color de fondo del menú, que no
              // lo decide este archivo.
              color: seleccionado ? theme.colorScheme.primary : null,
            ),
          ),
        ),
        // La marca del vigente. Sin ella habría que recordar cuál se eligió la
        // última vez para saber cuál está activo, que es justo lo que un
        // selector tiene que responder de un vistazo.
        if (seleccionado)
          Icon(
            Icons.check_rounded,
            size: 16,
            color: theme.colorScheme.primary,
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
//  Contenedor de contenido
// -----------------------------------------------------------------------------

/// Envuelve el contenido de una sección con márgenes, migas de pan y ancho
/// máximo.
///
/// El ancho máximo existe por legibilidad: en un monitor ancho, una línea de
/// texto que ocupe los 2500 px es incómoda de leer porque el ojo pierde el
/// principio de la línea siguiente.
///
/// ## El contrato de altura, y por qué ya no hay un scroll aquí
///
/// Esta sección entrega a su hijo una altura **acotada**: la que sobra tras las
/// migas de pan. No la envuelve en un `SingleChildScrollView`.
///
/// Antes sí lo hacía, y era un fallo silencioso: un scroll vertical da al hijo
/// altura **infinita**, y un panel que reparte el espacio con `Expanded` —o que
/// usa un `ListView` normal— revienta con «incoming height constraints are
/// unbounded». Tres paneles del cPanel lo hacían, así que abrirlos en la
/// aplicación real lanzaba una excepción de layout; las pruebas no lo veían
/// porque los montaban en el `body` acotado de un `Scaffold`, que no es como se
/// montan de verdad.
///
/// La regla, entonces: **el panel decide si llena el hueco o si crece.** Si su
/// contenido puede pasar de la pantalla, se envuelve él mismo en un
/// `SingleChildScrollView`. Así los dos contratos caben, en vez de obligar a
/// todos a compartir uno que sólo sirve a unos.
class ContenidoSeccion extends StatelessWidget {
  const ContenidoSeccion({
    super.key,
    required this.child,
    this.migas = const [],
    this.anchoMaximo = 1280,
  });

  final Widget child;
  final List<String> migas;
  final double anchoMaximo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        final esAngosto = restricciones.maxWidth < 700;
        return Padding(
          padding: EdgeInsets.all(esAngosto ? 16 : 24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: anchoMaximo),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (migas.isNotEmpty) MigasDePan(partes: migas),
                  // `Flexible` y no un hijo suelto: en un `Column`, un hijo no
                  // flexible recibe altura **infinita** en el eje principal, así
                  // que un panel con `Expanded` o con un `ListView` normal
                  // volvería a reventar. Siendo flexible, recibe el hueco que
                  // sobra —acotado— y lo reparte como quiera. El ajuste es
                  // holgado, no forzado: un panel corto no se estira.
                  Flexible(child: child),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
