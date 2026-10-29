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
| V4 | Cuadrante de horarios no filtra por día | `ANALISIS_VIDEO_2026-10-25.md:78` | `BACKLOG_PENDIENTES.md` G10 dice "cerrado 2026-10-22" con `SelectorDeDias` en Horarios/Guardias; **verificar** que también aplica en el cuadrante dentro de `CpanelProgramasPanel` |
| V5 | Bloques horarios no se recalculan solos (encadenamiento 9:15+45m→10:00) | `ANALISIS_VIDEO_2026-10-25.md:96` | Hoy se pueden solapar |
| V6 | Confusión MTP/PNA en Guardias Docentes | `ANALISIS_VIDEO_2026-10-25.md:109` | Deben verse separados; el cuadrante de MTP no debe listar lo de PNA |
| V7 | PNA es UN solo programa (con sus materias y fechas) | `ANALISIS_VIDEO_2026-10-25.md:120` | Conceptual — alimenta la Fase 4/5 |
| V8 | Fechas de inicio/fin del curso y del período | `ANALISIS_VIDEO_2026-10-25.md:127` | Falta modelo de duración/caducidad de periodos (ver `03`, diseño `DISENO_PERIODOS_DURACION_Y_CADUCIDAD_2026-10-10.md`) |
| V9 | Avisar en «Cursos y PNA» cuándo abre la próxima inscripción | `ANALISIS_VIDEO_2026-10-25.md:138` | **Es la Fase 4** ("próxima apertura" desde el período vigente) |
| V10 | Cursos PNA deben aparecer en el cuadrante con nombre y docente | `ANALISIS_VIDEO_2026-10-25.md:149` | Fase 4/5 (agrupar cuadrante/PNA por curso) |
| V11 | "Dos veces consecutivas fuera" para reincorporar | `ANALISIS_VIDEO_2026-10-25.md:162` | Regla de negocio de reincorporación |
| V14 | Aula/espacio debería ser opcional; curso obligatorio | `ANALISIS_VIDEO_2026-10-25.md:183` | |
| N2 | Cuadrante inutilizable en el teléfono | `ANALISIS_VIDEO_2_2026-10-25.md:48` | 🔴 prioritario — el usuario dice "hay que usar la computadora" |
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
| B1 | **6 specs E2E en rojo** desde antes: `live_prod_v124` (espera «v1.2.4»), `admin_cpanel_p0` (nombre viejo), `export_csv` (flaky de login), `aula_virtual` («una tarjeta por sección»), `auditoria_completa_sistema` (2), `refresco_al_volver` | `ESTADO_DEL_SISTEMA.md:185` | 🔴 deuda de pruebas (no del producto) |
| B2 | **15/143 archivos de `lib/` usan `LayoutBuilder`** — deuda responsive estructural; patrón híbrido tarjetas(<900)/tabla(≥900) en `cpanel_usuarios_roles_panel.dart` | memoria proyecto (`Deuda responsive`) | 🟡 |
| B3 | `CpanelSeccionesPanel` (676 líneas) **no lo instancia nadie** desde D11 → hoy no se puede crear una sección desde la UI. Falta borrar el panel huérfano (Fase 5) | `ESTADO_DEL_SISTEMA.md:123` · `BACKLOG_PENDIENTES.md:C10` | 🔴 |
| B4 | `verificar-esquema.mjs` tiene **5 expectativas obsoletas** (espera `habilitar_sistema_bids`, tablas `password_resets`/`planilla_observaciones`/`planilla_versiones`, etc.) — un rojo suyo no significa que la base esté mal | `ESTADO_DEL_SISTEMA.md:45` | 🟢 quick win |
| B5 | Guardia anti doble-clic `lib/widgets/guardia_toque.dart` — usar `conGuardia` en TODO botón que abra diálogo o mute estado | memoria proyecto | 🟡 |
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
