# Auditoría independiente — 2026-10-25

**Cómo se hizo.** Cuatro subagentes en paralelo, cada uno con una misión acotada y
en modo de **solo lectura**: seguridad y autorización, código muerto y deuda,
accesibilidad e i18n, y deriva de documentación. Los dos últimos fallaron por un
error de red del host (502, no resolvió `workbuddy.ai`), no por el proyecto.

**Regla aplicada a sus informes:** un subagente describe lo que *pretendió* hacer.
Cada hallazgo se reverificó con medición propia antes de tocar nada. Dos de los
cuatro informes llegaron con falsos positivos que ellos mismos retiraron al
investigarlos; otros se retiraron aquí.

---

## Corregido

### Seguridad

| # | Hallazgo | Qué se hizo |
|---|---|---|
| S1 | **El JWT se aceptaba por query string en las ~60 rutas de la API**, no sólo en el WebSocket. Fastify loguea `req.url` completo, así que el token acababa en los logs de Render, en el `Referer` y en el historial. | El `onRequest` de `app.ts` ahora sale antes si la ruta no empieza por `/api/v1/asistencia/rt`. |
| S2 | **`solicitar-recuperacion` devolvía el correo del perfil** cuando el identificador existía. El `mensaje` no diferenciaba, pero el JSON sí: era un oráculo de enumeración que además entregaba la dirección. | Se quitó `email` de la respuesta. El cliente ya usaba como destino lo que el usuario escribió, con ese campo sólo como refinamiento. |
| S3 | **`porIdentificador` buscaba con `ilike` sin escapar comodines.** El valor va parametrizado (no hay inyección SQL), pero `%` y `_` son comodines de `ILIKE` y el esquema sólo exige `min(3)`: `admin%` acierta por prefijo y «0 filas» frente a «>1 filas» da un oráculo binario. | Se escapan `\`, `%` y `_` antes de la búsqueda. |

**Nota sobre S1:** existía una prueba que afirmaba el comportamiento contrario
(«`?token=` autentica TAMBIÉN una ruta REST, y eso se deja medido»). Su propio
comentario decía que acotarlo «es un cambio de seguridad y no se hace sin
decisión». La decisión estaba tomada por el encargo, así que se invirtió la
prueba: ahora exige **401 por query** y **200 por cabecera**.

### Deuda

| # | Hallazgo | Qué se hizo |
|---|---|---|
| D1 | **`UsuariosAdminRepository` tenía un `catch (_) {}` vacío** que, si la API fallaba, consultaba `profiles` por debajo. Tres problemas: un fallo de red se vestía de «lista vacía» (la RLS limita `profiles` al propio usuario salvo para admin); la paginación era mentira (`skip`/`take` sobre todos los perfiles en el cliente); y era el único repositorio que se saltaba el backend. | Fuera el fallback en `listar`. |
| D2 | **El mismo patrón en `cambiarEstado`**, que es una **escritura**: activar o desactivar una cuenta es la operación más delicada del panel y tenía un camino oculto. | Fuera. Un solo camino, el del backend, que es el que audita. |
| D3 | **`.or('email.ilike.%$b%,…')` con la entrada del usuario concatenada.** Se fue con D1, así que el vector desapareció. Verificado que era el único sitio de `lib/` con ese patrón. | — |
| D4 | **`uuid: ^4.0.0` declarada sin un solo import.** | Fuera de `pubspec.yaml`. `flutter pub get` la eliminó también del lock y de `package_config` (era directa, no transitiva). Build verificado. |
| D5 | **`conGuardiaEn`** sin llamadores. | Fuera. |
| D6 | **`UserRoleName`** (extensión de 14 líneas) sin un solo uso. | Fuera. |
| D7 | **`categoriaLegible`** sin usos. Su propio comentario decía «usada en las migas de pan», y era falso. | Fuera, con el comentario que mentía. |

**Verificación de D1/D2:** el test `test/usuario_admin_repository_test.dart`
mockea HTTP con el mismo payload, así que la ruta no cambia. No se pudo ejecutar
`flutter test` localmente —el sandbox no levanta `flutter_tester` (error 231)—,
pero el analizador de tipos da 243 archivos, 0 issues, y la suite E2E
`admin_cpanel_p0` (que incluye «Usuarios y Roles expone gestión real») pasa
**10/10** sin el fallback.

---

## Encontrado y **no** corregido, con la razón

Esto es tan importante como lo corregido: son cosas que el informe señaló y que
deliberadamente quedan como están.

### N1. `trustProxy: true` sin acotar (susceptible de suplantar el límite de intentos)

Los limitadores de `/auth` se clavean por `request.ip`, que con `trust: true`
viene de la entrada **más a la izquierda** de `X-Forwarded-For`, que es la que
controla el cliente. Si Render no sobreescribe la cabecera, rotarla anula la cuota
de 20/15 min que protege las rutas de fuerza bruta.

**No se toca** porque **no se puede verificar desde el repo**: depende del
comportamiento de Render, que no es observable aquí. Corregirlo a ciegas podría
romper el límite real (si Render sí sobreescribe, acotar el trust a una IP
inventada lo desactivaría). **Requiere una medición en producción**:

```bash
for i in $(seq 1 25); do
  curl -s -o /dev/null -w '%{http_code} ' -X POST \
    https://inces-lms-api.onrender.com/api/v1/auth/restablecer-codigo \
    -H 'Content-Type: application/json' -H "X-Forwarded-For: 10.0.0.$i" \
    -d '{"codigo":"000000000000","password":"xxxxxxxx"}'
done; echo
```

Si todas devuelven 429 salvo las de IP nueva, el límite funciona y no hay nada que
hacer. Si las de IP nueva devuelven 200, hay que acotar el `trustProxy`.

### N2. Vistas sin `security_invoker` (`v_cuadrante_clases`, `v_cuadrante_guardias`, `v_periodo_vigente`, `v_ocupacion_secciones`, `v_attendance_sesiones`)

En PostgreSQL una vista se ejecuta con los privilegios de su **dueño**. Si el
dueño tiene `BYPASSRLS` (comportamiento habitual del rol `postgres` en Supabase),
esas vistas exponen datos sin filtrar por RLS aunque estén concedidas sólo a
`authenticated`. `v_exportacion_hacer` ya lleva `with (security_invoker = true)`,
así que el patrón existe en el repo.

**No se toca** porque **no se puede comprobar desde el repo** si el dueño tiene
`BYPASSRLS`. La comprobación es contra la base:

```sql
select rolname, rolbypassrls from pg_roles
where rolname in ('postgres', 'authenticated');
```

Si `postgres` tiene `rolbypassrls = true`, aplicar `with (security_invoker = true)`
a las cinco vistas es una migración de bajo riesgo y alto valor. **Queda anotado
como la siguiente acción de seguridad con evidencia pendiente.**

### N3. `r2_key` viaja al cliente en todas las respuestas de archivos

Contradice el contrato declarado en `lib/models/archivo.dart` («nunca la ruta del
bucket»). No permite leer el objeto —la descarga exige URL firmada tras comprobar
RLS—, pero publica la topología interna del bucket.

**No se toca** porque quitarla exige tocar el modelo Dart, el repositorio, el
gateway y las pruebas a la vez, y el beneficio es de defensa en profundidad, no de
cierre de un agujero. Es refactor, no parche.

### N4. Duplicación masiva `cpanel_cuadrante_panel.dart` ↔ `cpanel_guardias_panel.dart`

191 líneas idénticas y 113 ventanas de 6 líneas compartidas entre dos archivos de
1.122 y 2.176 líneas. Es el sitio con mayor riesgo de deriva silenciosa del repo.

**No se toca** porque consolidarlo es reescribir dos paneles de producción con
comportamiento distinto (cuadrante de clases vs. guardias docentes). El ahorro
potencial es real, pero el riesgo de romper cualquiera de los dos en el proceso
también. **Queda como el refactor grande pendiente**, para hacerlo con calma y con
la matriz verde antes y después.

### N5. 42 exports muertos en el backend (mayormente alias `z.infer` en `esquemas.ts`)

Verificado que ningún archivo de `backend/` los referencia. Son alias de tipo: no
ocupan runtime.

**No se tocan** porque el valor es cosmético y el riesgo es no nulo —basta que un
test futuro importe uno por `import type`. Si se quieren quitar, es una pasada
mecánica con el analizador en verde después.

### N6. Cadena de altura muerta en `responsivo.dart` (`VentanaAltura`, `esAlturaCompacta`, `cabeDoblePanelLadoALado`…)

Verificado sin consumidores. Pero `docs/BACKLOG_PENDIENTES.md` la tiene como
**B3 ABIERTO con decisión «cablear»**, no «borrar». Borrarla contradiría una
decisión de producto pendiente.

### N7. Rate limit en memoria y por proceso

Con más de una instancia, o tras un reinicio, la cuota efectiva se multiplica y
los contadores se pierden. Hoy `render.yaml` declara una sola instancia free, así
que no se materializa.

**No se toca** porque es deuda que se activa sola al escalar, y escalar es una
decisión que no es mía.

---

## Lo que no se pudo verificar

- **N1 y N2**, por las razones de arriba: necesitan acceso a producción o a la base.
- **Eficacia real de las políticas RLS** contra un atacante con JWTs de cada rol.
  El repo incluye el arnés: `node supabase/tests/validate.mjs` (546 aserciones).
- **Que las migraciones aplicadas coincidan con las del repo.** Se verificó el
  2026-10-24 con `apply-migrations.mjs --check`: 50 aplicadas, 0 pendientes, 0 deriva.
- **Accesibilidad e i18n y deriva de documentación**: los dos subagentes
  encargados no llegaron a ejecutarse por el fallo de red del host.

---

## Verificación final

| Comprobación | Resultado |
|---|---|
| Backend (`npm run verify`) | **712/712** |
| Analizador Dart | 243 archivos, **0/0/0** |
| Build web | OK |
| E2E `admin_cpanel_p0` (paneles admin) | **10/10** |

---

## Lo que yo añadiría a esta lista

El informe del subagente de deuda no lo señaló, pero salió de cruzarlo con el de
seguridad: **`docs/BACKLOG_PENDIENTES.md` y `ESTADO_DEL_SISTEMA.md` mencionan
símbolos que acabo de borrar** (`conGuardiaEn`, `categoriaLegible`). Hay que
ajustarlos, y en general **la deriva de documentación sigue sin auditar** porque
ese subagente no corrió. Es la siguiente auditoría que lanzaría.
