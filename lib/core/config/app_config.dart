import 'package:flutter/foundation.dart';

class AppConfig {
  static const String version = '1.5.0';
  static const String versionLabel =
      'INCES LMS v$version · CFS Rafael Urdaneta · Prod 2026';

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _rawApiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// URL base de la API Fastify.
  ///
  /// Si se ejecuta en navegador Web (`kIsWeb`) y la app fue abierta desde
  /// una dirección de red privada LAN (RFC 1918: 192.168.x.x, 10.x.x.x, 172.16-31.x.x),
  /// y la variable de compilación apunta a localhost o está vacía, se resuelve
  /// dinámicamente al host de la LAN en el puerto 3001.
  ///
  /// En dominios de producción (p. ej. Cloudflare Pages o dominios públicos),
  /// localhost, o compilaciones con URL explícita no-localhost, respeta
  /// la configuración configurada sin alteraciones.
  static String get apiBaseUrl {
    final configurada = _rawApiBaseUrl.trim();
    if (!kIsWeb) return configurada;

    final uriActual = Uri.base;
    final hostActual = uriActual.host.trim();

    // En dominios de Cloudflare Pages (*.pages.dev): se delega de forma nativa a
    // las Cloudflare Pages Functions del mismo origen para garantizar respuesta
    // inmediata en el Edge (0 ms cold start) y compatibilidad total con CORS.
    if (hostActual.endsWith('.pages.dev')) {
      final esquema = uriActual.scheme.isNotEmpty ? uriActual.scheme : 'https';
      return '$esquema://$hostActual';
    }

    if (esHostPrivadoLan(hostActual)) {
      if (configurada.isEmpty || configurada.contains('localhost') || configurada.contains('127.0.0.1')) {
        final esquema = uriActual.scheme.isNotEmpty ? uriActual.scheme : 'http';
        return '$esquema://$hostActual:3001';
      }
    }
    return configurada;
  }

  /// Comprueba si un host corresponde a una subred privada local (LAN / RFC 1918).
  @visibleForTesting
  static bool esHostPrivadoLan(String host) {
    if (host.isEmpty || host == 'localhost' || host == '127.0.0.1') return false;
    if (host.endsWith('.local') || host.endsWith('.lan')) return true;
    final partes = host.split('.');
    if (partes.length == 4) {
      final p0 = int.tryParse(partes[0]);
      final p1 = int.tryParse(partes[1]);
      if (p0 != null && p1 != null) {
        if (p0 == 10) return true;
        if (p0 == 192 && p1 == 168) return true;
        if (p0 == 172 && p1 >= 16 && p1 <= 31) return true;
      }
    }
    return false;
  }

  /// Devuelve un mensaje descriptivo si falta o está mal la configuración de
  /// compilación, o `null` si todo está en orden.
  ///
  /// No se limita a comprobar que no esté vacío: una URL que aún lleva la
  /// plantilla (`https://<project-ref>.supabase.co`) es no-vacía pero igual de
  /// inútil, y antes pasaba desapercibida hasta que el login fallaba sin dar
  /// pistas. Mejor fallar fuerte y temprano, con la causa nombrada.
  static String? problemaConfiguracion() {
    if (supabaseUrl.isEmpty) {
      return 'Falta SUPABASE_URL. Compila con '
          '--dart-define-from-file=.env.json';
    }
    if (supabaseUrl.contains('<') || supabaseUrl.contains('project-ref')) {
      return 'SUPABASE_URL parece una plantilla sin rellenar '
          '(contiene "<" o "project-ref"). Usa el .env.json real.';
    }
    if (supabaseAnonKey.isEmpty) {
      return 'Falta SUPABASE_ANON_KEY. Compila con '
          '--dart-define-from-file=.env.json';
    }
    return null;
  }

  /// Lanza [StateError] con un mensaje claro si la configuración de compilación
  /// no está completa. Lo llama [main] antes de iniciar sesión; el error se
  /// captura allí y se muestra una pantalla de fallo legible en lugar de una
  /// excepción sin tratar en la consola.
  static void validate() {
    final problema = problemaConfiguracion();
    if (problema != null) throw StateError(problema);
  }
}
