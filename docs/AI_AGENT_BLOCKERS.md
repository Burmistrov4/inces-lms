# AI Agent Blockers / Human Follow-up

> Regla: un bloqueo afecta sólo la subtarea correspondiente. El agente continúa con todo trabajo independiente. Revalidar estos estados contra evidencia nueva antes de actuar.

## ⚠️ Revalidación del 2026-10-13 — lee esto antes de usar las entradas de abajo

Este archivo contiene una **contradicción documental resuelta por medición**, y conviene saber cuál de las dos versiones manda:

| Fecha | Afirmación | Evidencia |
|---|---|---|
| 2026-10-09 (sesión 2) | «El `CreateFile failed 231` **no se reproduce**; el toolchain de Flutter funciona; `flutter test` → 974 pruebas, `flutter build web` → `√ Built`» | Verdadero **en aquella sesión y con aquel entorno** |
| 2026-10-13 | El `231` **sí bloquea** cualquier VM de Dart que spawnee un hijo, y `flutter build web` no se puede compilar en local | `docs/handover/AUDITORIA_ADVERSARIAL_2026-10-13.md` §4 |

**Registrado como contradicción, no borrado.** La entrada del 2026-10-09 se conserva tal cual, con su fecha. **El estado vigente es el del 2026-10-13**: el bloqueo es del entorno/sandbox de Windows, no del proyecto, y se reproduce de forma sostenida. Un bloqueo que aparece y desaparece entre sesiones se mide **cada vez** que se va a citar; nunca se hereda de un párrafo.

Comandos medidos el 2026-10-13, con su código de salida:

| Comando | Resultado | Qué demuestra |
|---|---|---|
| `dart pub get` (con `FLUTTER_ROOT`) | **exit 0**, «Got dependencies!» | La resolución de dependencias sí funciona; es la vía segura |
| `node devops/analizar-dart.mjs` | **exit 0**, 226 archivos, 0 issues | El sustituto del analizador corre; **no** equivale a `dart analyze` |
| `npm run verify` (en `backend/`) | **exit 0**, 685/685 en 33 archivos | El backend se verifica completo en local |
| `flutter pub get` | muere con `231` | El wrapper de Flutter spawnea `git.exe`/`where.exe` |
| `dart analyze` | muere con `231` | Lanza el analysis server |
| `flutter build web` | muere con `231` | — |
| `flutter test` | muere con `231` | — |

**Consecuencia operativa:** la verificación real del lado Flutter es CI (`flutter_ci.yml`, `e2e.yml`, `web_bundle.yml`, `android_bundle.yml`). Un análisis sustituto o un bundle antiguo **no** se declaran como PASS de `flutter test`/`analyze`/`build`.

**Bloqueos reproducidos y pendientes al 2026-10-13** (todos ellos requieren acción del propietario, no del agente):

1. Clave de firma de distribución para Google Play (el APK actual es de depuración).
2. SMTP/Resend: HTTP 401; sólo afecta notificaciones externas opcionales.
3. `SUPABASE_JWT_SECRET` en `backend/.env` para verificar el JWT en local y quitar el viaje a GoTrue.
4. Los 6 secretos del barrido D9 (`limpiar-pendientes.yml` falla seguro sin ellos).
5. La lista de campos de HACER (D17): falta el archivo de ejemplo.
6. Cuenta de prueba autorizada para verificar «Invitar docente» y la promoción de administradores **en producción**.

---

## Resueltos — 2026-10-09 (sesión 2: build local y flujos de identidad)

### El `CreateFile failed 231` NO se reproduce — el toolchain de Flutter funciona en esta sesión

> **Superado el 2026-10-13:** el `231` volvió a reproducirse de forma sostenida en el sandbox de Windows. Esta entrada es histórica; el estado vigente está en la revalidación de la cabecera.
- **Medición (no deducción):** `flutter.bat --version` → OK; `flutter build web --release --dart-define-from-file=.env.json` → **`√ Built build\web`** (157 s, exit 0); `flutter.bat test --no-pub` → ejecuta la suite completa (924+ casos observados) sin el `231`.
- **Consecuencia:** el bloqueo histórico **no es un defecto del proyecto ni de la configuración**: es del entorno/sandbox de la sesión anterior. No se debe volver a citarlo como «bloqueado por el 231» sin volver a medirlo.
- **Bundle fresco verificado:** `build/web/main.dart.js` (3.773.331 B, 2026-10-09 12:23) contiene la URL real (`twdppwnxlnmxkiejbrei`), **cero** marcadores de plantilla, `restablecer-codigo` y `mobile_scanner`. Es decir: el artefacto corresponde al código actual, incluido lo no commiteado.
- **Cierre:** se puede recompilar en local. La vía por el artefacto `web-bundle` de CI sigue siendo válida como alternativa, pero deja de ser la única.

### Recuperación interna — la emisión de códigos escribía por la vía del usuario (defecto real, corregido)
- **Síntoma:** `POST /api/v1/admin/usuarios/:id/restablecer` → **403 PERMISO_DENEGADO**, `contexto: "anular códigos previos"`.
- **Causa raíz:** la ruta escribía `password_resets` con `reposDe(request)` —el cliente del llamante, con RLS—, pero esa tabla **sólo concede `SELECT` a `authenticated`** y no tiene política de escritura: su único camino de entrada es el backend con `service_role`, por diseño. Contra Postgres es un `42501`.
- **Por qué no lo vio ninguna prueba:** el arnés de backend devolvía **el mismo objeto** de repositorios para `reposAdmin` y para `reposDePeticion`, así que la escritura «funcionaba» en memoria. Sólo se reprodujo contra el motor real.
- **Corrección (dos partes):** (1) la ruta usa `deps.reposAdmin.recuperacion.emitir(...)` —la lectura del perfil sigue yendo por RLS—; (2) el arnés ahora devuelve una **vista del llamante** cuyo `recuperacion.emitir` falla a propósito, imitando la RLS. Cualquier ruta que vuelva a escribir por la vía equivocada falla en la prueba, no en la nube.
- **Evidencia:** `node supabase/humo-recuperacion.mjs --confirmar` → **27 OK / 0 fallos**, residuo 0/0/0 (ver más abajo).

### Flujos de identidad — verificados contra el motor real (A y B)
- **Instrumentos nuevos/ampliados (fuera de CI a propósito, con cuentas desechables y purga):**
  - `supabase/humo-recuperacion.mjs` (**nuevo**): emite código → huella SHA-256 en la base → emitir otro anula el anterior → canje → contraseña nueva entra y la vieja no → **el refresh token previo muere** (revocación de sesiones) → no reutilizable → código inválido responde igual (sin enumeración) → auditoría sin secretos. **27 OK / 0 fallos.**
  - `supabase/humo-invitaciones.mjs` (**ampliado**): añadido el ciclo de vida — revocar (403 al activar, sin crear cuenta, 409 al revocar dos veces), renovar (la vieja queda revocada y su token deja de activar; la nueva activa y crea el docente), y el listado del panel que **no expone el hash del token**. **34 OK / 0 fallos.**
- **Aislamiento demostrado:** ambos crean cuentas `humo-*@ejemplo.invalid`, operan sólo sobre ellas y **purgan por prefijo**; el residuo medido es `0/0/0` en los tres contadores.
- **Criterio de cierre cumplido:** invitación→activación→login y recuperación→contraseña nueva→login→rechazo de la anterior, más cierre de sesiones y rechazo de token repetido.

### E2E completo con bundle FRESCO — verde
- `CI=true E2E_ARRANCAR_BACKEND=0 E2E_WEB_DIR=../build/web npx playwright test` → **24/24 passed (2.2 min), exit 0** sobre el bundle recién compilado (no el de CI ni una copia parcheada). Incluye los ocho módulos P0, Usuarios y Roles, `export_csv`, `aula_virtual` y `stepper_inscripcion`.

## Resueltos — 2026-10-09

### UI autenticada de Usuarios y Roles y módulos P0 — CERRADO (causa raíz medida)
- **Síntoma real (no el descrito antes):** no era «Chromium se bloquea antes del primer caso». El harness **sí** ejecuta; lo que fallaba era el **login del administrador**: el formulario se enviaba y no pasaba nada.
- **Causa raíz:** el bundle local `build/web` estaba compilado con **`dart-define.example.json`** (la plantilla), no con `.env.json`. El artefacto contiene literalmente
  `("<clave-publicable>","https://<project-ref>.supabase.co")`, así que la app apunta a una URL inválida y el SDK lanza **antes de emitir ninguna petición**. `AppConfig.validate()` no lo detecta (sólo comprueba que no esté vacío).
- **Cómo se midió:** credenciales válidas contra Supabase Auth (200) · no es el gesto (`pulsar` y `pulsarReal` fallan igual) · el control «Mostrar contraseña» **sí** funciona (los clicks llegan a Flutter) · volcado del árbol tras pulsar → SnackBar «No pudimos completar la operación» · red completa durante el login → **cero** peticiones · `fetch` directo del navegador a Supabase → **200** (descarta proxy/CORS) · `grep` del artefacto → los marcadores.
- **Corrección:** se sustituyeron los dos marcadores en una **copia** del bundle (`C:/tmp/web-fixed`, script `C:/tmp/parchear-bundle.mjs`). El build local está bloqueado por el `231`, así que no se puede recompilar aquí. Añadida **guardia** en `e2e/playwright.config.ts`: si el bundle trae los marcadores, falla de inmediato con la causa escrita (control negativo y positivo verificados).
- **Evidencia:** `npx playwright test tests/admin_cpanel_p0.spec.ts` con `CI=true` y `E2E_WEB_DIR` al bundle corregido → **10/10 ok, 0 fallos** (login + los **ocho módulos P0** + Usuarios y Roles), con peticiones reales al backend (`/api/v1/admin/ocupacion`, `/periodos`, `/programas`, `/secciones`, `/usuarios` → 200).
- **Ajuste del spec:** `admin_cpanel_p0.spec.ts` comprobaba el buscador con `cuantos('Buscar usuario')`, que da **0** porque `cuantos` sólo mira roles `button|link|tab|menuitem` o hojas de texto, y un `textbox` no es ninguna de las dos cosas. Cambiado a `campo('Buscar usuario').count()`.
- **Regresión seleccionada revalidada el 2026-10-09:** `admin_cpanel_p0.spec.ts` + `export_csv.spec.ts` + `aula_virtual.spec.ts` + `stepper_inscripcion.spec.ts` → **24 esperadas, 0 omitidas, 0 inesperadas, 0 flaky**, código de salida 0; informe JSON temporal `C:/tmp/inces-e2e-regression-20261009.json`. Corrida con `CI=true` y `E2E_WEB_DIR=C:/tmp/web-fixed`.
- **Riesgo residual:** `build/web` y `.env.json` están **ignorados por git**, así que aquello era un artefacto local, no un defecto del repositorio. **Superado el 2026-10-09 (sesión 2):** el bundle **sí se recompila en local** (`flutter build web --release --dart-define-from-file=.env.json` → `√ Built build\web`) y la suite E2E completa pasa **24/24** contra ese bundle fresco. La guardia de `e2e/playwright.config.ts` sigue vigente para que un bundle compilado con la plantilla falle de inmediato.

## Abiertos — requieren diagnóstico/seguimiento técnico

### Aplicación de migraciones Supabase — CERRADO
- Proyecto/ref confirmado: twdppwnxlnmxkiejbrei, estado ACTIVE_HEALTHY.
- Se aplicaron ambas migraciones remotas:
  - 202610070001_remove_semilla_soldadura_basica.sql
  - 202610080001_remove_legacy_m6_asistencia.sql
- El aplicador confirmó 10 módulos en system_modules, y la existencia de teacher_invitations y auth_logs.
- Comprobación posterior ejecutada con token cargado temporalmente desde backend/.env: 44 registradas, 0 pendientes, 0 con deriva. El modo --check no aplicó cambios.
- El token no se imprimió ni se copió a la documentación. Se retiró de la variable de entorno al terminar.
- Resultado: este bloqueo queda cerrado. No volver a marcarlo abierto salvo que una comprobación futura detecte divergencia.

## Seguimiento técnico — estados actualizados al 2026-10-09

### Ciclo E2E de Aula Virtual — CERRADO (2026-10-09)
- **Estado:** cerrado por ejecución real con limpieza verificada. Se ejecutó `E2E_PERMITIR_CICLO_MUTANTE=1 npx playwright test tests/aula_virtual_ciclo.spec.ts` contra el bundle local fresco.
- **Resultado actualizado:** **7/7 PASS, 0 flaky, exit 0** (2,6 min). C7 ahora espera el título real `Calificaciones` en vez del texto inexistente `LIBRO DE CALIFICACIONES`; también exige acciones montadas y fila del estudiante.
- **Recorrido:** el docente publica → el aprendiz abre y entrega → el docente abre el libro, califica 18 y devuelve → el aprendiz ve «Devuelta» y «Nota: 18 pts.».
- **Limpieza:** `supabase/limpiar-ciclo-aula.mjs --confirmar --desde "2026-10-09T17:35:07.532Z"` borró únicamente la tarea creada en esta corrida. Tareas **77 → 76**, entregas **228 → 225**, **0 huérfanas**.
- **Nota de datos:** la sección `SA` conserva **76 tareas** previas al ciclo de esta corrida; no se borraron ni alteraron.
- **Siguiente acción:** no queda un bloqueo C7. Continuar con medición de performance por rol y gates posteriores.

### Flutter test runner completo — entorno Windows — RESUELTO (2026-10-09, sesión 2)

> **Superado el 2026-10-13:** el cierre sólo es válido para la sesión del 2026-10-09. En la sesión del 2026-10-13 `flutter test --no-pub` y `flutter build web` vuelven a morir con `231`. Ver la revalidación de la cabecera.
- **Estado: cerrado.** La causa citada antes (`CreateFile failed 231` al lanzar el hijo) **no se reproduce** en esta sesión.
- **Medición:** `flutter.bat test --no-pub` ejecuta la suite completa (924+ casos observados en una corrida, `+N` creciente) sin el `231`; `flutter build web --release` terminó en `√ Built build\web` (157 s). El `231` era una limitación **del sandbox de la sesión anterior**, no del proyecto ni de una variable ausente.
- **Cómo usarlo ahora:** `flutter test --no-pub` y `flutter build web --release --dart-define-from-file=.env.json` son la vía normal. `node devops/analizar-dart.mjs` sigue siendo útil para tipos/lints y como contraste independiente.
- **Criterio de cierre:** cumplido — la suite ejecuta y su resultado se registra. Si el `231` reapareciera, **medirlo otra vez** antes de citarlo.

### Correo externo opcional — Resend HTTP 401
- **Tarea:** verificar entrega real sólo para notificaciones complementarias que el producto decida mantener por correo.
- **Estado:** bloqueo externo (HTTP 401), separado de invitación/activación y recuperación internas.
- **Trabajo permitido:** revisar errores, configuración sanitizada y no exposición de secretos; continuar con el resto del sistema. No reparar Resend como requisito para activar o recuperar cuentas.
- **Bloqueo humano sólo si:** el propietario debe renovar una clave, verificar dominio o completar DNS/autoridad externa.
- **Criterio de cierre:** si el correo opcional sigue en alcance, envío autorizado aceptado y recepción comprobada en buzón de prueba; nunca fingir entrega.

## Reglas de mantenimiento

- No duplicar aquí la deuda completa del producto: el plan de cierre y el TODO son la matriz canónica.
- Cada bloqueo debe incluir evidencia, acción siguiente concreta, criterio de cierre y fecha de última revisión.
- Cuando se resuelva, moverlo a Resueltos o eliminarlo de Abiertos conservando un checkpoint histórico.
- Nunca guardar tokens, contraseñas, JWT, cookies, claves API ni PII innecesaria.
- Un bloqueo no autoriza a desactivar RLS, evadir MFA/CAPTCHA, falsificar pruebas ni detener tareas independientes.


### E2E real de invitación/recuperación de identidad — RESUELTO (2026-10-09, sesión 2)
- **Estado: cerrado.** Se ejecutaron ambos recorridos contra el motor real, con cuentas desechables y purga verificada:
  - `supabase/humo-invitaciones.mjs --confirmar` → **34 OK / 0 fallos**, residuo 0/0/0.
  - `supabase/humo-recuperacion.mjs --confirmar` → **27 OK / 0 fallos**, residuo 0/0/0.
- **Cobertura:** invitación→activación→login, token de un solo uso, revocar, renovar (la vieja deja de activar), recuperación→contraseña nueva→login, rechazo de la contraseña anterior, **cierre de la sesión previa** (el refresh token viejo muere), código no reutilizable y respuesta indistinguible para códigos inválidos.
- **Salvaguardas respetadas:** no se cambió la contraseña de ninguna cuenta real; todo ocurre sobre cuentas `humo-*@ejemplo.invalid` creadas y borradas por el propio script; no hubo commit, push ni despliegue.


---

# CHECKPOINT — 2026-10-09 · C7 estabilizado y ciclo E2E completo

## Corrección
- [x] En `e2e/tests/aula_virtual_ciclo.spec.ts`, C7 dejó de buscar el texto inexistente `LIBRO DE CALIFICACIONES` y ahora espera el título real `Calificaciones`. La prueba valida además que las acciones del libro estén montadas y que aparezca la fila del estudiante.
- [x] La corrección cambia la aserción de la prueba, no el producto. No se alteró la lógica de calificación.

## Ejecución real
- [x] Bundle local fresco ya generado en esta sesión por `flutter build web --release --dart-define-from-file=.env.json`.
- [x] `E2E_PERMITIR_CICLO_MUTANTE=1 npx playwright test tests/aula_virtual_ciclo.spec.ts` desde `e2e/`: **7/7 PASS, 0 flaky, exit 0**, duración aproximada 2,6 minutos.
- [x] La ruta real docente → publicación → entrega del aprendiz → libro `Calificaciones` → nota 18 → devolución → visualización de la nota por el aprendiz quedó validada.
- [x] Limpieza acotada ejecutada con `node supabase/limpiar-ciclo-aula.mjs --confirmar --desde "2026-10-09T17:35:07.532Z"`: borró sólo la tarea de esta corrida.
- [x] Limpieza comprobada: tareas **77 → 76**, entregas **228 → 225**, **0 huérfanas**; línea base restaurada.

## Estado del repositorio
- El cambio de la prueba y estos checkpoints permanecen locales.
- No se hizo commit, push ni despliegue.
- No se ejecutaron las sondas `_*.spec.ts` ni el ciclo contra producción.

## Siguiente paso
Continuar con la puerta de performance: medir cargas y operaciones representativas por rol, registrar métricas repetibles y definir el gate de aceptación antes de iniciar el barrido responsive. La suite mutante debe seguir excluida de la regresión predeterminada salvo que se prepare un entorno aislado dedicado.
