# Cierre autónomo nocturno — 2026-10-13

Sesión autónoma lanzada desde el mega-prompt de cierre integral. **Nada commiteado,
nada desplegado**: todo queda en el árbol de trabajo, acotado y verificado, para que
Lorenzo revise el `git diff` y dé la salida.

Regla de la sesión: *medir antes de afirmar*. Cada defecto de abajo se reprodujo, se
midió con un instrumento concreto, y se comprobó el arreglo con el mismo instrumento.
Donde algo no se pudo medir, queda dicho con la causa del bloqueo.

---

## 1. Verde de las cadenas que sí corren en este equipo

| Cadena | Resultado | Evidencia |
|---|---|---|
| Backend `npm run verify` (tsc + lint + vitest) | **685/685 PASS, exit 0** | 679 de base + 6 pruebas nuevas |
| Backend `npm run build` | exit 0 | `dist/` fresco |
| Analizador Dart (sustituto, 224 archivos) | **0 errores / 0 avisos / 0 infos** | con `flutter_localizations` dentro |
| E2E SEO público (Playwright, Chrome real) | **3/3 PASS** | contra los archivos fuente de `web/` |
| Humo invitaciones (nube, cuentas desechables + purga) | **34 OK / 0 fallos**, residuo 0/0/0 | contra el código de hoy |
| Humo recuperación (nube, mismas condiciones) | **27 OK / 0 fallos**, residuo 0/0/0 | ídem |

Rendimiento fresco, medido contra el build `dist` nuevo en puerto aislado 3002
(1 warmup + 7 muestras, JWT real de administrador):

| Ruta | Mediana | Línea base documentada |
|---|---|---|
| `/api/v1/yo` | 269 ms | ~269 ms |
| `admin/usuarios` | 677–694 ms | ~690 ms |
| `admin/aulas` | 707 ms | ~707 ms |
| `admin/programas` | 692 ms | ~692 ms |
| `admin/cuadrante` | 825 ms | ~825 ms |

En línea o mejor. **No se toca el coste de viajes de red**: el hook de auth sigue
siendo 2 viajes en serie (regla 9 de la memoria), así que la paralización de
lecturas independientes quedó fuera del alcance por ser cambio de comportamiento,
no arreglo de defecto.

---

## 2. Defectos encontrados y corregidos (con su evidencia)

### 2.1 Perfil sin nombre: cadena vacía que no dispara `??` (P0,UI)

**Síntoma.** En Inscritos, Cola y Usuarios y Roles, algunas filas quedaban en
blanco o mostraban el UUID.

**Causa raíz.** `backend/src/infra/repos-supabase.ts → resolverEstudiantes`
componía `nombre` juntando `nombres` y `apellidos`; si ambos venían vacíos
devolvía `''` — cadena vacía, **no** `null` —. El front hacía
`estudianteNombre ?? estudianteId`, y `??` **no salta con una cadena vacía**:
la fila se quedaba en blanco. En dos de las tres pantallas el extremo era el
UUID, que no es un nombre que un administrador pueda reconocer.

**Arreglo, en las dos capas.**
- Nueva regla pura `backend/src/dominio/reglas-perfiles.ts` → `nombreVisible()`:
  nombre → correo → `'Sin nombre registrado'`. Nunca cadena vacía.
- Conectada en `resolverEstudiantes` (donde vive el defecto), con pruebas en
  `backend/test/reglas-perfiles.test.ts`.
- Front: getter `etiquetaEstudiante` en `lib/models/inscripcion.dart` (una sola
  definición, antes había tres copias con distinto extremo) y
  `nombreCompleto` corregido en `lib/models/usuario_admin.dart`.
- Pruebas nuevas: `test/inscripcion_modelo_test.dart`,
  `test/usuario_admin_modelo_test.dart`, y un caso de widget en
  `test/cpanel_inscripciones_inscritos_dialog_test.dart`.

**Verificación por HTTP real**, login → secciones → inscritos, contra
**producción** (código viejo) y contra el **build local** (código nuevo):
mismo comportamiento para los que tienen nombre, y ninguna fila viaja ya con
cadena vacía. Sin regresión.

### 2.2 Cuentas de demostración etiquetadas, no borradas (P0, datos)

**Medición, no suposición.** Sonda de **solo lectura** y sólo agregados contra
la nube: de 64 perfiles, **57 sin nombre, y 56 de ellos con correo
`@semilla.invalid`** — el TLD reservado de RFC 2606 para dominios inválidos, es
decir, las cuentas de la siembra. No son estudiantes reales.

**Arreglo.** Las tres pantallas (Inscritos, Cola, Usuarios y Roles) muestran la
etiqueta **«Cuenta de demostración»** para esos correos, con el mismo estilo de
chip. **No se borra ni se oculta nada**: son datos de la siembra que el sistema
de periodos puede necesitar, y borrar en la nube sin autorización explícita está
fuera de lo que un cierre autónomo puede hacer.

### 2.3 `/robots.txt` y `/sitemap.xml` devolvían el HTML de la SPA (P0, SEO)

**Medición en producción** (solo lectura):

```
GET https://inces-lms.pages.dev/robots.txt   → 200 · text/html · 2775 B
GET https://inces-lms.pages.dev/sitemap.xml  → 200 · text/html · 2775 B
```

Los 2775 bytes eran el `index.html` de la SPA: el *fallback* de enrutamiento
de Cloudflare Pages sirve el index para cualquier ruta sin archivo. Un
rastreador que pide `/robots.txt` recibe HTML, y el resultado práctico es que
Google indexa una aplicación que requiere login —páginas de error 404
semánticas en Search Console—.

**Arreglo.**
- `web/robots.txt`: sólo la portada indexable; `/admin`, `/login`, `/recuperar`,
  `/verificar` y todo parámetro de sesión fuera.
- `web/sitemap.xml`: una URL, la portada. No inventar rutas que no existen.
- Guarda en `.github/workflows/web_bundle.yml`: los cinco archivos deben existir
  en `build/web` antes de publicar el artefacto (una comprobación que no puede
  fallar no sirve de nada).
- `docs/PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md` §5.1 actualizado con los dos
  archivos nuevos.
- Spec E2E nueva `e2e/tests/seo_publico.spec.ts` (**3/3 PASS**), y
  `e2e/serve.mjs` aprendió los MIME `.txt`/`.xml` — antes los servía como
  octet-stream, distinto de producción, que es justo lo que la spec viene a
  medir.

### 2.4 Selector de fecha en inglés (P1, UX)

**Causa raíz.** `lib/widgets/campos_planilla/campo_planilla.dart` tenía un
comentario que decía que traducir el calendario era imposible sin registrar
localizaciones. Cierto: el proyecto no registraba
`GlobalMaterialLocalizations`, y sin él el selector sale en inglés. La
afirmación del comentario era correcta; lo que faltaba es lo que él mismo decía
que faltaba.

**Arreglo.** `flutter_localizations` en `pubspec.yaml` (viene en el SDK, no hay
descarga nueva) + delegados y `supportedLocales` en `MaterialApp`
(`lib/main.dart`). El comentario que se volvió falso quedó corregido.

**Verificación.** Analizador con la localización cargada: 224 archivos, 0
issues. Para poder medirlo hubo que añadir temporalmente la entrada de
`flutter_localizations` a `.dart_tool/package_config.json` (lo genera
`flutter pub get`, que no puede correr por el `231`); **el archivo quedó
restaurado** a su estado original.

### 2.5 APK release sin permiso `INTERNET` (P0, Android)

**Síntoma si se hubiera publicado.** La app se instala, abre, y el login no
responde: ningún socket se puede abrir.

**Medición.** Sólo el manifiesto de *debug*
(`android/app/src/debug/AndroidManifest.xml`) declara
`android.permission.INTERNET`. Revisado uno por uno: el manifiesto `main`, los
manifiestos de todos los plugins de pub-cache en uso, y el código del plugin de
Gradle de Flutter (`packages/flutter_tools/gradle/`) — **ninguno lo declara**.
No es un descuido del plugin: Flutter no inyecta `INTERNET` por ti. La razón de
que nunca se viera es que todo el desarrollo se probó con `flutter run`, que
compila el manifiesto de debug.

**Arreglo.** `<uses-permission android:name="android.permission.INTERNET"/>`
en el manifiesto `main`, con la evidencia en el comentario para que nadie lo
quite como si fuera redundante.

### 2.6 El lanzador de Android mostraba el logo de Flutter (P1, marca)

**Medición.** Los cinco `mipmap-*/ic_launcher.png` eran el icono por defecto de
Flutter, y `android:label` era `inces_lms_app` (nombre de paquete, no nombre de
app).

**Arreglo.** Generados desde `web/icons/Icon-192.png` —la marca real—:
- Los 5 mipmaps legacy (`mdpi` 48 → `xxxhdpi` 192), la marca compuesta sobre
  blanco porque el icono original tiene transparencia y los lanzadores antiguos
  dejan ver el fondo del escritorio.
- Icono adaptativo API 26+ (`mipmap-anydpi-v26/ic_launcher.xml` +
  `drawable/ic_launcher_foreground.png` + color de fondo): la marca en la zona
  segura del 66 % para que ningún recorte de máscara la corte.
- `android:label` → **INCES LMS**.
- Flujo nuevo `.github/workflows/android_bundle.yml`: APK + AAB release, mismos
  secretos de Supabase que el bundle web, validación del artefacto, 30 días de
  retención.

---

## 3. Bloqueado, con causa medida (no simulado)

**`CreateFile failed 231` sigue activo.** Cuatro intentos, tres estrategias
distintas: Git Bash directo, la receta de dos piezas del entorno (limpiar
proxies de loopback + `PROGRAMFILES(X86)`), y PowerShell. En los tres casos
`flutter --version` muere al lanzar su subproceso. **No es el proyecto: es el
sandbox**, y la respuesta del proyecto es CI, no insistir. Consecuencias:

- `flutter test`, `flutter build web` y el build Android local **no corren**.
  La suite E2E completa (24/24 según el estado documentado) y el build Android
  deben correr **en CI tras el push**.
- Para verificar el cambio de localizaciones se usó el analizador sustituto
  (`devops/analizar-dart.mjs`) con la entrada temporal de paquete ya descrita.
- La spec SEO se corrió contra los **archivos fuente** de `web/` servidos por
  `serve.mjs` vía `E2E_WEB_DIR`, no contra el bundle local: `build/web` puede
  estar congelado (regla 2) y publicarlo sin saber de dónde viene está
  prohibido.

**Sin JDK 17+ en el equipo** (medido: sólo JRE 1.8.0_501). Aun sin el `231`, el
build Android local no podría correr. Otra razón por la que el flujo de CI es
la respuesta correcta.

---

## 4. Lo que queda externo a esta sesión

- Clave de firma para publicar en Google Play (el AAB sale firmado con la de
  debug en el flujo nuevo; para Play hace falta un keystore, que Lorenzo debe
  generar y subir como secreto — el flujo ya contempla
  `ANDROID_KEYSTORE_BASE64` como secreto opcional).
- SMTP real (dominio propio en Resend, bloqueado en el usuario).
- `SUPABASE_JWT_SECRET` como secreto del backend.
- Los 6 secretos del barrido diario D9.
- La lista de campos de HACER (D17): hace falta un archivo de ejemplo, no una
  especificación.

---

## 5. Árbol de trabajo (todo esto es el diff a revisar)

Modificados (20): `.github/workflows/web_bundle.yml`,
`android/app/src/main/AndroidManifest.xml`, los 5 `mipmap-*/ic_launcher.png`,
`backend/src/infra/repos-supabase.ts`,
`docs/PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md`, `e2e/serve.mjs`,
`lib/main.dart`, `lib/models/inscripcion.dart`, `lib/models/usuario_admin.dart`,
`lib/screens/admin/cpanel_inscripciones_cola_dialog.dart`,
`lib/screens/admin/cpanel_inscripciones_inscritos_dialog.dart`,
`lib/screens/admin/cpanel_inscripciones_panel.dart`,
`lib/screens/admin/cpanel_usuarios_roles_panel.dart`,
`lib/widgets/campos_planilla/campo_planilla.dart`, `pubspec.yaml`,
`test/cpanel_inscripciones_inscritos_dialog_test.dart`.

Nuevos (12): `web/robots.txt`, `web/sitemap.xml`,
`.github/workflows/android_bundle.yml`,
`android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`,
`android/app/src/main/res/drawable/ic_launcher_foreground.png`,
`android/app/src/main/res/values/colors.xml`,
`backend/src/dominio/reglas-perfiles.ts`,
`backend/test/reglas-perfiles.test.ts`, `e2e/tests/seo_publico.spec.ts`,
`test/inscripcion_modelo_test.dart`, `test/usuario_admin_modelo_test.dart`,
este archivo.

---

## 6. Siguiente paso exacto

1. `git diff` — los cambios están acotados y cada uno tiene su porqué arriba.
2. Commit + push a `main`.
3. Corren solos: `web_bundle.yml` (robots/sitemap/localizaciones),
   `flutter_ci.yml` (analizador + suite), `e2e.yml` (regresión 24/24 contra el
   bundle) y el nuevo `android_bundle.yml` (APK + AAB).
4. Si `flutter_ci.yml` y `e2e.yml` salen verdes → publicar el artefacto
   `web-produccion` con `wrangler pages deploy` (§5.2 del procedimiento).
5. El APK queda como artefacto descargable para instalarlo en los teléfonos del
   Centro de Formación.

---

## APÉNDICE — Auditoría adversarial del mismo día (leer antes de publicar)

La segunda fase auditó este documento contra el disco y **falsó tres cosas** que
aquí se afirman. El detalle está en
[`AUDITORIA_ADVERSARIAL_2026-10-13.md`](./AUDITORIA_ADVERSARIAL_2026-10-13.md);
lo que cambia para los pasos de arriba:

1. **El paso 3 no habría funcionado.** `flutter_localizations` no resolvía
   contra el `intl: ^0.19.0` fijado: `flutter pub get` —el primer paso de los
   cuatro workflows— moría con *version solving failed*. Corregido:
   `intl: ^0.20.3` y `pubspec.lock` resuelto de verdad (ver §2.1 de la
   auditoría).
2. **La verificación del analizador de la noche no era válida.** Pasó con la
   entrada de paquete inyectada a mano en `.dart_tool/package_config.json`, que
   enmascaraba el fallo de resolución. El estado honesto: `dart pub get` e
   `intl` ya resueltos aquí, analizador real **BLOCKED** (`231`), sustituto en
   verde.
3. **Un mensaje al usuario seguía mostrando el UUID** («Promovido
   3f2a…: ya tiene su asiento.»), la misma clase de defecto que §2.1 de este
   documento dio por corregida. Corregido.

El paso 4 sigue en pie **tal como está escrito**: sólo publicar con
`flutter_ci.yml` y `e2e.yml` en verde, que ahora es más importante que cuando se
escribió.

---

*Documento escrito al cierre de la sesión. Si algo de aquí se contradice con el
código, gana el código — pero que se contradiga significa que hay un bug en este
documento, y se arregla el mismo día.*
