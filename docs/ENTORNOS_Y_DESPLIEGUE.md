# Entornos y despliegue — fuente única

> **Este documento manda sobre cualquier otro cuando se hable de dónde vive cada
> pieza.** Creado el 2026-11-18 para cerrar la contradicción Render/Vercel que
> llegó a estar viva en cinco archivos a la vez. Si algo lo contradice —un
> workflow, un `.md` antiguo, una variable en un panel—, está mal el otro.
>
> Regla del proyecto: **manda el código y la configuración real** (nivel 1 de
> `ESTRUCTURA_DOCUMENTAL.md`). Lo que hay aquí se comprobó contra workflows,
> `backend/vercel.json`, `functions/` y una petición real desde la web publicada
> el 2026-11-18: `GET https://inces-lms-api.vercel.app/api/v1/admin/periodos`
> responde como API propia, así que **esa** es la API que usa producción.

---

## 1. Los dos entornos

| | **Local (desarrollo)** | **Producción** |
|---|---|---|
| Frontend | `flutter run -d chrome --web-port=8090` | **Cloudflare Pages** · https://inces-lms.pages.dev |
| API | Fastify en `http://localhost:3001` | **Vercel Hobby** · https://inces-lms-api.vercel.app |
| Base de datos | **Supabase en la nube** (no hay Postgres local) | Supabase, proyecto `twdppwnxlnmxkiejbrei` |
| Archivos | Cloudflare R2 (mismo bucket) | Cloudflare R2, bucket `inces-lms-media` |
| Correo | Gmail SMTP o Supabase Auth | Gmail SMTP o Supabase Auth |
| Coste | 0 | **0** |

**No hay entorno de staging.** Se prueba en local contra la base de la nube y se
publica después. Por eso el orden de despliegue importa (§4).

## 2. Por qué este stack y qué se retiró

Todo el sistema corre en capas gratuitas, sin tarjeta y sin techo de horas:

| Pieza | Plan | Límite que hay que conocer |
|---|---|---|
| Cloudflare Pages | Free | 500 builds/mes; ancho de banda y peticiones ilimitados para estáticos |
| **Vercel Hobby** | Free | 100 GB-h de función/mes, 1 M invocaciones; **solo uso no comercial**; sin WebSocket persistente |
| Supabase | Free | 500 MB de base, 50 k usuarios activos/mes; el proyecto **se pausa tras 7 días sin actividad** |
| Cloudflare R2 | Free | 10 GB almacenados, sin coste de egreso |
| GitHub Actions | Free | 2.000 min/mes en repos privados, ilimitado en públicos |

**Retirado el 2026-10-31: Render.** Su plan free da 750 h/mes por workspace (un
mes son 744 h) y **suspende** el servicio al agotarlas —medido con `503` y
`x-render-routing: suspend`—. Cloud Run y Fly se descartaron porque exigen
tarjeta. Consecuencias aceptadas de Vercel:

- **WebSocket de asistencia** (`/api/v1/asistencia/rt`) no mantiene el canal: la
  pantalla del docente cae al GET plano y la asistencia sigue por REST.
- **`@fastify/rate-limit`** cuenta por instancia; el límite efectivo es más alto.
- **Cachés de módulos y parámetros** viven por instancia y son de vida corta.

El blueprint de Render quedó archivado en `docs/historial/configuracion/render.yaml`.
Las Pages Functions de `functions/` siguen en el repositorio, corregidas a Vercel,
pero **no se despliegan** (la publicación es subida directa de `build/web`).

## 3. Variables de entorno

### 3.1 Frontend — se resuelven **al compilar**

Flutter no lee `.env` en ejecución: `String.fromEnvironment()` se congela dentro
del bundle. Se inyectan con `--dart-define-from-file=.env.json`.

| Variable | Dónde se define | Valor en producción |
|---|---|---|
| `SUPABASE_URL` | `.env.json` local / secretos de GitHub | proyecto de Supabase |
| `SUPABASE_ANON_KEY` | íd. | clave **publicable** (no es secreto) |
| `API_BASE_URL` | íd. + `--dart-define` en CI | `https://inces-lms-api.vercel.app` |

Un bundle compilado sin estas variables arranca y falla en cada llamada; por eso
`playwright.config.ts` aborta si detecta los marcadores de la plantilla.

### 3.2 Backend — se validan al arrancar (`backend/src/config/env.ts`)

| Grupo | Variables |
|---|---|
| Supabase | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` |
| Proceso | `NODE_ENV`, `PORT` (Vercel lo pone), `HOST`, `LOG_LEVEL` |
| CORS | `CORS_ORIGINS` (en producción: `https://inces-lms.pages.dev`) |
| Cachés/límites | `MODULE_CACHE_TTL_MS`, `SETTINGS_CACHE_TTL_MS`, `RATE_LIMIT_MAX`, `RATE_LIMIT_WINDOW` |
| Enlaces | `FRONTEND_URL` |
| Correo | `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM` |
| R2 | `CLOUDFLARE_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`, `R2_PUT_TTL_SEGUNDOS`, `R2_GET_TTL_SEGUNDOS` |

**R2 es «las cuatro o ninguna»**: con credenciales a medias el proceso **no
arranca**, a propósito (`configuracionR2()`). Sin ninguna, el módulo de archivos
responde 503 y el resto funciona.

### 3.3 Herramientas (no son de ejecución)

| Variable | Para qué | Dónde vive |
|---|---|---|
| `SUPABASE_ACCESS_TOKEN` (`sbp_…`) | migraciones, verificación de esquema | `backend/.env`, nunca al repo |
| `CLOUDFLARE_API_TOKEN` | publicar en Pages | `backend/.env`, nunca al repo |
| `SEMILLA_PASSWORD` | fijar la clave de los datos de siembra | entorno del operador |
| `E2E_*` | suite Playwright | `e2e/.env.e2e` (ignorado) |

Ninguna de estas tres primeras debe cargarse en Vercel: son de despliegue.

## 4. Orden de despliegue (importa)

1. **Base de datos** — solo si hay migraciones nuevas y **con autorización**:
   `node supabase/apply-migrations.mjs --check` y luego, revisado el SQL, sin
   `--check`. Las migraciones no se aplican solas desde CI.
2. **Backend → Vercel.** Una ruta nueva debe existir antes de que la web la
   llame; si el frente sale primero, la llamada da 404 y el panel cae a su
   respaldo (no se rompe, pero la función nueva no se ve).
3. **Frontend → Cloudflare Pages**, con `API_BASE_URL` apuntando a Vercel.
4. **Verificar** (§5) y registrar evidencia.

## 5. Verificación mínima después de publicar

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://inces-lms-api.vercel.app/salud
curl -s https://inces-lms-api.vercel.app/salud/profundo
curl -s -o /dev/null -w '%{http_code}\n' https://inces-lms.pages.dev/
```

Y en el bundle publicado (**tiene** que contener la API de Vercel y **no**
`localhost` ni `onrender.com`):

```bash
curl -s https://inces-lms.pages.dev/main.dart.js | grep -c 'inces-lms-api.vercel.app'
curl -s https://inces-lms.pages.dev/main.dart.js | grep -c 'onrender.com'   # debe dar 0
```

Prueba funcional mínima: entrar con las tres cuentas y recorrer el menú. La
suite `e2e/` lo automatiza; la medición del 2026-11-18 dio **16/16 admin, 5/5
docente, 8/8 estudiante**.

## 6. Cómo se despliega cada pieza

### Backend (Vercel)

El proyecto se despliega con el CLI **desde `backend/`**, no por Git: el vínculo
de Git se quitó a propósito porque `rootDirectory` no se podía fijar sin romper
el CLI (ver §7 quater del procedimiento).

```bash
cd backend
npm run build          # tsc → dist/
npx vercel --prod      # requiere sesión; los secretos viven en el panel
```

`backend/vercel.json` enruta todo a `api/index.js`, que monta Fastify sobre
`dist/`. Las variables se cargan en el panel (Settings → Environment Variables).

### Frontend (Cloudflare Pages)

```bash
flutter build web --release --no-wasm-dry-run \
  --dart-define-from-file=.env.json \
  --dart-define=API_BASE_URL=https://inces-lms-api.vercel.app
node devops/desplegar-pages.mjs build/web     # valida y publica
```

`devops/desplegar-pages.mjs` comprueba los cinco archivos del artefacto, que la
API de producción esté dentro y que no haya `localhost`; si algo falla, **no
publica**.

## 7. Reglas para quien venga después

1. **Un solo host de API.** Si aparece otro (`onrender.com`, una IP, un túnel),
   es deuda: corregirlo en el mismo cambio.
2. **No inventar variables.** Si una variable no está en §3, no existe; el
   arranque falla nombrando la que falta, y eso es correcto.
3. **No publicar un bundle sin validar.** `devops/desplegar-pages.mjs` y el
   workflow `web_bundle.yml` ya lo hacen: úsalos, no subas `build/web` a mano.
4. **No aplicar migraciones sin autorización.** Se revisan, se corren con
   `--check` y se documenta el resultado.
5. **No mover `render.yaml` de vuelta** salvo decisión explícita del propietario.
6. **Actualizar este archivo** el mismo día que cambie un host, un plan o una
   variable. Es la fuente única; los demás documentos enlazan aquí.

---

Última revisión: **2026-11-18**. Cambio: consolidación Render → Vercel y
verificación de que producción llama a `inces-lms-api.vercel.app`.
