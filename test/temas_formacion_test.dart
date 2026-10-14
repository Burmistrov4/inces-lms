import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inces_lms_app/theme/temas_formacion.dart';

void main() {
  group('AreaFormativa · resolución de materias y programas', () {
    test('clasifica programas de soldadura y herrería en metalmecánica', () {
      expect(AreaFormativa.resolver('Soldadura Universal'), AreaFormativa.metalmecanica);
      expect(AreaFormativa.resolver('Soldadura por Arco Eléctrico SMAW'), AreaFormativa.metalmecanica);
      expect(AreaFormativa.resolver('Herrería y Forja'), AreaFormativa.metalmecanica);
      expect(AreaFormativa.resolver('Oxicorte y TIG'), AreaFormativa.metalmecanica);
    });

    test('clasifica cursos de alimentos y gastronomía', () {
      expect(
        AreaFormativa.resolver('Higiene y Manipulación de Alimentos'),
        AreaFormativa.alimentos,
      );
      expect(AreaFormativa.resolver('Panadería Artesanal'), AreaFormativa.alimentos);
      expect(AreaFormativa.resolver('Cocina Básica'), AreaFormativa.alimentos);
    });

    test('clasifica cursos de estética y servicios personales', () {
      expect(
        AreaFormativa.resolver('Estética (cejas y pestañas)'),
        AreaFormativa.serviciosPersonales,
      );
      expect(AreaFormativa.resolver('Barbería y Peluquería'), AreaFormativa.serviciosPersonales);
      expect(AreaFormativa.resolver('Cosmetología'), AreaFormativa.serviciosPersonales);
    });

    test('clasifica cursos de comunicación, oratoria y gestión', () {
      expect(AreaFormativa.resolver('Oratoria y Liderazgo'), AreaFormativa.comunicacionYGestion);
      expect(AreaFormativa.resolver('Comunicación Asertiva'), AreaFormativa.comunicacionYGestion);
      expect(AreaFormativa.resolver('Computación y Ofimática'), AreaFormativa.comunicacionYGestion);
    });

    test('clasifica cursos juveniles e introductorios', () {
      expect(
        AreaFormativa.resolver('Curso Introductorio (15-16 años)'),
        AreaFormativa.juvenilYBasica,
      );
      expect(AreaFormativa.resolver('Orientación Vocacional'), AreaFormativa.juvenilYBasica);
    });

    test('degrada limpiamente a técnica general para nombres sin coincidencia o nulos', () {
      expect(AreaFormativa.resolver(''), AreaFormativa.tecnicaGeneral);
      expect(AreaFormativa.resolver(null), AreaFormativa.tecnicaGeneral);
      expect(AreaFormativa.resolver('Curso Genérico X'), AreaFormativa.tecnicaGeneral);
    });

    test('cada área tiene icono, color primario y degradado no nulo', () {
      for (final area in AreaFormativa.values) {
        expect(area.etiqueta.isNotEmpty, isTrue);
        expect(area.icono, isA<IconData>());
        expect(area.colorPrimario, isA<Color>());
        expect(area.degradadoBanner.colors.length, greaterThanOrEqualTo(2));
      }
    });
  });
}
