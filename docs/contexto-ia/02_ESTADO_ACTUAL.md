# 02 — Estado actual del sistema

> **Regla del proyecto:** este documento envejece. Cada cifra lleva la fecha en
> que se midió. Si vas a tomar una decisión con una de estas cifras, **vuelve a
> medirla** con los comandos de `07_MAPA_Y_COMANDOS.md`.

## 1. Producción (verificado 2026-10-10)

| Pieza | Dónde | URL / identificador |
|---|---|---|
| Frontend (Flutter Web) | Cloudflare Pages, proyecto `inces-lms` | https://inces-lms.pages.dev |
| Backend (Fastify) | Render, servicio `inces-lms-api` (Docker, plan free) | https://inces-lms-api.onrender.com |
| Health check | Render | `GET /salud` → **200** |
| Base de datos | Supabase, proyecto `twdppwnxlnmxkiejbrei` (región sa-east-1, PostgreSQL 17.6) | `https://twdppwnxlnmxkiejbrei.supabase.co` |
| Repositorio | GitHub, rama `main` | `github.com/Burmistrov4/inces-lms` |

**Comprobado en producción:** Pages `/` → 200; bundle público contiene la API de
producción y **cero** `localhost:3001`; Render `/salud` → 200; preflight CORS de
una ruta de administración → 204 con el origen exacto del frontend.

**Cómo se despliega (resumen; el procedimiento completo está en
`docs/PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md`):**

- Frontend: el workflow `web_bundle.yml` compila el bundle **con la API de
  producción**, lo valida (§5.1 del procedimiento) y lo publica como artefacto;
  se despliega con `wrangler pages deploy`. **Nunca** se publica un bundle
  compilado con la plantilla (`dart-define.example.json`) ni uno que apunte a
  una API local.
- Backend: Render despliega solo desde `main` (Dockerfile en `backend/`).
- Base de datos: las migraciones **no** se aplican automáticamente. Se revisa el
  SQL, se corre `apply-migrations.mjs --check` y **sólo se aplica con
  autorización explícita**.

## 2. Base de datos en la nube

- **46 migraciones** aplicadas en el proyecto remoto; **0 pendientes, 0 con
  deriva** (libro mayor `schema_migrations` con checksum SHA-256; medido el
  2026-10-09 con `supabase/apply-migrations.mjs --check`).
- **Último recuento de catálogo publicado: 24 tablas, 6 vistas, 58 funciones,
  29 triggers, 52 políticas RLS** (medido el 2026-09-29). Las 13 migraciones
  posteriores añadieron objetos (p. ej. la tabla `password_resets`, funciones
  del bloque E2 de la planilla, columnas de invitaciones), así que **el recuento
  vigente se mide con `supabase/contar-catalogo.mjs`**, no se hereda de aquí.
- RLS activa en todas las tablas de negocio. Las dos tablas de auditoría
  (`config_audit_log`, `auth_logs`) **no tienen camino de escritura para nadie**
  salvo sus triggers y el backend con `service_role`.

**Inventario estructural (lo que hay que conocer antes de tocar el esquema):**

- **Tablas** (las de negocio, por origen): `profiles`, `aspirantes`,
  `sections`, `enrollments` (Fase 0); `programs`, `subjects`,
  `program_subjects` (M2); `academic_periods`, `classrooms`,
  `teacher_duties`, `schedule_slots` (M3); `inscripcion_campos` (M4,
  el catálogo de la planilla); `files_metadata` (M5); `m6_anuncios`,
  `m6_tareas`, `m6_entregas` (M6); `attendance_sessions`, `attendance_marks`
  (M7); más las de infraestructura: `system_modules`, `system_settings`,
  `config_audit_log`, `teacher_invitations`, `auth_logs`, `schema_migrations`,
  `password_resets` (2026-10-09).
- **Vistas** (todas `security_invoker`, es decir: respetan la RLS de las tablas
  base): `v_cuadrante_clases`, `v_cuadrante_guardias`, `v_periodo_vigente`
  (M3), `v_ocupacion_secciones` (M4), `v_exportacion_hacer` (M4, la exportación
  hacia HACER), `v_attendance_sesiones` (M7).
- **Funciones y triggers** que sostienen reglas que la API no puede ver:
  `handle_new_user()` (alta atómica de `profiles` + `aspirantes`, rol fijo
  `estudiante`), `proteger_ultimo_admin()` (D8), `proteger_modulo_critico()`
  (`m0_cpanel` no se apaga), las dos reglas de negocio de M2
  (`exigir_pensum_de_programa` diferido, `proteger_pensum_en_uso`),
  `exigir_agenda_libre()` + sus dos envoltorios `security definer` (el corazón
  anti-colisión de M3), y el motor de cupos de M4 (`solicitar_inscripcion`,
  `aceptar_cupo`, `promover_siguiente`, `expirar_ofertas_cupo`,
  `existe_oferta_vigente`, …). El detalle completo está en
  `ESTADO_DEL_SISTEMA.md` §3.

## 3. Estado de la verificación (todo medido, nada supuesto)

| Red | Resultado | Fecha |
|---|---|---|
| Backend `npm run verify` (typecheck + lint + vitest) | **675 / 675**, 32 archivos | 2026-10-09 |
| SQL sobre PostgreSQL real (PGlite, `supabase/tests`) | **546 aserciones**, 0 fallos | 2026-10-09 |
| `flutter test` | **974 pruebas**, todas en verde | 2026-10-09 |
| `devops/analizar-dart.mjs` (tipos/lints en local) | **223 archivos**, sin diagnósticos | 2026-10-10 |
| E2E Playwright (navegador Chromium real) | **24 / 24** (2,2 min) | 2026-10-09 |
| Humo de flujos de identidad contra la nube (`--confirmar`) | invitaciones **34 OK / 0 fallos**; recuperación **27 OK / 0 fallos**, residuo 0/0/0 | 2026-10-09 |
| Ciclo E2E del aula (muta datos; se corre aparte y con limpieza) | **7 / 7 PASS** | 2026-10-09 |

**Rendimiento (G3, causa raíz medida y corregida el 2026-10-09):** el hook de
autenticación hacía **dos viajes de red en serie** en cada petición
(verificar token en GoTrue + leer perfil en PostgREST = 421 ms fijos).
Paralelizados esos viajes y varias parejas de lecturas independientes, las
rutas bajaron: `admin/usuarios` 1.462 → **521 ms** (−64 %), `aula/trabajo`
−47 %, `mi-horario` −32 %, `cuadrante` → **679 ms** (tres esperas secuenciales:
está en su suelo sin caché de período o verificación local del JWT).
Paginación y filtros: **44 OK / 0 fallos**, incluido «desplazamiento fuera de
rango → 200 con página vacía».

## 4. Lo que funciona y está demostrado (selección)

- **Alta de aspirante**: transacción atómica en PostgreSQL (trigger sobre
  `auth.users`); el formulario se renderiza desde el catálogo
  `inscripcion_campos` (9–10 pasos, campos condicionales validados también en
  la base).
- **Ciclo del aula virtual completo**: el docente publica un anuncio, crea una
  tarea, el aprendiz entrega, el docente califica y devuelve, el aprendiz ve la
  nota. Demostrado en E2E con limpieza verificada.
- **Asistencia QR**: el docente abre sesión, proyecta un QR que caduca cada
  15 s, las marcas entran por WebSocket sin recargar; el alumno marca con los
  seis dígitos y **la RLS valida el código** (la barrera anti-trampas vive en la
  base, no en la app).
- **Planilla oficial**: generación de PDF (612×792 pt, sobreimprime la plantilla
  institucional bit a bit) y Excel editable en el backend, más exportación CSV
  hacia HACER con formato medido (BOM, CRLF, separador `;`, mayúsculas,
  `documento_identidad` derivado).
- **Usuarios y Roles del cPanel**: listado paginado con filtros, cambio de rol
  con protección del último administrador en dos capas (regla pura + trigger),
  invitación/revocación/renovación de docentes y emisión de códigos de
  recuperación.

## 5. Abierto — pendientes reales (con su criterio de cierre)

| # | Pendiente | Qué falta |
|---|---|---|
| 1 | **Correo externo (Resend)** | Renovar clave/verificar dominio del propietario. HTTP 401 hoy. **No bloquea nada**: registro, invitación y recuperación son internos. |
| 2 | **D17 — especificación de HACER** | Falta **la lista de campos y el orden** que espera la plataforma del INCES. Se resuelve **preguntando**, no programando. La capa que cambiaría cuando llegue es una: `columnasExportacionHacer` + `csvDeExportacionHacer` + el `select` de la vista. |
| 3 | **D9 — barrido de subidas abandonadas** | El reloj (cron diario 07:17 UTC en GitHub Actions) y el código están hechos y verificados; **faltan los seis secretos** de GitHub. Sin ellos falla seguro (no toca nada). |
| 4 | ~~Login con cédula~~ | ✅ **ARREGLADO el 2026-10-02.** Estaba muerto por construcción (la cédula vive en `aspirantes`, no en `profiles`, y las políticas de `profiles` no cubren `anon`). La migración `202610020001` creó la RPC `security definer` `email_por_cedula(text)`: entra una cédula, sale **un correo o NULL** (no expone el padrón), normaliza por dígitos en ambos lados, con `EXECUTE` sólo para `anon`/`authenticated` tras revocar de `PUBLIC`. El cliente ya la usa (`AuthService` → `emailPorCedula`). **El precio, aprobado explícitamente por Lorenzo el 2026-10-02: la función es un oráculo de existencia** (un anónimo puede comprobar si una cédula está registrada). Nota: la lista de pendientes de la memoria del proyecto lo seguía dando por muerto —era una nota anterior a esta fecha. |
| 5 | **D7 — catálogo de la planilla** | `opciones` no es editable desde el panel, `aplica_a` quedó muerto, y hay cinco credenciales por rotar. |
| 6 | **Bloque de períodos (duración/caducidad/estados)** | **Sólo diseño**: `docs/DISENO_PERIODOS_DURACION_Y_CADUCIDAD_2026-10-10.md`. `academic_periods` no tiene duración ni estados; `programs` no tiene duración. Requiere migración nueva + autorización + 5 decisiones institucionales. |
| 7 | **Verificación funcional en producción** | Falta una cuenta de prueba autorizada para verificar en navegador real de producción «Invitar docente» y la promoción de administradores. |
| 8 | **M7 — cámara en dispositivo físico** | Único pendiente del módulo de asistencia: validar `mobile_scanner` en un teléfono real. |
| 9 | **`SUPABASE_JWT_SECRET`** | No está en `backend/.env`; es del propietario. Con él, la verificación local del JWT eliminaría el viaje a GoTrue. |
| 10 | **G3 — rendimiento** | Falta medición estable en producción y decidir entre caché del período o verificación local del JWT. Responsive: barrido hecho; puerta de aceptación por definir. |
| 11 | **`habilitar_sistema_bids`** | Nace apagado a propósito. **Decidir si debe nacer encendido es de Lorenzo.** |

**Deuda documental y de datos, declarada a propósito:**

- **7 sesiones de asistencia quedaron `OPEN` más de 12 h** del 2026-09-26: son
  la huella del bug D28 (el botón «Cerrar» afectaba 0 filas). **No hacen daño**:
  el resolutor de código las ignora y el alumno no puede calcular su código.
  Cerrarlas es un `update` de una línea sobre datos de producción: **decisión,
  no arreglo**.
- **D21 quedó con una asimetría conocida**: `asistencia_puede_marcar` (la
  guardia de la política de inserción) no lleva la cota de 12 h que sí tiene el
  resolutor. Está escrito en vez de «arreglado por si acaso».

## 6. Cerrado — no reabrir sin medir

Autenticación sin Resend (códigos internos + ciclo de invitación); P0 /
Usuarios y Roles / los ocho módulos; planilla Excel/PDF/HACER; M3 y M4
completos; M6 ciclo completo; el arnés local de E2E con `CI=true`; la corrección
del panel de invitaciones (crasheaba por altura no acotada dentro del acordeón,
2026-10-10, desplegada a producción). El historial de deudas D1–D29 está en
`08_GLOSARIO.md` y en `ESTADO_DEL_SISTEMA.md` §6.
