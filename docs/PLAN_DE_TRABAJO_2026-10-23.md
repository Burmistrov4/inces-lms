# PLAN DE TRABAJO — pulido, corrección y mejora (2026-10-23)

> **Para qué existe.** Lorenzo pidió el informe de lo hecho **y** el plan de cómo
> sigo puliendo el proyecto. Este documento es ese plan, con el estado medido, el
> hallazgo de rendimiento que cambia las prioridades y las fases en orden.

---

## 1. Estado actual (medido, no supuesto)

| Frente | Estado | Evidencia |
|---|---|---|
| Analizador Dart | **241 archivos, 0 errores / 0 avisos / 0 infos** | `node devops/analizar-dart.mjs` |
| Backend | **712/712 pruebas**, typecheck y lint en verde | `cd backend && npm run verify` |
| Matriz responsive | **186 capturas, 0 desbordes, 0 page errors, 0 no navegables** | `cd e2e && E2E_MATRIZ=1 node node_modules/@playwright/test/cli.js test matriz_responsive` |
| Conectividad local | **Resuelta (A1)**: el backend enlaza dual-stack en Windows y la matriz corre con **un solo comando** | `netstat`: `0.0.0.0:3001` + `[::]:3001` |
| Documentación | Reorganizada: raíz 15 → **7** `.md`; `docs/` 29 → **13**; historial 24 → **53** (nada borrado) | `docs/README.md` (índice único) |

---

## 2. HALLAZGO QUE CAMBIA LAS PRIORIDADES: el backend está sano pero lento

Medido el 2026-10-22 sobre 344 peticiones reales de la matriz:

| Métrica | Valor | Límite de Nielsen |
|---|---|---|
| Mediana | **853 ms** | 1 s (flujo) |
| p90 | 1424 ms | — |
| Máximo | **12 316 ms** | 10 s (atención) |
| Peticiones > 1 s | **112 de 344 (33 %)** | — |
| Errores | **0** (331×200, 13×204) | — |

**Conclusión:** no hay fallos; hay **lentitud**. Es la causa real de lo que
Lorenzo describió como «tarda en cargar» y del «No pudimos conectar»
intermitente (un pico de 12 s supera la paciencia del usuario).

**Y la causa NO es código ineficiente.** Verificado:

- El hook de autenticación ya hace los dos viajes de red **en paralelo**
  (`Promise.allSettled` en `plugins/autenticacion.ts`).
- `perfiles.listar` ya hace `count` + página **en paralelo** (`Promise.all`).

Lo que queda es **latencia de red a Supabase** desde esta máquina (~200–400 ms
por viaje, dos tandas por petición). En producción (Render → Supabase) será
menor, pero el patrón se mantiene.

**Implicación para el plan:** ya no se puede «optimizar el backend» mucho más sin
cambiar la arquitectura de datos. La palanca barata ahora es el **frente**:
cachear, no repetir peticiones y **mejorar el rendimiento percibido**.

---

## 3. Plan por fases (en orden)

### Fase A — Rendimiento percibido — **CERRADA DEL TODO** (2026-10-24)

**Objetivo:** que la app *se sienta* rápida aunque el backend tarde 850 ms.

1. **Esqueletos de carga** en vez de spinners: el usuario ve la forma del
   contenido mientras llega (reduce la percepción de espera).
2. **Caché en memoria por sección**: al volver a una sección ya visitada, mostrar
   lo último conocido al instante y refrescar en segundo plano. Hoy cada visita
   re-lanza ~20 peticiones.
3. **No repetir peticiones iguales** si una está en vuelo.

*Criterio de éxito:* volver a una sección ya vista debe pintar **sin espera**, y
toda espera mayor de 1 s debe mostrar progreso.

**Cierre definitivo (2026-10-24).** Faltaba extender el refresco en segundo
plano a los paneles donde los datos cambian por acciones de **otros** usuarios,
que es donde el dato viejo duele. Ahora está en **8 paneles** (los 4 de antes más
Registro de Accesos, Módulos del Sistema, Secciones del Período e Historial de
Configuración).

**El contrato tiene una trampa que documentar:** sin `marcarCarga()` en la rama de
éxito, el mixin **nunca dispara** —sale si no hay carga previa— y no falla nada:
simplemente no refresca. Es el fallo silencioso típico de este patrón.

Por eso se añadió `e2e/tests/refresco_al_volver.spec.ts`, que **mide peticiones
reales** y comprueba las tres cosas: la primera visita pide, volver enseguida no
pide (instantáneo), y tras 45 s sí pide. Compilar no demuestra que un refresco
dispare; medirlo sí.

### Fase B — Patrón de buscador (G9) — **CERRADA**

1. **Usuarios y Roles** — hecho (barra a todo el ancho, filtros en `Wrap`).
2. **Aulas** — hecho (`cpanel_aulas_panel.dart:258-262`, con el comentario que
   explica el patrón y por qué se abandonó el ancho fijo de 260 px).
3. **Programas** — hecho (`cpanel_programas_panel.dart:340-347`).

Los tres verificados en la matriz. **El plan estaba sin actualizar: el trabajo ya
estaba hecho desde la primera tanda del día.**

### Fase C — Robustez y deudas menores — **CERRADA**

1. **G6** — «Inscripciones y Cupos» no navegó una vez (transitorio): reproducir.
2. **El pico de 12 s** — investigar qué consulta fría lo provoca.
3. **Matriz con verificación de datos** — ya añadida: ahora Detecta el aviso
   «No pudimos conectar» y lo marca en el log (antes la matriz daba 0 desbordes
   con paneles vacíos).

### Fase E — UI/UX e intuitividad — **CERRADA (primera tanda)**

**Por qué existe:** Lorenzo lo señaló y tenía razón. Las fases A-C eran de
rendimiento y robustez; ninguna se ocupaba de que un administrador, un instructor
o un aprendiz **entiendan la app sin capacitación**. Se auditó la arquitectura de
información de los tres roles y se encontró jerga, nombres triplicados y acciones
que no hacen lo que prometen.

**Cambios aplicados:**

| Qué | Antes | Ahora |
|---|---|---|
| Admin: archivos | «Cloud CFS» (y dos nombres más para lo mismo) | **«Archivos del Centro»** |
| Admin: configuración | «Parámetros» | **«Configuración del Centro»** |
| Admin: secciones | «Secciones» | **«Secciones del Período»** |
| Admin: horarios | «Horarios de Clases» | **«Cuadrante de Horarios»** |
| Admin: botón del encabezado | «Inscribir Aspirante» (ese panel no inscribe a nadie) | **«Inscripciones y Cupos»** |
| Docente: asistencia | «Asistencia» / «Asistencia QR» | **«Pasar lista»** (un solo nombre) |
| Docente: materiales | «Material de apoyo» | **«Guías y materiales»** |
| Estudiante: inscripción | «Ofertas de cupos» | **«Inscribirme en un curso»** |
| Estudiante: tareas | «Mis entregas» / «Bóveda de Archivos» | **«Mis tareas»** / pestaña «Mis archivos» |
| Estudiante: expediente | «Mi Expediente» | **«Mi inscripción»** |
| Estudiante: materiales | «Material de apoyo» | **«Guías y materiales»** |
| Estudiante: menú | orden por implementación | **lo más usado primero** (aulas → asistencia → tareas) |

**También:**
- Fuera la jerga técnica visible: ya no se le dice «Cloudflare R2» al usuario.
- Estados vacíos que **enseñan qué hacer**, no sólo que no hay datos.
- La matriz E2E actualizada a los nombres nuevos (navega por título).

#### Segunda tanda — **CERRADA**

**1. Se quitó la mentira del explorador de archivos.** `_inicializarDatos()`
sembraba carpetas y documentos inventados —«Ing. Carlos Mendoza (Docente)»,
«Prof. Mario Alvarado», «Hace 5 días»— para que el panel no se viera vacío en la
demostración. El administrador abría «Archivos del Centro» y veía **personas y
documentos que no existen**. Ahora arranca vacío: lo real llega de
`/archivos/mios` y lo que no hay, no se pinta. **151 líneas de datos falsos
fuera.**

**2. Autor y fecha reales.** El `propietario` estaba escrito a mano
(«Administrador Maestro») incluso en los archivos que vienen del servidor, y el
tiempo era siempre «Hace un momento». Ahora:
- Los archivos del servidor muestran **de dónde vienen** (Entrega de tarea / Guía
  del docente / Documento del centro), que es lo que el admin necesita saber y es
  lo único que el API puede afirmar sin inventar (sólo devuelve `propietarioId`).
- Lo que crea el usuario va firmado con **su** nombre, no con uno fijo.
- El tiempo es relativo de verdad (`Ahora mismo` / `Hace N min` / `Hace N h`).

**3. Cuatro parámetros que mentían, ocultos.** `inscripciones_abiertas`,
`max_faltas_consecutivas`, `enrollment_lock_days` y `r2_presign_ttl_minutos` se
pintaban como interruptores pero **ningún camino del backend los lee**: el
administrador los cambiaba y no pasaba nada. Ocultos hasta que exista el código
que los use. **Un control que no hace nada es peor que no tenerlo**, porque el
usuario cree que configuró algo.

**4. Entregar una tarea: de 5 clics a 2.** «Mis tareas» mostraba la tarea pero el
botón decía «Abrir en Aula» y **ni siquiera abría la tarea**: navegaba a la
sección «Mis aulas», desde donde había que buscar el aula, entrar, buscar la
tarea y pulsar Entregar. Ahora cada tarjeta tiene **«Entregar»** y abre el mismo
gestor que usa el aula (`TASK_SUBMISSION` con el id de la tarea), así que la
entrega queda atada a la tarea exactamente igual. No es un camino paralelo: es el
mismo, con un clic menos de por medio.

**Lo que quedaba** (arquitectura, no UI) — estado al 2026-10-24:

**Parámetros muertos — RESUELTO en código, pendiente de aplicar en la nube.**
Migración `202610240001_limpiar_parametros_sin_efecto.sql`: borra las cuatro
filas y falla si alguna sobrevive. Validada con PGlite aplicando **todas** las
migraciones: **546 aserciones, 0 fallos**. `validate.mjs` pasó de 11 a 7
parámetros y sus dos aserciones dependientes se movieron a claves que sí existen.
**Falta un paso humano:** aplicarla con `SUPABASE_ACCESS_TOKEN`.

**Carpetas — decisión escrita, esperando a Lorenzo.**
`docs/DECISION_CARPETAS_2026-10-24.md` con el coste medido de las dos opciones:

| | Opción A (quitar) | Opción B (servidor) |
|---|---|---|
| Migraciones | **0** | 1 (tabla + RLS + FK) |
| Endpoints | **0** | 4 |
| Archivos Dart | 1 (el panel) | ~4 + el panel |
| Riesgo | medio-bajo | medio-alto |
| Alineado con Classroom | **sí** (`entity_type` ya es el eje) | no |

**Recomendación: A.** El eje de organización correcto ya existe en el producto
(`files_metadata.entity_type` + `entidad_id`); las carpetas añadían una segunda
verdad que además sólo vivía en un navegador.

### Fase D — Producto: multi-nube con Google Drive (F1 → F2 → F3) — **LA QUE SIGUE**

**Documento de diseño ya escrito:** `docs/DISENO_MULTINUBE_DRIVE_2026-10-23.md`.
Espera la decisión de Lorenzo (4 preguntas concretas).

**Antes de escribir código**, documento de diseño y decisión de Lorenzo
(él pide diagnóstico y plan primero):

- **F1** — login con Google + Drive como **espejo** (los archivos siguen en
  Drive; R2 se reserva y no se agota).
- **F2** — archivos de más de 25 MB: **ofrecer enlace de Drive** en vez de rechazar.
- **F3** — visores/editores dentro de la app (doc/docx, xlsx/xls, PDF, PPTX).

---

## 4. Reglas de trabajo (para no perder el norte)

1. **Medir antes de afirmar.** Ninguna cifra entra sin el comando que la produce.
2. **Verificar cada fase con la matriz** (un comando, gracias a A1) antes de
   seguir.
3. **Cerrar la deuda en el documento el mismo día que en el código.**
4. **Una captura fea es un defecto.**
5. **Detectar no es recuperar:** la matriz ahora también avisa si un panel cargó
   sin datos.

---

*Siguiente acción: Fase A, punto 1 — esqueletos de carga.*


---

## Actualización del 2026-10-23 (cierre de A y C)

| Fase | Estado | Resultado |
|---|---|---|
| **A.1** Esqueletos | **CERRADA** | `EsqueletoLista` en `lib/widgets/comunes.dart`, conectado a 16 paneles vía `EstadoPanel`. Verificado con captura a 80 ms. |
| **A.2** Caché + refresco | **CERRADA** | `lib/core/refresco_secciones.dart` (mixin `RefrescoAlVolver`, umbral 45 s) en Aulas, Programas, Usuarios y Roles, e Inscripciones. |
| **C** G6 + pico lento | **CERRADA** | G6 no se reprodujo (navega en los 6 perfiles). La lentitud es de **red a Supabase**: 281 ms local vs 349–1331 ms por viaje. |
| **D** F1→F2→F3 | **SIGUIENTE** | Requiere documento de diseño y decisión de Lorenzo. |

**Además, en la Fase C se encontraron y corrigieron dos cosas que no estaban en el plan:**

1. **Regresión propia:** el aviso de refresco genérico hacía recargar *todos* los
   paneles vivos en cada cambio de sección (el dashboard los mantiene en un
   `Stack`). `/admin/acceso` pasó de 990 ms a 4699 ms de media, con pico de 133 s.
   Corregido: el aviso lleva el título de la sección.
2. **El viewport alto retrasaba el arranque:** con 1280×1400 el motor de Flutter
   tarda 22 s en montar (frente a 8,8 s), y con la máquina cargada el login
   caducaba a los 60 s. Corregido: el viewport alto va después de iniciar sesión.

**Estado final verificado:** 186 capturas · 0 desbordes · 0 page errors ·
0 no navegables · 0 fallos de login · 0 sin datos · 0 peticiones fallidas.


---

## Actualización 2 (misma noche) — Arquitectura de datos: caché compartida

Lorenzo pidió «cambiar la arquitectura de datos para mejorar la velocidad». El
hallazgo fue concreto: **`/api/v1/mi-horario` se pedía 56 veces en una corrida**
(17 % de 328 peticiones) y las 56 eran la misma URL sin parámetros, porque cuatro
paneles leían el mismo horario cada uno por su cuenta.

**Implementado** (`lib/core/cache_lecturas.dart`): caché en memoria con TTL +
**single-flight**, que no cachea fallos y que **se vacía al cerrar sesión**.

| Métrica | Antes | Después |
|---|---|---|
| Peticiones a `/mi-horario` | 56 | **6** |
| Total de peticiones de la corrida | 328 | **257** |
| Capturas | 186 | 186 |
| Desbordes / page errors / no navegables | 0 / 0 / 0 | 0 / 0 / 0 |
| Fallos de login | 1 (flake) | **0** |

Además: el timeout de arranque del motor en la matriz subió de 60 s a 120 s.


---

# CIERRE DE LA NOCHE — 2026-10-23

## Lo que se hizo

| # | Trabajo | Resultado medido |
|---|---|---|
| 1 | **Fase A.1** — esqueletos de carga | `EsqueletoLista` conectado a 16 paneles vía `EstadoPanel`; verificado con captura a 80 ms |
| 2 | **Fase A.2** — caché + refresco en segundo plano | Mixin `RefrescoAlVolver` (umbral 45 s) en 4 paneles admin + Inscripciones |
| 3 | **Fase C** — G6 y el endpoint lento | G6 no se reprodujo; la lentitud es de red a Supabase (281 ms local vs 349–1331 ms por viaje) |
| 4 | **Arquitectura de datos** (lo que pidió Lorenzo) | Caché compartida con *single-flight* en los 9 endpoints más calientes |
| 5 | **Pulido de calidad** — auditoría de las 186 capturas | 4 defectos de UI corregidos + 1 bug del verificador |
| 6 | **Fase D** — documento de diseño | `docs/DISENO_MULTINUBE_DRIVE_2026-10-23.md`, espera decisión |

## El número que resume la noche

**328 → 167 peticiones por corrida completa de la matriz: un 49 % menos.**
Y a la vez, **más capturas cargadas con datos reales** (la caché destapó un
desborde latente que antes tapaba el esqueleto).

| Endpoint | Antes | Después |
|---|---|---|
| `/mi-horario` | 56 | 5 |
| `/admin/periodos` | 45 | 3 |
| `/admin/programas` | 46 | 9 |
| `/admin/acceso` | 36 | 6 |
| `/admin/usuarios` | 32 | 5 |
| `/admin/usuarios/invitaciones` | 30 | 5 |
| `/admin/ocupacion` | 33 | 3 |
| `/admin/secciones` | 30 | 6 |
| **TOTAL** | **328** | **167** |

## Estado verificado

- Matriz: **186 capturas** · 0 desbordes · 0 page errors · 0 no navegables ·
  0 fallos de login · 0 sin datos · 0 peticiones fallidas
- Analizador Dart: **243 archivos, 0 errores / 0 avisos / 0 infos**
- Backend: **712/712** pruebas

## Lo que queda

1. **Fase D (multi-nube con Drive)** — el documento de diseño está escrito con
   tres opciones y una recomendación (B: Drive sólo para lo que no cabe). Faltan
   las 4 decisiones de Lorenzo.
2. **Refresco automático en el resto de paneles** — el mixin `RefrescoAlVolver`
   está en 4 paneles; el patrón está documentado para enchufarlo a los demás.
3. **Verificación funcional en navegador** de «Invitar docente» y de la promoción
   de administradores en producción (falta una cuenta de prueba autorizada).

---

# Actualización del 2026-10-24 — Fase D cerrada y verificación funcional completa

## Fase D — **CERRADA**

Lorenzo delegó las cuatro decisiones del documento de diseño. Quedan escritas con
su justificación en `docs/DISENO_MULTINUBE_DRIVE_2026-10-23.md`:

| Decisión | Elección | Por qué |
|---|---|---|
| ¿A, B o ambos? | **B** | A exige OAuth, pantalla de consentimiento verificada y custodiar tokens de refresco; B resuelve el mismo problema pegando un enlace |
| ¿Qué cuenta de Drive? | La del usuario, **sin que el sistema la toque** | Sin OAuth no hay credencial que custodiar |
| ¿Enlace muerto? | **Se avisa** | Se marca «enlace externo»; comprobar exigiría la API que B evita |
| ¿Visores propios (F3)? | **No** | Se abre en pestaña nueva: cero código, cero riesgo |

**Implementado (F2):** cuando una subida falla por `ARCHIVO_DEMASIADO_GRANDE`, el
error deja de ser un callejón sin salida y ofrece **«Subirlo a Drive»**, que abre
el diálogo de enlace que ya existía. La rama de fallo distinguía antes sólo el
mensaje, así que no había forma de ofrecer una salida distinta según el motivo.

## Verificación funcional módulo por módulo

Suite funcional completa: **30 pruebas, 0 fallos**. Cubre el flujo público, el
panel administrativo entero, el aula virtual y su ciclo, el stepper de inscripción,
la exportación a HACER, el SEO público y el refresco al volver.

**Tres bugs reales salieron de esa verificación:**

1. **«Usuarios y Roles» abría con el formulario de invitación ocupando el pliegue**
   y la lista de usuarios debajo — el campo de búsqueda ni llegaba a construirse.
   La prueba se llama justamente «expone gestión real, no sólo invitaciones», y
   tenía razón. La invitación es ahora una acción plegable.
2. **`robots.txt` permitía rastrear todo el sitio** (`Allow: /`) y luego enumeraba
   a mano las rutas privadas. Eso falla por omisión: cualquier ruta nueva que no
   se añada queda expuesta. Ahora la política es la inversa (`Allow: /$` +
   `Disallow: /`), más los assets que la portada necesita.
3. **La prueba del CSV exigía «letra + 9 dígitos» a toda cédula**, y la base de
   pruebas guarda una de 19 dígitos sin letra. El exportador **no está roto**: su
   contrato es una derivación (letra de la cédula o de la nacionalidad + dígitos
   con relleno, **nunca recortados**). La prueba se reescribió para verificar esa
   derivación. El fixture pasó de 62 a 56 columnas porque la app quita los UUID
   crudos a propósito.

**Un fallo del arnés, no de la app:** `pulsarReal` pulsaba en el centro del nodo
sin comprobar que estuviera visible. El último ítem del menú del administrador
queda recortado por el pie (tema y cerrar sesión), así que el clic caía en el
selector de tema y el módulo nunca se abría. Ahora desplaza con la rueda del
ratón sobre la lista hasta que el punto caiga de verdad en el objetivo.
