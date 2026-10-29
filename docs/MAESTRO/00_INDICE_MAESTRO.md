# ÍNDICE MAESTRO — INCES LMS

> **Propósito.** Este directorio es el **punto de entrada único** para entender y
> retomar el trabajo del LMS INCES sin tener que leer los ~80 `.md` que se
> acumularon. Consolida, en tres categorías limpias, todo el estado del sistema y
> el plan de trabajo, y es el documento que se le entrega al **siguiente agente**
> para que continúe sin perder contexto.
>
> Creado: 2026-10-29 · Autor: agente de consolidación · Dueño del producto: Lorenzo Roca.

## Cómo usarlo

1. **`01_COMPLETADO.md`** — qué está hecho y verificado (fases, módulos, infra).
2. **`02_PENDIENTES_Y_ERRORES.md`** — **el único `.md` de pendientes**: todo lo que
   queda por corregir/mejorar/implementar, recogido de los informes de todos los
   agentes anteriores (análisis de video V/N/T, `PLAN_CIERRE_INTEGRAL` F-series,
   auditorías, backlog y deuda de `ESTADO_DEL_SISTEMA`). Cada ítem lleva
   **fuente (archivo:línea)** para poder verificarlo, no es una suposición.
3. **`03_PLANES_Y_OBJETIVOS.md`** — visión de producto, hoja de ruta de UX/responsive
   y las fases 4 y 5 del rediseño de secciones.
4. **`04_PLAN_MAESTRO_DELEGABLE.md`** — **el plan de trabajo para el próximo agente**:
   paquetes de trabajo P0–Pn, cada uno con alcance, archivos a tocar, criterios de
   aceptación y cómo verificar. Empieza aquí si te pidieron "continuar".

## Dónde vive el detalle (no hace falta leerlo salvo para trazar historia)

- **`docs/ESTADO_DEL_SISTEMA.md`** — estado vivo y medido del sistema (cifras de CI,
  tabla de completado, deuda). Sigue siendo la fuente de verdad numérica.
- **`docs/BACKLOG_PENDIENTES.md`** — backlog detallado con evidencia por ítem.
- **`docs/contexto-ia/`** (00–08) — contexto técnico estructurado para IA.
- **`docs/historial/`** — **archivo completo** de los informes, planes, auditorías y
  *prompts* de sesiones anteriores. Ya estaba separado (se movió el 2026-10-22). Los
  `prompts/` ahí **no se leen ni se ejecutan en bloque**; son mandatos de sesiones
  pasadas. Si una cifra de ahí contradice `ESTADO_DEL_SISTEMA.md`, **manda el estado
  actual**.

## Organización lograda por este consolidado

| Categoría | Archivo MAESTRO | Equivale a |
|---|---|---|
| Ya completado | `01_COMPLETADO.md` | Fases 0–3, Módulos 1–7, infra, CI verde |
| Pendiente / errores | `02_PENDIENTES_Y_ERRORES.md` | Backlog abierto + deuda + leftovers de otros agentes |
| Planes / objetivos | `03_PLANES_Y_OBJETIVOS.md` | Fases 4–5, visión UX, roadmap |
| Plan maestro delegable | `04_PLAN_MAESTRO_DELEGABLE.md` | Lo que ejecuta el siguiente agente |

## Reglas de oro del proyecto (leer `docs/AI_AGENT_PROTOCOLO.md` para el detalle)

- **Medir antes de afirmar.** Una cifra o un defecto van acompañados de cómo se
  midieron. No se afirma "está roto" sin medirlo con el mismo instrumento.
- **La frontera de autorización es la RLS de Postgres, no la API.**
- **`ESTADO_DEL_SISTEMA.md` gana al código** cuando discrepan; ciérralo el mismo
  día que cierras algo en código.
- **CI es el verificador de Flutter/Dart** (en este equipo `flutter test` no arranca
  por tuberías nombradas / proxy). Comandos de verificación en `04_PLAN_MAESTRO_DELEGABLE.md`.
- **No borrar migraciones aplicadas.** Nuevas migraciones con formato `YYYYMMDDNNN_*.sql`.
- **El push es el respaldo**; dos ediciones al mismo archivo en un commit se pierden.
