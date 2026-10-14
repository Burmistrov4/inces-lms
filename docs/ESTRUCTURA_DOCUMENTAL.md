# Estructura documental y reglas de mantenimiento

## Objetivo

Que una persona o agente identifique qué leer, qué documento manda, cuál es el estado real, qué validar y dónde registrar evidencia, sin confundir memoria con pruebas.

## Jerarquía de precedencia

Cuando dos documentos se contradigan, se aplica este orden. **La jerarquía no autoriza a ignorar una decisión explícita de producto ni información de seguridad**: si el nivel 1 parece contradecir una decisión de producto, no se resuelve solo —se registra el conflicto y se pide la decisión.

| Nivel | Qué es | Por qué manda |
|---|---|---|
| **1. Código, configuración y workflows reales** | `lib/`, `backend/src/`, `supabase/`, `render.yaml`, `.github/workflows/`, `android/`, `web/` | Es el comportamiento implementado. Ningún documento cambia lo que el código hace. |
| **2. Procedimientos operativos vigentes, respaldados por evidencia** | `docs/PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md`, `LEVANTAR_EN_LOCAL.md`, `devops/README.md`, `e2e/README.md` | Comandos reproducibles con salida esperada; se siguen para operar. |
| **3. Estado del sistema y registros fechados de verificación** | `ESTADO_DEL_SISTEMA.md` (sección vigente), `docs/handover/*` | Fotografía del árbol en una fecha; sus cifras envejecen y se re-miden. |
| **4. Manuales funcionales y documentación de arquitectura** | arquitectura, contratos de API, diseño, briefings de módulo | Explican el sistema; se validan contra el nivel 1 antes de citarlos como verdad. |
| **5. Historiales, handovers y notas de agentes** | `HANDOVER*.md`, prompts, `.workbuddy-ai/memory/`, `docs/contexto-ia*/` | Contexto útil y decisiones pasadas. Nunca prueba por sí solo. |

**Cómo se resuelve una contradicción**

1. Se mide con el instrumento que corresponde al nivel del que viene la afirmación (para el nivel 1, ejecutar el comando o leer el archivo; para el 3, el comando de verificación).
2. Se registra el conflicto **en los dos documentos**, con fecha y evidencia, aunque uno quede por encima del otro.
3. **No se elige automáticamente la versión más reciente.** Un documento más nuevo puede estar simplemente desactualizado: la fecha no es prueba. Si el nivel 4 o 5 contradice al nivel 1, gana el nivel 1 aunque sea más viejo.
4. Si la contradicción es de producto o de seguridad y no se puede resolver midiendo, se marca como **pendiente de decisión** y se pregunta; no se resuelve por jerarquía.

## Fuentes canónicas por dominio

| Dominio | Fuente canónica | Regla |
|---|---|---|
| Entrada humana | README.md | Presentación y puesta en marcha; no es bitácora. |
| Entrada de agentes | AGENT_START_HERE.md | Lectura mínima y actuación segura. |
| Índice | docs/README.md | Mapa, precedencia y enlaces. |
| Estado real | ESTADO_DEL_SISTEMA.md | Fotografía vigente; entradas antiguas quedan como historial. |
| Alcance | PLAN_MAESTRO.md, PLAN_CIERRE_100_FUNCIONAL_2026.md, TODO_CIERRE_INTEGRAL_INCES_LMS.md | Objetivos, aceptación y cola operativa, sin duplicar funciones. |
| Gates y protocolo | docs/PROJECT_PHASE_GATES.md, docs/AI_AGENT_OPERATING_PROTOCOL.md | Criterios de calidad y reglas de trabajo. |
| Arquitectura/contratos | Documentos de arquitectura, módulos, SQL/API y diseño | Validar contra código, esquema y permisos reales. |
| Runbooks | Despliegue, arranque local, DevOps, E2E y R2 | Comandos reproducibles; secretos sólo en archivos locales protegidos. |
| Evidencia fechada | docs/handover y auditorías fechadas | Registro de observaciones y bloqueos de cada sesión. |
| Memoria de agentes | .workbuddy-ai/memory, MEMORY.md y memorias de otros agentes | Contexto auxiliar; no demuestra pruebas ni estado remoto. |

## Clasificación del inventario

Inventario contado el **2026-10-13 (Fase 1)** con recorrido recursivo excluyendo dependencias y artefactos: node_modules, .git, .dart_tool, build, .wrangler, entornos virtuales y deploy-ad5ce67. **Resultado: 218 archivos Markdown** (recontado al cierre de la Fase 1; el primer recuento dio 217 porque aún no existía `docs/handover/FASE1_CONSOLIDACION_DOCUMENTAL_2026-10-13.md`), de los que el catálogo lista 217 —se excluye a sí mismo—.

**Desglose por categoría, corregido el 2026-10-14** (cada ruta contada una sola vez, con git como autoridad): **72 rastreados** (`git ls-files '*.md'`), **16 no rastreados y no ignorados** (`git ls-files --others --exclude-standard '*.md'`) y **130 ignorados** por `.gitignore` (`git ls-files --others --ignored --exclude-standard '*.md'`, más un fichero en una ruta demasiado larga para que git la recorra, confirmado ignorado con `git check-ignore`). 72 + 16 + 130 = 218.

> **Corrección del 2026-10-14.** Esta línea afirmaba «72 rastreados y 145 sin rastrear». Era
> incorrecto: mezclaba en un solo número los archivos sin seguimiento con los que están
> cubiertos por reglas de ignorado. De esos 145, sólo **16** carecen de seguimiento; los
> otros **129** son documentos dentro de `.agents/`, `.claude/skills/`, `.workbuddy-ai/` y
> `No subir esta carpeta…`, todos ignorados por git. Las etiquetas del anexo del catálogo se
> reescribieron entrada por entrada.
>
> **Y no confundir** los 16 Markdown sin seguimiento con los **80 archivos sin seguimiento de
> cualquier extensión** (`git ls-files --others --exclude-standard`): son recuentos de
> universos distintos.

- **Producto/código:** raíz, docs, devops, e2e, supabase/tests, diseño de planilla y contratos.
- **Evidencia histórica:** auditorías, reportes, handovers, checkpoints y planes fechados. No asumir que siguen vigentes.
- **Prompts legados:** PROMPT_*, MEGA_PROMPT_* y ULTRA_MEGA_PROMPT_*. No iniciar una sesión leyéndolos/ejecutándolos todos; manda AGENT_START_HERE y el gate activo.
- **Memorias internas:** .workbuddy-ai/memory, artefactos de agentes y MEMORY.md; son contexto, no evidencia ejecutable.
- **Skills/configuración de herramientas:** copias bajo .agents, .claude, .codebuddy, .continue, .hermes y .workbuddy-ai/skills. No moverlas como si fueran documentación del producto.
- **Material académico separado:** No subir esta carpeta Github - Contexto - Archivos. No es manual de ingeniería y debe seguir separado del repositorio publicable.

## Reorganización hecha en esta fase

1. Se establece un índice único en docs/README.md y un catálogo reproducible en docs/CATALOGO_DOCUMENTAL.md.
2. Se define precedencia y diferencia entre código, mediciones, planes, memoria e historial.
3. La auditoría adversarial del 2026-10-13 queda por encima del cierre nocturno inicial del mismo día.
4. La futura lectura de agentes se acota a fuentes canónicas, sin mover todavía archivos que puedan tener enlaces existentes.

## Fase 1 (2026-10-13) — consolidación sin mover archivos

Trabajo documental hecho sin reestructurar el árbol, para no romper enlaces ni perder cambios de otros agentes:

1. `docs/README.md` queda como punto de entrada único, organizado por finalidad y público.
2. `docs/CATALOGO_DOCUMENTAL.md` añade, para cada documento relevante, propósito, público, estado, documento canónico relacionado y acción recomendada. **El inventario automático se conserva como anexo**, porque es reproducible y permite localizar cualquier Markdown por ruta.
3. La jerarquía de cinco niveles de este documento sustituye a la regla anterior de `ESTADO_DEL_SISTEMA.md` («si algo aquí contradice a otro archivo, manda este»), que quedó registrada como histórica en ese mismo archivo.
4. `docs/PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md` es el **único** procedimiento oficial de despliegue. `RELEASE_AUDIT_20261010_0302.md` y `PROMPT_ANTIGRAVITY_RELEASE_PRODUCCION_HOY.md` quedan catalogados como histórico y como prompt: no son guías operativas y no deben divergir del canónico.
5. `docs/AI_AGENT_BLOCKERS.md` lleva ahora en su cabecera la revalidación del 2026-10-13, que conserva las entradas antiguas con su fecha y marca cuáles quedaron superadas.
6. No se borró ni movió ningún documento. Los duplicados detectados quedan listados en el catálogo con su acción recomendada para una fase posterior.

## Fase posterior: movimiento físico no destructivo

No renombrar ni mover en masa los documentos antiguos sin analizar primero sus referencias entrantes. Después, se podrán agrupar en docs/arquitectura, docs/operacion, docs/calidad, docs/modulos, docs/agentes y docs/historial. Dejar stubs/enlaces en las rutas antiguas cuando exista compatibilidad que preservar. No borrar informes por parecer duplicados sin comparar fecha, contenido y referencias.

## Reglas de mantenimiento

- Todo documento nuevo declara propósito, estado (vigente/histórico), fecha y fuente de evidencia cuando aplica.
- Cifras de pruebas, migraciones y producción incluyen fecha, entorno, comando y código de salida.
- BLOCKED/NOT RUN no se convierte en PASS por logs parciales, análisis sustitutos o éxito del código fuente.
- Corregir el documento canónico una sola vez; los demás enlazan.
- Nunca registrar secretos, valores de .env, tokens, cookies, JWT ni PII innecesaria.
- Antes de editar, revisar git status y contenido actual por si otro agente comparte el árbol.
