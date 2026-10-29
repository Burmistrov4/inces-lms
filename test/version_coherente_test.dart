import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inces_lms_app/core/config/app_config.dart';

/// Guardia de coherencia de versión: `pubspec.yaml` ↔ `AppConfig` ↔ `CHANGELOG`.
///
/// **Por qué existe.** Medido el 2026-10-29: el `pubspec` iba por `1.5.5+7` y
/// `AppConfig.version` seguía en `1.5.1`, así que la interfaz mostraba «v1.5.1»
/// en el menú, el pie y la portada mientras el CHANGELOG documentaba 1.5.5.
/// No lo detectó nada porque la constante es la única fuente de lo que se pinta
/// y nadie la comparaba con nada.
///
/// El proyecto ya había corregido esta clase de fallo una vez (un panel con la
/// versión escrita a mano junto a otro que leía la constante), pero la lección
/// se quedó en la interfaz y no llegó al archivo que la alimenta. Una prueba que
/// compara los tres sitios cuesta veinte líneas y cierra la fuga por completo:
/// subir la versión en un solo sitio ahora es un rojo, no una discrepancia que
/// alguien descubre tres releases después.
void main() {
  test('la versión de la interfaz coincide con pubspec.yaml', () {
    final pubspec = _archivo('pubspec.yaml').readAsStringSync();
    final coincidencia = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(
      coincidencia,
      isNotNull,
      reason: 'pubspec.yaml no tiene una línea «version: x.y.z» reconocible; '
          'si cambió el formato, actualiza también esta prueba.',
    );

    expect(
      AppConfig.version,
      coincidencia!.group(1),
      reason: 'La versión visible (AppConfig.version) y la del pubspec no '
          'pueden separarse: la primera es la que ve el usuario en el menú, el '
          'pie y la portada.',
    );
  });

  test('la versión de la interfaz coincide con la última del CHANGELOG', () {
    final changelog = _archivo('CHANGELOG.md').readAsStringSync();
    final primera = RegExp(
      r'^##\s*\[([0-9]+\.[0-9]+\.[0-9]+)\]',
      multiLine: true,
    ).firstMatch(changelog);

    expect(
      primera,
      isNotNull,
      reason: 'CHANGELOG.md no tiene ninguna cabecera «## [x.y.z]».',
    );

    expect(
      AppConfig.version,
      primera!.group(1),
      reason: 'La entrada más reciente del CHANGELOG y la versión que se pinta '
          'tienen que ser la misma. Si acabas de publicar, añade la entrada; si '
          'acabas de subir la versión, súbela en los dos sitios.',
    );
  });
}

/// Localiza un archivo de la raíz del paquete subiendo por los directorios
/// padres.
///
/// `flutter test` corre desde la raíz del paquete, pero asumirlo convertiría un
/// cambio de invocación en un «archivo no encontrado» que no explica nada.
File _archivo(String relativa) {
  var directorio = Directory.current;

  for (var intentos = 0; intentos < 6; intentos++) {
    final candidato = File('${directorio.path}/$relativa');
    if (candidato.existsSync()) return candidato;

    final padre = directorio.parent;
    if (padre.path == directorio.path) break;
    directorio = padre;
  }

  fail(
    'No encontré «$relativa» subiendo desde ${Directory.current.path}. '
    'Ejecuta la prueba desde la raíz del repositorio.',
  );
}
