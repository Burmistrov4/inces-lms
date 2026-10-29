# 03 — PLANES Y OBJETIVOS

> Visión de producto, hoja de ruta de UX/responsive y las fases 4–5 del rediseño de
> secciones. Complementa `02_PENDIENTES_Y_ERRORES.md` (el *qué* falta) con el
> *para dónde* va el sistema. Fuentes: `docs/BACKLOG_PENDIENTES.md` (Objetivo
> primordial), `docs/PLAN_SIMPLIFICACION_SECCIONES_2026-10-29.md`,
> `docs/ESPECIFICACION_MAESTRA_REDISENO_1_5_2026-10-25.md`,
> `docs/REQUISITOS_NO_FUNCIONALES_UX.md`.

## Objetivo primordial (Lorenzo, 2026-10-21)

> La app tiene que ser **INTUITIVA** y tener un **responsive REAL**, como si lo
> hubiera hecho un ingeniero de Google. Debe poder usarla un profesor mayor sin
> dificultad. No basta con que "quepa": tiene que verse y usarse bien en
> **absolutamente todas** las pantallas. Cada apartado se revisa al mínimo detalle.

Consecuencia práctica (cada vez que se adapta un panel al responsive, revisar
**también** su facilidad de uso: etiquetas cortas, jerarquía clara, objetivos
táctiles ≥48 dp, textos que no se amontonan). Una captura fea es un defecto.

## Requisitos no funcionales de UX (medibles)

De `docs/REQUISITOS_NO_FUNCIONALES_UX.md` (ISO/IEC 25010, Nielsen, Material 3):
- Límites de respuesta: **0,1 s** (feedback) · **1 s** (mismo contexto) · **10 s**
  (límite de atención). Un esqueleto cuenta como respuesta a <1 s.
- Objetivos táctiles ≥48 dp; jerarquía visual clara; sin truncamientos de palabra.
- El layout sobrevive a texto al 200 % y a DPR 2–3.

## Hoja de ruta de UX / responsive (en curso)

1. **Responsive de detalle (A4/A5/A6/B2/B3/B4):** diálogos a 390 px, escalado 200 %,
   DPR 2–3, ratio del panel lateral del gestor, `cabeDoblePanelLadoALado` sin
   consumidores, rejillas de landing.
2. **Cerrar los defectos de video (V/N/T):** ver `02_PENDIENTES_Y_ERRORES.md`
   sección A. Priorizar N2 (cuadrante en móvil), V9/V10 (próxima apertura y PNA en
   cuadrante), T2 (cupo por sección), V5 (encadenamiento de bloques).
3. **Deuda `LayoutBuilder` (15/143):** migrar al patrón híbrido
   tarjetas(<900)/tabla(≥900) ya validado en `cpanel_usuarios_roles_panel.dart`.

## Fases del rediseño de secciones (`PLAN_SIMPLIFICACION_SECCIONES_2026-10-29.md`)

| Fase | Qué | Estado |
|---|---|---|
| 1 | Quitar secciones sueltas / red de menús | ✅ (previo) |
| 2 | Unificar «Lapsos»+«Secciones» y PNA/horarios AM-PM en «Período» | ✅ (Rediseño 1.5, 2026-10-28) |
| **3** | **Unificar «Cursos y PNA» + «Inscripciones y Cupos» en un módulo** | ✅ **CERRADA 2026-10-29** |
| **4** | **Landing por curso** con cupos y «próxima apertura» desde el período vigente | ⏳ **PENDIENTE** |
| **5** | **Borrar `CpanelSeccionesPanel`** cuando archivar/editar cupo viva en la tarjeta del curso | ⏳ **PENDIENTE** |

### Fase 4 — Landing por curso (detalle)
- Cada curso/PNA muestra: cupos ocupados/disponibles, ventana de inscripción y
  «próxima apertura» (calculado desde `academic_periods` vigente).
- Agrupar cuadrante/PNA **por curso**; el cuadrante lista cursos PNA con nombre y
  docente (V10).
- Alimenta el semáforo de inscripción (C5) y el aviso «cuándo abre la próxima» (V9).

### Fase 5 — Eliminar el panel huérfano
- `CpanelSeccionesPanel` (676 líneas) no lo instancia nadie desde D11. Una vez que
  crear/editar/archivar sección viva en la tarjeta del curso (fase 4), **borrarlo**
  con su prueba. Cierra R-22 (panel construido, inalcanzable) de raíz.

## Roadmap funcional (más allá de secciones)

- **Módulo 8 — Pasantías:** registro OFF; NO habilitar hasta completar el flujo
  (criterio de `PLAN_CIERRE_100_FUNCIONAL_2026.md:59`). Pendiente de diseño y E2E.
- **Planilla oficial:** cerrar comparación visual final (F-PLN) y prueba UI alumno
  (F-R2) — ver `02` sección E.
- **Asistencia QR:** recorrer el ciclo en navegador real / cámara física (F-ASIS, D4).
- **R2 / Drive:** enlace de Drive cuando un archivo excede el límite (F2, ya cerrado);
  visores/editores dentro de la app descartados (F3) a favor de abrir en pestaña.
- **Asistente virtual** (C7) y **documentos ofimáticos** (C2/C3): fase posterior.

## Decisiones que requieren a Lorenzo (no se adivinan)

- Campus vs Aula Virtual (TAREA 9 de la Especificación maestra).
- Modelo de **duración/caducidad/estados de periodos** (5 decisiones institucionales).
- Uno o varios grupos por curso y período (afecta la Fase 5).
- SMTP real en Render (H1) para correo transaccional.
