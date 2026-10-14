# 08 — Glosario

## 1. Deudas técnicas (D-números)

Registro histórico. **Estado al 2026-10-12.** El detalle de cada una está en
`ESTADO_DEL_SISTEMA.md` §6.

| # | Deuda | Estado |
|---|---|---|
| D1 | `SupabaseService` no era inyectable → camino de red sin pruebas | ✅ resuelta |
| D2 | Los dashboards hablaban con el singleton saltándose los repositorios | ✅ resuelta |
| D3 | Sin validación de configuración al arrancar | ✅ resuelta |
| D4 | Los 5xx consumían la cuota de rate limit | ✅ resuelta (`skipOnError`) |
| D5 | El modo mantenimiento bloqueaba todo si fallaba la lectura del parámetro | ✅ resuelta (falla abierto) |
| D6 | Falta el contrato OpenAPI 3.1 | ✅ resuelta (generado desde Zod + pruebas de coherencia en dos direcciones) |
| D7 | Sin verificación de tokens en caché (una llamada a Auth por petición) | ⏳ aceptada; medir antes de optimizar |
| D8 | No se comprobaba que quedara **otro** admin al degradar a uno | ✅ resuelta (trigger `proteger_ultimo_admin` + regla pura) |
| D9 | Una URL `PUT` prefirmada no puede imponer tamaño máximo → subidas abandonadas | 🟡 código y reloj hechos y verificados; **faltan los seis secretos** de GitHub (falla seguro) |
| D10 | Conexión directa a Postgres sólo IPv6 → `supabase db push` no funciona | ✅ resuelta (`apply-migrations.mjs` + libro mayor con checksums) |
| D11 | `ESTADO_DEL_SISTEMA.md` arrastraba cifras viejas | ✅ resuelta (y vuelta a necesitar: el documento se desincroniza solo) |
| D12 | `cursos` y `programs` eran el mismo concepto | ✅ cerrada del todo (vista de compatibilidad retirada 2026-09-25) |
| D13 | El `sections` de Fase 0 no era el que exige M3 | ✅ resuelta (rediseño + Regla 2 como trigger) |
| D14 | `aspirantes.curso_seleccionado` era texto libre | ✅ resuelta (`program_id` + `resolver_programa_inscripcion()`) |
| D15 | Dos convenciones de período incompatibles | ✅ resuelta (`periodo_activo = "SA26-2"`) |
| D16 | El bucket R2 no tenía política de CORS | ✅ resuelta (2026-09-19; preflight verificado) |
| D17 | **No existe la especificación de campos que espera HACER** | 🟡 **abierta**: falta la lista de columnas y su orden. Se cuela preguntando, no programando |
| D18 | M7 (asistencia) no tenía una sola prueba propia | ✅ resuelta (2026-09-27; 32 pruebas backend + 3 archivos Flutter) |
| D19 | `m7_asistencia` sin guardia de módulo (y ponerla tal cual daría 403 al alumno) | ✅ resuelta (sólo las rutas del docente + el WS) |
| D20 | El validador SQL estuvo rojo sin que nadie lo supiera (autocomprobación no hermética) | ✅ resuelta (2026-09-26; + flujo `Supabase CI`) |
| D21 | La pantalla de asistencia del alumno no podía marcar (**nunca**): `maxLength: 6` vs parser de 43 | ✅ resuelta (vía manual de 6 dígitos + servidor resuelve la sesión; lector QR con `mobile_scanner`) |
| D22 | El tablero del docente se congelaba en silencio si el canal se cerraba limpiamente (faltaba `onDone`) | ✅ resuelta |
| D23 | `pubspec.lock` no contenía `qr_flutter` (versión se resolvía contra la red en cada CI) | ✅ resuelta (`454d923`) |
| D24 | El cPanel pintaba dos secciones «General» seguidas (vocabulario de categorías en tres sitios) | ✅ resuelta (+ `aula`, + `recursos`, + dos pruebas) |
| D25 | Una prueba pasaba sin medir lo que decía (apagaba una fila que no existía en la semilla) | ✅ resuelta (afirma su premisa + verificado por mutación) |
| D26 | Una prueba podía ponerse roja sin que nada fallara (leía el reloj dos veces) | ✅ resuelta |
| D27 | La política del alumno era inalcanzable: llamaba a una función con `EXECUTE` revocado → `42501` antes de decidir | ✅ resuelta (`202609270001`; `asistencia_puede_marcar`) |
| D28 | El docente no podía cerrar su sesión (faltaba la política `UPDATE`) | ✅ resuelta |
| D29 | Las aserciones negativas estaban verdes por el motivo equivocado (todas por el `42501` de D27) | ✅ cerrada al ejercitar el camino feliz |

## 2. Hallazgos R-números (del `REPORTE_ARIA.md` y los contratos)

| # | Hallazgo |
|---|---|
| R-06 / R-12 | Divergencia de período: `system_settings.periodo_activo` vs `academic_periods`. Cerrada con `exigir_periodo_registrado()` |
| R-10 | M2 no escribe con `insert`: programa + pensum van por RPC atómica (PostgREST no inserta padre+hijos en una petición) |
| R-14 | El nombre del docente se resuelve con `nombre_para_mostrar()`, no relajando `profiles_read_own` (la RLS no oculta columnas) |
| R-16 | `turno` es columna generada a partir del bloque (`turno_de_bloque`), no un campo que pueda contradecirlo |
| R-18 | Una zona del centro es una fila de `classrooms` con `capacity = 0` |
| R-20 | Los envoltorios de trigger del cuadrante son `security definer` a propósito: su función existe revocada a todos |
| R-22 | «Ítem de menú disponible» y «módulo encendido» son dos contratos; la comprobación es bidireccional (¿existe algo que no anuncio?) |
| R-23 | `enrollments` tiene las escrituras **revocadas** a `anon` y `authenticated`: única vía, las RPC `security definer` |
| R-24 | El `Content-Type` de la subida va firmado (`signableHeaders`); sin firma, el cliente podía declarar cualquier tipo |

## 3. Módulos y migraciones

- **M0** cPanel · **M1** onboarding/invitaciones · **M2** currículo y pensum ·
  **M3** cuadrante, aulas, guardias · **M4** inscripciones, cupos, planilla y
  exportación HACER · **M5** archivos en R2 · **M6** aula virtual ·
  **M7** asistencia QR · **M8** pasantías (diseñada, no construida) ·
  **M9** certificados/QR (**descartado del alcance**).
- **E-1 / E-2**: bloque del flujo de la Planilla Oficial (migraciones
  `20261006000x`): persistencia del workflow, transiciones exactas, cierre de
  bypasses administrativos, integridad de aprobación/observaciones y
  observación atómica.
- **Convención de migraciones:** `YYYYMMDDNNN_descripcion.sql`. **Nunca editar
  una aplicada**; el libro mayor (`schema_migrations`) guarda su checksum
  SHA-256.

## 4. Vocabulario del proyecto

| Término | Significado |
|---|---|
| **HACER** | Plataforma nacional del INCES a la que el LMS **alimenta** (no sustituye). No emite certificados |
| **cPanel / Administrador Maestro** | Panel del admin: módulos, parámetros, usuarios, catálogo, auditoría |
| **Planilla** | Ficha oficial de inscripción del aspirante; existe en PDF (sobreimprime la plantilla institucional bit a bit), Excel editable y exportación CSV hacia HACER |
| **Aspirante** | Ficha de quien se inscribe (`aspirantes`); al completar el registro ya es estudiante |
| **Pensum** | Qué materia va en qué programa y en qué período (`program_subjects`); Regla 1: una carrera activa no puede quedarse sin materias |
| **Cuadrante** | La rejilla de clases: sección + docente + aula + día/bloque, con anti-colisión |
| **Guardia** | Custodia de un docente sobre un espacio en un día/bloque, con o sin clase |
| **Lapso** | Período académico (`academic_periods`); el vigente se declara y `sections.period_code` apunta a él |
| **Sección** | Grupo concreto de una materia en un lapso, con cupo |
| **Matrícula** | Fila de `enrollments`: `ENROLLED`, `WAITLISTED`, `PENDING_BID` o `DROPPED` |
| **Bid / oferta** | Oferta de cupo con vencimiento (`bid_ttl_horas`, 24 h) al siguiente de la cola; **el motor nace apagado** |
| **Semilla** | Datos de ejemplo persistentes (`sembrar-datos.mjs`), marcados (`SEM-`, `[SEMILLA]`, `@semilla.invalid`) |
| **Humo** | Prueba contra la infraestructura real que **crea y purga** (`humo-*.mjs`, `--confirmar`) |
| **Libro mayor** | `schema_migrations`: versión + checksum + fecha de cada migración aplicada; detecta deriva |
| **Deriva** | Diferencia entre lo que dice el repo y lo que tiene la nube (o entre dos documentos) |
| **PGlite** | PostgreSQL compilado a WASM: corre las migraciones de verdad en CI sin Docker ni credenciales |
| **CanvasKit** | Motor de render de Flutter Web: no expone widgets como DOM (de ahí el árbol semántico para E2E) |
| **Árbol semántico** | La capa de accesibilidad de Flutter Web; lo único que Playwright puede leer |
| **Result\<T\>** | `Success`/`Failure` + `AppException`: el contrato de las capas de datos (ADR-010). `null` = «no existe», nunca «falló» |
| **Puerto (gateway)** | Interfaz que la app consume y los tests doblan (Supabase, backend, R2, selector de archivos) |
| **`231` / `ERROR_PIPE_BUSY`** | El fallo intermitente del VM de Dart al crear tuberías nombradas en este equipo; la respuesta es CI |
| **Verde que no midió** | Prueba o verificador que pasa sin ejercitar lo que afirma (D25). Su imagen simétrica es el rojo que no midió (D26) |

## 5. Siglas del stack

| Sigla | |
|---|---|
| ADR | Architecture Decision Record (decisión de arquitectura registrada) |
| RLS | Row Level Security (políticas de fila de PostgreSQL) |
| RPC | Remote Procedure Call (función de Postgres invocada por HTTP) |
| JWT | JSON Web Token (la sesión que emite GoTrue) |
| TTL | Time To Live (caducidad: caché de módulos, URLs prefirmadas, códigos) |
| CORS | Política de orígenes cruzados del navegador (el preflight es el juez, no Node) |
| PG / PG17 | PostgreSQL 17.6 sobre Supabase |
| GoTrue | El servicio de autenticación de Supabase |
| PostgREST | La API REST automática de Supabase (la que habla el frontend) |
