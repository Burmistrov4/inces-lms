# Plan de simplificación: que «sección» deje de existir en la cara visible

**Fecha:** 2026-10-29 · **Estado:** fase 1 hecha; fases 2–5 pendientes · **Decide:** Lorenzo

> Objetivo del propietario, textual: «erradica las secciones, deja período y hazlo
> más simple y funcional posible para que **absolutamente cualquier** administrador,
> profesor y estudiante puedan empezar a usar el sistema».

---

## 1. Por qué «sección» aparece en todas partes

Una sección es la fila que liga **programa + materia + período** (con un nombre
corto y un cupo). De ella cuelgan **los horarios** (`schedule_slots.section_id`),
**las inscripciones** (`enrollments.section_id`), **las aulas virtuales** y **la
asistencia**. Por eso el sistema la pide en el cuadrante, en el PNA y en
inscripciones: es la llave de todo lo demás.

El problema no es que exista: es que **se le pide al usuario**. El administrador
tiene que saber que «Soldadura por Arco» son en realidad varias filas
(una por materia) y crearlas antes de poder poner un horario. Eso no es un
concepto del negocio, es un detalle de implementación que se escapó a la interfaz.

## 2. Lo que ya está hecho (2026-10-29)

- **El cuadrante crea el grupo sin salir de la pantalla.** El desplegable pasó de
  «Sección» a **«Curso · materia (grupo)»**, y debajo hay un botón
  *«Falta el curso o la materia: crearlo aquí»* que abre un formulario mínimo
  (**curso → materia del pensum → nombre opcional**) y deja el grupo creado y
  elegido. Ya no hay que ir a otro módulo (que además llevaba desde D11 sin
  entrada en el menú).
- **El mensaje del cuadrante** ya no manda a «Secciones del Período».
- **La barra de paginación** desaparece cuando hay una sola página.

## 3. Modelo objetivo

| Concepto visible | Qué es por debajo |
|---|---|
| **Curso** | `programs` (+ su pensum) |
| **Período** | `academic_periods` |
| **Grupo / cohorte** | `sections` — **interno**, nombre automático, nunca se pide |
| **Horario** | curso + materia + docente + espacio + bloque |
| **Inscripción** | al **curso** en el período (una sola vez), no a cada materia |

Regla: si un curso se dicta en un período, **el grupo existe o se crea solo**.
El administrador nunca ve la palabra «sección».

## 4. Fases

| # | Fase | Qué cambia | Riesgo |
|---|---|---|---|
| 1 | **Crear grupo al vuelo** | hecho hoy | bajo |
| 2 | **Cuadrante y PNA por curso** | el desplegable agrupa por curso y muestra «curso · materia»; el alta ya no pide sección | medio |
| 3 | **Un solo módulo «Cursos»** | «Inscripciones y Cupos» se absorbe: cada curso muestra cupo, ocupados, ventana de inscripción, inscritos y acciones | medio |
| 4 | **Landing por curso** | disponibilidad y «próxima apertura» leídas de `programs` + su grupo | bajo |
| 5 | **Borrar `CpanelSeccionesPanel`** (676 líneas) | cuando archivar/editar cupo viva en la tarjeta del curso | bajo |

## 5. Lo que **no** hay que hacer

- **No borrar la tabla `sections`.** Inscripciones y horarios la referencian; sin
  ella se pierde el historial. Su desaparición es de la **interfaz**, no del
  esquema.
- **No hacer las cinco fases en un commit.** Cada una se cierra con los cuatro
  controles y la matriz de 192 capturas; el Lote 5 demostró lo que cuesta saltarse
  ese paso.

## 6. Decisión que falta

> ¿Un curso puede tener **varios grupos simultáneos** en el mismo período (mañana
> y tarde, por ejemplo) o siempre **uno**?

- **Uno** (recomendado si el centro no abre dos cohortes del mismo curso a la vez):
  el sistema crea el grupo solo y no pregunta nunca.
- **Varios**: el administrador pone un nombre al grupo sólo cuando de verdad
  necesita el segundo; el primero es automático.

Hasta que se decida, la fase 1 mantiene el campo «Nombre del grupo» con «ÚNICA»
por defecto, que sirve para las dos respuestas.
