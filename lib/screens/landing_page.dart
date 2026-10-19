import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/inscripcion_campo.dart';
import '../repositories/aspirante_repository.dart';
import '../theme/inces_theme.dart';
import '../theme/temas_formacion.dart';

/// Página pública de aterrizaje: la raíz `/` cuando **no** hay sesión.
///
/// Es la cara institucional del sistema. Antes, quien abría la aplicación sin
/// sesión caía de golpe en el login; ahora ve la identidad del centro, la oferta
/// formativa real (Módulo 2) y dos caminos: inscribirse o entrar al portal
/// académico.
///
/// **No es una ruta propia.** La muestra [AuthGate] como su hijo cuando no hay
/// sesión. Registrar además `'/'` en `routes` rompería el arranque: `MaterialApp`
/// lanza una aserción si `home` y `routes['/']` coexisten.
///
/// La oferta se lee de `AspiranteRepository.obtenerProgramasDisponibles()`, que
/// va por PostgREST **anónimo** (la RLS deja ver los programas activos), así que
/// no hace falta sesión para pintarla.
class LandingPage extends StatefulWidget {
  const LandingPage({super.key, this.aspiranteRepository});

  /// Inyectable para las pruebas. En producción se resuelve solo.
  ///
  /// Sin esto, montar la Landing en una prueba dispararía una consulta real a
  /// Supabase en `initState`, y ninguna prueba podría montarla sin red.
  final AspiranteRepository? aspiranteRepository;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  late final AspiranteRepository _aspiranteRepo;

  bool _cargando = true;

  /// La oferta formativa: `valor` = uuid del programa, `etiqueta` = su nombre.
  List<OpcionCampo> _cursos = const [];

  /// Por qué no hay cursos que mostrar, si no los hay. `null` cuando sí hay.
  String? _aviso;

  final TextEditingController _busquedaCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _claveOferta = GlobalKey();
  String _areaSeleccionada = 'TODOS';

  @override
  void initState() {
    super.initState();
    _aspiranteRepo = widget.aspiranteRepository ?? AspiranteRepository();
    _cargarOferta();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollearAOferta() {
    final ctx = _claveOferta.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  List<OpcionCampo> get _cursosFiltrados {
    final query = _busquedaCtrl.text.trim().toLowerCase();
    return _cursos.where((c) {
      final nombre = c.etiqueta.toLowerCase();
      final coincideTexto = query.isEmpty || nombre.contains(query);
      if (!coincideTexto) return false;

      if (_areaSeleccionada == 'TODOS') return true;
      if (_areaSeleccionada == 'PNA') {
        return nombre.contains('pna') ||
            nombre.contains('aprendiz') ||
            nombre.contains('juvenil');
      }
      if (_areaSeleccionada == 'SOLDADURA') {
        return nombre.contains('solda') ||
            nombre.contains('oxigas') ||
            nombre.contains('arco') ||
            nombre.contains('mig') ||
            nombre.contains('tig');
      }
      if (_areaSeleccionada == 'MECANICA') {
        return nombre.contains('mecan') ||
            nombre.contains('torno') ||
            nombre.contains('fresa') ||
            nombre.contains('ajuste') ||
            nombre.contains('herramient');
      }
      if (_areaSeleccionada == 'ELECTRICIDAD') {
        return nombre.contains('electr') ||
            nombre.contains('circuit') ||
            nombre.contains('bobin');
      }
      if (_areaSeleccionada == 'REFRIGERACION') {
        return nombre.contains('refrig') ||
            nombre.contains('clima') ||
            nombre.contains('aire');
      }
      if (_areaSeleccionada == 'GESTION') {
        return nombre.contains('gestion') ||
            nombre.contains('admin') ||
            nombre.contains('contab') ||
            nombre.contains('asistent');
      }
      return true;
    }).toList();
  }

  Future<void> _cargarOferta() async {
    setState(() {
      _cargando = true;
      _aviso = null;
    });

    final resultado = await _aspiranteRepo.obtenerProgramasDisponibles();
    if (!mounted) return;

    setState(() {
      final cursos = resultado.valueOrNull;
      if (cursos != null && cursos.isNotEmpty) {
        _cursos = cursos;
        _aviso = null;
      } else {
        // Un fallo de red y un catálogo vacío se ven igual —sin tarjetas—, y
        // sólo el `Result` los distingue. El mensaje dice cuál de los dos pasó,
        // en vez de degradar los dos al mismo «no hay cursos».
        _cursos = const [];
        _aviso = cursos == null
            ? 'No pudimos cargar la oferta formativa. Revisa tu conexión e '
                'inténtalo de nuevo.'
            : 'Todavía no hay cursos abiertos a inscripción. Vuelve pronto.';
      }
      _cargando = false;
    });
  }

  void _irAInscripcion() {
    Navigator.of(context).pushNamed('/inscripcion');
  }

  void _irAlPortalAcademico() {
    Navigator.of(context).pushNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _construirHero(),
            _construirPilares(),
            _construirQuienesSomos(),
            KeyedSubtree(key: _claveOferta, child: _construirOferta()),
            _construirRoles(),
            _construirCompromiso(),
            _construirPie(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero institucional
  // ---------------------------------------------------------------------------

  Widget _construirHero() {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: IncesTheme.degradadoAzul),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                _construirNavbar(),
                const SizedBox(height: 36),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final esEscritorio = constraints.maxWidth > 920;
                    return esEscritorio
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 6,
                                child: _construirContenidoHero(esEscritorio: true),
                              ),
                              const SizedBox(width: 40),
                              Expanded(
                                flex: 6,
                                child: Align(
                                  alignment: Alignment.center,
                                  child: _construirInsigniaIndustrial3D(),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _construirContenidoHero(esEscritorio: false),
                              const SizedBox(height: 32),
                              _construirHeroVisualMovil(),
                            ],
                          );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirNavbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final esEstrecho = constraints.maxWidth < 990;
        final hayBusqueda = _busquedaCtrl.text.trim().isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _construirMarca(),
                const Spacer(),
                if (!esEstrecho) ...[
                  SizedBox(
                    width: 280,
                    height: 40,
                    child: TextField(
                      controller: _busquedaCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _scrollearAOferta(),
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Buscar cursos o especialidad…',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 18),
                        suffixIcon: _busquedaCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                                onPressed: () {
                                  _busquedaCtrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: theme.colorScheme.onPrimary.withValues(alpha: 0.15),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: _irAlPortalAcademico,
                    icon: const Icon(Icons.login, size: 18, color: Colors.white),
                    label: const Text('Portal Académico', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _irAInscripcion,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: IncesTheme.azulPrimario,
                    ),
                    child: const Text('Inscribirse'),
                  ),
                ] else ...[
                  IconButton(
                    tooltip: 'Portal Académico',
                    icon: const Icon(Icons.login, color: Colors.white),
                    onPressed: _irAlPortalAcademico,
                  ),
                  FilledButton(
                    onPressed: _irAInscripcion,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: IncesTheme.azulPrimario,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Inscribirse'),
                  ),
                ],
              ],
            ),
            if (!esEstrecho && hayBusqueda) ...[
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 230),
                  child: SizedBox(
                    width: 320,
                    child: _construirSugerenciasBusqueda(),
                  ),
                ),
              ),
            ],
            if (esEstrecho) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 40,
                child: TextField(
                  controller: _busquedaCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _scrollearAOferta(),
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Buscar cursos o especialidad…',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 18),
                    suffixIcon: _busquedaCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                            onPressed: () {
                              _busquedaCtrl.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: theme.colorScheme.onPrimary.withValues(alpha: 0.15),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                  ),
                ),
              ),
              if (hayBusqueda) _construirSugerenciasBusqueda(),
            ],
          ],
        );
      },
    );
  }

  Widget _construirSugerenciasBusqueda() {
    final query = _busquedaCtrl.text.trim();
    if (query.isEmpty) return const SizedBox.shrink();

    final resultados = _cursosFiltrados;
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: esOscuro ? IncesTheme.superficieOscura : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: IncesTheme.azulPrimario.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 16, color: IncesTheme.azulPrimario),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        resultados.isEmpty
                            ? 'Sin coincidencias para "$query"'
                            : '${resultados.length} especialidad${resultados.length == 1 ? "" : "es"} encontrada${resultados.length == 1 ? "" : "s"}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: IncesTheme.azulPrimario,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        _busquedaCtrl.clear();
                        setState(() {});
                      },
                      child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (resultados.isNotEmpty)
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: resultados.length > 5 ? 5 : resultados.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final curso = resultados[idx];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: IncesTheme.azulPrimario.withValues(alpha: 0.1),
                          child: const Icon(Icons.school_outlined, size: 16, color: IncesTheme.azulPrimario),
                        ),
                        title: Text(
                          curso.etiqueta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: esOscuro ? Colors.white : Colors.black87,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                        onTap: () {
                          _scrollearAOferta();
                        },
                      );
                    },
                  ),
                ),
              InkWell(
                onTap: _scrollearAOferta,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  child: Text(
                    'Ver resultados en catálogo ↓',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: IncesTheme.azulPrimario,
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

  Widget _construirContenidoHero({required bool esEscritorio}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _construirMarca(),
        const SizedBox(height: 28),
        Text(
          'Formación Técnica y\nGestión Académica',
          style: GoogleFonts.inter(
            fontSize: esEscritorio ? 44 : 32,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 16),
        // Franja tricolor institucional estilizada
        Row(
          children: [
            Container(
              width: 28,
              height: 4,
              decoration: BoxDecoration(
                color: IncesTheme.advertencia, // Oro institucional
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 28,
              height: 4,
              decoration: BoxDecoration(
                color: IncesTheme.azulSecundario,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 28,
              height: 4,
              decoration: BoxDecoration(
                color: IncesTheme.rojoInces,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'CFS Nacional de Soldadura «Rafael Urdaneta»',
          style: GoogleFonts.inter(
            fontSize: 18,
            height: 1.4,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'INCES La Isabelica',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        Text(
          'Carabobo, Venezuela',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 30),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _irAInscripcion,
              icon: const Icon(Icons.assignment_outlined, size: 18),
              label: const Text('Inscribirse'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: IncesTheme.azulPrimario,
                elevation: 2,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _irAlPortalAcademico,
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Portal Académico'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _construirInsigniaIndustrial3D() {
    return _CarruselHeroOfertas(
      esMovil: false,
      onInscribirse: _irAInscripcion,
    );
  }

  Widget _construirHeroVisualMovil() {
    return _CarruselHeroOfertas(
      esMovil: true,
      onInscribirse: _irAInscripcion,
    );
  }

  Widget _construirMarca() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: Text(
            'I',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          'INCES LMS',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Pilares del Sistema y Roles
  // ---------------------------------------------------------------------------

  Widget _construirPilares() {
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;

    final pilares = [
      (
        icono: Icons.computer_outlined,
        titulo: 'Aula Virtual y Talleres Prácticos',
        modulo: 'Formación',
        descripcion:
            'Tablón de clase interactivo, asignaciones formativas para talleres y aulas '
            'y calificaciones continuas.',
      ),
      (
        icono: Icons.qr_code_scanner_rounded,
        titulo: 'Asistencia Segura con QR',
        modulo: 'Control',
        descripcion:
            'Registro de presencialidad en talleres y aulas con códigos dinámicos efímeros '
            'y verificación presencial.',
      ),
      (
        icono: Icons.how_to_reg_outlined,
        titulo: 'Asignación Transparente de Cupos',
        modulo: 'Admisión',
        descripcion:
            'Postulación en línea con asignación automática por orden de llegada (FIFO) '
            'y aforo controlado por curso.',
      ),
      (
        icono: Icons.cloud_done_outlined,
        titulo: 'Biblioteca Digital y Guías de Estudio',
        modulo: 'Recursos',
        descripcion:
            'Manuales técnicos, recetarios, guías de estética, planos y normas '
            'disponibles 24/7 sin límite de transferencia.',
      ),
    ];

    return Container(
      color: esOscuro
          ? theme.colorScheme.surface
          : IncesTheme.fondoClaro,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: IncesTheme.azulPrimario.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'CAPACIDADES DEL SISTEMA',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Plataforma Diseñada para la Formación Técnica Productiva',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tecnología moderna al servicio de aprendices, facilitadores y directivos del CFS Carabobo.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columnas = constraints.maxWidth > 900
                      ? 4
                      : constraints.maxWidth > 550
                          ? 2
                          : 1;
                  final ancho =
                      (constraints.maxWidth - 16 * (columnas - 1)) / columnas;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final p in pilares)
                        SizedBox(
                          width: ancho,
                          child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(IncesTheme.radioTarjeta),
                              side: BorderSide(
                                color: theme.colorScheme.outline
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          p.icono,
                                          size: 22,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme
                                              .surfaceContainerHighest,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          p.modulo,
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    p.titulo,
                                    style:
                                        theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    p.descripcion,
                                    style:
                                        theme.textTheme.bodySmall?.copyWith(
                                      color: theme
                                          .colorScheme.onSurfaceVariant,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _construirRoles() {
    final theme = Theme.of(context);

    final perfiles = [
      (
        rol: 'Aprendiz y Aspirante',
        icono: Icons.school_outlined,
        ventajas: [
          'Inscripción digital autónoma',
          'Acceso inmediato a tareas y guías',
          'Marcaje de asistencia con QR',
        ],
      ),
      (
        rol: 'Docente y Facilitador',
        icono: Icons.badge_outlined,
        ventajas: [
          'Gestión de aula virtual por materia',
          'Generador de código QR para lista',
          'Evaluación formativa y retroalimentación',
        ],
      ),
      (
        rol: 'Coordinación y Dirección',
        icono: Icons.admin_panel_settings_outlined,
        ventajas: [
          'Panel de control centralizado del centro',
          'Planificación integral de horarios y talleres',
          'Monitoreo en tiempo real y reportes oficiales',
        ],
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Experiencia Integral por Rol',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Interfaces diseñadas para responder exactamente a las responsabilidades de cada miembro de la comunidad educativa.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columnas = constraints.maxWidth > 800 ? 3 : 1;
                  final ancho =
                      (constraints.maxWidth - 16 * (columnas - 1)) / columnas;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final p in perfiles)
                        SizedBox(
                          width: ancho,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(
                                  IncesTheme.radioTarjeta),
                              border:
                                  Border.all(color: theme.colorScheme.outline),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(p.icono,
                                        size: 24,
                                        color: theme.colorScheme.primary),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        p.rol,
                                        style:
                                            theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                for (final v in p.ventajas) ...[
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outline,
                                        size: 16,
                                        color: IncesTheme.exito,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          v,
                                          style:
                                              theme.textTheme.bodySmall?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ¿Quiénes somos? (Identidad Institucional del CFS La Isabelica)
  // ---------------------------------------------------------------------------

  Widget _construirQuienesSomos() {
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;

    return Container(
      color: esOscuro
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15)
          : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: IncesTheme.azulPrimario.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'CONOCE NUESTRO CENTRO',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Centro de Formación Socialista CFS Nacional de Soldadura «Rafael Urdaneta»',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sede neurálgica de la formación técnica industrial en Carabobo y referencia nacional en metalmecánica y soldadura especializada.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              LayoutBuilder(
                builder: (context, constraints) {
                  final esEscritorio = constraints.maxWidth > 800;
                  return esEscritorio
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: _construirTextoQuienesSomos(theme),
                            ),
                            const SizedBox(width: 32),
                            Expanded(
                              flex: 5,
                              child: _construirTarjetasDestacadasQuienesSomos(theme),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _construirTextoQuienesSomos(theme),
                            const SizedBox(height: 24),
                            _construirTarjetasDestacadasQuienesSomos(theme),
                          ],
                        );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirTextoQuienesSomos(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'El Centro de Formación Socialista (CFS) Nacional de Soldadura «Rafael Urdaneta», adscrito a la Gerencia Regional del INCES Carabobo, está ubicado estratégicamente en la Zona Industrial La Isabelica (Valencia), epicentro de la manufactura y el parque automotriz y metalmecánico del centro del país.\n\n'
          'Nuestra misión es formar integralmente a la juventud trabajadora, aprendices del Programa Nacional de Aprendizaje (PNA) y profesionales en ejercicio mediante un enfoque pedagógico dual que combina la rigurosidad técnica en el aula con la práctica intensiva en talleres dotados con cabinas industriales.\n\n'
          'Impulsamos la soberanía técnica, la certificación de saberes empíricos y la inserción laboral productiva de acuerdo con las normas técnicas nacionales e internacionales (AWS, ASME, DIN).',
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.6,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _chipCualidad(Icons.verified_user_outlined, 'Acreditación Oficial INCES'),
            _chipCualidad(Icons.workspace_premium_outlined, 'Estándares AWS y ASME'),
            _chipCualidad(Icons.groups_outlined, 'Programa PNA 14-18 años'),
            _chipCualidad(Icons.location_on_outlined, 'La Isabelica · Valencia'),
          ],
        ),
      ],
    );
  }

  Widget _chipCualidad(IconData icono, String etiqueta) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            etiqueta,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirTarjetasDestacadasQuienesSomos(ThemeData theme) {
    final datos = [
      (
        numero: '100%',
        titulo: 'Formación Gratuita',
        desc: 'Acceso universal a educación técnica pública y de calidad.',
      ),
      (
        numero: 'Dual',
        titulo: 'Taller + Aula Virtual',
        desc: 'Práctica directa con maquinaria industrial y soporte digital.',
      ),
      (
        numero: 'HACER',
        titulo: 'Registro Nacional',
        desc: 'Conexión institucional con la plataforma nacional de títulos.',
      ),
    ];

    return Column(
      children: [
        for (final d in datos) ...[
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.7)),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    d.numero,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.titulo,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        d.desc,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Oferta formativa (dinámica con búsqueda y categorías)
  // ---------------------------------------------------------------------------

  Widget _construirOferta() {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Oferta formativa', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Cursos y programas técnicos abiertos a inscripción en el centro.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              _construirFiltrosArea(),
              const SizedBox(height: 20),
              _construirEstadoOferta(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirFiltrosArea() {
    final categorias = [
      (id: 'TODOS', etiqueta: 'Todos', icono: Icons.apps_rounded),
      (id: 'SOLDADURA', etiqueta: 'Soldadura Especializada', icono: Icons.precision_manufacturing_outlined),
      (id: 'MECANICA', etiqueta: 'Mecánica Industrial', icono: Icons.build_outlined),
      (id: 'ELECTRICIDAD', etiqueta: 'Electricidad y Electrónica', icono: Icons.bolt_outlined),
      (id: 'REFRIGERACION', etiqueta: 'Refrigeración', icono: Icons.ac_unit_outlined),
      (id: 'PNA', etiqueta: 'Programas PNA (14 a 18 años)', icono: Icons.school_outlined),
      (id: 'GESTION', etiqueta: 'Gestión y Servicios', icono: Icons.business_center_outlined),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final cat in categorias) ...[
            FilterChip(
              avatar: Icon(
                cat.icono,
                size: 16,
                color: _areaSeleccionada == cat.id
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.primary,
              ),
              label: Text(cat.etiqueta),
              selected: _areaSeleccionada == cat.id,
              onSelected: (_) {
                setState(() => _areaSeleccionada = cat.id);
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _construirEstadoOferta() {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final aviso = _aviso;
    if (aviso != null) return _construirAviso(aviso);

    return _construirRejilla();
  }

  Widget _construirAviso(String mensaje) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              mensaje,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: _cargarOferta,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _construirRejilla() {
    final lista = _cursosFiltrados;
    if (lista.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No se encontraron cursos con los filtros aplicados',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Prueba con otro término de búsqueda o selecciona otra categoría.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                _busquedaCtrl.clear();
                setState(() => _areaSeleccionada = 'TODOS');
              },
              child: const Text('Restablecer filtros'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const separacion = 16.0;
        final columnas = (constraints.maxWidth / 300).floor().clamp(1, 3);
        final ancho =
            (constraints.maxWidth - separacion * (columnas - 1)) / columnas;
        return Wrap(
          spacing: separacion,
          runSpacing: separacion,
          children: [
            for (final curso in lista)
              SizedBox(
                width: ancho,
                child: _TarjetaCurso(
                  curso: curso,
                  onInscribir: _irAInscripcion,
                ),
              ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Compromiso y Calidad
  // ---------------------------------------------------------------------------

  Widget _construirCompromiso() {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Text(
                'Compromiso Institucional con la Calidad',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'El CFS Nacional de Soldadura «Rafael Urdaneta» forma los profesionales que impulsan los sectores productivos e industriales del país.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 24,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  _insignia(
                      Icons.verified_outlined, 'Certificación Nacional INCES'),
                  _insignia(Icons.precision_manufacturing_outlined,
                      'Formación Dual Taller y Aula'),
                  _insignia(Icons.lock_clock_outlined,
                      'Infraestructura Tecnológica 24/7'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _insignia(IconData icono, String texto) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          texto,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Footer Institucional Completo
  // ---------------------------------------------------------------------------

  Widget _construirPie() {
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      color: esOscuro
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
          : IncesTheme.fondoOscuro,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final esEscritorio = constraints.maxWidth > 780;
                  return esEscritorio
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 4, child: _columnaFooterIdentidad()),
                            const SizedBox(width: 32),
                            Expanded(flex: 3, child: _columnaFooterUbicacion()),
                            const SizedBox(width: 32),
                            Expanded(flex: 3, child: _columnaFooterEnlaces()),
                            const SizedBox(width: 32),
                            Expanded(flex: 2, child: _columnaFooterModulos()),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _columnaFooterIdentidad(),
                            const SizedBox(height: 24),
                            _columnaFooterUbicacion(),
                            const SizedBox(height: 24),
                            _columnaFooterEnlaces(),
                            const SizedBox(height: 24),
                            _columnaFooterModulos(),
                          ],
                        );
                },
              ),
              const SizedBox(height: 36),
              const Divider(color: Colors.white24),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '© 2026 Instituto Nacional de Capacitación y Educación Socialista (INCES). República Bolivariana de Venezuela.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    'CFS Rafael Urdaneta · v1.3.2 (Prod 2026)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _columnaFooterIdentidad() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'I',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'INCES LMS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Centro de Formación Socialista «Rafael Urdaneta»\nEspecialistas en Soldadura y Tecnologías Industriales.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 10),
        const Text(
          '«Formar produciendo, producir formando»',
          style: TextStyle(
            color: IncesTheme.advertencia,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _columnaFooterUbicacion() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sede y Talleres',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Av. Este-Oeste 3, Zona Industrial La Isabelica, Valencia, Edo. Carabobo.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        SizedBox(height: 8),
        Text(
          'Horario de Talleres:\nLunes a Viernes 07:30 - 16:30',
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }

  Widget _columnaFooterEnlaces() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enlaces Oficiales',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 10),
        Text(
          '• Portal Nacional INCES (inces.gob.ve)\n'
          '• Plataforma HACER Títulos Oficiales\n'
          '• Min. Proceso Social de Trabajo',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.6),
        ),
      ],
    );
  }

  Widget _columnaFooterModulos() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Módulos LMS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 10),
        Text(
          '• Aula Virtual\n'
          '• Asistencia QR\n'
          '• Horarios y Talleres\n'
          '• Planilla HACER',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.6),
        ),
      ],
    );
  }
}

/// Tarjeta de un curso de la oferta formativa.
///
/// Muestra sólo el **nombre** del programa: es lo único que expone
/// `programasDisponibles()` (`id` + `name`). Enriquecerla con código o duración
/// exigiría otra lectura del Módulo 2, que es trabajo aparte.
class _TarjetaCurso extends StatelessWidget {
  const _TarjetaCurso({required this.curso, required this.onInscribir});

  final OpcionCampo curso;
  final VoidCallback onInscribir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final area = AreaFormativa.resolver(curso.etiqueta);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 75,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  area.rutaImagenAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(color: area.colorPrimario),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.75),
                        Colors.black.withValues(alpha: 0.35),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(area.icono, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          area.etiqueta,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  curso.etiqueta,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Formación técnica continua y capacitación productiva certificada por el INCES.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: onInscribir,
                    icon: const Icon(Icons.how_to_reg_rounded, size: 16),
                    label: const Text('Inscribirme'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



/// Carrusel interactivo y rotativo de ofertas formativas del Hero institucional.
class _CarruselHeroOfertas extends StatefulWidget {
  const _CarruselHeroOfertas({
    required this.esMovil,
    required this.onInscribirse,
  });

  final bool esMovil;
  final VoidCallback onInscribirse;

  @override
  State<_CarruselHeroOfertas> createState() => _CarruselHeroOfertasState();
}

class _DatoSlideHero {
  final String imagen;
  final String badge;
  final String tag;
  final String titulo;
  final String descripcion;
  final List<String> tags;
  final IconData icono;

  const _DatoSlideHero({
    required this.imagen,
    required this.badge,
    required this.tag,
    required this.titulo,
    required this.descripcion,
    required this.tags,
    required this.icono,
  });
}

class _CarruselHeroOfertasState extends State<_CarruselHeroOfertas> {
  int _indice = 0;
  Timer? _timer;

  static const List<_DatoSlideHero> _slides = [
    _DatoSlideHero(
      imagen: 'assets/images/area_metalmecanica.jpg',
      badge: 'METALMECÁNICA Y SOLDADURA',
      tag: 'Homologación AWS D1.1',
      titulo: 'Soldadura Universal y Forja Industrial',
      descripcion:
          'Cabinas individuales con equipos para procesos SMAW, GMAW/MIG, argón GTAW/TIG y oxicorte.',
      tags: ['Soldadura TIG/MIG', 'Herrería Estructural', 'Torno Mecánico'],
      icono: Icons.precision_manufacturing_rounded,
    ),
    _DatoSlideHero(
      imagen: 'assets/images/area_alimentos.jpg',
      badge: 'GASTRONOMÍA Y ALIMENTOS',
      tag: 'Certificado Sanitario MPPS',
      titulo: 'Cocina Industrial y Panificación',
      descripcion:
          'Talleres culinarios profesionales, técnicas de panadería artesanal, repostería e inocuidad alimentaria.',
      tags: ['Panadería Artesanal', 'Pastelería', 'Bromatología'],
      icono: Icons.restaurant_menu_rounded,
    ),
    _DatoSlideHero(
      imagen: 'assets/images/area_gestion.jpg',
      badge: 'INFORMÁTICA Y GESTIÓN',
      tag: 'Laboratorio Tecnológico',
      titulo: 'Administración, Sistemas y Oratoria',
      descripcion:
          'Capacitación en software administrativo, tributación, soporte técnico de redes y liderazgo productivo.',
      tags: ['Ofimática y Redes', 'Gestión Tributaria', 'Oratoria'],
      icono: Icons.laptop_chromebook_rounded,
    ),
    _DatoSlideHero(
      imagen: 'assets/images/area_servicios.jpg',
      badge: 'SERVICIOS PERSONALES',
      tag: 'Práctica con Modelos Reales',
      titulo: 'Estética Integral y Barbería Clásica',
      descripcion:
          'Técnicas modernas de corte y barbería, visagismo, diseño de cejas y pestañas con bioseguridad.',
      tags: ['Barbería Urbana', 'Cejas y Pestañas', 'Estilismo'],
      icono: Icons.spa_rounded,
    ),
    _DatoSlideHero(
      imagen: 'assets/images/area_juvenil.jpg',
      badge: 'PROGRAMA JUVENIL PNA',
      tag: 'Jóvenes de 14 a 18 años',
      titulo: 'Aprendices INCES e Inserción Laboral',
      descripcion:
          'Programa Nacional de Aprendizaje con orientación vocacional integral, formación técnica dual y valores.',
      tags: ['Formación Dual PNA', 'Orientación Técnica', 'Inserción'],
      icono: Icons.school_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _iniciarTimer();
  }

  void _iniciarTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 4500), (_) {
      if (mounted) {
        setState(() {
          _indice = (_indice + 1) % _slides.length;
        });
      }
    });
  }

  void _pausar() {
    _timer?.cancel();
  }

  void _irA(int indice) {
    _pausar();
    setState(() {
      _indice = indice.clamp(0, _slides.length - 1);
    });
    _iniciarTimer();
  }

  void _siguiente() {
    _irA((_indice + 1) % _slides.length);
  }

  void _anterior() {
    _irA((_indice - 1 + _slides.length) % _slides.length);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slide = _slides[_indice];
    final esMovil = widget.esMovil;

    return MouseRegion(
      onEnter: (_) => _pausar(),
      onExit: (_) => _iniciarTimer(),
      child: Container(
        width: esMovil ? double.infinity : 520,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(esMovil ? 20 : 24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 36,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: IncesTheme.azulPrimario.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: esMovil ? 210 : 255,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: Image.asset(
                      slide.imagen,
                      key: ValueKey<String>(slide.imagen),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, _, _) => Container(
                        color: IncesTheme.azulPrimario,
                        child: Icon(slide.icono, size: 54, color: Colors.white70),
                      ),
                    ),
                  ),
                  // Gradiente sutil para legibilidad de insignias sin oscurecer la foto
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.25),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    right: 14,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: IncesTheme.advertencia,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                slide.icono,
                                size: 13,
                                color: IncesTheme.azulPrimario,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                slide.badge,
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: IncesTheme.azulPrimario,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_outlined,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                slide.tag,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Controles de navegación anterior / siguiente
                  Positioned(
                    left: 12,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: const CircleBorder(),
                        elevation: 3,
                        shadowColor: Colors.black.withValues(alpha: 0.3),
                        child: InkWell(
                          onTap: _anterior,
                          customBorder: const CircleBorder(),
                          child: const Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(
                              Icons.chevron_left_rounded,
                              color: IncesTheme.azulPrimario,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: const CircleBorder(),
                        elevation: 3,
                        shadowColor: Colors.black.withValues(alpha: 0.3),
                        child: InkWell(
                          onTap: _siguiente,
                          customBorder: const CircleBorder(),
                          child: const Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              color: IncesTheme.azulPrimario,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Contador de láminas en la foto
                  Positioned(
                    bottom: 12,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_indice + 1} / ${_slides.length}',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Indicadores de puntos interactivos centrados
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (index) {
                      final esActivo = index == _indice;
                      return GestureDetector(
                        onTap: () => _irA(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: esActivo ? 26 : 7,
                          height: 6,
                          decoration: BoxDecoration(
                            color: esActivo
                                ? IncesTheme.azulPrimario
                                : IncesTheme.bordeCarruselNeutro,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    slide.titulo,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    slide.descripcion,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in slide.tags)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: IncesTheme.azulPrimario.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: IncesTheme.azulPrimario.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: IncesTheme.azulPrimario,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 44,
                    child: FilledButton(
                      onPressed: widget.onInscribirse,
                      style: FilledButton.styleFrom(
                        backgroundColor: IncesTheme.azulPrimario,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.assignment_turned_in_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Inscribirme en esta especialidad',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
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

