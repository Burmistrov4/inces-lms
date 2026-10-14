# 05 — Ciclo de vida: cómo nace, se verifica y se despliega un cambio

## 1. El ritmo de trabajo (el contrato con Lorenzo)

1. **Diagnóstico y plan ANTES del código.** Se mide el estado real (leer el
   código, correr el comando, verificar la hipótesis) y se presenta el plan.
2. **Luz verde explícita por fase.** No adelantarse: cada fase se cierra con
   evidencia antes de abrir la siguiente.
3. **Cada decisión arquitectónica se explica con su porqué** (Lorenzo está
   aprendiendo y necesita criterio, no dependencia).
4. **Los bugs se señalan con archivo y línea**, sin endulzar.
5. **Las premisas de un encargo también se miden.** Un encargo no es una
   medición: es una hipótesis con formato de instrucción. El proyecto ya recibió
   uno con tres premisas falsas (decía «backend FastAPI con boto3»; es Fastify,
   y no hay un solo `.py`).

## 2. La vida de un cambio, paso a paso

### Paso 0 — Medir el punto de partida

- `git status --short --branch` y `git log -1` **antes** de editar.
- Releer el documento que se va a editar **justo antes** de editarlo: puede
  haber otro agente trabajando en el mismo archivo.
- Verificar que la premisa del cambio es cierta (leer el código, no el
  roadmap).

### Paso 1 — La migración (si el cambio toca el esquema)

- Nombre: `YYYYMMDDNNN_descripcion.sql` en `supabase/migrations/`, en orden.
- **NUNCA editar una migración ya aplicada.** Cambia su checksum y el libro
  mayor grita deriva. Se escribe otra que la corrija.
- **Toda autocomprobación dentro de una migración debe ser hermética**: se
  prueba inspeccionando catálogos (`pg_proc`, `pg_policies`) o llamando
  funciones puras con valores ficticios, **nunca** leyendo filas que nadie
  garantiza que existan (una base nueva tiene `sections` y `profiles` vacías:
  esa no-hermeticidad dejó el validador SQL rojo horas sin que nadie lo supiera
  —D20—).
- Aplicar a la nube: `node supabase/apply-migrations.mjs` (usa la Management
  API por HTTPS; la conexión directa a Postgres es sólo IPv6, D10). **Aplicar
  en producción requiere autorización explícita, revisión del SQL y plan de
  recuperación.** El modo `--check` es de sólo lectura y es el que se corre
  siempre primero.

### Paso 2 — El backend

- Contrato primero: esquemas Zod en `src/http/esquemas.ts`. El documento
  OpenAPI se **regenera** (`npm run openapi`); si la prueba del artefacto falla,
  se regenera, no se toca la prueba.
- Rutas nuevas: registrar en Fastify, documentar, y **dejar que el test de
  OpenAPI las coteje en las dos direcciones** contra el árbol real.
- Las escrituras con reglas van por RPC `security definer` cuando la RLS no
  alcanza; la RPC **debe autorizar sola con `auth.uid()`**.

### Paso 3 — El frontend

- La pantalla se monta **donde vive** en las pruebas (los paneles del cPanel,
  dentro de `ContenidoSeccion`; el panel de invitaciones, dentro del acordeón).
- Reglas de UI de `04_ARQUITECTURA.md` §2.
- Los tests de layout responsive se hacen con **widget tests a 375/768/1024/
  1280/1440 px**, no con capturas: una captura prueba un momento, un test
  protege el futuro.

### Paso 4 — Verificar con las cinco redes (cada una ve cosas que las otras no)

| Red | Comando | Qué ve | Qué **no** puede ver |
|---|---|---|---|
| Tipos/lints Dart locales | `node devops/analizar-dart.mjs` | errores, avisos **e infos** de todo `lib/` + `test/` | El SQL, la API, el navegador |
| Flutter suite | `flutter test` (en CI si el entorno local muere) | la lógica del cliente | El SQL, la API, la red, y **el navegador** |
| SQL real | `cd supabase/tests && npm test` (PGlite) | migraciones, triggers, RLS por rol | La API, el despliegue |
| Backend | `cd backend && npm run verify` | la API completa sobre dobles | La base real, las credenciales |
| Nube / E2E | humos con `--confirmar`; `e2e/` con Playwright | la cadena de verdad: API → GoTrue → Postgres → R2 → navegador | Lo que a nadie se le ocurrió probar |

**Regla de oro de la verificación:** una red sólo vale lo que vale su verde.
Un verde producido por un reintento mide el reintento. Una prueba cuyo montaje
no puede hacer lo que dice es un no-op silencioso. **La pregunta que caza
cualquier verde hueco: «¿qué tendría que ser distinto en el mundo para que esta
prueba fallara?»**

### Paso 5 — Commit y push

- **El push es el respaldo.** Un commit local no sobrevive a un `.git` dañado
  (ya pasó: se recuperó porque todo lo commiteado estaba subido).
- Dos ediciones al mismo archivo en un mismo mensaje: **una se pierde**. Ir de
  una en una.
- No commitear `.env`, `.env.json`, `build/`, `e2e/informe/`, ni archivos
  `_*.spec.ts` de diagnóstico.

### Paso 6 — CI (el verificador independiente)

Con el push corren los workflows de `03_STACK_TECNOLOGICO.md` §6. **`in_progress`
no es PASS**: se espera el veredicto del SHA exacto. Cuando el único sitio donde
algo se reproduce es la CI, **la CI es el banco de pruebas**.

### Paso 7 — Despliegue a producción

El procedimiento oficial completo está en `docs/PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md`
(revisado 2026-10-10). Resumen:

1. **Frontend:** workflow `web_bundle.yml` → compila con `API_BASE_URL` de
   producción → valida el artefacto (existen `index.html`, `main.dart.js`,
   `_headers`; el bundle contiene la API de producción y **no** contiene
   `localhost:3001`) → `wrangler pages deploy --project-name=inces-lms`.
   **Prohibido publicar un bundle compilado con la plantilla.**
2. **Backend:** Render despliega solo desde `main`; se confirma el deploy del
   SHA esperado y `GET /salud` → 200. Un `render.yaml` no demuestra que el
   despliegue terminó.
3. **Base de datos:** `apply-migrations.mjs --check` primero; aplicar **sólo**
   con autorización.
4. **Verificación posterior:** frontend público 200, bundle correcto, CORS
   desde el origen real, login y un flujo representativo con cuenta de prueba
   autorizada. **Registrar evidencia** (SHA, IDs de deploy, respuestas HTTP) y
   declarar explícitamente lo que **no** se pudo verificar.

## 3. El ciclo de vida de los datos

### Migraciones vs. semilla vs. humo (tres papeles distintos, no mezclar)

| Concepto | Qué hace | Dónde corre |
|---|---|---|
| **Migración** | Cambia el **esquema** (tablas, políticas, funciones). Nunca siembra aulas ni fechas de lapso: sería fabricar dato institucional | `supabase/migrations/`, libro mayor con checksum |
| **Semilla** (`sembrar-datos.mjs`) | Crea datos de ejemplo **persistentes** para que el sistema tenga con qué demostrarse: 1 carrera, 3 materias, 2 aulas `[SEMILLA]`, 1 sección, 1 docente + 3 estudiantes, 3 matrículas, 2 clases, 1 anuncio publicado + 1 tarea en borrador. Idempotente; `--limpiar` la deshace **por marcador** (`SEM-`, `[SEMILLA]`, `@semilla.invalid`; **no inventa cédulas**) | a mano, nunca al desplegar |
| **Humo** (`humo-*.mjs`) | Verifica contra la infraestructura real, **crea y purga** (cuentas `humo-*@ejemplo.invalid`, purga por prefijo, residuo medido 0/0/0) | a mano o en el ciclo de cierre; fuera de CI salvo la suite E2E |

**Regla de la semilla:** insertar cada fila en un estado que **no derive** otras
filas. Un anuncio publicado no deriva nada; una tarea publicada **sí** (el RPC
crea una entrega por matrícula): por eso la tarea se siembra en `BORRADOR`.

**Regla del humo:** un sembrado y un humo son contratos **opuestos**, y por eso
son archivos distintos.

### La limpieza

Las limpiezas borran **por marca**, no por id recordado: sobreviven a un
proceso que muere a mitad y no dejan residuo entre corridas. El orden de
borrado respeta las FK `on delete restrict` **y la simetría de la Regla 1 de
M2**: al sembrar, el programa se activa *después* de cargarle el pensum; al
limpiar, se desactiva *antes* de vaciárselo.

### Auditoría

Todo cambio de módulo o parámetro queda en `config_audit_log` (append-only, sin
camino de escritura para nadie salvo el trigger), y todo acceso en `auth_logs`
(IP, instante, éxito/fallo; escritura sólo por el backend). **Ni el admin puede
insertar una traza a mano**: hay una prueba que lo comprueba con JWT real.

## 4. El ciclo de vida de una estimación (rendimiento)

El proyecto mide el rendimiento por rol con instrumentos propios (5–7 muestras +
1 de calentamiento, mismo JWT, mismo puerto) y **mide la salud de la ruta en el
mismo puerto que mide** (un `3001` sirviendo un `dist` viejo produjo una vez una
medida inválida). El suelo conocido hoy: el hook de autenticación pesa ~240 ms
(verificación de token + perfil, ya en paralelo) y `cuadrante`, con tres
esperas secuenciales, está en ~679 ms.

## 5. Ciclo de vida documental (por qué este paquete existe)

- `ESTADO_DEL_SISTEMA.md` es el documento vivo que **manda** sobre los demás
  cuando se contradicen.
- La memoria del proyecto vive en `.workbuddy-ai/memory/` (índice + `temas/` +
  logs diarios).
- **La deriva documental se trata como una deuda:** una nota que dice «falta
  hacer X» envejece en la dirección peligrosa —provoca trabajo (el proyecto
  tiene documentado el caso de un aviso que pedía reaplicar cuatro migraciones
  ya aplicadas). **Una nota que dice «falta» hay que volver a medirla, no volver
  a creerla.**
- **La frontera entre deriva e historia:** las tablas de medición fechadas y los
  registros de fallos **conservan** el valor viejo (son historia); lo que se
  corrige son los comandos, las URL para abrir y los valores por defecto.
