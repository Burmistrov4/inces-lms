/// Caché de lecturas compartido, con *single-flight*.
///
/// ## Por qué existe (medido, no supuesto)
///
/// Sobre una corrida completa de la matriz (328 peticiones), `GET
/// /api/v1/mi-horario` se pidió **56 veces** —el 17 % de todo el tráfico— y las
/// 56 eran **la misma URL sin parámetros**. Cuatro paneles distintos (Mis aulas,
/// Asistencia, Calificaciones, Mi horario) leen el mismo horario cada uno por su
/// cuenta, y cada lectura cuesta un viaje de red a Supabase (349–1331 ms medidos
/// el 2026-10-23).
///
/// Esta caché convierte esas 56 lecturas en una: la primera pide y las siguientes
/// —dentro del TTL— se sirven de memoria. Si varias llegan a la vez,
/// **comparten la misma petición** (*single-flight*): no se disparan dos.
///
/// ## Seguridad: hay que vaciarla al cerrar sesión
///
/// La clave es la URL, así que sin vaciado el siguiente usuario del mismo
/// dispositivo vería los datos del anterior durante el TTL. Por eso
/// `AuthService.cerrarSesion()` llama a [invalidarTodo].
library;

/// Una entrada de la caché: o un valor ya resuelto, o una petición en vuelo.
class _EntradaCache {
  _EntradaCache({this.valor, this.vuelo, required this.expira});

  final Object? valor;
  final Future<Object?>? vuelo;
  final DateTime expira;

  bool get fresca => DateTime.now().isBefore(expira);
}

/// Caché en memoria de lecturas, con TTL y *single-flight*.
class CacheLecturas {
  final Map<String, _EntradaCache> _entradas = {};

  /// Lee [clave] de memoria si está fresca; si no, llama a [fn].
  ///
  /// [ttl] es cuánto vale el dato. Debe ser corto: es un respaldo para no
  /// repetir la misma lectura en la misma pantalla, no una fuente de verdad.
  Future<T> leer<T>(
    String clave, {
    required Duration ttl,
    required Future<T> Function() fn,
  }) {
    final ahora = DateTime.now();
    final entrada = _entradas[clave];

    // 1. Valor ya resuelto y fresco.
    if (entrada != null && entrada.valor != null && entrada.fresca) {
      return Future.value(entrada.valor as T);
    }

    // 2. Petición en vuelo: se espera esa, no se dispara otra.
    final vuelo = entrada?.vuelo;
    if (vuelo != null) return vuelo as Future<T>;

    // 3. Ni una cosa ni la otra: se pide.
    final nueva = fn();
    _entradas[clave] = _EntradaCache(
      vuelo: nueva,
      expira: ahora.add(ttl),
    );
    return nueva.then((valor) {
      _entradas[clave] = _EntradaCache(
        valor: valor,
        expira: DateTime.now().add(ttl),
      );
      return valor;
    }).catchError((Object e, StackTrace t) {
      // **Un fallo no se cachea.** Se quita la entrada para que el siguiente
      // reintento salga de verdad: una caché que recuerda errores convierte un
      // fallo puntual en una pantalla rota durante todo el TTL.
      _entradas.remove(clave);
      throw Error.throwWithStackTrace(e, t);
    });
  }

  /// Vacía todo. Se llama al cerrar sesión.
  void invalidarTodo() => _entradas.clear();

  /// Cuántas entradas hay ahora (para pruebas y diagnóstico).
  int get tamano => _entradas.length;
}

/// La instancia compartida por toda la app.
final CacheLecturas cacheDeLecturas = CacheLecturas();
