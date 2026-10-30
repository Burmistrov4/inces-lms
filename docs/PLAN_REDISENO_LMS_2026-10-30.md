# Plan de rediseño del LMS — 2026-10-30

> Nace del reporte del dueño tras usar el sistema en escritorio y en su Redmi 10C.
> Cada punto dice **qué se midió**, **cómo lo resuelven los LMS de referencia** y
> **qué se hace aquí**. Restricción explícita del propietario: **no se vuelven a
> introducir secciones**.

---

## 1. Diagnóstico: los cuatro conceptos que hoy se pisan

El usuario reporta «al seleccionar el campo curso·materia aparece un aula virtual
archivada». No es un fallo de un campo: es que hay **cuatro cosas distintas con
nombres parecidos** y ninguna pantalla las distingue.

| Concepto | Dónde vive | Qué es de verdad | Cómo se llama hoy en la UI |
|---|---|---|---|
| **Curso/Programa** | `programs` | La oferta formativa («Soldadura Básica») | «Curso» |
| **Materia** | `subjects` | Lo que se dicta dentro del curso («Metalurgia») | «Materia» |
| **Grupo** | `sections` (nombre ≤5) | Una cohorte que cursa esa materia en ese período | «Sección» / «Grupo» / «Curso · materia» |
| **Aula virtual** | `aulas_virtuales` | El espacio de trabajo digital de un grupo | «Aula Virtual» |

En **Google Classroom** hay uno solo: *clase*. Una clase tiene nombre, código,
tablón, trabajos, personas y notas; el «grupo» y el «aula» son la misma cosa. En
**Moodle** hay *curso* (que contiene todo) y *grupos* (subconjunto de alumnos).
En **Canvas** hay *course* y *section* — y las secciones existen justamente para
lo que aquí se quitó: separar cohortes.

**Decisión propuesta (una sola entidad visible): el Aula Virtual es el grupo.**
No se crea nada nuevo: un aula virtual **pertenece** a un grupo (curso + materia +
período), y el grupo es un detalle que el administrador no ve salvo que haya dos
cohortes. Eso elimina la cuarta fila de la tabla de arriba y responde la pregunta
del dueño («¿para qué el aula virtual si ya elegí el grupo?»).

---

## 2. Lo que está roto hoy y se arregla en la fase 0

| # | Defecto medido | Causa | Estado |
|---|---|---|---|
| 1 | «Los datos enviados no son válidos» al crear curso·materia | El diálogo manda `nombre` libre; `sections.name` es `varchar(5)` y el contrato `.strict()` lo rechazaba | **corregido**: campo limitado a 5 con ayuda, y `nombre` aceptado en `grupos/resolver` |
| 2 | El nombre del período no se refleja hasta recargar | La cabecera leía el período una sola vez (`initState`) | **corregido**: se relee al cambiar de sección; muestra el nombre y el código en el tooltip |
| 3 | El icono «+» de una celda vacía parece una celda muerta | Icono de 16 px al 28 % de opacidad | **corregido**: 22 px al 45 % |
| 4 | No se pueden editar materias (horas, nombre, código) | El asistente de pensum solo añade y quita | **fase 1** |
| 5 | No se puede editar el código del período | `sections.period_code` es FK a `academic_periods.code` | **decisión §4** |
| 6 | No se puede crear un aula virtual desde el panel | Solo se listan | **fase 2** |

---

## 3. Cómo lo resuelven los LMS de referencia (patrones, no copia)

**Google Classroom**
- La unidad es la **clase**. Se crea en un formulario de tres campos (nombre,
  sección, materia) y recibe un **código de invitación**; el alumno entra con el
  código, no con una búsqueda.
- Dentro: **Tablón** (anuncios), **Trabajo en clase** (tareas, cuestionarios,
  materiales), **Personas** (profesores y alumnos) y **Calificaciones**.
- Los archivos viven en **Drive** y se comparten con la clase; una tarea crea una
  **copia por alumno** con permisos ya puestos. Ese es el «ecosistema» que el
  dueño quiere: no es que Classroom tenga un gestor de archivos, es que **el
  archivo es parte del trabajo**, no un módulo aparte.
- Notas: cada tarea tiene un **puntaje máximo** configurable; el libro suma.

**Moodle**
- Curso → secciones/temas → actividades. Cada actividad tiene **calificación**
  con escala configurable y un **libro de calificaciones** con categorías y
  ponderaciones.
- Los permisos son por **rol + contexto** (profesor en este curso, alumno en este
  otro), que es exactamente el modelo de RLS que ya tiene este sistema.

**Canvas**
- Curso → *sections* (cohortes) y **enrollments** con rol. El expediente del
  alumno (*student profile*) agrega todas sus matrículas y notas.

**Lo que se copia:** la idea de que **una sola entidad contiene todo** (trabajo,
gente, notas, archivos) y que el archivo nace dentro del trabajo.
**Lo que no se copia:** las secciones de Canvas y los cursos-contenedor de Moodle.

---

## 4. Decisiones que necesitan al propietario

### 4.1 ¿El período necesita un código editable?
Hoy hay tres identificadores y el usuario ve el equivocado:

- `academic_periods.id` — UUID interno, nunca se muestra.
- `academic_periods.code` — `SA26-2`. **Es la clave**: `sections.period_code` es
  una FK a él, y las exportaciones hacia HACER lo llevan. Cambiarlo obliga a
  `on update cascade` o a bloquearlo si hay grupos.
- `academic_periods.name` — «INCES 26-3». Es lo que el administrador entiende.

**Propuesta:** el nombre es libre y editable (ya lo es); el código se puede
cambiar **solo mientras no haya grupos que lo usen**, y la UI lo dice así en vez
de esconder el campo. Con grupos, se ofrece «duplicar como período nuevo». Es lo
que hacen Moodle y Canvas: el *shortname* se puede corregir, pero el sistema avisa
si algo cuelga de él.

### 4.2 ¿Qué pasa cuando un período se archiva?
Propuesta (una sola regla, fácil de explicar):
1. Se **congela**: no admite grupos, clases ni matrículas nuevas (ya está el
   trigger `exigir_periodo_no_cerrado`).
2. Se **consulta**: cuadrante, planillas y notas quedan legibles y exportables.
3. Se **hereda**: al crear el período siguiente, se ofrece copiar el cuadrante
   del anterior (N3 del backlog) en un gesto, con las aulas y los docentes.
4. El **expediente** del alumno sigue mostrando sus períodos cerrados con su nota
   final: un período archivado no borra historial.

### 4.3 Google Drive: ¿enlaces o cuenta vinculada?
Hoy se guarda un enlace. Vincular una cuenta real pide OAuth con permisos de
lectura y un cliente registrado; y el archivo queda en la cuenta del
administrador que lo vinculó (si esa cuenta desaparece, el aula se queda sin
material). **Recomendación:** empezar por enlaces con metadatos (título, tipo,
tamaño) y **no** prometer subida a Drive desde aquí; para lo que el centro sube,
R2 ya funciona y es del centro.

---

## 5. Fases

### Fase 0 — Correcciones del reporte (hecho en este lote)
Crear grupo, «+» de la celda, refresco del período. Criterio: el administrador crea
un grupo con etiqueta propia sin error y la cabecera refleja el nombre al volver.

### Fase 1 — Materias editables (horas, nombre, código)
- Endpoint `PATCH /admin/materias/:id` con validación (el código es único y
  aparece en la planilla: cambiarlo exige avisar).
- Diálogo de edición desde el pensum, con las horas (`horas` ya existe en el
  modelo: «72 h»).
- Criterio: se edita la hora de una materia y el pensum la muestra sin recargar.

### Fase 2 — Aula Virtual = grupo, con CRUD de verdad
- `POST/PATCH/DELETE /admin/aulas-virtuales` (crear desde el panel, archivar,
  asignar docente).
- La lista muestra **estado** (activa/archivada) y **dueño** (docente), no solo
  el nombre.
- Criterio: el administrador crea un aula, le asigna un docente y la ve en la
  lista del docente sin tocar la base.

### Fase 3 — Supervisión del aula (lo que el dueño llama «vigilar»)
Vista de solo lectura por aula: material publicado, entregas recibidas, alumnos,
última actividad. Sin permisos de escritura del admin sobre el trabajo del
docente (eso destruye la confianza en la nota).
- Criterio: el administrador ve qué publicó cada docente en la semana.

### Fase 4 — Notas 01–20 y libro
- Escala 01–20 con un decimal; redondeo **explícito**: 9.5 → 10 solo si el centro
  lo activa (parámetro `redondeo_definitiva`), nunca por defecto.
- Libro por grupo: columnas = actividades, filas = alumnos, definitiva calculada.
- Criterio: un 9.5 aparece como 9.5 y, con el parámetro activo, como 10 **y se
  dice que fue redondeado**.

### Fase 5 — Expediente y certificado
- Expediente por alumno: matrículas, notas por período, asistencia, entregas.
- Certificado PDF generado desde el expediente, guardado en R2 y entregado al
  buzón del alumno (descargable). El PDF lleva folio y hash para verificarlo.
- Criterio: el admin emite un certificado y el alumno lo descarga desde su cuenta.

### Fase 6 — Modernización visual
- Una sola barra superior con búsqueda global; el menú lateral agrupado por tarea
  («Preparar el período», «Dar clase», «Archivos», «Personas») ya existe: se
  mantiene y se le quita lo que duplica.
- Estados con color en todas las listas (vigente/archivado ya hecho).
- Criterio: ninguna pantalla con más de un scroll vertical y ningún control sin
  estado visible.

---

## 6. Riesgos

- **Renombrar el código de período** con historial colgando: mitigado con la regla
  de §4.1 (solo sin grupos) y nunca con `cascade` silencioso.
- **Dar al admin permiso de escritura sobre notas del docente**: no se hace; la
  supervisión es de lectura.
- **Drive**: prometer lo que no se puede cumplir deja al centro sin material si
  la cuenta se va. Enlaces + R2 primero.
- **Redondeo de notas**: es una decisión institucional, no técnica. Por defecto,
  no redondea.
