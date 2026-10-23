# Índice documental canónico — INCES LMS

**Este es el punto de entrada documental del proyecto.** Si llegaste aquí por primera vez, empieza por «Por dónde entrar» más abajo; no leas el repositorio entero.

Este índice separa fuentes de verdad, planes, procedimientos, evidencias fechadas y material histórico. No sustituye al código ni convierte resultados antiguos en vigentes. Para localizar cada Markdown por ruta, tamaño y seguimiento Git, consulta el [catálogo documental](CATALOGO_DOCUMENTAL.md); para saber qué documento manda cuando dos se contradicen, la [estructura documental](ESTRUCTURA_DOCUMENTAL.md).

**Zona horaria del proyecto: Venezuela (UTC−4).** Toda hora sin indicar la zona es de aquí.

## Por dónde entrar

| Si eres… | Lee, en este orden | Después |
|---|---|---|
| **Persona o equipo nuevo** | [README del producto](../README.md) → [levantar en local](../LEVANTAR_EN_LOCAL.md) | [Convenciones](../MEMORY.md) |
| **Agente de IA o desarrollo** | [AGENT_START_HERE](../AGENT_START_HERE.md) → este índice → [estado vigente](../ESTADO_DEL_SISTEMA.md) | La auditoría fechada más reciente |
| **Vas a operar o publicar** | [Estado vigente](../ESTADO_DEL_SISTEMA.md) → [procedimiento de despliegue](PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md) | [Verificación posterior](PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md#9-verificación-posterior) y [rollback](PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md#101-rollback-y-recuperación) |
| **Vas a tocar la base de datos** | [Estado §3 esquema](../ESTADO_DEL_SISTEMA.md) → [validación de migraciones](../supabase/tests/README.md) | Procedimiento §8 de despliegue |
| **Vas a tocar un módulo concreto** | Su contrato o documento de diseño → [briefings de backend](BRIEFING_BACKEND_MODULO4.md) | La auditoría del módulo, si existe |

## Precedencia cuando hay contradicciones

Resumen completo en [ESTRUCTURA_DOCUMENTAL.md](ESTRUCTURA_DOCUMENTAL.md#jerarquía-de-precedencia). En una línea:

1. **Código, configuración y workflows reales** (`lib/`, `backend/src/`, `supabase/`, `render.yaml`, `.github/workflows/`).
2. **Procedimientos operativos vigentes** respaldados por evidencia.
3. **Estado del sistema y registros fechados de verificación** (`ESTADO_DEL_SISTEMA.md`, `docs/handover/*`).
4. **Manuales funcionales y documentación de arquitectura**.
5. **Historiales, handovers y notas de agentes** — contexto, nunca prueba por sí solos.

Una contradicción se **registra en los dos documentos** y se resuelve con evidencia; la fecha más reciente no gana por ser más reciente. Distinguir siempre: implementado · probado en local · probado en CI · desplegado · verificado en producción.

## Última sesión revisada

- [Auditoría adversarial — 2026-10-13](handover/AUDITORIA_ADVERSARIAL_2026-10-13.md): referencia operativa más reciente. Flutter test/analyze/build y E2E contra bundle se mantienen BLOCKED/NOT RUN con causas explícitas.
- [Cierre nocturno inicial — 2026-10-13](handover/CIERRE_AUTONOMO_NOCTURNO_2026-10-13.md): antecedente; no utilizar sus cifras si la auditoría adversarial las corrigió.
- [Fase 1 — consolidación documental, 2026-10-13 23:28 -04:00](../ESTADO_DEL_SISTEMA.md): última fotografía del árbol. Rama `main`, HEAD `ad5ce67`, 24 modificados y 31 sin seguimiento, **sin commit, push ni despliegue**.
- Baseline visto durante esta sesión: el árbol conserva cambios de código y artefactos temporales sin seguimiento. Volver a medir antes de operar.

## Índice por dominio

### Inicio rápido para desarrolladores

- [README del producto](../README.md) — qué es el LMS y cómo se usa.
- [Levantar el proyecto en local](../LEVANTAR_EN_LOCAL.md) — puertos, credenciales de prueba, arranque de backend y frontend.
- [Mapa del repositorio y comandos](contexto-ia/07_MAPA_Y_COMANDOS.md) — qué hay en cada carpeta y con qué comando se prueba cada cosa.
- [DevOps](../devops/README.md) — pipeline de contexto, `analizar-dart.mjs` y tareas de mantenimiento.
- [Glosario](contexto-ia/08_GLOSARIO.md) — vocabulario del proyecto (HACER, SCE, semilla, cola…).

### Arquitectura y estructura del sistema

- [Stack definitivo e inamovible](PLAN_MAESTRO_STACK_DEFINITIVO.md) — decisiones de arquitectura y por qué son fijas.
- [Arquitectura del Aula Virtual](ARQUITECTURA_AULA_VIRTUAL.md) · [investigación que la originó](INVESTIGACION_AULA_VIRTUAL.md).
- [Arquitectura general](contexto-ia/04_ARQUITECTURA.md) — capas, repositorios, puertas y RLS.
- [Diseño del sistema de producto](INCES_PREMIUM_PRODUCT_DESIGN_SYSTEM.md) — sistema de diseño premium.
- [Reporte de la interfaz renovada](REPORTE_INTERFAZ_RENOVADA.md).
- [Estructura documental](ESTRUCTURA_DOCUMENTAL.md) — jerarquía y reglas de mantenimiento.
- [Catálogo documental](CATALOGO_DOCUMENTAL.md) — inventario con estado y audiencia.

### Estado actual y riesgos conocidos

- [ESTADO_DEL_SISTEMA.md](../ESTADO_DEL_SISTEMA.md) — fotografía vigente, arquitectura confirmada, pruebas realmente ejecutadas, bloqueos y próximas acciones. Las entradas antiguas del archivo son historial.
- [Auditoría de rendimiento](AUDITORIA_RENDIMIENTO_2026-10-08.md) — causa raíz de la latencia y mejoras medidas.
- [Bloqueadores y seguimiento humano](AI_AGENT_BLOCKERS.md) — con la revalidación del 2026-10-13 en la cabecera.
- [Gates de fase](PROJECT_PHASE_GATES.md) — criterios de aceptación por fase.

### Instalación y configuración local

- [Levantar en local](../LEVANTAR_EN_LOCAL.md) — receta completa.
- [Configuración de Cloudflare R2](CONFIGURACION_R2.md) — bucket, CORS y ciclo de vida.
- `backend/.env` y `.env.json` **no se versionan**: sus variables se cargan desde el entorno. Nunca se copian valores a la documentación.

### Convenciones de desarrollo

- [Reglas y lecciones](contexto-ia/06_REGLAS_Y_LECCIONES.md) — léelo antes de tocar nada.
- [Protocolo de operación para agentes](AI_AGENT_OPERATING_PROTOCOL.md) — cómo se trabaja y cómo se entrega.
- [Autonomía eficiente en contexto](AI_AGENT_TOKEN_EFFICIENT_AUTONOMY.md) — continuidad sin quemar contexto.
- [MEMORY.md del proyecto](../MEMORY.md) — índice de memoria; el detalle vive en `.workbuddy-ai/memory/temas/`.

### Pruebas y control de calidad

- [Suite E2E](../e2e/README.md) — Playwright, bundle fresco, activación por variables.
- [Validación de migraciones](../supabase/tests/README.md) — PGlite sin Docker.
- [DevOps](../devops/README.md) — `analizar-dart.mjs`, `verificar-esquema.mjs` y resto de instrumentos.
- Estado real de cada verificación: sólo en [ESTADO_DEL_SISTEMA.md](../ESTADO_DEL_SISTEMA.md) y en la auditoría fechada más reciente. **BLOCKED y NOT RUN no se convierten en PASS por un verde parcial.**

### Base de datos y migraciones

- Esquema y tablas: [ESTADO_DEL_SISTEMA.md §3](../ESTADO_DEL_SISTEMA.md).
- Convención de nombres `YYYYMMDDNNN_*.sql` y libro mayor: [reglas y lecciones](contexto-ia/06_REGLAS_Y_LECCIONES.md).
- Aplicar/verificar migraciones: [validación de migraciones](../supabase/tests/README.md) y §8 del [procedimiento de despliegue](PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md). **Nunca se aplica una migración a producción sin autorización explícita.**
- Correo y RLS: las políticas se ejercen, no se leen; una política que llame a una función sin `EXECUTE` es inalcanzable.

### Autenticación, autorización y roles

- Tres roles y `exigirModulo` / `exigirSesion`: [reglas y lecciones](contexto-ia/06_REGLAS_Y_LECCIONES.md).
- La frontera de autorización es la RLS, no la API (ADR-003): [stack definitivo](PLAN_MAESTRO_STACK_DEFINITIVO.md).
- Invitación de docentes y recuperación interna: [auditoría de invitaciones](AUDITORIA_INVITAR_DOCENTE_Y_GESTION_ACADEMICA_2026-10-10.md) y [bloqueadores](AI_AGENT_BLOCKERS.md).
- Login por cédula: RPC `email_por_cedula` (`security definer`), normaliza por dígitos.

### Despliegue y actualización de producción

- **[Procedimiento oficial de despliegue](PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md)** — el único canónico. Inventario de workflows, build, Cloudflare Pages, Render, Supabyte y smoke tests.
- [Configuración de Cloudflare R2](CONFIGURACION_R2.md) si el cambio toca almacenamiento.

### Verificación posterior al despliegue

- §9 del [procedimiento](PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md): frontend público, bundle, validación funcional mínima en navegador real y registro de evidencia.
- §10.1 del mismo documento: [rollback y recuperación](PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md#101-rollback-y-recuperación).

### Manuales funcionales y procedimientos operativos

- [Ciclo de vida del cambio](contexto-ia/05_CICLO_DE_VIDA.md) — cómo nace, se verifica y se despliega un cambio.
- [Estado actual del sistema](contexto-ia/02_ESTADO_ACTUAL.md) · [proyecto y producto](contexto-ia/01_PROYECTO_Y_PRODUCTO.md).
- [Contrato E-2 de la planilla oficial](diseno/planilla/CONTRATO_E2_PLANILLA_OFICIAL.md) · [diseño de persistencia](diseno/planilla/DISENO_E2_PERSISTENCIA.md) · [renderer](diseno/planilla/PLANILLA_OFICIAL_RENDERER_DISENO.md) · [auto-prompt del ciclo](historial/prompts/AUTOPROMPT_PLANILLA.md) · [auditoría de la planilla](historial/auditorias/AUDITORIA_PLANILLA.md).
- [Diseño de duración/caducidad de períodos](DISENO_PERIODOS_DURACION_Y_CADUCIDAD_2026-10-10.md) — sólo diseño, requiere migración nueva y cinco decisiones institucionales.

### Documentación para agentes de IA

- [AGENT_START_HERE.md](../AGENT_START_HERE.md) — ruta obligatoria y corta. **Empieza aquí.**
- [Paquete de contexto para otra IA](contexto-ia/00_INDICE.md) — nueve documentos autocontenidos.
- [Contexto unificado](contexto-ia-unificado/CONTEXTO_COMPLETO_INCES_LMS.md) — el paquete entero en un solo archivo.
- [Protocolo operativo](AI_AGENT_OPERATING_PROTOCOL.md) · [recuperación de entorno](AI_AGENT_AUTONOMY_AND_ENVIRONMENT_RECOVERY.md) · [autonomía eficiente](AI_AGENT_TOKEN_EFFICIENT_AUTONOMY.md).
- **[Prompts legados archivados](historial/prompts/README.md)**: son historial conservado para auditoría. No se ejecutan en bloque ni se leen para una tarea sencilla.

### Historiales, handovers y registros de auditoría

- [Auditoría adversarial 2026-10-13](handover/AUDITORIA_ADVERSARIAL_2026-10-13.md) · [cierre nocturno 2026-10-13](handover/CIERRE_AUTONOMO_NOCTURNO_2026-10-13.md).
- [HANDOVER.md](../HANDOVER.md) (bitácora canónica inmutable) · [auditorías y handoffs anteriores](historial/auditorias/README.md) ([HANDOVER_CHAT_NUEVO.md](historial/auditorias/HANDOVER_CHAT_NUEVO.md) · [handoff ARIA G3](historial/auditorias/HANDOFF_ARIA_G3_2026-10-10.md) · [reporte ARIA](historial/auditorias/REPORTE_ARIA.md) · [auditoría de estado real](historial/auditorias/AUDITORIA_ESTADO_REAL.md)).
- [RELEASE_AUDIT_20261010_0302.md](historial/auditorias/RELEASE_AUDIT_20261010_0302.md) — histórico; sus afirmaciones de build de Flutter quedaron superadas por la medición del 2026-10-13.
- [Auditoría de interfaz y Fase 0](CLINE_AUDITORIA_FASE_0.md) · [bloqueadores de Fase 0.5](CLINE_FASE_0_5_BLOQUEADORES.md) · [error handler](CLINE_BLOQUE_E_ERROR_HANDLER.md).

### Planificación y alcance

- [Plan maestro](../PLAN_MAESTRO.md) · [roadmap](../ROADMAP.md).
- [Plan de cierre 100 % funcional](../PLAN_CIERRE_100_FUNCIONAL_2026.md) · [TODO operativo](../TODO_CIERRE_INTEGRAL_INCES_LMS.md) · [gates](PROJECT_PHASE_GATES.md).
- [Certificación de cierre total](CERTIFICACION_CIERRE_TOTAL.md) — histórico de gates G1–G10.

### Contratos de API y backend

- [Contrato API Módulo 2](CONTRATO_API_MODULO2.md) · [Módulo 3](CONTRATO_API_MODULO3.md).
- [Briefing backend Módulo 4](BRIEFING_BACKEND_MODULO4.md) · [Módulo 5](BRIEFING_BACKEND_MODULO5.md).
- OpenAPI generado: `backend/openapi.json` (la prueba `openapi.test.ts` lo compara contra las rutas reales en ambos sentidos).

## Mantenimiento

Actualizar el documento canónico del dominio y enlazar evidencia desde el checkpoint. No duplicar un mismo relato en varios planes. Las auditorías fechadas son fotografías históricas; si algo envejece, corregir la vista vigente sin borrar la evidencia histórica.

Todo enlace local de este índice se comprobó contra el árbol el **2026-10-13** (Fase 1). Si mueves o renombras un documento, actualiza este índice y el [catálogo](CATALOGO_DOCUMENTAL.md) el mismo día; un enlace roto en el punto de entrada es un defecto, no una nota.
