# AGENT START HERE — INCES LMS

> **INDICE DE DOCUMENTACION:** [`docs/README.md`](docs/README.md) — por donde empezar.
> **PENDIENTES:** [`docs/BACKLOG_PENDIENTES.md`](docs/BACKLOG_PENDIENTES.md).
> **CONTINUIDAD:** [`docs/handover/REPORTE_CONTINUIDAD_2026-10-22.md`](docs/handover/REPORTE_CONTINUIDAD_2026-10-22.md).

## Misión

Tomar el estado real del repositorio y avanzar hasta cerrar lo que se pueda cerrar con evidencia. No depender del historial conversacional ni de un resumen de otra sesión: **el disco manda**.

Este archivo es una ruta de trabajo, no un mandato de proyecto. Si te pidieron algo concreto, hazlo; si te pidieron «cerrar todo», usa como alcance [PLAN_MAESTRO.md](docs/historial/planes/PLAN_MAESTRO.md) y [TODO_CIERRE_INTEGRAL_INCES_LMS.md](docs/historial/planes/TODO_CIERRE_INTEGRAL_INCES_LMS.md).

## Ruta obligatoria — nueve pasos, en este orden

Para una tarea sencilla, los pasos 1–5 son lectura corta: **no hace falta leer todo lo que hay enlazado abajo**.

1. **Reglas y restricciones del repositorio.** Lee §2 de [docs/ESTRUCTURA_DOCUMENTAL.md](docs/ESTRUCTURA_DOCUMENTAL.md) (precedencia) y las reglas no negociables de [docs/PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md](docs/PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md) §2. Sin `git reset --hard`, sin `git clean -fd`, sin borrar datos, sin publicar secretos, sin commit/push/despliegue sin autorización.
2. **Índice documental central.** [docs/README.md](docs/README.md): qué existe y para quién. Si necesitas un contrato, un runbook o una auditoría, sal de ahí.
3. **Estado del sistema y handover vigente.** La sección superior de [ESTADO_DEL_SISTEMA.md](ESTADO_DEL_SISTEMA.md) y la auditoría fechada más reciente (`docs/handover/`). Las entradas antiguas de ese archivo son historia, no fotografía.
4. **`git status` antes de tocar nada.** `git status --short`, `git rev-parse HEAD`, `git log -1 --oneline`. Puede haber otro agente editando los mismos documentos: **relee justo antes de editar** y prefiere ediciones aditivas y acotadas. Comprueba también procesos y puertos en uso, y si la base está al día: `node supabase/apply-migrations.mjs --check`.
5. **Investiga el código y reproduce el problema.** «No está» se mide, no se deduce. Si no puedes reproducirlo, ese hecho es el primer hallazgo, no una excusa para seguir.
6. **Implementa cambios pequeños, con su prueba.** Un cambio por ciclo, con la prueba que lo fije. Si el cambio es de comportamiento, la prueba tiene que poder fallar: verifícala por mutación si el riesgo lo justifica.
7. **Ejecuta las verificaciones y documenta el resultado real.** Abajo está el banco de pruebas de este entorno, con lo que **sí** corre y lo que está bloqueado. Un BLOCKED se declara BLOCKED con su causa y su código de salida; nunca se convierte en PASS por un sustituto, un log parcial o un verde antiguo.
8. **Actualiza la documentación afectada.** El mismo día. Si corriges una cifra, corrige también el documento que la citaba; si un documento queda obsoleto, márcalo como histórico con su fecha en lugar de borrarlo.
9. **Entrega un resumen** con: archivos tocados, evidencia (comando + código de salida), riesgos, bloqueos H1–H4 y estado de Git. Nunca dejes sólo «continuar».

## Banco de pruebas de este entorno (medido el 2026-10-13)

| Comprobación | Comando | Estado |
|---|---|---|
| Backend completo | `npm run verify` en `backend/` (typecheck + lint + vitest) | **PASS**: 685/685 en 33 archivos, exit 0 |
| Compilación backend | `npm run build` en `backend/` | exit 0 (medido en la auditoría adversarial del 2026-10-13, no en cada sesión: **revisalo si tu cambio toca TypeScript**) |
| Resolución de dependencias Dart | `dart pub get` con `FLUTTER_ROOT=/c/Users/Loro/develop/flutter` | **PASS**: exit 0 |
| Análisis estático de Dart | `node devops/analizar-dart.mjs` | 226 archivos, 0 issues, exit 0 (**no** es `dart analyze`) |
| `flutter test` / `flutter analyze` / `flutter build web` / build Android local | — | **BLOCKED** con `CreateFile failed 231` (el VM de Dart no puede crear la tubería de su hijo en este sandbox). Más JRE 1.8.0_501, sin JDK 17+ |
| E2E contra bundle fresco | — | **NOT RUN**: no hay bundle fresco en el árbol |
| Suite E2E de SEO | — | pruebas verdes contra los fuentes, salida no verificada (teardown colgado) |

**Consecuencia:** la verificación real del lado Flutter es CI (`flutter_ci.yml`, `e2e.yml`, `web_bundle.yml`, `android_bundle.yml`). Si el `231` algún día no se reproduce, **mídelo y regístralo con su fecha**; no borres la entrada anterior. Este bloqueo ha ido y vuelto entre sesiones.

Detalle, causas y alternativas: [docs/AI_AGENT_PROTOCOLO.md](docs/AI_AGENT_PROTOCOLO.md) y [docs/handover/AUDITORIA_ADVERSARIAL_2026-10-13.md](docs/handover/AUDITORIA_ADVERSARIAL_2026-10-13.md).

## Regla de autonomía

No preguntes qué hacer cuando el siguiente paso sea deducible del estado. Cerrar un hito no termina el trabajo.

    ESTADO → SIGUIENTE DISCRIMINADOR → IMPLEMENTAR → PROBAR → REGRESAR → DOCUMENTAR → REPETIR

Si algo falla, no declares imposibilidad. Escalera: cambiar de herramienta · reducir el caso · bajar de capa · inspeccionar artefactos propios · usar ingeniería inversa del sistema propio · crear un adaptador reversible · probar equivalencia · documentar.

## Ingeniería inversa

Permitida sobre código, artefactos, bundles propios, sourcemaps, OpenAPI, migraciones, contratos, trazas y APIs legítimamente accesibles. **Prohibida** para evadir autenticación, MFA, CAPTCHA, RLS, autorización, secretos o controles de terceros.

## Únicos bloqueadores humanos

| Id | Situación |
|---|---|
| **H1** | Credencial externa que sólo el propietario puede proporcionar |
| **H2** | Autorización para una acción irreversible |
| **H3** | Decisión de producto genuinamente ambigua y no deducible |
| **H4** | Infraestructura externa que exige login interactivo, MFA, CAPTCHA o aprobación física |

Un H1–H4 no detiene el resto del proyecto: se registra y se sigue con lo independiente. Los que están abiertos ahora están en [docs/AI_AGENT_PROTOCOLO.md](docs/AI_AGENT_PROTOCOLO.md).

## Evidencia

Nunca declares PASS por: pantalla abierta · HTTP 200 aislado · mock · reintento · prueba sin precondición · no-op · un verde heredado de otra sesión. La prueba debe demostrar la operación real que afirma medir.

---

## Estado conocido al 2026-10-09 (sesión 2) — HISTÓRICO, no lo uses como actual

> **Aviso:** este bloque es una fotografía del 2026-10-09 y **contradice** la medición del 2026-10-13 que está más arriba (allí el `231` sí bloquea). Se conserva por su fecha y por las decisiones que registra; **la cifra vigente es la de la tabla del banco de pruebas.** Lee esta sección sólo si necesitas el contexto de aquella sesión.

- **Autenticación SIN Resend: CERRADA y VERIFICADA contra el motor real (2026-10-09).** Recuperación interna (código temporal de un solo uso emitido por un administrador, canjeado por el titular que fija su propia contraseña, con **cierre de las sesiones previas**) y ciclo de vida completo de la invitación docente (consumo atómico, revocar, renovar, listado con estado real y sin exponer el hash). Evidencia de aquella sesión: `supabase/humo-invitaciones.mjs` → **34 OK / 0 fallos**; `supabase/humo-recuperacion.mjs` → **27 OK / 0 fallos**; residuo `0/0/0` en ambos. Migraciones `202610090001`/`202610090002` aplicadas a la nube.
- **Defecto real corregido en aquella sesión:** la emisión de códigos escribía `password_resets` con el cliente del llamante (sólo tiene `SELECT`) → 403 en la nube. Ahora va por `reposAdmin`, y el arnés de pruebas **bloquea** esa vía para que el defecto no vuelva a pasar inadvertido.
- **P0 / E2E de aquella sesión:** el bundle local estaba compilado con `dart-define.example.json` (la plantilla) → la app apuntaba a una URL inválida y el login fallaba **antes de emitir ninguna petición**. Guardia añadida en `e2e/playwright.config.ts`, que sigue vigente.
- **Rendimiento (G3, 2026-10-09):** el hook de autenticación hacía **dos viajes de red en serie en cada petición autenticada** (verificar token en GoTrue + leer perfil en PostgREST = **421 ms fijos**), y cada consulta adicional sumaba ~190 ms. Paralelizados esos dos viajes y tres pares de lecturas independientes: `admin/usuarios` **−64 %** (1.462 → 521 ms), `aula/trabajo` −47 %, `aula/mis-entregas` −43 %, `mi-horario` −32 %. Detalle y tablas en [docs/AUDITORIA_RENDIMIENTO_2026-10-08.md](docs/AUDITORIA_RENDIMIENTO_2026-10-08.md).
- Restricciones externas que siguen abiertas: clave de firma para Play, SMTP/Resend (401), `SUPABASE_JWT_SECRET`, los 6 secretos del barrido D9 y la lista de campos de HACER (D17).

Estos datos son una fotografía, no una fuente superior al código o a una medición nueva.

## Handoff

Al detenerte por un límite real del entorno, escribe en `docs/handover/` un registro con: fecha · fase · hito · estado · evidencia (comando y código de salida) · archivos · comandos · resultados · regresiones · H1/H2/H3/H4 · deudas · siguiente discriminador · comando exacto · criterio de cierre.

Nunca dejes únicamente «continuar».

## Continuidad de agentes

- [docs/AI_AGENT_TOKEN_EFFICIENT_AUTONOMY.md](docs/AI_AGENT_TOKEN_EFFICIENT_AUTONOMY.md) — continuidad económica de contexto.
- [docs/PROJECT_PHASE_GATES.md](docs/PROJECT_PHASE_GATES.md) — puertas de aceptación.
- [docs/AI_AGENT_PROTOCOLO.md](docs/AI_AGENT_PROTOCOLO.md) — protocolo de trabajo.
- [docs/AI_AGENT_AUTONOMY_AND_ENVIRONMENT_RECOVERY.md](docs/AI_AGENT_AUTONOMY_AND_ENVIRONMENT_RECOVERY.md) — recuperación de entorno.

**Prompts legados archivados** (`docs/historial/prompts/`): no se leen ni se ejecutan en bloque. Son mandatos de sesiones pasadas; comprueba que su objetivo sigue vigente contra [ESTADO_DEL_SISTEMA.md](ESTADO_DEL_SISTEMA.md) antes de usarlos. Para referencia histórica con otro agente (Antigravity, Gemini), [PROMPT_MAESTRO_CICLO_VIDA_COMPLETO_AGENTE_IA.md](docs/historial/prompts/PROMPT_MAESTRO_CICLO_VIDA_COMPLETO_AGENTE_IA.md) y [PROMPT_ANTIGRAVITY_AUTONOMOUS_CLOSURE.md](docs/historial/prompts/PROMPT_ANTIGRAVITY_AUTONOMOUS_CLOSURE.md) están organizados en [docs/historial/prompts/](docs/historial/prompts/README.md).

El agente debe continuar por ciclos verificables, guardar checkpoints y cambiar de método ante bloqueos; no debe intentar evadir cuotas, controles de seguridad ni límites legítimos del proveedor.
