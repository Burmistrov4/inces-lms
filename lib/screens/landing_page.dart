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

  @override
  void initState() {
    super.initState();
    _aspiranteRepo = widget.aspiranteRepository ?? AspiranteRepository();
    _cargarOferta();
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _construirHero(),
            _construirPilares(),
            _construirGaleriaEspecialidades(),
            _construirRoles(),
            _construirOferta(),
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
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final esEscritorio = constraints.maxWidth > 850;
                return esEscritorio
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _construirContenidoHero(esEscritorio: true),
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            flex: 5,
                            child: Center(
                              child: _construirInsigniaIndustrial3D(),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _construirContenidoHero(esEscritorio: false),
                          const SizedBox(height: 28),
                          _construirHeroVisualMovil(),
                        ],
                      );
              },
            ),
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
    return Container(
      width: 380,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 190,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/hero_soldadura.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.white.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.precision_manufacturing_rounded,
                      size: 48,
                      color: Colors.white70,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.70),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 14,
                  right: 14,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: IncesTheme.advertencia,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'TALLER INDUSTRIAL',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: IncesTheme.azulPrimario,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: IncesTheme.exito,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Presencial y Homologado',
                              style: GoogleFonts.inter(
                                fontSize: 10,
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
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Formación Técnica y Profesional',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Capacitación integral en metalmecánica, gastronomía, servicios y desarrollo personal homologada por el Estado.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _chipArea(Icons.precision_manufacturing_rounded, 'Metalmecánica'),
                    _chipArea(Icons.restaurant_menu_rounded, 'Alimentos'),
                    _chipArea(Icons.spa_rounded, 'Estética'),
                    _chipArea(Icons.record_voice_over_rounded, 'Oratoria'),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        color: IncesTheme.advertencia,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Certificación INCES Valedera',
                        style: GoogleFonts.inter(
                          fontSize: 12,
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
        ],
      ),
    );
  }

  Widget _construirHeroVisualMovil() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 180,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/hero_soldadura.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.white.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.precision_manufacturing_rounded,
                      size: 40,
                      color: Colors.white70,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.70),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: IncesTheme.advertencia,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'CFS NACIONAL DE SOLDADURA',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: IncesTheme.azulPrimario,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        color: IncesTheme.advertencia,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Sede La Isabelica • Carabobo',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          '100% Gratuito',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                _chipArea(Icons.precision_manufacturing_rounded, 'Metalmecánica'),
                _chipArea(Icons.restaurant_menu_rounded, 'Alimentos'),
                _chipArea(Icons.spa_rounded, 'Estética'),
                _chipArea(Icons.record_voice_over_rounded, 'Oratoria'),
                _chipArea(Icons.school_rounded, 'Jóvenes PNA'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipArea(IconData icono, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            texto,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
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

  // ---------------------------------------------------------------------------
  // Galería de Especialidades y Talleres Productivos
  // ---------------------------------------------------------------------------

  Widget _construirGaleriaEspecialidades() {
    final theme = Theme.of(context);

    final especialidades = [
      _EspecialidadData(
        area: AreaFormativa.metalmecanica,
        titulo: 'Metalmecánica y Soldadura',
        descripcion:
            'Talleres industriales con cabinas individuales de soldadura por arco (SMAW), '
            'semiautomática (GMAW/MIG-MAG), argón (GTAW/TIG), oxicorte y conformado en forja.',
        competencias: const [
          'Soldadura SMAW / GMAW',
          'Herrería y Forja',
          'Torno Mecánico',
          'Normas AWS D1.1',
        ],
        modalidad: '100% Práctico en Taller',
      ),
      _EspecialidadData(
        area: AreaFormativa.alimentos,
        titulo: 'Alimentación y Gastronomía',
        descripcion:
            'Formación integral en higiene y manipulación de alimentos, panificación artesanal, '
            'pastelería y técnicas culinarias con certificación sanitaria oficial del MPPS.',
        competencias: const [
          'Manipulación Sanitaria',
          'Panadería Artesanal',
          'Pastelería Básica',
          'Inocuidad Bromatológica',
        ],
        modalidad: 'Prácticas de Cocina y Aulas',
      ),
      _EspecialidadData(
        area: AreaFormativa.serviciosPersonales,
        titulo: 'Servicios Personales y Estética',
        descripcion:
            'Técnicas avanzadas de diseño de cejas y pestañas, visagismo facial, '
            'barbería clásica y urbana, corte y protocolos de bioseguridad estética.',
        competencias: const [
          'Cejas y Pestañas',
          'Barbería Moderna',
          'Colorimetría y Estilo',
          'Bioseguridad Cosmética',
        ],
        modalidad: 'Prácticas con Modelos Reales',
      ),
      _EspecialidadData(
        area: AreaFormativa.comunicacionYGestion,
        titulo: 'Comunicación, Gestión y Oratoria',
        descripcion:
            'Desarrollo de competencias en expresión oral, oratoria, liderazgo productivo, '
            'computación básica, ofimática y administración de proyectos socio-productivos.',
        competencias: const [
          'Oratoria y Expresión',
          'Liderazgo Productivo',
          'Computación Básica',
          'Ofimática Aplicada',
        ],
        modalidad: 'Laboratorios y Salones Multimedia',
      ),
      _EspecialidadData(
        area: AreaFormativa.juvenilYBasica,
        titulo: 'Formación Juvenil y Aprendices (PNA)',
        descripcion:
            'Programa Nacional de Aprendizaje (PNA) e inducción para adolescentes '
            'de 15 a 16 años, combinando valores, formación técnica vocacional y desarrollo humano.',
        competencias: const [
          'Adolescentes 15 a 16 años',
          'Orientación Vocacional',
          'Formación Dual PNA',
          'Inserción Ocupacional',
        ],
        modalidad: 'Acompañamiento Pedagógico Integral',
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
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: IncesTheme.azulPrimario.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'TALLERES Y ÁREAS FORMATIVAS',
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
                'Especialidades Productivas del Centro',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Formación gratuita y certificada en talleres equipados para el trabajo industrial, '
                'servicios, alimentación y emprendimiento en Carabobo.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columnas = constraints.maxWidth > 900
                      ? 3
                      : constraints.maxWidth > 600
                          ? 2
                          : 1;
                  const separacion = 18.0;
                  final ancho =
                      (constraints.maxWidth - separacion * (columnas - 1)) /
                          columnas;

                  return Wrap(
                    spacing: separacion,
                    runSpacing: separacion,
                    children: [
                      for (final esp in especialidades)
                        SizedBox(
                          width: ancho,
                          child: _TarjetaEspecialidad(
                            data: esp,
                            onExplorar: _irAInscripcion,
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
  // Oferta formativa (dinámica)
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
                'Cursos abiertos a inscripción en el centro.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _construirEstadoOferta(),
            ],
          ),
        ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        const separacion = 16.0;
        // El número de columnas sale del ancho disponible, no de un valor fijo:
        // así la rejilla no desborda en móvil ni deja tarjetas diminutas en
        // escritorio. El techo es 3 para que la tarjeta no se estire sin fin.
        final columnas = (constraints.maxWidth / 300).floor().clamp(1, 3);
        final ancho =
            (constraints.maxWidth - separacion * (columnas - 1)) / columnas;
        return Wrap(
          spacing: separacion,
          runSpacing: separacion,
          children: [
            for (final curso in _cursos)
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

  Widget _construirPie() {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          'INCES · CFS Nacional de Soldadura «Rafael Urdaneta» · La Isabelica',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
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

class _EspecialidadData {
  const _EspecialidadData({
    required this.area,
    required this.titulo,
    required this.descripcion,
    required this.competencias,
    required this.modalidad,
  });

  final AreaFormativa area;
  final String titulo;
  final String descripcion;
  final List<String> competencias;
  final String modalidad;
}

class _TarjetaEspecialidad extends StatelessWidget {
  const _TarjetaEspecialidad({
    required this.data,
    required this.onExplorar,
  });

  final _EspecialidadData data;
  final VoidCallback onExplorar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera fotográfica de la especialidad con degradado y badge
          SizedBox(
            height: 140,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  data.area.rutaImagenAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      gradient: data.area.degradadoBanner,
                    ),
                    child: Center(
                      child: Icon(
                        data.area.icono,
                        size: 48,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.80),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(data.area.icono, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                data.modalidad,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        data.titulo,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          shadows: const [
                            Shadow(
                              color: Colors.black87,
                              offset: Offset(0, 1),
                              blurRadius: 3,
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
          // Cuerpo
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.descripcion,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in data.competencias)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: data.area.colorPrimario.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                data.area.colorPrimario.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          c,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: data.area.colorPrimario,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onExplorar,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Postularme a esta área'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
