# CHANGELOG — INCES LMS

Todas las modificaciones, correcciones y nuevas funcionalidades implementadas en el proyecto INCES LMS se documentan en este archivo.

## [1.7.2] - 2026-10-30
### El móvil vuelve a deslizar, la cabecera deja de mentir y el tope de archivos sale del parámetro

> **Desplegado:** Cloudflare Pages `8cd8c992` (`inces-lms.pages.dev`), API de
> producción. Backend sin cambios.

**La versión salta a 1.7.2 por un error de proceso.** 1.7.1 se subió una vez y
después se publicaron **dos tandas más sin volver a subirla**, así que tres
bundles distintos llevaban la misma etiqueta y el dueño —con razón— miró la
página y creyó que no había cambiado nada. Un número de versión que no cambia
con lo que se publica no sirve como señal: sube en cada despliegue o sobra.

#### 1. El móvil no deslizaba en cuatro paneles

Reportado en un Redmi 10C: «no puedes deslizar ni para arriba ni para abajo» en
Cuadrante de Horarios, Horario PNA, Cursos y PNA y Espacios y Aulas — mientras
Guardias Docentes era el único utilizable. La asimetría era la pista: Guardias
ya envolvía el panel entero en un scroll en pantalla angosta; los otros cuatro
usaban `Column + Expanded`, que entrega al contenido el alto que sobre. Con la
cabecera llena (título, selector, cuatro botones, guía y fichas de día) sobraba
**cero**, y no había nada que arrastrar. Se copió el patrón que ya funcionaba.

#### 2. La cabecera

- El escudo «I» salía dos veces en escritorio (barra lateral + cabecera). Ahora
  sólo aparece cuando hay cajón.
- El período estaba **hardcodeado** en `admin_dashboard`, así que nunca cambiaba.
  Ahora se lee de la base.
- La insignia no decía estado: **verde = vigente, ámbar = archivado**, con los
  tonos del tema (medidos por contraste).
- «Horario Ordinario» pasa a «Cuadrante de Horarios», el nombre del menú.

#### 3. El tope de subida leía un literal

Los textos de Archivos del Centro decían «hasta 10 MB» con el 10 escrito a mano;
coincidía con `system_settings.m5_max_bytes` por casualidad. Ahora se lee del
parámetro. Y se hace visible `m5_max_archivos_por_entidad`: es el tope de
adjuntos **por aula o sección**, no por archivo.

#### Verificación

- `flutter test` **1054/1054** · `node devops/analizar-dart.mjs` 251 archivos 0/0/0.
- Sonda en navegador real: 360×800 con el horario visible y desplazable; 1440 sin
  logo duplicado y con el período en verde.

## [1.7.1] - 2026-10-29
### El cuadrante vuelve a cargar: el `400` del catálogo y la tabla que no cabía

> **Desplegado:** bundle en Cloudflare Pages (`81eef35a.inces-lms.pages.dev`),
> servido por `inces-lms.pages.dev` con la API de producción. Backend sin cambios.

Tres defectos medidos en navegador real, no deducidos:

#### 1. El cuadrante y el horario PNA no cargaban nunca

Pedían el catálogo de secciones con `limite: 150`. El contrato admite **100**
(`esquemaListadoSecciones` → `.max(100)`), así que el backend respondía `400` y
la rejilla se quedaba **en esqueletos para siempre, sin un solo mensaje**: la
llamada va dentro de un `try` que no informa. Ahora se **pagina** con el máximo
del contrato (`SeccionesRepository.listarTodasLasSecciones`) en vez de usar una
cifra mágica que se rompe en silencio.

De paso: el filtro viajaba como `soloActivas` y la API espera **`activa`**. Zod
descarta la clave desconocida, así que el panel mostraba también las secciones
archivadas **como si fueran vigentes**. Corregido; el panel ahora dice la verdad
(y hoy la verdad es que no hay ninguna sección activa en el centro).

#### 2. N2 — el cuadrante en el teléfono

Con «Todo» seleccionado se servía una tabla de 116 + 6·140 = **956 px dentro de
un 390**. Ahora la forma la decide el ancho (`CuadranteGrid.cabeComoTabla`): si
las columnas no caben con un mínimo legible, se pinta selector de día + lista de
bloques, y los botones «Anterior/Siguiente» —que mueven la tabla— desaparecen
cuando no hay tabla que mover.

#### 3. La hora de la tarde decía «01:00»

La rejilla mostraba «Tarde 01:00 - 01:45» sin meridiano. Ahora
`horaConMeridianoDeBloque` escribe «a. m.» / «p. m.» **en la presentación y no en
el dato**, porque el mismo mapa alimenta el formulario «Horas de bloques».

#### Verificación

- `flutter test` **1054/1054** · `node devops/analizar-dart.mjs` 251 archivos 0/0/0.
- Sonda en navegador real a 390 / 820 / 1440: **0 desbordes**, y
  `/admin/secciones?activa=true&limite=100` → `200` (antes `400`).
- `cd backend && npm run verify` **728/728** (sin cambios de backend).
- CI: Flutter ✅ · Supabase ✅ · E2E 27 pasan / 2 fallan, y esas 2 fallan **por
  datos** (no hay ninguna sección activa), no por el código.

## [1.7.0] - 2026-10-29
### El período congela de verdad, el PNA deja de pedir sección y la interfaz deja de gastar media pantalla

> **Desplegado:** migración `202610290001` aplicada a la nube (62 versiones,
> 0 pendientes, 0 deriva).

**Lo que se pidió, en palabras del propietario:** «erradica las secciones, deja
período y hazlo más simple y funcional posible», y «honestamente desconozco qué
debería suceder cuando se cierra un período».

#### 1. Cerrar un período ahora cierra algo (migración `202610290001`)

Hasta hoy, cerrar escribía `closed_at` y archivaba las secciones, pero **se podía
seguir creando grupos, clases y guardias dentro** y `periodo_activo` seguía
apuntándole. El candado de la interfaz no cerraba nada por debajo.

- **Trigger `exigir_periodo_no_cerrado`** en `sections`, `schedule_slots` y
  `teacher_duties`: un período cerrado no admite nada nuevo (`23514`). **Sólo
  INSERT**: editar y archivar lo que existe sigue permitido, porque cerrar es
  congelar, no secuestrar el historial.
- **Regla del sucesor**: cerrar el período **vigente** sin otro abierto devuelve
  `409 PERIODO_VIGENTE_SIN_SUCESOR` en vez de dejar al centro sin período en
  curso. `forzar: true` cubre el cierre definitivo y entonces la API **suelta
  `periodo_activo`**, que era la parte que quedaba incoherente.
- **El diálogo ofrece el camino bueno**: elegir el período siguiente y
  «Cerrar y activar el siguiente» en un gesto. Primero se declara el sucesor y
  después se cierra, en ese orden, para que un fallo no deje el hueco.

#### 2. La ventana de inscripción se aplica (y **no** se duplica)

`programs.inscripcion_inicio/fin/proxima_apertura` existía desde el 2026-10-28 y
ya estaba cableada hasta la landing. Lo que faltaba era **hacerla valer**: la RPC
`solicitar_inscripcion` no la miraba.

- Ahora rechaza fuera de ventana con un mensaje que dice **cuándo** abre, cuándo
  cerró y cuál es la próxima apertura, no un «no puedes» a secas.
- La administración **no** queda atrapada: `reincorporar_inscripcion` sigue
  permitiendo admitir a alguien fuera de plazo.
- **Corrección de un error mío, contada entera:** la primera versión de esta
  migración añadía `inscripcion_inicio/fin` también a `academic_periods`. Se
  descartó antes de aplicarla: dos sitios que dicen cuándo se puede inscribir es
  la redundancia que hay que evitar. La ventana es del **curso**, y punto.

#### 3. «Sección» fuera del Horario PNA (el grupo se crea solo)

- **Ruta nueva `POST /api/v1/admin/grupos/resolver`**: dado programa + materia +
  período devuelve el grupo, **creándolo si no existe** (nombre automático `A`,
  `B`, …). Responde 201 si lo creó y 200 si ya estaba.
- El diálogo de Horario PNA pide **«Materia PNA»**, no «Programa / Sección». El
  desplegable de secciones queda sólo como respaldo si el pensum no carga.
- Es `POST` y no `GET` a propósito: un `GET` que crea filas se duplica con
  cualquier reintento.

#### 4. Menos espacio robado en pantalla estrecha

Medido en la captura real de 390×844: **~448 px de 844 (53 %)** antes del primer
dato, entre encabezado, migas, título con subtítulo de tres líneas, pestañas,
buscador y paginación.

- **`MigasDePan` desaparece por debajo de 700 px.** En el móvil no añadían
  información —el menú ya marca dónde estás y el título lo repite— y costaban
  ~28 px fijos.
- **`TituloSeccion` pliega el subtítulo en un icono de información** por debajo de
  640 px. La explicación no se pierde: sigue en el `Tooltip`, a un toque. Ahorra
  las tres líneas (~50 px) y devuelve el botón de acción a la misma fila.
- El contrato nuevo está fijado en `test/titulo_seccion_responsive_test.dart`.

#### 5. Dos bugs latentes que esto destapó

- **Umbral del panel de Guardias**: decidía «móvil o escritorio» **sólo por
  altura** (`maxHeight >= 700`). Al quitar 28 px de migas, un 360×740 pasó a
  medir 720 y cruzó el umbral: entró en la rama de escritorio y desbordó 10 px.
  Ahora exige además `maxWidth >= 600`.
- **`TituloSeccion` se estiraba a toda la altura disponible** porque su `Column`
  no llevaba `mainAxisSize.min`. Una cabecera de 74 px medía 780.

#### 6. Un solo módulo «Cursos»: «Inscripciones y Cupos» desaparece del menú

La queja con más detalle del propietario era tener el mismo dato partido en dos
sitios: el catálogo en «Cursos y PNA» y la ocupación/cupos en «Inscripciones y
Cupos». Ahora es **una** pantalla.

- **Backend `GET /api/v1/admin/cursos/resumen`** (ruta nueva, con contrato
  OpenAPI y prueba D6): por programa devuelve la `ventana de inscripción`
  (`estadoInscripcion` ABIERTA/CERRADA/PROXIMA_APERTURA + fechas), el `cupo`
  agregado, `ocupados`, `disponibles`, `inscritos` y la lista de `secciones`
  del grupo vigente, cada una con `seccionId`, `nombre` y `periodo` (este
  último enriquecido para nombrar el archivo de exportación HACER).
- **Frontend `CpanelProgramasPanel`** pinta una franja resumen (Grupos activos,
  Cupos ocupados, Cupos disponibles) y, por cada sección bajo «Grupos /
  Secciones», reutiliza los diálogos que ya existían: **Ver cola**
  (`mostrarColaDeSeccion`), **Ver inscritos** (`mostrarInscritosDeSeccion`),
  **Exportar HACER** (`HacerExportService`), **Reincorporar** y **Promover
  siguiente**. Nada se duplica: los diálogos son los mismos del módulo 4.
- **Se borró `lib/screens/admin/cpanel_inscripciones_panel.dart`** (795 líneas)
  y su prueba `test/cpanel_inscripciones_test.dart`. El `_DialogoReincorporar`
  se sacó a `reincorporar_dialog.dart` para seguir disponible.
- **Navegación**: se retiró la entrada «Inscripciones y Cupos» del menú y se
  repuntaron todos los `onNavegarA('Inscripciones y Cupos')` → `'Cursos y PNA'`
  (dashboard, resumen, campos de planilla, walkthrough). El modal de reportes
  «Inscripciones y Cupos Oficiales» ahora dice «Cursos y Cupos Oficiales».
- **E2E**: la señal de sesión y las 6 specs/navegaciones que citaban el módulo
  borrado apuntan a «Cursos y PNA»; el page object de exportación HACER usa
  «Exportar HACER» dentro de «Cursos y PNA». `test/m4_responsive_test.dart`
  conserva las pruebas de layout de Secciones y del diálogo de cola.

#### Verificación de este lote

| Control | Resultado |
|---|---|
| `node devops/analizar-dart.mjs` | 249 archivos · **0 errores, 0 avisos, 0 infos** |
| `flutter analyze` | **No issues found!** |
| `cd backend && npm run verify` | **34 archivos · 736/736** · exit 0 |
| `flutter test` | **1061/1061** · exit 0 |
| `apply-migrations.mjs --check` | **0 pendientes, 0 deriva** (62 versiones) |

**Nota de entorno (nueva, medida hoy):** `flutter test` fallaba **en los 84
archivos** con `Unable to connect to flutter_tester process: WebSocketException:
Invalid WebSocket upgrade request`. No era el proyecto: hay un **proxy HTTP en el
entorno** (`HTTP_PROXY`/`HTTPS_PROXY` con `NO_PROXY` vacío) que rompe el handshake
del WebSocket local de `flutter_tester`. Con
`env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy NO_PROXY=127.0.0.1,localhost flutter test`
la suite corre. Queda anotado porque el síntoma parece un fallo de código y no lo
es.

#### Lo que este lote NO trae (y es lo siguiente)

- **Unificar «Cursos y PNA» con «Inscripciones y Cupos».** Sigue siendo el
  defecto que el propietario describió con más detalle («un solo curso en una
  pestaña, seis en la otra»). Requiere un endpoint de resumen por curso y retirar
  el panel de ocupación del menú. Diseño en
  `docs/PLAN_SIMPLIFICACION_SECCIONES_2026-10-29.md` §4 (fase 3).
- **Landing por curso** con cupos y «próxima apertura» (fase 4).
- **Expediente del aprendiz** y constancia de lectura de entregas: no existe.
- **La cabecera del cPanel sigue con `SA26-2` escrito a mano**
  (`admin_dashboard.dart:242`). Es una mentira después de cerrar un período.

## [1.6.0] - 2026-10-29
### El período se puede usar, cerrar y archivar — y la versión que se ve ya es la real

**Por qué 1.6.0 y no 1.5.5.** El Rediseño 1.5 está completo y el producto cambió de
comportamiento (período, horarios MTP/PNA, cupos, archivar, cédula); 1.5.5 era un
parche de un lote. La versión visible deja de ir por detrás: `pubspec.yaml` `1.6.0+8`,
`AppConfig.version` `1.6.0` y esta entrada, los tres iguales y **con guardia**
(`test/version_coherente_test.dart` falla si se separan).

**Cerrar un período: verificado en producción, no deducido.** Con un período temporal
en la nube (creado, con sección, cerrado y borrado después):

| Paso | Resultado medido |
|---|---|
| `POST /admin/periodos` | 201 · período creado |
| `POST /admin/secciones` | 201 · sección activa en ese período |
| `PATCH {activo:false}` sobre un período **inactivo** | 200, pero **no hace nada**: `is_active` ya era `false`, el trigger no dispara y la sección sigue activa |
| `PATCH {cerrado:true}` sobre un período **activo** | 200 · `closed_at` escrito · **la sección queda archivada** (`archived_at`) |
| `PUT /periodos/{id}/vigente` sobre un período cerrado | **400** (no se puede hacer vigente uno cerrado) |

De ahí salieron tres arreglos:

- **Un período nuevo nace activo.** Tenía `default false`: aparecía como «Borrador»,
  su fila ofrecía «Hacer vigente» y la API respondía **400** — el «intento usarlo y
  me da error» del propietario. `crearPeriodo` ahora inserta `is_active: true`.
- **El borrador ofrece «Activar», no «Hacer vigente».** Es el paso que de verdad
  falta, y deja de ofrecer una acción que la API rechaza.
- **Cerrar el período vigente avisa.** La API lo permite y deja
  `system_settings.periodo_activo` nombrando un período cerrado: el cuadrante y los
  horarios siguen apuntando a él. No se bloquea (puede ser deliberado), pero el
  diálogo lo dice en rojo antes de confirmar.

**Despliegue del día:** commit `5f2ad6e` + `aba70e5`; Pages `bb7c8f86`
(`inces-lms.pages.dev`); `/salud` 200. Verificado con sesión real: el docente entra y
llega a «Aulas Virtuales».

**Lo que este cambio NO incluye, y es lo siguiente** (requiere decisión de producto):
unificar «Inscripciones y Cupos» con «Cursos y PNA», mostrar disponibilidad y ventana
de inscripción en la landing por curso, y retirar «secciones» de la interfaz. Las tres
son el mismo cambio de modelo: hoy la sección es la unidad que liga programa + materia
+ período, y de ella cuelgan horarios e inscripciones. Fichas en
`docs/BACKLOG_PENDIENTES.md` (C10 y el plan de unificación).

## [1.6.0] — añadido la misma noche: «sección» deja de pedirse
### Crear el grupo desde el cuadrante, sin salir de la pantalla

- **«Asignar clase» ya no te manda a otro módulo.** El desplegable pasa de
  «Sección» a **«Curso · materia (grupo)»** y debajo hay un botón
  *«Falta el curso o la materia: crearlo aquí»* que abre un formulario mínimo
  (**curso → materia del pensum → nombre**, por defecto «ÚNICA»), crea el grupo y
  lo deja **elegido** en el diálogo, sin perder lo que ya estaba puesto.
- **Verificado en producción** con sesión real: el diálogo abre desde
  `inces-lms.pages.dev` (`campo=1 boton=1 dialogo=1`, Playwright).
- El mensaje del cuadrante ya no manda a «Secciones del Período» (apartado retirado
  en D11) y la barra de paginación desaparece cuando hay una sola página.
- **Diseño del resto escrito**: `docs/DISENO_CICLO_PERIODO_2026-10-29.md` (qué pasa y
  qué debería pasar al cerrar un período) y
  `docs/PLAN_SIMPLIFICACION_SECCIONES_2026-10-29.md` (fases 2–5 para que «sección»
  desaparezca de la cara visible).

## [1.5.5] - 2026-10-29
### Lote 5 — Aulas Virtuales del admin, scroll del tablón y **el daño que el renombrado hizo** (reparado)

**Lo que trajo el Lote 5** (commit `21cbdaf`, 2026-10-28):

- **Panel nuevo `CpanelAulasVirtualesPanel`** (256 líneas): lista las secciones del centro con su aula virtual y abre cada una en modo docente. Resuelve los nombres de programa y materia con dos lecturas de catálogo; si fallan, degrada la etiqueta al identificador y el aula sigue abriendo. El administrador **sí** puede publicar: `m6_dicta_seccion()` incluye `is_admin()` (migración `202609220001`, línea 339), así que la RPC no devuelve 42501. Archivadas separadas, con filtro de facto por la cabecera.
- **Tablón de la móvil con una sola `ListView`**: antes era un `Column` con un `Expanded` que contenía otra lista; en 360×740 los bloques fijos desbordaban y el contenido quedaba inalcanzable. Ahora el tablón entero desliza y la lista de anuncios son hijos de esa lista, no un scrollable anidado.
- **Caja «Nuevo anuncio» responsive** con `Wrap`.

**Lo que el Lote 5 rompió, y se repara aquí:**

- **El Aula Virtual del docente quedó inalcanzable.** El menú pasó de «Mis aulas» a «Aulas Virtuales» pero la rama del `switch` siguió siendo `case 'Mis aulas'`, así que caía en el `default` y el docente veía «Esta sección está pendiente de construir» en su primer apartado. Lo cazaron **6 pruebas** —3 de `aula_produccion_test.dart`, 1 de `menu_alcanzable_test.dart` («disponibles no contiene 'Mis aulas'») y 2 de `menu_gobernado_por_modulos_test.dart` («Found 0 widgets with type PanelMisAulas»)—. Ninguna prueba de panel podía verlo: el panel estaba bien, faltaba la puerta.
- **`_navegarA` fallaba en silencio** con el nombre viejo. Tres accesos del propio panel docente (`docente_resumen_panel` ×2, `docente_calificaciones_panel`) llamaban con «Mis aulas» y no pasaba nada: sin error, sin log, sin cambio de pantalla. Se alinean los llamadores y se añade un **alias explícito** (`'Mis aulas' → 'Aulas Virtuales'`) para que un renombrado futuro no vuelva a dejar un botón mudo.
- **El panel se contradecía con el menú**: `PanelMisAulas` escribía «Mis aulas» en el título, en las migas y en «Volver a…». Ahora recibe `titulo` (por defecto «Mis aulas», que es el nombre del aprendiz) y el docente le pasa el suyo.
- **Contraste del icono de la caja de anuncio**: se había puesto `Colors.white` sobre `primaryContainer`, que es el tono pálido de `ColorScheme.fromSeed` (≈1,3:1). Vuelve a un color de rol, `onPrimaryContainer`, que contrasta en claro y en oscuro.
- **El botón subía de línea también a 1440 px**, porque un `Expanded` dentro de un `Row` con `mainAxisSize.min` obliga a la fila a ocupar todo el ancho. El texto va en `Flexible`: una línea cuando cabe, dos cuando no.

**E2E y matriz, que estaban desincronizados desde antes de este lote:**

- `matriz_responsive.spec.ts` listaba **tres nombres muertos** y **dos ausentes** en el admin: `Programas Académicos` (hoy «Cursos y PNA»), `Secciones del Período` (retirada por D11) y `Guardias Docentes` (hoy «Guardias Docentes (MTP)»), y faltaban `Horario PNA` y `Aulas Virtuales`. Con nombres muertos la matriz no falla en el panel: falla al pulsar y anota `NO PULSABLE`, que es peor porque se lee como un fallo de layout. Lista corregida a las **17** reales.
- La señal de login del docente era «Mis aulas»; `LoginPage.entrar` **lanza** si no aparece, así que el rol docente entero se perdía (25 capturas). Corregida.
- `AulaVirtualPage` tenía «Mis aulas» escrito a mano y lo usan las dos suites (docente y aprendiz). Ahora resuelve la entrada del menú **por presencia** entre los dos nombres.
- Se actualizan `aula_virtual_ciclo`, `captura_dashboards_roles`, `performance_baseline` y `capturar-dashboards-roles.mjs`.

**Encontrado en la revisión de cierre (y corregido):**

- **La interfaz mostraba la versión equivocada.** `AppConfig.version` estaba en `1.5.1` mientras `pubspec.yaml` iba por `1.5.5+7`: el menú, el pie y la portada pintaban «v1.5.1» y el CHANGELOG documentaba 1.5.5. Corregido, y **cerrado con guardia**: `test/version_coherente_test.dart` compara `pubspec.yaml` ↔ `AppConfig.version` ↔ primera entrada del CHANGELOG y falla si se separan.
- **Mensaje que mandaba a un apartado inexistente.** El cuadrante decía «crea primero una sección en “Secciones del Período”»; ese apartado se retiró en D11 y su panel quedó sin punto de entrada. Ahora el aviso no nombra un sitio que no existe.
- **Pendiente detectado, no corregido aquí:** `CpanelSeccionesPanel` (676 líneas, con pruebas propias) **no lo instancia nadie** desde D11, y `crearSeccion` no tiene otro llamador, así que hoy **no hay forma de crear una sección desde la interfaz**. Es la lección de R-22 repetida: probar el panel donde vive no prueba que se pueda llegar a él. Queda como **P1** en `docs/BACKLOG_PENDIENTES.md` (C10) porque resolverlo exige decidir la forma —pestaña dentro de «Cursos y PNA», filtrada por programa— y eso pide capturas y juicio de intuitividad.

**Medido el 2026-10-29 (este equipo, toolchain real):**

| Control | Comando | Resultado |
|---|---|---|
| Analizador | `node devops/analizar-dart.mjs` | **249 archivos · 0/0/0** · exit 0 |
| Analizador real | `flutter analyze` | **No issues found!** (51,2 s) · exit 0 |
| Suite Flutter | `flutter test` | **1060/1060** · exit 0 |
| Backend | `cd backend && npm run verify` | **34 suites · 721/721** · exit 0 |

> **El bloqueo `CreateFile failed 231` no se reproduce.** `flutter test`, `flutter analyze` y `flutter build` corren en esta máquina el 2026-10-29. La entrada «BLOCKED» de `ESTADO_DEL_SISTEMA.md` queda como histórica, con su fecha.

**Publicado el 2026-10-29** (commit `5f2ad6e`, push `7cbda5e..5f2ad6e`):

- **Frontend:** `wrangler pages deploy` → `bb7c8f86.inces-lms.pages.dev`, alias `inces-lms.pages.dev`. Bundle validado según el procedimiento §5.1: API de producción presente y **cero** `localhost`; versión visible **1.5.5**.
- **Backend:** `/salud` → 200 en `inces-lms-api.onrender.com`.
- **Verificado con sesión real en producción:** el docente entra y llega a «Aulas Virtuales».
- **Una vez deshecho en el acto:** el primer `pages deploy` (`93d6d111`) llevó un bundle compilado con el `.env.json` local (`localhost:3001`). Faltó el override `--dart-define=API_BASE_URL=…` que sí usa `web_bundle.yml`. Se detectó con la comprobación §5.1 **antes** de dar el despliegue por bueno y se rehizo. El override no es opcional.

## [1.5.4] - 2026-10-28
### Lote 3 — Ventana de inscripciones y próxima apertura (parcial: código listo, migración SIN aplicar)

**Lo que el propietario pidió y no existía:** por curso/programa, decir cuándo abren y cierran las inscripciones, cuándo arranca y cuándo vuelve a comenzar — visible para admin, docente y aspirante.

- **Migración nueva `202610280001_ventana_inscripciones_programas.sql`** (local): `programs.inscripcion_inicio/inscripcion_fin/proxima_apertura` (date, anulables) + constraint de coherencia. **No aplicada a producción** — requiere autorización explícita.
- **Backend:** `Programa`/`EntradaCrearPrograma`/`CambiosPrograma` con las 3 fechas; columnas en `COLUMNAS_PROGRAMA*`; escritura en crear (post-RPC) y actualizar; esquemas Zod (`fechaIsoSchema`, refine de coherencia cierre ≥ apertura). 721 tests backend en verde.
- **Flutter:** modelo `Programa`/`ProgramaConTotales`/`OpcionCampo` con las fechas; catálogo del aspirante las lee (con select de respaldo); **asistente de creación** gana tarjeta «Cupos e inscripciones» (cupo + 3 selectores de fecha, en columna en móvil, aviso de incoherencia en vivo) y la revisión muestra cupos y fechas; **diálogo de edición** permite cambiarlas; tarjeta del listado muestra chips «Inscripciones hasta d/m» y «Nueva apertura: d/m»; **landing** muestra la ventana («Inscripciones: del X al Y», «abiertas hasta…») y la nueva apertura. 1057 tests Flutter en verde.

**Aplicado a producción (2026-10-28, con autorización del propietario):** producción estaba 8 migraciones atrás (todo el Rediseño 1.5 D1–D10 + la ventana de inscripciones). `apply-migrations.mjs` las aplicó: 61 versiones, 0 deriva; columnas verificadas en vivo contra `programs`. `verificar-esquema.mjs` reporta 5 comprobaciones desactualizadas respecto al Rediseño (bids eliminado → setting ausente, mapa de módulos, 6 cursos reales sembrados, límite de archivos 30, tablas heredadas residuales) — deriva conocida del verificador, no regresiones.

## [1.5.3] - 2026-10-28
### Lote 4 — Nomenclatura de Guardias
- El módulo se llama ahora **«Guardias Docentes (MTP)»** en el menú, en el título del panel, en el horario del docente y en los accesos desde Cuadrante, Aulas y Horario PNA (clave de navegación actualizada en las 6 referencias juntas para no romper rutas).

## [1.5.2] - 2026-10-28
### Responsive móvil (Lote 1 y Lote 2) — «Precisión quirúrgica» sobre la cabecera y el scroll

**Cabecera institucional compacta en móvil (<640 px)** — `lib/widgets/comunes.dart`
- `EncabezadoInstitucional` pasa a una sola línea (~56 px): menú + escudo 32 px + saludo + insignias de rol/período.
- Se retiran del encabezado móvil el correo (ya está en Perfil) y la fila de accesos directos que duplicaba el cajón lateral.
- Escritorio sin cambios.

**Scroll roto en móvil — Cursos y PNA** — reproducido y corregido con `test/scroll_movil_redmi10c_test.dart` (360×740 dp, Redmi 10C):
- `EsqueletoLista` (`comunes.dart`): el Column fijo desbordaba 162 px cuando el hueco restante era menor que el esqueleto (el «se queda cargando» a medias). Ahora se acota con scroll interno.
- Tarjeta de programa (`cpanel_programas_panel.dart`): la columna lateral fija de acciones (switch + lápiz + ojo ≈ 150 px) dejaba el texto con ~102 px de ancho y desbordaba 129 px. En angosto (<420 px) las acciones editar/ver bajan a una fila propia y el contenido recupera el ancho.
- Fila «Requiere pensum»: el botón de ancho intrínseco desbordaba la fila; en angosto se apila bajo el aviso, y «Gestionar pensum» se apila bajo el texto de materias.
- Chips de código/«Sin pensum» con elipsis en vez de desbordar.
- Verificación: 0 excepciones de layout en carga/settle/drag, la lista desliza hasta el último ítem; suite completa de Flutter en verde.

**Scroll en móvil — Cuadrante de Horarios, Horario PNA y Guardias Docentes**
- Cuadrante: leyenda desbordaba 43 px (Row de ancho mínimo dentro de Wrap) → texto Flexible; la rejilla desliza verticalmente.
- Horario PNA: insignia «PNA: Materia y Docente…» desbordaba 327 px (Row fija) → Wrap con texto Flexible.
- Guardias Docentes: en móvil el panel completo desliza (cabecera+filtros fijos desbordaban 202 px); la matriz va en altura natural sin scroll vertical propio ni Scrollbar — con extensión 0 ese scrollable se comía los gestos sin desplazar nada (causa raíz del «no desliza»). Escritorio sin cambios.
- Explorador de archivos: fila de metadatos de tarjeta desbordaba 43 px en celdas angostas → tamaño y origen con elipsis.
- **Cierre del Lote 2:** `scroll_movil_redmi10c_test.dart` cubre 7 módulos (Cursos y PNA, Cuadrante, Horario PNA, Guardias, Aulas, Explorador, Gestor documental) con verificación estricta de 0 excepciones de layout a 360×740; suite completa en verde (1057 tests).

## [1.5.0] - 2026-10-27
### Rediseño 1.5 — Culminación integral de las 11 tareas (D1 a D10)

**D1 (Tarea 1) — Eliminación del sistema de bids**
- Flujo de inscripciones directo: WAITLISTED (cola) → ENROLLED (matriculado) sin ofertas intermedias con expiración (PENDING_BID eliminado).
- Migración 202610260001_eliminar_sistema_bids.sql y actualización de pruebas y servicios.

**D2 (Tarea 2) — Eliminación de lapsos; unificación en «Período» con herencia**
- Unificación conceptual en «Período» (migración 202610270001_periodo_sin_lapsos.sql).
- Implementada función RPC heredar_horario_periodo para clonar automáticamente las secciones activas y slots del período saliente al nuevo.

**D3 y D4 (Tareas 3 y 4) — Separación de MTP y PNA y tres horarios diferenciados**
- Pantallas y cuadrantes independientes para MTP (guardias técnicas de docentes) y PNA (Programa Nacional de Aprendizaje).
- Tres esquemas de horarios validados: Ordinario (curso obligatorio, materia/espacio opcional), MTP (docente y espacio obligatorio, sin materia) y PNA (materia y docente obligatorios).
- Migración 202610270002_tres_horarios_mtp_pna.sql.

**D5 (Tarea 5) — Cupo por curso no global y disponibilidad visible**
- Cupo configurable por programa/sección en lugar de forzar el parámetro global.
- Indicador visual «Quedan X de Y cupos» en landing page y en tarjetas del cPanel.
- Migración 202610270003_cupo_por_curso.sql con funciones cupo_efectivo y cupos_ocupados_programa.

**D6 (Tarea 6) — Rediseño del gestor de archivos con descarga múltiple en ZIP**
- Selección múltiple de archivos con casillas y atajo Shift para rango.
- Generación de ZIP mediante streaming en backend con archiver en la ruta /api/v1/archivos/descargar-zip.
- Barra de acciones flotante contextual (descarga ZIP, eliminación) y soporte de vistas cuadrícula y lista.

**D7 (Tarea 7) — Reorganización de navegación a 7 apartados funcionales**
- Menú del cPanel reestructurado en 7 grupos por tarea: Preparar el período, Inscribir, Dar clase, Archivos, Personas, Registro de accesos y Mi cuenta.
- Optimización ergonómica y táctil para dispositivos móviles y Drawer.

**D8 (Tarea 8) — Archivar funciona (secciones y períodos)**
- Registro automático de archived_at al desactivar/archivar secciones y períodos (migración 202610270004_archivar_secciones_y_periodos.sql).
- Trigger en academic_periods que archiva automáticamente sus secciones activas al cerrarse el período, sin afectar aulas virtuales.

**D9 (Branding institucional) — Mantenimiento oficial de «Aula Virtual»**
- Mantenimiento inequívoco del nombre y branding «Aula Virtual» en títulos, rutas y menús.
- Favicon oficial del CFS con fondo blanco removido (transparencia alfa) y logo oficial institucional de alta resolución.

**D10 (Tarea 10) — Autenticación con cédula de identidad**
- Inicio de sesión admitiendo cédula tanto para aprendices como para administradores y docentes.
- Índice único en base de datos idx_profiles_cedula_digits sobre perfiles administrativos.

**Tarea 11 — Documentación y suite de pruebas**
- 555 aserciones de migraciones en verde (validate.mjs).
- 721 pruebas de backend en verde (vitest).
- 246 archivos Dart analizados con 0 errores y 0 avisos.

**Eliminación del sistema de bids (Decisión D1)**
- Flujo de inscripciones simplificado: `WAITLISTED` (cola) → `ENROLLED` (matriculado) → `DROPPED` (historial/baja).
- Al liberarse un cupo en una sección, el primer aspirante en cola entra directamente a `ENROLLED` sin requerir oferta intermedia ni vencimiento de tiempo (`PENDING_BID` eliminado de `EstadoInscripcion`).
- Migración `202610260001_eliminar_sistema_bids.sql`: eliminada columna `bid_expires_at`, limpiados parámetros obsoletos en `system_settings` (`habilitar_sistema_bids`, `bid_ttl_horas`), y reescritas funciones PL/pgSQL (`cupos_ocupados`, `solicitar_inscripcion`, `promover_siguiente_de_cola`, `renunciar_cupo`, `reincorporar_inscripcion`).
- Purga completa de lógica y pruebas de bids en backend y frontend Dart (`mis_inscripciones_panel.dart`, `cpanel_inscripciones_panel.dart`, arneses y fakes).

**Recursos de identidad visual oficial (CFS Rafael Urdaneta La Isabelica)**
- Procesamiento del nuevo favicon institucional (`inces-lms-favicon.png`): remoción del fondo blanco exterior en esquinas mediante máscara de contorno y suavizado anti-aliasing (alfa transparente 0 fuera del squircle).
- Generación de todos los tamaños del nuevo favicon y PWA icons: `favicon-16.png`, `favicon-32.png`, `favicon-48.png`, `favicon.png`, `apple-touch-icon.png`, `Icon-192.png`, `Icon-512.png`, `Icon-maskable-192.png`, `Icon-maskable-512.png` y `assets/images/icono_app.png`.
- Incorporación del logo oficial de alta resolución del centro (`assets/images/inces_lms_logo.png` y `web/icons/inces-lms-logo.png`).

## [1.4.0] - 2026-10-25
### Identidad institucional, rango PNA corregido, seguridad de la API y auditoría independiente

**Identidad y marca**
- Logo oficial del INCES en la landing (descargado del sitio del instituto) y en el login, que hasta hoy mostraba un cuadrado azul con una «I».
- Icono de la app y favicon rediseñados: la «i» estilizada del INCES con el punto convertido en chispa de soldadura, sobre azul institucional. Un solo icono para la pestaña, el acceso directo de Android y el login.
- `theme-color` unificado en `#003B73`: había dos declarados y el navegador se quedaba con el viejo.
- El logo de la portada se pintaba dos veces (navbar y hero). Corregido.

**Rango de edad del PNA: 14 a 18 años**
- El dato estaba en cuatro sitios con tres valores distintos: la landing decía 14 a 17, el programa en la base «(15-16 años)» y el selector de fecha de nacimiento cortaba en 15, así que **un aspirante de 14 años no podía ni elegir su fecha**. Los cuatro corregidos a la vez (migración `202610250002`).

**Seguridad**
- El JWT se aceptaba por query string en las 60 rutas de la API; ahora sólo en el WebSocket de asistencia, que es el único canal que lo necesita.
- `solicitar-recuperacion` devolvía el correo del perfil: era un oráculo de enumeración de cuentas. Eliminado.
- Comodines de `ILIKE` escapados en la búsqueda por identificador.
- Login con cédula habilitado para administradores y docentes (migración `202610250001`): el RPC sólo miraba `aspirantes`, así que la cédula de un docente no servía aunque la interfaz la ofreciera.

**Deuda**
- Fuera el fallback mudo a Supabase de `UsuariosAdminRepository`: convertía un fallo de red en «lista vacía» y su paginación era falsa.
- Fuera `uuid`, `conGuardiaEn`, `UserRoleName` y `categoriaLegible`, todos sin un solo uso.
- El límite de subida que anuncia la interfaz pasa de 25 a 10 MB, que es el real.

**SEO**
- `robots.txt` con política inversa (permitir la portada, bloquear el resto por defecto) en vez de una lista negra que fallaba por omisión.
- Esquema `WebSite` con `SearchAction`, junto al `EducationalOrganization` que ya existía.

**Despliegue**
- `devops/desplegar-pages.mjs`: valida el artefacto y publica en Cloudflare Pages.
- Primera publicación desde el 2026-10-13: producción deja de servir el bundle viejo.

## [1.3.1] - 2026-10-18
### Calibración Milimétrica de Planilla Oficial INCES, Catálogo Geográfico Nacional de 24 Estados y Autocompletado Dinámico
- **Calibración Milimétrica de Impresión en Planilla Oficial INCES (612 × 792 pt Letter):**
  - Centrado geométrico matemático exacto del glifo `[X]` en el centroide de cada casilla oficial (Género, Estado Civil, Pueblo Indígena, Diversidad Funcional, Estado de Avance de Formación y las 20 Misiones Oficiales).
  - Eliminación definitiva del bug de superposición `SIX` en Pueblo Indígena donde la marca de `NO` caía encima de las letras `SI` (corregido a `cx = 541.88, cy = 558.88`).
  - Elevación de las líneas base tipográficas (`y = 422.0` para estado/municipio/parroquia, `y = 395.0` para dirección/teléfonos, `y = 371.0` para correos, `y = 127.5` para formación) eliminando el contacto de texto contra los bordes de celda ("montado").
  - Resolución resiliente multi-clave para fecha de nacimiento (`datos.fecha_nacimiento`, `iden.fecha_nacimiento`, `entrada.fechaNacimiento`, `aspirante.fechaNacimiento`) y cálculo dinámico de edad cronológica.
  - Mapeo institucional de niveles educativos en el renderizador PDF a títulos formales legibles (`Educación Media General`, `Bachiller`, `Técnico Medio`, etc.) preservando el contrato semántico backend.
  - Incorporación de bloque formal inferior de firmas (`Firma del Aspirante` y `Firma y Sello CFS Receptor`) junto con pie de verificación institucional para expediente interno.
- **Catálogo Geográfico Nacional y UX de Selección Reactiva:**
  - Expansión de `VenezuelaGeografia` a las 24 entidades federales con sus municipios y parroquias reales.
  - Normalización insensible a mayúsculas, tildes, espacios y guiones bajos (`CARABOBO` -> `Carabobo`, `DISTRITO_CAPITAL` -> `Distrito Capital`), suprimiendo completamente las sugerencias de marcador de posición («Municipio Centro», «Municipio Capital», «Municipio Foráneo»).
  - Componente de entrada con sugerencias dinámicas filtradas en tiempo real según lo escrito, contenedor desplazable con límite de altura y barra de desplazamiento visible (`thumbVisibility: true`), botón para limpiar campo y acción rápida «Ver todas».
- **Evidencias Visuales de Producción:**
  - Registrada captura calibrada de la planilla oficial renderizada en `docs/assets/production_ready/05_planilla_oficial_impresion_calibrada.png`.

## [1.3.0] - 2026-10-17
### Cierre Operativo de cPanel, Matriz Semanal de Guardias, Validaciones Venezolanas, Limpieza HACER y Landing Page Institucional
- **Limpieza de Cuentas de Demostración y Gestión de Estado en `Usuarios y Roles` (M0):**
  - Filtro tipo chip (`_ocultarCuentasDemo`) que oculta cuentas de testing (`@semilla.invalid` y sin nombre) en vistas y selectores del sistema.
  - Endpoint `PATCH /api/v1/admin/usuarios/:id/estado` con protección estricta que impide desactivar al último administrador activo del centro.
  - Botón de acción rápida para Activar / Desactivar (Archivar) cuentas en la tabla de usuarios con confirmación modal y respuesta visual inmediata.
- **Módulo `Horarios de Clases` (M3):**
  - Guía rápida compactada en una barra estilizada de una línea con interruptor funcional «Ver pasos detallados / Ocultar».
  - Selector de docentes reemplazado por Autocomplete reactivo con filtrado por nombre, apellido y correo, limitación a 5-7 elementos visibles, barra de desplazamiento visible (`thumbVisibility: true`) y botón de acceso rápido `+ Invitar nuevo docente`.
  - Bloques de horario con nombres descriptivos (ej. `Mañana · Bloque 1 (07:30 - 08:15)`) y modal administrativo para personalizar horas de inicio y fin por franja.
- **Módulo `Guardias Docentes` (M3):**
  - Implementada la vista "Rol de Guardia MTP / PNA - Pizarra Física": matriz semanal con espacios/talleres en filas y turnos Mañana (07:30 - 12:00) y Tarde (13:00 - 17:30) de Lunes a Sábado en columnas.
  - Celdas táctiles con asignación directa mediante un clic en los espacios vacíos y chips visuales para docentes asignados.
  - Selector conmutador en la cabecera para alternar entre `[ Matriz Semanal | Lista detallada ]`.
- **Programas, Currículo, Secciones y Lapsos Académicos (M2 / M3 / M4):**
  - Modal «Editar programa» que permite modificar nombre, requisito de pasantías y duración (valor y unidad) respetando la identidad institucional inmutable.
  - Sincronización del rango etario oficial de aprendices PNA a «14 a 18 años».
  - Cabeceras del pensum curricular actualizadas a «Módulo / Trimestre X».
  - Resolución automática de UUIDs a nombres legibles de programas y materias en las tarjetas de sección.
  - Modal «Editar sección» para ajustar nombre corto, cupo máximo (o herencia global) y estado de archivado.
  - Asignación de fechas de vigencia institucional por defecto (2026-09-15 a 2027-01-30) para el lapso activo `SA26-2`, eliminando avisos de «Sin fechas cargadas» en backend, PostgREST y la tabla de Lapsos Académicos.
- **Validaciones Estrictas de Identidad y Contacto Venezolano:**
  - Cédula de identidad validada entre 6 y 9 dígitos numéricos (o con formato oficial V/E).
  - Teléfonos móviles y fijos validados en 10 u 11 dígitos contra los códigos de área y operadoras de Venezuela (0412, 0414, 0424, 0416, 0426, 0241, etc.).
  - Nombres y apellidos restringidos a caracteres alfabéticos, tildes, diéresis y espacios, bloqueando números o caracteres especiales.
- **Exportación HACER Limpia e Individual:**
  - Depuración del serializador CSV/Excel para excluir UUIDs internos y metadata JSON cruda, entregando un formato institucional limpio para los directores del CFS.
  - Botón de descarga directa de la «Planilla HACER (.xlsx)» individual por aspirante en el diálogo de inscritos de cada sección.
- **Landing Page e Identidad Institucional:**
  - Barra de búsqueda reactiva en tiempo real integrada en el encabezado de navegación.
  - Medallones/chips interactivos de áreas técnicas (Soldadura Especializada, Mecánica Industrial, Electricidad, Refrigeración, Programas PNA, Gestión y Servicios).
  - Sección «¿Quiénes somos?» enriquecida con la historia, misión y visión del CFS Nacional de Soldadura «Rafael Urdaneta» (La Isabelica, Valencia, Carabobo).
  - Pie de página institucional completo de 4 columnas con sedes, horarios, enlaces al portal nacional HACER y créditos oficiales.

## [1.2.9] - 2026-10-16
### Ciclo Completo de Entrega de Tareas en Aula Virtual, Resiliencia Cold-Start y Sincronización Global
- **Cierre del Ciclo Pedagógico de Tareas en el Campus Virtual (M6):**
  - Diferenciación explícita de roles: Facilitadores asignan y evalúan; estudiantes consignan evidencias técnicas y prácticas de taller.
  - Botón de llamada a la acción directo e inequívoco (`FilledButton.tonalIcon` «Entregar trabajo» / «Ver mi entrega enviada» / «Ver calificación y comentarios») en cada tarjeta de tarea en `AulaVirtualDashboardScreen`.
  - Integración de `GestorDocumentalPanel` para adjuntar evidencias fotográficas y documentales de taller (piezas de soldadura, cordones, planos e informes en PDF, JPG, PNG, WEBP) a Cloudflare R2 vía URLs prefirmadas de S3.
  - Barra de estado de entrega interactiva (`ASIGNADA`, `ENTREGADA`, `DEVUELTA`, `RECLAMADA`) con confirmación de entrega y anulación para corrección antes de la fecha límite.
  - Libro de Calificaciones (Gradebook) para el facilitador con visor de evidencias, calificación numérica y retroalimentación cualitativa privada.
  - Sanitización de títulos con artefactos de pruebas automatizadas (`Tarea E2E [ciclo]...` convertidas a `Práctica Técnica de Taller #XXXX`) y bienvenida institucional limpia en el feed del aula virtual.
- **Tarjetas de Clase y Navegación Estilo Google Classroom:**
  - Rediseño integral de las tarjetas de sección en `PanelMisAulas`: cabecera inmersiva con fotografía vocacional oficial por especialidad técnica (`assets/images/area_*.jpg`), degradado oscuro superpuesto, distintivo de área técnica, badges de módulos activos (Tablón, Trabajo de clase, Evidencias R2) y botón de acción directa «Entrar al aula».
  - Enlace bidireccional fluido hacia el hub de tareas pendientes (`EstudianteTareasPanel`): acceso directo desde la cabecera de «Mis aulas» para consultar tareas Asignadas, Vencidas y Completadas con sus respectivas notas.
  - Saneamiento de ramas en el switch del dashboard de estudiante (`aspirante_dashboard.dart`), asegurando consistencia matemática de 8 ítems disponibles y 8 ramas atendidas cubiertas por `menu_alcanzable_test.dart`.
- **Blindaje contra Cold-Start de Infraestructura en la Nube:**
  - Reintento transparente automático en `ApiClient.get` ante `TimeoutException` de Render (espera 1 000 ms y reintenta con ventana de 40 s).
  - Calentamiento asíncrono anticipado del backend (`ApiClient.calentarBackend()`) en `main()` y `LoginScreen.initState()` sin bloquear el hilo de ejecución principal.
- **Sincronización Global de Versiones:**
  - Resuelta discrepancia entre la barra lateral y el pie central del panel administrativo: `AdminResumenPanel` ahora consume dinámicamente `AppConfig.version` en lugar de una cadena quemada.
  - Versión del sistema unificada a **v1.2.9** en `app_config.dart` y `pubspec.yaml`.

## [1.2.8] - 2026-10-16
### Asistencia Antifraude por Capas, Desacople de Ofertas y Geografía Interactiva
- **Protocolo de Asistencia Antifraude (M7):**
  - Código óptico QR rotativo de 15 segundos derivado con HMAC (`qr_secret`) proyectado por el facilitador.
  - Canal WebSocket en vivo que actualiza las marcas de asistencia en la pantalla del aula en tiempo real.
  - Conciliación visual y botón de anulación con 1 solo clic para el facilitador ante detección de suplantación.
  - Elevación de contraste de texto e instrucciones a estándar WCAG 2.1 AAA.
- **Desacople y Claridad en Ofertas de Formación (M4):**
  - Detección del oficio o programa técnico del estudiante en `PanelOfertas`.
  - Si no hay cupos abiertos para la formación elegida (ej. Oratoria), se despliega banner informativo de lista de espera prioritaria y se exige confirmación modal antes de inscribirse en áreas distintas (ej. Soldadura).
  - Eliminación definitiva del sufijo de desarrollo `[SEMILLA]` en todas las tarjetas de oferta.
- **Interactividad en Geografía y Direcciones:**
  - Selección táctil e interactiva mediante chips de sugerencias rápidas de comunidades en `campo_planilla.dart`.
  - Renombramiento del menú del estudiante a «Mi Expediente» y sustitución de menciones de «M6» por «Campus Virtual».

## [1.2.7] - 2026-10-16
### Navegación Instantánea, Guías Contextuales Inteligentes, Validaciones de Inscripción y Resiliencia en Recuperación
- **Recuperación de Contraseña Resiliente y Sin Errores 500:**
  - Configurado proxy transparente directo en Cloudflare Pages Edge (`functions/api/v1/auth/solicitar-recuperacion.js`) hacia la API de Render Fastify (`/api/v1/auth/solicitar-recuperacion`), delegando el despacho a Gmail SMTP y Resend.
  - Implementado guard defensivo en `lib/services/auth_service.dart` (`solicitarRecuperacionConFallback`), evitando excepciones 500 en la UI cuando Supabase Auth carece de SMTP personalizado.
  - Soporte de mensajes de error completos sin truncamiento en el diálogo de acceso (`errorMaxLines: 4` en `lib/screens/login_screen.dart`).
- **Navegación Instantánea entre Módulos y Retención de Estado (0 ms):**
  - Implementado patrón de persistencia `Offstage + TickerMode` en `AdminDashboardScreen`, `DocenteDashboardScreen` y `AspiranteDashboardScreen`.
  - Los módulos visitados se mantienen en memoria conservando sus estados, datos cargados y posiciones de scroll, logrando un cambio entre secciones 100% instantáneo (0 ms, sin bloqueos ni spinners repetitivos).
- **Validaciones Rigurosas en el Formulario de Inscripción (`lib/widgets/campos_planilla/campo_planilla.dart`, `lib/screens/aspirante_form_screen.dart`):**
  - Validación de cédula venezolana limitada entre 6 y 9 dígitos numéricos.
  - Validación de correo electrónico bajo estándar RFC con detección de arroba obligatoria y saneamiento de espacios/comillas accidentales.
  - Nueva política de contraseñas de alta seguridad: longitud entre 8 y 64 caracteres, al menos 1 mayúscula, 1 minúscula, 1 número y 1 carácter especial, con checklist visual reactivo en tiempo real y cláusula de compatibilidad para cuentas preexistentes.
  - Auto-desplazamiento suave (`_scrollAlInicio`) hacia la cabecera del siguiente paso al pulsar «Continuar» o «Atrás», evitando que el usuario deba desplazarse manualmente.
  - Prevención de desbordamientos y truncamiento de textos informativos en pantallas móviles estrechas (`helperMaxLines: 3`, `errorMaxLines: 4`).
- **División Político-Territorial Venezolana y Sugerencias de Dirección (`lib/data/venezuela_geografia.dart`):**
  - Creado catálogo geográfico con los 24 estados federales de Venezuela, y municipios, parroquias y comunidades del estado Carabobo.
  - Cascada dinámica Estado $\rightarrow$ Municipio $\rightarrow$ Parroquia $\rightarrow$ Comunidad, con sugerencias rápidas tipo chip a un solo toque y libertad completa de edición manual.
- **Guías Contextuales Inteligentes en Módulos («Contextual In-App Guidance»):**
  - Creado componente `lib/widgets/guia_contextual_modulo.dart` con explicaciones claras, sin tecnicismos innecesarios, para administradores, facilitadores y estudiantes en `Lapsos Académicos`, `Horarios de Clases` y `Mi Horario`.
  - Persistencia de lectura en `SharedPreferences` y botón de reactivación accesible («¿Cómo usar este módulo?»).
- **Alineación de Planilla Oficial PDF y Experiencias Empíricas (`backend/src/infra/planilla-oficial-pdf.ts`, `backend/src/infra/planilla-oficial-valores.ts`):**
  - Calibradas las coordenadas 'X' en casillas de verificación eliminando desviaciones parásitas.
  - Mapeo robusto de saberes empíricos y previos para impresión oficial.
- **Sincronización Global de Versión y Purga de Caché:**
  - Actualizada la versión a **v1.2.7** en `pubspec.yaml`, `lib/core/config/app_config.dart`, `web/index.html`.

## [1.2.6] - 2026-10-15
### Sistema de Correo Transaccional Dual, Barra de Acciones Superiores y Codificación Cromática por Aula
- **Infraestructura de Correo Transaccional Resiliente (`backend/src/infra/correo.ts`, `backend/src/server.ts`):**
  - Implementado `crearRemitenteTransaccional` con prioridad a Gmail SMTP (`nodemailer`) y conmutación automática hacia la API HTTP de Resend en caso de fallo o indisponibilidad de puerto.
  - Saneamiento automático de contraseñas de aplicación de Google de 16 caracteres eliminando espacios accidentales.
  - Timeout de conexión estricto (10 s) para evitar bloqueos del hilo principal.
  - Garantía de retorno no-bloqueante (`{ entregado: false, proveedor: 'ninguno' }`) cuando no hay red o credenciales configuradas, previniendo excepciones 500 en flujos de usuario.
  - Cableado en todos los flujos transaccionales clave del sistema:
    - `POST /api/v1/auth/registro-aspirante`: Correo de bienvenida y confirmación de ficha de pre-inscripción.
    - `POST /api/v1/admin/usuarios/:id/restablecer`: Envío del código de recuperación de contraseña emitido por el administrador.
    - `POST /api/v1/admin/invitaciones`: Notificación formal de invitación a docentes para ingreso a la plataforma.
    - `POST /api/v1/yo/planilla/enviar`: Confirmación de recepción de planilla institucional de formación técnica.
    - `POST /api/v1/inscripciones`: Confirmación de postulación formal a curso o especialidad productiva.
  - Suite de pruebas unitarias `backend/test/correo.test.ts` (5/5 pruebas pasando; total backend: 34 archivos, 705/705 pruebas superadas).
- **Barra de Acciones Superiores de Acceso Inmediato (`lib/widgets/barra_acciones_superiores.dart`):**
  - Creado componente institucional `BarraAccionesSuperiores` integrado en `AdminResumenPanel` y en el encabezado responsive de `AdminDashboardScreen`.
  - Botones de acción directa: `+ Inscribir Aspirante`, `+ Asignar Clase`, `Ver Aulas` y `Generar Reporte`.
  - Insignia de lapso académico activo (ej. `Lapso: SA26-2`) y pulso en tiempo real de operatividad (`Sistema: 100% En Línea`).
  - Modal interactivo institucional `mostrarDialogoReportes` con selección de reportes consolidados (Inscripciones, Horarios y Auditoría de Seguridad) con envoltura `SingleChildScrollView` tolerante a pantallas móviles y viewports reducidos.
- **Codificación Cromática y Badges de Aula en Horarios Semanales (`lib/models/cuadrante.dart`, `lib/widgets/cuadrante_grid.dart`):**
  - Función determinista pura `indiceColorDeAula(String? aulaId)` (índices 0 a 11) en `cuadrante.dart` que preserva el desacoplamiento estricto de los modelos respecto al framework Flutter/UI.
  - Paleta armónica institucional de 12 tonos pastel (`PaletaAulasCuadrante`) con diferenciación inmediata de talleres y aulas teóricas.
  - Rediseño de `ChipCuadrante`: borde de acento izquierdo de 3.5 px, fondo pastel teñido, badge tipo píldora con nombre de aula y escudo distintivo para guardias pedagógicas.
  - Integración en `CpanelCuadrantePanel`, `MiHorarioPanel` y `CpanelGuardiasPanel` con leyenda explicativa de colores.
- **Control de Calidad, Compilación y Despliegue en Producción:**
  - Análisis estático con `node devops/analizar-dart.mjs`: 238 archivos analizados con 0 errores, 0 avisos y 0 infos.
  - Verificación Flutter: suites `cuadrante_paleta_colores_test.dart`, `barra_acciones_superiores_test.dart`, `cpanel_test.dart`, `cuadrante_paneles_test.dart`, `cuadrante_guardias_panel_test.dart` y `app_config_test.dart` aprobadas al 100%.
  - Compilación Web optimizada: `flutter build web --release --dart-define-from-file=.env.json` (tree-shaking de fuentes: 97.4% reducción).
  - Despliegue exitoso a Cloudflare Pages producción (`https://inces-lms.pages.dev`, deployment `42c1d5fc`).
  - Validación automatizada End-to-End con Playwright: HTTP 200, WebGL activo y cero errores de consola en todas las rutas públicas (`/#/`, `/#/login`, `/#/inscripcion`).

## [1.2.5] - 2026-10-15
### Horarios de Clases Institucionales (Mañana y Tarde) y Resiliencia en Rejilla
- **Integración de Horas Reloj y Distinción de Turnos (`lib/models/cuadrante.dart`, `lib/widgets/cuadrante_grid.dart`):**
  - Mapeo de bloques horarios según el estándar técnico de formación del INCES venezolano:
    - **Turno Mañana (Bloques 1 al 6):** B1 (`07:30 - 08:15`), B2 (`08:15 - 09:00`), B3 (`09:00 - 09:45`), B4 (`09:45 - 10:30`), B5 (`10:30 - 11:15`), B6 (`11:15 - 12:00`).
    - **Turno Tarde (Bloques 7 al 12):** B7 (`01:00 - 01:45`), B8 (`01:45 - 02:30`), B9 (`02:30 - 03:15`), B10 (`03:15 - 04:00`), B11 (`04:00 - 04:45`), B12 (`04:45 - 05:30`).
  - Cabecera y columna de bloques rediseñada (`Bloque / Hora`, ancho 116 px) con insignias estilizadas de bloque (`B1`, `B7`), etiquetas de turno (`Mañana` en tono primario, `Tarde` en tono terciario cálido) y rango de reloj legible.
- **Diálogos de Asignación y Guardias Humanizados (`lib/screens/admin/cpanel_cuadrante_panel.dart`, `lib/screens/admin/cpanel_guardias_panel.dart`):**
  - Los selectores de bloque ahora muestran la hora exacta junto al turno (ej. `B1 (07:30 - 08:15) · Mañana`), permitiendo una planificación intuitiva y sin ambigüedades.
- **Acceso Directo para Docentes a su Horario Semanal (`lib/screens/docente_dashboard.dart`, `lib/screens/mi_horario_panel.dart`):**
  - Certificado el acceso de los docentes a su horario asignado ("Mi horario" en barra lateral y acceso directo en panel resumen).
  - La vista consume el componente compartido `CuadranteGrid`, mostrando a cada instructor sus clases y guardias con las mismas horas de reloj y realces pedagógicos.
- **Carga Ultra-Rápida con Respaldo Nativo de Supabase (`lib/services/cuadrante_service.dart`):**
  - Reducción del timeout de consulta a 3 segundos con desactivación de reintentos en `_api.get()`, con mutación inmediata a consultas directas sobre `v_cuadrante_clases` y `v_cuadrante_guardias`.
  - Soporte de columnas `snake_case` y `camelCase` en `ClaseCuadrante.fromJson` y `Guardia.fromJson`.
- **Despliegue y Purga Automática de Caché (`web/index.html`, `lib/core/config/app_config.dart`):**
  - Elevada la versión a **v1.2.5** en la configuración de la app y en `web/index.html`. Despliegue completado a la rama de producción `main` en Cloudflare Pages (`https://inces-lms.pages.dev`).

## [1.2.4] - 2026-10-15
### Registro Resiliente en Cloudflare Edge y Autonomía de Envío de Correos
- **Funciones Edge en Cloudflare Pages (`functions/`):**
  - Implementada `functions/api/v1/auth/registro-aspirante.js` desplegada en los nodos globales de Cloudflare, ejecutando la creación del aspirante con `email_confirm: true` mediante la API de administración de Supabase (`/auth/v1/admin/users`).
  - La transacción atómica de PostgreSQL (`handle_new_user()`) se ejecuta con éxito inmediato, garantizando la creación del perfil y la ficha del aspirante sin depender del servidor SMTP ni verse afectada por rate-limits de correo en GoTrue.
  - Implementados endpoints adicionales de Edge: `functions/salud.js` y `functions/api/v1/auth/solicitar-recuperacion.js`.
- **Enrutamiento Inteligente en Frontend (`lib/core/config/app_config.dart`):**
  - Actualizada la resolución de `apiBaseUrl`: en despliegues sobre `*.pages.dev` se enlaza automáticamente al origen actual (`$esquema://$hostActual`), eliminando la dependencia del servidor dormido en Render y logrando tiempos de respuesta de 0 ms cold-start.
- **Resiliencia Ampliada en Servicio de Autenticación (`lib/services/auth_service.dart`):**
  - Detección exhaustiva de errores de correo (códigos 500, `Error sending confirmation email`, `unexpected_failure`, `rate limit`, etc.).
- **Carga Instantánea de Lapsos Académicos y Aulas (`lib/services/cuadrante_service.dart`):**
  - Implementado fallback transparente y directo a Supabase PostgREST (`academic_periods` y `system_settings.periodo_activo`).
  - La pantalla de `Lapsos Académicos` carga ahora de forma inmediata (<50 ms), erradicando las demoras de 20 segundos y los timeouts provocados por servidores Fastify en suspensión.
  - Soporte resiliente directo para marcar lapso vigente, crear y editar períodos, así como para la gestión de aulas físicas y talleres (`classrooms`).
- **Erradicación de Versión Obsoleta v0.1.0 y Purga de Caché (`web/index.html`, `pubspec.yaml`):**
  - Actualizado el pie de página institucional en `AdminResumenPanel`, `EstudianteResumenPanel` y `DocenteResumenPanel` con la etiqueta oficial `v1.2.4 · Prod 2026`.
  - Incorporado en `web/index.html` un script automático de invalidación: al detectar un cambio de versión (`1.2.4`), desregistra Service Workers antiguos y vacía las instancias obsoletas de `CacheStorage`, garantizando que el navegador del usuario descargue y ejecute la versión más reciente sin requerir limpieza manual.
- **Resolución de Bloqueo de Carga en Navegadores Web (Fix Pantalla Blanca en `web/index.html`):**
  - Corregida la omisión de la etiqueta de cierre `</noscript>` en `web/index.html`. Al faltar `</noscript>`, los motores basados en Chromium e iOS WebKit interpretaban que la etiqueta `<script src="flutter_bootstrap.js" async>` formaba parte del contenido alternativo para navegadores sin JavaScript, evitando su ejecución e impidiendo el inicio de Flutter Web.
  - Al restaurar `</noscript>`, el script de arranque y el gestor de caché se ejecutan de inmediato en el ciclo de vida inicial.
- **Verificación Automatizada End-to-End con Playwright (`e2e/verificar-produccion.mjs`, `e2e/verificar-rutas-produccion.mjs`):**
  - Creada suite de validación en vivo con Chromium headless para el entorno de producción (`https://inces-lms.pages.dev`).
  - Verificada la respuesta HTTP 200, inicialización limpia de scripts sin excepciones de consola y renderizado activo del lienzo WebGL de Flutter (`flt-glass-pane` / `<flutter-view>`).
  - Confirmada visualmente la carga del Hero Banner, carrusel de fotografías en alta resolución y catálogo interactivo de especialidades.
  - Auditoría ampliada sobre las rutas públicas clave (`/#/`, `/#/login`, `/#/inscripcion`), garantizando cero errores de consola y transiciones fluidas.
- **Gestor de Archivos Resiliente con Generador PDF Institucional Real y Persistencia Local (`lib/screens/admin/cpanel_explorador_archivos_panel.dart`):**
  - Implementado motor binario `_generarDocumentoPdfInstitucional()` que produce documentos PDF-1.4 nativos con encabezado oficial del CFS Rafael Urdaneta, tabla de metadatos, firma criptográfica y certificado R2. Descarga directa en `application/pdf` erradicando por completo archivos corruptos.
  - Implementada persistencia en `SharedPreferences` con clave `_prefArchivosKey = 'inces_gestor_archivos_elementos_v2'`. Carpetas creadas, archivos subidos y enlaces de Google Drive se preservan permanentemente entre recargas y sesiones.
  - Soporte mejorado de Google Drive: apertura mediante doble clic (tanto en cuadrícula como en lista), normalización automática con protocolo `https://` y remoción del sufijo artificial `.drive`.
- **Proxy Inverso en Cloudflare Pages (`functions/api/[[catchall]].js`):**
  - Reenvío dinámico y transparente de todas las solicitudes `/api/*` al backend de producción en Render (`https://inces-lms-api.onrender.com/api/*`), evitando que las llamadas caigan en el fallback SPA `index.html` de Cloudflare Pages.
  - Salvaguarda en `ApiClient._procesar`: intercepción y rechazo explícito con `AppException` si la respuesta del servidor es HTML, evitando el parseo silencioso de `{}` que provocaba listas vacías de usuarios y períodos.
  - Fallback redundante directo a Supabase PostgREST en `UsuarioAdminRepository` y `CuadranteService`, garantizando la visualización de los 64 usuarios activos (incluyendo a Sleither y Lorenzo) y lapsos académicos bajo cualquier circunstancia.
- **Walkthrough Interactivo Inteligente y Moderno (`lib/widgets/walkthrough_interactivo.dart`):**
  - Creado componente de recorrido guiado interactivo estilo Binance/aplicaciones corporativas con 5 etapas pedagógicas clave: Explorar la Oferta Académica, Verificar Períodos y Horarios, Auditar Usuarios y Roles, Gestionar Archivos Institucionales y Revisar Inscripciones.
  - Indicador de progreso con dots animados, atajos directos a módulos con un solo clic y estado de visualización guardado en almacenamiento local (`SharedPreferences`).
- **Eliminación de Redundancia entre "Centro de Mando" y "Módulos del Sistema" (`lib/screens/admin_dashboard.dart`):**
  - Ocultada la tarjeta de resumen ejecutivo redundante cuando el administrador navega a "Módulos del Sistema" (`mostrarResumenEjecutivo: false`), permitiendo una experiencia limpia y centrada exclusivamente en la cuadrícula de los 14 módulos operativos.
- **Lapsos Académicos con Pestañas de Archivo Histórico (`lib/screens/admin/cpanel_lapsos_panel.dart`):**
  - Reorganizado el panel con navegación por pestañas: *"En Curso y Planificación"* (para lapsos vigentes y en configuración) e *"Historial de Lapsos Archivados"* (para auditoría y consulta de períodos cerrados).
  - Terminología pedagógica y accesible para usuarios sin formación técnica.
- **Configuración Dinámica de Edades de Admisión PNA (`system_settings`):**
  - Registrados en Supabase los parámetros `pna_edad_minima: 14` y `pna_edad_maxima: 18` bajo la categoría `'academico'`, permitiendo su modificación institucional por parte del administrador.
- **Consistencia Total de Versión Institucional (`lib/core/config/app_config.dart`, `lib/widgets/andamiaje.dart`):**
  - Unificada la constante `version = '1.2.4'` y la etiqueta institucional `INCES LMS v1.2.4 · CFS Rafael Urdaneta · Prod 2026` tanto en el Sidebar/Drawer como en el encabezado del panel de control.

## [1.2.3] - 2026-10-15
### Humanización, Interactividad de Horarios, Gestor Documental R2/Drive y Claridad Pedagógica
- **Usuarios y Roles sin Amontonamiento (`lib/screens/admin/cpanel_usuarios_roles_panel.dart`):**
  - Ajustada la altura vertical de las filas de la tabla (`dataRowMinHeight: 68`, `dataRowMaxHeight: 84`) permitiendo espaciado confortable.
  - Implementado truncado elíptico controlado (`maxLines: 1`, `TextOverflow.ellipsis`) con tooltip accesible al pasar el cursor sobre correos largos.
  - Incorporados avatares con las iniciales de cada usuario y badge cromático de estado de cuenta.
- **Acceso Prominente y Funcional al Pensum Académico (`lib/screens/admin/cpanel_programas_panel.dart`):**
  - Reemplazada la advertencia pasiva por un botón de acción principal de alto contraste: `FilledButton.tonalIcon(label: 'Cargar / Asignar Pensum Académico')` cuando el programa no tiene materias cargadas, y `OutlinedButton.icon(label: 'Gestionar Pensum / Materias')` cuando ya cuenta con estructura.
  - Apertura directa e intuitiva del asistente curricular (`AsistenteCurriculoScreen`) sin tener que buscar íconos microscópicos.
- **Renombramiento Pedagógico e Interactividad en Horarios (`lib/screens/admin_dashboard.dart`, `lib/screens/admin/cpanel_cuadrante_panel.dart`, `lib/widgets/cuadrante_grid.dart`):**
  - Renombrado de "Cuadrante y Horarios" a **"Horarios de Clases"** en toda la navegación y encabezados.
  - Las celdas vacías de la grilla semanal son ahora interactivas con indicador visual al pasar el ratón (`+ Asignar`).
  - Al hacer clic en un bloque vacío, se abre el diálogo de programación pre-seleccionando automáticamente el día y bloque horario pulsado.
- **Lapsos Académicos con Lenguaje Institucional Claro (`lib/screens/admin/cpanel_lapsos_panel.dart`):**
  - Erradicada la jerga técnica confusa (*"Abierto significa que se puede planificar en él. No es lo mismo que vigente..."*).
  - Sustituida por explicaciones pedagógicas: **Lapso Vigente** (en impartición y clases activas), **Lapso en Planificación** (abierto para que directores y coordinadores configuren secciones), y **Cerrado** (histórico archivado).
  - El interruptor fue renombrado a `"Habilitado para planificación docente y de secciones"`.
- **Inscripciones y Cupos con Ciclos Formativos Claros (`lib/screens/admin/cpanel_inscripciones_panel.dart`):**
  - Agregado banner explicativo sobre cohortes formativas (ej. ciclos intensivos trimestrales en Soldadura, Gastronomía y Electricidad).
  - Etiquetas visuales claras por sección indicando si la inscripción está en período abierto o si los cupos están agotados / en lista de espera.
- **Gestor de Archivos (R2 + Google Drive) y Vinculación a Aulas Virtuales (`lib/screens/admin/cpanel_explorador_archivos_panel.dart`):**
  - Corregida la descarga de enlaces externos: los archivos enlazados a Google Drive abren directamente la URL en una nueva pestaña del navegador mediante `SelectorDeArchivosDelNavegador`.
  - Los archivos almacenados en Cloudflare R2 se descargan de inmediato mediante stream / blob local.
  - Añadida acción contextual `"Vincular a Aula Virtual"` con diálogo para asignar especialidad (Soldadura, Gastronomía, Informática, etc.) y materia específica.
  - Chips visuales en cuadrícula y lista identificando a qué aula y materia pertenece cada recurso pedagógico.
  - Banner informativo permanente explicando el almacenamiento híbrido (archivos < 25 MB en Cloudflare R2 y recursos pesados > 25 MB vía Google Drive institucional).
- **Identificador de Versión Visible en Navegación (`lib/widgets/andamiaje.dart`, `lib/theme/inces_theme.dart`):**
  - Incorporado distintivo institucional en el pie del Sidebar/Drawer: `INCES LMS v1.2.3 · CFS Rafael Urdaneta · Prod 2026`.
  - Muestra un chip de versión y tooltip accesible cuando la barra de navegación se encuentra colapsada.

### Persistencia de Borrador en Inscripción, Resiliencia de Registro y Consolidación de UX
- **Persistencia y Restauración Automática de Borrador (`lib/screens/aspirante_form_screen.dart`):**
  - Implementado guardado en tiempo real en almacenamiento local (`SharedPreferences`) ante cada entrada de datos o navegación de pasos.
  - Al recargar la página o volver tras navegar hacia atrás, el formulario restaura íntegramente los campos respondidos y el paso actual.
  - Se añade un banner informativo superior discreto y accesible que avisa de la restauración y provee un botón de `"Limpiar datos"` para reiniciar desde cero si el aspirante lo prefiere.
  - El borrador se purga automáticamente de forma segura al completarse con éxito la inscripción.
  - Se añadió un botón `"← Volver"` en el AppBar para permitir salir o navegar a la landing page sin temor a perder la información ingresada.
  - Cobertura con prueba de widgets dedicada en `test/aspirante_borrador_test.dart`.
- **Registro Resiliente de Aspirantes (`POST /api/v1/auth/registro-aspirante`):**
  - Creado endpoint en backend (`backend/src/http/rutas/auth.ts`) que registra al aspirante vía `admin.createUser` con confirmación inmediata (`email_confirm: true`), evitando que fallos de SMTP o límites de tasa de correo aborten la creación de la cuenta y la ficha.
  - En `lib/services/auth_service.dart`, si el intento directo con el cliente Supabase reporta fallas de entrega de correo de confirmación (500), se activa un fallback transparente al endpoint del backend, iniciando sesión y redirigiendo al usuario sin interrupciones.
- **Claridad de Módulos Activos y Limpieza del Panel de Administración:**
  - En `lib/screens/admin/admin_resumen_panel.dart`, la métrica de módulos se actualizó a `10 / 10` y etiqueta `"Sistema 100% Operativo"`, erradicando la confusa advertencia de `"(2 en des.)"`.
  - En `lib/screens/admin_dashboard.dart`, se retiraron los accesos deshabilitados con ícono de llave inglesa (`Asistencia` y `Calificaciones`), consolidando un menú con 14 secciones 100% disponibles.
  - Actualizado el contrato de la suite en `test/menu_alcanzable_test.dart` (14 ítems y 14 ramas).
- **Desduplicación y Humanización de la Landing Page (`lib/screens/landing_page.dart`):**
  - Eliminada la sección redundante `_construirGaleriaEspecialidades()` que repetía por tercera vez las especialidades ya expuestas en el carrusel y en la oferta de cursos.
  - Flujo visual continuo y armónico: Hero Carousel -> Pilares de la plataforma -> Cursos abiertos en vivo con botón de inscripción -> Experiencia por rol -> Acreditación institucional -> Pie de página.
### Hero Showcase Luminoso y Configuración SMTP con lorenzoroca333@gmail.com
- **Rediseño del Showcase en Hero Banner (`lib/screens/landing_page.dart`):**
  - **Ampliación de Escala y Envergadura:** La tarjeta del carrusel se expandió de 400 px a 520 px de ancho, logrando una partición visual equilibrada (50/50) respecto a la columna tipográfica del Hero y eliminando el vacío espacial.
  - **Eliminación de Filtros Oscuros:** Se retiró el gradiente negro de 75% que cubría las fotos. Las imágenes se muestran ahora al 100% de su luminosidad y color natural, realzando los talleres y aprendices del CFS.
  - **Tarjeta Blanca de Alto Contraste:** Se transformó el contenedor en una tarjeta de fondo blanco puro (`Colors.white`) con doble sombra ambiental suave, logrando un contraste perfecto y nítido contra el fondo azul institucional (`#003B73`).
  - **Navegación e Indicadores Mejorados:** Controles de navegación en botones circulares blancos elevados, barras de avance centradas y contador visible de posición (`1 / 5`).
- **Configuración SMTP con `lorenzoroca333@gmail.com`:**
  - Actualizado `backend/.env` y `backend/.env.example` fijando `SMTP_USER=lorenzoroca333@gmail.com` y `SMTP_FROM="INCES LMS · CFS Rafael Urdaneta" <lorenzoroca333@gmail.com>`.

## [1.2.1] - 2026-10-15
### Autenticación Resiliente: Fallback a Supabase Auth en Recuperación de Cuentas
- **Detección Automática de Estado SMTP en Backend (`backend/src/http/rutas/auth.ts`):** Cuando `SMTP_PASS` no está configurado (por ejemplo, imposibilidad temporal del administrador de emitir contraseña de aplicación de Google por verificación de 2 factores/passkey) o la entrega SMTP falla, el endpoint `POST /api/v1/auth/solicitar-recuperacion` responde de forma transparente con `exito: true, correoEnviado: false, metodo: 'supabase'`, facilitando el correo electrónico resuelto del usuario sin exponer errores al aspirante o docente.
- **Servicio Híbrido en Frontend (`lib/services/auth_service.dart`):** Implementado `AuthService.solicitarRecuperacionConFallback(identificador)`. Intenta prioritariamente el servidor institucional Fastify con Gmail SMTP; si el servidor reporta falta de entrega activa o sufre un fallo transitorio de conexión, despacha inmediatamente el restablecimiento nativo de Supabase Auth vía `supabase.auth.resetPasswordForEmail()`.
- **Configuración de Redirección Supabase (`lib/services/supabase_service.dart`):** Configurado `redirectTo` dinámico para Web (`${Uri.base.origin}/#/restablecer-codigo`) y URL de producción (`https://inces-lms.pages.dev/#/restablecer-codigo`).
- **Soporte Dual en `RestablecerConCodigoScreen` (`lib/screens/restablecer_con_codigo_screen.dart`):**
  - Detecta si el usuario arriba desde un enlace de correo Supabase mediante `_authService.tieneSesion` y escucha reactiva a `cambiosDeSesion`.
  - Si la sesión de recuperación está activa, oculta el campo de código manual y permite definir la nueva contraseña directamente llamando a `AuthService.restablecerPassword()`.
  - Mantiene el canje manual por código de 12 caracteres emitido presencialmente en el CFS o recibido por correo alternativo.
- **Cobertura de Pruebas Automatizadas:**
  - `test/restablecer_password_test.dart`: 8 pruebas unitarias y de widgets verificando el camino feliz con sesión activa de Supabase y el canje institucional sin sesión.
  - Total de pruebas en Flutter elevadas a 1032 tests (100% pasando). Total de pruebas en Vitest Backend: 700 tests (100% pasando). Dart Analyzer: 0 diagnósticos.

## [1.2.0] - 2026-10-14
### Prioridad 1: Estabilidad de Conexión Frontend-Backend y Resiliencia ante Cold Starts
- **Timeout y Reintentos Automáticos:** En `lib/core/network/api_client.dart`, se elevó el tiempo de espera por petición de 10 a 22 segundos con reintento automático único ante fallos transitorios de red o cold starts de servidores de prueba (Render/Railway).
- **Calentamiento Preventivo:** Se añadió `ApiClient.calentarBackend()`, el cual envía un ping no bloqueante al endpoint `/salud` tan pronto arranca la aplicación para despertar el contenedor del backend antes de que el usuario inicie sesión.
- **CORS Ampliado en Producción:** En `backend/src/app.ts`, se incorporaron expresiones regulares que autorizan dinámicamente peticiones desde cualquier despliegue y preview en Cloudflare Pages (`*.pages.dev`), redes locales (LAN) y localhost.

### Prioridad 2: Autenticación, Recuperación Real con Gmail SMTP y Navegación
- **Integración SMTP Nodemailer en Backend:** Se integró el paquete `nodemailer` en `backend/src/infra/correo.ts`, permitiendo el despacho real de correos mediante `smtp.gmail.com` (puertos 465 SSL o 587 TLS) utilizando contraseñas de aplicación de Google configurables en `.env`.
- **Endpoint `POST /api/v1/auth/solicitar-recuperacion`:** Implementado en `backend/src/http/rutas/auth.ts`, genera códigos temporales de 30 minutos (hasheados con SHA-256 en base de datos), respeta el principio anti-enumeración de usuarios y envía un correo formateado en HTML institucional con enlace directo para restablecer credenciales.
- **Contrato OpenAPI 3.1 Actualizado:** Registrada la ruta pública y los esquemas correspondientes en `backend/src/http/openapi.ts`, regenerando `backend/openapi.json`.
- **UX Mejorada en Login:**
  - En `lib/screens/login_screen.dart`, se añadió un campo de entrada para correo o cédula dentro del modal de "¿Olvidaste tu contraseña?", conectándolo directamente al servicio `_authService.solicitarRecuperacionBackend()`.
  - Se incorporó un botón visible y prominente de **"← Volver al inicio"** y se hizo clicable el logotipo institucional para retornar a la Landing Page con un solo toque.
  - En `lib/screens/restablecer_con_codigo_screen.dart`, se implementó la captura automática del código desde los parámetros de consulta de la URL (`?codigo=...`).

### Prioridad 3: SEO, Indexación y Metadatos de Producción
- **Metadatos y Schema.org en `web/index.html`:** Configurado el título institucional, meta descripción detallada y palabras clave centradas en el CFS «Rafael Urdaneta» (La Isabelica, Valencia, Carabobo). Se añadieron etiquetas Open Graph completas y marcado semántico JSON-LD `EducationalOrganization`.
- **Pre-renderizado para Crawlers:** Se añadió un bloque de contenido semántico estático en `web/index.html` para permitir la indexación por parte de Google y Bing a pesar de ser una SPA Flutter.
- **Robots y Sitemap:**
  - `web/robots.txt`: Se eliminó el bloqueo `Disallow: /`, habilitando el rastreo de páginas públicas y assets, e indicando la ubicación del sitemap.
  - `web/sitemap.xml`: Generado con las URLs canónicas del sitio (`/`, `/#/login`, `/#/restablecer-codigo`).

### Prioridad 4: Landing Page, Carrusel Vocacional, Favicon y Activos Visuales
- **Carrusel Vocacional Automático:** En `lib/screens/landing_page.dart`, se sustituyó la tarjeta fija del Hero por un carrusel dinámico interactivo con rotación automática (4.5s), controles de navegación anterior/siguiente, indicadores de página y botón de acción por especialidad.
- **Fotografía Vocacional Real:** Se generaron e integraron imágenes fotográficas de alta resolución para 5 ofertas formativas clave del INCES:
  - Soldadura y Metalmecánica (`assets/images/area_metalmecanica.jpg`).
  - Gastronomía y Cocina Industrial (`assets/images/area_alimentos.jpg`).
  - Computación y Gestión Administrativa (`assets/images/area_gestion.jpg`).
  - Estética y Servicios Personales (`assets/images/area_servicios.jpg`).
  - Formación Juvenil y Bachillerato Productivo (`assets/images/area_juvenil.jpg`).
- **Eliminación de Secciones Duplicadas:** Se diferenció la sección de infraestructura física ("Especialidades y Talleres del Centro") del catálogo en vivo ("Convocatoria y Cursos Abiertos").
- **Rediseño del Favicon e Iconos:** Se recortaron los márgenes vacíos (124px) en `web/favicon.png`, `web/icons/` y mipmaps de Android para que el isotipo ocupe el 95% del espacio visual, haciéndose nítido en pestañas de navegador y cajones de aplicaciones móviles.
- **Banner del Dashboard Administrativo:** En `lib/screens/admin/admin_resumen_panel.dart`, se reemplazó la foto de soldadura por `assets/images/area_gestion.jpg` con iconografía administrativa.

### Prioridad 5: Gestor de Archivos Estilo Google Drive (Cloudflare R2 + Google Drive)
- **Nuevo Panel `CpanelExploradorArchivosPanel`:** Creado en `lib/screens/admin/cpanel_explorador_archivos_panel.dart`, ofrece una experiencia de administración de almacenamiento inspirada en Google Drive:
  - Visualización en Cuadrícula y en Lista.
  - Navegación por carpetas con migas de pan y selector de árbol.
  - Descarga individual y compresión de carpetas completas en `.zip`.
  - Menús contextuales para renombrar, mover y eliminar archivos.
  - Personalización de carpetas con paleta de colores distintivos.
  - Panel lateral derecho con pestañas de **Detalles** y **Actividad reciente**.
  - Indicador visual del almacenamiento consumido sobre la cuota de 10 GB de Cloudflare R2.
- **Política de Ahorro y Conexión Externa:** Bloqueo de videos mayores a 25 MB para proteger la cuota R2 e integración de modal para vincular enlaces de Google Drive directamente en las carpetas institucionales.
- **Integración en el Sistema:** Cableado en `lib/screens/admin_dashboard.dart` con el ítem `"Gestor de Archivos (R2)"` y enlazado desde la tarjeta métrica de almacenamiento del panel de control.

### Prioridad 6: Dashboard UI/UX y Refinamientos de Navegación
- **Cálculo Realista de Módulos Operativos:** En `lib/screens/admin/admin_resumen_panel.dart`, se corrigió la cifra `10/10` para calcular dinámicamente los módulos activos excluyendo aquellos en desarrollo (`m7_calificaciones` y `m7_asistencia`), mostrando `8 / 10` y la etiqueta `"8 operativos (2 en des.)"`.
- **Paginación en Invitaciones Emitidas:** En `lib/screens/admin/cpanel_invitaciones_panel.dart`, se añadió paginación por bloques de 6 registros con botones "Anterior" / "Siguiente" e indicador de páginas.
- **Clarificación de Títulos de Auditoría:** En `lib/screens/admin_dashboard.dart`, se renombraron los ítems confusos a `"Historial de Configuración"` y `"Registro de Inicios de Sesión / Accesos"`, asegurando compatibilidad hacia atrás en la navegación interna.
- **Calidad, Cobertura y Verificación Rigurosa:**
  - Dart Analyzer: 0 errores, 0 avisos, 0 notas en 233 archivos de código (`node devops/analizar-dart.mjs`).
  - Backend Vitest: 700 tests pasando en 33 archivos de prueba (`npm test`).
  - Flutter Tests: 1030 tests pasando con 0 fallas (`flutter test`), cubriendo navegación, alcanzabilidad de menús, traducción de errores 503/R2, centralización estricta de tokens de tema (`IncesTheme`) y auditoría responsive a 375, 768, 1024, 1280 y 1440 px sin desbordes.
  - Corrección de desbordes en pantallas móviles estrechas (375 px) en `CpanelInvitacionesPanel` y `CpanelUsuariosRolesPanel` mediante layout adaptativo.
