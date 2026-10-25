import 'package:flutter/material.dart';
import 'inces_theme.dart';

/// Área formativa institucional del INCES.
///
/// El CFS Nacional de Soldadura «Rafael Urdaneta» (La Isabelica) y los centros
/// de formación socialista del INCES dictan programas en diversas ramas del
/// saber técnico, productivo y de servicios. Esta clase clasifica el nombre del
/// programa en su área correspondiente y le asigna identidad visual
/// (icono, colores, degradados estilo Google Classroom).
enum AreaFormativa {
  metalmecanica,
  alimentos,
  serviciosPersonales,
  comunicacionYGestion,
  juvenilYBasica,
  tecnicaGeneral;

  String get etiqueta {
    switch (this) {
      case AreaFormativa.metalmecanica:
        return 'Metalmecánica e Industria';
      case AreaFormativa.alimentos:
        return 'Alimentación y Gastronomía';
      case AreaFormativa.serviciosPersonales:
        return 'Servicios Personales y Estética';
      case AreaFormativa.comunicacionYGestion:
        return 'Comunicación y Gestión';
      case AreaFormativa.juvenilYBasica:
        return 'Formación Juvenil y Básica';
      case AreaFormativa.tecnicaGeneral:
        return 'Formación Técnica Profesional';
    }
  }

  IconData get icono {
    switch (this) {
      case AreaFormativa.metalmecanica:
        return Icons.precision_manufacturing_rounded;
      case AreaFormativa.alimentos:
        return Icons.restaurant_menu_rounded;
      case AreaFormativa.serviciosPersonales:
        return Icons.spa_rounded;
      case AreaFormativa.comunicacionYGestion:
        return Icons.record_voice_over_rounded;
      case AreaFormativa.juvenilYBasica:
        return Icons.school_rounded;
      case AreaFormativa.tecnicaGeneral:
        return Icons.auto_stories_rounded;
    }
  }

  Color get colorPrimario {
    switch (this) {
      case AreaFormativa.metalmecanica:
        return IncesTheme.areaMetalmecanica;
      case AreaFormativa.alimentos:
        return IncesTheme.areaAlimentos;
      case AreaFormativa.serviciosPersonales:
        return IncesTheme.areaServicios;
      case AreaFormativa.comunicacionYGestion:
        return IncesTheme.areaGestion;
      case AreaFormativa.juvenilYBasica:
        return IncesTheme.areaJuvenil;
      case AreaFormativa.tecnicaGeneral:
        return IncesTheme.azulPrimario;
    }
  }

  /// Ruta del recurso fotográfico oficial de la especialidad.
  String get rutaImagenAsset {
    switch (this) {
      case AreaFormativa.metalmecanica:
        return 'assets/images/area_metalmecanica.jpg';
      case AreaFormativa.alimentos:
        return 'assets/images/area_alimentos.jpg';
      case AreaFormativa.serviciosPersonales:
        return 'assets/images/area_servicios.jpg';
      case AreaFormativa.comunicacionYGestion:
        return 'assets/images/area_gestion.jpg';
      case AreaFormativa.juvenilYBasica:
        return 'assets/images/area_juvenil.jpg';
      case AreaFormativa.tecnicaGeneral:
        return 'assets/images/hero_soldadura.jpg';
    }
  }

  /// Degradado de cabecera tipo Google Classroom para el Aula Virtual.
  LinearGradient get degradadoBanner {
    switch (this) {
      case AreaFormativa.metalmecanica:
        return const LinearGradient(
          colors: [
            IncesTheme.bannerMetalmecanicaOscuro,
            IncesTheme.bannerMetalmecanicaMedio,
            IncesTheme.areaMetalmecanica,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case AreaFormativa.alimentos:
        return const LinearGradient(
          colors: [
            IncesTheme.bannerAlimentosOscuro,
            IncesTheme.areaAlimentos,
            IncesTheme.bannerAlimentosClaro,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case AreaFormativa.serviciosPersonales:
        return const LinearGradient(
          colors: [
            IncesTheme.bannerServiciosOscuro,
            IncesTheme.areaServicios,
            IncesTheme.bannerServiciosClaro,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case AreaFormativa.comunicacionYGestion:
        return const LinearGradient(
          colors: [
            IncesTheme.bannerGestionOscuro,
            IncesTheme.bannerGestionMedio,
            IncesTheme.areaGestion,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case AreaFormativa.juvenilYBasica:
        return const LinearGradient(
          colors: [
            IncesTheme.bannerJuvenilOscuro,
            IncesTheme.bannerJuvenilMedio,
            IncesTheme.areaJuvenil,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case AreaFormativa.tecnicaGeneral:
        return IncesTheme.degradadoAzul;
    }
  }

  /// Deduce el área formativa a partir del nombre del programa o materia.
  static AreaFormativa resolver(String? nombre) {
    if (nombre == null || nombre.trim().isEmpty) {
      return AreaFormativa.tecnicaGeneral;
    }

    final n = nombre.toLowerCase();

    // Metalmecánica e industria
    if (n.contains('soldadura') ||
        n.contains('herreria') ||
        n.contains('herrería') ||
        n.contains('torno') ||
        n.contains('torner') ||
        n.contains('mecanic') ||
        n.contains('mecánic') ||
        n.contains('metal') ||
        n.contains('oxicorte') ||
        n.contains('smaw') ||
        n.contains('gmaw') ||
        n.contains('gtaw') ||
        n.contains('arco') ||
        n.contains('tig') ||
        n.contains('mig')) {
      return AreaFormativa.metalmecanica;
    }

    // Alimentos y gastronomía
    if (n.contains('alimento') ||
        n.contains('higiene') ||
        n.contains('manipulacion') ||
        n.contains('manipulación') ||
        n.contains('cocina') ||
        n.contains('panader') ||
        n.contains('pasteler') ||
        n.contains('gastronom')) {
      return AreaFormativa.alimentos;
    }

    // Servicios personales y estética
    if (n.contains('estetica') ||
        n.contains('estética') ||
        n.contains('ceja') ||
        n.contains('pestaña') ||
        n.contains('barber') ||
        n.contains('peluquer') ||
        n.contains('manicur') ||
        n.contains('pedicur') ||
        n.contains('belleza') ||
        n.contains('cosmetol')) {
      return AreaFormativa.serviciosPersonales;
    }

    // Comunicación, gestión y humanidades
    if (n.contains('oratoria') ||
        n.contains('comunicaci') ||
        n.contains('administra') ||
        n.contains('contabil') ||
        n.contains('computaci') ||
        n.contains('ofimatic') ||
        n.contains('ofimátic') ||
        n.contains('liderazgo')) {
      return AreaFormativa.comunicacionYGestion;
    }

    // Formación juvenil y básica
    if (n.contains('introductorio') ||
        n.contains('juvenil') ||
        n.contains('adolescent') ||
        // El rango del PNA cambió de 14-17 a 14-18 el 2026-10-25, y con él el
        // nombre del programa semilla («Curso Introductorio (15-16 años)» →
        // «(14-18 años)»). Se aceptan los tres rangos a propósito: si alguien
        // renombra un programa a mano con un rango antiguo, debe seguir cayendo
        // en juvenil y no en «técnica general», que es donde acabaría por
        // omisión y donde no le corresponde.
        n.contains('14-18') ||
        n.contains('14-17') ||
        n.contains('15-16') ||
        n.contains('orientacion') ||
        n.contains('orientación') ||
        n.contains('aprendiz')) {
      return AreaFormativa.juvenilYBasica;
    }

    return AreaFormativa.tecnicaGeneral;
  }
}
