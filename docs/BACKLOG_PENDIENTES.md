# BACKLOG DE PENDIENTES — INCES LMS

> **Para qué existe:** que ningún problema detectado se pierda entre sesiones.
> Cada fila lleva estado, evidencia y siguiente acción concreta. Se actualiza el
> mismo día que se cierra algo (regla del proyecto: «una deuda se cierra en el
> documento el mismo día que en el código»).
>
> Creado: 2026-10-21 · Autor: Aria · Dueño del producto: Lorenzo Roca.
>
> **¿Sos un agente nuevo o te quedaste sin contexto?** Lee primero
> [`docs/handover/REPORTE_CONTINUIDAD_2026-10-22.md`](handover/REPORTE_CONTINUIDAD_2026-10-22.md):
> estado verificado, comandos exactos, trampas medidas del entorno y por dónde
> empezar. Después volvé a este backlog, que está sincronizado con él.

## OBJETIVO PRIMORDIAL (anotado 2026-10-21, orden explícita de Lorenzo)

> **La app tiene que ser INTUITIVA y tener un responsive REAL, como si lo hubiera
> hecho un ingeniero de Google.** Debe poder usarla un profesor mayor sin
> dificultad. No basta con que "quepa": tiene que verse y usarse bien en
> **absolutamente todas** las pantallas, y cada apartado, módulo y segmento se
> revisa al mínimo detalle.
>
> Consecuencia práctica: cada vez que se adapte un panel al responsive, se
> revisa TAMBIÉN su **facilidad de uso** (etiquetas cortas, jerarquía clara,
> objetivos táctiles ≥48 dp, textos que no se amontonan, acciones obvias). Una
> captura fea es un defecto, no un detalle.

---

## Leyenda de estado
- **ABIERTO** — detectado, sin empezar.
- **EN CURSO** — se está trabajando.
- **BLOQUEADO** — depende de algo externo (humano, credenciales, decisión).
- **CERRADO** — resuelto y verificado (se queda una línea, no se borra).

---

## A. Pruebas y verificación (prioridad actual: seguir probando)

| # | Pendiente | Estado | Evidencia / siguiente acción |
|---|---|---|---|
| A1 | **Conectividad local rota:** el backend escuchaba solo IPv4 y `localhost` resolvia a IPv6. | **CERRADO Y VERIFICADO (2026-10-22)** | Default condicional por plataforma en `backend/src/config/env.ts`: `platform() === 'win32' ? '::' : '0.0.0.0'`. En Windows enlaza dual-stack (`localhost` funciona); en Linux/CI/Render se mantiene IPv4 porque alli `::` enlaza SOLO IPv6 y dejaria ciego el servicio. Se quito `HOST` de `backend/.env` para que mande el default. **Bonus:** la matriz ahora corre con UN solo comando (`E2E_MATRIZ=1 node ... test matriz_responsive`), sin backend manual ni `E2E_ARRANCAR_BACKEND=0`: 186 capturas, 0 desbordes, 0 «No pudimos conectar». Backend: 712/712 pruebas. |
| A2 | **Perfil horizontal de móvil (844×390).** Material 3 advierte que un teléfono en horizontal tiene altura `compact` y ahí no cabe el doble panel. | **CERRADO (2026-10-21)** | Añadido a `matriz_responsive.spec.ts` y probado en los 29 apartados + superficies públicas. |
| A3 | **Superficies públicas** (`/login`, `/inscripcion`) a los 6 anchos. | **CERRADO (2026-10-21)** | Test añadido a la matriz; 12 capturas, 0 desbordes, 0 page errors. |
| A4 | **Diálogos/modales a 390 px.** Verificar que `anchoDialogoSeguro` evita desborde en los diálogos reales (Nueva carpeta, Invitar docente, Subir documento). | **ABIERTO** | Abrir cada diálogo a 390 y capturar. |
| A5 | **Escalado de texto (200 %).** Material exige que el layout sobreviva a texto al 200 %. | **ABIERTO** | Probar con `textScaler` o zoom del navegador; medir cortes. |
| A6 | **DPR alto (2–3).** Los móviles reales tienen devicePixelRatio 2–3; la matriz corrió a DPR 1. | **ABIERTO** | Añadir `deviceScaleFactor: 2` a un perfil. |

## B. Responsive / Material 3 (hallazgos de la investigación)

| # | Pendiente | Estado | Evidencia / siguiente acción |
|---|---|---|---|
| B1 | **Menú a 840 px.** Hoy el menú lateral permanente entra en `expanded` (≥840) y deja el contenido en 1 columna. Material 3 pide *navigation rail* en `expanded` y menú permanente en `large` (≥1200). | **CERRADO EN CÓDIGO (verificado 2026-10-25); el backlog estaba desactualizado** | Medido: `lib/widgets/andamiaje.dart:189-193` — `usaRail = medium || expanded`, `menuLateralFijo = large || xlarge` (≥1200). El comentario de las líneas 184-188 documenta el cambio con la medición del 2026-10-21. Nada que hacer. Nota vieja: `andamiaje.dart`: mover el umbral del menú permanente de 840 a 1200; rail en 840–1199. Exige re-medir la matriz. |
| B2 | **Ratio del panel lateral del gestor.** Corta en 1100 px; M3 pide `expanded` (840) con 70/30 o `medium` (600) con 50/50. | **ABIERTO** | `cpanel_explorador_archivos_panel.dart`: alinear con `cabeDoblePanelLadoALado`. |
| B3 | **`cabeDoblePanelLadoALado` sin consumidores.** Se añadió la clase de altura pero ningún panel la usa todavía. | **ABIERTO** | Cablear en el gestor de archivos y en cualquier doble panel. |
| B4 | **Rejillas de la landing** (`pilares`, `perfiles`) no usan `rejillaDeTarjetas`. | **ABIERTO (baja)** | Son superficie pública bespoke; unificar cuando se toque la landing. |
| B5 | **Rejilla de horarios pobre en movil.** `CuadranteGrid` era una tabla de **1124 px fijos** (6 dias x 168 + gutter 116) dentro de un `SingleChildScrollView` horizontal: en 390 px solo se veia «Bloque/Hora» + «Lunes» a medias. | **CERRADO Y VERIFICADO (2026-10-22)** | Opcion (a) implementada: **dos formas segun el ancho**. <1200 px → **selector de dia + lista vertical** de los 12 bloques (`_CuadrantePorDia`, patron de Google Calendario/Classroom en movil; el punto marca los dias con contenido). >=1200 px → la tabla con **ancho de columna adaptativo** (`clamp((ancho-116)/6, 104, 168)`), que cabe sin scroll. Ajuste final: el selector de dia pasa de `ListView` horizontal a **`Wrap`** porque con 6 chips el ultimo quedaba fuera de pantalla (medido: x=459 en 390). |
| B6 | **El detector de la matriz marca el scroll horizontal intencional como «desborde».** `CuadranteGrid` sale con 750 px de «exceso» a 390 aunque es scrollable. | **CERRADO (2026-10-23); el backlog estaba desactualizado** | Medido: `e2e/tests/matriz_responsive.spec.ts:154` define `enScrollHorizontal(nodo)` y la línea 174 lo aplica (`if (exceso > 2 && !enScrollHorizontal(nodo))`). La matriz corre 0 desbordes en 6 perfiles. Nota vieja: Refinar el detector para distinguir nodo dentro de un contenedor scrollable de nodo recortado sin scroll. Mientras tanto, interpretar a mano. |

## C. Funcional / producto (Fases 2–4 del plan)

| # | Pendiente | Estado | Evidencia / siguiente acción |
|---|---|---|---|
| C1 | **Conectividad backend local** (misma raíz que A1). | **CERRADO (2026-10-22) con A1** | Medido: `backend/src/config/env.ts:43` fija el default dual-stack (`::` en Windows, `0.0.0.0` en el resto) y `backend/.env` ya no define `HOST`. Nada que hacer. |
| C2 | **Crear documentos ofimáticos** (docx/xlsx/pdf/pptx) desde el gestor. | **ABIERTO** | Fase 2, ciclo 3. |
| C3 | **Enlaces de Google Drive** con título automático en el gestor. | **ABIERTO** | Fase 2, ciclo 3. |
| C4 | **Reedición de planilla rechazada** por el aspirante. | **ABIERTO** | Fase 3. |
| C5 | **Semáforo de inscripción** (abierta/cerrada) visible en los 3 dashboards. | **ABIERTO** | Fase 3. |
| C6 | **Fuera «Lapsos» y «Secciones» del frente**; materias PNA + horarios AM/PM. | **ABIERTO** | Fase 3 (requiere migración + decisión institucional). |
| C7 | **Asistente virtual** con catálogo de acciones. | **ABIERTO** | Fase 4. |
| C8 | **Docente «Mis aulas» muestra «No pudimos conectar»** en vez de «no tienes aulas» si la cuenta no tiene matrículas. | **CERRADO EN CÓDIGO (verificado 2026-10-25); el backlog estaba desactualizado** | Medido: `lib/screens/mis_aulas_panel.dart:150-165` ya distingue los dos casos. El error sólo se pinta por `EstadoPanel(cargando: _cargando, error: _error, …)` (línea 138), que recibe `_error` **sólo cuando la carga falla de verdad**. El estado vacío tiene su propio `PanelVacio` con título «Todavía no tienes aulas activas» y mensaje distinto para docente («Cuando la coordinación del centro te asigne secciones…») y para estudiante. No queda nada que arreglar. |

## D. Infraestructura / humano

| # | Pendiente | Estado | Evidencia / siguiente acción |
|---|---|---|---|
| D1 | **H1 SMTP real** en Render (`SMTP_USER` + `SMTP_PASS`). Sin ellas no sale correo. | **BLOQUEADO (humano)** | Lorenzo debe cargar las variables en Render. |
| D2 | **Commit pendiente** de todo lo de esta sesión. | **BLOQUEADO (Lorenzo)** | No se commitea hasta que él diga «commitea» (regla del repo). |

## E. Bugs críticos encontrados al probar (2026-10-21)

| # | Bug | Estado | Evidencia / arreglo |
|---|---|---|---|
| E1 | **Toda la navegación por menú lateral y los botones de la barra superior estaban MUERTOS.** `onTap: () => conGuardia(...)` llamaba a `conGuardia` y **descartaba el callback** que devolvía; el botón no hacía nada. Afecta a ~30 sitios: los 3 menús laterales (`_ItemMenu`), las 15 acciones de `barra_acciones_superiores.dart` y los accesos rápidos de los 3 dashboards. Regresión introducida al aplicar la guardia anti-rebote (2026-10-20); **compila sin error**, por eso no se había visto. | **CERRADO Y VERIFICADO (2026-10-21)** | `conGuardia` ahora **ejecuta de inmediato** y devuelve `void`; ajustados los 2 sitios del gestor que sí capturaban el callback. **Verificado con la matriz: 29/29 apartados navegan** (antes 0/29); captura de «Usuarios y Roles» muestra el panel real, no «Centro de Mando». *(Nota 2026-10-25: la variante `conGuardiaEn`, que este arreglo también mencionaba, se borró en la auditoría independiente por no tener un solo llamador — `docs/historial/reportes/AUDITORIA_INDEPENDIENTE_2026-10-25.md`, D5.)* |
| E2 | **`pulsarReal` no navega entradas de menú** (solo abre modales). La matriz debe usar `pulsar` (dispatchEvent) para el menú. | **CERRADO (2026-10-21)** | Cambiado en `matriz_responsive.spec.ts`; se verifica el breadcrumb anterior vs actual. |
| E3 | **Gestor de Archivos desbordaba 297 px a 390 / 344 a 600 / 115 a 840.** El detector instrumentado identificó el nodo exacto: **«Política de 10 GB»** en `_construirBarraCuota`, un `Row` rígido (icono + texto + barra de 140 + texto + `Spacer` + botón ≈ 640 px). | **CERRADO Y VERIFICADO (2026-10-21)** | `_construirBarraCuota` reescrita: dos filas hasta `expanded` (<840), una fila con `Flexible` desde 840. Matriz: **0 px en 390/600/840/844/1280/1700**. |
| E4 | **Encabezado del gestor demasiado comprimido a 390**: el título quedaba en «Ge…/Ar…». | **CERRADO Y VERIFICADO (2026-10-21)** | En compacto: título corto «Archivos» visible completo, sin subtítulo, sin toggle cuadrícula/lista y «Nuevo» como icono «+». Captura a 390 confirma «Archivos» legible y 0 px de desborde. |

---

## F. Ideas de producto GUARDADAS (orden lógico — incluir cuando toque)

> Lorenzo las dejó escritas el 2026-10-21 para no perderlas. **No se implementan
> todavía**: van después de estabilizar el Cloud Explorer. Se incluyen en este
> orden porque cada una depende de la anterior.

| # | Idea | Estado | Depende de / cuándo |
|---|---|---|---|
| F1 | **Multi-nube con Google Drive.** Inicio de sesión con cuenta Google para admin/docente/aprendiz; **importar** archivos del Drive y gestionarlos desde la app como **espejo** (siguen guardados en Drive), abrirlos dentro de la app. El R2 se reserva para lo imprescindible, así **nunca se agota**. | **DESCARTADA (2026-10-24, decisión de Lorenzo)** | Se eligió la opción B del documento de diseño: **sin OAuth**. Vincular la cuenta de Google exige pantalla de consentimiento verificada, custodiar tokens de refresco en el backend y tocar el login —que hoy funciona— para resolver un problema que se resuelve pegando un enlace. La salida cuando un archivo no cabe es «subirlo a Drive y pegar el enlace» (F2, cerrada). Nota vieja: Requería OAuth de Google + API de Drive; iba después de estabilizar el Cloud Explorer. |
| F2 | **Regla del límite (10 MB, `m5_max_bytes`) → enlace de Drive.** Si un archivo supera el límite del sistema, en vez de rechazarlo, ofrecer **vincular un enlace compartido de Drive**. | **CERRADA (2026-10-24)** | Commit `b254ea5`. Cuando la subida falla con `ARCHIVO_DEMASIADO_GRANDE`, el banner ofrece «Subirlo a Drive» y abre el diálogo de enlace. Ver `docs/DISENO_MULTINUBE_DRIVE_2026-10-23.md`, sección «Decisiones tomadas». |
| F3 | **Visores/editores dentro de la app:** doc/docx, xlsx/xls (incluidos formatos viejos de Excel), **PDF visor y editor**, **PPTX visor y editor**. | **DESCARTADA (2026-10-24)** | El enlace se abre en pestaña nueva: cero código y cero riesgo, y el visor de Google ya es mejor que uno propio. Ver decisión 4 en `docs/DISENO_MULTINUBE_DRIVE_2026-10-23.md`. Nota vieja: Fase posterior a F1; exige librerías de render (PDF.js, docx-preview, etc.) o servicio de conversión. |
| F4 | **Nombre del módulo.** Renombrar «Gestor de Archivos (R2)» a algo **corto, claro y genial** para los 3 roles. | **CERRADO (2026-10-21)** | Se adoptó **«Cloud CFS»**: menú, breadcrumb, accesos rápidos, walkthrough y encabezado del panel. Verificado: navega y 0 px en los 6 perfiles. | **Renombrado a «Archivos del Centro» en la Fase E (2026-10-24):** `grep -rn "Cloud CFS" lib/` da 0 menciones; el nombre vigente está en `admin_resumen_panel.dart` y `cpanel_explorador_archivos_panel.dart`. |

## G. Hallazgos de la captura del Cloud Explorer (2026-10-21)

| # | Hallazgo | Estado | Acción |
|---|---|---|---|
| G1 | **La cuota mostraba «1.84 GB de 10 GB» con la nube casi vacía.** Era un `static const double _cuotaUsadaGb = 1.84` (valor de demo). | **CERRADO (2026-10-21)** | Ahora se calcula sumando `tamanoBytes` de los archivos listados y se formatea (MB si <0.1 GB, GB con 2 decimales). Con los archivos de semilla muestra «6.8 MB», no 1.84 GB. **Decisión pendiente de Lorenzo:** si quiere la nube vacía de verdad, hay que quitar los archivos de semilla del gestor. |
| G2 | **La tarjeta «Almacenamiento Híbrido…» no se podía cerrar ni deslizar.** | **CERRADO (2026-10-21)** | Añadido botón **X** (`_mostrarTarjetaInfo`) que la oculta; se restaura al recargar. |
| G3 | **No se ven los archivos ni el espacio gestionable** en la captura del gestor: solo carpetas y la tarjeta informativa. | **PARCIAL (2026-10-22)** | Con el backend en dual-stack la app ya carga datos reales (se ve en Usuarios y Roles: «Invitaciones emitidas (15)»). Falta verificar que el listado de archivos de Cloud CFS pinte con datos reales; si el usuario no tiene archivos, mostrar estado vacío con acción. |
| G4 | **El sistema debe ser reactivo en tiempo real** (subida, borrado, cuota) y **a prueba de errores/excepciones/límites** de todo tipo. | **OBJETIVO TRANSVERSAL** | Incluir en cada panel del gestor: estados de carga/éxito/error, límites visibles, sin excepciones sin capturar. |
| G5 | **Guardias Docentes desbordaba** 15 px (840), 11 px (844) y 111 px (1280). El usuario ya lo señaló: «roles de guardía… le hace falta muchísimo por mejorar». | **CERRADO Y VERIFICADO (2026-10-22)** | Dos arreglos: (1) `TituloSeccion` pone las acciones en un `Wrap` **acotado** (`Flexible`) —beneficia a todas las cabeceras—; (2) la rejilla (`_matrizSemanal` y `_pizarraMural`) usa **ancho de columna adaptativo**. Matriz: **0 px en los 6 perfiles**. Captura a 840: las 5 columnas de días caben completas con datos reales. |
| G6 | **Inscripciones y Cupos no navegó** en una corrida (transitorio). | **CERRADO (2026-10-23): no se reprodujo** | La matriz cubre el apartado (`matriz_responsive.spec.ts:50`) y pasa 186/186 capturas con 0 no navegables en los 6 perfiles. La sección G6 de este documento ya lo daba por cerrado. |
| G7 | **El buscador se veía truncado («Bu…») a 390** y no quedaba claro si filtraba. | **CERRADO (2026-10-22)** | Patrón de Google: en la barra va una **lupa**; al tocarla el buscador **se expande a ancho completo** (autofoco + flecha para volver). El filtrado es **en vivo por nombre** (`_filtroBusqueda`). Cloud CFS verificado: 0 px en los 6 perfiles. |
| G8 | **Campos de formulario demasiado anchos**: a 1700 px, «Nombres», «Apellidos» y «Correo» se estiraban a ~1300–1400 px (lo señaló Lorenzo en la captura). | **CERRADO (2026-10-22)** | `cpanel_invitaciones_panel` y `perfil_panel` acotados con `ConstrainedBox(maxWidth: 720)` —patrón de formularios de Google: ancho legible, no estirado. |
| G9 | **Unificar el patrón de buscador en TODOS los módulos**: lupa que se expande a ancho completo, no campos inline. | **CERRADO EN SU VARIANTE «BARRA A TODO EL ANCHO» (2026-10-23); la variante «lupa colapsable» sigue abierta** | Medido el 2026-10-25: los tres paneles que el plan cita tienen la barra a todo el ancho en su propia fila, con los filtros en un `Wrap` debajo —verificado con `grep -c "a todo el ancho"` = 1 en `cpanel_usuarios_roles_panel`, `cpanel_aulas_panel` y `cpanel_programas_panel`. **Queda pendiente la variante más estricta** que pide este apartado: la lupa colapsable tipo Material 3 SearchBar, que hoy sólo tiene `cpanel_explorador_archivos_panel` (4 usos de `_buscando`). Los 13 paneles restantes con buscador siguen con campo visible siempre. Es decisión de diseño, no descuido: la barra siempre visible se eligió a propósito en la Fase B. |

## Cerrados hoy (2026-10-21)
- Error de arranque resuelto (config de build) + pantalla de fallo legible.
- Rejillas de los 3 resúmenes unificadas con `rejillaDeTarjetas`.
- 4 fallos de lint que rompían la CI (analizador 241 archivos, 0/0/0).
- Contrato ampliado con clases de altura de Material 3.
- Matriz de 145 capturas (29 apartados × 5 perfiles), 0 desbordes, 0 page errors.

---

## H. Reorganización documental (2026-10-22) — CERRADO

> **Motivo:** había 29 `.md` sueltos en `docs/` y 15 en la raíz, suficiente para
> confundir a cualquier agente. **Nada se borró:** 28 archivos movidos a
> `docs/historial/` (que pasó de 24 a 53 `.md`) y 2 fusiones. La regla del
> proyecto es trazabilidad hacia atrás.

| # | Hecho | Detalle |
|---|---|---|
| H1 | **Raíz: 15 → 7 `.md`** | Movidos a `docs/historial/planes/`: `PLAN_MAESTRO`, `ROADMAP`, `TODO`, `TODO_CIERRE_INTEGRAL`, `PLAN_CIERRE_100_FUNCIONAL`, `RESUMEN_ARQUITECTURA_PARA_IA`, `manual_ingenieria_gemini_argon`, `organizacion_y_evolucion_sistema`. |
| H2 | **`docs/`: 29 → 13 `.md`** | Auditorías fechadas → `historial/auditorias/`. Módulos ya implementados (briefings M4/M5, Aula Virtual, contratos API, plan de stack) → `historial/modulos-implementados/`. |
| H3 | 4 `AI_AGENT_*` → **`docs/AI_AGENT_PROTOCOLO.md`** | Bloqueos, protocolo, autonomía y eficiencia de tokens en uno. Originales en `historial/fusionados/`. |
| H4 | 3 `CLINE_*` → **`docs/CLINE_FASE_0_REGISTRO.md`** | Originales en `historial/fusionados/`. |
| H5 | `contexto-ia-unificado/` → `historial/fusionados/` | Duplicaba el pack `contexto-ia/` (que se queda). |
| H6 | **Índice único: `docs/README.md`** | Por dónde empezar · vigentes · raíz · historial. Enlazado desde `AGENT_START_HERE.md` y desde la cabecera de este backlog. |
| H7 | Enlaces arreglados | `AGENT_START_HERE.md`, `ESTADO_DEL_SISTEMA.md`, `CATALOGO_DOCUMENTAL.md`, `ESTRUCTURA_DOCUMENTAL.md`, `PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md`. **`HANDOVER.md` no se tocó** (inmutable hacia atrás, por regla). |
| H8 | **Nada se borró** | Verificado: `docs/historial/` conserva los 28 movidos + los 24 que ya tenía. |
| H9 | **Nuevo: `docs/REQUISITOS_NO_FUNCIONALES_UX.md`** | Vocabulario estándar (ISO/IEC 25010, heurísticas de Nielsen, límites de respuesta 0,1/1/10 s, Material 3) y objetivos medibles de usabilidad, retroalimentación y rendimiento. Es un requisito no funcional, no un adorno. |
| G10 | **No había filtro de día (Lun–Sáb) en Guardias ni visible en Horarios**, y los controles de ambos paneles estaban desorganizados (Lorenzo lo señaló el 2026-10-22). | **CERRADO (2026-10-22)** | Nuevo **`SelectorDeDias` compartido** (`Todo | Lun | Mar | Mié | Jue | Vie | Sáb`, con un punto en los días que tienen contenido) en los dos paneles. En Guardias **sustituye** al confuso «Lun–Vie / Lun–Sáb»; al elegir un día la rejilla muestra **solo ese día** en lista (se lee mejor que una columna suelta). En Horarios el filtro vive junto a la rejilla, no en la cabecera. `CuadranteGrid` recibe `diaFiltro`. |
| G11 | **Los controles de vista de Guardias desaparecían durante la carga** (la barra estaba dentro del `EstadoPanel`), y al aparecer movían todo el panel. | **CERRADO (2026-10-22)** | `_barraSubVistasYControles()` salió del `EstadoPanel` y vive en `build`, antes del `Expanded`: sólo gira el contenido, el usuario siempre ve dónde está. |

## Corte de luz del 2026-10-22 (leer antes de asustarse)
Hubo un corte del suministro eléctrico a mitad de la verificación. **No se perdió nada**: el
analizador quedó en 241/0-0-0 y los cuatro ficheros tocados (`cuadrante_grid.dart`,
`cpanel_cuadrante_panel.dart`, `cpanel_guardias_panel.dart`,
`estudiante_tareas_panel.dart`) estaban guardados en disco. Se recomprobó con
`node devops/analizar-dart.mjs` antes de seguir. Si un corte vuelve a pasar:
**releer el estado antes de reconstruir**.

---

## I. RENDIMIENTO MEDIDO (2026-10-22) — la palanca ahora es el frente

Sobre **344 peticiones reales** de la matriz:

| Métrica | Valor |
|---|---|
| Mediana | **853 ms** |
| p90 | 1424 ms |
| Máximo | **12 316 ms** |
| > 1 s | 112 de 344 (33 %) |
| Errores | **0** (331×200, 13×204) |

**No es un fallo: es lentitud.** Causa del «tarda en cargar» y del «No pudimos
conectar» intermitente (un pico de 12 s).

**Y no es código ineficiente** —verificado—: el hook de auth ya paraleliza sus dos
viajes (`Promise.allSettled` en `plugins/autenticacion.ts`) y `perfiles.listar`
ya hace `count`+página en paralelo (`Promise.all`). Lo que queda es **latencia de
red a Supabase** (~200–400 ms por viaje, dos tandas por petición).

**Plan completo:** [`docs/historial/reportes/PLAN_DE_TRABAJO_2026-10-23.md`](historial/reportes/PLAN_DE_TRABAJO_2026-10-23.md).
Fase A (rendimiento percibido: esqueletos + caché por sección) → Fase B (terminar
G9 en Aulas y Programas) → Fase C (G6, el pico de 12 s) → Fase D (F1→F2→F3).

**Además:** la matriz ahora **detecta paneles que cargaron sin datos** (avisa
«No pudimos conectar» en el log). Antes daba 0 desbordes con paneles vacíos.

## J. Trampa del proxy en el health check de Playwright (2026-10-23) — CERRADA

**Síntoma:** 72 de 186 capturas cargaban sin datos («No pudimos conectar») con la
matriz en verde y el backend respondiendo 200.

**Causa:** backend huérfano con código viejo (IPv4 only) + `reuseExistingServer`
de Playwright + health check contra `127.0.0.1` mientras la app usa `localhost`
(→ `::1` en Windows) = `ERR_CONNECTION_REFUSED`.

**Cura:** health check del backend con `localhost` (mismo host que la app) y A1
(dual-stack por defecto). Detalle en `.workbuddy-ai/memory/2026-10-21.md`.

**CORRECCIÓN (causa raíz real):** no era un backend huérfano. El entorno define
`HTTP_PROXY` (proxy del sandbox); el health check de Playwright salía por él, el
proxy respondía 502 y Playwright lo interpretaba como «servidor disponible», así
que **nunca arrancaba el backend**. La app, sin proxy, recibía
`ERR_CONNECTION_REFUSED`. **Cura:** `NO_PROXY=localhost,127.0.0.1,::1` en
`e2e/playwright.config.ts` + backend con `node` directo y `cwd` + health check
con `localhost`. **Verificado:** 186 capturas, 0 desbordes, **0 sin datos**.

## K. Fase A — Rendimiento percibido (2026-10-23)

| # | Hecho | Detalle |
|---|---|---|
| A.1 | **Esqueletos de carga** en vez de spinner | Nuevo `EsqueletoLista` en `lib/widgets/comunes.dart`: pinta la barra de búsqueda/filtros y N tarjetas con la forma de la lista real, con pulso suave (`FadeTransition` 0,45↔1). `EstadoPanel` ahora acepta `esqueleto` y por defecto muestra el genérico. **Por qué:** un `CircularProgressIndicator` centrado no dice *qué* está cargando; el esqueleto muestra la forma del contenido que viene y la espera se percibe más corta (límite de Nielsen de 1 s). |
| A.2 | **Pendiente:** caché por sección | Al volver a una sección ya visitada, mostrar lo último conocido al instante y refrescar en segundo plano. Hoy cada visita re-lanza ~20 peticiones. |

### A.2 — Caché por sección + refresco en segundo plano — CERRADO (2026-10-23)

**Hallazgo primero:** el dashboard **ya** cacheaba los paneles (`_panelesCargados`
+ `Stack` de `Offstage`), así que volver a una sección ya era instantáneo. Lo que
faltaba era la otra mitad del patrón de Google: que esos datos **no queden
viejos**.

**Implementado:**

- `lib/core/refresco_secciones.dart` (nuevo): `RefrescoSecciones` (un
  `ValueNotifier` estático, para no tocar constructores de 40 archivos) y el mixin
  `RefrescoAlVolver`.
- El dashboard avisa con `RefrescoSecciones.notificar()` en **los dos** sitios
  donde cambia de sección.
- Mixin aplicado a **Aulas, Programas y Usuarios y Roles**: al volver, si la
  última carga pasó de **45 s**, recargan **en silencio** (`_cargar(silencioso:
  true)`): no se vuelve a mostrar el esqueleto, se conserva lo que hay hasta que
  llegue lo nuevo.
- Umbral deliberado: volver a una sección tiene que ser **instantáneo**, así que
  si los datos son recientes no se pide nada.

**Para enchufarlo a otro panel:** mezclar `RefrescoAlVolver`, llamar a
`marcarCarga()` en el éxito de la carga e implementar
`refrescarEnSegundoPlano() => _cargar(silencioso: true);`.

## L. Fase C — G6 y el pico lento del backend (2026-10-23)

### G6 — «Inscripciones y Cupos»: **CERRADO**
Navega en los 6 perfiles, 0 desbordes, 0 no navegables. No se reprodujo: era
transitorio. Verificado en la corrida del 2026-10-23.

### El endpoint sistemáticamente más lento: `/api/v1/admin/ocupacion`
Medido sobre **519 peticiones reales** (corrida de la matriz, backend con log
visible gracias al arranlo con `node` directo):

| Endpoint | Media | Máximo | Peticiones |
|---|---|---|---|
| **`/admin/ocupacion`** | **1311 ms** | 2656 ms | 37 |
| `/mis-inscripciones` | 1197 ms | 1571 ms | 21 |
| `/admin/acceso` | 990 ms | **9898 ms** | 49 |
| `/ofertas` | 970 ms | 1562 ms | 25 |
| `/admin/usuarios/invitaciones` | 927 ms | **7457 ms** | 45 |
| resto | ~860–930 ms | ~1200 ms | — |

**Diagnóstico:** `ocupacion` lee la vista `v_ocupacion_secciones`
(`security_invoker` + funciones `definer` para los recuentos). El coste es de la
**base**, no del código: es una agregación. No se toca la vista.

**Acción aplicada (la palanca barata):** el mixin `RefrescoAlVolver` enchufado
también a `cpanel_inscripciones_panel.dart`, que es quien la consume. Antes de
los 45 s de umbral, volver a Inscripciones **no relanza** la petición.

**Picos (9,9 s / 7,5 s / 6,7 s):** en `acceso`, `invitaciones` y `usuarios`. Como
la media de esos tres es ~950 ms y el pico es 10× la media, tienen forma de
**arranque en frío** (primera consulta tras un rato sin tocar la base), no de una
consulta intrínsecamente lenta. **Abierto:** confirmar cronometrando la primera
petición después de un rato de inactividad.

### Cierre de la Fase C — la lentitud es de red, no del código (2026-10-23)

**Medición que lo demuestra** (mismo instante, misma máquina):

| Destino | Tiempo |
|---|---|
| `GET /salud` del backend local (no toca la base) | **281 ms** |
| Ida y vuelta a Supabase (REST), 4 consultas seguidas | **749 · 349 · 565 · 1331 ms** |

Nuestro backend hace **dos viajes en paralelo** (verificar token + leer perfil), así
que la mediana de ~800–1450 ms es exactamente **un viaje a Supabase**. No hay nada
que optimizar en el código: ya está paralelizado (hook de auth y `count`+página).

**Los picos de 60–67 s** son saturación de la red a Supabase (conectividad de
Venezuela), no una consulta lenta: en la misma corrida la mediana era de 1,4 s.

**Consecuencia para el proyecto:** en producción el backend corre en **Render**, más
cerca de Supabase, así que allí la latencia será menor. Las tres palas que sí
están en nuestra mano ya están aplicadas: **esqueletos** (Fase A.1), **caché con
refresco en segundo plano** (Fase A.2) y **menos peticiones**.

### Bonus encontrado y corregido: el viewport alto retrasaba el arranque

Medido: con el viewport de la matriz (1280×1400) el motor de Flutter tarda **22 s**
en montar, frente a **8,8 s** con el viewport por defecto. Con la máquina cargada
pasaba de los 60 s del timeout y **el login caducaba** (tres roles sin arrancar en
dos corridas seguidas). **Arreglo:** el viewport alto se pone **después** de iniciar
sesión, no antes. Verificado: 0 fallos de login.

## M. Arquitectura de datos: caché compartida de lecturas (2026-10-23)

**El hallazgo:** en una corrida completa de la matriz, `GET /api/v1/mi-horario`
se pedía **56 veces** —el 17 % de las 328 peticiones— y las 56 eran **la misma
URL sin parámetros**. Cuatro paneles distintos (Mis aulas, Asistencia,
Calificaciones, Mi horario) leen el mismo horario cada uno por su cuenta, y cada
lectura cuesta un viaje de red a Supabase.

**Lo implementado** (`lib/core/cache_lecturas.dart`, nuevo):

- `CacheLecturas.leer(clave, {ttl, fn})`: memoria con TTL **+ single-flight** (si
  dos peticiones iguales llegan a la vez, comparten una).
- **Un fallo no se cachea:** se borra la entrada para que el siguiente reintento
  salga de verdad.
- **Se vacía al cerrar sesión** (`AuthService.cerrarSesion`): la clave es la URL,
  así que sin vaciado el siguiente usuario del mismo dispositivo vería los datos
  del anterior durante el TTL.
- Aplicada a las dos lecturas de `/mi-horario` (`AulaService.misAulas` y
  `CuadranteService.miHorario`), que ahora **comparten** entrada.

**Resultado medido:** `mi-horario` pasa de **56 peticiones a 3** (18,7× menos), y
el total de la corrida de 328 a 220. El rol estudiante no llegó a entrar en esa
corrida (fallo de arranque del motor), así que el número real es todavía mejor.

**Además:** el timeout de arranque del motor de Flutter en la matriz subió de
60 s a 120 s (con la máquina cargada se pasaba de 60 s y el login caducaba).

## N. Pulido de calidad (2026-10-23, noche) — auditoría visual de las 186 capturas

Revisadas las capturas de los tres roles en varios anchos. Cuatro defectos
encontrados y corregidos:

1. **La cuota de R2 cortaba el porcentaje.** A 840 px, «6.8 GB de 10 GB (68.0 %)»
   no cabía y el `ellipsis` se comía el final: «6.8 GB de 10 GB (0...». El
   porcentaje va ahora en su propio elemento, así que no depende de que sobre
   sitio. (`cpanel_explorador_archivos_panel.dart`)
2. **«Administradores» se partía a mitad de palabra** a 390 px. El `ListTile` de
   las tarjetas de resumen gastaba 40 px de icono y 32 de padding, y a la palabra
   le quedaban ~80 px. Reemplazado por una fila propia: le sobran ~30 px y cabe
   entera. (`cpanel_usuarios_roles_panel.dart`)
3. **El esqueleto genérico contradecía la forma real.** Pintaba barra de búsqueda
   y pastillas en paneles que no tienen ninguna de las dos cosas. Ahora el
   esqueleto por defecto es neutro y los paneles que sí tienen barra la piden
   explícitamente. (`lib/widgets/comunes.dart`)
4. **Diez pluralizaciones perezosas** («sección(es)», «disponible(s)»). Helper
   `plural(n, singular, plural)` en `comunes.dart`; cero «(es)»/(s) en la
   interfaz.

### Bug del verificador encontrado por el camino

La matriz marcaba un desborde de **197 px** en la pizarra de guardias a 600 px.
Era un **rojo falso**: la pizarra vive dentro de un `SingleChildScrollView`
horizontal, así que su contenido pasa del viewport a propósito. El detector
medía todos los nodos contra el ancho de la ventana sin mirar si tenían un
ancestro con scroll. Corregido: un nodo dentro de un scroll horizontal no
desborda. **El rojo falso apareció porque la caché hizo que el panel cargara
antes y la captura pasara a mostrar la matriz real en vez del esqueleto.**

**Estado final:** 186 capturas · 0 desbordes · 0 page errors · 0 no navegables ·
0 fallos de login · 0 sin datos · 0 peticiones fallidas · 167 peticiones
(eran 328 al empezar el día).
