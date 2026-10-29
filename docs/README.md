# DOCUMENTACION — INCES LMS

> **Este es el indice unico.** Si sos un agente de IA o retomas el proyecto,
> lee en este orden y no te pierdas: el resto de los `.md` son historia.

---

## 1. POR DONDE EMPEZAR (en este orden)

| # | Documento | Para que |
|---|---|---|
| 1 | [`handover/REPORTE_CONTINUIDAD_2026-10-22.md`](handover/REPORTE_CONTINUIDAD_2026-10-22.md) | **Empieza aqui.** Estado verificado, comandos exactos, trampas medidas del entorno y por donde seguir. |
| 2 | [`BACKLOG_PENDIENTES.md`](BACKLOG_PENDIENTES.md) | Que falta, en orden logico, con evidencia. |
| 3 | [`REQUISITOS_NO_FUNCIONALES_UX.md`](REQUISITOS_NO_FUNCIONALES_UX.md) | Usabilidad, retroalimentacion, tiempos de respuesta (ISO 25010 + Nielsen). |
| 4 | [`AI_AGENT_PROTOCOLO.md`](AI_AGENT_PROTOCOLO.md) | Bloqueos del entorno, protocolo de operacion, uso eficiente de tokens. |
| 5 | [`../ESTADO_DEL_SISTEMA.md`](../ESTADO_DEL_SISTEMA.md) | **Fuente de verdad** del estado del sistema. Gana sobre cualquier otro documento. |

---

## 2. DOCUMENTOS VIGENTES

| Documento | Que es |
|---|---|
| `ESPECIFICACION_MAESTRA_REDISENO_1_5_2026-10-25.md` | **Mandato del Rediseño 1.5** (11 tareas, decisiones D1–D11). Ojo: su TAREA 9 («Campus») fue **anulada** el 2026-10-27; ver `ESTADO_DEL_SISTEMA.md`. |
| `ARQUITECTURA_Y_ESPECIFICACION_SISTEMA_SDD.md` | Arquitectura y especificacion (SDD). |
| `PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md` | Como desplegar (Render + Cloudflare Pages). |
| `CONFIGURACION_R2.md` | Configuracion del almacenamiento R2. |
| `PROJECT_PHASE_GATES.md` | Puertas de fase del proyecto. |
| `DISENO_MULTINUBE_DRIVE_2026-10-23.md` | Diseno de la Fase D (Drive): decisiones cerradas el 2026-10-24. |
| `DISENO_PERIODOS_DURACION_Y_CADUCIDAD_2026-10-10.md` | **Diseno pendiente de implementar** (duracion/caducidad de periodos). Requiere migracion nueva + autorizacion. |
| `INCES_PREMIUM_PRODUCT_DESIGN_SYSTEM.md` | Sistema de diseno del producto. |
| `ESTRUCTURA_DOCUMENTAL.md` | Estructura de carpetas de documentacion. |
| `CATALOGO_DOCUMENTAL.md` | Catalogo historico de documentos. |
| `CLINE_FASE_0_REGISTRO.md` | Registro fusionado de la Fase 0 de Cline. |
| `contexto-ia/` | Pack de contexto para agentes de IA (9 archivos, con su propio indice). **Sus cifras son del 2026-10-09/12**: envejecidas a proposito, re-medir antes de citarlas. |
| `diseno/` | Disenos por modulo (planilla, etc.). |
| `historial/reportes/` | Informes fechados. El mas reciente de cierre: `LOTE_5_CIERRE_2026-10-29.md`. |

---

## 3. EN LA RAIZ DEL REPOSITORIO (7 documentos)

| Documento | Que es |
|---|---|
| `README.md` | Presentacion del proyecto. |
| `ESTADO_DEL_SISTEMA.md` | **Fuente de verdad** del estado. |
| `HANDOVER.md` | Historial de traspasos (**inmutable hacia atras**, por regla del proyecto). |
| `CHANGELOG.md` | Registro de cambios. |
| `AGENT_START_HERE.md` | Entrada rapida para agentes. |
| `LEVANTAR_EN_LOCAL.md` | Como levantar el proyecto en local. |
| `MEMORY.md` | Memoria del proyecto. |

---

## 4. HISTORIAL (no leer para trabajar; esta por trazabilidad)

`docs/historial/` conserva **todo** lo que se movio el 2026-10-22. Nada se
borro: la regla del proyecto es trazabilidad hacia atras.

`docs/historial/reportes/` conserva los informes fechados de octubre 2026 que
estaban sueltos en `docs/` (movidos 2026-10-28): análisis de video (1–3 y
consolidado), auditoría independiente del 2026-10-25, decisión de carpetas,
guía de indexación en Google, plan de trabajo del 2026-10-23 y propuesta de
«próxima inscripción». Ya están aplicados o registrados; citarlos como historia.

| Carpeta | Contenido |
|---|---|
| `historial/planes/` | Planes maestros, roadmaps y TODOs superados (8). |
| `historial/auditorias/` | Auditorias y reportes fechados (14). |
| `historial/reportes/` | Informes de octubre 2026 + cierres de lote (9). |
| `historial/modulos-implementados/` | Briefings y contratos de modulos ya implementados (7). |
| `historial/fusionados/` | Originales de los documentos fusionados + el README anterior (8). |
| `historial/prompts/` | Prompts de agentes (15). |

---

## 5. REGLA

**Si este indice contradice a `ESTADO_DEL_SISTEMA.md`, gana `ESTADO_DEL_SISTEMA.md`.**
Y si contradice al codigo, gana el codigo.

*Indice reescrito el 2026-10-22. Antes habia 29 `.md` sueltos en `docs/` y 15 en
la raiz; ahora 15 y 7.* Recontado el 2026-10-29: **15** `.md` en `docs/` (antes
decia 13 y ya eran 15 cuando se escribio esa linea) y **7** en la raiz. Los dos
documentos de handoff que otra sesion dejo en `docs/` el 2026-10-28 se retiraron
el 2026-10-29 —contenian afirmaciones falsas— y su contenido, corregido, vive en
`historial/reportes/LOTE_5_CIERRE_2026-10-29.md`.*
