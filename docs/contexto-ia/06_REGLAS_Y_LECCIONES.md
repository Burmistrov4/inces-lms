# 06 — Reglas y lecciones (léelo antes de tocar nada)

> Este archivo es el destilado de errores que **costaron caros**. Cada regla
> tiene su medición detrás. No son estilo: son facturas ya pagadas.

## 1. Las reglas load-bearing

1. **Medir antes de afirmar.** «No está» se mide, no se deduce. Una cifra de
   contraste no entra en un comentario si no sale del medidor. **Un volcado
   truncado no es evidencia.**
2. **«No se puede en este entorno» caducan como las cifras.** `flutter test` se
   dio por imposible dos veces y dos veces se midió que sí corría (con la
   receta exacta). Antes de repetir un «no se puede», medirlo otra vez. Y cuando
   la hipótesis es «lo bloquea el sandbox», hay que probarlo **fuera** del
   sandbox antes de seguir creyéndolo: es la única prueba que lo distingue de
   un fallo del host.
3. **Nunca editar una migración aplicada.** El libro mayor detecta deriva por
   checksum. Se añade otra.
4. **La frontera de autorización es la RLS, no la API** (ADR-003). Una
   `security definer` autoriza por sí misma con `auth.uid()`: la RLS **no** la
   protege (R-20).
5. **Dos ediciones al mismo archivo en un mensaje: una se pierde.** Y puede
   haber **otro agente** editando los mismos documentos: releer justo antes de
   editar; ediciones aditivas y acotadas.
6. **El push es el respaldo.**
7. **Un comentario que explica el porqué es una afirmación, y su mecanismo se
   mide.** Un comentario falso viaja igual que una cifra inventada. Este
   proyecto acumula cinco casos de comentarios que se justificaban a sí mismos.

## 2. El entorno de desarrollo: lo que hay que saber el minuto cero

### El `CreateFile failed 231` (`ERROR_PIPE_BUSY`)

- **Qué es:** el VM de Dart, al lanzar su primer subproceso, intenta crear una
  tubería *nombrada* y falla. Mueren `flutter test`, `flutter build web`,
  `dart analyze`, `flutter pub get`.
- **Historia medida, y por qué importa:** bloqueó de forma **sostenida** el
  2026-09-27 y el 2026-10-10 (el build murió 6 de 6 veces en `dart2js`); **no**
  se reprodujo el 2026-10-09 sesión 2 (build web en 157 s, suite completa
  verde). **Moraleja: es intermitente y pertenece al entorno, no al proyecto.
  Mídelo antes de citarlo, en cualquier dirección.**
- **La respuesta cuando bloquea: CI, no insistir en local.** `flutter_ci.yml` y
  `e2e.yml` corren en `ubuntu-latest`, donde el problema no existe.
- **Sustitutos locales que sí funcionan:** `node devops/analizar-dart.mjs`
  (tipos y lints de `lib/` + `test/`, lanzando el servidor de análisis
  directamente con `dartaotruntime.exe`; **su listón incluye las `info`**, igual
  que `flutter analyze`), y `devops/` tiene además utilidades de apoyo.
- **Nunca correr `dart format`** en este proyecto. Y atención: `dart format`
  comprueba **sintaxis, no tipos** —un identificador inexistente lo atraviesa
  entero.
- **En este equipo, desde Node: `spawn` y nunca `spawnSync`** (`spawnSync`
  falla con `EBUSY`: la misma familia de tuberías).
- **`build/web` local puede quedar congelado** en un artefacto viejo. Antes de
  auditar o publicar, comprobar de dónde viene: si hay archivos `.dart` más
  nuevos que `main.dart.js`, el build no es de hoy. **No publicarlo.**

### La receta de dos piezas (histórica, sigue siendo útil para otras órdenes de Flutter)

```
env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
  'NO_PROXY=127.0.0.1,localhost' 'no_proxy=127.0.0.1,localhost' \
  "PROGRAMFILES(X86)=C:\Program Files (x86)" flutter …
```

1. `PROGRAMFILES(X86)`: en Git Bash no existe (sin ella:
   `%PROGRAMFILES(X86)% environment variable not found`).
2. Proxy desactivado: `HTTP_PROXY`/`HTTPS_PROXY` apuntan a `127.0.0.1:61458` e
   interceptan el WebSocket de loopback de `flutter_tester`.

**Dar sólo una de las dos piezas hizo concluir una vez que era imposible.** Con
las dos corrió 365/365 ese mismo día.

### Flutter Web y Playwright (trampas medidas)

- CanvasKit **no expone widgets como DOM**: `getByRole`/`getByText` miden 0.
  Hay que pulsar `flt-semantics-placeholder` con `dispatchEvent` y usar
  `flt-semantics[aria-label=…]` / `getByLabel`. El `<canvas>` está en el shadow
  DOM de `flt-glass-pane`: `document.querySelectorAll('canvas')` da 0 con la app
  funcionando.
- `find.textContaining` busca en **toda** la pantalla: un subtítulo puede
  encontrarse dos veces («Matriculado» dentro de «Matriculados»). Las
  aserciones de texto se escriben **exactas** siempre que se pueda.
- `TextField` con `maxLength` **trunca en silencio** —fue el mecanismo exacto
  que dejó muerta la pantalla de asistencia del alumno (D21): el campo admitía
  6 caracteres y el parser exigía 43. El campo de código **no lleva
  `maxLength` a propósito**, y una prueba afirma que sigue siendo `null`.
- El bundle E2E local se corre con **`CI=true`**: sin él, `reuseExistingServer`
  reutiliza un servidor estático zombi de una corrida anterior y la suite muere
  a mitad con `ERR_CONNECTION_REFUSED`.
- **La guardia del bundle:** `e2e/playwright.config.ts` falla de inmediato si
  `main.dart.js` contiene los marcadores de la plantilla (`<project-ref>`,
  `<clave-publicable>`). Un bundle compilado con `dart-define.example.json`
  apunta a una URL inválida y el login falla **sin emitir ninguna petición**: el
  síntoma es «el formulario se envía y no pasa nada, ni error ni red». Medido
  el 2026-10-09 con nueve discriminadores.

## 3. Base de datos y autorización — las trampas finas

- **Una política RLS que llama a una función con `EXECUTE` revocado es
  inalcanzable** (`42501` antes de decidir nada). PostgreSQL evalúa el `EXECUTE`
  contra el rol que consulta. Fue D27: el alumno no podía marcar asistencia
  **nunca, por ningún camino**, y doce pruebas negativas estaban verdes por el
  mismo error. **No conceder `EXECUTE` si la función es un oráculo**
  (`asistencia_codigo_vigente` lo era: fuerza bruta de seis dígitos).
- **`revoke execute … from anon, authenticated` NO basta:** PostgreSQL concede
  `EXECUTE` a `PUBLIC` por defecto y el permiso se **hereda**. Hay que revocarlo
  de `PUBLIC` y concederlo a `service_role`. Medido en la nube el 2026-10-09.
- **Un `SQLSTATE` solo no distingue la causa:** `42501` puede ser falta de
  `GRANT` *o* RLS. Comprobar ambas, y **como qué rol** corre la prueba: probar
  un rechazo con un admin no prueba nada.
- **`information_schema` miente por omisión:** sólo muestra lo que el rol
  actual puede ver. Preguntar por claves ajenas que apuntan a `auth.users`
  devuelve **cero filas, no un error** —así se escaparon cuatro claves, una con
  `CASCADE` sobre `enrollments`. Usar **`pg_constraint`**. **Un cero se lee igual
  que «no hay nada»: peor que un error.**
- **`service_role` se salta la RLS, pero NO los triggers.** Un script con la
  clave secreta no puede escribir cualquier estado.
- **RLS es por fila; no puede ocultar una columna.** Para eso, GRANT a nivel de
  columna —y entonces `has_table_privilege(...,'SELECT')` es **false**.
- **`schema_migrations.version` guarda el nombre SIN `.sql`.** Comparar contra
  el nombre del archivo fabrica un «pendiente» falso.
- **`or=()` de PostgREST: columna y operador se separan con PUNTO**
  (`subject_id.in.(…)`), no con igualdad.
- **`PATCH` sin `Prefer: return=representation` responde 204 y sin cuerpo**: la
  escritura ocurre y no hay nada que leer para comprobarla.
- **Las fechas van a Postgres como `YYYY-MM-DD`**, no timestamp ISO: un ISO
  completo desplaza un día por zona horaria y rompe el CHECK de mayoría de edad.
- **Las vistas llevan `security_invoker`**: sin él corren con los privilegios de
  su dueño y se saltan la RLS de las tablas base (un estudiante vería el
  cuadrante de todo el centro).
- **El validador SQL corre como el dueño de las tablas**, y el dueño se salta
  la comprobación de `EXECUTE`: ése es su punto ciego (así vivió R-20). Hay una
  sección que escribe como `authenticated` con claims de admin para taparlo.
  **Si añades una prueba de trigger, pregúntate como qué rol está escribiendo.**
- **La conexión directa a Postgres es sólo IPv6** (D10): `supabase db push`
  falla con `ENETUNREACH`. La vía es `apply-migrations.mjs` por la Management
  API.

## 4. Pruebas — los verdes que no midieron

- **Una prueba cuyo montaje no puede hacer lo que dice es un no-op silencioso.**
  La prueba que fijaba que `m7_asistencia` no lleva guardia apagaba el módulo
  con un `.map` sobre una fila que **no existía** en la semilla: el verde medía
  el módulo **encendido** (D25). Arreglo: la fila entra en la semilla con los
  valores medidos en la nube y **la prueba afirma su propia premisa** antes de
  usarla. Verificado **por mutación** (renombrar la clave hace fallar la
  guarda): un guardián que nunca se ha visto fallar no se sabe si funciona.
- **La imagen simétrica: un rojo que no medía** (D26). Una prueba leía el reloj
  **dos veces** para el mismo código QR de 15 s: podía fallar por un cambio de
  ventana sin que nada del código estuviera mal.
- **Un doble debe reproducir CÓMO falla, no sólo qué devuelve.** El doble en
  memoria no puede reproducir el 416 de PostgREST, ni la colación exacta, ni el
  `42501` de la RLS: por eso cada repositorio nuevo necesita su **humo contra
  la base real**. (Caso real: el arnés devolvía el **mismo objeto** para
  `reposAdmin` y `reposDePeticion`, y un defecto real de permisos «funcionaba»
  en memoria; sólo se vio contra el motor.)
- **Un doble más estricto que el original convierte un arreglo correcto en un
  fallo de prueba** —y tienta a revertir el arreglo.
- **Una prueba puede consagrar el defecto como contrato** sin que nadie lo note
  (una prueba asertaba el 400 de un bug con un comentario que lo justificaba).
  Al arreglar un defecto, **buscar la prueba que lo daba por bueno.**
- **Probar cada capa por separado no prueba la composición**: un valor por
  defecto se arregló en el SQL y el esquema Zod tenía **su propio** `.default`
  que lo anulaba desde arriba. Al arreglar uno, buscar el mismo valor en las
  capas superiores.
- **Un verificador que no distingue «no hay nada» de «no estoy escuchando» es
  peor que no tenerlo** (un falso verde con el mismo aspecto que uno de verdad).
  Al escribir un verificador, comprobar primero que **ve** algo conocido —una
  sonda con un error deliberado— antes de creerle un verde.
- **Un verificador local vale lo que vale su primera pasada real.** El de Dart
  filtró las `info` durante días: verde local, CI rojo. El listón del
  verificador es el del CI: error, aviso **e info**.
- **Correr la suite COMPLETA (`flutter test`), no sólo el archivo tocado**: en
  el cierre de M2 los archivos sueltos daban verde y la suite completa destapó
  6 fallos.

## 5. Documentación y proceso

- **Un número escrito en dos sitios envejece siempre en el que nadie volvió a
  ejecutar.** Los totales viven en un solo sitio, con fecha.
- **Un «pendiente» viejo provoca trabajo** (reaplicar migraciones ya aplicadas,
  reescribir pruebas que existen). Volver a medirlo, no volver a creerlo.
- **Un documento puede contradecirse consigo mismo, y la contradicción es la
  señal.** Al corregir una afirmación, buscar la contraria en todo el documento:
  se busca la **frase**, no el archivo que uno recuerda.
- **Cuando un fallo de CI no se puede leer desde fuera, ése es el primer bug**
  (los registros de job exigen permisos de administración; las anotaciones no,
  y hay que publicarlas).
- **Medir y commitear en momentos distintos sobre un árbol que otro trabaja
  invalida la medición:** correr la suite completa **después** de la última
  edición, no antes.
- **`WebFetch` cachea por URL 15 minutos:** sondear la misma URL devuelve datos
  congelados. Cambiar la URL entre sondeos.
- **GitHub enmascara los secretos en los registros.** Nunca imprimir tokens;
  el `sbp_` de la Management API vive en `backend/.env` (gitignored) y se lee de
  ahí, no de la línea de órdenes.
- **La fecha del reloj inyectado puede estar mal:** verificar con `date` antes
  de sacar conclusiones de una marca de tiempo.

## 6. Si llegas con la misión de «arreglar X»

1. **Verifica la premisa** con código y comandos (el proyecto tiene un caso
   documentado de misión con tres premisas falsas).
2. **Lee primero** `02_ESTADO_ACTUAL.md` §5 (pendientes reales) y
   `08_GLOSARIO.md` (puede que X sea una deuda **cerrada** con número D/R).
3. **Respeta las puertas:** aplicar migraciones en producción, tocar RLS,
   cambiar CORS/secretos/dominios y promover administradores **requieren
   autorización explícita** de Lorenzo.
4. **Cierra la deuda en el documento el mismo día que en el código**, con su
   evidencia.
