# Procedimiento oficial de despliegue a producción — INCES LMS

> Guía operativa para que otro agente compile, publique y verifique INCES LMS en GitHub, GitHub Actions, Cloudflare Pages, Render y Supabase. Un push no equivale a un despliegue exitoso.

## 1. Inventario de producción

| Componente | Configuración |
|---|---|
| Repositorio | https://github.com/Burmistrov4/inces-lms |
| Rama de producción | main |
| Frontend Flutter Web | Cloudflare Pages, proyecto inces-lms |
| Frontend público | https://inces-lms.pages.dev |
| Backend | Render, servicio inces-lms-api |
| Backend público | https://inces-lms-api.onrender.com |
| Health check | https://inces-lms-api.onrender.com/salud |
| Base de datos | Supabase PostgreSQL |
| Configuración Render | render.yaml en la raíz |

El frontend debe usar la API https://inces-lms-api.onrender.com. No publiques un bundle que use localhost, una IP LAN o un servidor de desarrollo.

### 1.1 Workflows reales (`/.github/workflows/`)

Siete archivos, verificados uno por uno el 2026-10-13. **Ninguno de ellos publica en Cloudflare Pages ni en Render por sí solo**: los que disparan con `push` construyen y prueban; el despliegue del frontend es la §6 y el del backend lo decide Render.

| Workflow | Disparo | Función real | ¿Despliega? |
|---|---|---|---|
| `backend_ci.yml` (Backend CI) | push · pull_request · manual | typecheck + lint + tests del backend (`npm run verify`) | No |
| `flutter_ci.yml` (Flutter CI) | push · pull_request · manual | `flutter pub get`, `flutter analyze` y la suite de `flutter test`: el analizador real que el sandbox de Windows no puede ejecutar | No |
| `e2e.yml` (E2E Playwright) | push a `main` (rutas `e2e/**`, `lib/**`) · cron diario `0 6 * * *` · manual | Compila el bundle web y corre Playwright contra él, con backend vivo | No |
| `supabase_ci.yml` (Supabase CI) | push · pull_request | Valida las migraciones contra PostgreSQL real; **no las aplica** a producción | No |
| `limpiar-pendientes.yml` | cron `07:17 UTC` (03:17 Venezuela) · manual | Reloj del barrido de subidas abandonadas de M5 (D9) | No |
| `web_bundle.yml` (Web bundle de producción) | **manual** (`workflow_dispatch`) | Compila el bundle con la API de producción, lo valida (§5.1) y sube el artefacto `web-produccion` | **No**: sólo produce el artefacto |
| `android_bundle.yml` (APK Android) | **manual** (`workflow_dispatch`) | Compila APK y AAB en `ubuntu-latest` porque el equipo local no puede (JRE 8 y `ERROR_PIPE_BUSY`) | No: sube artefactos `inces-lms-apk` / `inces-lms-aab` |

Dos advertencias que evitan un falso positivo:

- **`web_bundle.yml` no publica.** Su último paso es `actions/upload-artifact` con el nombre `web-produccion`. Publicar en Cloudflare es la §6, a mano.
- **El APK de `android_bundle.yml` está firmado con la clave de depuración** (`signingConfig = debug` en `android/app/build.gradle.kts`). Sirve para instalar y probar en dispositivos del centro; **no** para Google Play, que exige la clave de distribución real del propietario (pendiente, `docs/AI_AGENT_PROTOCOLO.md`).

## 2. Reglas no negociables

1. Confirma que estás en el repositorio correcto y en la rama esperada.
2. Ejecuta git status --short --branch antes de editar, compilar, limpiar o publicar.
3. No ejecutes git reset --hard, git clean -fd ni borrados masivos. No sobrescribas cambios ajenos.
4. No incluyas .env, claves, tokens, logs, capturas ni pruebas temporales en commits.
5. Nunca imprimas secretos ni los copies a esta documentación. Usa variables de entorno o el gestor de secretos autorizado.
6. No asumas que Cloudflare, Render o Supabase se actualizaron porque el push terminó.
7. No apliques migraciones de producción sin autorización explícita, revisión del SQL y plan de recuperación.
8. No cambies secretos, CORS, dominios, infraestructura o planes sin registrar el motivo y confirmar el impacto.
9. Si hay archivos locales ajenos a la tarea, déjalos intactos y repórtalos.

## 3. Preparación y GitHub

Ejecuta en PowerShell:

    $root = 'C:\Users\Loro\Desktop\Cuarto Semestre\1. Servicio Comunitario\INCES-LMS-PROJECT'
    Set-Location $root
    git rev-parse --show-toplevel
    git branch --show-current
    git status --short --branch
    git fetch origin
    git log -1 --oneline
    git rev-parse HEAD
    git rev-parse origin/main

Confirma que la raíz corresponde a INCES LMS. Revisa diferencias locales y remotas antes de actualizar o publicar. Si hay cambios sin subir, inspecciona archivo por archivo y ejecuta las pruebas de la sección 4.

Cuando los cambios estén revisados y autorizados, agrega únicamente los archivos pertinentes:

    git add <archivos-revisados>
    git diff --cached --check
    git diff --cached --stat
    git diff --cached
    git commit -m "descripción breve del cambio"
    git push origin main
    git fetch origin
    git status --short --branch
    git rev-parse HEAD
    git rev-parse origin/main

No uses git add -A sin revisar el estado: podría incorporar archivos temporales. HEAD y origin/main deben coincidir para confirmar que el commit está en remoto.

## 4. Pruebas antes de publicar

### 4.1 Backend

    Set-Location "$root\backend"
    npm ci
    npm run verify
    npm run build

npm run verify ejecuta typecheck, lint y tests. Si algo falla, investiga y corrige antes de desplegar.

### 4.2 Flutter

Desde la raíz:

    Set-Location $root
    flutter --version
    flutter pub get
    flutter test

Si se usa --no-pub, confirma que las dependencias ya están instaladas y actualizadas. Antes de terminar procesos Flutter/Dart, comprueba qué tarea ejecutan y evita builds simultáneos.

### 4.3 GitHub Actions

En https://github.com/Burmistrov4/inces-lms/actions confirma los workflows del SHA exacto que vas a publicar. Espera a que terminen: in_progress no es PASS. Inspecciona los logs de cualquier fallo. CI no es lo mismo que un workflow de despliegue.

Con GitHub CLI autenticado, opcionalmente:

    gh auth status
    gh run list --repo Burmistrov4/inces-lms --limit 15
    gh run view <RUN_ID> --repo Burmistrov4/inces-lms

## 5. Build Flutter Web para producción

Desde la raíz del proyecto:

    Set-Location $root
    $env:PROGRAMFILES_X86 = 'C:\Program Files (x86)'
    flutter build web --release --no-pub --no-wasm-dry-run --dart-define-from-file=.env.json --dart-define=API_BASE_URL=https://inces-lms-api.onrender.com
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter Web build falló con código $LASTEXITCODE"
    }

El override de API de producción debe prevalecer sobre cualquier valor local de .env.json. No cambies ese archivo local solo para compilar. Si cambian las opciones de Flutter o la configuración de entorno, inspecciona lib/core/config/app_config.dart y flutter build web --help antes de alterar el comando.

### 5.1 Validación obligatoria del artefacto

    $index = Join-Path $root 'build\web\index.html'
    $jsPath = Join-Path $root 'build\web\main.dart.js'
    $headers = Join-Path $root 'build\web\_headers'
    $robots = Join-Path $root 'build\web\robots.txt'
    $sitemap = Join-Path $root 'build\web\sitemap.xml'
    if (!(Test-Path $index))  { throw 'Falta build/web/index.html' }
    if (!(Test-Path $jsPath)) { throw 'Falta build/web/main.dart.js' }
    if (!(Test-Path $headers)) { throw 'Falta build/web/_headers' }
    if (!(Test-Path $robots)) { throw 'Falta build/web/robots.txt' }
    if (!(Test-Path $sitemap)) { throw 'Falta build/web/sitemap.xml' }
    $js = Get-Content $jsPath -Raw
    if (!$js.Contains('https://inces-lms-api.onrender.com')) {
        throw 'El bundle no contiene la API de producción'
    }
    if ($js.Contains('http://localhost:3001') -or $js.Contains('localhost:3001')) {
        throw 'El bundle contiene una API local; se cancela el despliegue'
    }
    if (!(Get-Content $robots -Raw).Contains('Sitemap: https://inces-lms.pages.dev/sitemap.xml')) {
        throw 'robots.txt no declara el sitemap'
    }
    if (!(Get-Content $sitemap -Raw).Contains('<urlset')) {
        throw 'sitemap.xml no parece un sitemap'
    }
    Get-Item $index, $jsPath, $headers, $robots, $sitemap | Select-Object FullName, Length, LastWriteTime
    Get-Content $headers

Si una comprobación falla, no publiques. Diagnostica, vuelve a compilar y repite. Comprueba también que web/_headers sea el archivo fuente esperado y que las cabeceras de seguridad/cache estén presentes.

Los cinco archivos salen de `web/` y los copia `flutter build web` a `build/web/`. `robots.txt` y `sitemap.xml` existen porque sin ellos Cloudflare Pages responde a esas rutas con el `index.html` de la SPA (medido el 2026-10-13: `200 text/html`, 2775 B) y ningún rastreador recibe instrucciones reales.

### 5.2 Vía alternativa: el artefacto de CI `web-produccion`

Si el build local está bloqueado por el entorno (`CreateFile failed 231`), el bundle se compila en `web_bundle.yml`, que ya aplica las comprobaciones de la §5.1 dentro del job:

    gh run list --repo Burmistrov4/inces-lms --workflow web_bundle.yml --limit 5
    gh run view <RUN_ID> --repo Burmistrov4/inces-lms
    gh run download <RUN_ID> --repo Burmistrov4/inces-lms --name web-produccion --dir C:/tmp/web-produccion

Antes de publicar el directorio descargado, repite a mano la §5.1 sobre `C:/tmp/web-produccion`. Un artefacto de CI es una compilación, **no** un despliegue: la §6 sigue siendo obligatoria.

## 6. Publicación en Cloudflare Pages

### 6.1 Autenticación y proyecto

Usa una sesión autenticada de Wrangler o credenciales de despliegue aprobadas. Nunca guardes tokens en el repositorio ni en esta guía.

    Set-Location $root
    npx --yes wrangler whoami
    npx --yes wrangler pages project list

Si Wrangler no está autenticado, detente y completa el inicio de sesión autorizado. Confirma que el proyecto destino se llama exactamente inces-lms.

#### 6.1.1 Token de API para despliegues no interactivos

Wrangler lee dos variables de entorno, con **nombres exactos** (no inventar otros:
si el nombre no coincide, Wrangler ignora la variable y vuelve a pedir login):

| Variable | Valor |
|---|---|
| `CLOUDFLARE_API_TOKEN` | El token de API |
| `CLOUDFLARE_ACCOUNT_ID` | El id de la cuenta (32 hex) |

**Cómo crear el token** en <https://dash.cloudflare.com/profile/api-tokens>:

- Plantilla **«Edit Cloudflare Workers»** → **no sirve**: no incluye Pages.
- Usar **Create Custom Token** con:
  - **Permissions**: `Account` → `Cloudflare Pages` → **Edit**
  - **Account Resources**: `Include` → la cuenta del centro
  - **Zone Resources**: `None` (Pages es de cuenta, no de zona)
  - Opcional, para que `wrangler whoami` muestre el nombre de la cuenta:
    `User` → `User Details` → `Read`. **No es necesario para desplegar**: sin él
    `whoami` falla pero el deploy funciona. `devops/desplegar-pages.mjs` lo trata
    como informativo por eso mismo.
- **Client IP address filtering**: dejar **vacío**. La conexión del centro es
  residencial y la IP cambia; fijarla rompería el despliegue desde otro sitio.

**La expiración: anotarla o ponerla sin caducidad.** Un token a 1 año funciona,
pero **el día que caduca los despliegues fallan sin decir por qué** —el mensaje
habla de autenticación, no de caducidad—. Si se elige con fecha, hay que anotarla
aquí:

> **Token `inces-lms pages deploy`: RENOVADO el 2026-10-26** (el anterior
> caducaba el 2026-10-25). Verificado el 2026-10-28: el token figura **Active**
> en el dashboard, `wrangler pages project list` responde y el último deploy
> a `inces-lms.pages.dev` es de hace horas. No requiere acción.

Para un proyecto que se defiende ante un jurado y sigue vivo después, «No
expiration» evita esa trampa; con fecha, el riesgo es menor si el token se filtra.

**Dónde va.** En `backend/.env`, que está cubierto por `.gitignore` y **no** se
versiona (verificado con `git check-ignore -v backend/.env`). Es una credencial
de **despliegue**, no de ejecución: el backend nunca la lee. Por eso **no debe
estar en Render** — allí no sirve para nada y amplía la superficie.

**Comprobar que quedó bien antes de publicar:**

    npx --yes wrangler whoami

Debe responder con la cuenta y el nombre del token. Si dice que no está
autenticado, el token está mal, le faltan permisos o la variable no se cargó.

### 6.2 Publicar producción

> **Sube la versión antes de publicar, siempre.** Medido el 2026-10-30: se
> publicaron tres bundles distintos con la misma etiqueta `1.7.1`, y el dueño del
> producto miró la página, vio el mismo número y concluyó —con razón— que no había
> cambiado nada. El número es la única señal que el usuario tiene desde fuera:
> `pubspec.yaml`, `AppConfig.version` y la cabecera nueva del `CHANGELOG.md` se
> mueven **juntos** antes de cada `wrangler pages deploy`, y
> `test/version_coherente_test.dart` es lo que impide que se separen.

Solo después de validar el artefacto de la sección 5:

    npx --yes wrangler pages deploy '.\build\web' --project-name=inces-lms --branch=main
    if ($LASTEXITCODE -ne 0) {
        throw "Cloudflare Pages deploy falló con código $LASTEXITCODE"
    }

Guarda el URL, identificador, rama, entorno y resultado que devuelve Wrangler. Luego consulta el historial:

    npx --yes wrangler pages deployment list --project-name=inces-lms

Confirma que la nueva publicación figura como Production en main. Un URL de preview no demuestra que el dominio principal esté actualizado.

**Wrangler no está fijado en este repositorio.** Los comandos usan `npx --yes wrangler`, que resuelve la última versión publicada en el momento de ejecutarse: el comportamiento puede cambiar entre dos despliegues sin que cambie el repositorio. La versión con la que se redactó esta sección es la 4.151.0 (comprobada el 2026-10-14). Si una GUI o un script necesita reproducibilidad, fija la versión (`npx --yes wrangler@4.151.0 …`) o declárala como dependencia de desarrollo.

## 7. Render: backend

> **Aviso medido el 2026-10-30/31.** El plan gratuito de Render da **750 horas
> de instancia al mes por workspace** (≈ un servicio siempre encendido, sin
> margen: un mes son 744 h) y **suspende** los servicios free al agotarlas. Se
> observó en producción: `503` con `x-render-routing: suspend` y el cuerpo «This
> service has been suspended». Las horas se reinician el día 1 de cada mes.
> Si vuelve a pasar, la alternativa sin cambios de código es
> `devops/desplegar-cloudrun.sh` (§7 bis).

render.yaml declara un servicio con raíz backend, Dockerfile ./Dockerfile y health check /salud. Si Render tiene auto-deploy habilitado, el push a la rama configurada puede iniciarlo; confírmalo en el Dashboard. render.yaml por sí solo no demuestra que el despliegue haya terminado.

1. Abre el Dashboard de Render y selecciona inces-lms-api.
2. Comprueba el despliegue asociado al SHA/commit esperado.
3. Espera el estado Live/Deploy succeeded y revisa logs si hay errores.
4. Comprueba que las variables secretas requeridas están configuradas, sin imprimir valores.
5. No inicies un segundo deploy si ya hay uno en curso. Antes de un redeploy, verifica commit, rama y estado.

## 7 bis. Cloud Run: la misma API, sin techo de horas

`devops/desplegar-cloudrun.sh` despliega la **misma imagen** en Google Cloud Run:
free tier real (2M peticiones, 180k vCPU-s, 360k GiB-s al mes) y
`--min-instances=0`, así que sin tráfico no consume cuota. No hay que tocar una
línea de código: el Dockerfile ya construye una API stateless que escucha en
`$PORT` y responde en `/salud`.

Requiere `gcloud` autenticado y un proyecto con facturación asociada (Cloud Run
la exige aunque no cobre dentro del free tier).

```bash
gcloud auth login
gcloud config set project TU_PROYECTO
./devops/desplegar-cloudrun.sh
```

Al terminar imprime la URL del servicio. Después:

1. Añade el dominio de la web a `CORS_ORIGINS` en `backend/.env` y vuelve a
   correr el script con `--solo-env`.
2. Recompila la web con `--dart-define=API_BASE_URL=<esa URL>` (§5) y publica.
3. **No** dejes las dos APIs vivas apuntando a la misma base sin querer: elige
   una y apaga la otra.

Las variables se envían por lista explícita, no «todas las del `.env`»: mandar de
más a un servicio público es la forma más fácil de filtrar una clave.

Prueba el endpoint:

    $health = Invoke-WebRequest -Uri 'https://inces-lms-api.onrender.com/salud' -UseBasicParsing -TimeoutSec 30
    if ([int]$health.StatusCode -ne 200) {
        throw 'Health check de Render no devolvió HTTP 200'
    }
    $health.StatusCode
    $health.Content

Prueba CORS desde el origen real del frontend:

    $cors = Invoke-WebRequest -Uri 'https://inces-lms-api.onrender.com/api/v1/admin/invitaciones' -Method Options -Headers @{
        Origin = 'https://inces-lms.pages.dev'
        'Access-Control-Request-Method' = 'GET'
        'Access-Control-Request-Headers' = 'authorization,content-type'
    } -UseBasicParsing -TimeoutSec 30
    $cors.StatusCode
    $cors.Headers['Access-Control-Allow-Origin']

El preflight debe responder con un código 2xx esperado (se ha verificado HTTP 204) y autorizar el origen exacto de producción. Health 200 no sustituye pruebas funcionales.

## 7 ter. Fly.io: siempre encendida por 3,69 $/mes

La otra cara de la moneda. Cloud Run es gratis al volumen del centro pero paga
arranque en frío; Fly **no tiene capa gratuita** para cuentas nuevas, cobra por
segundo de máquina encendida y no tiene techo de horas: `shared-cpu-1x` con
512 MB son **3,69 $/mes** a 30 días continuos.

`backend/fly.toml` ya trae `auto_stop_machines = "off"` y
`min_machines_running = 1`: la máquina no se duerme, y eso es justo lo que se
está pagando. Los 512 MB no son un lujo: la API genera **PDF de planilla y
certificados en memoria**, y con 256 MB el proceso muere en la ruta más pesada.

```bash
flyctl auth login
./devops/desplegar-fly.sh
```

Las claves van por `fly secrets` (cifradas, inyectadas como entorno), nunca en
`fly.toml`, que se versiona. Después, el mismo orden que con Cloud Run:
`CORS_ORIGINS` con el dominio de la web, y recompilar con el `--dart-define`
nuevo.

| | Cloud Run | Fly.io | Render free |
|---|---|---|---|
| Coste al volumen del centro | 0 $ | 3,69 $/mes | 0 $ |
| Techo | free tier generoso | ninguno | **750 h/mes** |
| Arranque en frío | 1–3 s | no | ~1 min tras 15 min |

## 7 quater. Vercel Hobby: la opción sin tarjeta

**Es la que se usa.** Render agota las 750 horas al mes, Cloud Run y Fly exigen
tarjeta y las disponibles son prepagadas (`OR_CCR_104`: «No se admiten tarjetas
prepagadas»). Vercel Hobby es gratis, **no pide tarjeta**, no tiene techo de
horas y no duerme el servicio.

**No hay reescritura.** `backend/src/vercel.ts` hace lo mismo que `server.ts`
—cargar el entorno, construir los clientes de Supabase y llamar a
`construirApp`— y en vez de `app.listen()` entrega cada petición al servidor
interno de Fastify con `server.emit('request')`. Las ~100 rutas, los hooks, las
guardias y la RLS quedan intactos.

```bash
cd backend
vercel link --yes --project inces-lms-api   # una vez
vercel env add <NOMBRE> production          # una por variable
vercel --prod
```

**URL de producción:** `https://inces-lms-api.vercel.app`

### La trampa que costó cinco despliegues

`vercel link` **detecta Fastify** en `package.json` y crea el proyecto con
`framework: "fastify"` y `outputDirectory: "public"` **en los ajustes del
servidor**, que mandan sobre `vercel.json`. Con ese preset el build busca un
entrypoint de servidor (`app|index|server.js`) dentro de `public/` y falla con
`No entrypoint found in output directory`, ignorando lo que diga el archivo.

Ni `"framework": "other"` ni `"framework": ""` se aceptan por `vercel.json`
(enum cerrado). La salida es limpiar los ajustes del proyecto por API:

```bash
curl -X PATCH "https://api.vercel.com/v9/projects/<projectId>?teamId=<teamId>" \
  -H "Authorization: Bearer <token>" -H "content-type: application/json" \
  -d '{"framework":null,"outputDirectory":null,"buildCommand":null,"installCommand":null}'
```

Después basta con `outputDirectory: "public"` y un `public/index.html`
cualquiera: Vercel exige un directorio de salida aunque sólo se sirvan
funciones. El `tsc` se ejecuta en `postinstall`, no en `buildCommand`.

### Sin despliegue automático de Git, a propósito

`vercel link` conectó el repo y quedó `rootDirectory: null`, así que un push a
`main` habría construido **la raíz del repo** —sin `package.json` ni `api/`— y
fallado. Corregirlo a `rootDirectory: "backend"` rompe el CLI: lanzado desde
`backend/` busca `backend/backend` y aborta, y lanzado desde la raíz del repo el
CLI intenta subir todo el proyecto y el upload se cae.

Se elige lo que está medido y funciona: **se quita el vínculo de Git** y se
despliega con `vercel --prod` desde `backend/`, que es lo que produce los tres
despliegues verdes. El costo es que un push no publica la API sola; a cambio no
hay builds rotos que confundan.

También se fijó **Node 22.x**: Vercel ponía 26.x por defecto, una versión que el
proyecto nunca corrió (`engines` declara `>=22` y Docker y Render usan 22).

**Falta `CLOUDFLARE_ACCOUNT_ID` y la API no arranca.** `crearAlmacenamiento`
exige las cuatro variables de R2 o ninguna, así que sin la cuenta de Cloudflare
el proceso muere en el arranque con `Configuración de R2 incompleta`. Se ve en
`vercel logs <url> --json`, no en el navegador: el cliente sólo recibe un 500
`ARRANQUE_FALLIDO`.

### Variables de entorno en el panel de Vercel

Las mismas que en Render, sin `PORT` ni `HOST` (Vercel los pone):

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`,
`CORS_ORIGINS` (con `https://inces-lms.pages.dev`), `FRONTEND_URL`,
`NODE_ENV=production`, y las de R2 y SMTP si se usan.

### Lo que no funciona aquí, y por qué se acepta

| Limitación | Efecto | Mitigación |
|---|---|---|
| **WebSocket** (`/api/v1/asistencia/rt`) | Una función serverless no puede quedarse abierta: el canal no se abre | La pantalla del docente ya cae al GET plano (200 con descripción) y la asistencia sigue por REST; se pierde el empujón en vivo |
| `@fastify/rate-limit` en memoria | Cada instancia cuenta por su lado: el límite real es más alto | El control de verdad es la RLS de Supabase |
| Caché de módulos/parámetros | Por instancia y corta | Sólo abarata consultas; no rompe nada |
| Arranque en frío | ~1 s en la primera petición | Aceptable; el plan Hobby no permite instancias fijas |

### Mancha que hay que mirar antes de crecer

El plan Hobby es **sólo para uso personal no comercial**. Un centro de formación
público sin ánimo de lucro encaja en el espíritu de la norma, pero si el uso
crece o alguien cobra por el proyecto, Vercel puede pedir el plan Pro
(20 $/mes por asiento). Queda escrito aquí para que la decisión no se olvide.

Medido el 2026-10-31 con un banco que imita a `@vercel/node` (cuerpo ya
parseado en `req.body` y stream consumido): `GET /salud` → 200
`{"estado":"ok"}`; `POST` con cuerpo inválido → 400 `PETICION_INVALIDA` con
`detalles` de Zod, o sea que el cuerpo **vuelve al stream** gracias al hook
`preParsing`; ruta inexistente → 404. Sin ese hook, el POST se queda colgado
hasta el timeout.

## 8. Supabase: verificación sin migrar automáticamente

La validación de migraciones en CI no las aplica automáticamente a producción.

1. Revisa el SQL nuevo, el orden, compatibilidad hacia atrás, impacto y estrategia de recuperación.
2. Confirma el proyecto Supabase correcto y el respaldo/plan de recuperación.
3. Ejecuta primero el modo de solo comprobación:

    Set-Location $root
    node .\supabase\apply-migrations.mjs --check

El script puede necesitar SUPABASE_ACCESS_TOKEN en el entorno. Cárgalo de forma segura desde el gestor de secretos o entorno autorizado. No imprimas el valor, no lo pegues en el chat ni lo añadas a una línea de comandos registrada.

Revisa proyecto/ref, migraciones detectadas, pendientes y drift. Si la autenticación falla, detente: no concluyas que no hay pendientes.

No ejecutes node .\supabase\apply-migrations.mjs sin --check en producción salvo autorización explícita para aplicar las migraciones revisadas. No marques migraciones manualmente como aplicadas para ocultar discrepancias. Tras una migración autorizada, repite --check y las pruebas de regresión.

## 9. Verificación posterior

### 9.1 Frontend público y bundle

    $base = 'https://inces-lms.pages.dev'
    $index = Invoke-WebRequest -Uri "$base/?verify=$([guid]::NewGuid().ToString('N'))" -UseBasicParsing -TimeoutSec 30
    if ([int]$index.StatusCode -ne 200) { throw 'Frontend no devuelve HTTP 200' }
    $bundle = Invoke-WebRequest -Uri "$base/main.dart.js?verify=$([guid]::NewGuid().ToString('N'))" -UseBasicParsing -TimeoutSec 60
    $js = $bundle.Content
    if (!$js.Contains('https://inces-lms-api.onrender.com')) {
        throw 'Bundle público no contiene la API esperada'
    }
    if ($js.Contains('localhost:3001')) {
        throw 'Bundle público contiene localhost'
    }
    Write-Output "Frontend HTTP: $([int]$index.StatusCode)"
    Write-Output "Bundle bytes: $($js.Length)"

Si Flutter cambia a salida WASM u otro formato, no asumas que main.dart.js sigue siendo el bundle principal. Inspecciona index.html y flutter_bootstrap.js, descarga el archivo realmente referenciado y aplica las mismas comprobaciones.

### 9.2 Validación funcional mínima en navegador real

- La página carga sin errores fatales en consola.
- Login y cierre de sesión con una cuenta de prueba autorizada.
- Las llamadas de red usan el backend de producción, nunca localhost.
- Un flujo representativo de lectura y escritura con datos de prueba autorizados.
- Una cuenta sin privilegios no puede acceder a operaciones administrativas.
- Los módulos críticos cargan; revisar 4xx/5xx, CORS y fallos de red.
- Revisar invitaciones/recuperación si forman parte del cambio.
- No uses credenciales personales reales ni borres datos reales como prueba.

E2E en CI es evidencia valiosa, pero no sustituye verificar la versión desplegada.

### 9.3 Registrar evidencia

Guarda el SHA de GitHub, enlaces/estados CI, deployment ID/URL y rama de Cloudflare, deployment ID/commit/estado de Render, respuestas HTTP, resultado de Supabase --check y pruebas funcionales. Anota claramente lo que no se pudo verificar.

## 10. Diagnóstico, rollback y recuperación

- **Build Flutter lento:** inspecciona logs, CPU/RAM y procesos Flutter/Dart; no ejecutes builds simultáneos. Detén solo un proceso obsoleto identificado y vuelve a compilar una vez.
- **Wrangler sin autenticación:** no publiques; autentica por el procedimiento autorizado y confirma cuenta/proyecto.
- **Bundle apunta a localhost:** cancela publicación, corrige configuración, recompila y vuelve a validar.
- **Render no actualiza:** revisa rama, commit, auto-deploy y logs. No cambies secretos para ocultar el error.
- **CI falla:** inspecciona el job del SHA exacto y repite CI tras corregirlo.
- **Supabase muestra drift o pendientes:** detente y presenta diagnóstico; no migres ni reviertas sin autorización.
- **Frontend y backend desincronizados:** revisa compatibilidad API y orden; prioriza cambios compatibles hacia atrás y verifica ambos servicios.
- **Deploy fallido:** conserva logs, deployment ID y SHA. Aplica el rollback de la **§10.1** sólo a una versión conocida como buena y tras revisar implicaciones.

### 10.1 Rollback y recuperación

Un rollback es un despliegue más: se ejecuta con el mismo procedimiento y se verifica igual.

**Frontend (Cloudflare Pages).** Pages conserva los despliegues anteriores, así que volver atrás es elegir uno conocido como bueno. **Advertencia medida: Wrangler no tiene comando de rollback.** El 2026-10-14 se comprobó con Wrangler 4.151.0 (`npx --yes wrangler@latest pages deployment --help`, exit 0): los únicos subcomandos son `list`, `create`, `tail` y `delete`. No existe `pages deployment rollback`, y `--project-name` tampoco es una opción de esos subcomandos. La guía anterior documentaba ese comando; **se retira porque no existe**.

*Procedimiento principal — panel de Cloudflare* (documentación oficial de [Rollbacks](https://developers.cloudflare.com/pages/configuration/rollbacks/), vigente a la fecha de esta revisión):

1. Entra al panel de Cloudflare → **Workers & Pages** → proyecto **inces-lms** → pestaña **Deployments**.
2. En **All deployments**, abre el menú de tres puntos del despliegue destino y elige **Rollback to this deployment**.
3. Confirma la ventana. El despliegue de producción cambia **al instante**.
4. Sólo los despliegues de producción construidos con éxito son objetivos válidos; **los de preview no lo son**.

Para identificar el despliegue correcto antes de tocar nada, Wrangler sí sirve para listar (comando verificado):

    npx --yes wrangler pages deployment list --project-name=inces-lms

*Alternativa — API de Cloudflare* (para quien no tenga acceso al panel). Endpoint documentado: `POST /accounts/{account_id}/pages/projects/{project_name}/deployments/{deployment_id}/rollback`. Prerrequisitos: el **account ID**, un **API token con permiso de edición de Pages** y el **deployment ID** objetivo. No guardes tokens en el repositorio ni en esta guía.

Después del rollback repite la §9.1 completa: HTTP 200 en `/`, bundle con la API de producción y **sin** `localhost:3001`, `robots.txt` como `text/plain` y `sitemap.xml` como XML. Confirma además en el panel que el despliegue activo es el que elegiste y que su commit o artefacto es el esperado.

**Backend (Render).** En el Dashboard de `inces-lms-api`, abre el despliegue anterior conocido como bueno y usa *Rollback to this deploy*. Confirma que el commit mostrado es el esperado y espera el estado Live; luego comprueba `/salud` y el preflight CORS de la §7.

**Reglas del rollback.**

1. Sólo a una versión **conocida como buena**, nunca a la anterior por descarte.
2. Antes de tocar nada, guarda el SHA, el deployment ID y los logs del despliegue que falla.
3. Si el fallo viene de la base de datos (drift, columna ausente), el rollback del código **no** lo arregla: detente, documenta y espera autorización. No reviertas migraciones por instinto.
4. Si el fallo es de esquema y ya se aplicó una migración, la recuperación es una migración nueva compatible hacia atrás, no un borrado.
5. Tras el rollback, `git status` y el diff tienen que explicar por qué el árbol quedó como quedó. Un rollback sin explicación escrita es un incidente sin cierre.

## 11. Formato obligatorio del informe final

- **GitHub:** rama, SHA y coincidencia de HEAD con origin/main.
- **CI:** estado y enlaces de los siete workflows de la §1.1 (Backend, Flutter, E2E, Supabase, limpiar-pendientes y, si se usaron, web bundle y APK Android).
- **Flutter:** comando, código de salida y verificaciones del artefacto.
- **Cloudflare:** deployment ID/URL, entorno Production y bundle público validado.
- **Render:** deployment ID/commit, estado y health check.
- **Supabase:** resultado de --check; declarar explícitamente si se aplicaron migraciones (por defecto, no).
- **Pruebas funcionales:** qué se comprobó y qué no.
- **Cambios locales excluidos:** enumerarlos sin borrarlos.
- **Riesgos/bloqueadores:** declararlos sin minimizar.

Nunca digas “todo está en producción” si solo se hizo push, si hay deployments en progreso o si no se comprobó el bundle público.

## 12. Referencias oficiales

- Repositorio: https://github.com/Burmistrov4/inces-lms
- GitHub Actions: https://github.com/Burmistrov4/inces-lms/actions
- Cloudflare Pages: https://developers.cloudflare.com/pages/
- Wrangler Pages deploy: https://developers.cloudflare.com/pages/get-started/direct-upload/
- Render deploys: https://render.com/docs/deploys
- Supabase database migrations: https://supabase.com/docs/guides/deployment/database-migrations

---

Última revisión documental: **2026-10-14 (cierre de Fase 1)**: se sustituyó el comando de rollback de Wrangler, que no existe, por el procedimiento del panel y la API (§10.1), y se documentó que Wrangler no está fijado (§6.2). Revisión anterior: **2026-10-13** (Fase 1): inventario de workflows verificado contra `.github/workflows/` (§1.1), vía del artefacto de CI (§5.2) y rollback (§10.1). Revisión anterior: 2026-10-10. Antes de cada despliegue, verifica los nombres de servicios, dominios, workflows, comandos y estado actual de cada plataforma. Actualiza esta guía si la infraestructura cambia.
