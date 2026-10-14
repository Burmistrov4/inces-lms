# Catálogo Markdown del repositorio

Dos partes. **§1 Clasificación curada** es la que responde qué es cada documento, para quién, si sigue vigente y qué hacer con él; **§2 Inventario automático** es la lista reproducible de los 217 Markdown con ruta, tamaño y clasificación Git, para localizar cualquier archivo. Inventario contado y clasificado el **2026-10-13 (Fase 1)** y **recontado al cierre de la misma fase**: **218 archivos Markdown en total**, 217 listados (el catálogo se excluye a sí mismo). El documento que faltaba en el primer recuento es `docs/handover/FASE1_CONSOLIDACION_DOCUMENTAL_2026-10-13.md`, que este catálogo se adelantó a listar. El desglose por categoría se corrigió el **2026-10-14**: 72 rastreados, 16 no rastreados y 130 ignorados (ver la tabla de la cabecera del §2).

Estados usados: **vigente** (se usa hoy), **histórico** (se conserva por su fecha, no manda), **obsoleto pendiente de revisión** (afirma algo que la medición posterior contradice), **pendiente de verificación** (no se ha podido medir). «Canónico relacionado» señala a qué documento remite cuando hay solapamiento.

## §1. Clasificación curada

### 1.1 Entrada, estado y precedencia

| Ruta | Propósito | Público | Estado | Canónico relacionado | Acción recomendada |
|---|---|---|---|---|---|
| `AGENT_START_HERE.md` | Ruta de trabajo obligatoria y corta para agentes | Agentes de IA | vigente | `docs/README.md` | Mantenerla corta: una tarea sencilla no debe exigir leer prompts ni historial |
| `docs/README.md` | Punto de entrada documental único, por finalidad y público | Todos | vigente | — | Revisar sus enlaces al mover cualquier documento |
| `docs/ESTRUCTURA_DOCUMENTAL.md` | Jerarquía de precedencia y reglas de mantenimiento | Todos | vigente | — | Es la jerarquía; no duplicarla en otros archivos |
| `docs/CATALOGO_DOCUMENTAL.md` | Este catálogo | Todos | vigente | `docs/README.md` | Regenerar §2 al añadir o mover Markdown |
| `ESTADO_DEL_SISTEMA.md` | Fotografía vigente + archivo histórico del estado | Todos | vigente (sección superior) · histórico (resto) | `docs/handover/*` | Sólo la sección vigente manda; cada cifra lleva su fecha |
| `docs/AI_AGENT_BLOCKERS.md` | Bloqueos, su evidencia y seguimiento humano | Agentes · propietario | vigente, con revalidación del 2026-10-13 | `docs/handover/AUDITORIA_ADVERSARIAL_2026-10-13.md` | Revalidar antes de actuar: contiene historia |
| `MEMORY.md` | Índice de la memoria del proyecto | Agentes | vigente | `.workbuddy-ai/memory/MEMORY.md` | El detalle vive en `temas/`; no duplicar aquí |
| `docs/PROJECT_PHASE_GATES.md` | Criterios de aceptación por fase | Equipo | vigente | `PLAN_CIERRE_100_FUNCIONAL_2026.md` | — |

### 1.2 Operación: arranque, pruebas, base de datos y despliegue

| Ruta | Propósito | Público | Estado | Canónico relacionado | Acción recomendada |
|---|---|---|---|---|---|
| `docs/PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md` | **Único** procedimiento oficial de despliegue | Operación | vigente | — | Es el canónico; las guías auxiliares remiten aquí |
| `LEVANTAR_EN_LOCAL.md` | Arranque local del backend y del frontend | Desarrollo | vigente | `devops/README.md` | — |
| `e2e/README.md` | Cómo se activa y se lee la suite Playwright | Desarrollo · QA | vigente | `docs/PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md` | — |
| `devops/README.md` | Instrumentos de verificación y pipeline de contexto | Desarrollo | vigente | `docs/AI_AGENT_AUTONOMY_AND_ENVIRONMENT_RECOVERY.md` | — |
| `supabase/tests/README.md` | Validación de migraciones con motor real sin Docker | Desarrollo | vigente | `docs/PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md` §8 | — |
| `docs/CONFIGURACION_R2.md` | Bucket, CORS, ciclo de vida y URLs prefirmadas | Operación | vigente | `docs/r2-cors.json`, `docs/r2-lifecycle.json` | Verificar contra el bucket real antes de cambiar CORS |
| `docs/PLAN_MAESTRO_STACK_DEFINITIVO.md` | Stack y decisiones de arquitectura inamovibles | Todos | vigente | Código | Si se contradice con el código, gana el código |

### 1.3 Arquitectura, diseño y contratos

| Ruta | Propósito | Público | Estado | Canónico relacionado | Acción recomendada |
|---|---|---|---|---|---|
| `docs/ARQUITECTURA_AULA_VIRTUAL.md` | Arquitectura del Módulo 6 (Aula Virtual) | Desarrollo | vigente | `backend/openapi.json` | — |
| `docs/INVESTIGACION_AULA_VIRTUAL.md` | Investigación que originó el Módulo 6 | Historia | histórico (insumo) | `docs/ARQUITECTURA_AULA_VIRTUAL.md` | Conservar como origen, no como especificación |
| `docs/CONTRATO_API_MODULO2.md` · `docs/CONTRATO_API_MODULO3.md` | Contratos HTTP de Módulos 2 y 3 | Desarrollo | vigente | `backend/openapi.json` | `openapi.test.ts` los compara con las rutas reales: si el contrato y el test discrepan, manda el test |
| `docs/BRIEFING_BACKEND_MODULO4.md` · `docs/BRIEFING_BACKEND_MODULO5.md` | Instrucciones para implementar fases ya cerradas | Historia | histórico | Contratos de API | No releer como especificación vigente: describen trabajo ya ejecutado |
| `docs/INCES_PREMIUM_PRODUCT_DESIGN_SYSTEM.md` | Sistema de producto y diseño premium | Diseño | vigente | `lib/` | — |
| `docs/REPORTE_INTERFAZ_RENOVADA.md` | Reporte de la interfaz renovada | Historia | histórico | `docs/INCES_PREMIUM_PRODUCT_DESIGN_SYSTEM.md` | — |
| `docs/diseno/planilla/CONTRATO_E2_PLANILLA_OFICIAL.md` · `docs/diseno/planilla/DISENO_E2_PERSISTENCIA.md` · `docs/diseno/planilla/PLANILLA_OFICIAL_RENDERER_DISENO.md` | Planilla oficial de inscripción: contrato, persistencia y renderer | Desarrollo | vigente | `backend/assets/` | — |
| `docs/historial/auditorias/*` (`AUDITORIA_PLANILLA.md`, `AUDITORIA_M4.md`, `AUDITORIA_ESTADO_REAL.md`, `HANDOFF_ARIA_G3_*.md`, `RELEASE_AUDIT_*.md`, `REPORTE_ARIA.md`, etc.) | Auditorías y handoffs de fases anteriores | Historia | histórico | `docs/historial/auditorias/README.md` | No tratar sus cifras como vigentes |
| `docs/DISENO_PERIODOS_DURACION_Y_CADUCIDAD_2026-10-10.md` | Diseño de duración y caducidad de períodos | Producto | vigente como diseño, **no implementado** | — | Requiere migración nueva + autorización + 5 decisiones institucionales |
| `docs/AUDITORIA_RENDIMIENTO_2026-10-08.md` | Auditoría de rendimiento y causa raíz | Equipo | histórico con datos a revalidar | `ESTADO_DEL_SISTEMA.md` | Las mejoras de latency se re-miden antes de citarlas |
| `docs/AUDITORIA_INVITAR_DOCENTE_Y_GESTION_ACADEMICA_2026-10-10.md` | Hallazgos de «Invitar docente» y gestión académica | Equipo · propietario | vigente como hallazgo | `docs/AI_AGENT_BLOCKERS.md` | Falta la verificación funcional en producción con cuenta autorizada |
| `docs/CERTIFICACION_CIERRE_TOTAL.md` | Certificación de gates G1–G10 | Historia | histórico | `docs/PROJECT_PHASE_GATES.md` | — |

### 1.4 Planificación, prompts y contexto para IA

| Ruta | Propósito | Público | Estado | Canónico relacionado | Acción recomendada |
|---|---|---|---|---|---|
| `PLAN_MAESTRO.md` · `ROADMAP.md` · `PLAN_CIERRE_100_FUNCIONAL_2026.md` · `TODO_CIERRE_INTEGRAL_INCES_LMS.md` | Alcance, prioridades y cola operativa | Equipo | vigente | `ESTADO_DEL_SISTEMA.md` | El TODO es la cola; no duplicar estados aquí |
| `docs/contexto-ia/*` (9 archivos) | Paquete de contexto autocontenido para una IA sin acceso al repo | IA externa | vigente, **caduco por diseño** | `ESTADO_DEL_SISTEMA.md` | Cada cifra lleva su fecha (2026-10-12); re-medir antes de decidir con ella |
| `docs/contexto-ia-unificado/CONTEXTO_COMPLETO_INCES_LMS.md` | Los nueve archivos fusionados en uno | IA externa | vigente, **caduco por diseño** | `docs/contexto-ia/` | Ver duplicado D-1 más abajo |
| `docs/historial/prompts/*` (14 mandatos históricos) | Mandatos de sesiones pasadas archivados | Historia | histórico | `docs/historial/prompts/README.md` | **No ejecutar en bloque.** Comprobar que su objetivo sigue vigente antes de usarlo |
| `HANDOVER.md` | Bitácora canónica inmutable entre sesiones | Historia | histórico | `docs/handover/*` | `HANDOVER.md` es inmutable hacia atrás: sólo se añade |

| `RELEASE_AUDIT_20261010_0302.md` | Auditoría de release del 2026-10-10 | Historia | **obsoleto pendiente de revisión** | `docs/PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md` | Afirma `flutter build web --release` PASS; la medición del 2026-10-13 lo contradice (`231`). No usarcomo evidencia de build |
| `docs/handover/CIERRE_AUTONOMO_NOCTURNO_2026-10-13.md` | Cierre nocturno inicial | Historia | histórico | `docs/handover/AUDITORIA_ADVERSARIAL_2026-10-13.md` | La auditoría adversarial corrige sus cifras: mandan las de la auditoría |
| `docs/handover/AUDITORIA_ADVERSARIAL_2026-10-13.md` | Auditoría del árbol con PASS/BLOCKED/NOT RUN | Todos | **vigente** | `ESTADO_DEL_SISTEMA.md` | Es la referencia operativa más reciente |
| `docs/AI_AGENT_OPERATING_PROTOCOL.md` · `docs/AI_AGENT_AUTONOMY_AND_ENVIRONMENT_RECOVERY.md` · `docs/AI_AGENT_TOKEN_EFFICIENT_AUTONOMY.md` | Reglas de trabajo, recuperación de entorno y economía de contexto | Agentes | vigente | `AGENT_START_HERE.md` | — |
| `.workbuddy-ai/memory/**`, `.autoclaw/**`, `.clinerules/**` | Memoria y reglas de agentes | Agentes | contexto auxiliar | — | No es evidencia ejecutable ni prueba de estado remoto |
| `devops/out/contexto_proyecto.md` | Volcado de contexto generado | Agentes | pendiente de verificación | `docs/contexto-ia/` | 1,5 MB generado: regenerar antes de consumirlo |

### 1.5 Duplicados detectados (medidos, no supuestos)

No se elimina nada en la Fase 1. Se listan con su evidencia para una fase posterior.

| Id | Qué | Evidencia | Acción recomendada |
|---|---|---|---|
| **D-1** | `docs/contexto-ia-unificado/CONTEXTO_COMPLETO_INCES_LMS.md` frente a los nueve archivos de `docs/contexto-ia/` | **Medido el 2026-10-13**: no son byte a byte (90.597 B frente a 89.262 B concatenados), pero **1.031 de 1.497 líneas del unificado son idénticas** a líneas del paquete y sólo 86 líneas son propias (cabecera y separadores) | Duplicado sustancial, no exacto. Decidir cuál es el canónico (se propone el paquete de nueve, que permite enlazar por sección) y convertir el otro en un enlace |
| **D-2** | Seis copias de la skill `archify` bajo `.agents/`, `.claude/`, `.codebuddy/`, `.continue/`, `.hermes/` y `.workbuddy-ai/skills/` | SHA-256 idénticos, ya registrados en §2 de este catálogo (11 grupos) | Copias de herramienta, no documentación de producto: no moverlas ni borrarlas como si fueran duplicados de documento |
| **D-3** | Varios `PROMPT_*`/`MEGA_PROMPT_*` de raíz con objetivos solapados (cierre total, reanudación, release) | Convivencia de siete mandatos con alcance similar | Fase posterior: consolidar en un único índice de prompts obsoletos que remita a `AGENT_START_HERE.md` |
| **D-4** | `HANDOVER.md` (2.785 líneas) y `HANDOVER_CHAT_NUEVO.md` (392) | Solapamiento de contenido de continuidad | `HANDOVER.md` es inmutable hacia atrás; el otro es un extracto. Conservar ambos y dejar que el extracto enlace al canónico |

## §2. Inventario automático (anexo reproducible)

Lista generada desde el árbol de trabajo el 2026-10-13. Incluye rutas, primer encabezado detectado, líneas/tamaño y clasificación Git (`git` · `no rastreado` · `ignorado`). Sirve para localizar documentos; su lectura semántica está en §1 y su vigencia se valida allí. Etiquetas reescritas el 2026-10-14 contra `git ls-files`.

**Documentos listados:** 217 (el propio catálogo se excluye para evitar autorreferencia). **Total Markdown actual, incluido este catálogo:** 218. **HEAD:** ad5ce67.

**Clasificación real de los 218, medida el 2026-10-14** (cada ruta en una sola categoría, con git como autoridad):

| Categoría | Cuántos | Cómo se mide |
|---|---|---|
| Rastreados por Git | **72** | `git ls-files '*.md'` |
| No rastreados y no ignorados | **16** | `git ls-files --others --exclude-standard '*.md'` |
| Ignorados por `.gitignore` | **130** | `git ls-files --others --ignored --exclude-standard '*.md'` (129) más 1 en una ruta demasiado larga para que git la recorra, confirmado ignorado con `git check-ignore` |
| **Total** | **218** | Recorrido del sistema de archivos excluyendo `.git`, `node_modules`, `.dart_tool`, `build`, `.wrangler`, `venv`, `__pycache__` y `deploy-ad5ce67` |

Las etiquetas del anexo usan por eso tres valores: `git`, `no rastreado` e `ignorado`.
**Corrección del 2026-10-14:** la versión anterior de esta cabecera decía «rastreados 72 ·
no rastreados 145». Eso mezclaba dos categorías: de esos 145, sólo **16** carecen de
seguimiento; los otros **129** están cubiertos por reglas de ignorado (`.agents/`,
`.claude/skills/`, `.workbuddy-ai/`, `No subir esta carpeta…`). Re-etiquetado entrada por
entrada: 72 `git`, 15 `no rastreado` y 130 `ignorado` (el anexo excluye al propio catálogo).

**Refresco del 2026-10-14:** las cifras de líneas y tamaño se regeneraron para los 10
documentos que la Fase 1 modificó, que habían quedado desfasadas respecto al disco. Las 207
restantes se comprobaron contra el sistema de archivos y ya coincidían. Verificación: 217
fichas revisadas, **0 desfasadas**.

**No confundir** estos 16 Markdown sin seguimiento con los **80 archivos sin seguimiento de
cualquier extensión** que devuelve `git ls-files --others --exclude-standard`: los 80
incluyen código, workflows, imágenes y especificaciones, y sólo 16 de ellos son `.md`.

## Documentación de raíz/plataformas

- **AGENT_START_HERE.md** — AGENT START HERE — INCES LMS · 95 líneas · 10,1 KB · git
- **AUDITORIA_ESTADO_REAL.md** — AUDITORÍA DE ESTADO REAL — INCES-LMS-PROJECT · 269 líneas · 22,3 KB · git
- **AUDITORIA_M4.md** — AUDITORÍA DE INVENTARIO — Módulo 4 y Planilla Dinámica · 224 líneas · 12,4 KB · git
- **AUDITORIA_PLANILLA.md** — Auditoría — Planilla Oficial de Inscripción INCES · 566 líneas · 30,5 KB · git
- **AUTONOMOUS_AGENT_MASTER_PROMPT.md** — PROMPT MAESTRO v2 — AGENTE AI AUTÓNOMO DE CIERRE TOTAL — INCES LMS · 998 líneas · 20,2 KB · git
- **AUTOPROMPT_PLANILLA.md** — Auto-prompt — Ciclo de vida de la Planilla de Inscripción INCES · 221 líneas · 9,4 KB · git
- **CONTRATO_E2_PLANILLA_OFICIAL.md** — CONTRATO E-2 DEFINITIVO — Planilla Oficial INCES · 325 líneas · 16,2 KB · git
- **DISENO_E2_PERSISTENCIA.md** — Diseño técnico de persistencia — E-2 Planilla Oficial · 326 líneas · 13,4 KB · git
- **ESTADO_DEL_SISTEMA.md** — ESTADO DEL SISTEMA — INCES LMS · 3353 líneas · 279,7 KB · git
- **ESTADO_REAL_MEGA_PROMPT_V2.md** — ESTADO REAL DE INCES-LMS-PROJECT — MEGA PROMPT v2 · 241 líneas · 12 KB · git
- **HANDOFF_ARIA_G3_2026-10-10.md** — Handoff para ARIA — cierre G3 y rendimiento (2026-10-10) · 102 líneas · 10,7 KB · git
- **HANDOVER.md** — HANDOVER — INCES LMS · 2785 líneas · 157,6 KB · git
- **HANDOVER_CHAT_NUEVO.md** — HANDOVER — Contexto completo para un chat nuevo con acceso al filesystem · 392 líneas · 17,6 KB · git
- **INSTRUCCION_ANTIGRAVITY_CONTINUAR_MEGA_PROMPT_MAIN.md** — INSTRUCCIÓN DE CONTINUIDAD PARA ANTIGRAVITY — MAIN DE GITHUB Y RUTA CANÓNICA · 104 líneas · 6,9 KB · git
- **ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md** — Launch Screen Assets · 5 líneas · 0,3 KB · git
- **LEVANTAR_EN_LOCAL.md** — Levantar el proyecto en local · 300 líneas · 9,8 KB · git
- **MEGA_PROMPT_CLINE_CFS.md** — MEGA PROMPT ULTRA DETALLADO — CLINE · 950 líneas · 21,1 KB · git
- **MEMORY.md** — MEMORY.md — INCES LMS · 157 líneas · 7,8 KB · git
- **overview.md** — Sprint 2 — Módulo 6 «Aula Virtual»: cierre · 135 líneas · 5,5 KB · git
- **PLAN_CIERRE_100_FUNCIONAL_2026.md** — PLAN DE CIERRE 100% FUNCIONAL — INCES LMS · 1150 líneas · 46,4 KB · git
- **PLAN_MAESTRO.md** — Plan Maestro — LMS INCES La Isabelica · 498 líneas · 26,3 KB · git
- **PLANILLA_OFICIAL_RENDERER_DISENO.md** — Diseño del renderer de la Planilla Oficial INCES · 699 líneas · 28,3 KB · git
- **PROMPT_ANTIGRAVITY_AUTONOMOUS_CLOSURE.md** — PROMPT MAESTRO — ANTIGRAVITY / GEMINI · 743 líneas · 17 KB · git
- **PROMPT_ANTIGRAVITY_RELEASE_PRODUCCION_HOY.md** — MEGA PROMPT PARA ANTIGRAVITY — CIERRE, VALIDACIÓN Y DESPLIEGUE REAL A PRODUCCIÓN HOY · 225 líneas · 20,6 KB · git
- **PROMPT_ARIA_CONTINUACION_G3_2026-10-10.md** — Prompt de continuación para ARIA — INCES-LMS / G3 · 26 líneas · 3,8 KB · git
- **PROMPT_CIERRE_TOTAL_PRODUCTO.md** — MANDATO DE CIERRE TOTAL — INCES-LMS · 500 líneas · 11,3 KB · git
- **PROMPT_LANZADOR_AGENTE.md** — LANZADOR — AGENTE AUTÓNOMO INCES-LMS · 117 líneas · 4,2 KB · git
- **PROMPT_MAESTRO_CICLO_VIDA_COMPLETO_AGENTE_IA.md** — PROMPT MAESTRO UNIVERSAL — CIERRE INTEGRAL DEL CICLO DE VIDA INCES-LMS · 332 líneas · 21,2 KB · git
- **PROMPT_MAESTRO_CONTINUACION_CIERRE_INTEGRAL_2026-10-09.md** — MEGAPROMPT OPERATIVO — CONTINUACIÓN AUTÓNOMA Y CIERRE INTEGRAL INCES-LMS · 188 líneas · 19,7 KB · git
- **PROMPT_REANUDACION_AUTONOMA_UNIVERSAL.md** — PROMPT MAESTRO — REANUDACIÓN Y EJECUCIÓN AUTÓNOMA DEL PROYECTO INCES-LMS · 803 líneas · 18,3 KB · git
- **README.md** — INCES LMS — CFS Nacional de Soldadura "Rafael Urdaneta" · 219 líneas · 11 KB · git
- **RELEASE_AUDIT_20261010_0302.md** — AUDITORÍA DE RELEASE Y EVALUACIÓN DE DESPLIEGUE A PRODUCCIÓN — INCES LMS · 52 líneas · 4,9 KB · git
- **REPORTE_ARIA.md** — REPORTE_ARIA — Contradicciones entre el documento y el código base · 1182 líneas · 60,1 KB · git
- **ROADMAP.md** — ROADMAP — INCES LMS PROJECT · 254 líneas · 14,7 KB · git
- **TODO_CIERRE_INTEGRAL_INCES_LMS.md** — TODO — Auditoría de cierre funcional y UX/UI de INCES-LMS · 1163 líneas · 67,9 KB · git
- **ULTRA_MEGA_PROMPT_RETOMAR_ANTIGRAVITY_INCES_LMS_2026-10-10.md** — ULTRA-MEGA PROMPT PARA RETOMAR INCES-LMS EN ANTIGRAVITY · 550 líneas · 39,1 KB · git

## Documentación técnica de producto

- **docs/AI_AGENT_AUTONOMY_AND_ENVIRONMENT_RECOVERY.md** — CONTRATO DE AUTONOMÍA TOTAL Y RECUPERACIÓN DE ENTORNO — INCES LMS · 496 líneas · 12,9 KB · git
- **docs/AI_AGENT_BLOCKERS.md** — AI Agent Blockers / Human Follow-up · 156 líneas · 17,1 KB · git
- **docs/AI_AGENT_OPERATING_PROTOCOL.md** — PROTOCOLO DE OPERACIÓN AUTÓNOMA PARA AGENTES AI — INCES LMS · 462 líneas · 15,6 KB · git
- **docs/AI_AGENT_TOKEN_EFFICIENT_AUTONOMY.md** — AUTONOMÍA EFICIENTE EN TOKENS — INCES LMS · 66 líneas · 2,2 KB · git
- **docs/ARQUITECTURA_AULA_VIRTUAL.md** — Arquitectura del Aula Virtual (Módulo 6) · 451 líneas · 24,3 KB · git
- **docs/AUDITORIA_INVITAR_DOCENTE_Y_GESTION_ACADEMICA_2026-10-10.md** — Auditoría — «Invitar docente», Usuarios/Roles y gestión académica · 227 líneas · 10,2 KB · git
- **docs/AUDITORIA_RENDIMIENTO_2026-10-08.md** — Auditoría de rendimiento — INCES LMS · 502 líneas · 27,6 KB · git
- **docs/BRIEFING_BACKEND_MODULO4.md** — Briefing para el agente que implementa la Fase 2 del Módulo 4 · 641 líneas · 28,2 KB · git
- **docs/BRIEFING_BACKEND_MODULO5.md** — Briefing para el agente que implementa la Capa 4 del Módulo 5 (rutas HTTP de archivos) · 541 líneas · 25,3 KB · git
- **docs/CERTIFICACION_CIERRE_TOTAL.md** — CERTIFICACIÓN DE CIERRE TOTAL DEL PRODUCTO (G1-G10) · 71 líneas · 4,6 KB · git
- **docs/CLINE_AUDITORIA_FASE_0.md** — AUDITORÍA FASE 0 — Portal CFS + Inscripción + Roles · 273 líneas · 11,1 KB · git
- **docs/CLINE_BLOQUE_E_ERROR_HANDLER.md** — BLOQUE E — Auditoría del error handler · 248 líneas · 10,3 KB · git
- **docs/CLINE_FASE_0_5_BLOQUEADORES.md** — FASE 0.5 — Cierre de bloqueadores arquitectónicos · 336 líneas · 16,2 KB · git
- **docs/CONFIGURACION_R2.md** — Configuración de Cloudflare R2 · 595 líneas · 27,7 KB · git
- **docs/CONTRATO_API_MODULO2.md** — Contrato de API — Módulo 2 (Currículo y Pensum) · 478 líneas · 19,5 KB · git
- **docs/CONTRATO_API_MODULO3.md** — Contrato de API — Módulo 3 (Cuadrante, Horarios, Aulas y Guardias Docentes) · 684 líneas · 30,8 KB · git
- **docs/DISENO_PERIODOS_DURACION_Y_CADUCIDAD_2026-10-10.md** — Diseño — Duración configurable, caducidad e historial de períodos académicos · 244 líneas · 11,6 KB · git
- **docs/ESTRUCTURA_DOCUMENTAL.md** — Estructura documental y reglas de mantenimiento · 94 líneas · 9 KB · no rastreado
- **docs/INCES_PREMIUM_PRODUCT_DESIGN_SYSTEM.md** — Sistema de producto y diseño premium — INCES LMS · 123 líneas · 10,1 KB · git
- **docs/INVESTIGACION_AULA_VIRTUAL.md** — Investigación — El núcleo de Google Classroom (insumo del Módulo 6) · 351 líneas · 30,7 KB · git
- **docs/PLAN_MAESTRO_STACK_DEFINITIVO.md** — PLAN MAESTRO — Stack Definitivo e Inamovible · 227 líneas · 11,2 KB · git
- **docs/PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md** — Procedimiento oficial de despliegue a producción — INCES LMS · 351 líneas · 21,4 KB · git
- **docs/PROJECT_PHASE_GATES.md** — GATES DE FASE — INCES LMS · 45 líneas · 1,9 KB · git
- **docs/README.md** — Índice documental canónico — INCES LMS · 147 líneas · 12 KB · no rastreado
- **docs/REPORTE_INTERFAZ_RENOVADA.md** — Reporte de la Interfaz Renovada · 258 líneas · 12,3 KB · git

## Handover y evidencia fechada

- **docs/handover/AUDITORIA_ADVERSARIAL_2026-10-13.md** — Auditoría adversarial de los cambios nocturnos — 2026-10-13 (segunda fase) · 181 líneas · 10,1 KB · no rastreado
- **docs/handover/CIERRE_AUTONOMO_NOCTURNO_2026-10-13.md** — Cierre autónomo nocturno — 2026-10-13 · 279 líneas · 13,2 KB · no rastreado
- **docs/handover/FASE1_CONSOLIDACION_DOCUMENTAL_2026-10-13.md** — Fase 1 — Consolidación documental (2026-10-13, 23:28 -04:00) · 211 líneas · 15,4 KB · no rastreado

## Material académico separado

- **No subir esta carpeta Github - Contexto - Archivos/Docx SCE + Contexto para reanudar el desarrollo del Documento de Servicio Comunitario/_ARIA_2026-09-17/_obsoleto/03_PLAN_DE_ACCION_AJUSTADO.md** — Plan de Acción ajustado — 120 h por estudiante · 96 líneas · 8,5 KB · ignorado
- **No subir esta carpeta Github - Contexto - Archivos/Docx SCE + Contexto para reanudar el desarrollo del Documento de Servicio Comunitario/_ARIA_2026-09-17/01_DIAGNOSTICO_Y_PLAN_SCE.md** — Diagnóstico y Plan — Informe de Servicio Comunitario Estudiantil (S.C.E.) · 343 líneas · 25,9 KB · ignorado
- **No subir esta carpeta Github - Contexto - Archivos/Docx SCE + Contexto para reanudar el desarrollo del Documento de Servicio Comunitario/_ARIA_2026-09-17/02_CALENDARIOS.md** — Calendarios de los 4 Diarios de Campo · 208 líneas · 12,7 KB · ignorado
- **No subir esta carpeta Github - Contexto - Archivos/Docx SCE + Contexto para reanudar el desarrollo del Documento de Servicio Comunitario/_ARIA_2026-09-17/03_PLAN_DE_ACCION_CRONOGRAMA.md** — Plan de Acción — Cronograma de Actividades (ítem 9) · 71 líneas · 9,6 KB · ignorado
- **No subir esta carpeta Github - Contexto - Archivos/Docx SCE + Contexto para reanudar el desarrollo del Documento de Servicio Comunitario/_ARIA_2026-09-17/05_VERIFICACION_Y_CORRECCIONES.md** — Verificación y correcciones — 21/09/2026 · 447 líneas · 27,2 KB · ignorado
- **No subir esta carpeta Github - Contexto - Archivos/Docx SCE + Contexto para reanudar el desarrollo del Documento de Servicio Comunitario/_Respaldo 2026-09-17/_crono_antes_2026-09-21/03_PLAN_DE_ACCION_CRONOGRAMA.md** — Plan de Acción — Cronograma de Actividades (ítem 9) · 63 líneas · 8,6 KB · ignorado

## Memorias y reglas de herramientas

- **.autoclaw/AGENT-ORIENTATION.md** — Working in an AutoClaw project — INCES-LMS-PROJECT · 58 líneas · 6,1 KB · ignorado
- **.autoclaw/agent-style.md** — Agent Style Guide · 18 líneas · 0,7 KB · ignorado
- **.autoclaw/kdream/memory/MEMORY.md** — 2026-09-09T16:26:54.718Z — /learn · 10 líneas · 0,5 KB · ignorado
- **.autoclaw/kg/README.md** — `.autoclaw/kg/kg.db` — Knowledge Graph · 11 líneas · 0,5 KB · ignorado
- **.autoclaw/learnings/insight-2026-09-09T16-26-54-718Z.md** — Insight — 2026-09-09T16:26:54.718Z · 24 líneas · 1,2 KB · ignorado
- **.autoclaw/orchestrator/board.md** — AutoClaw Agendaboard · 23 líneas · 0,4 KB · ignorado
- **.autoclaw/README.md** — `.autoclaw/` — AutoClaw coordination, memory & learning · 17 líneas · 0,8 KB · ignorado
- **.autoclaw/vector/README.md** — `.autoclaw/vector/db.sqlite` — Vector store · 11 líneas · 0,4 KB · ignorado
- **.clinerules/autobuild.md** — AutoBuild — Autonomous Workflow Engine · 218 líneas · 9,5 KB · git
- **.clinerules/cross-agent.md** — Cross-Agent Coordination Protocol · 79 líneas · 3 KB · git
- **.clinerules/cross-agent-protocol.md** — Cross-Agent Coordination Protocol — Kilo Code · 67 líneas · 4,2 KB · git
- **.clinerules/doc-writer.md** — Doc-Writer — Specialized Persona · 60 líneas · 3,1 KB · git
- **.clinerules/intelligence.md** — AutoClaw Intelligence — Learning & Retrieval Layer · 107 líneas · 6,9 KB · git
- **.clinerules/kdream.md** — KDream — Persistent Background Agent · 195 líneas · 8,6 KB · git
- **.clinerules/mateam.md** — MAteam — Multi-Agent Coordinator · 124 líneas · 6,2 KB · git
- **.clinerules/orchestrate.md** — Orchestrate — Multi-Agent Parallel Development · 329 líneas · 15,6 KB · git
- **.clinerules/security-auditor.md** — Security-Auditor — Specialized Persona · 69 líneas · 3,9 KB · git
- **.workbuddy-ai/artifacts/barrido-disparador-ruta-admin.md** — El barrido de M5 ya tiene disparador — punto 3 del roadmap · 135 líneas · 7,1 KB · ignorado
- **.workbuddy-ai/artifacts/capa7-ui-modulo5.md** — Capa 7 — Gestor Documental (UI del Módulo 5) · 166 líneas · 7,2 KB · ignorado
- **.workbuddy-ai/artifacts/cierre-puntos-1-4.md** — Cierre de los puntos 1–4 — Módulo 5 · 174 líneas · 7 KB · ignorado
- **.workbuddy-ai/artifacts/m5-encendido-y-guardia.md** — M5 — Encendido del módulo y guardia `exigirModulo()` · 128 líneas · 6,5 KB · ignorado
- **.workbuddy-ai/artifacts/research-aula-virtual-google-classroom.md** — Investigación — El núcleo de Google Classroom como referencia para el Módulo 6 (Aula Virtual INCES) · 351 líneas · 30,7 KB · ignorado
- **.workbuddy-ai/memory/2026-09-11.md** — 2026-09-11 — Sesión de arquitectura y DevOps · 49 líneas · 2,8 KB · ignorado
- **.workbuddy-ai/memory/2026-09-12.md** — 2026-09-12 · 326 líneas · 17,3 KB · ignorado
- **.workbuddy-ai/memory/2026-09-13.md** — 2026-09-13 · 252 líneas · 14,1 KB · ignorado
- **.workbuddy-ai/memory/2026-09-14.md** — 2026-09-14 · 371 líneas · 19,4 KB · ignorado
- **.workbuddy-ai/memory/2026-09-15.md** — 2026-09-15 — Módulo 3: despliegue, el fallo `42501` y el contrato de API · 371 líneas · 19 KB · ignorado
- **.workbuddy-ai/memory/2026-09-17.md** — 2026-09-17 — Despliegue de M3 a la nube y planificación de M4 · 337 líneas · 16,7 KB · ignorado
- **.workbuddy-ai/memory/2026-09-18.md** — 2026-09-18 — M4 Fase 1 (esquema) implementada, desplegada y verificada en producción · 850 líneas · 43,3 KB · ignorado
- **.workbuddy-ai/memory/2026-09-19.md** — 2026-09-19 — Cierre de los puntos 1-4 de la revisión de la madrugada · 411 líneas · 21,6 KB · ignorado
- **.workbuddy-ai/memory/2026-09-22.md** — 2026-09-22 — Sprint autónomo: Módulo 6 (Aula Virtual) · 666 líneas · 34,2 KB · ignorado
- **.workbuddy-ai/memory/2026-09-23.md** — 2026-09-23 · 202 líneas · 9,8 KB · ignorado
- **.workbuddy-ai/memory/2026-09-24.md** — 2026-09-24 · 498 líneas · 27,7 KB · ignorado
- **.workbuddy-ai/memory/2026-09-25.md** — 2026-09-25 · 1236 líneas · 78,2 KB · ignorado
- **.workbuddy-ai/memory/2026-09-26.md** — 2026-09-26 · 200 líneas · 24,7 KB · ignorado
- **.workbuddy-ai/memory/2026-09-27.md** — 2026-09-27 · 703 líneas · 49,5 KB · ignorado
- **.workbuddy-ai/memory/2026-09-28.md** — 2026-09-28 — M7 no funcionaba; D21 cerrada por la vía manual · 260 líneas · 14 KB · ignorado
- **.workbuddy-ai/memory/2026-09-29.md** — 2026-09-29 — D21 segunda mitad: el escáner QR (auditoría + capa nativa) · 983 líneas · 59 KB · ignorado
- **.workbuddy-ai/memory/2026-09-30.md** — 2026-09-30 · 751 líneas · 41,8 KB · ignorado
- **.workbuddy-ai/memory/2026-10-01.md** — 2026-10-01 — Arnes local de Playwright, credenciales deterministas, M6 y D17 · 131 líneas · 10,3 KB · ignorado
- **.workbuddy-ai/memory/2026-10-02.md** — 2026-10-02 — Gesto de pestana, modales del docente, E2E del aula · 143 líneas · 11,6 KB · ignorado
- **.workbuddy-ai/memory/2026-10-03.md** — 2026-10-03 — Dos problemas separados, y metricas que no hay que mezclar · 32 líneas · 2,3 KB · ignorado
- **.workbuddy-ai/memory/2026-10-09.md** — 2026-10-09 — CAUSA RAÍZ del bloqueo E2E: el bundle local tiene config de PLANTILLA · 336 líneas · 20,8 KB · ignorado
- **.workbuddy-ai/memory/2026-10-10.md** — 2026-10-10 — Diagnóstico «Invitar docente» + gestión académica · 77 líneas · 5,1 KB · ignorado
- **.workbuddy-ai/memory/2026-10-12.md** — 2026-10-12 — Paquete de contexto para otra IA (`docs/contexto-ia/`) · 54 líneas · 2,9 KB · ignorado
- **.workbuddy-ai/memory/2026-10-13.md** — 2026-10-13 — Cierre autónomo nocturno (mega-prompt) · 218 líneas · 12,7 KB · ignorado
- **.workbuddy-ai/memory/MEMORY.md** — MEMORY — INCES LMS · 88 líneas · 6,7 KB · ignorado
- **.workbuddy-ai/memory/temas/api-backend.md** — Tema: API del backend y listado de usuarios · 68 líneas · 3,8 KB · ignorado
- **.workbuddy-ai/memory/temas/cerradas.md** — Cerradas — no reabrir sin medir · 55 líneas · 4,6 KB · ignorado
- **.workbuddy-ai/memory/temas/convenciones.md** — Tema: Convenciones de código y flujo de trabajo · 112 líneas · 7,5 KB · ignorado
- **.workbuddy-ai/memory/temas/e2e.md** — E2E — la descarga del CSV hacia HACER, en un navegador de verdad · 282 líneas · 18,8 KB · ignorado
- **.workbuddy-ai/memory/temas/infraestructura.md** — Tema: Infraestructura y despliegue · 369 líneas · 26,4 KB · ignorado
- **.workbuddy-ai/memory/temas/interfaz.md** — Tema: Interfaz y sistema de diseño · 229 líneas · 14,4 KB · ignorado
- **.workbuddy-ai/memory/temas/lecciones.md** — Lecciones transversales — INCES LMS · 231 líneas · 121,9 KB · ignorado
- **.workbuddy-ai/memory/temas/modulo2.md** — Tema: Módulo 2 — Oferta académica / currículo · 28 líneas · 1,9 KB · ignorado
- **.workbuddy-ai/memory/temas/modulo3.md** — Tema: Módulo 3 — Cuadrante, Aulas, Guardias · 89 líneas · 5,6 KB · ignorado
- **.workbuddy-ai/memory/temas/modulo4.md** — Tema: Módulo 4 — Inscripciones y Cupos · 696 líneas · 41,3 KB · ignorado
- **.workbuddy-ai/memory/temas/modulo5.md** — Tema: Módulo 5 — Archivos (Cloudflare R2) · 229 líneas · 13,4 KB · ignorado
- **.workbuddy-ai/memory/temas/modulo6.md** — Módulo 6 — Aula Virtual INCES · 89 líneas · 10,8 KB · ignorado
- **.workbuddy-ai/memory/temas/modulo7.md** — Módulo 7 — Asistencia QR en vivo · 311 líneas · 20,6 KB · ignorado

## Operación, tests y runbooks

- **devops/out/contexto_proyecto.md** — Contexto del Proyecto - INCES LMS · 33042 líneas · 1549,3 KB · ignorado
- **devops/README.md** — DevOps - Pipeline de Contexto Continuo (INCES LMS) · 326 líneas · 12,7 KB · git
- **e2e/README.md** — Suite E2E · 381 líneas · 20,5 KB · git
- **supabase/tests/README.md** — Validación de migraciones · 89 líneas · 5,3 KB · git

## Paquetes de contexto para IA

- **docs/contexto-ia/00_INDICE.md** — Contexto para otra IA — INCES LMS · 84 líneas · 4,6 KB · no rastreado
- **docs/contexto-ia/01_PROYECTO_Y_PRODUCTO.md** — 01 — El proyecto y el producto · 136 líneas · 7,5 KB · no rastreado
- **docs/contexto-ia/02_ESTADO_ACTUAL.md** — 02 — Estado actual del sistema · 152 líneas · 10,7 KB · no rastreado
- **docs/contexto-ia/03_STACK_TECNOLOGICO.md** — 03 — Stack tecnológico · 223 líneas · 12,7 KB · no rastreado
- **docs/contexto-ia/04_ARQUITECTURA.md** — 04 — Arquitectura · 227 líneas · 14,9 KB · no rastreado
- **docs/contexto-ia/05_CICLO_DE_VIDA.md** — 05 — Ciclo de vida: cómo nace, se verifica y se despliega un cambio · 168 líneas · 9,3 KB · no rastreado
- **docs/contexto-ia/06_REGLAS_Y_LECCIONES.md** — 06 — Reglas y lecciones (léelo antes de tocar nada) · 210 líneas · 12,5 KB · no rastreado
- **docs/contexto-ia/07_MAPA_Y_COMANDOS.md** — 07 — Mapa del repositorio y comandos · 149 líneas · 8,1 KB · no rastreado
- **docs/contexto-ia/08_GLOSARIO.md** — 08 — Glosario · 108 líneas · 9,1 KB · no rastreado
- **docs/contexto-ia-unificado/CONTEXTO_COMPLETO_INCES_LMS.md** — Contexto completo — INCES LMS (documento único) · 1496 líneas · 90,7 KB · no rastreado

## Skills/configuración de agentes

- **.agents/skills/archify/brand-marks/README.md** — Built-in brand marks · 31 líneas · 1,4 KB · ignorado
- **.agents/skills/archify/references/authoring-contract.md** — Authoring contract · 247 líneas · 13,9 KB · ignorado
- **.agents/skills/archify/references/brand-marks.md** — Brand marks · 65 líneas · 2,1 KB · ignorado
- **.agents/skills/archify/references/delivery-contract.md** — Delivery contract · 138 líneas · 9,4 KB · ignorado
- **.agents/skills/archify/references/viewer-runtime.md** — Viewer Runtime reference · 45 líneas · 4,1 KB · ignorado
- **.agents/skills/archify/renderers/dataflow/README.md** — Data Flow Renderer · 104 líneas · 4,1 KB · ignorado
- **.agents/skills/archify/renderers/lifecycle/README.md** — Lifecycle Renderer · 115 líneas · 5,1 KB · ignorado
- **.agents/skills/archify/renderers/sequence/README.md** — Sequence Renderer · 114 líneas · 4,7 KB · ignorado
- **.agents/skills/archify/renderers/workflow/README.md** — Workflow Renderer · 223 líneas · 10,1 KB · ignorado
- **.agents/skills/archify/schemas/README.md** — Archify JSON IR Schemas · 211 líneas · 11,2 KB · ignorado
- **.agents/skills/archify/SKILL.md** — Archify · 137 líneas · 16 KB · ignorado
- **.agents/skills/archify/THIRD_PARTY_NOTICES.md** — Third-party notices · 69 líneas · 5,1 KB · ignorado
- **.claude/skills/archify/brand-marks/README.md** — Built-in brand marks · 31 líneas · 1,4 KB · ignorado
- **.claude/skills/archify/references/authoring-contract.md** — Authoring contract · 247 líneas · 13,9 KB · ignorado
- **.claude/skills/archify/references/brand-marks.md** — Brand marks · 65 líneas · 2,1 KB · ignorado
- **.claude/skills/archify/references/delivery-contract.md** — Delivery contract · 138 líneas · 9,4 KB · ignorado
- **.claude/skills/archify/references/viewer-runtime.md** — Viewer Runtime reference · 45 líneas · 4,1 KB · ignorado
- **.claude/skills/archify/renderers/dataflow/README.md** — Data Flow Renderer · 104 líneas · 4,1 KB · ignorado
- **.claude/skills/archify/renderers/lifecycle/README.md** — Lifecycle Renderer · 115 líneas · 5,1 KB · ignorado
- **.claude/skills/archify/renderers/sequence/README.md** — Sequence Renderer · 114 líneas · 4,7 KB · ignorado
- **.claude/skills/archify/renderers/workflow/README.md** — Workflow Renderer · 223 líneas · 10,1 KB · ignorado
- **.claude/skills/archify/schemas/README.md** — Archify JSON IR Schemas · 211 líneas · 11,2 KB · ignorado
- **.claude/skills/archify/SKILL.md** — Archify · 137 líneas · 16 KB · ignorado
- **.claude/skills/archify/THIRD_PARTY_NOTICES.md** — Third-party notices · 69 líneas · 5,1 KB · ignorado
- **.codebuddy/skills/archify/brand-marks/README.md** — Built-in brand marks · 31 líneas · 1,4 KB · ignorado
- **.codebuddy/skills/archify/references/authoring-contract.md** — Authoring contract · 247 líneas · 13,9 KB · ignorado
- **.codebuddy/skills/archify/references/brand-marks.md** — Brand marks · 65 líneas · 2,1 KB · ignorado
- **.codebuddy/skills/archify/references/delivery-contract.md** — Delivery contract · 138 líneas · 9,4 KB · ignorado
- **.codebuddy/skills/archify/references/viewer-runtime.md** — Viewer Runtime reference · 45 líneas · 4,1 KB · ignorado
- **.codebuddy/skills/archify/renderers/dataflow/README.md** — Data Flow Renderer · 104 líneas · 4,1 KB · ignorado
- **.codebuddy/skills/archify/renderers/lifecycle/README.md** — Lifecycle Renderer · 115 líneas · 5,1 KB · ignorado
- **.codebuddy/skills/archify/renderers/sequence/README.md** — Sequence Renderer · 114 líneas · 4,7 KB · ignorado
- **.codebuddy/skills/archify/renderers/workflow/README.md** — Workflow Renderer · 223 líneas · 10,1 KB · ignorado
- **.codebuddy/skills/archify/schemas/README.md** — Archify JSON IR Schemas · 211 líneas · 11,2 KB · ignorado
- **.codebuddy/skills/archify/SKILL.md** — Archify · 137 líneas · 16 KB · ignorado
- **.codebuddy/skills/archify/THIRD_PARTY_NOTICES.md** — Third-party notices · 69 líneas · 5,1 KB · ignorado
- **.continue/prompts/cross-agent-protocol.md** — Cross-Agent Coordination Protocol — Continue · 67 líneas · 4,2 KB · git
- **.continue/skills/archify/brand-marks/README.md** — Built-in brand marks · 31 líneas · 1,4 KB · ignorado
- **.continue/skills/archify/references/authoring-contract.md** — Authoring contract · 247 líneas · 13,9 KB · ignorado
- **.continue/skills/archify/references/brand-marks.md** — Brand marks · 65 líneas · 2,1 KB · ignorado
- **.continue/skills/archify/references/delivery-contract.md** — Delivery contract · 138 líneas · 9,4 KB · ignorado
- **.continue/skills/archify/references/viewer-runtime.md** — Viewer Runtime reference · 45 líneas · 4,1 KB · ignorado
- **.continue/skills/archify/renderers/dataflow/README.md** — Data Flow Renderer · 104 líneas · 4,1 KB · ignorado
- **.continue/skills/archify/renderers/lifecycle/README.md** — Lifecycle Renderer · 115 líneas · 5,1 KB · ignorado
- **.continue/skills/archify/renderers/sequence/README.md** — Sequence Renderer · 114 líneas · 4,7 KB · ignorado
- **.continue/skills/archify/renderers/workflow/README.md** — Workflow Renderer · 223 líneas · 10,1 KB · ignorado
- **.continue/skills/archify/schemas/README.md** — Archify JSON IR Schemas · 211 líneas · 11,2 KB · ignorado
- **.continue/skills/archify/SKILL.md** — Archify · 137 líneas · 16 KB · ignorado
- **.continue/skills/archify/THIRD_PARTY_NOTICES.md** — Third-party notices · 69 líneas · 5,1 KB · ignorado
- **.hermes/skills/archify/brand-marks/README.md** — Built-in brand marks · 31 líneas · 1,4 KB · ignorado
- **.hermes/skills/archify/references/authoring-contract.md** — Authoring contract · 247 líneas · 13,9 KB · ignorado
- **.hermes/skills/archify/references/brand-marks.md** — Brand marks · 65 líneas · 2,1 KB · ignorado
- **.hermes/skills/archify/references/delivery-contract.md** — Delivery contract · 138 líneas · 9,4 KB · ignorado
- **.hermes/skills/archify/references/viewer-runtime.md** — Viewer Runtime reference · 45 líneas · 4,1 KB · ignorado
- **.hermes/skills/archify/renderers/dataflow/README.md** — Data Flow Renderer · 104 líneas · 4,1 KB · ignorado
- **.hermes/skills/archify/renderers/lifecycle/README.md** — Lifecycle Renderer · 115 líneas · 5,1 KB · ignorado
- **.hermes/skills/archify/renderers/sequence/README.md** — Sequence Renderer · 114 líneas · 4,7 KB · ignorado
- **.hermes/skills/archify/renderers/workflow/README.md** — Workflow Renderer · 223 líneas · 10,1 KB · ignorado
- **.hermes/skills/archify/schemas/README.md** — Archify JSON IR Schemas · 211 líneas · 11,2 KB · ignorado
- **.hermes/skills/archify/SKILL.md** — Archify · 137 líneas · 16 KB · ignorado
- **.hermes/skills/archify/THIRD_PARTY_NOTICES.md** — Third-party notices · 69 líneas · 5,1 KB · ignorado
- **.workbuddy-ai/skills/archify/brand-marks/README.md** — Built-in brand marks · 31 líneas · 1,4 KB · ignorado
- **.workbuddy-ai/skills/archify/references/authoring-contract.md** — Authoring contract · 247 líneas · 13,9 KB · ignorado
- **.workbuddy-ai/skills/archify/references/brand-marks.md** — Brand marks · 65 líneas · 2,1 KB · ignorado
- **.workbuddy-ai/skills/archify/references/delivery-contract.md** — Delivery contract · 138 líneas · 9,4 KB · ignorado
- **.workbuddy-ai/skills/archify/references/viewer-runtime.md** — Viewer Runtime reference · 45 líneas · 4,1 KB · ignorado
- **.workbuddy-ai/skills/archify/renderers/dataflow/README.md** — Data Flow Renderer · 104 líneas · 4,1 KB · ignorado
- **.workbuddy-ai/skills/archify/renderers/lifecycle/README.md** — Lifecycle Renderer · 115 líneas · 5,1 KB · ignorado
- **.workbuddy-ai/skills/archify/renderers/sequence/README.md** — Sequence Renderer · 114 líneas · 4,7 KB · ignorado
- **.workbuddy-ai/skills/archify/renderers/workflow/README.md** — Workflow Renderer · 223 líneas · 10,1 KB · ignorado
- **.workbuddy-ai/skills/archify/schemas/README.md** — Archify JSON IR Schemas · 211 líneas · 11,2 KB · ignorado
- **.workbuddy-ai/skills/archify/SKILL.md** — Archify · 137 líneas · 16 KB · ignorado
- **.workbuddy-ai/skills/archify/THIRD_PARTY_NOTICES.md** — Third-party notices · 69 líneas · 5,1 KB · ignorado

## Copias exactas (SHA-256)

- 8B771A16322C: .agents/skills/archify/brand-marks/README.md; .claude/skills/archify/brand-marks/README.md; .codebuddy/skills/archify/brand-marks/README.md; .continue/skills/archify/brand-marks/README.md; .hermes/skills/archify/brand-marks/README.md; .workbuddy-ai/skills/archify/brand-marks/README.md
- 82EFC1BE4563: .agents/skills/archify/references/authoring-contract.md; .claude/skills/archify/references/authoring-contract.md; .codebuddy/skills/archify/references/authoring-contract.md; .continue/skills/archify/references/authoring-contract.md; .hermes/skills/archify/references/authoring-contract.md; .workbuddy-ai/skills/archify/references/authoring-contract.md
- 8010869DA706: .agents/skills/archify/references/brand-marks.md; .claude/skills/archify/references/brand-marks.md; .codebuddy/skills/archify/references/brand-marks.md; .continue/skills/archify/references/brand-marks.md; .hermes/skills/archify/references/brand-marks.md; .workbuddy-ai/skills/archify/references/brand-marks.md
- 1B8BC39B364F: .agents/skills/archify/references/delivery-contract.md; .claude/skills/archify/references/delivery-contract.md; .codebuddy/skills/archify/references/delivery-contract.md; .continue/skills/archify/references/delivery-contract.md; .hermes/skills/archify/references/delivery-contract.md; .workbuddy-ai/skills/archify/references/delivery-contract.md
- DC0D9FFE6B99: .agents/skills/archify/references/viewer-runtime.md; .claude/skills/archify/references/viewer-runtime.md; .codebuddy/skills/archify/references/viewer-runtime.md; .continue/skills/archify/references/viewer-runtime.md; .hermes/skills/archify/references/viewer-runtime.md; .workbuddy-ai/skills/archify/references/viewer-runtime.md
- 18C4F86BA62F: .agents/skills/archify/renderers/dataflow/README.md; .claude/skills/archify/renderers/dataflow/README.md; .codebuddy/skills/archify/renderers/dataflow/README.md; .continue/skills/archify/renderers/dataflow/README.md; .hermes/skills/archify/renderers/dataflow/README.md; .workbuddy-ai/skills/archify/renderers/dataflow/README.md
- F8EF88DC8591: .agents/skills/archify/renderers/lifecycle/README.md; .claude/skills/archify/renderers/lifecycle/README.md; .codebuddy/skills/archify/renderers/lifecycle/README.md; .continue/skills/archify/renderers/lifecycle/README.md; .hermes/skills/archify/renderers/lifecycle/README.md; .workbuddy-ai/skills/archify/renderers/lifecycle/README.md
- A442335DCF44: .agents/skills/archify/renderers/sequence/README.md; .claude/skills/archify/renderers/sequence/README.md; .codebuddy/skills/archify/renderers/sequence/README.md; .continue/skills/archify/renderers/sequence/README.md; .hermes/skills/archify/renderers/sequence/README.md; .workbuddy-ai/skills/archify/renderers/sequence/README.md
- 7E1BD65CC5CC: .agents/skills/archify/renderers/workflow/README.md; .claude/skills/archify/renderers/workflow/README.md; .codebuddy/skills/archify/renderers/workflow/README.md; .continue/skills/archify/renderers/workflow/README.md; .hermes/skills/archify/renderers/workflow/README.md; .workbuddy-ai/skills/archify/renderers/workflow/README.md
- F4CA94EC18CF: .agents/skills/archify/schemas/README.md; .claude/skills/archify/schemas/README.md; .codebuddy/skills/archify/schemas/README.md; .continue/skills/archify/schemas/README.md; .hermes/skills/archify/schemas/README.md; .workbuddy-ai/skills/archify/schemas/README.md
- 10094272D6D1: .agents/skills/archify/SKILL.md; .claude/skills/archify/SKILL.md; .codebuddy/skills/archify/SKILL.md; .continue/skills/archify/SKILL.md; .hermes/skills/archify/SKILL.md; .workbuddy-ai/skills/archify/SKILL.md
- 0B7FB59365DC: .agents/skills/archify/THIRD_PARTY_NOTICES.md; .claude/skills/archify/THIRD_PARTY_NOTICES.md; .codebuddy/skills/archify/THIRD_PARTY_NOTICES.md; .continue/skills/archify/THIRD_PARTY_NOTICES.md; .hermes/skills/archify/THIRD_PARTY_NOTICES.md; .workbuddy-ai/skills/archify/THIRD_PARTY_NOTICES.md
