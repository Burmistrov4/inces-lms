# Auditoría adversarial de los cambios nocturnos — 2026-10-13 (segunda fase)

Nada de lo que afirma el resumen de la sesión anterior se da por bueno: cada
afirmación se comprobó contra el disco o se volvió a ejecutar. Donde no se pudo
comprobar, queda **BLOCKED** con la causa medida, no como verde.

**Resultado: la auditoría encontró tres defectos reales en los cambios de la
noche, todos corregidos en esta sesión. El más serio habría puesto en rojo los
cuatro workflows de CI.**

---

## 1. Estado real del árbol

| Comprobación | Resultado |
|---|---|
| Raíz y rama | `C:/Users/Loro/Desktop/Cuarto Semestre/1. Servicio Comunitario/INCES-LMS-PROJECT`, rama **main** |
| HEAD | `ad5ce67` (2026-10-10) — **igual que `origin/main`**: la noche no dejó ningún commit, todo quedó en el árbol de trabajo |
| Inventario | 20 modificados + 12 nuevos, coincidente con el handover salvo `pubspec.lock` (añadido por esta auditoría, ver §2.4) |
| `git diff --check` | **FAIL al inicio** (3 líneas de sólo espacios en `AndroidManifest.xml`) → **corregido, ahora exit 0** |
| Credenciales y config local | `backend/.env`, `android/local.properties`, `.dart_tool/` intactos: siguen en `.gitignore` y `package_config.json` quedó **byte a byte** igual al respaldo previo |
| Residuo propio | `backend/server-e2.err` (86 B, log de un lanzamiento fallido mío) eliminado |
| Fines de línea | 5 archivos CRLF en disco vs LF en el blob: **no es defecto** — el repo normaliza a LF y `core.autocrlf` maneja el checkout; medido archivo por archivo contra `git show HEAD:` |
| Codificación | Todos los archivos tocados **UTF-8 válido sin doble codificación**. El mojibake de `pubspec.yaml` (29 secuencias) es **preexistente**: idéntico en HEAD |

---

## 2. Los tres defectos encontrados y corregidos

### 2.1 `flutter_localizations` no resolvía: `intl` bloqueaba todo el CI (P0)

**Medido ahora, no supuesto.** `flutter pub get` no puede correr aquí (`231`),
así que resolví con el SDK directo:

```
$ flutter pub get                       → EXIT=1, CreateFile failed 231
$ dart pub get                          → EXIT=1, «every version of
  flutter_localizations from sdk depends on intl ^0.20.3 …
  inces_lms_app depends on intl ^0.19.0 → version solving failed»
```

**Consecuencia de no haberse resuelto nunca:** `flutter pub get` es el primer
paso de `web_bundle.yml`, `flutter_ci.yml`, `e2e.yml` y del nuevo
`android_bundle.yml`. Los cuatro habrían muerto en el primer paso: el cambio de
la noche no llegaba a ningún lado. La razón por la que no se vio es exactamente
la que esta fase prohibió: el analizador de la noche «pasó» porque se inyectó a
mano la entrada de `flutter_localizations` en `.dart_tool/package_config.json`,
saltándose la resolución. Un archivo generado editado a mano acredita una
instalación normal, y aquí lo enmascaraba.

**Corregido.** `pubspec.yaml`: `intl: ^0.19.0` → `^0.20.3`, con la razón en el
comentario. El único uso del proyecto es `DateFormat('dd/MM/yyyy')`
(`campo_planilla.dart:211,387`), idéntico en ambas versiones —medido, no
supuesto—. Resuelto de verdad:

```
$ dart pub get   → EXIT=0, «Changed 2 dependencies!»
```

El lock cambia sólo lo que debe (+`flutter_localizations` del SDK, `intl`
0.19.0 → 0.20.3; 7 inserciones, 2 borrados) y `.dart_tool/package_config.json`
lo generó `pub 3.13.0`, no una mano.

### 2.2 `unused_import` en el test nuevo (P1, habría tumbado `flutter analyze`)

El sustituto del analizador marcó `test/inscripcion_modelo_test.dart:3` —
`unused_import` de `models/inscripcion.dart`: el tipo se infiere del helper. Con
el listón del CI (que falla por `info`), eso es rojo. **Corregido**: import
eliminado; sustituto ahora en 226 archivos, 0 issues, exit 0.

### 2.3 Un mensaje al usuario seguía mostrando el UUID (P2, corrección incompleta)

Barriendo `estudianteId` en `lib/` apareció lo que la noche dio por corregido:
`cpanel_inscripciones_panel.dart:151` —
«**Promovido 3f2a9c61-…: ya tiene su asiento.**». Un SnackBar con la clave
interna cruda. **Corregido** con `promovida.etiquetaEstudiante`. Revisados los
demás usos: los que quedan son claves de widget, nombres de archivo y valores de
formulario —no etiquetas visibles—, y el dropdown de reincorporar ya usa
`_etiquetaCandidato` → `etiquetaEstudiante`.

---

## 3. Lo que sí quedó verificado (con evidencia)

**Backend, corrido hoy, no heredado.** `npm run verify` → **685/685, 33
archivos, exit 0**. `npm run build` → **exit 0** (`dist/server.js` fresco).

**La regla del nombre visible.** Código leído entero
(`reglas-perfiles.ts` + `resolverEstudiantes` + los getters del modelo) y
pruebas revisadas una por una: cubren `null`, `undefined`, `''`, sólo-espacios,
recorte y una sola parte. No son permisivas.

**Las cuentas de demostración.** `esCuentaDemo` decide **por dato**
(`@semilla.invalid`, normalizado con `trim().toLowerCase()`), nunca por una
lista manual. Una cuenta **real sin nombre** produce «Sin nombre registrado» sin
chip; una cuenta demo produce chip. Riesgo residual honesto y único: si alguna
vez se creara una cuenta real con correo en `@semilla.invalid` (TLD reservado
RFC 2606, no recibible), se etiquetaría como demostración. Es la única condición
en que el criterio se puede equivocar, y equivocarse hacia «demo» es el lado
seguro: no borra ni oculta nada.

**robots.txt / sitemap.xml.** Archivos correctos (`Allow: /$`,
`Sitemap:` exacto, `<urlset>`, sólo la portada). La pieza que decide si el
arreglo puede funcionar —si `flutter build web` copia los archivos de `web/` al
bundle— quedó probada **por la fuente del toolchain**
(`flutter_tools/lib/src/build_system/targets/web.dart:657-672`: copia todo
`web/` salvo `index.html` y `flutter_bootstrap.js`) y **empíricamente**:
`build/web` y `deploy-ad5ce67/` contienen a la vez lo generado
(`main.dart.js`, `flutter_service_worker.js`, `version.json`) y lo copiado
(`manifest.json`, `_headers`, `favicon.png`, `icons/`). E2E de SEO: **3/3 ok**
contra los archivos fuente de hoy.

**Android.** Manifiesto `main` con `INTERNET`, `label="INCES LMS"`, cámara
`required="false"`. Iconos: 5/5 mipmaps en el tamaño exacto de su densidad,
foreground adaptativo 432×432 con la marca en la zona segura (bbox 285 = 66 %),
marca presente (41,7 % de píxeles no blanco, color dominante `#6C408D`). Las
afirmaciones de la cabecera del workflow se verificaron contra el código:
`signingConfig = debug` (cierto, `build.gradle.kts:66`), JRE 1.8.0_501 (cierto,
remedido), Android Studio ausente (cierto). Ajusté una imprecisión: decía «tres
intentos», fueron tres estrategias con varias invocaciones.

**Workflow Android.** YAML válido, 10 pasos, `permissions: contents: read`,
secretos `SUPABASE_URL`/`SUPABASE_ANON_KEY` **comprobados antes de usarse y
nunca impresos**, artefactos con `if-no-files-found: error` y retención 30 días.
Los cuatro workflows fijan Flutter 3.47.0 y hacen `flutter pub get`: CI resuelve
lo mismo que resolví aquí.

---

## 4. BLOCKED y NOT RUN (con causa, no con excusa)

| Comprobación | Estado | Causa medida |
|---|---|---|
| `flutter test` (suite Dart) | **BLOCKED** | `CreateFile failed 231`: el VM de Dart no puede crear la tubería de su hijo. `flutter pub get` muere igual (spawnea `git.exe` y `where.exe`) |
| `flutter analyze` real | **BLOCKED** | `dart analyze` también spawnea el analysis server (`dartaotruntime.exe … analysis_server_aot.dart.snapshot`) → `231` |
| `flutter build web` | **BLOCKED** | misma causa |
| Build Android local | **BLOCKED** | `231` + sin JDK 17+ (JRE 1.8.0_501) |
| E2E completo (24/24) contra bundle | **BLOCKED** | no hay bundle fresco que sirvir; en CI `e2e.yml` compila y sirve `build/web` |
| Suite E2E de SEO contra el **bundle construido** | **NOT RUN** | 3/3 sí pasó contra los archivos fuente; dos corridas (300 s y 20 min) se mataron **en el teardown del arnés**, sin línea de resumen ni código de salida. Las **tres pruebas pasaron** (`ok 1/2/3` en ambas corridas); por el criterio de esta fase —no se declara PASS sin código cero— el resultado honesto es «pruebas verdes, salida no verificada» |
| Validación `strings` sobre `libapp.so` | **riesgo aceptado** | si el snapshot AOT algún día comprime sus literales, la guarda daría un falso negativo; falla **seguro** (cancela), y el comentario del workflow ya dice qué hacer si pasa |

**Nota sobre la suite de SEO contra el bundle:** la comprobación que de verdad
importa —que Cloudflare Pages sirva `text/plain` y `application/xml` en
producción— no se puede hacer sin publicar. La pieza intermedia (que los
archivos lleguen al bundle) quedó probada por la fuente del toolchain y por el
bundle viejo; el resto es trabajo de CI.

---

## 5. Estado y qué falta para publicar

**No publiques todavía.** Lo que queda antes:

1. Commit + push. Con el push corren solos `flutter_ci.yml` (analizador real y
   suite: la verificación que aquí no se pudo hacer), `e2e.yml` (bundle fresco +
   E2E contra él, incluida la suite de SEO) y, lanzado a mano,
   `android_bundle.yml`.
2. Si `flutter_ci.yml` sale verde → el cambio de localizaciones queda verificado
   por el analizador de verdad, que es el instrumento que esta sesión no pudo
   usar.
3. Si `e2e.yml` sale verde → el spec de SEO queda medido contra el bundle
   construido, no contra los fuentes.
4. Sólo entonces, publicar el artefacto `web-produccion` (§5.2 del
   procedimiento) y comprobar en producción:
   `curl -sI https://inces-lms.pages.dev/robots.txt` debe decir
   `content-type: text/plain`, y `/sitemap.xml`, XML.

**Sigue externo a esta sesión:** clave de firma para Play, SMTP/Resend,
`SUPABASE_JWT_SECRET`, los 6 secretos del barrido D9, la lista de campos de
HACER (D17).

---

## 6. Archivos tocados por esta auditoría

`pubspec.yaml` (`intl ^0.20.3` + comentario), `pubspec.lock` (resuelto por pub,
no a mano), `test/inscripcion_modelo_test.dart` (import eliminado),
`lib/screens/admin/cpanel_inscripciones_panel.dart` (aviso sin UUID),
`android/app/src/main/AndroidManifest.xml` (espacios en blanco),
`.github/workflows/android_bundle.yml` (precisión del comentario), este
documento y la memoria diaria. **Nada commiteado, nada publicado.**
