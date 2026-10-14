# 07 — Mapa del repositorio y comandos

## 1. Mapa de carpetas

```
/                          (raíz)
├─ lib/                    Frontend Flutter
│  ├─ main.dart            AuthGate: "/" = portada (sin sesión) o dashboard (con sesión)
│  ├─ screens/             Pantallas; admin/ (18 paneles del cPanel), docente/, aspirante/
│  ├─ providers/           Sesión/rol (role_provider) y tema (tema_provider)
│  ├─ services/            Orquestación (auth, asistencia, aula, archivos, …)
│  ├─ repositories/        Capa de datos → Result<T> (nunca null como error)
│  ├─ core/gateways/       PUERTOS: Supabase, backend, R2, selector de archivos, tema
│  ├─ core/                Result, AppException, config, reglas puras (cuadrante, currículo)
│  ├─ models/              Modelos de dominio puros
│  └─ theme/               IncesTheme: única fuente de color y tipografía
├─ test/                   Pruebas Flutter (widget + unitarias; ~72 archivos)
├─ backend/
│  ├─ src/server.ts        Único punto que lee process.env
│  ├─ src/app.ts           Construye la app con todo inyectado (deps)
│  ├─ src/config/env.ts    Config validada con Zod al arrancar
│  ├─ src/dominio/         Tipos, errores y puertos (interfaces)
│  ├─ src/infra/           Adaptadores Supabase, R2, caché TTL, traducción de errores
│  ├─ src/http/            plugins (auth, módulos, errores), esquemas Zod, rutas/
│  ├─ test/                Pruebas vitest (32 archivos) + arnés con dobles en memoria
│  ├─ scripts/             limpiar-pendientes.mts (barrido R2), probe-r2-*.mts
│  ├─ openapi.json         Artefacto del contrato (generado por npm run openapi)
│  └─ Dockerfile           Imagen de producción (Render)
├─ supabase/
│  ├─ migrations/          46 migraciones YYYYMMDDNNN_*.sql (nunca editar una aplicada)
│  ├─ tests/               Validador PGlite: validate.mjs + vectores + medir-conteos
│  ├─ apply-migrations.mjs Libro mayor (checksum SHA-256): --check / aplicar
│  ├─ verificar-esquema.mjs  Comprueba el esquema DESPLEGADO (sólo lectura)
│  ├─ contar-catalogo.mjs  Recuento del catálogo en la nube
│  ├─ sembrar-datos.mjs    Semilla idempotente (--confirmar / --limpiar)
│  ├─ humo-*.mjs           Humos contra la infraestructura real (crean y purgan)
│  └─ crear-admin.mjs / eliminar-cuenta.mjs / limpiar-ciclo-aula.mjs
├─ e2e/                    Playwright + TypeScript
│  ├─ playwright.config.ts (con la GUARDIA del bundle plantilla → falla con la causa)
│  ├─ src/                 Page Objects y helpers del DOM de Flutter
│  └─ tests/               admin_cpanel_p0, export_csv, aula_virtual(+_ciclo),
│                          stepper_inscripcion, performance_baseline
├─ .github/workflows/      flutter_ci, backend_ci, supabase_ci, e2e,
│                          web_bundle (producción), limpiar-pendientes (cron D9)
├─ devops/                 analizar-dart.mjs (verificador de tipos local),
│                          pipeline de contexto (devops/out/, gitignored)
├─ docs/                   Documentación viva; **docs/contexto-ia/ = este paquete**
├─ render.yaml             Blueprint de Render (backend Docker, /salud)
├─ docker-compose.yml      Arquitectura dual local
└─ ESTADO_DEL_SISTEMA.md   EL documento que manda cuando hay contradicción
```

**Archivos que NUNCA se commitean** (están en `.gitignore`): `backend/.env`,
`.env.json` (raíz, para Flutter), `build/`, `devops/out/`, `e2e/informe/`,
`.wrangler/`. Las plantillas son `backend/.env.example` y
`dart-define.example.json` (**una por componente**; no crear más).

## 2. Comandos de verificación (los que hay que saber de memoria)

### Frontend

```bash
# Tipos + lints locales (incluye infos; no necesita que arranque el VM)
node devops/analizar-dart.mjs

# Suite completa (si el entorno local lo permite; si no → CI)
flutter test

# Compilar (config en tiempo de compilación: --dart-define-from-file)
flutter build web --release --dart-define-from-file=.env.json
```

### Backend

```bash
cd backend
npm ci                 # instala exactamente el lockfile
npm run verify         # typecheck + lint + test  ← la puerta diaria
npm run build          # compila
npm run openapi        # regenera el contrato (si la prueba del artefacto falla)
```

### SQL

```bash
cd supabase/tests && npm install && npm test    # PGlite: migraciones + RLS + triggers
```

### Contra la nube (sólo lectura los dos primeros; el token vive en backend/.env)

```bash
TOKEN="$(sed -n 's/^SUPABASE_ACCESS_TOKEN=//p' backend/.env | tr -d '\r')"
SUPABASE_ACCESS_TOKEN="$TOKEN" node supabase/apply-migrations.mjs --check   # 0 pendientes / 0 deriva
SUPABASE_ACCESS_TOKEN="$TOKEN" node supabase/verificar-esquema.mjs          # esquema desplegado
SUPABASE_ACCESS_TOKEN="$TOKEN" node supabase/contar-catalogo.mjs            # recuento vigente
```

### Humos (escriben en la nube y purgan; usar `--confirmar`)

```bash
node backend/test-humo.mjs                        # API real → Supabase real
node supabase/humo-invitaciones.mjs --confirmar   # ciclo de invitación (34 aserciones)
node supabase/humo-recuperacion.mjs --confirmar   # recuperación interna (27 aserciones)
node supabase/humo-cuadrante.mjs --confirmar      # triggers anti-colisión de M3
node supabase/humo-archivos.mjs --confirmar       # ciclo R2 real
```

### E2E

```bash
cd e2e
CI=true E2E_ARRANCAR_BACKEND=0 E2E_WEB_DIR=../build/web npx playwright test
# el ciclo que MUTA datos (crea/publica tareas) se corre aparte y con limpieza:
E2E_PERMITIR_CICLO_MUTANTE=1 E2E_WEB_DIR=../build/web npx playwright test tests/aula_virtual_ciclo.spec.ts
node supabase/limpiar-ciclo-aula.mjs --confirmar --desde "<ISO de la corrida>"
```

### Semilla y mantenimiento

```bash
node supabase/sembrar-datos.mjs --confirmar          # siembra (idempotente)
node supabase/sembrar-datos.mjs --limpiar --confirmar # deshace por marcador
npx tsx backend/scripts/limpiar-pendientes.mts        # simulación; --confirmar borra
npx tsx backend/scripts/probe-r2-cors.mts             # exit 0 = CORS del bucket ok
```

## 3. Configuración y secretos (nombres, nunca valores)

| Variable | Dónde | Para qué |
|---|---|---|
| `SUPABASE_URL` / `SUPABASE_ANON_KEY` | `backend/.env`, `.env.json` (raíz), secretos de GitHub | Cliente público de Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | `backend/.env` + Render + GitHub | Backend: caminos donde la RLS no alcanza. **Se deja vacía cuando falta** (un marcador de texto pasaría Zod y fallaría más tarde y peor) |
| `SUPABASE_ACCESS_TOKEN` (sbp_) | `backend/.env` | Management API: migraciones, esquema, catálogo. **Nunca al repo ni a la línea de órdenes** |
| `CORS_ORIGINS` | `backend/.env` + Render | Origen del frontend (`https://inces-lms.pages.dev` + locales: `localhost:8090` **e** `127.0.0.1:8090` —para el navegador son orígenes distintos—) |
| `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` / `R2_BUCKET` / `CLOUDFLARE_ACCOUNT_ID` | `backend/.env` + Render + GitHub | Almacenamiento R2 |
| `E2E_*` (6: URL, ANON_KEY, SERVICE_ROLE_KEY, ADMIN_EMAIL, ADMIN_PASSWORD, SECCION) + `E2E_ALUMNO_*`, `E2E_DOCENTE_*` | secretos de GitHub | Suite E2E. **La suite falla a propósito si faltan**: un verde con pruebas saltadas sería peor que un rojo |
| `SUPABASE_JWT_SECRET` | **ausente** (del propietario) | Verificación local del JWT (evitaría el viaje a GoTrue) |

## 4. Dónde está cada verdad

| Pregunta | Dónde mirar |
|---|---|
| ¿Está esto construido? ¿Con qué pruebas? | `ESTADO_DEL_SISTEMA.md` §5–§7 |
| ¿Qué deuda hay y su número? | `08_GLOSARIO.md` y `ESTADO_DEL_SISTEMA.md` §6 |
| ¿Cómo se despliega? | `docs/PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md` |
| ¿Qué decide cada ADR? | `docs/PLAN_MAESTRO_STACK_DEFINITIVO.md` y `03_STACK_TECNOLOGICO.md` |
| ¿Qué trampas hay al tocar X? | `.workbuddy-ai/memory/temas/` (por tema: api-backend, interfaz, e2e, infraestructura, modulo2..7) |
| ¿Por qué esta regla existe? | `.workbuddy-ai/memory/temas/lecciones.md` y `06_REGLAS_Y_LECCIONES.md` |
| ¿Qué pasó el día D? | `.workbuddy-ai/memory/YYYY-MM-DD.md` (logs diarios, append-only) |
