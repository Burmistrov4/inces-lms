/// Guardia anti doble-toque.
///
/// **El defecto que viene a cerrar.** En la demo del 2026-10-20 Lorenzo pulsó
/// rápido dos veces sobre un botón que abre un diálogo y el sistema apiló **dos
/// ventanas**: la segunda pulsación lanzó otro `showDialog` mientras la primera
/// todavía estaba en pantalla. No es un falso positivo de la demo —es el
/// comportamiento estándar de Flutter— y se repite en cualquier botón cuya
/// acción no es idempotente (abrir un diálogo, lanzar una mutación, cambiar de
/// sección).
///
/// **Por qué un debounce por clave y no un bloqueo global.** Un simple
/// «ya hay un diálogo abierto, ignora el siguiente» rompe los flujos que
/// legitimamente encadenan diálogos (pop del primero y apertura del segundo en
/// el mismo gesto). La ventana de tiempo, en cambio, distingue el rebote
/// mecánico del dedo —dos pulsaciones en menos de medio segundo— de la
/// intención real, sin importar qué diálogo se abra después.
///
/// Uso:
/// ```dart
/// onPressed: () => conGuardia(onAbrirDialogo, 'aulas-guardar'),
/// ```
library;

import 'package:flutter/widgets.dart';

/// Ventana durante la cual una segunda pulsación con la misma clave se ignora.
///
/// 600 ms: por encima del rebote de un doble clic real y muy por debajo del
/// tiempo que tardaría una persona en pulsar otra vez el mismo botón queriendo
/// hacerlo. Si en algún flujo hace falta repetir una acción rápido, se sube la
/// ventana en ese sitio con [conGuardiaEn] en vez de subirla aquí para todos.
const Duration kVentanaAntiRebote = Duration(milliseconds: 600);

final Map<String, DateTime> _ultimaPulsacion = {};

/// ¿Se puede ejecutar la acción identificada por [clave]?
///
/// Devuelve `false` si la misma clave se pulsó hace menos de
/// [kVentanaAntiRebote]. No lanza excepciones: quien recibe `false` simplemente
/// no hace nada, que es exactamente lo que el usuario espera de un rebote.
bool permitirPulsacion(String clave, {Duration? ventana}) {
  final ahora = DateTime.now();
  final previa = _ultimaPulsacion[clave];
  _ultimaPulsacion[clave] = ahora;
  if (previa == null) return true;
  return ahora.difference(previa) >= (ventana ?? kVentanaAntiRebote);
}

/// Ejecuta [accion] sólo si [permitirPulsacion] lo autoriza.
///
/// **Ejecuta de inmediato y devuelve `void`, a propósito.** Antes devolvía un
/// `VoidCallback?` que había que invocar aparte, y en los ~30 sitios que la usan
/// como `onPressed: () => conGuardia(...)` el callback devuelto se **descartaba**:
/// ningún botón hacía nada. Compilaba —un `void` acepta cualquier retorno— y no
/// daba error, así que pasó desapercibido hasta que la matriz responsive
/// comprobó que la vista no cambiaba al pulsar el menú (medido el 2026-10-21).
/// Con ejecución inmediata, el patrón natural `() => conGuardia(...)` funciona.
///
/// Acepta `null` porque las fábricas de [BarraAccionesSuperiores] reciben
/// callbacks opcionales; envolver un `null` no puede romper el botón.
void conGuardia(VoidCallback? accion, String clave, {Duration? ventana}) {
  if (accion == null) return;
  if (!permitirPulsacion(clave, ventana: ventana)) return;
  accion();
}

/// Igual que [conGuardia] con una ventana propia, para flujos que necesitan
/// permitir repeticiones rápidas deliberadas.
void conGuardiaEn(
  VoidCallback? accion,
  String clave,
  Duration ventana,
) =>
    conGuardia(accion, clave, ventana: ventana);
