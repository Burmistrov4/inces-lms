# 01 — COMPLETADO (lo ya hecho y verificado)

> Consolidado de `ESTADO_DEL_SISTEMA.md` (tabla de completado, líneas 650–682),
> `docs/BACKLOG_PENDIENTES.md` (secciones cerradas) y la memoria del proyecto.
> **Cifras medidas, no deducidas.** Última sincronización: 2026-10-29.

## Fases del proyecto

| Fase | Alcance | Estado |
|---|---|---|
| Fase 0 | Esquema base, RLS, roles, migraciones versionadas | ✅ Completa |
| Fase 1 | Auth y onboarding atómico de aspirantes | ✅ Completa |
| Fase 2 | API stateless Node/TypeScript (Fastify) + Docker | ✅ Completa |
| Fase 3 | Núcleo del Administrador Maestro (cPanel) | ✅ Completa |
| Rediseño secciones (fase 3 del `PLAN_SIMPLIFICACION_SECCIONES`) | Unificar «Cursos y PNA» + «Inscripciones y Cupos» en un módulo | ✅ **CERRADA 2026-10-29** |

## Módulos (backend + frontend + esquema)

| Módulo | Estado | Nota |
|---|---|---|
| Módulo 1 — Invitación de docentes por token + `auth_logs` | ✅ Completo | Flujo interno, sin depender de correo externo |
| Módulo 2 — Currículo y Pensum | ✅ Completo | 7 rutas + asistente Flutter de 3 pasos |
| Módulo 3 — Cuadrante, Horarios, Aulas y Guardias | ✅ Completo | 4 tablas, 2 triggers anti-colisión, 3 vistas, 14 rutas, rejilla `CuadranteGrid` responsive |
| Módulo 4 — Inscripciones y cupos | ✅ Completo | Cola FIFO, ofertas con vencimiento, anti-acaparamiento, frontera de escritura por RPC. **Panel unificado en `CpanelProgramasPanel`** (el antiguo `cpanel_inscripciones_panel.dart` de 795 líneas **borrado** 2026-10-29) |
| Módulo 5 — Archivos en R2 | ✅ Completo | `files_metadata`, 3 RPC, `PuertaAlmacenamiento` S3, gestor documental (Capa 7) con 19 pruebas de widget |
| Módulo 6 — Aula Virtual | ✅ Completo | Tablón, trabajo, entregas, calificar, devolver, libro; Centro de Mando del Docente; bandera `m6_aula_virtual` ENCENDIDA |
| Módulo 7 — Asistencia QR | ✅ Completo (backend + frontend) | 4 rutas REST + WebSocket; `asistencia_qr_panel` + `marcar_asistencia_panel`. **Falta** recorrer el ciclo en un navegador real / cámara física |
| Módulo 8 — Pasantías | ⏳ **PENDIENTE** | Registro técnico OFF; NO habilitar hasta completar el flujo (ver `02_PENDIENTES_Y_ERRORES.md`) |

## Infraestructura, CI y producción (2026-10-29)

- **Backend (Fastify/TS):** 34 suites · **728/728** (`cd backend && npm run verify`).
- **Frontend (Flutter):** **1061/1061** pruebas (`flutter test`, medido en CI).
- **Analizador propio:** 249 archivos · 0 errores/avisos/infos (`node devops/analizar-dart.mjs`).
- **Migraciones:** **62 aplicadas · 0 pendientes · 0 deriva** (`apply-migrations.mjs --check`).
- **CI del push:** Flutter CI ✅ · Backend CI ✅ · Supabase CI ✅.
- **Frontend desplegado:** `wrangler pages deploy` → `inces-lms.pages.dev` (HTTP 200, bundle con API de producción, cero `localhost`).
- **Backend:** `GET https://inces-lms-api.onrender.com/salud` → 200 `{"estado":"ok"}`.
- **OpenAPI 3.1** generado desde Zod; contrato cubierto por `openapi.test.ts` (D6).
- **`cleanstack-ci.yml`** (workflow vacío de 0 bytes que fallaba en cada push) **borrado 2026-10-29**.

## Rendimiento (ya aplicado)

- Hook de auth paraleliza sus dos viajes; `count`+página en paralelo.
- **Esqueletos de carga** (`EsqueletoLista`) en vez de spinner (Fase A.1).
- **Caché por sección + refresco en segundo plano** (`RefrescoAlVolver`, Fase A.2).
- **Caché compartida de lecturas** (`CacheLecturas` + single-flight): `mi-horario`
  pasó de 56→3 peticiones por corrida (Fase M).

## Responsive (línea base histórica)

- Matriz E2E: 192 capturas · **0 desbordes** · 0 page errors · 4/4 roles.
- `CuadranteGrid` responsive (<1200 selector de día + lista; ≥1200 tabla adaptativa).
- Menú: rail en 840–1199, permanente en ≥1200 (`andamiaje.dart`).
- Gestor de archivos, Guardias, buscador, formularios acotados — cerrados.
- **Deuda abierta:** 15/143 archivos de `lib/` aún usan `LayoutBuilder` (ver `02`).

## Seguridad

- RLS ejercida (no solo leída): M4, M5, M7 verificados con sondas en vivo.
- Auditoría independiente 2026-10-25: oráculo de búsqueda `ilike` corregido
  (`porIdentificador` escapa `%`/`_`), `catch(_){}` vacío eliminado en
  `UsuariosAdminRepository`.
- Login con cédula (RPC `email_por_cedula`, `security definer`, oración de
  existencia aprobada por Lorenzo el 2026-10-02).

## Documentación

- `docs/contexto-ia/` (00–08): contexto estructurado para IA.
- `docs/BACKLOG_PENDIENTES.md`, `ESTADO_DEL_SISTEMA.md`, `CHANGELOG.md` vigentes.
- `docs/historial/` conserva todos los informes/planes/auditorías/prompts anteriores
  como archivo (no se borró nada; trazabilidad hacia atrás).
