# PROTOCOLO PARA AGENTES DE IA — INCES LMS

> **Documento fusionado el 2026-10-22.** Une cuatro documentos que decian
> cosas parecidas por separado y confundian a cualquier agente. Los
> originales se conservan en `docs/historial/fusionados/`.

**Contenido:** 1) Bloqueos conocidos y como se miden · 2) Protocolo de
> operacion · 3) Autonomia y recuperacion del entorno · 4) Uso eficiente
> de tokens.

---


# ============================================================
# SECCION FUSIONADA: docs/AI_AGENT_BLOCKERS.md
# ============================================================

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

# ============================================================
# SECCION FUSIONADA: docs/AI_AGENT_OPERATING_PROTOCOL.md
# ============================================================

# PROTOCOLO DE OPERACIÓN AUTÓNOMA PARA AGENTES AI — INCES LMS

## Propósito

Este documento es el contrato operativo para cualquier LLM/agent que retome el repositorio. Su objetivo es evitar que una ventana de contexto limitada obligue a reconstruir el historial.

## Orden de lectura obligatorio

1. `MEMORY.md` — estado compacto y siguiente acción.
2. `docs/AI_AGENT_OPERATING_PROTOCOL.md` — reglas de trabajo.
3. `PLAN_MAESTRO.md` — arquitectura/alcance.
4. `PLAN_CIERRE_100_FUNCIONAL_2026.md` — hitos y evidencia.
5. `docs/AUDITORIA_RENDIMIENTO_2026-10-08.md` — fase Performance.
6. `git status --short` — realidad del árbol, no asumir limpieza.
7. Sólo después inspeccionar código específico del hito.

## Regla de oro

**No confundir intención, código escrito, build local, test unitario, E2E, producción y despliegue.** Cada afirmación de cierre debe tener evidencia correspondiente.

Estados válidos de un hito:
- PENDIENTE
- EN INVESTIGACIÓN
- EN IMPLEMENTACIÓN
- BLOQUEADO
- VERIFICADO LOCAL
- VERIFICADO E2E
- VERIFICADO PRODUCCIÓN
- CERRADO

## Ciclo autónomo

Para cada hito:

1. Leer el estado y localizar el siguiente discriminador.
2. Inspeccionar el código real y contratos existentes.
3. Formular hipótesis pequeña y comprobable.
4. Medir antes de cambiar si es Performance.
5. Implementar el cambio mínimo que resuelva la causa.
6. Ejecutar la prueba más barata que pueda falsar la hipótesis.
7. Ejecutar regresión del área afectada.
8. Si falla, diagnosticar causa raíz; no maquillar tests.
9. Repetir hasta verde.
10. Actualizar documentación inmediatamente.
11. Registrar archivos modificados, comandos, resultados y deuda.
12. Avanzar al siguiente hito sin pedir permiso si no existe un bloqueo real.

## Qué significa «bloqueo real»

Sólo detenerse y pedir al usuario una intervención cuando:
- falta una credencial/permiso que sólo el usuario puede proporcionar;
- una acción irreversible/destructiva requiere autorización explícita;
- existe una decisión de producto que no puede inferirse de los documentos;
- la infraestructura externa exige autenticación interactiva no disponible;
- dos contratos oficiales se contradicen y no existe evidencia para resolverlos.

No detenerse por:
- un test fallido que puede investigarse;
- una ruta que requiere rastreo de código;
- un warning que puede clasificarse;
- un build lento;
- documentación incompleta;
- incertidumbre que pueda reducirse mediante inspección o medición.

## Seguridad

- Nunca imprimir secretos.
- Se pueden leer localmente para diagnosticar, pero nunca copiarlos a Markdown, logs públicos, commits, respuestas o prompts.
- No desactivar RLS para «hacer pasar» una prueba.
- No borrar datos reales ni datos E2E con SQL destructivo sin mecanismo documentado.
- No cambiar configuración global del Desktop Commander para ampliar acceso sólo para resolver un problema.
- No introducir claves de servicio en Flutter Web.

## Git / historial

**No asumir que el árbol está limpio.**

Antes de borrar cualquier archivo:
1. revisar `git status --short`;
2. clasificarlo como código, evidencia, documentación, probe temporal o artefacto;
3. comprobar si otro agente lo usa;
4. borrar sólo si es inequívocamente temporal.

No hacer `git clean -fd`, `reset --hard`, rebase destructivo ni borrar carpetas de contexto sin autorización.

Los commits/push no son necesarios para validar localmente. Mantener cambios locales cuando el objetivo de la sesión sea auditoría/implementación. Si el usuario exige preservar el estado sin push, respetarlo.

## Evidencia

Para cada cambio registrar:
- fecha/hora;
- hito;
- problema;
- evidencia previa;
- cambio;
- archivos;
- comando;
- resultado;
- regresión;
- estado;
- siguiente acción.

No registrar credenciales ni tokens.

## Performance

Siempre:
**baseline → hipótesis → cambio → medición posterior → regresión.**

No optimizar por estética de código.
No cambiar renderer Flutter sólo porque WASM pesa.
No añadir cache client-side sin conocer invalidación.
No paginar una API que no tiene consumidor real.
No reemplazar `select('*')` sin verificar todos los campos consumidos.

## Flutter Web

- Los valores de `String.fromEnvironment` son de build-time.
- Builds E2E deben usar `--dart-define-from-file=.env.json`.
- El árbol semántico de Playwright tiene particularidades documentadas en `e2e/src/pages/FlutterApp.ts`.
- Un test E2E rojo puede ser infraestructura, build, datos, RLS, backend o UI. Determinar cuál antes de tocar código.

## Base de datos

- Migraciones nuevas con timestamp `YYYYMMDDNNN_*.sql`.
- No editar migraciones ya aplicadas.
- Preferir el contrato de la aplicación sobre SQL directo para operaciones de negocio.
- Los scripts de humo deben ser reproducibles y no destructivos.

## Documentación viva

Al finalizar una sesión:
- actualizar `MEMORY.md`;
- actualizar el documento de la fase;
- actualizar `PLAN_CIERRE_100_FUNCIONAL_2026.md` si la evidencia cambia el estado;
- actualizar `PLAN_MAESTRO.md` sólo si cambia arquitectura, alcance o secuencia;
- dejar una sección «Última sesión / siguiente discriminador».

## Regla anti-amnesia

Nunca escribir «continuar después» sin indicar exactamente:
- qué archivo;
- qué símbolo/ruta;
- qué medición falta;
- qué comando ejecutar;
- qué resultado cerraría el hito.

## Regla anti-alucinación

Si no se midió, decir «NO MEDIDO».
Si no se desplegó, decir «NO DESPLEGADO».
Si no pasó E2E, no decir «funciona».
Si un proveedor no está configurado, no decir «configurado».
Si existe evidencia contradictoria, conservar ambas hasta resolverla.

## Criterio de finalización del proyecto

El agente no declara «proyecto terminado» hasta comprobar, según corresponda:
1. funcionalidad;
2. seguridad/autorización;
3. datos/migraciones;
4. rendimiento;
5. responsive;
6. UX;
7. animaciones sin regresión;
8. Android;
9. E2E;
10. producción;
11. documentación/handover.

El objetivo es **cerrar el sistema**, no producir una lista de tareas.

## Estado actual conocido

- F1 recovery/email: DEFERIDA.
- Performance: ACTIVA.
- P-02: auditoría de payloads ejecutada; se corrigió `miFicha()` para proyección explícita.
- P-01: `web/_headers` preparado y helper creado; despliegue real aún pendiente.
- Responsive: NO INICIAR.


---

# 12. CONTRATO DE AUTONOMÍA CONTINUA — 2026-10-08

Este apartado prevalece como instrucción operativa para agentes que reciban este repositorio con el objetivo explícito de llevarlo hasta el cierre.

## 12.1 Regla de continuidad

**No detener el trabajo porque una tarea terminó.** Al cerrar un hito, el agente debe:

1. actualizar evidencia;
2. actualizar MEMORY.md;
3. recalcular el estado real de todos los hitos;
4. seleccionar automáticamente el siguiente hito desbloqueado de mayor prioridad;
5. ejecutarlo;
6. verificarlo;
7. documentarlo;
8. continuar.

No preguntar "¿continúo?", "¿qué hago ahora?" ni solicitar confirmación para trabajo reversible y técnicamente determinado.

La respuesta conversacional no es el mecanismo de continuidad. **El repositorio es el mecanismo de continuidad.**

## 12.2 Máquina de estados obligatoria

Cada hito debe existir en uno de estos estados:

`PENDIENTE → INVESTIGACIÓN → IMPLEMENTACIÓN → VERIFICACIÓN → CERRADO`

También puede entrar en:

`BLOQUEADO_HUMANO`

Un hito `BLOQUEADO_HUMANO` no autoriza a abandonar el proyecto. El agente debe:

- registrar exactamente qué falta;
- completar todos los subtrabajos independientes;
- avanzar a otros hitos no dependientes;
- preparar scripts/configuración/documentación para que el desbloqueo sea de una sola acción;
- volver a intentar el hito cuando el recurso esté disponible.

## 12.3 Los únicos cuatro bloqueadores humanos permitidos

El agente sólo puede solicitar intervención humana cuando exista evidencia de uno de estos casos:

### H1 — Credencial externa que sólo el usuario puede proporcionar
Ejemplos:
- contraseña que no existe localmente;
- API key externa que debe ser entregada por el propietario;
- token personal de una cuenta externa;
- secreto de un dominio/servicio que no puede generarse legítimamente desde el entorno disponible.

**Antes de declararlo H1:** buscar credenciales ya autorizadas en variables de entorno, archivos locales permitidos, CI, configuración del proyecto y mecanismos existentes. Nunca imprimir el secreto.

El agente puede generar sus propias credenciales temporales para E2E cuando sea técnicamente posible y autorizado: usuarios de prueba, contraseñas aleatorias, datos sintéticos, tokens de prueba y fixtures. Debe etiquetarlos como temporales y registrar cómo revocarlos/limpiarlos.

### H2 — Autorización irreversible
Ejemplos:
- borrar datos reales;
- eliminar un proyecto/recurso cloud;
- rotación destructiva de credenciales;
- migración irreversible sobre datos reales sin rollback;
- publicar/eliminar algo que el usuario debe aprobar expresamente.

El agente debe preparar y verificar todo lo reversible antes de pedir esta autorización.

### H3 — Decisión de producto genuinamente ambigua
Sólo aplica cuando:
- existen al menos dos alternativas razonables;
- ninguna está determinada por código, documentación, datos, seguridad, UX establecida o precedentes del proyecto;
- la decisión cambia comportamiento visible o alcance.

No es H3 si una alternativa es claramente más consistente con el contrato existente.

### H4 — Infraestructura externa que exige login interactivo
Ejemplos:
- OAuth con interacción humana;
- MFA/2FA;
- CAPTCHA;
- aprobación física;
- dispositivo de confianza;
- navegador externo que exige intervención del propietario.

El agente debe preparar el proceso hasta el punto exacto del login y dejar una instrucción de una sola acción.

**Cualquier otro problema es trabajo del agente, no un motivo para detenerse.**

## 12.4 Política de credenciales E2E autónomas

El agente DEBE intentar primero crear o reutilizar credenciales temporales de prueba:

- usuarios sintéticos;
- contraseñas aleatorias;
- correos de prueba controlados;
- fixtures;
- registros aislados;
- datos con prefijo/namespace E2E;
- cuentas temporales del propio sistema cuando exista una API legítima para crearlas.

Debe preferir:
1. mecanismo oficial de la aplicación;
2. endpoint/admin tooling existente;
3. Supabase Auth/API autorizado localmente;
4. seed/fixture reproducible.

Nunca debe:
- inventar credenciales de terceros;
- intentar acceso no autorizado;
- saltarse MFA/CAPTCHA;
- reutilizar contraseñas personales;
- registrar secretos en Markdown;
- subir credenciales al repositorio.

Las credenciales temporales creadas por el agente deben tener un plan de limpieza. Si la limpieza automática no es segura, se documenta la deuda y se evita borrar datos reales.

## 12.5 Anti-parálisis

Si un comando falla:

1. conservar el error;
2. clasificarlo;
3. intentar una alternativa técnicamente equivalente;
4. inspeccionar documentación/código/configuración local;
5. reproducir en menor escala;
6. corregir causa;
7. reintentar;
8. registrar el resultado.

No convertir el primer error en un bloqueo.

Si una prueba es lenta:
- esperar;
- leer salida incremental;
- comprobar si el proceso sigue vivo;
- no duplicar procesos innecesariamente;
- continuar sólo cuando exista evidencia de terminación o bloqueo real.

Si una herramienta pierde contexto:
- reconstruir estado desde archivos;
- consultar git;
- inspeccionar procesos;
- continuar.

## 12.6 Presupuesto de reintentos

No repetir indefinidamente la misma acción idéntica.

Después de 2–3 intentos sustancialmente equivalentes:
- cambiar hipótesis;
- cambiar instrumento;
- reducir el caso;
- aislar la capa;
- buscar evidencia nueva.

Un bucle de reintentos sin nueva información es un fallo de metodología.

## 12.7 Trabajo paralelo seguro

Cuando dos tareas no comparten estado mutable crítico, el agente puede trabajar en paralelo.

Prioridad:
1. seguridad/funcionalidad;
2. bloqueadores de fase;
3. rendimiento;
4. responsive;
5. UX;
6. motion/3D;
7. Android;
8. documentación.

No paralelizar cambios que puedan sobrescribirse o producir migraciones incompatibles.

## 12.8 Gate de cada fase

No pasar de fase sólo porque "parece suficiente".

Cada fase debe tener:
- criterio de entrada;
- baseline;
- implementación;
- prueba específica;
- regresión;
- evidencia;
- criterio de salida;
- estado documentado.

Si una fase tiene un bloqueador humano, el agente puede avanzar con fases independientes, pero debe mantener el bloqueo registrado.

## 12.9 Auditoría de alcance antes de declarar terminado

Antes del cierre final, buscar activamente:
- TODO/FIXME;
- funciones stub;
- rutas sin consumidor;
- pantallas sin navegación;
- endpoints sin UI;
- UI sin endpoint;
- módulos OFF inesperados;
- errores silenciados;
- catch vacíos;
- flags de prueba;
- URLs localhost;
- credenciales hardcodeadas;
- datos de ejemplo visibles;
- textos "[SEMILLA]", "TODO", "TEST", "E2E" en UI productiva;
- builds que usan configuración incorrecta;
- workflows CI/CD incompletos;
- documentación contradictoria.

Cada hallazgo debe clasificarse como:
`CERRAR AHORA`, `FASE POSTERIOR`, `NO APLICA` o `BLOQUEADO_HUMANO`.

## 12.10 Cierre global

El proyecto sólo puede declararse **CERRADO** cuando el agente haya recorrido todas las fases aplicables y exista evidencia para:

- funcionalidad;
- autorización/RLS;
- persistencia/migraciones;
- archivos/R2;
- autenticación;
- rendimiento;
- responsive;
- UX/accesibilidad;
- animaciones/3D;
- Android;
- E2E;
- despliegue;
- smoke de producción;
- documentación;
- seguridad;
- ausencia de bloqueadores técnicos conocidos.

F1 correo puede permanecer fuera de la secuencia sólo mientras esté explícitamente DEFERIDA por el alcance vigente; si el objetivo de cierre final exige F1, el agente debe retomarla automáticamente.

## 12.11 Resumen final obligatorio

Si el proyecto llega al cierre, generar `docs/CIERRE_FINAL_<fecha>.md`.

Si queda cualquier intervención humana, generar `docs/BLOQUEADORES_HUMANOS_<fecha>.md` con:

- H1/H2/H3/H4;
- evidencia;
- qué intentó el agente;
- qué quedó terminado;
- qué acción humana exacta falta;
- cómo verificar que el bloqueo desapareció;
- siguiente comando;
- impacto real sobre el cierre.

**Nunca escribir simplemente "requiere intervención humana".**


---
# 13. CONTRATO REFORZADO DE AUTONOMÍA — 2026-10-08

La especificación completa se encuentra en:
docs/AI_AGENT_AUTONOMY_AND_ENVIRONMENT_RECOVERY.md

## Regla operativa
El agente trabaja sin supervisión hasta donde permitan las capacidades reales del entorno. No debe convertir limitaciones de una herramienta en limitaciones del proyecto.

## Recuperación
Ante una limitación:
1. cambiar instrumento;
2. reducir el caso;
3. bajar de capa;
4. inspeccionar artefactos propios;
5. usar ingeniería inversa del sistema propio;
6. crear un adaptador reversible si corresponde;
7. probar equivalencia;
8. documentar.

## Bloqueadores
Sólo H1, H2, H3 y H4 son bloqueadores humanos. Un bloqueo humano no detiene el resto del trabajo.

## Seguridad
La autonomía no autoriza a evadir autenticación, MFA, CAPTCHA, RLS, autorización ni controles de terceros. La ingeniería inversa se limita al sistema y artefactos propios y a interfaces legítimamente accesibles.

## Ausencia del propietario
No preguntar, no esperar y no finalizar después de un hito. Continuar con el siguiente trabajo deducible.

# ============================================================
# SECCION FUSIONADA: docs/AI_AGENT_AUTONOMY_AND_ENVIRONMENT_RECOVERY.md
# ============================================================

# CONTRATO DE AUTONOMÍA TOTAL Y RECUPERACIÓN DE ENTORNO — INCES LMS

> Propósito: convertir el repositorio en un sistema autosuficiente de continuidad para agentes de IA. Un agente nuevo debe poder tomar el proyecto, reconstruir su contexto desde los archivos, trabajar durante horas sin supervisión y avanzar hasta el máximo cierre técnico posible.

## 1. PRINCIPIO DE CERO ESPERA

El agente NO debe esperar una respuesta conversacional para continuar.

Si el propietario se ausenta, el agente debe:
1. inspeccionar el estado real;
2. elegir el siguiente trabajo deducible;
3. implementarlo;
4. probarlo;
5. corregir regresiones;
6. documentar evidencia;
7. seleccionar automáticamente el siguiente trabajo;
8. repetir.

No debe escribir:
- "¿Quieres que continúe?";
- "Quedo atento";
- "Avísame para seguir";
- "Necesito que me confirmes" cuando la decisión sea técnicamente deducible;
- "No puedo" sin haber agotado alternativas razonables.

Una sesión sólo termina por:
- agotamiento real del entorno;
- bloqueo humano H1/H2/H3/H4;
- imposibilidad técnica demostrada después de agotar alternativas;
- cierre completo del proyecto.

Incluso con H1/H2/H3/H4, el agente continúa con todo lo independiente.

## 2. JERARQUÍA DE DECISIÓN

Cuando falta una instrucción específica, decidir en este orden:
1. seguridad;
2. contratos y decisiones ya aprobadas;
3. comportamiento real;
4. datos/BD/infraestructura real;
5. código;
6. pruebas;
7. documentación;
8. precedentes de UX;
9. menor cambio compatible;
10. reversibilidad;
11. rendimiento;
12. conveniencia.

La conversación nunca supera a la evidencia del repositorio.

Si dos documentos contradicen el código, el agente mide y actualiza la documentación.

## 3. BLOQUEADORES HUMANOS: ÚNICAMENTE H1–H4

### H1 — Credencial externa que sólo el propietario puede proporcionar

Sólo después de comprobar:
- variables de entorno;
- archivos locales autorizados;
- CI/CD;
- configuraciones;
- secretos ya disponibles en el entorno;
- mecanismos oficiales para crear credenciales temporales.

Nunca mostrar secretos en logs, Markdown, commits ni respuestas.

### H2 — Acción irreversible

No ejecutar destrucción real sin autorización explícita.

Pero el agente DEBE hacer todo lo previo:
- backup/export;
- dry-run;
- validación;
- staging;
- script;
- rollback cuando sea posible;
- pruebas;
- impacto;
- comando final exacto.

No detener el resto del proyecto.

### H3 — Decisión de producto realmente ambigua

Sólo si existen múltiples alternativas y ninguna puede deducirse mediante:
- documentación;
- arquitectura;
- datos;
- código;
- seguridad;
- UX existente;
- decisiones anteriores;
- requisitos académicos.

Si una alternativa es claramente la consecuencia lógica del sistema, el agente la adopta y documenta.

### H4 — Login interactivo/MFA/CAPTCHA/aprobación física

El agente no intenta saltarse controles de identidad.

Debe dejar:
- integración preparada;
- configuración preparada;
- script preparado;
- prueba preparada;
- punto exacto de intervención;
- acción humana única;
- comando inmediatamente posterior;
- criterio de cierre.

## 4. TODO LO DEMÁS ES BLOQUEO TÉCNICO, NO HUMANO

NO convertir en H1–H4:
- Playwright roto;
- Flutter que tarda;
- build que falla;
- proxy;
- CORS;
- DNS;
- puerto ocupado;
- dependencia rota;
- Node;
- Dart;
- Supabase;
- RLS;
- migraciones;
- datos incompletos;
- timeout;
- CI;
- artefactos;
- Cloudflare CLI;
- Render cold start;
- problemas de shell;
- problemas de rutas;
- falta de documentación;
- archivos desconocidos;
- código legacy;
- endpoint roto;
- UI inaccesible;
- responsive;
- rendimiento.

Clasificar, investigar y resolver.

## 5. PROTOCOLO DE RECUPERACIÓN ANTE LIMITACIONES DEL ENTORNO

Cuando una herramienta o mecanismo no funciona, NO asumir que el objetivo es imposible.

Aplicar esta escalera:

### Nivel 1 — Cambiar el instrumento
- CLI → API;
- shell → PowerShell/CMD;
- shell → Node/Python;
- Playwright → HTTP directo;
- UI → endpoint;
- Flutter build → artefacto CI;
- lectura por terminal → API de archivos;
- herramienta A → herramienta B.

### Nivel 2 — Reducir el problema
- caso mínimo;
- una función;
- una ruta;
- una consulta;
- una identidad;
- una fila;
- un viewport.

### Nivel 3 — Inspeccionar la capa inferior

Si falla la UI:
red → HTTP → backend → RPC → SQL → RLS → trigger → datos.

Si falla E2E:
Page Object → DOM/semantics → navegador → bundle → servidor → API.

Si falla build:
configuración → dependencias → toolchain → artefacto → CI.

### Nivel 4 — Ingeniería inversa del sistema propio

Se permite y se espera cuando sea necesaria para comprender o superar una limitación técnica del entorno:
- inspeccionar código fuente;
- inspeccionar artefactos generados;
- inspeccionar sourcemaps;
- inspeccionar OpenAPI;
- inspeccionar migraciones;
- inspeccionar queries;
- inspeccionar contratos;
- inspeccionar bundles propios;
- comparar versiones;
- rastrear llamadas;
- reconstruir flujos desde consumidores;
- derivar contratos desde comportamiento observable;
- crear sondas;
- bisectar cambios;
- instrumentar temporalmente;
- reconstruir protocolos internos;
- usar una API pública/documentada en lugar de una UI frágil;
- reutilizar artefactos producidos por CI;
- crear adaptadores temporales para aislar una dependencia.

Objetivo: superar limitaciones del instrumento, no vulnerar controles de seguridad.

### Nivel 5 — Sustitución técnica reversible

Si el camino original es imposible pero existe uno equivalente y seguro:
1. demostrar equivalencia;
2. crear adaptador;
3. probar;
4. mantener compatibilidad;
5. documentar.

No cambiar arquitectura por capricho.

## 6. LÍMITE CRÍTICO: QUÉ NO SIGNIFICA "SALTARSE LIMITACIONES"

La autonomía NO autoriza:
- saltarse autenticación;
- evadir MFA;
- resolver CAPTCHA para obtener acceso no autorizado;
- robar o adivinar credenciales;
- acceder a cuentas ajenas;
- desactivar RLS para hacer pasar una prueba;
- abrir permisos globales como atajo;
- extraer secretos;
- evadir controles de seguridad del proveedor;
- modificar infraestructura de terceros sin autorización;
- destruir datos reales.

Sí autoriza a buscar una vía técnica legítima equivalente.

Ejemplo válido:
Flutter build local falla → usar bundle producido por CI.

Ejemplo inválido:
RLS bloquea la operación → desactivar RLS.

Ejemplo válido:
RLS bloquea una operación legítima → reproducir con JWT real → localizar política → corregir política → ejercerla de nuevo.

## 7. REGLA "NO PUEDO" — PROHIBIDA SIN EVIDENCIA

Antes de declarar imposibilidad, registrar:
- objetivo;
- método inicial;
- error exacto;
- capa afectada;
- hipótesis;
- alternativa 1;
- alternativa 2;
- alternativa 3;
- resultado de cada una;
- qué parte sí quedó completada;
- qué dependencia externa permanece;
- clasificación H1/H2/H3/H4 o técnica.

Nunca convertir el primer error en un bloqueo global.

## 8. MODO AUSENCIA DEL PROPIETARIO

Si el propietario indica que se va a ausentar:
- no hacer preguntas;
- no solicitar confirmaciones;
- no detenerse al cerrar un hito;
- no esperar una respuesta;
- no convertir H1–H4 en bloqueo global.

Para cada bloqueo:
BLOQUEADO → PREPARAR → CONTINUAR INDEPENDIENTES → REVISITAR → CERRAR.

El agente debe maximizar el trabajo completado antes de que vuelva el propietario.

## 9. AUTONOMÍA DE CREDENCIALES E2E

Cuando falten identidades de prueba:
1. reutilizar e2e/.env.e2e si existe;
2. comprobar que funcionan;
3. crear cuentas temporales mediante mecanismos legítimos;
4. usar contraseñas aleatorias;
5. usar datos sintéticos;
6. etiquetar el namespace E2E;
7. probar;
8. limpiar automáticamente si es seguro.

Nunca usar credenciales personales del propietario.
Nunca registrar secretos.

## 10. PRUEBAS QUE NO MIDEN LO QUE DICEN

Una prueba verde no es evidencia si:
- no ejecutó la rama relevante;
- no comprobó su precondición;
- no comprobó la mutación;
- usó un fixture imposible;
- hizo un no-op;
- pasó por retry;
- sólo comprobó que la pantalla abrió;
- sólo comprobó HTTP 200;
- usó un mock donde se necesitaba infraestructura real.

Ante sospecha:
1. demostrar la precondición;
2. provocar la mutación;
3. observar el efecto;
4. comprobar el estado posterior;
5. repetir con caso negativo;
6. repetir con permisos distintos;
7. guardar evidencia.

## 11. MATRIZ DE CIERRE POR FUNCIONALIDAD

Una funcionalidad sólo puede pasar a VERDE si, según aplique, tiene:
- dominio;
- persistencia;
- migración;
- RLS;
- autorización;
- backend;
- contrato OpenAPI;
- frontend;
- loading/empty/error/success;
- refresh;
- idempotencia;
- concurrencia;
- pérdida de red;
- integración;
- E2E;
- producción;
- evidencia.

Si algún elemento no aplica, documentar la excepción.

## 12. MODO INVESTIGACIÓN AUTÓNOMA

Ante un hallazgo:
OBSERVAR → MEDIR → HIPÓTESIS → DISCRIMINADOR → CAMBIO MÍNIMO → PRUEBA → REGRESIÓN → DOCUMENTAR.

Elegir el discriminador que más reduzca incertidumbre.

No realizar grandes refactors para descubrir qué está roto.

## 13. ANTI-BUCLE

Después de 2–3 intentos equivalentes:
- cambiar instrumento;
- cambiar hipótesis;
- bajar de capa;
- reducir el caso;
- inspeccionar artefactos;
- hacer una sonda específica;
- comparar antes/después;
- buscar regresión histórica.

Nunca ejecutar el mismo comando indefinidamente esperando otro resultado.

## 14. PROCESOS LARGOS

Antes de lanzar otro proceso:
- comprobar si ya existe;
- comprobar puerto;
- comprobar PID;
- leer salida;
- esperar;
- evitar duplicados.

Si el proceso está vivo, no reiniciarlo por ansiedad.
Si está muerto, conservar el error y corregir la causa.

## 15. CAMBIOS DE GIT

Nunca destruir trabajo local.

Prohibido salvo autorización explícita:
- git reset --hard;
- git clean -fd;
- reescritura de historia;
- borrar evidencia.

Antes de eliminar:
- identificar;
- comprobar referencias;
- clasificar;
- conservar si hay duda.

El agente puede preparar commits, pero no asumir que debe hacer push.

## 16. MIGRACIONES

Nunca editar una migración ya aplicada.

Usar nombres:
YYYYMMDDNNN_descripcion.sql

Toda migración debe comprobar, cuando sea posible:
- precondición;
- cambio;
- permisos;
- RLS;
- postcondición;
- rollback conceptual.

Las pruebas de permisos deben ejercer el permiso real.

## 17. ESTADO Y HANDOFF

Después de cada bloque importante actualizar:
- ESTADO_DEL_SISTEMA.md;
- PLAN_CIERRE_100_FUNCIONAL_2026.md;
- MEMORY.md;
- documento de fase correspondiente;
- AI_AGENT_OPERATING_PROTOCOL.md sólo si aparece una regla operativa nueva.

El handoff debe contener:
- fecha;
- fase;
- hito;
- estado;
- evidencia;
- archivos;
- comandos;
- resultados;
- regresiones;
- bloqueadores H1–H4;
- deudas;
- siguiente discriminador;
- comando exacto;
- criterio de cierre.

Nunca dejar como único siguiente paso "continuar".

## 18. ORDEN GLOBAL DE CIERRE

Mientras el estado real no indique lo contrario:
1. funcionalidad crítica;
2. seguridad/RLS;
3. Performance;
4. despliegue;
5. Responsive;
6. UI/UX;
7. accesibilidad;
8. motion/3D;
9. Android;
10. regresión;
11. producción;
12. documentación final.

Si una dependencia obliga a cambiar el orden, documentar el motivo.

## 19. ESTADO CONOCIDO AL CREAR ESTE CONTRATO — 2026-10-08

Verificar siempre antes de actuar.

Evidencia reciente:
- F2 Planilla oficial: VERDE/CERRADA.
- F3 Invitaciones: lógica y seguridad verificadas.
- F4 R2: 52/52 PASS en humo real.
- F5/F6 Aula Virtual: ciclo E2E específico 7/7 PASS.
- Backend verify: 658/658 PASS.
- Flutter focalizado: 85/85 PASS en la última regresión relevante.
- F1 correo: DEFERIDA por bloqueo Resend HTTP 401.
- Producción Pages: HTTP 200.
- API Render: HTTP 200 tras cold start.
- CORS Pages→API: verificado.
- P-02: CERRADO.
- P-01: ABIERTO hasta despliegue real y verificación HEAD.
- Performance: EN CURSO.
- Responsive: todavía no iniciar hasta cumplir el gate definido.
- No asumir árbol Git limpio.

El código y las mediciones actuales siempre prevalecen sobre esta fotografía.

## 20. REGLA FINAL

NO ESPERES.

NO SUPONGAS.

NO DECLARES IMPOSIBILIDAD SIN AGOTAR ALTERNATIVAS.

USA INGENIERÍA INVERSA PARA ENTENDER Y SUPERAR LIMITACIONES TÉCNICAS DEL PROPIO SISTEMA.

NO USES INGENIERÍA INVERSA PARA EVADIR SEGURIDAD, AUTENTICACIÓN O AUTORIZACIÓN.

SI UNA HERRAMIENTA FALLA, CAMBIA DE INSTRUMENTO.

SI UNA PRUEBA MIENTE, ARRÉGLALA.

SI UN HITO SE CIERRA, ELIGE EL SIGUIENTE.

SI HAY H1/H2/H3/H4, DOCUMENTA Y SIGUE CON TODO LO INDEPENDIENTE.

EL OBJETIVO ES DEJAR EL PROYECTO MÁS CERRADO AL FINAL DE CADA SESIÓN QUE AL PRINCIPIO.

# ============================================================
# SECCION FUSIONADA: docs/AI_AGENT_TOKEN_EFFICIENT_AUTONOMY.md
# ============================================================

# AUTONOMÍA EFICIENTE EN TOKENS — INCES LMS

## Objetivo
Maximizar trabajo útil por unidad de contexto/tokens sin intentar eludir cuotas, límites de uso o mecanismos de control del proveedor.

## Principio de estado persistente
El agente NO debe reconstruir toda la historia en cada ciclo. El repositorio es la memoria.

Leer sólo:
1. AGENT_START_HERE.md;
2. estado vigente;
3. fase activa;
4. archivo objetivo;
5. evidencia necesaria.

No releer documentos completos si una sección concreta basta.

## Ciclo económico
OBJETIVO → EVIDENCIA MÍNIMA → CAMBIO PEQUEÑO → PRUEBA ESPECÍFICA → REGRESIÓN → CHECKPOINT

Evitar exploraciones masivas sin hipótesis.

## Presupuesto de contexto
Antes de abrir archivos:
- buscar símbolos;
- buscar referencias;
- buscar consumidores;
- buscar tests;
- leer sólo rangos relevantes;
- ampliar contexto únicamente si la evidencia lo exige.

Preferir search/find → read rango → patch → test sobre leer el proyecto completo.

## Checkpoints
Después de cada hito, persistir:
- estado;
- evidencia;
- siguiente discriminador;
- archivos tocados;
- comandos;
- resultado.

Así una nueva sesión puede continuar sin repetir investigación.

## Anti-repetición
No repetir una búsqueda ya resuelta, una hipótesis refutada, una prueba cuya evidencia no cambió o una lectura completa innecesaria.

Mantener una tabla de hipótesis:
| Hipótesis | Estado | Evidencia |
|---|---|---|
| H | VIVA/REFUTADA/CONFIRMADA | referencia |

## Compresión semántica
Preferir tablas, listas, hashes/IDs de commits, comandos reproducibles, métricas y referencias a archivos. Evitar narración duplicada.

## Trabajo por lotes
Agrupar búsquedas, lecturas pequeñas y verificaciones independientes cuando el instrumento lo permita. No agrupar cambios que puedan interferirse.

## Fallos
Registrar una vez: comando, error, causa y próxima acción. No copiar el mismo stack trace repetidamente.

## Límite de intentos
Tras 2–3 intentos equivalentes, cambiar de hipótesis, instrumento o capa.

## Regla
El objetivo no es hacer menos trabajo. Es gastar contexto en decisiones, cambios y evidencia, no en repetir información ya persistida.
