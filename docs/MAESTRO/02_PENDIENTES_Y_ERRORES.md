# 02 — PENDIENTES Y ERRORES (consolidado de todos los agentes)

> **Este es el único `.md` de pendientes.** Reúne lo que queda por corregir,
> mejorar o implementar, recogido de: el backlog vivo (`docs/BACKLOG_PENDIENTES.md`),
> la deuda de `ESTADO_DEL_SISTEMA.md`, los análisis de video V/N/T
> (`historial/reportes/ANALISIS_VIDEO*`), el `PLAN_CIERRE_INTEGRAL`
> (`historial/planes/PLAN_CIERRE_100_FUNCIONAL_2026.md`, F-series) y las auditorías.
>
> Cada ítem lleva **fuente (archivo:línea)** para poder verificarlo antes de actuar.
> Prioridad: 🔴 alto/bloqueante · 🟡 medio · 🟢 bajo · 🔒 bloqueado por humano/credencial.

---

## A. Defectos de UX/responsive reportados en videos (V/N/T) — 🔴 alta prioridad

Estos vienen de las transcripciones de los videos de Lorenzo (2026-10-25). Chocan
con el **objetivo primordial** del producto: "intuitivo y responsive real, como
Google". Varios fueron marcados "cerrados" en el backlog por fechas distintas —
**verificar en pantalla real antes de darlos por hechos**, porque el usuario los
volvió a señalar en video.

| # | Defecto | Fuente | Nota |
|---|---|---|---|
| V4 | Cuadrante de horarios no filtra por día | `ANALISIS_VIDEO_2026-10-25.md:78` | ✅ **VERIFICADO 2026-10-29 (noche)**: el filtro existe y funciona en `CpanelCuadrantePanel` y `CpanelPnaPanel` (`SelectorDeDias` + `diaFiltro` en la rejilla). Lo que **no** existía era la otra mitad: con «Todo» elegido, la tabla seguía siendo de 956 px. Ver N2 |
| V5 | Bloques horarios no se recalculan solos (encadenamiento 9:15+45m→10:00) | `ANALISIS_VIDEO_2026-10-25.md:96` | Hoy se pueden solapar |
| V6 | Confusión MTP/PNA en Guardias Docentes | `ANALISIS_VIDEO_2026-10-25.md:109` | Deben verse separados; el cuadrante de MTP no debe listar lo de PNA |
| V7 | PNA es UN solo programa (con sus materias y fechas) | `ANALISIS_VIDEO_2026-10-25.md:120` | Conceptual — alimenta la Fase 4/5 |
| V8 | Fechas de inicio/fin del curso y del período | `ANALISIS_VIDEO_2026-10-25.md:127` | Falta modelo de duración/caducidad de periodos (ver `03`, diseño `DISENO_PERIODOS_DURACION_Y_CADUCIDAD_2026-10-10.md`) |
| V9 | Avisar en «Cursos y PNA» cuándo abre la próxima inscripción | `ANALISIS_VIDEO_2026-10-25.md:138` | **Es la Fase 4** ("próxima apertura" desde el período vigente) |
| V10 | Cursos PNA deben aparecer en el cuadrante con nombre y docente | `ANALISIS_VIDEO_2026-10-25.md:149` | Fase 4/5 (agrupar cuadrante/PNA por curso) |
| V11 | "Dos veces consecutivas fuera" para reincorporar | `ANALISIS_VIDEO_2026-10-25.md:162` | Regla de negocio de reincorporación |
| V14 | Aula/espacio debería ser opcional; curso obligatorio | `ANALISIS_VIDEO_2026-10-25.md:183` | |
| N2 | Cuadrante inutilizable en el teléfono | `ANALISIS_VIDEO_2_2026-10-25.md:48` | 🔴 **CAUSA RAÍZ ENCONTRADA Y CORREGIDA 2026-10-29 (noche)**, en dos capas: (a) la tabla de la semana se pintaba siempre con «Todo» seleccionado —116 + 6·140 = 956 px dentro de 390—, ahora la forma la decide el ancho (`CuadranteGrid.cabeComoTabla`); (b) el panel pedía `limite=150` al catálogo de secciones y el backend rechaza >100 con `400`, así que **la rejilla se quedaba en esqueletos para siempre** (ver B15) |
| N3 | Herencia de horario al archivar/cerrar un lapso | `ANALISIS_VIDEO_2_2026-10-25.md:71` | Hoy se rehace desde cero cada período |
| N4 | Facilitador suplente (asignar suplente a un bloque) | `ANALISIS_VIDEO_2_2026-10-25.md:81` | |
| N5 | Rol elegible al invitar docente | `ANALISIS_VIDEO_2_2026-10-25.md:88` | |
| N6 | No se puede borrar una invitación | `ANALISIS_VIDEO_2_2026-10-25.md:98` | |
| N7 | Aviso "correo enviado" poco visible | `ANALISIS_VIDEO_2_2026-10-25.md:105` | 🟢 |
| N8 | Filtros tapa el contenido | `ANALISIS_VIDEO_2_2026-10-25.md:110` | 🟡 el usuario dice que los filtros ocultan lo que quiere ver |
| N9 | Logo del INCES pequeño / no aparece | `ANALISIS_VIDEO_2_2026-10-25.md:118` | 🟢 |
| T2 | Cupo máximo es global y debería ser **por sección** | `ANALISIS_VIDEO_3_2026-10-25.md:69` | 🔴 importante — el cupo global choca con el modelo de secciones de M4 |
| T6 | Materia opcional en el cuadrante | `ANALISIS_VIDEO_3_2026-10-25.md:121` | 🟡 |

> **Acción:** antes de cualquier "cierre", reproducir en navegador real a 390 px y
> con el flujo del usuario. El backlog marcó varios como cerrados por fechas; el
> video es la confirmación de que siguen abiertos.

---

## B. Deuda técnica y de código (verificada)

| # | Ítem | Fuente | Prioridad |
|---|---|---|---|
| B1 | **Las 6 specs E2E en rojo — re-medidas el 2026-10-29 (noche)**: `admin_cpanel_p0` **18/18 en verde** y `refresco_al_volver` **en verde** (la causa era el `viewport` pisado por `devices['Desktop Chrome']`); `live_prod_v124` y `auditoria_completa_sistema` pasan a **opt-in** (sólo navegaban y guardaban capturas en `C:/Users/Loro/.gemini/`); `aula_virtual` y `export_csv` **siguen en rojo por DATOS, no por código**: en la nube sólo queda **una sección y está archivada** (`select period_code,is_active from sections` → `SA26-2, false, 1`), así que «Mis aulas» no tiene tarjeta y «Cursos y PNA» no tiene tarjetas de donde exportar. Corrida medida: **19 pasan · 2 fallan · 11 no corren** (`e2e7.log`) | `e2e/tests/*.spec.ts` · `e2e/playwright.config.ts` | 🟡 |
| B2 | **15/143 archivos de `lib/` usan `LayoutBuilder`** — deuda responsive estructural; patrón híbrido tarjetas(<900)/tabla(≥900) en `cpanel_usuarios_roles_panel.dart` | memoria proyecto (`Deuda responsive`) | 🟡 |
| B3 | `CpanelSeccionesPanel` (676 líneas) **no lo instancia nadie** desde D11 → hoy no se puede crear una sección desde la UI. Falta borrar el panel huérfano (Fase 5) | `ESTADO_DEL_SISTEMA.md:123` · `BACKLOG_PENDIENTES.md:C10` | 🔴 |
| B4 | ✅ **CERRADO 2026-10-29 (noche)** — `verificar-esquema.mjs` tenía 5 rojos y **4 eran expectativas muertas**: las tablas `password_resets`/`planilla_observaciones`/`planilla_versiones` (nuestras, de `202610060001` y `202610090002`, con RLS) figuraban como «sobrantes»; `habilitar_sistema_bids` (retirado por `202610260001`) se seguía exigiendo; el recuento de cursos libres estaba fijado en 5 cuando el centro ya tiene 6; y el tope de archivos de M5 se comparaba con el valor exacto, no con su forma. Corregido: ahora da **147 OK y 1 rojo que es deriva real** (ver B13) | `supabase/verificar-esquema.mjs` · `node supabase/verificar-esquema.mjs` → exit 1 con 1 fallo | ✅ |
| B13 | 🔴 **`m7_calificaciones` y `m8_pasantias` están ENCENDIDOS en la nube** sin ninguna implementación detrás (sólo existe el icono en el panel de módulos). Ninguna migración los enciende: los prendió alguien desde el panel. El mandato dice que m8 debe estar OFF. **Requiere decisión de Lorenzo**: apagarlos o dejarlos. Mientras tanto `verificar-esquema.mjs` los marca en rojo a propósito | `supabase/verificar-esquema.mjs` (aserción nueva) · medido con `select clave, habilitado from system_modules` | 🔴 |
| B14 | 🔴 **La contraseña del administrador estaba escrita en claro en 5 specs** (`live_prod_v124`, `live_modulos`, `auditoria_completa_sistema`, `captura_dashboards_roles`, `matriz_responsive`) y lleva en el historial de git desde `a174718`. Retirada del código el 2026-10-29 (ahora se lee del entorno); **falta rotarla**, porque estar en el historial ya la deja comprometida | `grep -rn "Codenamelms33" e2e/` → 0 tras el arreglo | 🔴 🔒 |
| B15 | 🔴 **El cuadrante y el horario PNA no cargaban nunca**: pedían `limite: 150` al catálogo de secciones y el contrato admite **100** (`esquemaListadoSecciones` → `.max(100)`), así que el backend devolvía `400` y el panel se quedaba en esqueletos sin mensaje. Además el filtro viajaba como `soloActivas` y la API espera **`activa`**: Zod descarta la clave desconocida, de modo que también entraban las secciones archivadas. **Corregido 2026-10-29 (noche)**: `activa=true` + paginado con el máximo del contrato (`SeccionesRepository.listarTodasLasSecciones`). Medido: `/api/v1/admin/secciones?soloActivas=true&limite=150` → **400**; `/api/v1/admin/secciones?activa=true&limite=100` → **200** | `lib/services/secciones_service.dart` · `lib/repositories/secciones_repository.dart` · `test/secciones_paginadas_test.dart` | ✅ |
| B6 | `admin_dashboard.dart:242` sigue con `SA26-2` escrito a mano en la cabecera | `ESTADO_DEL_SISTEMA.md:70` | 🟢 |
| B7 | `AspiranteGateway.todos()` sin límite / `miFicha()` con `select` amplio — evaluar paginación/columnas mínimas | `PLAN_CIERRE_100_FUNCIONAL_2026.md:1074` · `PLAN_MAESTRO.md:28` | 🟡 |
| B8 | `trustProxy` y vistas sin `security_invoker` por medir contra producción | `ESTADO_DEL_SISTEMA.md:194` | 🟡 |
| B9 | Expediente del aprendiz + constancia de lectura de entregas: **no existe** | `ESTADO_DEL_SISTEMA.md:69` | 🟡 |
| B10 | D17: vista de exportación HACER expone lo que se puede sin especificación (falta lista de campos) | memoria proyecto · `ESTADO_DEL_SISTEMA.md:702` | 🟡 |
| B11 | D7: `opciones` no editable, `aplica_a` muerto, cinco credenciales por rotar | memoria proyecto | 🟡 |
| B12 | D9: barrido diario de archivos abandonados necesita 6 secretos (falla seguro) | memoria proyecto | 🟡 |

---

## C. Funcional pendiente (backlog abierto)

| # | Ítem | Estado | Fuente |
|---|---|---|---|
| C2 | Crear documentos ofimáticos (docx/xlsx/pdf/pptx) desde el gestor | ABIERTO | `BACKLOG_PENDIENTES.md:C2` |
| C3 | Enlaces de Google Drive con título automático en el gestor | ABIERTO | `BACKLOG_PENDIENTES.md:C3` |
| C4 | Reedición de planilla rechazada por el aspirante | ABIERTO | `BACKLOG_PENDIENTES.md:C4` |
| C5 | Semáforo de inscripción (abierta/cerrada) visible en los 3 dashboards | ABIERTO | `BACKLOG_PENDIENTES.md:C5` |
| C7 | Asistente virtual con catálogo de acciones | ABIERTO | `BACKLOG_PENDIENTES.md:C7` |
| A4 | Diálogos/modales a 390 px (verificar `anchoDialogoSeguro` en diálogos reales) | ABIERTO | `BACKLOG_PENDIENTES.md:A4` |
| A5 | Escalado de texto al 200 % (`textScaler`) | ABIERTO | `BACKLOG_PENDIENTES.md:A5` |
| A6 | DPR alto (2–3) en la matriz | ABIERTO | `BACKLOG_PENDIENTES.md:A6` |
| B2r | Ratio del panel lateral del gestor corta en 1100 px | ABIERTO | `BACKLOG_PENDIENTES.md:B2` |
| B3r | `cabeDoblePanelLadoALado` sin consumidores | ABIERTO | `BACKLOG_PENDIENTES.md:B3` |
| B4r | Rejillas de la landing no usan `rejillaDeTarjetas` | ABIERTO (baja) | `BACKLOG_PENDIENTES.md:B4` |

---

## D. Bloqueadores humanos / credenciales (🔒)

| # | Ítem | Por qué está bloqueado | Fuente |
|---|---|---|---|
| D1 | **H1 SMTP real** en Render (`SMTP_USER`+`SMTP_PASS`) — sin eso no sale correo | Lorenzo debe cargar las variables en Render | `ESTADO_DEL_SISTEMA.md:191` · `BACKLOG_PENDIENTES.md:D1` |
| D2 | Región de Render y `SUPABASE_JWT_SECRET` — palancas mayores de velocidad | Decisiones/credenciales del propietario | `ESTADO_DEL_SISTEMA.md:183` |
| D3 | Verificación en navegador de «Invitar docente» y de la promoción de administradores | Falta una cuenta de prueba autorizada | memoria proyecto |
| D4 | M7: validación de cámara QR en dispositivo físico | No hay dispositivo físico en el flujo de pruebas | memoria proyecto |

---

## E. Pendiente del `PLAN_CIERRE_INTEGRAL` (F-series, de otros agentes)

Estado del plan de "cierre funcional 100 %" (2026-10-09) — lo que ese agente dejó
sin marcar VERDE (fuente: `historial/planes/PLAN_CIERRE_100_FUNCIONAL_2026.md`):

| # | Ítem | Estado declarado | Fuente |
|---|---|---|---|
| F-PLN | Planilla oficial | 🔴 falta comparación visual final | `:580` |
| F-R2 | Archivos / Cloudflare R2 | 🔴 humo real existe; falta prueba UI alumno | `:581` |
| F-ASIS | Asistencia | 🟡 backend/RLS verde; falta cierre físico/dispositivo | `:583` |
| F-PAS | Pasantías (m8) | 🔴 OFF; por auditar | `:585` |
| F1.1 | Recuperación de contraseña / correo | 🔒 DEFERIDA (bloqueo de correo H1) | `:639` · `:1026` |
| F2 | Planilla: falta prueba post-integración donde las rutas HTTP generen el PDF y Alumno/Admin produzcan el mismo documento | No marcada VERDE | `:922` |
| Perf | Performance en curso; P-01 abierto, P-02 cerrado; responsive aún no iniciado (a esa fecha) | EN CURSO | `:1084` · `:1149` |
| Entrega | "Falta demostrar entrega real a un correo de profesor" | Bloqueado por correo | `:522` · `:705` |

> Nota: las cifras de ese plan son de 2026-10-09 y **están supersedidas** por
> `ESTADO_DEL_SISTEMA.md`. Úsalo solo para recuperar *criterios de aceptación* de
> flujos, no como estado actual.

---

## F. Decisiones vivas (requieren a Lorenzo)

- **Campus vs Aula Virtual:** la Especificación maestra (TAREA 9) ordena renombrar
  «Aula Virtual» → «Campus»; anulado por instrucción directa el 2026-10-27. Marcar
  como anulada **o** ejecutarla. (`ESTADO_DEL_SISTEMA.md:195`)
- **Periodos con duración/caducidad/estados:** solo diseño
  (`DISENO_PERIODOS_DURACION_Y_CADUCIDAD_2026-10-10.md`); requiere migración nueva +
  autorización + 5 decisiones institucionales.
- **MVP:** el LMS alimenta a HACER, no lo sustituye; no emite certificados.
