# Análisis del video de revisión — 2026-10-25 17:59

**Archivo:** `2026-10-25 17-59-39.mp4` · 15:10 · 1152×720
**Cómo se analizó:** 114 fotogramas extraídos cada 8 s, 16 fotogramas clave a
resolución completa, y **el audio transcrito** con Vosk (modelo español). La
transcripción tiene errores de reconocimiento —«pene a» es **PNA**, «metepec» es
**MTP**, «draghi» es **Drive**, «semillas» es **[SEMILLA]**— pero el hilo se
sigue con claridad.

**Recorrido del video:** Cuadrante de Horarios → Asistente de pensum →
Configuración del Centro → Parámetros del Sistema → Aulas y espacios → Asignar
clase → Guardias docentes → Programas Académicos → Inscripciones y Cupos.

---

## Lo que pides, en tus palabras

Del cierre del video (13:05 en adelante), que es donde lo resumes:

> «primero: que tienen que simplemente quieren aparecer MTP y aquí PNA y ya. Y
> esto así como se está filtrando de lunes a sábado […] está muy bien cómo lo
> hacen en Guardia Docente pero **no lo hace bien en Cuadrante de Horarios**.
> **Dividir bien los cursos del PNA** y **establecer cuándo empieza y termina un
> curso** y cuándo empieza y termina [el período]. **El PNA [es] un solo
> programa, el Programa Nacional de Aprendizaje.** **Indicar desde alguna parte
> del dashboard, desde Inscripciones y Cupos, cuándo hay inscripciones abiertas
> o cupos disponibles o cuándo empieza el siguiente** […] cuándo empieza otra vez
> el ingreso, cuándo termina el actual y cuándo empieza otra vez algún curso en
> específico. Esto de promover, reincorporar […] **se supone que hace falta
> tener dos veces consecutivas fuera** de un curso y creo que también del PNA.»

---

## Los problemas, uno por uno

### V1 · No se puede cambiar el nombre de un programa — **ALTO**

> «decidí que se vea “Curso Introductorio”, esto usted puede cambiar el título
> porque entre catorce y dieciocho […] ¿no se puede desde aquí? **tenemos un
> problema grave** […] no aparece opción para cambiar el nombre, es un problema
> grave» (02:44 – 03:30)

**Verificado:** el diálogo de edición **sí** tiene el campo
(`cpanel_programas_panel.dart:1022`, `TextFormField` con `_nombreCtrl`, sin
`enabled: false`). Así que el campo existe. **El problema es otro:** o el
diálogo no se abre desde donde lo buscas, o el guardado falla sin decir nada.
Hay que reproducirlo con la consola abierta.

**Lo que sí encontré de paso:** el nombre real en la base era
«Curso Introductorio (15-16 años)», y ahora es «(14-18 años)» — ver V2.

### V2 · El rango del PNA era 15-16, no 14-18 — **CORREGIDO HOY**

Lo que dijiste en 02:44 («entre catorce y dieciocho») era correcto, y el dato
estaba mal en **cuatro** sitios con tres valores distintos. Los cuatro
corregidos:

| Sitio | Antes | Ahora |
|---|---|---|
| `landing_page.dart` | `kEdadPnaMax = '17'` | `'18'` |
| Programa en la base | «(15-16 años)» | «(14-18 años)» (migración `202610250002`) |
| `temas_formacion.dart` | buscaba «15-16» | acepta 14-18, 14-17 y 15-16 |
| `campo_planilla.dart` | selector cortaba en `hoy-15` | `hoy-14` |

**Ese último era el peor:** un aspirante de 14 años **no podía ni seleccionar su
fecha de nacimiento**, así que el formulario le impedía inscribirse en el único
programa al que tiene derecho.

### V3 · Quitar «[SEMILLA]» — **CORREGIDO HOY**

> «quítale eso de semillas porque muy raro es» (08:15)

Medido contra la base: `SEM-SOL-01` se llamaba «Soldadura **[SEMILLA]**». La
migración `202610070001` solo había limpiado `SEM-SOL-CL`, y su propio comentario
avisaba de que no tocaba otras filas. La migración de hoy lo quita de **todas**
las filas, no de una por código.

### V4 · El cuadrante de horarios no filtra por día — **ALTO, PENDIENTE**

> «si yo voy a martes aparece solamente lo que se ha colocado en martes […] pero
> la idea es que aparezca de una vez de lunes a sábado […] y aquí se me repite
> el martes […] el de arriba sí filtra bien, si le doy “todo” otra vez aparecen
> de abajo […] si le doy miércoles aparece otro del lunes» (04:04 – 05:47)

**Este es el hallazgo más importante del video.** Y lo más valioso que dijiste
es la comparación:

> «**está muy bien cómo lo hacen en Guardia Docente pero no lo hace bien en
> Cuadrante de Horarios**» (13:28)

Es decir: **el mismo patrón está bien implementado en un módulo y mal en el
otro**. Eso convierte el arreglo en algo acotado —copiar el filtro que ya
funciona en `cpanel_guardias_panel.dart` al `cpanel_cuadrante_panel.dart`— en
vez de inventar uno.

### V5 · Los bloques horarios no se recalculan solos — **ALTO, PENDIENTE**

> «si yo cambio esto y lo pongo aquí 9:15, a ver qué pasa […] entonces si esto se
> ajustara solo […] **no se ajusta solo, tenemos un problema grave**» (04:15 – 04:47)

Y más adelante:

> «se tienen que […] ir sumando hasta el final […] para que no se solapen las
> horas» (10:19 – 10:53)

Los bloques deberían encadenarse: si uno empieza a las 9:15 y dura 45 minutos,
el siguiente empieza a las 10:00. Hoy se pueden solapar y quedar inconsistentes.

### V6 · Confusión MTP / PNA en Guardias Docentes — **MEDIO, PENDIENTE**

> «invitamos a […] MTP supone que es un acuerdo de docente […] MTP son guardia
> docente, muy diferente al PNA […] se ve un poco extraño, debería parecer PNA
> […] PNA es otra cosa, que haga algo totalmente aparte» (01:17 – 01:44)

Guardias Docentes mezcla dos modalidades que institucionalmente son distintas:
**MTP** (Maestro Técnico Productivo) y **PNA** (Programa Nacional de
Aprendizaje). Deben verse separadas, y el cuadrante de MTP no debería listar
PNA.

### V7 · El PNA es UN solo programa — **ALTO, PENDIENTE (conceptual)**

> «el PNA un solo programa, el Programa Nacional de Aprendizaje» (14:03)

Hoy el PNA se representa como si fuera una categoría con varios cursos sueltos.
Debería ser **un** programa, con sus materias dentro y sus propias fechas.

### V8 · Fechas de inicio y fin del curso y del período — **ALTO, PENDIENTE**

> «al PNA se le puede añadir cierta cantidad de materias, indicar cuándo empieza
> y cuándo termina un período […] que el administrador pueda indicar cuándo
> termina y cuándo [empieza] otro» (06:10 – 06:39)

Esto es exactamente lo que ya está diseñado en
`docs/DISENO_PERIODOS_DURACION_Y_CADUCIDAD_2026-10-10.md` y **nunca se
implementó** porque requería migración y cinco decisiones institucionales. El
video es la confirmación de que hace falta.

### V9 · Avisar en Inscripciones y Cupos cuándo abre la próxima — **ALTO, PENDIENTE**

> «indicar desde alguna parte del dashboard, desde Inscripciones y Cupos, cuándo
> hay inscripciones abiertas o cupos disponibles o cuándo empieza el siguiente
> […] cuándo empieza otra vez el ingreso, cuándo termina el actual y cuándo
> empieza otra vez algún curso en específico» (14:10 – 14:46)

**Coincide exactamente con la feature que propuse ayer**
(`docs/PROPUESTA_PROXIMA_INSCRIPCION_2026-10-25.md`), y confirma el sitio donde
la quieres: **Inscripciones y Cupos**, no otro.

### V10 · Los cursos PNA deben aparecer en el cuadrante con nombre y docente — **ALTO, PENDIENTE**

> «crear materias para añadirle a ese PNA […] que los cursos PNA que aparezcan
> ahí se puedan añadir en cuadrante de horario para decir: oye, este día, dentro
> del bloque horario tal, hay el curso tal con el profesor tal» (07:10 – 07:38)

Y en Guardias:

> «necesito que me aparezca el nombre del curso» (09:49 – 10:08)

Hoy el bloque muestra el aula o el espacio, pero no el curso. Sin el nombre del
curso, el cuadrante no sirve para lo que sirve un cuadrante.

### V11 · «Dos veces consecutivas fuera» para reincorporar — **MEDIO, PENDIENTE**

> «esto de promover, reincorporar […] se supone que hace falta tener dos veces
> consecutivas fuera de un curso y creo que también del PNA» (14:46 – 15:06)

Regla de negocio: solo se reincorpora a quien lleva **dos períodos consecutivos**
fuera. Hoy el botón no lo exige.

### V12 · Carga lenta del cuadrante — **MEDIO**

> «¿qué tan rápido carga? […] tardó un poco […] arreglado ser parte de la
> velocidad» (00:17 – 00:33)

El cuadrante se queda en esqueletos varios segundos. Es el panel con más
peticiones de red del sistema.

### V13 · No se puede eliminar un archivo desde el gestor — **MEDIO**

> «no aparece nuevo y no fabricó […] esto pero no se puede eliminar de aquí […]
> voy a hacer una prueba: eliminar» (12:34 – 12:46)

### V14 · El aula/espacio debería ser opcional pero el curso obligatorio — **MEDIO**

> «esto son datos […] de espacios […] requiere […] como el curso, o que también
> puede dejar el espacio […] opcional colocarlo, pero necesito que me aparezca el
> nombre del curso» (09:45 – 10:08)

---

## Lo que hice hoy

| # | Qué | Estado |
|---|---|---|
| V2 | Rango PNA 14-18 en los cuatro sitios | ✅ código + migración |
| V3 | «[SEMILLA]» fuera de todas las filas | ✅ migración |
| — | Versión unificada en 1.4.0 (pie, `AppConfig`, `pubspec`, CHANGELOG) | ✅ |
| — | Logo oficial en el login (mostraba un cuadrado con «I») | ✅ |
| — | SEO: `theme-color` duplicado, esquema `WebSite` | ✅ |
| — | Guía de indexación en Google | ✅ `docs/GUIA_INDEXACION_GOOGLE_2026-10-25.md` |

## Lo que queda, por orden de impacto

**Sesión 1 — el cuadrante (V4, V5, V10)**
Es el bloque más grande del video y el más visible. La clave es que el filtro ya
funciona bien en Guardias Docentes: se porta ese patrón, se encadenan los bloques
horarios y se añade el nombre del curso al bloque.

**Sesión 2 — PNA como programa único y sus fechas (V7, V8, V9)**
Requiere migración de esquema (duración y estados en `academic_periods`) y las
cinco decisiones institucionales que el diseño del 2026-10-10 ya identificó.
V9 es la feature que propuse ayer y que el video confirma.

**Sesión 3 — MTP/PNA separados y reglas de reincorporación (V6, V11)**
Más acotado, pero toca lógica de negocio.

**Sesión 4 — pulido (V12, V13, V14)**
Carga, borrado de archivos, campos opcionales.

**V1 necesita reproducirse antes de tocarlo:** el campo de nombre existe y no
está deshabilitado, así que el fallo está en otra parte (¿el diálogo no abre?,
¿el guardado falla en silencio?). Sin verlo fallar no lo arreglo a ciegas.
