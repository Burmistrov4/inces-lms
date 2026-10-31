import 'package:flutter/foundation.dart';

class AppConfig {
  /// VersiÃ³n visible en la interfaz (menÃº, pie y portada).
  ///
  /// **Tiene que coincidir con `pubspec.yaml`.** Medido el 2026-10-29: el
  /// `pubspec` iba por 1.5.5+7 y esta constante seguÃ­a en 1.5.1, asÃ­ que la app
  /// mostraba Â«v1.5.1Â» en el menÃº, en el pie y en la portada mientras el
  /// CHANGELOG documentaba 1.5.5. Es la misma discrepancia que ya se corrigiÃ³
  /// una vez haciendo que los paneles lean `AppConfig.version` â€” la constante
  /// era la Ãºnica fuente y se quedÃ³ atrÃ¡s.
  ///
  /// No se deriva del `pubspec` en tiempo de ejecuciÃ³n porque leer el paquete
  /// exigirÃ­a `package_info_plus` (y una llamada de plataforma en cada arranque
  /// web). En su lugar, `test/version_coherente_test.dart` compara las dos y
  /// falla si se separan.
  static const String version = '1.10.3';
  static const String versionLabel =
      'INCES LMS v$version Â· CFS Rafael Urdaneta Â· Prod 2026';

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _rawApiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// URL base de la API Fastify.
  ///
  /// Si se ejecuta en navegador Web (`kIsWeb`) y la app fue abierta desde
  /// una direcciÃ³n de red privada LAN (RFC 1918: 192.168.x.x, 10.x.x.x, 172.16-31.x.x),
  /// y la variable de compilaciÃ³n apunta a localhost o estÃ¡ vacÃ­a, se resuelve
  /// dinÃ¡micamente al host de la LAN en el puerto 3001.
  ///
  /// En dominios de producciÃ³n (p. ej. Cloudflare Pages o dominios pÃºblicos),
  /// localhost, o compilaciones con URL explÃ­cita no-localhost, respeta
  /// la configuraciÃ³n configurada sin alteraciones.
  static String get apiBaseUrl {
    final configurada = _rawApiBaseUrl.trim();
    if (!kIsWeb) return configurada;

    final uriActual = Uri.base;
    final hostActual = uriActual.host.trim();

    // En dominios de Cloudflare Pages (*.pages.dev) se delega al mismo origen
    // **sólo si no hay URL configurada**, para el caso en que el despliegue
    // incluya las Pages Functions de `functions/` que hacen de proxy.
    //
    // Medido el 2026-10-31: esas funciones apuntan a Render
    // (`RENDER_BACKEND_URL || onrender.com`) y **no viajan** en
    // `wrangler pages deploy build/web`, así que en producción el atajo dejaba
    // la app pidiendo `/api/v1/...` a Pages y recibiendo un 503 en HTML. Ese HTML
    // es el «El servidor respondió con contenido HTML en lugar de datos JSON»
    // de Cursos y PNA, Guardias, Aulas Virtuales, Archivos y Usuarios. La app
    // parecía muerta con Render arriba y abajo, porque nunca lo alcanzaba.
    if (hostActual.endsWith('.pages.dev') && configurada.isEmpty) {
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

  /// Devuelve un mensaje descriptivo si falta o estÃ¡ mal la configuraciÃ³n de
  /// compilaciÃ³n, o `null` si todo estÃ¡ en orden.
  ///
  /// No se limita a comprobar que no estÃ© vacÃ­o: una URL que aÃºn lleva la
  /// plantilla (`https://<project-ref>.supabase.co`) es no-vacÃ­a pero igual de
  /// inÃºtil, y antes pasaba desapercibida hasta que el login fallaba sin dar
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

  /// Lanza [StateError] con un mensaje claro si la configuraciÃ³n de compilaciÃ³n
  /// no estÃ¡ completa. Lo llama [main] antes de iniciar sesiÃ³n; el error se
  /// captura allÃ­ y se muestra una pantalla de fallo legible en lugar de una
  /// excepciÃ³n sin tratar en la consola.
  static void validate() {
    final problema = problemaConfiguracion();
    if (problema != null) throw StateError(problema);
  }
}
