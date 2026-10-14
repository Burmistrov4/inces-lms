# 03 — Stack tecnológico

> Cada tecnología lleva su versión medida y **el porqué** de la decisión. Las
> decisiones registradas (ADR) son vinculantes: cambiarlas es una decisión de
> arquitectura, no una preferencia de implementación.

## 1. Mapa de capas

| Capa | Tecnología | Versión medida | Dónde vive |
|---|---|---|---|
| Frontend | **Flutter + Dart** (Web) | Flutter **3.47.0** / Dart 3.13 (`sdk: ^3.13.0`) | `lib/`, `test/` |
| Estado (frontend) | **Provider** | ^6.1.2 | `lib/providers/` |
| API | **Node.js + TypeScript + Fastify + Zod** | Node **22**, TS 5.7, Fastify ^5.2.1, Zod ^3.24.1 | `backend/` |
| Base de datos | **Supabase (PostgreSQL)** | **17.6**, región `sa-east-1` | nube (ref `twdppwnxlnmxkiejbrei`) |
| Auth | **Supabase Auth (GoTrue)** | v2 del cliente JS (`@supabase/supabase-js` ^2.47.10) | cliente Flutter + backend |
| Almacenamiento pesado | **Cloudflare R2** (S3-compatible) | SDK `@aws-sdk/client-s3` ^3.1131.0 | `backend/` + bucket `inces-lms-media` |
| Tiempo real | **WebSocket** (`@fastify/websocket`, `web_socket_channel`) | ^11.3.1 / ^3.0.1 | asistencia M7 |
| Validación SQL | **PGlite** (PostgreSQL compilado a WASM) | — | `supabase/tests/` |
| E2E | **Playwright + TypeScript** (Chromium real) | — | `e2e/` |
| CI/CD | **GitHub Actions** (6 workflows) | — | `.github/workflows/` |
| Producción backend | **Render** (Docker, plan free) | — | `render.yaml` |
| Producción frontend | **Cloudflare Pages** | — | proyecto `inces-lms` |
| Local/dual | **Docker + docker-compose** | — | raíz |

**Cero Python en todo el proyecto.** Esto es deliberado y está documentado: un
encargo externo llegó en 2026-09-24 describiendo el backend como «FastAPI con
boto3»; era falso, y ejecutarlo al pie de la letra habría metido Python en un
backend que no lo tiene.

## 2. Frontend — Flutter Web

**Por qué Flutter:** una sola base de código para los tres destinos
institucionales (Web para el centro, Android/iOS como destino posible), 100 %
responsive desde el inicio, y compila a JavaScript estándar para Cloudflare
Pages. La versión va **fijada a 3.47.0 en CI**, no a `stable`: es la que usa el
proyecto en local; un verde con otro toolchain no sería evidencia sobre lo que
se defiende ante el jurado.

**Dependencias (y el porqué de las que no son obvias):**

| Paquete | Para qué |
|---|---|
| `supabase_flutter` ^2.8.0 | Cliente oficial: auth (GoTrue) y PostgREST desde el navegador |
| `provider` ^6.1.2 | Gestión de estado ligera (sesión, tema, rol) |
| `qr_flutter` ^4.1.0 | **Pinta** el QR del docente (M7) |
| `mobile_scanner` ^7.4.2 | **Lee** QR (segunda mitad de D21). Variante **empaquetada** de MLKit a propósito: el modelo va dentro de la app y funciona **sin red** —la variante ligera lo descargaría de Google Play Services, y fallaría justo el día que la conexión no va |
| `web_socket_channel` ^3.0.1 | Canal en vivo del tablero de asistencia |
| `web` ^1.1.0 | API del navegador (DOM) para elegir archivos y abrir descargas (M5/HACER). Es la alternativa vigente a `dart:html`, deprecado |
| `crypto` ^3.0.3 | CriptografíaLocal (hashes de apoyo) |
| `shared_preferences` ^2.5.5 | Memoria de la preferencia de tema |
| `google_fonts` ^6.2.1 | Tipografía **Inter** (no Poppins: dígitos anchos que castigan las tablas densas) |
| `intl`, `uuid`, `http`, `cupertino_icons` | Formato de fechas, UUIDs, cliente HTTP de apoyo, iconos |

**Arquitectura del frontend (Capas, de fuera a dentro):**

```
screens/      → widgets con estado (pantallas y paneles)
providers/    → estado de sesión/rol/tema (Provider)
services/     → orquestación; nunca hablan con la red directamente
repositories/ → capa de datos; devuelven Result<T>, nunca null como error
gateways/     → puertos (interfaces) hacia Supabase/Backend/R2/navegador
models/       → modelos de dominio puros
core/         → Result, errores tipados (AppException), config, reglas puras
theme/        → IncesTheme: única fuente de color y tipografía
```

**Contrato load-bearing (ADR-010):** las capas de datos devuelven
`Result<T>` (`Success`/`Failure` con `AppException`); **`null` significa «no
existe», nunca «falló»**; los errores de Postgres/PostgREST/GoTrue se traducen
a español con mensajes accionables.

**Sistema de diseño:** `lib/theme/inces_theme.dart` es la **única** fuente de
color y tipografía; los colores de marca son **exactos, no derivados**
(`#003B73` primario, `#0059B3` secundario, `#D32F2F` rojo INCES). Hay tema claro
y oscuro con contraste medido (WCAG 4.5:1 en los dos).

**Lo que Flutter Web implica y hay que saber:**

- La configuración se lee **al compilar** (`String.fromEnvironment()`), no de un
  `.env`: el equivalente es `--dart-define-from-file=.env.json`.
- En CanvasKit, **los widgets no son DOM**: no existen `getByRole`/`getByText`
  para el E2E; hay que encender el árbol semántico (`flt-semantics-placeholder`)
  y usar `flt-semantics[aria-label=…]` / `getByLabel`. El `<canvas>` vive en el
  shadow DOM de `flt-glass-pane`.
- `flutter test` corre en la VM de Dart: **no compila el código de navegador**.
  Un import condicional puede resolver a la rama equivocada en silencio: la
  prueba pasa y el navegador lanza al primer clic. La compilación web
  (`flutter build web`) es la que cubre esa rama.

## 3. Backend — Node/TypeScript con Fastify

**Por qué Fastify y no otro:** API **stateless** (sin estado en memoria;
escalable horizontalmente y compatible con serverless y contenedor), schemas de
validación con **Zod** y contrato **OpenAPI 3.1 generado desde Zod** —un
`openapi.yaml` escrito a mano sería un segundo contrato que se separa del
primero en la primera semana (D6, resuelta).

**Dependencias:**

| Paquete | Para qué |
|---|---|
| `fastify` ^5.2.1 + `@fastify/cors` ^11, `helmet` ^13, `rate-limit` ^10.2.2, `websocket` ^11.3.1 | HTTP, CORS, cabeceras de seguridad, límite de peticiones, canal en vivo |
| `zod` ^3.24.1 + `@asteasolutions/zod-to-openapi` ^7.3.4 | Validación de entrada + generación del contrato |
| `@supabase/supabase-js` ^2.47.10 | Tres clientes: del **llamante** (con su RLS), **admin** (`service_role`) y anónimo |
| `@aws-sdk/client-s3` + `s3-request-presigner` ^3.1131.0 | Cloudflare R2 con URLs prefirmadas |
| `pdf-lib` ^1.17.1 | Planilla oficial en PDF (sobreimprime la plantilla institucional) |
| `write-excel-file` ^4.1.1 | Planilla Excel editable |
| `ws` ^8.21.3 | Servidor WebSocket del canal de asistencia |
| `vitest` ^3.0.2, `eslint` ^9, `tsx`, `typescript-eslint` | Pruebas, lint, ejecución en desarrollo |

**Arquitectura del backend (puertos y adaptadores):**

```
src/server.ts        → único punto que lee process.env
src/app.ts           → construye la app con todo inyectado (deps)
src/config/env.ts    → configuración validada con Zod al arrancar
src/dominio/         → tipos, errores y PUERTOS (interfaces)
src/infra/           → adaptadores: clientes Supabase, traducción de errores,
                       caché TTL, repositorios concretos
src/http/            → plugins (autenticación, módulos, errores), esquemas Zod,
                       rutas registradas en Fastify
```

**Reglas de la autorización en la API:**

- `exigirSesion()` y `exigirAdmin()` resuelven la identidad del llamante; las
  guardias de módulo `exigirModulo()` van **después** (el orden decide que una
  petición anónima reciba **401**, no 403/404).
- El backend habla con Supabase con **el cliente del llamante** cuando la
  operación debe respetar su RLS, y con `service_role` sólo donde la RLS no
  alcanza (p. ej. emitir códigos de recuperación: la tabla `password_resets`
  **sólo concede SELECT a `authenticated`** por diseño).
- La caché de módulos tiene TTL: apagar un módulo surte efecto «dentro del TTL».

**Contrato de error (uniforme en todo el sistema):**

```json
{ "error": { "codigo": "MODULO_DESHABILITADO", "mensaje": "…", "detalles": { "contexto": "…" } } }
```

El cliente sólo lee `error.codigo`; `mensaje` es para el usuario y `detalles`
para el log. Catálogo completo de códigos (401/403/404/409/410/413/429/500/503)
en `ESTADO_DEL_SISTEMA.md` §4.

## 4. Base de datos — Supabase (PostgreSQL 17.6)

**Decisiones que la definen (ADRs 002/003/006):**

- La **autenticación** vive en Supabase Auth; la **lógica de negocio** en la API
  Node (ADR-002).
- **La frontera de autorización es la RLS, no la API** (ADR-003). El admin y el
  catálogo leen por PostgREST directo, sin pasar por Fastify. Saltarse la app y
  hablarle a PostgREST da el mismo rechazo.
- **PostgreSQL, no MongoDB** (ADR-006). Se evaluó migrar a MongoDB y se canceló:
  PostgreSQL ya estaba montado, tiene RLS probado y su free tier cubre el
  volumen del CFS.

**Lo que vive en la base y no en la API (a propósito):** las invariantes que la
API no puede garantizar porque sólo ve una parte de los caminos (editor SQL,
migraciones, carreras concurrentes):

- `handle_new_user()` — alta atómica de `profiles` + `aspirantes` (ADR-007).
- `proteger_ultimo_admin()` (D8) — no se puede degradar/desactivar/borrar al
  último admin activo (con bloqueo de transacción para la carrera).
- `proteger_modulo_critico()` — `m0_cpanel` no se apaga ni se borra.
- `exigir_agenda_libre()` + envoltorios `security definer` — anti-colisión de
  aula y docente (M3), que **traduce** la API a `409 CHOQUE_DE_AGENDA`
  reusando el mensaje del propio trigger.
- Las dos reglas de M2 (pensum obligatorio, pensum en uso) y el motor de cupos
  de M4 (cola FIFO, ofertas con vencimiento, anti-acaparamiento).
- La validación de la planilla contra el catálogo `inscripcion_campos`
  (también cuando se escribe por PostgREST, no sólo en el `signUp`).

**Conexión:** la conexión directa a Postgres es **sólo IPv6**, así que
`supabase db push` no funciona desde una red IPv4. La vía que sí funciona es
`supabase/apply-migrations.mjs` (API de administración por HTTPS, con libro
mayor de checksums SHA-256). Detalle en `05_CICLO_DE_VIDA.md`.

**Parámetros operativos** (`system_settings`, editables desde el cPanel sin
desplegar): `inscripciones_abiertas`, `periodo_activo` (= `"SA26-2"`),
`modo_mantenimiento`, `max_faltas_consecutivas`, `bid_ttl_horas` (24),
`enrollment_lock_days` (2), `habilitar_sistema_bids` (**false** a propósito),
`cupo_maximo_por_seccion` (25), `r2_presign_ttl_minutos` (15), `m5_max_bytes`
(10 MB), `m5_max_archivos_por_entidad` (10).

## 5. Almacenamiento — Cloudflare R2

**Regla de oro (ADR-004):** los archivos **sólo** viven en R2; la base guarda
únicamente la metadata (`r2_key`). Las URLs son **prefirmadas con TTL de 15
minutos** (`r2_presign_ttl_minutos`).

- **La clave del objeto la construye el servidor** (UUID + extensión del nombre
  original): si el cliente eligiera la clave, una URL prefirmada de subida
  permitiría sobrescribir cualquier objeto del bucket.
- El ciclo es de tres pasos: **firmar → `PUT` directo a R2 → confirmar**. Una
  URL `PUT` prefirmada **no puede** imponer tamaño máximo: por eso el ciclo
  crea la fila `PENDING` antes de que el objeto exista, el límite se comprueba
  con el `HeadObject` posterior (413 si se excede) y existe un **barrido** de
  subidas abandonadas (D9).
- R2 exige `region: 'auto'` y `forcePathStyle: true`; el SDK de S3 firma sólo
  `host` por defecto, así que hay que firmar también `content-type`
  (`signableHeaders`).
- El bucket necesita política **CORS** (D16, resuelta): `application/pdf` no es
  tipo seguro para CORS, el navegador obliga a un preflight y sin política R2
  responde 403 sin cabeceras. **Desde Node el `PUT` da 200 igual**: el único
  juez es el preflight (`probe-r2-cors.mts`).

## 6. CI/CD y producción

| Workflow | Qué hace | Cuándo |
|---|---|---|
| `flutter_ci.yml` | `flutter analyze` + `flutter test`, publica el fallo como anotación legible | push/PR a `main` |
| `backend_ci.yml` | `npm run verify` (tipos + lint + pruebas). **Sin secretos**: las pruebas son herméticas | push/PR si cambia `backend/` |
| `supabase_ci.yml` | Valida **todas** las migraciones contra PostgreSQL real (PGlite) | push/PR si cambia `supabase/` |
| `e2e.yml` | Compila el frontend, levanta backend, corre Playwright contra Chromium real; **falla a propósito si faltan secretos** | noche (06:00 UTC), push que toque `e2e/`, `lib/`, `backend/`, `supabase/`, `pubspec.*` |
| `web_bundle.yml` | Compila el bundle **de producción** y valida el artefacto antes de publicarlo | manual (`workflow_dispatch`) |
| `limpiar-pendientes.yml` | El reloj de D9: barre subidas abandonadas en R2 (borra de verdad en la corrida programada) | diario 07:17 UTC |

**Arquitectura dual Cloud/Local (ADR-009):** el mismo artefacto corre en la
nube y en local vía variables de entorno + `docker-compose.yml` (backend
`3001`, frontend `8090` en desarrollo). El backend carga el `.env` con
`--env-file-if-exists` (flag nativo de Node 22, sin `dotenv`), tolerando su
ausencia dentro del contenedor.
