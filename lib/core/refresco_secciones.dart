/// Refresco en segundo plano al volver a una sección (stale-while-revalidate).
///
/// ## Por qué existe
///
/// El dashboard del administrador **ya cachea los paneles** (`_panelesCargados`
/// + `Offstage`), así que volver a una sección es instantáneo: no se reconstruye
/// el widget ni se vuelve a pedir nada. Eso es la mitad del patrón de Google.
///
/// La otra mitad es que esos datos **no quedan viejos**: si otro administrador
/// cambió algo, el usuario debe verlo al volver, sin una pantalla de carga.
///
/// ## Cómo se usa
///
/// 1. El dashboard llama a [RefrescoSecciones.notificar] cada vez que cambia de
///    sección.
/// 2. Los paneles que quieran refrescarse solos mezclan [RefrescoAlVolver] y
///    llaman a [RefrescoAlVolver.marcarCarga] cuando una carga termina bien.
/// 3. Al volver, si la última carga es más vieja que el umbral, el panel recarga
///    **en silencio**: conserva lo que muestra y sólo reemplaza lo que cambió.
library;

import 'package:flutter/widgets.dart';

/// Aviso de «el usuario acaba de cambiar de sección».
///
/// Es un [ValueNotifier] estático a propósito: los paneles se enteran sin que
/// haya que pasarles nada por constructor, que es lo que haría falta tocar
/// cuarenta archivos para enchufar una cosa que sólo le importa a unos pocos.
class RefrescoSecciones {
  RefrescoSecciones._();

  /// Lleva el **título de la sección** que se acaba de mostrar.
  ///
  /// No vale un contador: el dashboard mantiene TODOS los paneles vivos dentro
  /// de un `Stack` de `Offstage`, así que un aviso genérico los haría recargar
  /// **todos** en cada cambio de sección. Medido el 2026-10-23: con el aviso
  /// genérico `/admin/acceso` pasó de 990 ms de media a **4699 ms**, con un
  /// pico de **133 s** —dieciséis navegaciones por cuatro paneles que se
  /// refrescaban sin que nadie los estuviera mirando—.
  static final ValueNotifier<String?> cambios = ValueNotifier<String?>(null);

  /// El dashboard llama esto en cada cambio de sección.
  static void notificar(String seccion) => cambios.value = seccion;
}

/// Mixin para paneles que se refrescan solos al volver a ellos.
///
/// El umbral es deliberado: volver a una sección tiene que ser **instantáneo**,
/// así que si la última carga es reciente no se pide nada. Sólo se refresca
/// cuando los datos pueden haberse quedado atrás.
mixin RefrescoAlVolver<T extends StatefulWidget> on State<T> {
  /// Pasado este tiempo, volver a la sección recarga en segundo plano.
  static const umbral = Duration(seconds: 45);

  DateTime? _ultimaCarga;

  @override
  void initState() {
    super.initState();
    RefrescoSecciones.cambios.addListener(_alVolver);
  }

  @override
  void dispose() {
    RefrescoSecciones.cambios.removeListener(_alVolver);
    super.dispose();
  }

  /// Título de la sección del menú que muestra este panel.
  ///
  /// Es lo que hace que el refresco sea selectivo: sólo recarga el panel que el
  /// usuario acaba de abrir, no todos los que siguen vivos en el `Stack`.
  String get seccion;

  void _alVolver() {
    // **Sólo si el aviso es para esta sección.** Si no, un cambio de sección
    // recargaría todos los paneles vivos a la vez.
    if (RefrescoSecciones.cambios.value != seccion) return;
    final ultima = _ultimaCarga;
    // Sin carga previa no hay nada que refrescar: el panel aún está montando.
    if (ultima == null) return;
    if (DateTime.now().difference(ultima) < umbral) return;
    refrescarEnSegundoPlano();
  }

  /// Recarga los datos **sin** pantalla de carga: lo que ya se muestra se queda
  /// hasta que llegue lo nuevo.
  Future<void> refrescarEnSegundoPlano();

  /// Se llama cada vez que una carga termina bien.
  void marcarCarga() => _ultimaCarga = DateTime.now();
}
