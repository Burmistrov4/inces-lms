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
        return const Color(0xFF0284C7);
      case AreaFormativa.alimentos:
        return const Color(0xFF15803D);
      case AreaFormativa.serviciosPersonales:
        return const Color(0xFF7E22CE);
      case AreaFormativa.comunicacionYGestion:
        return const Color(0xFFD97706);
      case AreaFormativa.juvenilYBasica:
        return const Color(0xFF2563EB);
      case AreaFormativa.tecnicaGeneral:
        return IncesTheme.azulPrimario;
    }
  }

  /// Degradado de cabecera tipo Google Classroom para el Aula Virtual.
  LinearGradient get degradadoBanner {
    switch (this) {
      case AreaFormativa.metalmecanica:
        return const LinearGradient(
          colors: [Color(0xFF0C4A6E), Color(0xFF0369A1), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case AreaFormativa.alimentos:
        return const LinearGradient(
          colors: [Color(0xFF14532D), Color(0xFF15803D), Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case AreaFormativa.serviciosPersonales:
        return const LinearGradient(
          colors: [Color(0xFF581C87), Color(0xFF7E22CE), Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case AreaFormativa.comunicacionYGestion:
        return const LinearGradient(
          colors: [Color(0xFF78350F), Color(0xFFB45309), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case AreaFormativa.juvenilYBasica:
        return const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8), Color(0xFF2563EB)],
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
        n.contains('15-16') ||
        n.contains('orientacion') ||
        n.contains('orientación') ||
        n.contains('aprendiz')) {
      return AreaFormativa.juvenilYBasica;
    }

    return AreaFormativa.tecnicaGeneral;
  }
}
