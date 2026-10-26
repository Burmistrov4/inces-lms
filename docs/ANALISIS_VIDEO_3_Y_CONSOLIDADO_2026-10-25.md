# Análisis del tercer video y consolidado de los tres — 2026-10-25

**Archivo:** `2026-10-25 18-43-24.mp4` · 34:03 · versión 1.3.2
**Método:** 136 fotogramas cada 15 s y **audio transcrito** con Vosk (322 líneas).
Errores de reconocimiento: «pene a» = **PNA**, «metepec» = **MTP**, «laxos/laxa»
= **lapsos**, «ciudad/ciudadano» = **archivar/archivado**, «chida» = **archivar**,
«el venía» = **el PNA**.

Este es el video **de las decisiones**: los dos anteriores describían síntomas,
aquí Lorenzo dice qué quiere hacer con ellos. Y la decisión más grande es
eliminar un módulo entero.

---

## La decisión central: fuera «Lapsos Académicos»

Lo dice **cuatro veces** en el video, con una razón que no admite discusión:

> «el lapso marcado como vigente es el que gobierna las aulas virtuales, la
> asistencia y los horarios de hoy […] **dejamos el período y ya** […] pareciera
> que es como un [nivel] superior […] **yo siento que están de más** […] **el
> período [está bien] dejarlo, pero los lapsos están [de más]**» (23:11 – 23:37)

> «**los lapsos hay que eliminarlos por completo, son un desastre incómodo**» (20:19)

> «definitivamente hay que quitarlo […] no [es] nada más que [un] período» (32:32)

**El razonamiento, que es correcto:** «Período» y «Lapso» son dos niveles
jerárquicos para lo mismo. Un lapso que solo sirve para decir qué período está
vigente **es** el período. La duplicación obliga al administrador a crear dos
cosas antes de poder usar el sistema, y a archivarlas en el orden correcto.

**Esto ya estaba en el backlog como C6** («Fuera «Lapsos» y «Secciones» del
frente»), pero ahí se leía como una preferencia. En el video queda claro que es
una decisión tomada.

---

## Lo que este video añade a los dos anteriores

### T1 · El registro de accesos está vacío — **ALTO, causa encontrada**

> «[el registro de inicios de sesión] no aparece […] no se filtra bien […] sólo
> exitosa […] **no aparece ni sesión, total rota, no sirve**» (01:00 – 02:44)

**Medido y explicado.** `auth_logs` tiene **13 filas**, todas del 10 al 13 de
octubre. Siendo hoy 25 y habiendo entrado al sistema varias veces, **no se está
registrando nada nuevo**.

**La causa no es el panel: es el flujo de login.** El cliente hace

```dart
await auth.signInWithPassword(email: email, password: password);  // supabase_service.dart:75
```

**directo contra Supabase.** El backend sí tiene cuatro llamadas a
`acceso.registrar(...)` en `auth.ts`, pero **el cliente nunca pasa por
`/api/v1/auth/login`**, así que el backend no se entera de que alguien entró.

**Las dos salidas posibles**, y hay que elegir:

- **Trigger en la base** sobre `auth.audit_log_entries` (Supabase ya registra los
  logins internamente). No toca el cliente y es la opción que recomiendo, pero
  exige una migración que lea el schema `auth`, que hoy no está expuesto por
  PostgREST (`config.toml:13` solo expone `public`).
- **Que el cliente llame al backend** para iniciar sesión. Es más control, pero
  cambia el flujo de autenticación entero y es el camino con más riesgo.

### T2 · El cupo máximo es global y debería ser por sección — **ALTO**

> «cupo máximo […] tenemos veinticinco […] eso no sirve […] si tú quieres ajustar
> un cupo para una sección específica […] **debería ser específico para cada
> curso, no puede ser para uno solo para todo**» (04:20 – 05:10)

**Verificado:** `sections.cupo_maximo` existe por sección, pero el **parámetro
global** `m1_cupo_maximo` se aplica por encima. Dos sitios que dicen cuánta gente
cabe, y el global gana. Hay que decidir cuál manda y quitar el otro.

Y añade algo sobre el nombre del parámetro:

> «¿pero esto se supone que cuál entidad? un usuario no entiende que se está
> refiriendo» (05:49 – 05:53)

### T3 · «Aula Virtual» no se encuentra en Google — **ALTO**

> «las aulas virtuales […] **yo cuando google [busco] no aparece nada** […] cero,
> cero, cero […] **ni siquiera indexado aparece** […] y sea aula virtual o sea
> classroom […] yo creo que habría que cambiarle a clase, aula virtual o campus»
> (11:16 – 12:30)

**Confirma el diagnóstico de `docs/GUIA_INDEXACION_GOOGLE_2026-10-25.md`** desde
el otro lado: no es que la página esté mal posicionada, es que **no está en el
índice**. Y aporta una idea que no había considerado: el nombre «aula virtual» es
genérico y compite con miles de páginas; uno más específico («campus INCES La
Isabelica») tendría menos competencia.

### T4 · Mover «Secciones del Período» y «Campos de Inscripción» a Programas — **MEDIO**

> «secciones del período […] **habría que llevarlo para programas académicos**»
> (09:56 – 10:21)
> «campos de inscripción […] creo que lo que debe [hacer] era quedar en programa
> académico» (26:14)

El menú tiene demasiados apartados sueltos que pertenecen a un mismo flujo.

> «**siento que es demasiada [información], agobia a cualquiera**» (19:45 – 19:59)

### T5 · No se pueden renombrar las materias — **ALTO**

> «**no puedo cambiar nombres, son materias feas** […] dónde pone ver más materia,
> crear materia» (28:07)

Y de paso, otra vez la etiqueta:

> «evitar este nombre de semilla» (28:20)

**Medido:** las **3 materias** se llamaban «… [SEMILLA]». **Corregido hoy**
(migración `202610250003`). El renombrado desde el panel es otra cosa y hay que
comprobarlo.

### T6 · La materia debería ser opcional en el cuadrante — **MEDIO**

> «no podría colocar la materia como opcional mientras no la quiera colocar» (28:42)

Hoy el bloque exige curso **y** materia; hay bloques donde la materia no aplica.

### T7 · El aviso que se cierra vuelve a aparecer — **MEDIO**

> «esto lo [había] eliminado [en] un video y **se volvió a mostrar ahorita** […]
> cómo es eso posible, está eliminado, no hay una cruz» (14:41 – 14:59)

Estado que no persiste entre sesiones: se cierra, se recarga y vuelve.

### T8 · Cédula en el perfil del administrador — **ALTO**

> «acordamos poder [en] una [sección de] perfil guardar aquí una cédula y poder
> iniciar sesión tanto [con cédula] como con mi correo […] **tampoco está**» (16:45)

**Contexto:** el login con cédula **ya funciona** para admin y docente desde hoy
(migración `202610250001`). Pero eso solo sirve si el administrador **tiene** una
cédula guardada, y **no hay ningún campo en el perfil para ponerla**. El arreglo
de hoy habilitó la puerta; falta la llave.

### T9 · Autocompletado de contraseña — **BAJO**

> «coloqué el correo pero **no colocó automáticamente la contraseña**» (00:11)

Faltan los atributos `autocomplete` en los campos del login.

### T10 · Validación de cédula al llenar la planilla — **MEDIO**

> «en el momento de rellenar la planilla virtual […] [si] detecta [cédula]
> inválida, mándalo como sucede […] hay un límite» (18:49 – 19:17)

### T11 · Espacios: virtual o físico indistinto — **BAJO**

> «aunque no [sea] virtual o física, simplemente es un espacio que uno crea» (33:38)

### T12 · Rendimiento — **MEDIO**

> «tarda en cargar», «no puedo ni moverme», «varios clics» (27:04, 16:35)

---

## Consolidado: los tres videos juntos

**96 minutos de revisión, 40+ hallazgos, 12 temas que se repiten en los tres.**
No es una lista de deseos: es el mismo puñado de problemas visto desde ángulos
distintos.

### Los cinco que aparecen en los tres videos

| Tema | V1 | V2 | V3 |
|---|---|---|---|
| **El cuadrante no filtra por día** | ✅ | ✅ | ✅ |
| **MTP y PNA mezclados** | ✅ | ✅ | ✅ |
| **Responsive: inusable en móvil** | — | ✅ | ✅ |
| **PNA como programa aparte, con fechas** | ✅ | ✅ | ✅ |
| **Avisar cuándo abre la próxima inscripción** | ✅ | ✅ | ✅ |

**Estos cinco son el proyecto.** Todo lo demás es importante pero secundario.

### Lo corregido en esta sesión

| Qué | Cómo se verificó |
|---|---|
| Paginación de usuarios (72 → 11) | contra la base real + test de regresión |
| PNA 14-18 en los cuatro sitios | base: `CUR-INT-01` dice «(14-18 años)» |
| `[SEMILLA]` fuera de programas **y materias** | base: 0 filas con la etiqueta |
| Login con cédula para admin y docente | migración aplicada, 53 versiones |
| Versión unificada en 1.4.0 | `main.dart.js` desplegado lo contiene |
| Logo oficial en la landing y el login | captura de producción |
| Icono de la app (la «i» con chispa) | `sha256` idéntico al desplegado |
| `theme-color` duplicado | un solo `meta` |
| `robots.txt` con política inversa | desplegado |

### El plan, en orden de impacto

**Sesión A — El cuadrante.** Filtro por día (portar el de Guardias, que sí
funciona), bloques encadenados, nombre del curso y del docente en el bloque,
materia opcional, y **la vista móvil**. Es el tema de los tres videos y el único
que hace el sistema inutilizable para un rol entero.

**Sesión B — Eliminar «Lapsos».** Decisión tomada. Toca esquema, menú, permisos y
las referencias en aulas/horarios. Es la operación más delicada del plan porque
borra un nivel jerárquico que hoy usan otras tablas.

**Sesión C — PNA como programa único, con fechas.** Inicio, fin y próxima
inscripción por curso individual, visibles en Inscripciones y Cupos y en la
landing. Es la feature que los tres videos piden con más insistencia después del
cuadrante.

**Sesión D — Accesos, cédula en el perfil y cupos.** Trigger de auditoría,
campo de cédula en el perfil, y decidir qué cupo manda (el global o el de la
sección).

**Sesión E — Pulido.** Renombrar materias, mover apartados al menú correcto,
autocompletado, aviso que persiste, validación de cédula.

### Lo que necesito de Lorenzo

1. **Decidir el arreglo del registro de accesos:** trigger en la base o cambiar
   el flujo de login (T1). La primera opción no toca el cliente y es la que
   recomiendo.
2. **Decidir qué cupo manda** cuando el global y el de la sección no coinciden (T2).
3. **Confirmar el nombre nuevo de «Aula Virtual»** si se renombra (T3): «Campus»,
   «Clase Virtual» o el que prefiera.
