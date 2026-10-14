# 04 — Arquitectura

## 1. El dibujo completo

```
                    ┌────────────────────────────────────────────┐
                    │              NAVEGADOR (Flutter Web)        │
                    │  lib/screens · providers · services ·        │
                    │  repositories · gateways (puertos)           │
                    └───────┬───────────────────────┬────────────┘
                            │                       │
              AUTH + LECTURAS por RLS          ESCRITURAS con reglas
              (PostgREST directo, ADR-003)     (Fastify /api/v1)
                            │                       │
                            ▼                       ▼
                 ┌──────────────────┐      ┌──────────────────┐
                 │  SUPABASE        │      │  BACKEND         │
                 │  GoTrue (auth)   │◄────►│  Fastify 5 + Zod │
                 │  PostgREST       │ JWT  │  Node 22 / TS    │
                 │  PostgreSQL 17.6 │      └────┬────────┬────┘
                 │  + RLS + triggers│           │        │
                 └────┬─────────────┘     service_role   │
                      │                         │        │
                      │                 ┌───────▼──┐  ┌──▼───────────┐
                      │                 │ tablas   │  │ CLOUDFLARE R2│
                      └────────────────►│ (RLS)    │  │ (archivos,   │
                                        └──────────┘  │  presigned)  │
                                                     └──────────────┘
```

**Dos caminos de datos, y cuál usar es una decisión de arquitectura:**

1. **Auth y lecturas van directo a Supabase** (PostgREST) desde el navegador.
   La autorización la decide la **RLS** (ADR-003): el frontend no tiene poder
   que la API pudiera quitarle. Por eso el menú lee `system_modules` por
   PostgREST sin ninguna ruta de Fastify: cualquier autenticado tiene `select`.
2. **Las escrituras con reglas van por Fastify** (`/api/v1/...), que valida con
   Zod, traduce errores de Postgres a códigos HTTP semánticos y usa el cliente
   de Supabase del llamante (respeta su RLS) o `service_role` donde la RLS no
   alcanza.

## 2. Frontend — estructura y responsabilidades

### Pantallas (selección con su hueco en el sistema)

| Pantalla | Rol | Qué resuelve |
|---|---|---|
| `landing_page.dart` | público | Portada: `/` sin sesión. Lee la oferta como `anon` |
| `login_screen.dart` | público | Login (correo + contraseña) con enlace a registro y a recuperación |
| `aspirante_form_screen.dart` | aspirante | **Renderiza el catálogo** `inscripcion_campos`: 9–10 pasos, campos condicionales, validación local + prechequeo en base |
| `restablecer_con_codigo_screen.dart` / `restablecer_password_screen.dart` | público | Canje del código interno de 12 caracteres / enlace viejo |
| `activar_cuenta_screen.dart` | docente invitado | Lee el token del fragmento de la URL y fija la contraseña |
| `admin_dashboard.dart` | admin | Menú lateral adaptativo (cajón <900 px) + `switch` por título |
| `admin/*` (18 paneles) | admin | cPanel: módulos, parámetros, auditoría, accesos, invitaciones, usuarios y roles, programas, secciones, aulas, lapsos, guardias, cuadrante, inscripciones, catálogo de la planilla |
| `aula_virtual_dashboard.dart`, `mis_aulas_panel.dart`, `mi_horario_panel.dart` | docente/estudiante | Aula: anuncios, tareas, entregas; horario propio |
| `crear_anuncio_panel.dart`, `crear_tarea_panel.dart`, `libro_calificaciones_panel.dart`, `gestor_documental_panel.dart` | docente | Centro de Mando del Docente |
| `docente/asistencia_qr_panel.dart` | docente | Tablero M7: QR que caduca cada 15 s, marcas en vivo por WebSocket |
| `aspirante/marcar_asistencia_panel.dart`, `aspirante/escaner_qr_screen.dart` | estudiante | Marca asistencia: seis dígitos o lector de QR |
| `mis_inscripciones_panel.dart` | estudiante | Ciclo de estados de inscripción (cuenta regresiva, aceptar/renunciar, orden por urgencia) |
| `perfil_panel.dart` | admin + estudiante | Un solo panel compartido: edita nombres y apellidos, muestra correo/rol |

### Contratos de UI aprendidos de bugs reales (no romper)

- **`ContenidoSeccion` entrega a su hijo una altura ACOTADA** (vía `Flexible`),
  no un scrollable. Los paneles que reparten espacio con `Expanded` dependen de
  eso; los que crecen con su contenido traen su propio `ListView`. **Al
  probarlos, montarlos dentro de `ContenidoSeccion`**, como en el dashboard:
  montarlos en un `Scaffold` pelado esconde el fallo.
- **Nunca deshabilitar un campo de entrada con un estado que cambia mientras el
  usuario escribe** (`enabled: !_isLoading` congela el campo a mitad de tecleo).
  Se bloquea el **botón**, no el campo.
- **Liberar el estado de carga ANTES de `if (!mounted) return;`**; si no, un
  desmontaje durante la petición deja la bandera en `true` para siempre y la
  pantalla muere.
- **El estado del módulo gobierna los menús** y **falla abierto**: si la lectura
  de `system_modules` falla, el menú se muestra de más y el backend contesta su
  403 —nunca al revés—. Un gris explica quién lo apagó y dónde se enciende.

## 3. Backend — superficie HTTP

Base: `/api/v1`. **80 rutas / 89 operaciones / 125 esquemas** (medido el
2026-10-12 sobre `backend/openapi.json`; el documento se **genera** desde Zod,
no se escribe a mano). Familias de rutas:

| Familia | Acceso | Ejemplos |
|---|---|---|
| salud | público | `GET /salud`, `GET /salud/profundo` |
| identidad | sesión | `GET /yo` (perfil + módulos visibles), `GET /modulos` |
| cPanel | admin | `GET/PATCH /admin/modulos`, `/admin/parametros`, `/admin/auditoria`, `/admin/acceso`, `/admin/usuarios` |
| invitación/activación | admin / token | `POST /admin/usuarios/invitaciones`, `POST /auth/activar` (token de un solo uso, sin sesión) |
| recuperación | admin / token | `POST /admin/usuarios/:id/restablecer` (emite el código), canje público del código |
| currículo (M2) | admin | `/admin/programas`, `/admin/materias` (crear programa + pensum es **atómico** por RPC) |
| cuadrante (M3) | admin + rol | `/admin/aulas`, `/admin/periodos`, `/admin/guardias`, `/admin/cuadrante`, `GET /mi-horario` |
| inscripciones (M4) | mixto | `/ofertas`, `/mis-inscripciones`, `POST /inscripciones`, `/admin/ocupacion`, `/admin/secciones/:id/cola`, `/admin/inscripciones/*` |
| planilla/HACER (M4) | admin | PDF y Excel de la planilla oficial, exportación CSV hacia HACER |
| archivos (M5) | sesión + admin | firmar subida, confirmar, URL de lectura, borrado propio, borrado de admin, barrido |
| aula (M6) | sesión | tablón, trabajo, entregas, calificar, devolver, libro |
| asistencia (M7) | docente/estudiante | `POST /asistencia/sesiones`, `POST /asistencia/marcar`, `PATCH …/cerrar`, `GET /asistencia/rt` (WebSocket) |

**Patrones transversales que hay que respetar al añadir rutas:**

- **Paginación: contar primero.** Toda lista hace el `count` con `head: true`
  antes de pedir la página y devuelve `{ filas, total, limite, desplazamiento }`.
  Así el cliente pinta «1 a 25 de 340» sin una segunda consulta y un
  desplazamiento fuera de rango devuelve página vacía (no 416).
- **Guardia de módulo después de la de rol** (el orden produce el 401 correcto).
- **Ninguna ruta escribe `enrollments` directo**: la tabla tiene las escrituras
  revocadas; todo pasa por RPC `security definer`.
- **El choque de agenda no se comprueba en la API, se traduce**: la API escribe,
  el trigger decide, el repositorio convierte el `23514` en 409 reusando el
  mensaje del trigger (que ya nombra día y bloque).
- **Toda ruta documentada debe existir y responder** (401 si es protegida): el
  test de OpenAPI compara el documento contra el árbol real de Fastify **en las
  dos direcciones**.

## 4. Base de datos — el modelo, por dominio

### Identidad

- `auth.users` (GoTrue) → trigger `handle_new_user()` → crea **en la misma
  transacción** `profiles` (rol fijo `estudiante`) y `aspirantes` (la ficha).
  ADR-007/008: **el auto-registro nunca otorga rol**, y la ficha nunca se
  inserta desde el cliente.
- `profiles`: identidad y rol (espejo de `auth.users`). El perfil editable son
  nombres y apellidos; correo, cédula y rol se **muestran** y no se tocan.
- `aspirantes`: ficha de inscripción. **M4 le añadió `datos_planilla` (jsonb)**:
  la planilla extendida con la forma del catálogo, para que añadir un campo del
  CFS no exija migración. El trigger `aspirantes_validar_planilla` la valida
  contra el catálogo **también al escribir por PostgREST**.
- `inscripcion_campos` (M4): **el catálogo de la planilla**: una fila por campo
  con tipo, obligatorio, orden, opciones, condición de visibilidad y a qué
  programa aplica. Fuente de verdad del formulario: la pantalla lo renderiza y
  el administrador lo edita sin tocar código. Legible por `anon` a propósito
  (el aspirante pinta el formulario sin sesión).

### Oferta académica (M2/M3)

- `programs` (carreras y cursos libres; absorbió a `cursos` en D12),
  `subjects` (banco global de materias), `program_subjects` (el pensum).
- `sections` (rediseñada en D13), `enrollments` (matrículas y sus cuatro
  estados: `ENROLLED`, `WAITLISTED`, `PENDING_BID`, `DROPPED`).
- `academic_periods` (catálogo de lapsos), `classrooms` (aulas, talleres y
  zonas —una zona es una fila con `capacity = 0`—), `teacher_duties`
  (guardias), `schedule_slots` (el cuadrante).

### Infraestructura del sistema

- `system_modules` (interruptores), `system_settings` (parámetros),
  `config_audit_log` (auditoría append-only de la configuración).
- `teacher_invitations` (invitaciones; se guarda el **hash**, con revocar y
  renovar), `auth_logs` (trazas de acceso), `schema_migrations` (libro mayor
  de migraciones con checksum), `password_resets` (códigos de recuperación;
  **sólo lectura para admin, sin política de escritura**: su único camino de
  entrada es `service_role`).

### Aula (M6) y asistencia (M7)

- `m6_anuncios`, `m6_tareas`, `m6_entregas` + RPC de publicación/calificación.
  M6 no pregunta «¿eres docente?» sino «¿dictas ESTA sección?»
  (`m6_dicta_seccion()` lee `schedule_slots`) —por eso el sembrado de datos
  incluye clases en el cuadrante: sin ellas el Centro de Mando responde
  `SIN_PERMISO_EN_EL_AULA` con el docente y la sección existiendo.
- `attendance_sessions` (sesión abierta, `qr_secret` que viaja **una sola
  vez**), `attendance_marks` (una marca por alumno y sesión) +
  `v_attendance_sesiones`. **La RLS valida el código**: la política
  `attendance_marks_estudiante_insert` llama a `asistencia_codigo_vigente` y
  rechaza con `42501` un código caducado.

## 5. La RLS en una página (la matriz que decide todo)

| Tabla | Lectura | Escritura |
|---|---|---|
| `profiles` | la propia; admin todo | la propia (sin cambiar rol); admin todo |
| `aspirantes` | la propia; admin todo | la propia; admin todo. **Sin inserción anónima** |
| `system_modules` | cualquier autenticado | **solo admin** (y `m0_cpanel` ni se apaga) |
| `system_settings` | públicos para `anon` + autenticados; privados solo admin | **solo admin** |
| `config_audit_log` | solo admin | **nadie**: único camino, el trigger |
| `programs` | `anon` ve las activas; autenticados todo | solo admin |
| `subjects`, `program_subjects` | solo autenticados | solo admin |
| `sections`, `classrooms` | activas para `anon` + autenticados (classrooms: solo autenticados) | solo admin; **sin `DELETE`**: archivar es `is_active = false` |
| `enrollments` | la propia; admin todo; `anon` sin `GRANT` | **nadie escribe directo** (ni el dueño ni un admin): escrituras revocadas; sólo las RPC de M4 |
| `teacher_invitations` | solo admin | solo admin (la activación usa `service_role`) |
| `auth_logs` | solo admin | **nadie**: trigger/backend |
| `schema_migrations` | **nadie** | **nadie** (sólo el script con token) |
| `academic_periods` | público | solo admin |
| `teacher_duties` | el docente ve las suyas; estudiante **sin política** | solo admin |
| `schedule_slots` | el docente las suyas; el estudiante las de su sección | solo admin |
| `attendance_sessions` | docente (las suyas) y admin | solo el docente que la abre; cerrar es `PATCH` |
| `attendance_marks` | docente (su sesión); estudiante ninguna | **el estudiante sólo `INSERT`, y la política valida el código** |
| `password_resets` | admin (sólo lectura) | **nadie**: sólo `service_role` desde el backend |
| Vistas (`v_*`) | heredan la RLS de las tablas base por `security_invoker` | — |

**Tres propiedades de esta matriz que son deliberadas y hay que preservar:**

1. **«Sin política» no es «política que devuelve vacío»** (estudiante en
   `teacher_duties`): es una puerta pintada en la pared.
2. **`anon` recibe `42501 permission denied`, no una lista vacía**: una lista
   vacía sería indistinguible de una política mal escrita. Medido en vivo sobre
   `v_exportacion_hacer` (2026-09-25): el estudiante matriculado ve **su** fila,
   el ajeno ve **cero**, el de la cola no aparece.
3. **El nombre de un docente se resuelve con `nombre_para_mostrar()`**, no
   relajando `profiles_read_own`: la RLS es por fila y no puede ocultar una
   columna; relajar la política expondría cédula y correo de todo el centro.

## 6. El sistema de módulos, en funcionamiento

1. La fila de `system_modules` dice si el módulo está encendido y qué roles lo
   ven. **El menú la lee por PostgREST** y falla abierto.
2. La API tiene `exigirModulo()` en las rutas de los módulos que la llevan
   (M2, M3, M4, M5, M7 para las rutas del docente): apagarlo devuelve
   **403 `MODULO_DESHABILITADO`**; una clave inexistente devuelve **404
   `MODULO_DESCONOCIDO`** (error distinto a propósito: manda a buscar a la
   semilla, no a la bandera).
3. **La excepción deliberada es M7**: `POST /marcar` (el alumno es quien marca)
   queda sólo con `exigirSesion()`, porque la lista blanca del módulo es
   `['docente','admin']` y envolverla devolvería 403 al estudiante. Su barrera
   de contenido es la RLS. El WebSocket del tablero **sí** lleva guardia, y
   también su handshake.

## 7. Tiempo real (M7)

Canal **unidireccional** servidor → cliente por `GET /api/v1/asistencia/rt`:
el tablero del docente recibe un evento por cada marca, sin polling. El
estudiante marca por REST, así que un cliente no puede colar una marca por el
canal. Se suscribe con el mismo JWT de Supabase que usa REST. El upgrade pasa
por el router normal de Fastify (por eso los hooks —y la guardia de módulo— lo
alcanzan).
