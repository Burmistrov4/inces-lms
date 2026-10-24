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

### Fase A — Rendimiento percibido — **CERRADA**

**Objetivo:** que la app *se sienta* rápida aunque el backend tarde 850 ms.

1. **Esqueletos de carga** en vez de spinners: el usuario ve la forma del
   contenido mientras llega (reduce la percepción de espera).
2. **Caché en memoria por sección**: al volver a una sección ya visitada, mostrar
   lo último conocido al instante y refrescar en segundo plano. Hoy cada visita
   re-lanza ~20 peticiones.
3. **No repetir peticiones iguales** si una está en vuelo.

*Criterio de éxito:* volver a una sección ya vista debe pintar **sin espera**, y
toda espera mayor de 1 s debe mostrar progreso.

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

**Lo que queda de esta fase** (segunda tanda, cuando Lorenzo quiera):
- Ocultar tras «Avanzado» cuatro parámetros que **nadie lee** en el backend
  (`inscripciones_abiertas`, `max_faltas_consecutivas`, `enrollment_lock_days`,
  `r2_presign_ttl_minutos`).
- Unificar «Archivos del Centro» con el Gestor Documental real (hoy son dos
  sitios para lo mismo; las carpetas del explorador viven sólo en el navegador).
- Reducir los 5 clics de «entregar una tarea» (la tarea se ve en «Mis tareas»
  pero sólo se entrega desde el aula).

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
