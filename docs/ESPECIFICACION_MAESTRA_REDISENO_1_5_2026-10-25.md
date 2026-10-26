# Especificación maestra de rediseño — INCES LMS 1.5

**Fecha:** 2026-10-25 · **Origen:** tres videos de revisión (96 min) + decisión
directa de Lorenzo · **Destino:** agente de IA (antigravity)

Este documento es la **fuente única** de lo que hay que construir. La Parte V es
el megaprompt que se le entrega al agente. Todo lo demás es el contexto que
necesita para no equivocarse.

---

# Parte 0 — Resumen ejecutivo

Once decisiones. Cinco son estructurales (borran o crean algo), seis son de
comportamiento.

| # | Decisión | Tipo | Riesgo |
|---|---|---|---|
| D1 | **Eliminar el sistema de bids** (ofertas de cupo con vencimiento) | borra | **bajo** — 0 filas en producción |
| D2 | **Eliminar «Lapsos Académicos»** como nivel; queda sólo «Período» | borra | **alto** — toca 5 tablas |
| D3 | **Separar MTP y PNA** en dos pantallas distintas | reescribe | medio |
| D4 | **Tres horarios distintos**: ordinario (clases), MTP (docentes), PNA (estudiantes) | crea | alto |
| D5 | **Cupo por curso**, editable por el admin, con disponibilidad visible | reescribe | medio |
| D6 | **Rediseño agresivo** del gestor de archivos + descarga múltiple en ZIP | reescribe | medio |
| D7 | **Navegación más simple**: menos apartados, agrupados por tarea | reescribe | medio |
| D8 | **Archivar funciona**: aulas virtuales, secciones y períodos | arregla | medio |
| D9 | **Renombrar «Aula Virtual»** a algo que se encuentre en Google | renombra | bajo |
| D10 | **Cédula en el perfil** del admin y del docente | añade | bajo |
| D11 | **Eliminar el módulo «Secciones del Período»** del menú | borra | medio |

---

# Parte I — Estado medido (2026-10-25)

Números reales de la base de producción. El agente debe asumir esto, no lo que
diga la documentación antigua.

| Dato | Valor |
|---|---|
| Migraciones aplicadas | **53** |
| Perfiles | **72** (61 son `@semilla.invalid` → **11 personas reales**) |
| Programas | **7** |
| Materias | **3** |
| Secciones | **1** (`SA`, `max_capacity` 10, inactiva) |
| Períodos (`academic_periods`) | **1** (`SA26-2`, «Lapso SA26-2», activo) |
| Inscripciones | **4**, todas `ENROLLED` |
| **Inscripciones `PENDING_BID`** | **0** ← por esto D1 es de riesgo bajo |
| Registros de acceso (`auth_logs`) | **13**, todos del 10-13 de octubre (no se registran los nuevos) |
| Backend | 713/713 pruebas · 34 suites |
| Analizador Dart | 243 archivos · 0 errores, 0 avisos, 0 infos |

### Estructura que importa

```
programs (7)          code, name, type (CARRERA|CURSO_LIBRE), requires_internship, is_active
subjects (3)          code, name
academic_periods (1)  code, name, start_date, end_date, is_active, closed_at, closed_by
sections (1)          program_id, subject_id, period_code, name, max_capacity, is_active
enrollments (4)       student_id, section_id, status, bid_expires_at
```

**`sections` ya liga programa + materia + período.** Una sección *es* la
combinación de esos tres. Eso es importante para D2 y D5.

**`sections.period_code` es texto, no una clave foránea** a `academic_periods`.
Se compara por código.

### Módulos (`system_modules`)

| clave | nombre | estado |
|---|---|---|
| `m0_cpanel` | Administrador Maestro | ON |
| `m1_onboarding` | Autenticación y Onboarding | ON |
| `m2_curriculo` | Currículo y Pensum | ON |
| `m3_cuadrante` | Cuadrante y Horarios | ON |
| `m4_inscripciones` | Inscripciones y Cupos | ON |
| `m5_archivos` | Almacenamiento de Archivos | ON |
| `m6_aula_virtual` | Aula Virtual | ON |
| `m7_asistencia` | Asistencia QR en vivo | ON |
| `m7_calificaciones` | Calificaciones | ON |
| `m8_pasantias` | Pasantías | ON |

---

# Parte II — Las once decisiones, con su razón

## D1 · Eliminar el sistema de bids

**Qué es hoy.** `enrollments.status` admite `PENDING_BID`: cuando se libera un
cupo, el sistema le *ofrece* el asiento a alguien de la cola con un vencimiento
(`bid_expires_at`). Si no responde a tiempo, el cupo pasa al siguiente.

**Por qué se va.** Lorenzo: «vuela el sistema bids, eso no va y todo lo
relacionado con ello». Es un mecanismo de subasta que no corresponde a cómo
funciona un centro de formación: el cupo no se negocia, se asigna.

**Alcance medido.** 6 ocurrencias en `reglas-inscripciones.ts`, 5 en `tipos.ts`,
3 en `repos-supabase.ts`, 1 en `rutas/inscripciones.ts`, 1 en
`inscripcion_gateway.dart`, más la columna `bid_expires_at` y una RPC/trigger en
`202609190001_mod4_inscripciones.sql`.

**Riesgo: bajo.** Cero filas en `PENDING_BID` en producción. No hay datos que
migrar, sólo código que retirar.

**Qué queda en su lugar.** `WAITLISTED` (cola) → `ENROLLED` (dentro) →
`DROPPED` (fuera). Cuando se libera un cupo, **el primero de la cola entra
automáticamente**. Sin oferta, sin vencimiento, sin respuesta que esperar.

## D2 · Eliminar «Lapsos Académicos»

**Lo que hay hoy.** `academic_periods` es **una sola tabla** con `code`, `name`,
`start_date`, `end_date`, `is_active`, `closed_at`. El menú la llama «Lapsos
Académicos» y la fila existente se llama «Lapso SA26-2». **No hay dos
entidades**: «lapso» y «período» son la misma cosa con dos nombres.

**Lo que quiere Lorenzo.** Un solo concepto, llamado **Período**, con fecha de
inicio, fecha de fin y estado. Se crea uno nuevo, el anterior se archiva solo, y
el nuevo **hereda el horario** del anterior.

**Por qué.** «El lapso marcado como vigente es el que gobierna las aulas
virtuales, la asistencia y los horarios de hoy […] dejamos el período y ya […]
están de más».

**Alcance.** Renombrar el módulo, la pantalla y los textos; añadir la herencia de
horario al crear el siguiente; retirar el concepto «lapso» del vocabulario
visible. **La tabla no se borra**: `sections.period_code` la referencia por
código y otras tablas dependen de ella.

**Riesgo: alto.** Es la operación más delicada del plan. Toca esquema,
`m2_curriculo`, `m3_cuadrante`, `m4_inscripciones`, la asistencia y el aula
virtual. Debe hacerse con la matriz verde antes y después.

## D3 · Separar MTP y PNA

**Lo que hay hoy.** Un solo panel de «Guardias Docentes» con un filtro de
modalidad que mezcla las dos cosas.

**Lo que quiere Lorenzo.** Dos pantallas distintas:

- **MTP** (Maestro Técnico Productivo) = **las guardias de los docentes**. Quién
  cubre qué taller y qué espacio, por día y turno. Nada de materias ni de
  estudiantes.
- **PNA** (Programa Nacional de Aprendizaje) = **el horario de los estudiantes
  del programa**. Qué materia, con qué docente, en qué bloque, en qué espacio.

**Por qué.** «MTP son guardia docente, muy diferente al PNA […] aquí está el PNA
y aquí está el MTP que simplemente son los roles de guardia de los profesores».
Lo dice en los **tres** videos.

## D4 · Tres horarios distintos

| Horario | Para quién | Qué muestra | Quién lo edita |
|---|---|---|---|
| **Ordinario / Normal** | Los estudiantes de cursos regulares | Curso + materia + docente + espacio, por bloque | Admin y docente |
| **MTP** | Los docentes | Guardia: docente + taller/espacio, por día y turno | Admin |
| **PNA** | Los estudiantes del PNA | Materia + docente + espacio, por bloque | Admin |

**Regla dura:** un bloque del horario ordinario **debe** tener curso; la materia
y el espacio son **opcionales**. Un bloque de MTP **no** lleva materia. Un bloque
de PNA **debe** llevar materia y docente.

**Por qué.** «El horario ordinario/normal es para las clases y el MTP es el de los
docentes y el PNA para los estudiantes de ese programa de formación, que se le
pueda asignar un profe, materia a x bloque de horario».

## D5 · Cupo por curso, no global

**Lo que hay hoy.** Dos sitios dicen cuánta gente cabe: `sections.max_capacity`
(por sección, valor 10) y un parámetro global `cupo_maximo_por_seccion` en
`system_settings`. **El global gana**, así que ajustar una sección no sirve.

**Lo que quiere Lorenzo.** El cupo se define **por curso/sección**, y el
administrador puede cambiarlo en cualquier momento. Además, la **disponibilidad**
(«quedan 3 cupos») debe verse en la pantalla del curso y en la landing.

**Por qué.** «Cupo máximo […] tenemos veinticinco […] eso no sirve […] debería ser
específico para cada curso, no puede ser para uno solo para todo».

**Decisión que falta:** qué pasa con el parámetro global. Recomendación: queda
como **valor por defecto** al crear una sección nueva, y deja de aplicarse por
encima de lo que diga la sección.

## D6 · Rediseño del gestor de archivos

**Lo que quiere Lorenzo.** Que se parezca a Google Drive: tarjetas o lista,
selección múltiple, **descargar varios archivos como un ZIP**, y una interfaz
moderna.

**Referencia que mandó:** la pantalla de Drive con 8 archivos seleccionados y el
aviso «Preparando la descarga / Comprimiendo 1 archivo».

**Qué hay que construir:**
1. **Selección múltiple** con casillas y `Shift`/`Ctrl`.
2. **Descarga en ZIP** de lo seleccionado, generada en el servidor.
3. **Vista de cuadrícula y de lista**, conmutables.
4. Barra de acciones flotante cuando hay selección (descargar, mover, borrar).
5. Miniaturas reales de imágenes y PDF.

**Nota técnica:** el ZIP se genera en el backend con `archiver` y se sirve con
URL firmada, o se comprime en streaming. **No comprimir en el cliente**: un
centro con equipos modestos no puede con eso.

## D7 · Navegación más simple

**Lo que dice Lorenzo.** «Cuesta ir de un apartado a otro y saber cómo gestionar
todo […] facilita de manera extrema el uso».

**Qué hay que hacer:**
1. **Agrupar por tarea**, no por módulo técnico:
   - *Preparar el período*: Período, Programas, Materias, Secciones
   - *Inscribir*: Inscripciones, Cupos, Campos de la planilla
   - *Dar clase*: Horarios, Aulas virtuales, Asistencia, Calificaciones
   - *Gestionar*: Usuarios, Archivos, Configuración
2. **Máximo 7 entradas** en el menú lateral del admin (hoy hay más de 12).
3. **Cada pantalla dice qué hacer** en una línea, arriba.
4. **Breadcrumb que funcione** y vuelva al listado, no al inicio.

## D8 · Archivar tiene que funcionar

**Lo que quiere Lorenzo.** Que archivar un aula virtual, una sección o un
período funcione de verdad, y que sea fácil tanto para el admin como para el
docente.

**Estado hoy.** `sections.is_active` y `academic_periods.closed_at` existen, pero
Lorenzo reporta que archivar no se siente terminado y que no hay forma de
archivar un aula virtual.

**Qué hay que construir:**
1. Archivar **aula virtual** (hoy no existe la acción).
2. Archivar **sección** con confirmación que explique qué se pierde.
3. Archivar **período**, que a la vez cierra sus secciones y aulas.
4. **Desarchivar** (hoy no existe en ninguna de las tres).
5. Que lo archivado **siga visible** con un filtro «Ver archivados», no
   desapareciendo.

## D9 · Renombrar «Aula Virtual»

**Lo que dice Lorenzo.** «Yo cuando google [busco] no aparece nada […] ni siquiera
indexado […] habría que cambiarle a clase, aula virtual o campus».

**Opciones que él propuso:** «Clase Virtual», «Campus», «LMS / Sistema de Gestión
de Aprendizaje».

**Recomendación:** **«Campus»** como nombre corto del módulo, con «Campus INCES La
Isabelica» en los títulos y metadatos. «Aula virtual» compite con millones de
páginas; «Campus INCES La Isabelica» no compite con ninguna.

**Decisión pendiente:** el nombre exacto. Hay que confirmarlo antes de tocar 40+
textos.

## D10 · Cédula en el perfil

**Lo que dice Lorenzo.** «Acordamos poder [en] una [sección de] perfil guardar
aquí una cédula y poder iniciar sesión tanto [con cédula] como con mi correo […]
tampoco está».

**Estado.** El login con cédula **ya funciona** para admin y docente (migración
`202610250001`, aplicada). Pero **no hay campo en el perfil para ponerla**, así
que la función no sirve de nada: nadie tiene cédula guardada.

**Qué hay que construir:** campo de cédula editable en el perfil de admin y
docente, con validación de formato y de duplicado.

## D11 · Eliminar «Secciones del Período» del menú

**Lo que dice Lorenzo.** «Secciones del período […] habría que llevarlo para
programas académicos» (video 3) y «elimina las secciones, ya me cansaron».

**Interpretación.** El apartado **desaparece del menú** y su contenido se accede
**desde el programa**: eliges el programa, ves sus secciones, y ahí las creas y
archivas. No se borra la entidad `sections` —de ella cuelgan las inscripciones y
el horario—, se borra el apartado suelto.

---

# Parte III — Criterios de aceptación

Cada bloque se da por terminado cuando **todo** esto se cumple.

### D1 · Bids
- [ ] `PENDING_BID` ya no existe en `EstadoInscripcion`.
- [ ] `bid_expires_at` eliminada de la base (migración nueva).
- [ ] Al liberarse un cupo, el primero de `WAITLISTED` pasa a `ENROLLED` solo.
- [ ] `npm run verify` verde y sin referencias a `bid` en `src/`.

### D2 · Lapsos
- [ ] El menú dice «Período», en singular, y no hay ninguna entrada «Lapsos».
- [ ] Al crear el período siguiente, se ofrece **heredar el horario** del anterior.
- [ ] La palabra «lapso» no aparece en ningún texto visible (sí puede quedar en
      nombres de columnas o comentarios).
- [ ] La matriz responsiva sigue en 0 desbordes.

### D3/D4 · MTP, PNA y horario ordinario
- [ ] Tres pantallas distintas, con títulos distintos.
- [ ] El horario ordinario exige curso y permite materia/espacio vacíos.
- [ ] MTP no ofrece materias.
- [ ] PNA exige materia y docente.
- [ ] Ningún bloque de un horario aparece en otro.

### D5 · Cupos
- [ ] El admin cambia el cupo de un curso y se refleja en la landing.
- [ ] La pantalla del curso muestra «X de Y cupos».
- [ ] El parámetro global ya no pisa el valor de la sección.

### D6 · Gestor de archivos
- [ ] Selección múltiple con casillas.
- [ ] Descargar 3 archivos produce **un ZIP** con los 3.
- [ ] Vista de cuadrícula y de lista.
- [ ] La matriz sigue en 0 desbordes a 390 px.

### D7 · Navegación
- [ ] El menú del admin tiene **7 entradas o menos**.
- [ ] Cada pantalla tiene una línea que dice qué hacer.
- [ ] Se llega de «Programas» a «Secciones» en un clic.

### D8 · Archivar
- [ ] Se puede archivar y desarchivar un aula virtual.
- [ ] Se puede archivar y desarchivar una sección.
- [ ] Archivar un período cierra sus secciones.
- [ ] Lo archivado se ve con el filtro, no desaparece.

### D10 · Cédula
- [ ] El perfil tiene campo de cédula, guarda y valida duplicados.
- [ ] Un admin con cédula puede entrar con ella.

---

# Parte IV — Ambigüedades que hay que resolver antes de empezar

**No adivinar ninguna de estas.** Cada una cambia el trabajo de días.

1. **«Elimina las secciones… Aula Virtual.»** ¿Se elimina el módulo Aula Virtual
   entero, o sólo se renombra (D9)? Son cosas opuestas.
2. **Nombre nuevo de «Aula Virtual»:** ¿Campus, Clase Virtual, otro?
3. **Cupo global:** ¿se elimina el parámetro o queda como valor por defecto?
4. **Archivar un período:** ¿cierra también las aulas virtuales, o sólo las
   secciones?
5. **El PNA:** ¿es un `program` más (hoy `CUR-INT-01` lo es) o una entidad aparte?
   Hoy es un programa con `type = CURSO_LIBRE`.

---

# Parte V — Megaprompt para antigravity

> Copia todo lo que hay entre las líneas siguientes y entrégalo tal cual.

---

## CONTEXTO

Trabajas en **INCES LMS**, una plataforma de gestión académica para el Centro de
Formación Socialista Nacional de Soldadura «Rafael Urdaneta», INCES La Isabelica
(Valencia, Carabobo, Venezuela). Es el trabajo especial de grado de Lorenzo Roca
(IUTEPI, Análisis de Sistemas, 4º semestre).

**Repositorio:** `github.com/Burmistrov4/inces-lms`, rama `main`.

**Stack, sin excepciones:**
- Frontend: **Flutter Web** (`lib/`), Dart 3, Material 3. Sin `.py` en el repo.
- Backend: **Node/TypeScript + Fastify 5 + Zod**, ESM (`backend/src/`).
- Base de datos: **Supabase** (PostgreSQL 17, RLS, PostgREST).
- Archivos: **Cloudflare R2** (S3 con URLs firmadas).
- Producción: Render (API, `inces-lms-api.onrender.com`) y Cloudflare Pages
  (`inces-lms.pages.dev`).

**Reglas del proyecto que NO puedes romper:**

1. **La frontera de autorización es la RLS, no la API** (ADR-003). El backend no
   repite reglas que la base ya aplica.
2. **Migraciones con formato `YYYYMMDDNNN_*.sql`. Nunca editar una aplicada.**
   Hay 53 aplicadas; 0 pendientes; 0 deriva. Una migración aplicada es el
   historial de lo que pasó en la base.
3. **No correr `dart format`** como verificación: sólo comprueba sintaxis, no
   tipos.
4. **Verificar, no asumir.** Si dices que algo compila, compílalo. Si dices que
   un bug existe, señálalo con archivo y línea.
5. **Un volcado truncado no es evidencia.** Un `grep | head` que corta la salida
   no demuestra nada.
6. **El `231` (`ERROR_PIPE_BUSY`) bloquea Dart/Flutter en el sandbox de Windows.**
   Usa `node devops/analizar-dart.mjs` para tipos (243 archivos) y la suite E2E
   para comportamiento. El build de producción sale de
   `.github/workflows/web_bundle.yml`.
7. **Comentarios en español, y explican el *por qué*, no el *qué*.** Cuando algo
   se cambia porque estaba mal, el comentario dice qué pasaba antes y cómo se
   midió.

**Verificación obligatoria antes de dar algo por terminado:**

```bash
node devops/analizar-dart.mjs          # 243 archivos, 0/0/0
cd backend && npm run verify            # 713 pruebas, 34 suites
cd e2e && E2E_MATRIZ=1 node node_modules/@playwright/test/cli.js test matriz_responsive
                                        # 186 capturas, 0 desbordes
node supabase/tests/validate.mjs        # 546 aserciones sobre las migraciones
```

---

## ESTADO DE PARTIDA (medido el 2026-10-25, no lo inventes)

| Dato | Valor |
|---|---|
| Migraciones aplicadas | 53 |
| Perfiles | 72 (61 son `@semilla.invalid`; **11 personas reales**) |
| Programas | 7 |
| Materias | 3 |
| Secciones | 1 (`SA`, `max_capacity` 10, inactiva) |
| Períodos | 1 (`SA26-2`, «Lapso SA26-2», activo) |
| Inscripciones | 4, todas `ENROLLED` |
| **Inscripciones `PENDING_BID`** | **0** |

**Tablas que vas a tocar:**

```
programs (7)          code, name, type (CARRERA|CURSO_LIBRE), requires_internship, is_active
subjects (3)          code, name
academic_periods (1)  code, name, start_date, end_date, is_active, closed_at, closed_by
sections (1)          program_id, subject_id, period_code, name, max_capacity, is_active
enrollments (4)       student_id, section_id, status, bid_expires_at
```

`sections` **ya liga** programa + materia + período. `sections.period_code` es
**texto**, no una clave foránea.

**Módulos activos** (`system_modules`): `m0_cpanel`, `m1_onboarding`,
`m2_curriculo`, `m3_cuadrante`, `m4_inscripciones`, `m5_archivos`,
`m6_aula_virtual`, `m7_asistencia`, `m7_calificaciones`, `m8_pasantias`.

---

## LO QUE HAY QUE HACER

Once tareas. **En este orden**, porque cada una depende de la anterior.

### TAREA 1 — Eliminar el sistema de bids

**Hoy:** cuando se libera un cupo, el sistema le ofrece el asiento a alguien de la
cola con vencimiento (`PENDING_BID` + `bid_expires_at`). Si no responde, pasa al
siguiente.

**Debe quedar:** `WAITLISTED` (cola) → `ENROLLED` (dentro) → `DROPPED` (fuera).
Al liberarse un cupo, **el primero de la cola entra automáticamente**. Sin
oferta, sin vencimiento, sin esperar respuesta.

**Archivos con referencias medidas:** `backend/src/dominio/reglas-inscripciones.ts`
(6), `backend/src/dominio/tipos.ts` (5), `backend/src/infra/repos-supabase.ts`
(3), `backend/src/http/rutas/inscripciones.ts` (1),
`lib/core/gateways/inscripcion_gateway.dart` (1), y la RPC/trigger de
`202609190001_mod4_inscripciones.sql`.

**Riesgo: bajo.** Cero filas en `PENDING_BID`. No hay datos que migrar.

**Aceptación:** `PENDING_BID` no existe en el tipo; `bid_expires_at` eliminada por
migración; liberar un cupo promueve al primero de la cola; `npm run verify` verde;
`grep -ri bid backend/src/` no devuelve nada del flujo viejo.

---

### TAREA 2 — «Lapsos» desaparece; queda «Período»

**Lo importante:** `academic_periods` es **una sola tabla**. «Lapso» y «período»
son la misma cosa con dos nombres. El menú la llama «Lapsos Académicos» y la fila
existente se llama «Lapso SA26-2».

**Debe quedar:** un solo concepto, **Período**, con inicio, fin y estado. Al crear
el siguiente, se ofrece **heredar el horario** del anterior (bloques, aulas y
asignaciones).

**No borres la tabla.** `sections.period_code` la referencia por código y otras
tablas dependen de ella.

**Aceptación:** el menú dice «Período»; no hay «Lapsos» en ningún texto visible;
al crear el siguiente se ofrece heredar el horario; la matriz sigue en 0.

**Riesgo: alto.** Toca `m2_curriculo`, `m3_cuadrante`, `m4_inscripciones`, la
asistencia y el aula virtual. Corre la matriz antes y después.

---

### TAREA 3 — Separar MTP y PNA en dos pantallas

**Hoy:** un panel de «Guardias Docentes» con un filtro que mezcla las dos
modalidades.

**Debe quedar:**

- **MTP** = guardias de los **docentes**. Quién cubre qué taller o espacio, por
  día y turno. **Sin materias, sin estudiantes.**
- **PNA** = horario de los **estudiantes del PNA**. Materia + docente + espacio,
  por bloque.

**Aceptación:** dos pantallas con títulos distintos; MTP no ofrece materias; PNA
exige materia y docente; ningún bloque aparece en las dos.

---

### TAREA 4 — Tres horarios distintos

| Horario | Para quién | Obligatorio | Opcional |
|---|---|---|---|
| **Ordinario / Normal** | Estudiantes de cursos regulares | Curso | Materia, espacio |
| **MTP** | Docentes | Docente, espacio | — |
| **PNA** | Estudiantes del PNA | Materia, docente | Espacio |

**Regla dura:** el bloque del horario ordinario **exige curso**; materia y
espacio pueden quedar vacíos. El de MTP **no lleva materia**. El de PNA **exige
materia y docente**.

**Aceptación:** las tres reglas se cumplen y se prueban; el bloque muestra el
nombre del curso y del docente (hoy sólo muestra el aula).

---

### TAREA 5 — Cupo por curso

**Hoy:** dos sitios dicen cuánta gente cabe —`sections.max_capacity` y el
parámetro global `cupo_maximo_por_seccion`— y **el global gana**.

**Debe quedar:** el cupo se define **por sección**, el admin lo cambia cuando
quiera, y la disponibilidad («quedan 3 de 10») se ve en la pantalla del curso y
en la landing.

**Aceptación:** cambiar el cupo de un curso se refleja en la landing; la pantalla
muestra «X de Y»; el global ya no pisa el valor de la sección.

---

### TAREA 6 — Rediseño del gestor de archivos, con descarga en ZIP

**Referencia:** Google Drive. Lorenzo mandó una captura con 8 archivos
seleccionados y el aviso «Preparando la descarga / Comprimiendo 1 archivo».

**Debe quedar:**
1. **Selección múltiple** con casillas; `Shift` selecciona rango.
2. **Descargar lo seleccionado como un ZIP.** El ZIP se genera **en el backend**
   (`archiver` en streaming, o URL firmada del objeto comprimido). **Nunca en el
   cliente**: un centro con equipos modestos no puede comprimir 8 PDFs en el
   navegador.
3. **Vista de cuadrícula y de lista**, conmutables, y que la elección se recuerde.
4. **Barra de acciones flotante** cuando hay selección: descargar, mover, borrar.
5. Miniaturas reales de imágenes y primera página de PDF.

**Aceptación:** seleccionar 3 archivos y descargar produce **un ZIP con los 3**;
se puede cambiar entre cuadrícula y lista; la matriz sigue en 0 desbordes a
390 px.

**Contexto:** el panel mide ~2 300 líneas. **No lo reescribas entero**: extrae el
gestor de selección y la barra de acciones a widgets propios.

---

### TAREA 7 — Navegación: de 12 apartados a 7

**Hoy:** más de 12 entradas en el menú del admin, sin agrupar. Lorenzo: «cuesta ir
de un apartado a otro y saber cómo gestionar todo».

**Debe quedar, agrupado por tarea:**

| Grupo | Contiene |
|---|---|
| **Preparar el período** | Período, Programas (con sus materias y secciones dentro), Configuración |
| **Inscribir** | Inscripciones y Cupos, Campos de la planilla |
| **Dar clase** | Horarios (ordinario / MTP / PNA), Campus, Asistencia, Calificaciones |
| **Gestionar** | Usuarios, Archivos |

**Y además:**
- Cada pantalla abre con **una línea** que dice qué hacer.
- El breadcrumb vuelve **al listado**, no al inicio.

**Aceptación:** 7 entradas o menos en el menú del admin; «Secciones» se alcanza
desde «Programas» en un clic; cada pantalla tiene su línea de propósito.

---

### TAREA 8 — Archivar funciona de verdad

**Debe quedar:**
1. Archivar **aula virtual** (hoy la acción no existe).
2. Archivar **sección**, con confirmación que diga qué se pierde.
3. Archivar **período**, que cierra sus secciones.
4. **Desarchivar** las tres (hoy no existe en ninguna).
5. Lo archivado **sigue visible** con el filtro «Ver archivados»; no desaparece.

**Aceptación:** las tres se archivan y desarchivan; lo archivado se encuentra con
el filtro; archivar un período no deja secciones activas huérfanas.

---

### TAREA 9 — Renombrar «Aula Virtual»

**Pendiente de confirmar el nombre.** Opciones: «Campus», «Clase Virtual», otro.

**Recomendación:** **Campus**, con «Campus INCES La Isabelica» en títulos y
metadatos. «Aula virtual» compite con millones de páginas en Google; «Campus
INCES La Isabelica» no compite con ninguna.

**Aceptación:** el nombre nuevo aparece en el menú, el breadcrumb, los títulos y
los metadatos de `web/index.html`; no queda «Aula Virtual» en texto visible.

---

### TAREA 10 — Cédula en el perfil

**Contexto:** el login con cédula **ya funciona** para admin y docente
(migración `202610250001`). Pero **no hay campo para guardarla**, así que nadie
la tiene y la función no sirve.

**Debe quedar:** campo de cédula editable en el perfil de admin y docente, con
validación de formato y de duplicado.

**Aceptación:** se guarda la cédula; un admin con cédula entra con ella; una
cédula duplicada se rechaza con un mensaje claro.

---

### TAREA 11 — Eliminar «Secciones del Período» del menú

El apartado **desaparece** y su contenido se accede **desde el programa**: eliges
el programa, ves sus secciones, las creas y las archivas.

**No borres la tabla `sections`**: de ella cuelgan las inscripciones y el horario.

**Aceptación:** no hay entrada «Secciones del Período» en el menú; desde
«Programas» se llega a las secciones en un clic; crear y archivar sección
funciona desde ahí.

---

## CÓMO TRABAJAR

1. **Trabaja DIRECTAMENTE en la rama `main`.** NO crees ramas nuevas
   (`feat/*`, `fix/*`, `tarea/*`). Haz tus commits y el push directo a
   `origin main`. El usuario lo exigió de forma explícita: otro agente tendía a
   abrir ramas aparte y eso fragmentaba el trabajo y lo dejaba sin desplegar.
   Si necesitas aislar algo temporalmente, usa `git stash`, no ramas.
2. **Antes de tocar:** mide. Lee el archivo, cuenta las ocurrencias, mira los
   datos reales en la base. No deduzcas.
3. **Migraciones nuevas, nunca editar aplicadas.** Formato `YYYYMMDDNNN_*.sql`.
   Valida con `node supabase/tests/validate.mjs` (546 aserciones) antes de
   aplicar.
4. **Comentarios que expliquen el porqué.** Si cambias algo porque estaba mal, el
   comentario dice **qué pasaba antes y cómo se midió**. Ejemplo real del repo:

   ```dart
   // **Sin `email`, a propósito.** Medido el 2026-10-25: la respuesta incluía el
   // correo del perfil cuando el identificador existía, así que la forma del
   // cuerpo distinguía «existe» de «no existe» y entregaba la dirección asociada
   // a cada acierto.
   ```

5. **Verifica los cuatro controles** antes de decir que terminaste.
6. **Si una tarea toca el cuadrante o el horario, corre la matriz antes y
   después** y compara. Es la parte más frágil del sistema.
7. **Si encuentras una ambigüedad, pregunta.** No adivines. Las cinco de la
   Parte IV están sin resolver.

## LO QUE NO DEBES HACER

- No modificar el logo oficial del INCES (identidad de una institución pública).
- No introducir `.py` en el repositorio.
- No aplicar reglas de autorización en el backend que la RLS ya aplica.
- No comprimir archivos en el cliente.
- No borrar la tabla `sections` ni `academic_periods`.
- No prometer posiciones en Google: se puede asegurar indexación, no ranking.
- No decir «listo» sin haber corrido los cuatro controles.

## DEFINICIÓN DE TERMINADO

Una tarea está terminada cuando:
- [ ] Los cuatro controles pasan (analizador, backend, matriz, migraciones).
- [ ] Hay una prueba que cubre el comportamiento nuevo.
- [ ] El comentario del cambio explica el porqué y cómo se midió.
- [ ] Los documentos afectados están actualizados (`ESTADO_DEL_SISTEMA.md`,
      `CHANGELOG.md`).
- [ ] Está desplegado: `web_bundle.yml` → artefacto → `wrangler pages deploy`, y
      el backend redesplegado en Render.
- [ ] Verificado **en producción**, no sólo en local.
