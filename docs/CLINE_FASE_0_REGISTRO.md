# REGISTRO CLINE — FASE 0 (AUDITORIA Y BLOQUEOS)

> **Documento fusionado el 2026-10-22.** Los tres documentos de la Fase 0
> de Cline en un solo registro. Originales en `docs/historial/fusionados/`.


# ============================================================
# SECCION FUSIONADA: docs/CLINE_AUDITORIA_FASE_0.md
# ============================================================

# AUDITORÍA FASE 0 — Portal CFS + Inscripción + Roles

> **Fecha:** 2026-10-06 · **Commit:** `f53a3ac` · rama `main`
> **Naturaleza:** auditoría. **No se ha implementado nada.**
>
> Cada afirmación lleva su respaldo. Lo que **no** he verificado va marcado
> **NO VERIFICADO** — y eso es la mitad del valor de este documento.

---

## 1. Estado actual

```
rama: main · HEAD: f53a3ac
11 archivos modificados · 38 no rastreados
Migraciones: 0001–0006 de E-2 aplicadas · libro mayor 40 · 0 pendientes · 0 con deriva
```

**Lo verificado en esta sesión, con evidencia:**

| Área | Estado |
|---|---|
| Esquema y migraciones | 🟢 40 aplicadas, **0 con deriva** |
| RLS de `aspirantes` | 🟢 6 políticas — `read_own`, `admin_all` verificadas con JWT real |
| E2E (suites en `main`) | 🟢 **14 casos** verdes |
| Registro de aspirantes | 🟢 `signup` → 200, `aspirantes` crece |
| Planilla: workflow E-2 | 🟡 **servicio implementado y probado en local** (7/7 + 44/44) |
| Planilla: frontera RLS | 🟢 **DELETE bloqueado · auditoría inmutable · transiciones exactas** |
| Aula Virtual E2E | 🟢 **4/4** en dos corridas con `--retries=0` |
| **Rol Jefe del CFS** | 🔴 **NO EXISTE** |
| Portal público | 🟡 landing funcional; el resto **NO VERIFICADO** |

---

## 2. Arquitectura real

```
Flutter Web (CanvasKit)  →  Fastify 5 + Zod (ESM)  →  Supabase (PG 17.6 + RLS)
                                                    →  Cloudflare R2
                          Playwright (E2E)
```

**Backend por capas:** `HTTP → Dominio/Puertos → Infraestructura → Supabase` ✓
**El dominio no conoce Fastify ni Supabase** — los repositorios implementan los puertos, y **el cliente Supabase se construye por petición con el JWT del llamante** (`repos-supabase.ts:1113`), **que es lo que hace efectiva la RLS**.

**125 archivos Dart · 44 TypeScript en `src/` · 34+ migraciones · 12 specs E2E.**

---

## 3. Funcionalidades existentes — **[EVIDENCIA]**

| Módulo | Estado |
|---|---|
| Landing pública | ✅ carga oferta real por `obtenerProgramasDisponibles()` |
| Inscripción digital | ✅ formulario + `PUT /yo/planilla` |
| Planilla (PDF/XLSX genérico) | ✅ en uso |
| Planilla Oficial (renderer) | 🟡 **implementado, probado en aislamiento, SIN CONECTAR** |
| Workflow de planilla (E-2) | 🟡 servicio implementado; **frontera RLS cerrada** |
| Aula Virtual | ✅ 4/4 E2E |
| Asistencia QR (M7) | 🟡 nube ✓ · **sin validar en dispositivo físico** |
| cPanel de inscripciones | ✅ el admin descarga planillas |
| Roles | ✅ **3**: `admin`, `docente`, `estudiante` |
| Módulos del sistema | 11 filas, **8 encendidas** |

---

## 4. Reutilizable sin tocar

`landing_page.dart` · `AspiranteRepository` · `PuertaPlanilla` y su implementación ·
las 6 políticas RLS de `aspirantes` · el catálogo `inscripcion_campos` (44 campos) ·
`validar_planilla(jsonb)` · el arnés E2E completo · `apply-migrations.mjs` y sus
verificadores.

---

## 5. Incompletas — y su causa

| # | Funcionalidad | Qué falta |
|---|---|---|
| 1 | **Planilla Oficial conectada** | **0 imports, 0 rutas** — el renderer existe y no lo usa nadie |
| 2 | **Rutas HTTP del workflow** | implementadas; **medidas sólo por PostgREST, no por HTTP** |
| 3 | **Error handler** | **`23514` y `FST_ERR_CTP_EMPTY_JSON_BODY` → `500`** |
| 4 | **Jefe del CFS** | **no existe como rol** |
| 5 | **Atomicidad de observar** | RPC creado; **fault injection NO MEDIDO** |
| 6 | **Asistencia QR** | sin validar en dispositivo |

---

## 6. Riesgos — ordenados por daño

**1 · El error handler miente en dos direcciones.** Medido: un cuerpo vacío
(`statusCode: 400` según Fastify) y las transiciones ilegales (`23514`) **producen
`500`**. **El rechazo funciona; la comunicación no.** Es la misma familia que el
`_razonDeGotrue` del registro. **[MEDIDO]**

**2 · El renderer oficial no lo usa nadie.** Trabajo real, probado, **inalcanzable**.
Si un jurado pregunta «¿dónde veo la planilla oficial?», **hoy no hay dónde**.

**3 · La plantilla del PDF se busca en 4 rutas candidatas** y funciona porque `cwd`
es `backend/`. **En despliegue puede no encontrarla** — y el PDF saldría en blanco
**sin fallar**. **[NO VERIFICADO en producción]**

**4 · `eliminar-cuenta.mjs` fallará** con `on delete restrict` sobre fichas con
versiones. **Es el `RESTRICT` haciendo su trabajo**, pero el script no lo trata.

**5 · RLS no probada en la ruta administrativa.** Los casos negativos los cortó
`exigirAdmin()` **antes** de llegar a la RLS. **[MEDIDO — la RLS no se ejerció]**

---

## 7. Dependencias

```
Landing → AspiranteRepository → catálogo público (sin sesión)
Inscripción → PUT /yo/planilla → aspirantes.datos_planilla
Workflow → PuertaPlanilla → planilla_versiones (RLS + triggers)
Planilla Oficial → datos_planilla + program_id + enrollments + schedule_slots
Admin → exigirAdmin() + RLS admin_all
```

---

## 8. Contratos

**Zod define la entrada**; OpenAPI se deriva. **El workflow de E-2 usa errores con
código de dominio** — verificado: `{error: {codigo: "PLANILLA_NO_OBSERVADA", mensaje}}` ✓
**Ese es el patrón correcto y el error handler debería seguirlo para `23514`.**

---

## 9. Flujo de inscripción — **[EVIDENCIA]**

```
Landing → oferta dinámica → «Inscribirse» → formulario → PUT /yo/planilla
  → aspirantes.datos_planilla (jsonb) → PDF/XLSX bajo demanda
```

**El catálogo `inscripcion_campos` (44 campos) define el formulario** — añadir un
campo **no requiere tocar código** ✓

---

## 10. Flujo de planilla — el contrato aprobado

```
BORRADOR (= ausencia de versión)
   ↓ enviar
ENVIADA ──→ APROBADA
   └→ OBSERVADA → REENVIADA → APROBADA
```

**Protegido en PostgreSQL, verificado con JWT reales:**

| Invariante | Estado |
|---|---|
| Transiciones exactas (4 ✓ / 3 ✗) | ✅ medido |
| Snapshot inmutable | ✅ |
| `numero` · `aspirante_id` · `enviada_at` inmutables | ✅ |
| Auditoría de aprobación inmutable | ✅ **409, fila intacta** |
| DELETE administrativo | ✅ **las 4 versiones sobreviven** |
| Observación sólo sobre `ENVIADA` | ✅ 403 medido |
| `p_admin_id = auth.uid()` | ✅ leído en la función |

---

## 11. Roles actuales — **[EVIDENCIA]**

```sql
check (rol in ('admin', 'docente', 'estudiante'))    -- 202609100001_init.sql:17
```

**Tres roles, y el trigger de `profiles` impide el auto-ascenso** (`with check (id = auth.uid() and rol = 'estudiante')`).

**Capacidad técnica hoy:** aspirante → su planilla · admin → cualquiera ·
**docente → ninguna UI ni ruta de planilla**.

---

## 12. **Situación del rol Jefe del CFS** — el hallazgo de esta fase

```
grep -rn "jefe|JEFE" supabase/migrations/*.sql   →   0 coincidencias
```

**El rol NO EXISTE.** Ni en el esquema, ni en el backend, ni en Flutter.

**Consecuencias, y son de diseño, no de código:**

1. **Hay que decidir qué puede hacer** antes de crearlo. **No asumir que es un superadmin** — tu instrucción lo dice, y es la decisión correcta: **un jefe de centro supervisa, no necesariamente administra el sistema.**
2. **La persona no se hardcodea** ✓ — el rol se asigna por datos. **El modelo ya lo permite**: `profiles.rol` es una columna, y añadir un valor al `check` es una migración **de una línea**.
3. **[PROPUESTA]** Que `jefe_cfs` sea **un rol más**, con sus políticas RLS propias — **no una bandera que reutilice `is_admin()`**. Si compartiera `is_admin()`, **el rol no sería una entidad de autorización real**, que es lo que pediste.

---

## 13. Landing — **[EVIDENCIA]**

`lib/screens/landing_page.dart`:

- **línea 19:** documenta que la oferta sale de `AspiranteRepository.obtenerProgramasDisponibles()`
- **línea 59:** la llama
- **línea 171:** botón «Inscribirse»
- **línea 182:** botón «Portal Académico»
- **existe `test/landing_page_test.dart`** ✓

**Está conectada a datos reales y tiene pruebas.** **NO se reemplaza a ciegas** — el trabajo de Fase 2 es **mejorarla**, conservando su integración.

---

## 14. Gap analysis

| Fase | Qué falta | Depende de |
|---|---|---|
| 1 · Portal | sitemap, componentes, estados | — |
| 2 · Landing | jerarquía visual, responsive real, accesibilidad | 1 |
| 3 · Oferta | auditar el modelo de `programs` | — |
| 4 · Inscripción | conectar oferta → planilla | 3 |
| 5 · Workflow admin | conectar la UI al workflow E-2 | **medición HTTP** |
| 6 · Roles | **crear `jefe_cfs` + sus políticas** | **decisión funcional** |
| 7 · Dashboard | **indicadores cuando haya datos** | 5, 6 |
| 8 · QA | responsive, accesibilidad, seguridad | todo |

---

## 15-16. Tests

**Existentes:** 66 Flutter · 27 backend · 12 E2E specs · 40 migraciones verificadas ·
`planilla-workflow.test.ts` 7/7 · regresión de planillas 44/44 · landing ✓

**Faltantes:** integración del workflow **por rutas HTTP** · **fault injection de
atomicidad** · **RLS en la ruta administrativa** (nunca ejercida) · responsive real
(360→1440) · accesibilidad · **`jefe_cfs`** · error handler.

---

## 17. Fases propuestas

**Antes de Fase 1, dos cosas que no son de portal pero bloquean:**

1. **El error handler** — está medido, es acotado, y **todo lo que construyas encima heredará el defecto**.
2. **La medición HTTP del workflow** — sin ella, Fase 5 se construye sobre algo no verificado por su interfaz real.

**Después:** Fase 3 (oferta) puede ir en paralelo con 1 y 2 — **no depende de nada.**

---

## 18. Preguntas realmente bloqueantes

**Sólo cuatro, y las cuatro son de negocio:**

1. **¿Qué puede hacer el Jefe del CFS?** — sin esto, `jefe_cfs` no se puede crear. **Y si la respuesta es «lo mismo que el admin», entonces no hace falta un rol nuevo: hace falta un nombre.**
2. **¿El portal público y el académico comparten sesión?** — decide la navegación entera.
3. **¿La oferta pública son los `programs` de tipo `CURSO_LIBRE` activos?** — la landing ya los muestra así; **confirmarlo cierra Fase 3**.
4. **¿Dónde corre el backend en el despliegue?** — decide si la plantilla del PDF se encuentra.

**Ninguna otra bloquea.** El resto se resuelve auditando.

---

## Lo que NO he auditado, y por qué

**AuthGate · navegación · dashboard · tema · responsive · accesibilidad · RLS
completa · los 12 specs E2E uno a uno.**

**No los declaro 🟢 ni 🔴: los declaro NO VERIFICADO.** He priorizado **lo que
bloquea las fases siguientes** —roles, landing, workflow, error handler— y **lo he
medido**; el resto requiere una sesión propia.

**Y una advertencia de método, con la evidencia de esta sesión:** **de los seis
instrumentos que escribí hoy, cuatro fallaron por su propia construcción** —el
`tasklist` que da falso negativo, el `apikey` con dos identidades, el orden de
limpieza, el cuerpo vacío—. **Los dos agujeros reales de seguridad los encontró tu
auditoría, no mis pruebas.** **Auditar con cuidado rinde más que medir deprisa**, y
esta Fase 0 es exactamente eso.

# ============================================================
# SECCION FUSIONADA: docs/CLINE_FASE_0_5_BLOQUEADORES.md
# ============================================================

# FASE 0.5 — Cierre de bloqueadores arquitectónicos

> **Fecha:** 2026-10-07 · **Commit base:** `f53a3ac` · **Naturaleza:** auditoría + cierre medido de E1/E2.
> **Actualización:** el bloque E y el defecto E1 del workflow sí fueron corregidos y verificados; no se ha implementado `jefe_cfs`, Landing, RLS ni cambios de navegación.
>
> Cada bloque cierra con **evidencia**, `NO VERIFICADO` o `DECISIÓN PENDIENTE`.
> **No hay «cerrado por inferencia».**

---

## BLOQUE A — Jefe del CFS

### Evidencia

```sql
check (rol in ('admin', 'docente', 'estudiante'))   -- 202609100001_init.sql:17
```

**`grep -rn "jefe|JEFE" supabase/migrations/*.sql` → 0 coincidencias.** El rol **no existe**: ni en el esquema, ni en el backend, ni en Flutter.

**Y `is_admin()` es la única guardia de rol administrativo** — todas las rutas de administración pasan por ella.

### Hallazgo

**No hay nada que reasignar: `jefe_cfs` no le quita capacidades a nadie porque no existe.** La pregunta real **no es «qué le quito al admin»** sino **«qué necesita un jefe de centro que hoy nadie tiene»**.

### Matriz propuesta — **[PROPUESTA]**

| Capacidad | admin | **jefe_cfs** | docente | estudiante |
|---|:---:|:---:|:---:|:---:|
| Ver inscripciones del centro | ✅ | ✅ | ❌ | ❌ |
| Ver planillas de aspirantes | ✅ | ✅ | ❌ | ❌ |
| **Observar** una planilla | ✅ | ✅ | ❌ | ❌ |
| **Aprobar** una planilla | ✅ | ✅ | ❌ | ❌ |
| Gestionar el catálogo de campos | ✅ | ❌ | ❌ | ❌ |
| Gestionar usuarios y roles | ✅ | ❌ | ❌ | ❌ |
| Gestionar programas y secciones | ✅ | ❌ | ❌ | ❌ |
| Ver su propia planilla | — | — | — | ✅ |
| Aula Virtual (sus secciones) | ✅ | ❌ | ✅ | ✅ |

**El criterio que la sostiene:** **el jefe del CFS es el responsable académico del centro, no el administrador del sistema.** Supervisa el trámite de inscripción —**ve, observa, aprueba**— y **no toca la configuración**: ni el catálogo, ni los usuarios, ni los programas.

**Y eso es exactamente lo que pediste: `jefe_cfs` NO es superadmin.** Si lo fuera, **el rol no aportaría nada** — sería un segundo nombre para `admin`.

### Decisión recomendada

**Crear `jefe_cfs` como un valor más del `check`, con `is_jefe_o_admin()` propia** — **no reutilizando `is_admin()`**. Razón: si compartiera la función, **las políticas no distinguirían los dos roles**, y entonces **el rol no sería una entidad de autorización real**.

**La persona no se hardcodea** ✓ — `profiles.rol` es una columna; asignar o revocar es un `UPDATE`.

### NO implementar todavía

Nada de este bloque. **Falta confirmar la matriz** — y es `DECISIÓN PENDIENTE` del propietario.

---

## BLOQUE B — Sesión pública / académica

### Evidencia

**No hay `GoRouter` ni `routerConfig`** — cero coincidencias. La navegación es **imperativa**: `main.dart` monta un `AuthGate` que decide qué mostrar según la sesión.

**Archivos:** `core/gateways/auth_gateway.dart` · `main.dart` · `screens/landing_page.dart` · `screens/login_screen.dart`.

### Hallazgo

**El portal público y el académico comparten el mismo árbol de widgets, y `AuthGate` decide cuál se ve según si hay sesión.** La landing tiene botones que llevan a login y a inscripción.

**Consecuencia:** **no hay dos portales: hay uno con dos vistas.** Y eso **no es un defecto** — es una decisión, y funciona.

### Contrato recomendado — **[PROPUESTA]**

```
Sin sesión:
  /            → landing pública (oferta real, sin autenticar)
  /inscripcion → formulario público (el aspirante NO tiene cuenta todavía)

Con sesión:
  /panel       → dashboard según rol
  /aula        → Aula Virtual

Regla: la landing NUNCA exige sesión.
Regla: la inscripción pública NO exige sesión — es el orden que respeta ADR-007
       (autenticarse primero abriría una cuenta sin planilla).
```

**Lo que hay que decidir:** si se adopta `GoRouter` o se conserva la navegación imperativa. **`DECISIÓN PENDIENTE`** — y **no hay evidencia de que la imperativa esté fallando**, así que **migrar sería un cambio sin problema demostrado**.

---

## BLOQUE C — Fuente de la oferta formativa

### Evidencia

```
landing_page.dart:59   →  _aspiranteRepo.obtenerProgramasDisponibles()
aspirante_repository.dart:44  →  Result.guard(() => _gateway.programasDisponibles())
                                   ↓
                              gateway → endpoint / RPC → programs
```

**Y medido contra la base:** los programas activos son **6, todos `type: 'CURSO_LIBRE'`** — Estética, Oratoria, Curso Introductorio, Herrería, Higiene y Manipulación de Alimentos, y Soldadura Básica [SEMILLA].

### Hallazgo

**La fuente de verdad es `public.programs`**, con `is_active` y `type`. **`CURSO_LIBRE` es un tipo de programa**, y **la oferta pública del CFS son los programas activos de ese tipo**.

**Y hay un dato que conviene mirar:** el catálogo tiene **`SEM-SOL-CL` — «Soldadura Básica [SEMILLA]»**, que es **el sembrado**. **El CFS Nacional de Soldadura tiene un programa de soldadura que parece de demostración.** **[NO VERIFICADO]** si es el programa real o un dato de prueba.

### Decisión recomendada

**`programs` es la fuente de verdad, y no hay que crear otra** ✓ — **la landing ya lee de ahí.** Falta **confirmar qué programas son reales y cuáles del sembrado**, y eso es `DECISIÓN PENDIENTE`.

---

## BLOQUE D — Despliegue real

### Evidencia

```
Dockerfile           →  EXISTE  (backend/Dockerfile, 1.585 b, 12 sep)
docker-compose.yml   →  EXISTE
render.yaml          →  NO existe
Procfile             →  NO existe
proveedor real       →  NO VERIFICADO
```

> **CORRECCIÓN (2026-10-06).** Aquí se dijo que `Dockerfile` **no existía**. **Es
> falso.** Miré la raíz del repositorio en vez de `backend/`. **Un `ls` mal dirigido
> produjo una afirmación sobre el despliegue** — y es el mismo error de fondo que
> recorre esta sesión: **concluir desde donde se miró, no desde donde está.**

**Y la documentación histórica menciona Render** — pero **no hay ningún archivo de configuración de despliegue en el repositorio.**

### Hallazgo

**No se puede determinar dónde corre el backend en producción con la evidencia del repositorio.**

```
DESPLIEGUE REAL: NO VERIFICADO
```

**Y esto tiene una consecuencia concreta y ya identificada:** el renderer oficial busca la plantilla del PDF en **cuatro rutas candidatas** y funciona en pruebas porque `cwd` es `backend/`. **Sin saber el entorno de despliegue, no se puede saber si la encontrará** — y **el fallo sería un PDF en blanco que no da error**.

### Decisión recomendada

**`DECISIÓN PENDIENTE` del propietario: ¿dónde corre?** Y hasta saberlo, **la resolución de la plantilla debería fallar ruidosamente en vez de silenciosamente** — pero eso **es una implementación, y no la hago aquí**.

---

## BLOQUE E — Error handler

### Evidencia

**Archivo:** `backend/src/http/plugins/errores.ts` — **el manejador global.**

**Dos casos medidos con HTTP real y una corrección ya aplicada:**

**1 · `FST_ERR_CTP_EMPTY_JSON_BODY` — CORREGIDO**

```
error original:  FastifyError: Body cannot be empty when content-type is set to 'application/json'
code:            FST_ERR_CTP_EMPTY_JSON_BODY
resultado final: HTTP 400 · PETICION_INVALIDA · "El cuerpo debe ser JSON válido."
```

La corrección mínima ya está en `backend/src/http/plugins/errores.ts`: la rama de Fastify cubre los códigos `FST_ERR_CTP_*`. `npm run build` terminó con código 0 y la medición HTTP posterior confirmó el `400`.

**2 · E1 `OBSERVADA → OBSERVADA` — CORREGIDO EN EL RPC**

El fallo real no era un `23514`: el RPC lanzaba `P0001` cuando el `UPDATE ... WHERE estado = 'ENVIADA'` afectaba 0 filas, y `traducirError()` lo convertía en `500 ERROR_BASE_DE_DATOS`. La capa de repositorio ya tenía el `409 TRANSICION_PLANILLA_INVALIDA`, pero era inalcanzable.

La solución preserva la autoridad atómica del RPC: cuando no hay fila ENVIADA, la función hace `RETURN` sin insertar una observación y devuelve cero filas; el repositorio traduce ese resultado al `409` existente. Se aplicaron las migraciones nuevas `202610060007_e1_observar_estado_sin_error.sql` y `202610060008_e1_observar_estado_resultado_fix.sql`.

**Nota:** `0008` fue necesario porque la primera versión de `0007` omitió `approved_by` en su `RETURN QUERY`; el defecto fue detectado por la regresión HTTP (`42804`) y corregido mediante una migración posterior, sin editar migraciones aplicadas.

### Estado actual

El defecto específico de Fastify ya está corregido y medido. **No se hizo un mapeo global de `23514` a `409`**, porque eso mezclaría restricciones con semánticas distintas.

El caso E1 tampoco requirió modificar el traductor global: su causa era el `P0001` específico del RPC `observar_planilla_atomico`, y la corrección se hizo conservando el contrato `TRANSICION_PLANILLA_INVALIDA` que ya existía en el repositorio.

**Resultado del bloque E relevante para esta fase:**

- `FST_ERR_CTP_EMPTY_JSON_BODY` → **400 `PETICION_INVALIDA`** ✓
- `PLANILLA_INCOMPLETA` → **422** ✓
- `OBSERVADA → OBSERVADA` → **409 `TRANSICION_PLANILLA_INVALIDA`** ✓
- `23514` para motivo vacío → **400 `RESTRICCION_VIOLADA`** ✓

No se declara resuelto ningún otro mapeo global que no haya sido medido.

---

## BLOQUE F — Workflow HTTP

### Evidencia

**Rutas registradas y verificadas** (401 sin token, no 404): `POST /yo/planilla/enviar` · `POST /yo/planilla/reenviar` · `GET /yo/planilla/versiones` · `POST /inscripcion/planilla/:id/observar` · `/aprobar`.

**Regresión HTTP real ejecutada después de aplicar E1:**

```text
A1 · planilla incompleta        → 422 PLANILLA_INCOMPLETA              ✓
A4 · cuerpo JSON vacío          → 400 PETICION_INVALIDA                ✓
A3 · ENVIADA→OBSERVADA          → 200                                  ✓
E1 · OBSERVADA→OBSERVADA        → 409 TRANSICION_PLANILLA_INVALIDA     ✓
A3 · OBSERVADA→APROBADA         → 409 TRANSICION_PLANILLA_INVALIDA     ✓
A5 · ruta inexistente           → 404                                  ✓
A5 · sin token                  → 401                                  ✓
A5 · alumno→ruta admin          → 403 SOLO_ADMIN                       ✓
A5 · listar propias             → 200                                  ✓
```

Las pruebas crearon **2 fichas y 3 cuentas temporales** y la propia rutina confirmó la limpieza al finalizar. La ejecución terminó con **exit code 0**.

**ESTADO HTTP DEL WORKFLOW RELEVANTE A ESTA FASE: VERIFICADO ✓**

### Nota de alcance

Esto **no equivale a cerrar B1–B16 completo**. La regresión cubre los casos A1/A3/A4/A5 y E1 que estaban bloqueando esta fase; los escenarios adicionales del workflow que no fueron ejecutados aquí siguen siendo `NO VERIFICADO`.

El orden E → F fue correcto: primero se corrigió el manejo del cuerpo vacío y luego el RPC de observación, y finalmente se midió el contrato HTTP completo de esta frontera.

---

## BLOQUE G — Renderer oficial

### Evidencia

```
planilla-oficial-tipos.ts      130 líneas
planilla-oficial-valores.ts    307 líneas
planilla-oficial-pdf.ts        277 líneas
tests                          6/6 ✓
assets/planilla-oficial-template.pdf   EXISTE (561.475 b)
imports desde backend/src      0
rutas que lo invocan           0
```

### Hallazgo

**Implementado, probado y desconectado.** **Y un detalle que importa:** el contrato dice que **el PDF oficial se genera desde `planilla_versiones.datos_snapshot`** — **no desde `datos_planilla` vivo**. **[NO VERIFICADO]** si el renderer ya está preparado para recibir un snapshot o si lee la ficha viva.

### NO implementar todavía

**Conectar el renderer requiere:** resolver la ruta de la plantilla (bloque D) **y** decidir si lee snapshot o ficha viva. **Las dos están pendientes.**

---

## Orden recomendado de implementación

```
1 · BLOQUE F — completar la medición HTTP del workflow
      La frontera crítica de esta fase ya está verificada para A1/A3/A4/A5/E1.
      Faltan únicamente los escenarios B1–B16 que no fueron ejecutados aquí.

2 · BLOQUE D — decidir el despliegue
      Desbloquea la plantilla del PDF. DECISIÓN PENDIENTE del propietario.

3 · BLOQUE A — jefe_cfs
      Requiere aprobar la matriz. DECISIÓN PENDIENTE.

4 · BLOQUE C — confirmar qué programas son reales
      DECISIÓN PENDIENTE.

5 · BLOQUE G — conectar el renderer
      Depende de D y de confirmar el contrato de snapshot.

6 · BLOQUE B — navegación
      Es el menos urgente: funciona, y no hay evidencia de que falle.
```

---

## Resumen de estados

| Bloque | Estado |
|---|---|
| A · jefe_cfs | **DECISIÓN PENDIENTE** — matriz propuesta, sin aprobar |
| B · sesión | **NO VERIFICADO** el detalle; propuesta sin implementar |
| C · oferta | ✅ fuente identificada (`programs`) · **DECISIÓN PENDIENTE** qué es real |
| D · despliegue | **NO VERIFICADO** — no hay config de despliegue en el repo |
| E · error handler | ✅ **CORREGIDO Y MEDIDO** — Fastify 400 + E1 409 verificados |
| F · workflow HTTP | 🟢 **VERIFICADO PARCIALMENTE** — A1/A3/A4/A5/E1 en verde; B1–B16 completo sigue pendiente |
| G · renderer | ✅ auditado — desconectado, y depende de D |

**Ningún bloque se declara cerrado por inferencia.** **E1 está cerrado por medición HTTP real.** F queda parcialmente verificado por alcance explícito: la regresión ejecutada cubre los casos que bloqueaban esta fase, no todo B1–B16.

---

## Lo que NO debe implementarse todavía

`jefe_cfs` · las políticas RLS de roles · el rediseño de la Landing · la conexión del
renderer oficial · la navegación con `GoRouter`. **No se debe hacer un mapeo global
de `23514` a `409`**: el caso de motivo vacío sigue correctamente en `400
RESTRICCION_VIOLADA`, y cualquier nuevo mapeo debe probarse por contexto.

---

## ACTUALIZACIÓN — FASE 0.6-A / CONSOLIDACIÓN HTTP · 2026-10-07

La medición posterior a este documento cerró los tres escenarios que faltaban en la frontera HTTP del workflow de planillas:

- **B3** · enviar sin ficha → **HTTP 404** ✓
- **B10** · aprobar `ENVIADA` → **HTTP 200**, estado `ENVIADA → APROBADA` ✓
- **B11** · aprobar `REENVIADA` → **HTTP 200**, ciclo `ENVIADA → OBSERVADA → REENVIADA → APROBADA` ✓

Con ello, **B1–B16 quedan medidos por HTTP: 16/16 PASS, 0 FAIL, 0 NO DEFINIDO**. Esta afirmación se limita al contrato HTTP del workflow de planillas; no implica que todos los demás bloques del proyecto estén cerrados.

### Instrumentación consolidada

Se creó `supabase/_workflow-http-suite.mjs`, que ejecuta secuencialmente los dos instrumentos HTTP existentes:

1. `_errores-http.mjs` — escenarios A1/A3/A4/A5 + E1.
2. `_b3-b10-b11.mjs` — B3/B10/B11.

`_b3-b10-b11.mjs` ahora devuelve `exit code 1` si alguno de sus tres casos falla. Las migraciones `0007`/`0008` no fueron modificadas.

### Distinción de niveles

`supabase/_probar-transiciones.mjs` queda explícitamente identificado como instrumento **PostgREST/infraestructura**, no como prueba del contrato HTTP. Sus 400 corresponden a ese nivel y no deben compararse directamente con los 409 del backend HTTP. Para validar el contrato de aplicación debe utilizarse `_workflow-http-suite.mjs`.

### E1/E2

La regresión posterior mantiene:

- cuerpo JSON vacío → **400 `PETICION_INVALIDA`** ✓
- `OBSERVADA → OBSERVADA` → **409 `TRANSICION_PLANILLA_INVALIDA`** ✓

La causa histórica de E1 fue `P0001` en el RPC, no `23514`; las migraciones `202610060007_e1_observar_estado_sin_error.sql` y `202610060008_e1_observar_estado_resultado_fix.sql` permanecen aplicadas y sin editar.

### Estado de esta consolidación

**CERRADO:** medición B1–B16 por HTTP · consolidación de ejecución en una suite · separación explícita HTTP/PostgREST · documentación actualizada.

**PENDIENTE:** decisiones de producto/arquitectura identificadas en los bloques A, B, C, D y G. `SEM-SOL-CL` continúa siendo una decisión de producto y el despliegue real continúa sin verificar.

# ============================================================
# SECCION FUSIONADA: docs/CLINE_BLOQUE_E_ERROR_HANDLER.md
# ============================================================

# BLOQUE E — Auditoría del error handler

> **Fecha:** 2026-10-06 · **Naturaleza:** auditoría. **Producción sin modificar.**
> Separa **evidencia medida** · **causa raíz** · **propuesta** · **pendiente**.
> **Nada se declara cerrado por inferencia.**

---

## 0. Dos correcciones a mi informe anterior

**Corrección 1 — `backend/Dockerfile` SÍ EXISTE.** 1.585 bytes, 12 sep. **Mi Fase 0.5
dijo que no existía.** Miré la raíz del repositorio en vez de `backend/`. **Falso.**

```
Dockerfile:            EXISTE  (backend/Dockerfile)
docker-compose.yml:    EXISTE
render.yaml:           no existe
Procfile:              no existe
proveedor real:        NO VERIFICADO
```

**Corrección 2 — `23514` YA tiene traducción.** `traducir-error.ts:129` →
`RESTRICCION_VIOLADA`. **Y también `23502` (línea 117), `23505` (123), `23503` (137)
y `42501` (145).** **Mi afirmación de que estos códigos «no pasan por el traductor»
era incorrecta.** El problema **no es que falte una rama: es que la rama existente no
distingue el contexto.**

---

## 1. Evidencia medida

### 1.1 `errores.ts` — las ramas que existen

```
línea 19   ZodError                        →  ErrorApi.peticionInvalida()  →  400
línea 31   ErrorApi                        →  su propio `estado`
línea 44                                   →  ErrorApi.peticionInvalida()
línea 52   FST_ERR_CTP_INVALID_MEDIA_TYPE  →  ErrorApi.peticionInvalida()  →  400  ✓
línea 63                                   →  ErrorApi.interno()           →  500  ← el pozo
línea 70                                   →  ErrorApi.noEncontrado()
```

**La línea 52 es la clave, y es la prueba de que el patrón correcto ya se usó una
vez:** **`FST_ERR_CTP_INVALID_MEDIA_TYPE` sí tiene rama propia y da 400.**
**`FST_ERR_CTP_EMPTY_JSON_BODY` no la tiene** — y cae al pozo de la 63.

### 1.2 Los dos casos, medidos con HTTP real

**Caso 1 — cuerpo vacío:**

```
error:      FastifyError: Body cannot be empty when content-type is set to 'application/json'
code:       FST_ERR_CTP_EMPTY_JSON_BODY
statusCode: 400        ← Fastify ya lo clasifica como error del cliente
respuesta:  500        ← y el log dice "error no controlado"
```

**Caso 2 — transición ilegal E-2:**

```
origen:     el trigger `impedir_version_modificada` lanza 23514
respuesta:  500
```

### 1.3 El contraste que demuestra que el patrón funciona

**El servicio SÍ traduce bien cuando el error nace en el dominio:**

```
409  {"error":{"codigo":"PLANILLA_NO_OBSERVADA","mensaje":"La última versión…"}}
```

**Medido.** **El camino correcto existe, funciona, y lleva código de dominio.**
**Los errores de PostgreSQL y de Fastify no entran por ahí.**

---

## 2. Causa raíz

**No es «falta una rama para 23514».** Es **dónde se pierde el contexto semántico**:

```
PostgreSQL 23514  →  traducir-error.ts:129  →  RESTRICCION_VIOLADA  →  400
                        ↑
                   UNA sola traducción para TODOS los 23514
```

**`23514` es `check_violation`, y significa cosas distintas según qué constraint lo
lance.** Con **una sola traducción**, el sistema **no puede distinguir**:

- **una transición de workflow ilegal** → debería ser **409** (conflicto de estado)
- **una planilla incompleta al enviar** → debería ser **422** (entidad no procesable)
- **un `CHECK` de integridad interno** → **500** si es una condición que el cliente no provocó

**Y el caso de Fastify es más simple y más grave:** **`FST_ERR_CTP_EMPTY_JSON_BODY`
trae `statusCode: 400` en el propio error y el manejador lo ignora.** **Fastify ya
dijo que es del cliente; el manejador lo convierte en 500.**

---

## 3. Diseño propuesto — **[PROPUESTA, sin implementar]**

### 3.1 Principio: **el contexto viaja con el error, no se adivina del texto SQL**

**Adivinar el significado desde el mensaje de PostgreSQL es frágil** — un cambio de
redacción en un `raise` cambiaría el mapeo **sin que nada falle**. **La traducción
debe basarse en el contexto de la operación**, que el repositorio **ya conoce**:
`traducirError(error, 'observar la planilla')` — **el segundo argumento ya existe** y
**ya se usa** (`detalles.contexto` en el log medido).

### 3.2 Las dos ramas que faltan

**En `errores.ts`, antes del pozo de la línea 63:**

```
1. si el error trae `statusCode` y es 4xx  →  usarlo
     cubre TODOS los `FST_ERR_CTP_*`, no sólo el del cuerpo vacío
     y no hay que enumerarlos uno a uno

2. si el código PG es 23514  →  el mapeo lo decide el CONTEXTO
     no el código
```

**Por qué `statusCode` y no enumerar:** **`FST_ERR_CTP_EMPTY_JSON_BODY` no es el
único** — hay `INVALID_MEDIA_TYPE` (ya cubierto a mano), `BODY_LIMIT`,
`INVALID_CHARACTER`… **Enumerar uno a uno es una lista que envejece; usar el
`statusCode` que Fastify ya pone es una regla que no.**

### 3.3 El mapeo de `23514` por contexto

| Operación | `23514` de | HTTP | Código |
|---|---|---|---|
| `observarPlanilla` · `aprobarPlanilla` | transición del trigger | **409** | `TRANSICION_INVALIDA` |
| `enviarPlanilla` · `reenviarPlanilla` | `validar_planilla()` | **422** | `PLANILLA_INCOMPLETA` |
| cualquier otra | `CHECK` de integridad | **500** | `ERROR_BASE_DE_DATOS` |

**Y el punto que tu instrucción señala y con el que coincido:** **no convertir *todo*
`23514` en la misma respuesta.** **Un `422` legítimo convertido en `409` es peor que
el `500` actual** — porque **el `500` se nota y el `409` engaña.**

### 3.4 Alternativa que descarto, y por qué

**Traducir por el texto del mensaje** (`mensaje.includes('Transición de planilla no
permitida')`) — **es lo que hizo `_razonDeGotrue` en el registro y fue un error**:
comparaba subcadenas contra un cuerpo JSON **y acertaba por lo que el texto llevaba
dentro**. **Mismo antipatrón, mismo resultado.**

---

## 4. Archivos afectados

| Archivo | Cambio |
|---|---|
| `backend/src/http/plugins/errores.ts` | **2 ramas** antes del pozo: `statusCode` 4xx y `23514` por contexto |
| `backend/src/infra/traducir-error.ts` | **23514 deja de traducirse sola**: recibe el contexto |
| `backend/test/errores.test.ts` | **nuevo** — las seis pruebas del §5 |
| `backend/src/infra/repos-supabase.ts` | **no cambia** — ya pasa el contexto |

**El repositorio ya pasa el contexto** ✓ (`traducirError(error, 'observar la planilla')`).
**Eso es lo que hace la solución pequeña: la información ya está ahí.**

---

## 5. Matriz error → HTTP → código

| Error | Origen | HTTP | Código | Estado |
|---|---|---|---|---|
| Cuerpo JSON vacío | Fastify `FST_ERR_CTP_EMPTY_JSON_BODY` | **400** | `PETICION_INVALIDA` | ⚠️ hoy **500** |
| Media type inválido | Fastify `FST_ERR_CTP_INVALID_MEDIA_TYPE` | 400 | `PETICION_INVALIDA` | ✅ ya cubierto |
| Transición ilegal | trigger E-2, `23514` | **409** | `TRANSICION_INVALIDA` | ⚠️ hoy **500** |
| Planilla incompleta | `validar_planilla()`, `23514` | **422** | `PLANILLA_INCOMPLETA` | ⚠️ **NO MEDIDO** |
| `numero` duplicado | `UNIQUE`, `23505` | **409** | — | ✅ traducido (123) |
| `NOT NULL` | `23502` | 400 | — | ✅ traducido (117) |
| `FK` | `23503` | 400 | — | ✅ traducido (137) |
| `EXECUTE` revocado | `42501` | **403** | — | ✅ traducido (145) |
| Desconocido | — | **500** | `ERROR_INTERNO` | ✅ correcto |

**Tres filas están en ⚠️ y son el trabajo.** **Y una está `NO MEDIDO`: el `422` de la
planilla incompleta** — **no lo he provocado**, y **es justamente el caso que
justifica que `23514` no se pueda traducir en bloque.**

---

## 6. Pruebas necesarias — **[PENDIENTES]**

```
1. body JSON vacío              →  400        ← hoy 500, medido
2. transición ilegal E-2        →  409        ← hoy 500, medido
3. planilla incompleta enviar   →  422        ← NO MEDIDO
4. 23505 duplicado              →  409
5. 42501 sin permiso            →  403
6. error desconocido            →  500
```

**Las 3 y 4 y 5 no se han provocado.** **Y la 3 es la que decide el diseño:** si el
`23514` de `validar_planilla` **no se distingue del de la transición**, **el mapeo por
contexto es obligatorio** — y si se distinguen solos, **la solución es más pequeña
todavía.**

**Pruebas por HTTP real**, no unitarias: **el defecto está en el camino de la
petición**, y una prueba unitaria del manejador **no probaría que Fastify entrega el
error como se cree.**

---

## 7. Riesgos

**1 · Cambiar el manejador global toca TODOS los errores del backend.** Un mapeo mal
hecho **convierte errores internos en errores de cliente** — y **un `500` que se
vuelve `400` es peor que el `500`**: deja de alertar y **culpa al usuario**. **Por eso
la rama de `statusCode` debe aceptar sólo `4xx`**, nunca un `5xx` que venga del error.

**2 · `23514` por contexto exige que TODOS los llamadores pasen contexto.** Si alguno
no lo pasa, **cae al `500`** — que es **el comportamiento seguro**, y por eso el
`default` debe seguir siendo 500.

**3 · El orden importa:** `statusCode` **antes** de `23514`, porque **un error de
Fastify no trae código PG** y **uno de PostgreSQL no trae `statusCode`** — no se
solapan, pero el orden deja claro cuál manda.

---

## 8. Lo que NO debe implementarse todavía

**Nada de este bloque.** **Falta medir el caso 3** — el `422` de la planilla
incompleta — porque **es el que determina si el mapeo por contexto es necesario o
suficiente.**

**Y no se declara el Bloque E cerrado sin las pruebas HTTP reales del §6.**

---

## 9. Estado

| Pieza | Estado |
|---|---|
| Causa raíz | ✅ **localizada** — dos pozos distintos, uno por capa |
| `FST_ERR_CTP_EMPTY_JSON_BODY` | ✅ **medido** — `statusCode: 400` → respuesta `500` |
| `23514` de transición | ✅ **medido** — respuesta `500` |
| `23514` de planilla incompleta | **NO MEDIDO** |
| Traducción existente de `23514` | ✅ **existe** (`RESTRICCION_VIOLADA`) — **corrige mi informe** |
| `backend/Dockerfile` | ✅ **existe** — **corrige mi informe** |
| Propuesta | **[PROPUESTA]** — sin implementar |
| Pruebas | **[PENDIENTES]** |

**Y la síntesis, en una línea:** **el backend rechaza bien y comunica mal** — el
servicio traduce con código de dominio (`PLANILLA_NO_OBSERVADA`, 409 ✓), **y las dos
capas de abajo no llegan a ese camino.**
