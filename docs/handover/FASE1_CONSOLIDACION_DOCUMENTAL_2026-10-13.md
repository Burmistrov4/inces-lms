# Fase 1 — Consolidación documental (2026-10-13, 23:28 -04:00)

Sesión de **sólo documentación**, ejecutada sobre el estado real del árbol. Sin commit, sin
push, sin migraciones y sin despliegues. Todo lo que aquí se afirma se midió en esta sesión
o quedó marcado como heredado con su fecha.

## 1. Resultado

Los siete documentos canónicos quedan coherentes entre sí y con el repositorio:

| Criterio de aceptación | Estado |
|---|---|
| `docs/README.md` es el punto de entrada inequívoco | **cumplido** |
| `docs/CATALOGO_DOCUMENTAL.md` y `docs/ESTRUCTURA_DOCUMENTAL.md` concuerdan con el repositorio | **cumplido** (inventario recontado: 217 Markdown, 216 listados en el momento de la medición; 218/217 al añadir este registro. Desglose por categoría corregido el 2026-10-14: 72 + 16 + 130) |
| `AGENT_START_HERE.md` ofrece una ruta concisa y coherente | **cumplido** (nueve pasos; bloque histórico marcado como tal) |
| `ESTADO_DEL_SISTEMA.md` distingue evidencia actual de histórica | **cumplido** |
| Un único procedimiento oficial de despliegue | **cumplido** (las guías auxiliares quedaron catalogadas como históricas) |
| Los workflows documentados coinciden con los existentes | **cumplido** (siete, verificados uno por uno) |
| Los enlaces locales revisados funcionan | **cumplido** (115 enlaces, 0 rotos) |
| No se eliminaron documentos ni se alteraron funcionalidades | **cumplido** (`git status`: mismo conjunto de archivos que al empezar) |
| `git diff --check` termina sin errores | **cumplido** (exit 0) |

## 2. Archivos modificados y por qué

| Archivo | Cambio | Motivo |
|---|---|---|
| `ESTADO_DEL_SISTEMA.md` | Sección vigente reescrita: fecha con zona horaria, rama y SHA, arquitectura confirmada, servicios, pruebas realmente ejecutadas con su limitación, bloqueos reproducidos, riesgos, próximas acciones por prioridad | La sección anterior mezclaba heredado con medido y no llevaba zona horaria |
| `ESTADO_DEL_SISTEMA.md` | Se corrigió la regla «si algo aquí contradice a otro archivo, manda este», conservada como histórica | Ese documento se desincronizó cuatro veces en septiembre; la precedencia real está en la jerarquía |
| `docs/PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md` | §1.1 con los siete workflows reales, su disparo y su función; advertencia de que `web_bundle.yml` **no** publica y de que el APK es de depuración; §5.2 con la vía del artefacto de CI; §10.1 rollback y recuperación | El inventario listaba cinco workflows y faltaban dos; la auditoría adversarial citaba un «§5.2» inexistente; no había procedimiento de rollback |
| `docs/AI_AGENT_BLOCKERS.md` | Revalidación del 2026-10-13 en la cabecera, con comandos y códigos de salida, y marcas en las dos entradas que quedaron superadas | Contradicción medida: el 2026-10-09 dice que el `231` no se reproduce; el 2026-10-13 dice que sí bloquea |
| `docs/README.md` | Reescrito como índice por finalidad y público, con «por dónde entrar», precedencia resumida y dominios | Era el índice, pero le faltaban secciones exigibles (migraciones, roles, rollback, manuales, agentes) |
| `docs/CATALOGO_DOCUMENTAL.md` | §1 clasificación curada con propósito, público, estado, canónico relacionado y acción recomendada; §1.5 duplicados medidos; §2 inventario automático conservado como anexo | El catálogo sólo tenía ruta, tamaño y seguimiento Git |
| `docs/ESTRUCTURA_DOCUMENTAL.md` | Jerarquía de cinco niveles, cómo se resuelve una contradicción (no gana la más reciente) y registro de lo hecho en la Fase 1 | Hacía falta la jerarquía explícita y su límite (no autoriza ignorar decisiones de producto ni seguridad) |
| `AGENT_START_HERE.md` | Ruta obligatoria de nueve pasos, banco de pruebas medido y bloque del 2026-10-09 marcado como HISTÓRICO | Obligaba a leer prompts y planes antes de una tarea sencilla, y su bloque de estado contradice la medición actual |
| `README.md` (raíz) | El «Protocolo para agentes autónomos» remite a `AGENT_START_HERE.md` en vez de mandar a leer `AUTONOMOUS_AGENT_MASTER_PROMPT.md` | Dos rutas de lectura divergentes |
| `MEMORY.md` (raíz) | Nota que aclara que su lista es índice de memoria, no ruta de trabajo | Evitaba divergencia con `AGENT_START_HERE.md` |

### 2.1 Archivos creados, eliminados y modificados

| Categoría | Rutas | Evidencia |
|---|---|---|
| **Creado (1)** | `docs/handover/FASE1_CONSOLIDACION_DOCUMENTAL_2026-10-13.md` — este registro | Aparece en `git ls-files --others --exclude-standard` y **no** estaba al iniciar la fase |
| **Creados además (0)** | Ninguno. Los documentos `docs/README.md`, `docs/CATALOGO_DOCUMENTAL.md` y `docs/ESTRUCTURA_DOCUMENTAL.md` ya existían como no rastreados antes de esta fase; sólo se reescribieron | Consta en el `git status` del primer comando de la fase |
| **Eliminados (0)** | Ninguno | `git diff --name-status` no contiene ninguna línea `D` |
| **Modificados (24 al inicio, 26 al cierre)** | Los 24 preexistentes más `MEMORY.md` y `docs/AI_AGENT_BLOCKERS.md`, que estaban rastreados y limpios al empezar | `git diff --name-status`: 26 líneas, todas `M` |

Corregido el 2026-10-14: una versión anterior de este registro afirmaba «no se creó ni se borró ningún archivo del árbol», contradiciendo su propia creación.

## 3. Verificaciones ejecutadas

| Comando | Resultado |
|---|---|
| `git rev-parse --show-toplevel`, `git branch --show-current`, `git rev-parse HEAD` | raíz correcta, `main`, `ad5ce67` |
| `git rev-parse origin/main` | `ad5ce67` — HEAD y remoto coinciden |
| `git status --short` (inicio y final) | 24 modificados + 31 sin seguimiento → 26 modificados + 31 sin seguimiento; **ningún archivo perdido** |
| `npm run verify` (en `backend/`) | **685/685 en 33 archivos, exit 0**, 125,5 s |
| `dart pub get` con `FLUTTER_ROOT=/c/Users/Loro/develop/flutter` | **exit 0**, «Got dependencies!» |
| `node devops/analizar-dart.mjs` | **226 archivos, 0 errores/avisos/infos, exit 0** |
| `git diff --check` (repetido al final) | **exit 0** |
| Verificador estricto de enlaces sobre los 8 documentos tocados | **115 enlaces locales, 0 rotos** |
| Verificador de anclas | 4 anclas, 0 rotas |
| Verificador de rutas citadas en el catálogo | 53 rutas `.md`, 0 inexistentes |
| Recuento de Markdown del árbol | 217 total, 216 listados (coincide con el catálogo) |

> **Nota de la auditoría de cierre (misma fecha):** este 217/216 es el recuento **en el
> momento de medirlo**, antes de que existiera este documento. Al añadir este registro el
> total pasó a **218 Markdown, 217 listados**, y el catálogo y
> `docs/ESTRUCTURA_DOCUMENTAL.md` se corrigieron para no dejar la cifra desfasada.
> La lección es la de siempre: un conteo sin su fecha es una nota, no un dato.
>
> **Corrección del 2026-10-14 (cierre de Fase 1):** el desglose que entonces se dio
> («72 rastreados + 145 sin rastrear») **era incorrecto**. Medido con
> `git ls-files`, `git ls-files --others --exclude-standard` y
> `git ls-files --others --ignored --exclude-standard`, los 218 se reparten en
> **72 rastreados + 16 no rastreados y no ignorados + 130 ignorados** por `.gitignore`
> (`.agents/`, `.claude/skills/`, `.workbuddy-ai/`, `No subir esta carpeta…`, etc.).
> Los 145 anteriores mezclaban dos categorías distintas: 16 archivos realmente sin
> seguimiento y 129 cubiertos por reglas de ignorado. El anexo del catálogo quedó
> re-etiquetado entrada por entrada (72 `git`, 15 `no rastreado`, 130 `ignorado`;
> el catálogo se excluye a sí mismo, por eso el anexo suma 217 y no 218).
| Comparación de contenido `contexto-ia/` vs `contexto-ia-unificado/` | 1031 de 1497 líneas idénticas, 86 propias → duplicado sustancial, no exacto |
| Búsqueda de patrones de secreto en los documentos tocados | sin coincidencias |

**No ejecutado en esta sesión:** `flutter test`, `flutter analyze`, `flutter build web`,
build Android local (bloqueados con `231` + JRE 8), E2E contra bundle fresco, ni
`supabase/apply-migrations.mjs --check` contra la nube. Sus cifras no se citan como
vigentes.

## 4. Contradicciones resueltas con evidencia

1. **Precedencia de `ESTADO_DEL_SISTEMA.md`.** Afirmaba mandar sobre todo; se desincronizó
   cuatro veces en septiembre. **Resuelto:** gana el código y los workflows. La regla
   antigua quedó registrada como histórica en el propio archivo.
2. **El `CreateFile failed 231`.** El 2026-10-09 se midió «no reproducible»; el 2026-10-13,
   «bloquea de forma sostenida». **Resuelto:** manda la medición más reciente, con ambas
   conservadas y la indicación de re-medir antes de citarlo.
3. **`RELEASE_AUDIT_20261010_0302.md`** afirma `flutter build web --release` PASS. La
   medición del 2026-10-13 lo contradice. **Resuelto:** catalogado como «obsoleto pendiente
   de revisión», con la razón escrita.
4. **`AUTONOMOUS_AGENT_MASTER_PROMPT.md` como paso 6 de lectura obligatoria** en el README
   raíz. **Resuelto:** los prompts pasan a histórico y la ruta canónica es
   `AGENT_START_HERE.md`.
5. **Cinco archivos de planilla citados como si estuvieran en `docs/`** cuando están en la
   raíz. **Resuelto:** corregido en el índice y en el catálogo.

## 5. Contradicciones no resueltas (requieren decisión o medición externa)

1. **`docs/contexto-ia/` frente a `docs/contexto-ia-unificado/`** (duplicado D-1): son
   sustancialmente el mismo contenido. No se eliminó ninguno. **Falta decidir el canónico.**
2. **Cifras de producción dentro de `docs/contexto-ia/`** (verificadas el 2026-10-10): no se
   revalidaron contra los servicios en esta sesión porque verificar producción no era el
   objeto de la Fase 1. Quedan marcadas como «caducas por diseño».
3. **Estado de la nube (migraciones aplicadas, drift)**: la última medición es del
   2026-10-09 (46 aplicadas, 0 pendientes, 0 deriva). No se re midió: requiere
   `SUPABASE_ACCESS_TOKEN` y la sesión no lo cargó.
4. **`npm run build` del backend**: su PASS es de la auditoría del 2026-10-13; no se
   reejecutó aquí, y así quedó escrito.

## 6. Duplicados para una fase posterior (no eliminados)

| Id | Qué | Acción propuesta |
|---|---|---|
| D-1 | Paquete `contexto-ia/` (9 archivos) vs `contexto-ia-unificado/` (1 archivo) | Elegir canónico y convertir el otro en un enlace |
| D-2 | Seis copias de la skill `archify` bajo `.agents/`, `.claude/`, `.codebuddy/`, `.continue/`, `.hermes/`, `.workbuddy-ai/skills/` | Son copias de herramienta con SHA idéntico: no confundir con duplicados de documento |
| D-3 | Varios `PROMPT_*`/`MEGA_PROMPT_*` de raíz con objetivos solapados | Consolidar en un índice de prompts obsoletos |
| D-4 | `HANDOVER.md` (2.785 líneas) y `HANDOVER_CHAT_NUEVO.md` (392) | El extracto debería enlazar al canónico |

## 7. Pendientes y riesgos

- **31 archivos sin seguimiento siguen sin clasificar**, en particular `.wrangler/`,
  `deploy-ad5ce67/` y las 13 sondas de `e2e/tests/_*.spec.ts`. **No borrarlos ni subirlos
  en bloque**: varios son artefactos de depuración ajenos a esta sesión.
- **Los cambios de la noche nunca se compilaron en CI.** Localizaciones, Android,
  `robots.txt` y `sitemap.xml` existen en el árbol sin verificación de workflows.
- **`flutter_localizations` exige `intl ^0.20.3`**: un pin hacia abajo rompe los cuatro
  workflows en su primer paso.
- **Sin commit, push, migración ni despliegue** en esta sesión. Publicar exige autorización
  explícita del propietario.
- Restricciones externas abiertas: clave de firma para Play, SMTP/Resend (401),
  `SUPABASE_JWT_SECRET`, los 6 secretos del barrido D9, lista de campos de HACER (D17).

## 8. Siguiente paso — transición a la Fase 2

Preparado, **no ejecutado**. La Fase 2 natural es la verificación en CI de lo que la Fase 1
sólo documentó:

1. Revisar el diff íntegro y clasificar los 31 sin seguimiento.
2. Obtener autorización para commit + push → corren `flutter_ci.yml` (analizador real y
   suite), `e2e.yml` (bundle fresco + SEO), y a mano `web_bundle.yml` y `android_bundle.yml`.
3. Con esos códigos de salida, actualizar `ESTADO_DEL_SISTEMA.md` y levantar los BLOCKED que
   queden probados.
4. Sólo entonces desplegar el artefacto `web-produccion` (§6 del procedimiento) y comprobar
   en producción `robots.txt` como `text/plain` y `sitemap.xml` como XML.

Mientras tanto, la puerta de entrada para cualquier agente sigue siendo
`AGENT_START_HERE.md` → `docs/README.md`.

---

## 9. Cierre de la Fase 1 (2026-10-14)

Sesión de cierre: sólo documentación, sin commit, push, migración ni despliegue. HEAD sigue en
`ad5ce67`, igual que `origin/main`. Corrige tres cosas que el informe anterior dejó
inconsistentes y añade la evidencia que faltaba.

### 9.1 Inventario Markdown reconciliado

El informe anterior daba simultáneamente 218 Markdown, 217 listados, 72 rastreados, **145 sin
rastrear** y 80 archivos sin seguimiento de cualquier extensión. Las dos últimas cifras son
incompatibles: 145 Markdown no caben en 80 archivos de todas las extensiones. Medido con
fuentes separadas y cada ruta contada una sola vez:

| Categoría | Nº | Comando |
|---|---|---|
| Rastreados | **72** | `git ls-files '*.md'` |
| No rastreados **y no ignorados** | **16** | `git ls-files --others --exclude-standard '*.md'` |
| Ignorados por `.gitignore` | **130** | `git ls-files --others --ignored --exclude-standard '*.md'` + 1 con `git check-ignore` |
| **Total** | **218** | recorrido del disco con exclusiones declaradas |

La cifra de 145 era la suma de las dos categorías intermedias: 16 sin seguimiento real y 129
ignorados (`.agents/`, `.claude/skills/`, `.workbuddy-ai/`, `No subir esta carpeta…`). El
anexo del catálogo quedó re-etiquetado entrada por entrada —72 `git`, 15 `no rastreado`,
130 `ignorado`; el catálogo se excluye a sí mismo, por eso suma 217— y las cabeceras de
`docs/CATALOGO_DOCUMENTAL.md`, `docs/ESTRUCTURA_DOCUMENTAL.md` y `ESTADO_DEL_SISTEMA.md` se
corrigieron con la tabla y la metodología. Los 80 sin seguimiento son de cualquier extensión;
no tienen nada que ver con los 16 Markdown.

### 9.2 Comando de rollback que no existía

`docs/PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md` documentaba
`npx --yes wrangler pages deployment rollback --project-name=inces-lms <DEPLOYMENT_ID>`.
**Medido el 2026-10-14**: `npx --yes wrangler@latest pages deployment --help` (Wrangler
4.151.0, exit 0) sólo lista `list`, `create`, `tail` y `delete`; `pages project --help` sólo
lista `list`, `create` y `delete`. No existe subcomando de rollback, y `--project-name`
tampoco es opción de esos subcomandos. La documentación oficial de
[Rollbacks](https://developers.cloudflare.com/pages/configuration/rollbacks/) describe el
panel (Deployments → menú de tres puntos → *Rollback to this deployment*), que es lo que la
§10.1 ahora declara procedimiento principal, con la API
`POST /accounts/{account_id}/pages/projects/{project_name}/deployments/{deployment_id}/rollback`
como alternativa. `wrangler pages deployment list --project-name=inces-lms` sí existe y se
conserva para identificar el objetivo. Queda anotado que Wrangler no está fijado en el
repositorio: los comandos usan `npx --yes`, que resuelve la última versión publicada.

### 9.3 Lo local frente a GitHub

`origin/main` está en `ad5ce67`. En esa rama **no existen** `docs/README.md`,
`docs/CATALOGO_DOCUMENTAL.md`, `docs/ESTRUCTURA_DOCUMENTAL.md`, este registro,
`web/robots.txt`, `web/sitemap.xml` ni `.github/workflows/android_bundle.yml`, y su
`pubspec.yaml` mantiene `intl: ^0.19.0`. Las corridas verdes de CI que se ven en GitHub
corresponden a `ad5ce67`, así que no cubren ninguno de estos cambios. La Fase 1 no publicó
nada y la Fase 2 sigue siendo quien lo verifique.
