# Decisión pendiente: el modelo de carpetas

**Fecha:** 2026-10-24 · **Autor:** Aria · **Para:** Lorenzo Roca

---

## El problema, medido

«Archivos del Centro» tiene dos mitades que no viven en el mismo sitio:

| Mitad | Dónde vive | ¿Sobrevive a otro dispositivo? |
|---|---|---|
| Los **archivos** | `files_metadata` en Postgres + el objeto en R2 | **Sí** |
| Las **carpetas** | `SharedPreferences` (almacenamiento del navegador) | **No** |

Consecuencia concreta: un administrador crea la carpeta «Metalmecánica» en su
laptop, entra desde el teléfono y la carpeta **no está**. No es que se haya
perdido el archivo —los archivos están— es que la organización que hizo **no
existe fuera de ese navegador**.

Medido en `cpanel_explorador_archivos_panel.dart` (2 630 líneas):

- **77** menciones de «carpeta»
- **3** usos de `TipoElemento.carpeta`
- **17** usos de `_rutaActual` / `_rutaTexto` (la navegación por árbol)
- **5** puntos de persistencia en `SharedPreferences`

---

## Opción A — Quitar las carpetas (recomendada)

**Qué es:** «Archivos del Centro» pasa a ser una **lista plana con filtros**:
por tipo (entrega de tarea / guía del docente / documento del centro), por
autor y por fecha. Se borra el árbol, el botón «Nueva carpeta» y la persistencia
local.

**Por qué la recomiendo:**

1. **Es el modelo de Classroom.** Classroom no tiene carpetas: organiza por clase
   y por tarea. Nuestro `files_metadata` **ya** tiene ese eje
   (`entity_type` + `entidad_id`), así que la información para agrupar existe y
   es real. Las carpetas eran un eje *inventado* encima de uno que ya estaba.
2. **Cero migraciones.** No hay tabla nueva, no hay RLS nueva, no hay endpoints.
3. **Elimina la mentira de raíz** en vez de mudarla de sitio.
4. **Menos código:** de 2 630 líneas deberían quedar ~800, porque el árbol, la
   ruta, el diálogo de carpeta y la persistencia se van enteros.

**Coste:**

| Trabajo | Cantidad |
|---|---|
| Archivos Dart tocados | **1** (el panel) |
| Menciones a reescribir | **77** |
| Migraciones | **0** |
| Endpoints nuevos | **0** |
| Pruebas a actualizar | la matriz (capturas) |

**Riesgo:** medio-bajo. Es cirugía en un solo archivo, y la matriz detecta
cualquier desborde o panel vacío. No hay datos que perder: las carpetas locales
de un navegador no son datos del centro.

**Lo que se pierde:** la posibilidad de agrupar a mano documentos sueltos. Se
mitiga con el filtro por tipo, que ya distingue los tres orígenes.

---

## Opción B — Carpetas de servidor

**Qué es:** las carpetas pasan a Postgres, con jerarquía y RLS, y el panel deja
de usar `SharedPreferences`.

**Qué habría que construir:**

| Pieza | Detalle |
|---|---|
| **1 migración** | tabla `document_folders` (`id`, `nombre`, `padre_id`, `creado_por`, `created_at`) + RLS (admin todo, docente lo suyo) + `carpeta_id` en `files_metadata` + guarda contra ciclos en la jerarquía |
| **4 endpoints** | listar, crear, renombrar, borrar (con la regla de qué pasa con los archivos de dentro) |
| **~4 archivos Dart** | modelo, gateway, repositorio, servicio |
| **1 panel reescrito** | la persistencia cambia de `SharedPreferences` a llamadas al backend |
| **Aserciones nuevas** | en `validate.mjs` (RLS, jerarquía, borrado con contenido) |
| **E2E** | una prueba de que una carpeta creada en un contexto aparece en otro |

**Coste:** **1 migración + 4 endpoints + ~4 archivos nuevos + el panel.** Es
del orden de **5-8 veces** el trabajo de la opción A, y añade una entidad nueva
que mantener (con su RLS, su auditoría y su borrado en cascada).

**Riesgo:** medio-alto. Toca base de datos, backend y frontend a la vez, y el
borrado de una carpeta con archivos dentro es una decisión de producto que
alguien tiene que tomar (¿se borran los archivos? ¿suben al padre? ¿se bloquea
el borrado?).

---

## Recomendación

**Opción A.** No porque sea más barata —que también— sino porque **el eje de
organización correcto ya existe y es el del producto**: un archivo del centro no
se organiza en «Metalmecánica / 2026», se organiza por *qué es* (una entrega, una
guía, un documento suelto) y *de quién*. Las carpetas añadían una segunda verdad
que además sólo vivía en un navegador.

Si más adelante el centro pide carpetas de verdad, la opción B sigue estando
disponible y entonces se hará **con el eje nuevo ya limpio**, no encima de dos
sistemas conviviendo.

---

## Mientras decides

El panel ya no miente: arranca vacío, los archivos muestran su origen real y el
autor/fecha son verdaderos (2026-10-24). Lo único que queda es que **las carpetas
siguen siendo locales**, y eso hoy no se anuncia en la interfaz.

**Decisión que necesito:** ¿A o B? Con A avanzo en una sesión; con B necesito
además que definas qué pasa al borrar una carpeta con archivos dentro.
