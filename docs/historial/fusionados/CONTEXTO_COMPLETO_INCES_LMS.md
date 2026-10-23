# Contexto completo — INCES LMS (documento único)

> **Qué es este archivo.** Es la fusión, en un solo documento, de los nueve
> archivos de `docs/contexto-ia/`. Existe porque algunas herramientas e IAs
> sólo admiten **subir un archivo por interacción**: este es ese archivo.
>
> **Generado el 2026-10-12** concatenando las versiones canónicas de
> `docs/contexto-ia/` (mismo contenido, títulos degradados un nivel). Si algo
> de aquí contradice a los archivos de esa carpeta —o al código—, **mandan
> ellos**: esta fusión es una copia, no la fuente.
>
> **Cómo leerlo.** Las secciones están numeradas §0 a §8, en el mismo orden que
> los archivos originales. Cuando el texto dice «`02_ESTADO_ACTUAL.md` §5», se
> refiere a la sección **§2** de este mismo documento (y al archivo homónimo de
> `docs/contexto-ia/`). Para trabajar en el proyecto, edita siempre la carpeta
> de archivos separados; este documento se regenera concatenándolos.

## Índice general

- **§0** · Índice y mapa del paquete
- **§1** · El proyecto y el producto
- **§2** · Estado actual del sistema
- **§3** · Stack tecnológico
- **§4** · Arquitectura
- **§5** · Ciclo de vida
- **§6** · Reglas y lecciones
- **§7** · Mapa del repositorio y comandos
- **§8** · Glosario

---

## Contexto para otra IA — INCES LMS

> **Qué es esta carpeta.** Es un paquete de documentos escritos para una IA que
> **no tiene acceso** a este repositorio ni a sus archivos. Su objetivo es que
> entienda el proyecto entero —qué es, cómo está construido, en qué estado está,
> cómo se trabaja y qué trampas han costado caras— **sin necesidad de leerse los
> miles de archivos del repo**.
>
> **Fuente de verdad.** Este paquete se nutre de `ESTADO_DEL_SISTEMA.md` (el
> documento que manda cuando contradice a otro), de la memoria del proyecto
> (`.workbuddy-ai/memory/`), de los workflows de CI y del código medido el
> **2026-10-12**. Cada cifra lleva su fecha de medición. **Si una cifra de aquí
> contradice al código, gana el código**: este proyecto mide antes de afirmar, y
> un número sin comando que lo produzca es una nota, no un dato.
>
> ** Idioma de trabajo del proyecto: español.** Los comentarios, identificadores
> y mensajes al usuario están en español a propósito.

---

### Cómo leer este paquete

| Orden | Archivo | Para qué |
|---|---|---|
| 1 | `00_INDICE.md` | Este mapa. Empieza aquí. |
| 2 | `01_PROYECTO_Y_PRODUCTO.md` | Qué es el sistema, para quién, qué hace y qué **no** hace. |
| 3 | `02_ESTADO_ACTUAL.md` | Estado verificado hoy: qué funciona, qué está en producción, qué queda abierto. |
| 4 | `03_STACK_TECNOLOGICO.md` | Cada tecnología con su versión y el porqué de la decisión (ADRs). |
| 5 | `04_ARQUITECTURA.md` | Cómo encajan frontend, backend y base de datos; esquema, RLS, contrato de error. |
| 6 | `05_CICLO_DE_VIDA.md` | La vida de un cambio: del diagnóstico al despliegue, y las cinco redes de verificación. |
| 7 | `06_REGLAS_Y_LECCIONES.md` | Las reglas que sostienen el proyecto y las trampas medidas. **Léelo antes de tocar nada.** |
| 8 | `07_MAPA_Y_COMANDOS.md` | Mapa de archivos y los comandos exactos para verificar cada cosa. |
| 9 | `08_GLOSARIO.md` | D1–D29, R-xx, M0–M8, ADRs y vocabulario del proyecto. |

**Lectura mínima para poder trabajar sin romper nada:** `01` → `02` → `06` → `07`.
**Lectura completa recomendada:** las nueve, en orden.

---

### El proyecto en cinco líneas

- **LMS (plataforma educativa) para el CFS Nacional de Soldadura "Rafael Urdaneta"**
  del INCES, La Isabelica (Valencia, Venezuela). Es el **Trabajo Especial de
  Grado** de Lorenzo Roca y su equipo (IUTEPI, Análisis de Sistemas, 4º semestre).
- **Tres roles:** administrador (cPanel), docente y estudiante; más el aspirante
  en su registro previo. La autorización real vive en la base de datos
  (PostgreSQL + RLS), no en la API.
- **Stack:** Flutter Web + Fastify (Node/TypeScript) + Supabase (PostgreSQL) +
  Cloudflare R2. Cero Python. Producción en Render (API) y Cloudflare Pages
  (frontend); la base es Supabase en la nube.
- **Estado:** módulos 0–5, 6 (aula virtual) y 7 (asistencia QR) construidos,
  verificados y en producción; M8 (pasantías) y certificados fuera de alcance.
- **Filosofía:** cada afirmación se mide; un verde que no midió es peor que un
  rojo, porque tranquiliza.

### Cifras de cabecera (con fecha — ninguna es intemporal)

| Cifra | Valor | Medida |
|---|---|---|
| Migraciones en repo y en nube | **46 / 46**, 0 pendientes, 0 deriva | 2026-10-09 |
| Rutas API documentadas (OpenAPI 3.1) | **80 rutas · 89 operaciones · 125 esquemas** | 2026-10-12 (artefacto del repo) |
| Pruebas backend (vitest) | **675 / 675**, 32 archivos | 2026-10-09 |
| Aserciones SQL (PGlite) | **546**, 0 fallos | 2026-10-09 |
| Pruebas Flutter | **974**, todas en verde | 2026-10-09 |
| E2E (Playwright, navegador real) | **24 / 24** | 2026-10-09 |
| Análisis estático Dart (`analizar-dart.mjs`) | **223 archivos**, sin errores/avisos/infos | 2026-10-10 |
| Módulos sembrados | **11 filas, 8 encendidos** | 2026-10-09 |

> **Estas cifras envejecen solas.** El proyecto ha documentado cuatro veces la
> misma lección: un número escrito a mano se desincroniza. Antes de citar
> cualquiera, vuelve a medirla con el comando de `07_MAPA_Y_COMANDOS.md`.

### Las cinco reglas que no se negocian (resumen)

1. **Medir antes de afirmar.** «No está» se mide, no se deduce; «no se puede»
   también se mide.
2. **Nunca editar una migración ya aplicada.** Se añade otra que la corrija.
3. **La frontera de autorización es la RLS**, no la API (ADR-003).
4. **El push es el respaldo.** Dos ediciones al mismo archivo en un mismo
   mensaje: una se pierde.
5. **Puede haber otro agente editando los mismos documentos.** Releer justo
   antes de editar; ediciones aditivas y acotadas.

El detalle y el porqué de cada una están en `06_REGLAS_Y_LECCIONES.md`.

## 01 — El proyecto y el producto

### 1. Qué es y para quién

**INCES LMS** es un sistema de gestión académica web para el
**Centro de Formación Socialista (CFS) Nacional de Soldadura "Rafael Urdaneta"**,
del INCES, en el sector La Isabelica de Valencia, estado Carabobo, Venezuela.

No es un ejercicio académico genérico: es el **Trabajo Especial de Grado (TEG)**
de:

| Persona | Rol |
|---|---|
| Lorenzo Roca | Estudiante, 4º semestre, Análisis de Sistemas, IUTEPI, periodo SA26-2 |
| José Tarazón, Sleither Vásquez, Adrián Cedeño | Equipo |
| Prof. Maglis Camacho | Tutora |

**Repositorio:** `https://github.com/Burmistrov4/inces-lms` (rama `main`).
**Admin del sistema:** `lorenzo-roca11@hotmail.com` (correo con guion; el guion
es real — no es errata).

### 2. El problema real que resuelve

El centro lleva su gestión académica (inscripciones, cuadrante de clases,
asistencia, entregas de tareas, planillas) en papel y planillas sueltas. El LMS
digitaliza el ciclo del aprendiz y del docente, y **alimenta** al sistema
institucional **HACER** (la plataforma nacional del INCES) mediante exportaciones
en formato definido.

**Frontera del producto (decisión explícita, no olvido):**

- El LMS **alimenta a HACER, no lo sustituye**.
- **No emite certificados.** El módulo M9 (Certificados/QR) fue **descartado del
  alcance** (ADR, 2026-09-12). No reintroducir.
- La **verificación de identidad** es un procedimiento presencial del centro (con
  cédula). El software no lo sustituye ni finge un autoservicio seguro.

### 3. Los roles

| Rol | Cómo se obtiene | Qué puede |
|---|---|---|
| **estudiante** | Rol por defecto del auto-registro (ADR-008: el auto-registro **nunca** otorga otro rol) | Ver su horario, inscribirse, entregar tareas, marcar asistencia, editar su perfil (nombre y apellido) |
| **docente** | Por **invitación** de un administrador (token de un solo uso; el docente fija su contraseña al activar) | Abrir sesiones de asistencia QR, ver sus clases y guardias, publicar anuncios/tareas, calificar y devolver entregas, gestionar sus archivos |
| **admin** | Promoción manual/administrativa (nunca automática). El cambio de rol se hace desde el cPanel | Todo lo anterior + el cPanel: módulos, parámetros, usuarios, catálogo de la planilla, ocupación, exportaciones, auditoría |

Un cuarto actor, **aspirante**, es la ficha de quien se está inscribiendo
(tabla `aspirantes`); al completar el registro ya tiene perfil de estudiante.
La distinción importa: la cédula vive en `aspirantes`, **no** en `profiles`, y de
eso sale una deuda abierta (§ `02`, login con cédula).

### 4. Los módulos del sistema

El sistema es **modular por diseño**: cada módulo es una fila en la tabla
`system_modules` con su interruptor (`habilitado`), su orden, su categoría y su
lista de roles permitidos. El administrador enciende y apaga módulos desde el
cPanel **sin desplegar**, y la API rechaza con `403 MODULO_DESHABILITADO` las
rutas de un módulo apagado.

| Clave | Módulo | Estado (2026-10-09) |
|---|---|---|
| `m0_cpanel` | Administrador Maestro (núcleo) | 🟢 encendido, **protegido** (no se puede apagar) |
| `m1_onboarding` | Autenticación y onboarding | 🟢 encendido |
| `m2_curriculo` | Currículo y pensum (programas, materias, secciones) | 🟢 encendido |
| `m3_cuadrante` | Cuadrante, aulas, lapsos, guardias | 🟢 encendido |
| `m4_inscripciones` | Inscripciones y cupos (+ planilla y exportación HACER) | 🟢 encendido |
| `m5_archivos` | Almacenamiento de archivos en R2 | 🟢 encendido |
| `m6_aula_virtual` | Aula virtual: anuncios, tareas, entregas, calificaciones | 🟢 encendido |
| `m7_asistencia` | Asistencia por QR en vivo | 🟢 encendido |
| `m6_asistencia` | (fila heredada, sin rutas cableadas) | ⚪ apagado |
| `m7_calificaciones` | Calificaciones formales | ⚪ apagado |
| `m8_pasantias` | Pasantías | ⚪ apagado |

**M8 (pasantías) y M9 (certificados) están fuera del alcance actual.** M8 tiene
diseño en el plan maestro pero no está construido.

### 5. Decisiones de producto que definen el carácter del sistema

Están **tomadas y verificadas**; no son preferencias reversibles sin una
decisión nueva de Lorenzo:

1. **Autenticación sin correo externo.** La recuperación de contraseña y la
   activación de docentes son **flujos internos completos**, independientes de
   Resend, SMTP, correo y SMS. El aspirante se registra y entra directo
   (`mailer_autoconfirm = true` en Supabase). Resend queda relegado a
   notificaciones externas opcionales —y su integración está bloqueada
   (HTTP 401, falta dominio propio verificado).
   - Recuperación: código de **12 caracteres** (alfabeto sin `0/O/1/I/L`,
     ~59 bits), se muestra **una vez**, en la base sólo su **SHA-256**, 30 min
     de vida, un solo uso, emitir otro anula el anterior; canjearlo fija la
     contraseña y **cierra todas las sesiones** abiertas.
   - Invitación docente: token de un solo uso cuyo consumo es **atómico**
   (se reclama antes de crear la cuenta, para que dos activaciones simultáneas
   no creen dos cuentas), con **revocar** y **renovar**.
2. **La asistencia (M7) funciona por dos vías**: el QR que caduca cada 15
   segundos (proyectado por el docente) y la escritura manual de los seis
   dígitos. El servidor resuelve la sesión a partir del código; el alumno nunca
   lee `attendance_sessions`. El panel deja preparado el hueco del lector de
   cámara (`mobile_scanner` ya está en dependencias; la validación en dispositivo
   físico es el único pendiente de M7).
3. **El motor de "bids" de inscripciones existe pero nace apagado**
   (`habilitar_sistema_bids = false`): con bids apagados, una solicitud con cupo
   libre entra directo a `ENROLLED`; sin cupo, a la cola (`WAITLISTED`).
   **Encenderlo es decisión de Lorenzo**, no del que llegue.
4. **El estado de una matrícula nunca se borra**: `renunciar_cupo` deja
   `DROPPED` como historial. Archivar (no borrar) es el patrón del sistema
   (`is_active = false` en aulas, secciones, programas).
5. **Los archivos pesados van a Cloudflare R2**, no a la base. Supabase guarda
   sólo la metadata (`r2_key`). Tope por defecto: 10 MB por archivo, 10 archivos
   por entidad, configurables desde el cPanel sin desplegar.

### 6. A quién le habla el sistema

- **Portada pública** (`/` sin sesión): presenta el centro y la oferta de cursos
  libres.
- **Login / registro** (`/login`, `/inscripcion`): el aspirante se inscribe con
  su ficha completa; el formulario se **renderiza desde un catálogo en base**
  (`inscripcion_campos`), de modo que añadir o marcar campos obligatorios es
  configuración, no código.
- **Dashboards por rol** con menú lateral adaptativo (cajón por debajo de
  900 px).
- **cPanel** (admin): secciones por categoría, cada una con su panel.

### 7. Contexto que condiciona el diseño (Venezuela)

- **Cortes eléctricos.** La arquitectura es **dual Cloud/Local por diseño**
  (ADR-009): el mismo artefacto corre en la nube (free tiers) y en un servidor
  local vía variables de entorno y `docker-compose`. Las tareas programadas
  viven en GitHub Actions, **no** en la máquina de nadie, porque la máquina no
  siempre está encendida.
- **Presupuesto cero.** Todo el stack elegido vive en capas gratuitas
  suficientes para el volumen de un CFS: Supabase free (500 MB), R2 (10 GB),
  Render free, Cloudflare Pages, GitHub Actions.
- **Conectividad irregular en el aula.** De ahí que el lector de QR use la
  variante **empaquetada** de MLKit (modelo dentro de la app, funciona sin red)
  y que el canal en vivo de asistencia sea un WebSocket unidireccional que
  evita el polling.

## 02 — Estado actual del sistema

> **Regla del proyecto:** este documento envejece. Cada cifra lleva la fecha en
> que se midió. Si vas a tomar una decisión con una de estas cifras, **vuelve a
> medirla** con los comandos de `07_MAPA_Y_COMANDOS.md`.

### 1. Producción (verificado 2026-10-10)

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

### 2. Base de datos en la nube

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

### 3. Estado de la verificación (todo medido, nada supuesto)

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

### 4. Lo que funciona y está demostrado (selección)

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

### 5. Abierto — pendientes reales (con su criterio de cierre)

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

### 6. Cerrado — no reabrir sin medir

Autenticación sin Resend (códigos internos + ciclo de invitación); P0 /
Usuarios y Roles / los ocho módulos; planilla Excel/PDF/HACER; M3 y M4
completos; M6 ciclo completo; el arnés local de E2E con `CI=true`; la corrección
del panel de invitaciones (crasheaba por altura no acotada dentro del acordeón,
2026-10-10, desplegada a producción). El historial de deudas D1–D29 está en
`08_GLOSARIO.md` y en `ESTADO_DEL_SISTEMA.md` §6.

## 03 — Stack tecnológico

> Cada tecnología lleva su versión medida y **el porqué** de la decisión. Las
> decisiones registradas (ADR) son vinculantes: cambiarlas es una decisión de
> arquitectura, no una preferencia de implementación.

### 1. Mapa de capas

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

### 2. Frontend — Flutter Web

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

### 3. Backend — Node/TypeScript con Fastify

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

### 4. Base de datos — Supabase (PostgreSQL 17.6)

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

### 5. Almacenamiento — Cloudflare R2

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

### 6. CI/CD y producción

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

## 04 — Arquitectura

### 1. El dibujo completo

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

### 2. Frontend — estructura y responsabilidades

#### Pantallas (selección con su hueco en el sistema)

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

#### Contratos de UI aprendidos de bugs reales (no romper)

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

### 3. Backend — superficie HTTP

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

### 4. Base de datos — el modelo, por dominio

#### Identidad

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

#### Oferta académica (M2/M3)

- `programs` (carreras y cursos libres; absorbió a `cursos` en D12),
  `subjects` (banco global de materias), `program_subjects` (el pensum).
- `sections` (rediseñada en D13), `enrollments` (matrículas y sus cuatro
  estados: `ENROLLED`, `WAITLISTED`, `PENDING_BID`, `DROPPED`).
- `academic_periods` (catálogo de lapsos), `classrooms` (aulas, talleres y
  zonas —una zona es una fila con `capacity = 0`—), `teacher_duties`
  (guardias), `schedule_slots` (el cuadrante).

#### Infraestructura del sistema

- `system_modules` (interruptores), `system_settings` (parámetros),
  `config_audit_log` (auditoría append-only de la configuración).
- `teacher_invitations` (invitaciones; se guarda el **hash**, con revocar y
  renovar), `auth_logs` (trazas de acceso), `schema_migrations` (libro mayor
  de migraciones con checksum), `password_resets` (códigos de recuperación;
  **sólo lectura para admin, sin política de escritura**: su único camino de
  entrada es `service_role`).

#### Aula (M6) y asistencia (M7)

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

### 5. La RLS en una página (la matriz que decide todo)

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

### 6. El sistema de módulos, en funcionamiento

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

### 7. Tiempo real (M7)

Canal **unidireccional** servidor → cliente por `GET /api/v1/asistencia/rt`:
el tablero del docente recibe un evento por cada marca, sin polling. El
estudiante marca por REST, así que un cliente no puede colar una marca por el
canal. Se suscribe con el mismo JWT de Supabase que usa REST. El upgrade pasa
por el router normal de Fastify (por eso los hooks —y la guardia de módulo— lo
alcanzan).

## 05 — Ciclo de vida: cómo nace, se verifica y se despliega un cambio

### 1. El ritmo de trabajo (el contrato con Lorenzo)

1. **Diagnóstico y plan ANTES del código.** Se mide el estado real (leer el
   código, correr el comando, verificar la hipótesis) y se presenta el plan.
2. **Luz verde explícita por fase.** No adelantarse: cada fase se cierra con
   evidencia antes de abrir la siguiente.
3. **Cada decisión arquitectónica se explica con su porqué** (Lorenzo está
   aprendiendo y necesita criterio, no dependencia).
4. **Los bugs se señalan con archivo y línea**, sin endulzar.
5. **Las premisas de un encargo también se miden.** Un encargo no es una
   medición: es una hipótesis con formato de instrucción. El proyecto ya recibió
   uno con tres premisas falsas (decía «backend FastAPI con boto3»; es Fastify,
   y no hay un solo `.py`).

### 2. La vida de un cambio, paso a paso

#### Paso 0 — Medir el punto de partida

- `git status --short --branch` y `git log -1` **antes** de editar.
- Releer el documento que se va a editar **justo antes** de editarlo: puede
  haber otro agente trabajando en el mismo archivo.
- Verificar que la premisa del cambio es cierta (leer el código, no el
  roadmap).

#### Paso 1 — La migración (si el cambio toca el esquema)

- Nombre: `YYYYMMDDNNN_descripcion.sql` en `supabase/migrations/`, en orden.
- **NUNCA editar una migración ya aplicada.** Cambia su checksum y el libro
  mayor grita deriva. Se escribe otra que la corrija.
- **Toda autocomprobación dentro de una migración debe ser hermética**: se
  prueba inspeccionando catálogos (`pg_proc`, `pg_policies`) o llamando
  funciones puras con valores ficticios, **nunca** leyendo filas que nadie
  garantiza que existan (una base nueva tiene `sections` y `profiles` vacías:
  esa no-hermeticidad dejó el validador SQL rojo horas sin que nadie lo supiera
  —D20—).
- Aplicar a la nube: `node supabase/apply-migrations.mjs` (usa la Management
  API por HTTPS; la conexión directa a Postgres es sólo IPv6, D10). **Aplicar
  en producción requiere autorización explícita, revisión del SQL y plan de
  recuperación.** El modo `--check` es de sólo lectura y es el que se corre
  siempre primero.

#### Paso 2 — El backend

- Contrato primero: esquemas Zod en `src/http/esquemas.ts`. El documento
  OpenAPI se **regenera** (`npm run openapi`); si la prueba del artefacto falla,
  se regenera, no se toca la prueba.
- Rutas nuevas: registrar en Fastify, documentar, y **dejar que el test de
  OpenAPI las coteje en las dos direcciones** contra el árbol real.
- Las escrituras con reglas van por RPC `security definer` cuando la RLS no
  alcanza; la RPC **debe autorizar sola con `auth.uid()`**.

#### Paso 3 — El frontend

- La pantalla se monta **donde vive** en las pruebas (los paneles del cPanel,
  dentro de `ContenidoSeccion`; el panel de invitaciones, dentro del acordeón).
- Reglas de UI de `04_ARQUITECTURA.md` §2.
- Los tests de layout responsive se hacen con **widget tests a 375/768/1024/
  1280/1440 px**, no con capturas: una captura prueba un momento, un test
  protege el futuro.

#### Paso 4 — Verificar con las cinco redes (cada una ve cosas que las otras no)

| Red | Comando | Qué ve | Qué **no** puede ver |
|---|---|---|---|
| Tipos/lints Dart locales | `node devops/analizar-dart.mjs` | errores, avisos **e infos** de todo `lib/` + `test/` | El SQL, la API, el navegador |
| Flutter suite | `flutter test` (en CI si el entorno local muere) | la lógica del cliente | El SQL, la API, la red, y **el navegador** |
| SQL real | `cd supabase/tests && npm test` (PGlite) | migraciones, triggers, RLS por rol | La API, el despliegue |
| Backend | `cd backend && npm run verify` | la API completa sobre dobles | La base real, las credenciales |
| Nube / E2E | humos con `--confirmar`; `e2e/` con Playwright | la cadena de verdad: API → GoTrue → Postgres → R2 → navegador | Lo que a nadie se le ocurrió probar |

**Regla de oro de la verificación:** una red sólo vale lo que vale su verde.
Un verde producido por un reintento mide el reintento. Una prueba cuyo montaje
no puede hacer lo que dice es un no-op silencioso. **La pregunta que caza
cualquier verde hueco: «¿qué tendría que ser distinto en el mundo para que esta
prueba fallara?»**

#### Paso 5 — Commit y push

- **El push es el respaldo.** Un commit local no sobrevive a un `.git` dañado
  (ya pasó: se recuperó porque todo lo commiteado estaba subido).
- Dos ediciones al mismo archivo en un mismo mensaje: **una se pierde**. Ir de
  una en una.
- No commitear `.env`, `.env.json`, `build/`, `e2e/informe/`, ni archivos
  `_*.spec.ts` de diagnóstico.

#### Paso 6 — CI (el verificador independiente)

Con el push corren los workflows de `03_STACK_TECNOLOGICO.md` §6. **`in_progress`
no es PASS**: se espera el veredicto del SHA exacto. Cuando el único sitio donde
algo se reproduce es la CI, **la CI es el banco de pruebas**.

#### Paso 7 — Despliegue a producción

El procedimiento oficial completo está en `docs/PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md`
(revisado 2026-10-10). Resumen:

1. **Frontend:** workflow `web_bundle.yml` → compila con `API_BASE_URL` de
   producción → valida el artefacto (existen `index.html`, `main.dart.js`,
   `_headers`; el bundle contiene la API de producción y **no** contiene
   `localhost:3001`) → `wrangler pages deploy --project-name=inces-lms`.
   **Prohibido publicar un bundle compilado con la plantilla.**
2. **Backend:** Render despliega solo desde `main`; se confirma el deploy del
   SHA esperado y `GET /salud` → 200. Un `render.yaml` no demuestra que el
   despliegue terminó.
3. **Base de datos:** `apply-migrations.mjs --check` primero; aplicar **sólo**
   con autorización.
4. **Verificación posterior:** frontend público 200, bundle correcto, CORS
   desde el origen real, login y un flujo representativo con cuenta de prueba
   autorizada. **Registrar evidencia** (SHA, IDs de deploy, respuestas HTTP) y
   declarar explícitamente lo que **no** se pudo verificar.

### 3. El ciclo de vida de los datos

#### Migraciones vs. semilla vs. humo (tres papeles distintos, no mezclar)

| Concepto | Qué hace | Dónde corre |
|---|---|---|
| **Migración** | Cambia el **esquema** (tablas, políticas, funciones). Nunca siembra aulas ni fechas de lapso: sería fabricar dato institucional | `supabase/migrations/`, libro mayor con checksum |
| **Semilla** (`sembrar-datos.mjs`) | Crea datos de ejemplo **persistentes** para que el sistema tenga con qué demostrarse: 1 carrera, 3 materias, 2 aulas `[SEMILLA]`, 1 sección, 1 docente + 3 estudiantes, 3 matrículas, 2 clases, 1 anuncio publicado + 1 tarea en borrador. Idempotente; `--limpiar` la deshace **por marcador** (`SEM-`, `[SEMILLA]`, `@semilla.invalid`; **no inventa cédulas**) | a mano, nunca al desplegar |
| **Humo** (`humo-*.mjs`) | Verifica contra la infraestructura real, **crea y purga** (cuentas `humo-*@ejemplo.invalid`, purga por prefijo, residuo medido 0/0/0) | a mano o en el ciclo de cierre; fuera de CI salvo la suite E2E |

**Regla de la semilla:** insertar cada fila en un estado que **no derive** otras
filas. Un anuncio publicado no deriva nada; una tarea publicada **sí** (el RPC
crea una entrega por matrícula): por eso la tarea se siembra en `BORRADOR`.

**Regla del humo:** un sembrado y un humo son contratos **opuestos**, y por eso
son archivos distintos.

#### La limpieza

Las limpiezas borran **por marca**, no por id recordado: sobreviven a un
proceso que muere a mitad y no dejan residuo entre corridas. El orden de
borrado respeta las FK `on delete restrict` **y la simetría de la Regla 1 de
M2**: al sembrar, el programa se activa *después* de cargarle el pensum; al
limpiar, se desactiva *antes* de vaciárselo.

#### Auditoría

Todo cambio de módulo o parámetro queda en `config_audit_log` (append-only, sin
camino de escritura para nadie salvo el trigger), y todo acceso en `auth_logs`
(IP, instante, éxito/fallo; escritura sólo por el backend). **Ni el admin puede
insertar una traza a mano**: hay una prueba que lo comprueba con JWT real.

### 4. El ciclo de vida de una estimación (rendimiento)

El proyecto mide el rendimiento por rol con instrumentos propios (5–7 muestras +
1 de calentamiento, mismo JWT, mismo puerto) y **mide la salud de la ruta en el
mismo puerto que mide** (un `3001` sirviendo un `dist` viejo produjo una vez una
medida inválida). El suelo conocido hoy: el hook de autenticación pesa ~240 ms
(verificación de token + perfil, ya en paralelo) y `cuadrante`, con tres
esperas secuenciales, está en ~679 ms.

### 5. Ciclo de vida documental (por qué este paquete existe)

- `ESTADO_DEL_SISTEMA.md` es el documento vivo que **manda** sobre los demás
  cuando se contradicen.
- La memoria del proyecto vive en `.workbuddy-ai/memory/` (índice + `temas/` +
  logs diarios).
- **La deriva documental se trata como una deuda:** una nota que dice «falta
  hacer X» envejece en la dirección peligrosa —provoca trabajo (el proyecto
  tiene documentado el caso de un aviso que pedía reaplicar cuatro migraciones
  ya aplicadas). **Una nota que dice «falta» hay que volver a medirla, no volver
  a creerla.**
- **La frontera entre deriva e historia:** las tablas de medición fechadas y los
  registros de fallos **conservan** el valor viejo (son historia); lo que se
  corrige son los comandos, las URL para abrir y los valores por defecto.

## 06 — Reglas y lecciones (léelo antes de tocar nada)

> Este archivo es el destilado de errores que **costaron caros**. Cada regla
> tiene su medición detrás. No son estilo: son facturas ya pagadas.

### 1. Las reglas load-bearing

1. **Medir antes de afirmar.** «No está» se mide, no se deduce. Una cifra de
   contraste no entra en un comentario si no sale del medidor. **Un volcado
   truncado no es evidencia.**
2. **«No se puede en este entorno» caducan como las cifras.** `flutter test` se
   dio por imposible dos veces y dos veces se midió que sí corría (con la
   receta exacta). Antes de repetir un «no se puede», medirlo otra vez. Y cuando
   la hipótesis es «lo bloquea el sandbox», hay que probarlo **fuera** del
   sandbox antes de seguir creyéndolo: es la única prueba que lo distingue de
   un fallo del host.
3. **Nunca editar una migración aplicada.** El libro mayor detecta deriva por
   checksum. Se añade otra.
4. **La frontera de autorización es la RLS, no la API** (ADR-003). Una
   `security definer` autoriza por sí misma con `auth.uid()`: la RLS **no** la
   protege (R-20).
5. **Dos ediciones al mismo archivo en un mensaje: una se pierde.** Y puede
   haber **otro agente** editando los mismos documentos: releer justo antes de
   editar; ediciones aditivas y acotadas.
6. **El push es el respaldo.**
7. **Un comentario que explica el porqué es una afirmación, y su mecanismo se
   mide.** Un comentario falso viaja igual que una cifra inventada. Este
   proyecto acumula cinco casos de comentarios que se justificaban a sí mismos.

### 2. El entorno de desarrollo: lo que hay que saber el minuto cero

#### El `CreateFile failed 231` (`ERROR_PIPE_BUSY`)

- **Qué es:** el VM de Dart, al lanzar su primer subproceso, intenta crear una
  tubería *nombrada* y falla. Mueren `flutter test`, `flutter build web`,
  `dart analyze`, `flutter pub get`.
- **Historia medida, y por qué importa:** bloqueó de forma **sostenida** el
  2026-09-27 y el 2026-10-10 (el build murió 6 de 6 veces en `dart2js`); **no**
  se reprodujo el 2026-10-09 sesión 2 (build web en 157 s, suite completa
  verde). **Moraleja: es intermitente y pertenece al entorno, no al proyecto.
  Mídelo antes de citarlo, en cualquier dirección.**
- **La respuesta cuando bloquea: CI, no insistir en local.** `flutter_ci.yml` y
  `e2e.yml` corren en `ubuntu-latest`, donde el problema no existe.
- **Sustitutos locales que sí funcionan:** `node devops/analizar-dart.mjs`
  (tipos y lints de `lib/` + `test/`, lanzando el servidor de análisis
  directamente con `dartaotruntime.exe`; **su listón incluye las `info`**, igual
  que `flutter analyze`), y `devops/` tiene además utilidades de apoyo.
- **Nunca correr `dart format`** en este proyecto. Y atención: `dart format`
  comprueba **sintaxis, no tipos** —un identificador inexistente lo atraviesa
  entero.
- **En este equipo, desde Node: `spawn` y nunca `spawnSync`** (`spawnSync`
  falla con `EBUSY`: la misma familia de tuberías).
- **`build/web` local puede quedar congelado** en un artefacto viejo. Antes de
  auditar o publicar, comprobar de dónde viene: si hay archivos `.dart` más
  nuevos que `main.dart.js`, el build no es de hoy. **No publicarlo.**

#### La receta de dos piezas (histórica, sigue siendo útil para otras órdenes de Flutter)

```
env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
  'NO_PROXY=127.0.0.1,localhost' 'no_proxy=127.0.0.1,localhost' \
  "PROGRAMFILES(X86)=C:\Program Files (x86)" flutter …
```

1. `PROGRAMFILES(X86)`: en Git Bash no existe (sin ella:
   `%PROGRAMFILES(X86)% environment variable not found`).
2. Proxy desactivado: `HTTP_PROXY`/`HTTPS_PROXY` apuntan a `127.0.0.1:61458` e
   interceptan el WebSocket de loopback de `flutter_tester`.

**Dar sólo una de las dos piezas hizo concluir una vez que era imposible.** Con
las dos corrió 365/365 ese mismo día.

#### Flutter Web y Playwright (trampas medidas)

- CanvasKit **no expone widgets como DOM**: `getByRole`/`getByText` miden 0.
  Hay que pulsar `flt-semantics-placeholder` con `dispatchEvent` y usar
  `flt-semantics[aria-label=…]` / `getByLabel`. El `<canvas>` está en el shadow
  DOM de `flt-glass-pane`: `document.querySelectorAll('canvas')` da 0 con la app
  funcionando.
- `find.textContaining` busca en **toda** la pantalla: un subtítulo puede
  encontrarse dos veces («Matriculado» dentro de «Matriculados»). Las
  aserciones de texto se escriben **exactas** siempre que se pueda.
- `TextField` con `maxLength` **trunca en silencio** —fue el mecanismo exacto
  que dejó muerta la pantalla de asistencia del alumno (D21): el campo admitía
  6 caracteres y el parser exigía 43. El campo de código **no lleva
  `maxLength` a propósito**, y una prueba afirma que sigue siendo `null`.
- El bundle E2E local se corre con **`CI=true`**: sin él, `reuseExistingServer`
  reutiliza un servidor estático zombi de una corrida anterior y la suite muere
  a mitad con `ERR_CONNECTION_REFUSED`.
- **La guardia del bundle:** `e2e/playwright.config.ts` falla de inmediato si
  `main.dart.js` contiene los marcadores de la plantilla (`<project-ref>`,
  `<clave-publicable>`). Un bundle compilado con `dart-define.example.json`
  apunta a una URL inválida y el login falla **sin emitir ninguna petición**: el
  síntoma es «el formulario se envía y no pasa nada, ni error ni red». Medido
  el 2026-10-09 con nueve discriminadores.

### 3. Base de datos y autorización — las trampas finas

- **Una política RLS que llama a una función con `EXECUTE` revocado es
  inalcanzable** (`42501` antes de decidir nada). PostgreSQL evalúa el `EXECUTE`
  contra el rol que consulta. Fue D27: el alumno no podía marcar asistencia
  **nunca, por ningún camino**, y doce pruebas negativas estaban verdes por el
  mismo error. **No conceder `EXECUTE` si la función es un oráculo**
  (`asistencia_codigo_vigente` lo era: fuerza bruta de seis dígitos).
- **`revoke execute … from anon, authenticated` NO basta:** PostgreSQL concede
  `EXECUTE` a `PUBLIC` por defecto y el permiso se **hereda**. Hay que revocarlo
  de `PUBLIC` y concederlo a `service_role`. Medido en la nube el 2026-10-09.
- **Un `SQLSTATE` solo no distingue la causa:** `42501` puede ser falta de
  `GRANT` *o* RLS. Comprobar ambas, y **como qué rol** corre la prueba: probar
  un rechazo con un admin no prueba nada.
- **`information_schema` miente por omisión:** sólo muestra lo que el rol
  actual puede ver. Preguntar por claves ajenas que apuntan a `auth.users`
  devuelve **cero filas, no un error** —así se escaparon cuatro claves, una con
  `CASCADE` sobre `enrollments`. Usar **`pg_constraint`**. **Un cero se lee igual
  que «no hay nada»: peor que un error.**
- **`service_role` se salta la RLS, pero NO los triggers.** Un script con la
  clave secreta no puede escribir cualquier estado.
- **RLS es por fila; no puede ocultar una columna.** Para eso, GRANT a nivel de
  columna —y entonces `has_table_privilege(...,'SELECT')` es **false**.
- **`schema_migrations.version` guarda el nombre SIN `.sql`.** Comparar contra
  el nombre del archivo fabrica un «pendiente» falso.
- **`or=()` de PostgREST: columna y operador se separan con PUNTO**
  (`subject_id.in.(…)`), no con igualdad.
- **`PATCH` sin `Prefer: return=representation` responde 204 y sin cuerpo**: la
  escritura ocurre y no hay nada que leer para comprobarla.
- **Las fechas van a Postgres como `YYYY-MM-DD`**, no timestamp ISO: un ISO
  completo desplaza un día por zona horaria y rompe el CHECK de mayoría de edad.
- **Las vistas llevan `security_invoker`**: sin él corren con los privilegios de
  su dueño y se saltan la RLS de las tablas base (un estudiante vería el
  cuadrante de todo el centro).
- **El validador SQL corre como el dueño de las tablas**, y el dueño se salta
  la comprobación de `EXECUTE`: ése es su punto ciego (así vivió R-20). Hay una
  sección que escribe como `authenticated` con claims de admin para taparlo.
  **Si añades una prueba de trigger, pregúntate como qué rol está escribiendo.**
- **La conexión directa a Postgres es sólo IPv6** (D10): `supabase db push`
  falla con `ENETUNREACH`. La vía es `apply-migrations.mjs` por la Management
  API.

### 4. Pruebas — los verdes que no midieron

- **Una prueba cuyo montaje no puede hacer lo que dice es un no-op silencioso.**
  La prueba que fijaba que `m7_asistencia` no lleva guardia apagaba el módulo
  con un `.map` sobre una fila que **no existía** en la semilla: el verde medía
  el módulo **encendido** (D25). Arreglo: la fila entra en la semilla con los
  valores medidos en la nube y **la prueba afirma su propia premisa** antes de
  usarla. Verificado **por mutación** (renombrar la clave hace fallar la
  guarda): un guardián que nunca se ha visto fallar no se sabe si funciona.
- **La imagen simétrica: un rojo que no medía** (D26). Una prueba leía el reloj
  **dos veces** para el mismo código QR de 15 s: podía fallar por un cambio de
  ventana sin que nada del código estuviera mal.
- **Un doble debe reproducir CÓMO falla, no sólo qué devuelve.** El doble en
  memoria no puede reproducir el 416 de PostgREST, ni la colación exacta, ni el
  `42501` de la RLS: por eso cada repositorio nuevo necesita su **humo contra
  la base real**. (Caso real: el arnés devolvía el **mismo objeto** para
  `reposAdmin` y `reposDePeticion`, y un defecto real de permisos «funcionaba»
  en memoria; sólo se vio contra el motor.)
- **Un doble más estricto que el original convierte un arreglo correcto en un
  fallo de prueba** —y tienta a revertir el arreglo.
- **Una prueba puede consagrar el defecto como contrato** sin que nadie lo note
  (una prueba asertaba el 400 de un bug con un comentario que lo justificaba).
  Al arreglar un defecto, **buscar la prueba que lo daba por bueno.**
- **Probar cada capa por separado no prueba la composición**: un valor por
  defecto se arregló en el SQL y el esquema Zod tenía **su propio** `.default`
  que lo anulaba desde arriba. Al arreglar uno, buscar el mismo valor en las
  capas superiores.
- **Un verificador que no distingue «no hay nada» de «no estoy escuchando» es
  peor que no tenerlo** (un falso verde con el mismo aspecto que uno de verdad).
  Al escribir un verificador, comprobar primero que **ve** algo conocido —una
  sonda con un error deliberado— antes de creerle un verde.
- **Un verificador local vale lo que vale su primera pasada real.** El de Dart
  filtró las `info` durante días: verde local, CI rojo. El listón del
  verificador es el del CI: error, aviso **e info**.
- **Correr la suite COMPLETA (`flutter test`), no sólo el archivo tocado**: en
  el cierre de M2 los archivos sueltos daban verde y la suite completa destapó
  6 fallos.

### 5. Documentación y proceso

- **Un número escrito en dos sitios envejece siempre en el que nadie volvió a
  ejecutar.** Los totales viven en un solo sitio, con fecha.
- **Un «pendiente» viejo provoca trabajo** (reaplicar migraciones ya aplicadas,
  reescribir pruebas que existen). Volver a medirlo, no volver a creerlo.
- **Un documento puede contradecirse consigo mismo, y la contradicción es la
  señal.** Al corregir una afirmación, buscar la contraria en todo el documento:
  se busca la **frase**, no el archivo que uno recuerda.
- **Cuando un fallo de CI no se puede leer desde fuera, ése es el primer bug**
  (los registros de job exigen permisos de administración; las anotaciones no,
  y hay que publicarlas).
- **Medir y commitear en momentos distintos sobre un árbol que otro trabaja
  invalida la medición:** correr la suite completa **después** de la última
  edición, no antes.
- **`WebFetch` cachea por URL 15 minutos:** sondear la misma URL devuelve datos
  congelados. Cambiar la URL entre sondeos.
- **GitHub enmascara los secretos en los registros.** Nunca imprimir tokens;
  el `sbp_` de la Management API vive en `backend/.env` (gitignored) y se lee de
  ahí, no de la línea de órdenes.
- **La fecha del reloj inyectado puede estar mal:** verificar con `date` antes
  de sacar conclusiones de una marca de tiempo.

### 6. Si llegas con la misión de «arreglar X»

1. **Verifica la premisa** con código y comandos (el proyecto tiene un caso
   documentado de misión con tres premisas falsas).
2. **Lee primero** `02_ESTADO_ACTUAL.md` §5 (pendientes reales) y
   `08_GLOSARIO.md` (puede que X sea una deuda **cerrada** con número D/R).
3. **Respeta las puertas:** aplicar migraciones en producción, tocar RLS,
   cambiar CORS/secretos/dominios y promover administradores **requieren
   autorización explícita** de Lorenzo.
4. **Cierra la deuda en el documento el mismo día que en el código**, con su
   evidencia.

## 07 — Mapa del repositorio y comandos

### 1. Mapa de carpetas

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

### 2. Comandos de verificación (los que hay que saber de memoria)

#### Frontend

```bash
# Tipos + lints locales (incluye infos; no necesita que arranque el VM)
node devops/analizar-dart.mjs

# Suite completa (si el entorno local lo permite; si no → CI)
flutter test

# Compilar (config en tiempo de compilación: --dart-define-from-file)
flutter build web --release --dart-define-from-file=.env.json
```

#### Backend

```bash
cd backend
npm ci                 # instala exactamente el lockfile
npm run verify         # typecheck + lint + test  ← la puerta diaria
npm run build          # compila
npm run openapi        # regenera el contrato (si la prueba del artefacto falla)
```

#### SQL

```bash
cd supabase/tests && npm install && npm test    # PGlite: migraciones + RLS + triggers
```

#### Contra la nube (sólo lectura los dos primeros; el token vive en backend/.env)

```bash
TOKEN="$(sed -n 's/^SUPABASE_ACCESS_TOKEN=//p' backend/.env | tr -d '\r')"
SUPABASE_ACCESS_TOKEN="$TOKEN" node supabase/apply-migrations.mjs --check   # 0 pendientes / 0 deriva
SUPABASE_ACCESS_TOKEN="$TOKEN" node supabase/verificar-esquema.mjs          # esquema desplegado
SUPABASE_ACCESS_TOKEN="$TOKEN" node supabase/contar-catalogo.mjs            # recuento vigente
```

#### Humos (escriben en la nube y purgan; usar `--confirmar`)

```bash
node backend/test-humo.mjs                        # API real → Supabase real
node supabase/humo-invitaciones.mjs --confirmar   # ciclo de invitación (34 aserciones)
node supabase/humo-recuperacion.mjs --confirmar   # recuperación interna (27 aserciones)
node supabase/humo-cuadrante.mjs --confirmar      # triggers anti-colisión de M3
node supabase/humo-archivos.mjs --confirmar       # ciclo R2 real
```

#### E2E

```bash
cd e2e
CI=true E2E_ARRANCAR_BACKEND=0 E2E_WEB_DIR=../build/web npx playwright test
# el ciclo que MUTA datos (crea/publica tareas) se corre aparte y con limpieza:
E2E_PERMITIR_CICLO_MUTANTE=1 E2E_WEB_DIR=../build/web npx playwright test tests/aula_virtual_ciclo.spec.ts
node supabase/limpiar-ciclo-aula.mjs --confirmar --desde "<ISO de la corrida>"
```

#### Semilla y mantenimiento

```bash
node supabase/sembrar-datos.mjs --confirmar          # siembra (idempotente)
node supabase/sembrar-datos.mjs --limpiar --confirmar # deshace por marcador
npx tsx backend/scripts/limpiar-pendientes.mts        # simulación; --confirmar borra
npx tsx backend/scripts/probe-r2-cors.mts             # exit 0 = CORS del bucket ok
```

### 3. Configuración y secretos (nombres, nunca valores)

| Variable | Dónde | Para qué |
|---|---|---|
| `SUPABASE_URL` / `SUPABASE_ANON_KEY` | `backend/.env`, `.env.json` (raíz), secretos de GitHub | Cliente público de Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | `backend/.env` + Render + GitHub | Backend: caminos donde la RLS no alcanza. **Se deja vacía cuando falta** (un marcador de texto pasaría Zod y fallaría más tarde y peor) |
| `SUPABASE_ACCESS_TOKEN` (sbp_) | `backend/.env` | Management API: migraciones, esquema, catálogo. **Nunca al repo ni a la línea de órdenes** |
| `CORS_ORIGINS` | `backend/.env` + Render | Origen del frontend (`https://inces-lms.pages.dev` + locales: `localhost:8090` **e** `127.0.0.1:8090` —para el navegador son orígenes distintos—) |
| `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` / `R2_BUCKET` / `CLOUDFLARE_ACCOUNT_ID` | `backend/.env` + Render + GitHub | Almacenamiento R2 |
| `E2E_*` (6: URL, ANON_KEY, SERVICE_ROLE_KEY, ADMIN_EMAIL, ADMIN_PASSWORD, SECCION) + `E2E_ALUMNO_*`, `E2E_DOCENTE_*` | secretos de GitHub | Suite E2E. **La suite falla a propósito si faltan**: un verde con pruebas saltadas sería peor que un rojo |
| `SUPABASE_JWT_SECRET` | **ausente** (del propietario) | Verificación local del JWT (evitaría el viaje a GoTrue) |

### 4. Dónde está cada verdad

| Pregunta | Dónde mirar |
|---|---|
| ¿Está esto construido? ¿Con qué pruebas? | `ESTADO_DEL_SISTEMA.md` §5–§7 |
| ¿Qué deuda hay y su número? | `08_GLOSARIO.md` y `ESTADO_DEL_SISTEMA.md` §6 |
| ¿Cómo se despliega? | `docs/PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md` |
| ¿Qué decide cada ADR? | `docs/PLAN_MAESTRO_STACK_DEFINITIVO.md` y `03_STACK_TECNOLOGICO.md` |
| ¿Qué trampas hay al tocar X? | `.workbuddy-ai/memory/temas/` (por tema: api-backend, interfaz, e2e, infraestructura, modulo2..7) |
| ¿Por qué esta regla existe? | `.workbuddy-ai/memory/temas/lecciones.md` y `06_REGLAS_Y_LECCIONES.md` |
| ¿Qué pasó el día D? | `.workbuddy-ai/memory/YYYY-MM-DD.md` (logs diarios, append-only) |

## 08 — Glosario

### 1. Deudas técnicas (D-números)

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

### 2. Hallazgos R-números (del `REPORTE_ARIA.md` y los contratos)

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

### 3. Módulos y migraciones

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

### 4. Vocabulario del proyecto

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

### 5. Siglas del stack

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
