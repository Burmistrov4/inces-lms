/**
 * Reglas sobre cómo se muestra una persona en las listas administrativas.
 *
 * Son puras a propósito: la composición del nombre ocurría dentro de
 * `repos-supabase.ts` (`resolverEstudiantes`) y no había forma de probarla sin
 * levantar un cliente de Supabase. Enterrada allí, el defecto que corrige este
 * archivo no lo veía ninguna prueba.
 *
 * **El defecto:** `nombres` y `apellidos` se juntaban con
 * `[nombres, apellidos].filter(p => p.length > 0).join(' ')`. Un perfil con
 * los dos vacíos —que la base admite: la columna no es `NOT NULL` y el alta
 * automática sólo garantiza el trigger— producía `''`, es decir **una cadena
 * vacía, no `null`**. En el cliente, `nombre ?? id` no salta con `''` porque el
 * operador `??` sólo mira `null`/`undefined`: la fila del inscrito se quedaba
 * **en blanco** en vez de mostrar el correo o el UUID. Este archivo devuelve
 * `null` cuando no hay nombre, para que la cadena de emergencia del cliente
 * (nombre → correo → «Sin nombre registrado») funcione.
 */

/**
 * El nombre con que se muestra una persona, o `null` si no hay ninguno.
 *
 * `null` significa «no sé cómo se llama», y es información: quien consume esta
 * función decide su emergencia. Devolver `''` en su lugar sería mentir con
 * mecanismo de dato —un valor que parece resuelto y no lo está.
 */
export function nombreVisible(
  nombres: string | null | undefined,
  apellidos: string | null | undefined,
): string | null {
  const partes = [nombres, apellidos]
    .map((parte) => (typeof parte === 'string' ? parte.trim() : ''))
    .filter((parte) => parte.length > 0);

  const nombre = partes.join(' ').trim();
  return nombre.length > 0 ? nombre : null;
}
