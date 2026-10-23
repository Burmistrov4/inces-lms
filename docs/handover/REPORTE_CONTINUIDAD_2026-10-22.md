# REPORTE DE CONTINUIDAD — INCES LMS (2026-10-22)

> **Para qué es este archivo.** Lorenzo puede quedarse sin tokens a mitad de una
> sesion. Este informe esta escrito para que **otro agente de IA con contexto
> fresco** pueda retomar el trabajo sin repetir lo ya medido ni volver a pisar
> las mismas trampas. Léelo entero antes de tocar codigo.

---

## 1. TL;DR — el estado en 10 lineas

1. Proyecto: LMS del CFS Nacional de Soldadura "Rafael Urdaneta" (INCES La
   Isabelica). TEG de 4to semestre, IUTEPI. Tutor: Maglis Camacho.
2. Stack: Flutter Web + Supabase (PG) + Node/TS (Fastify 5 + Zod, ESM) + R2.
   3 roles: admin, docente, aspirante.
3. **Analizador: 241 archivos, 0 errores / 0 avisos / 0 infos.** Es el sustituto
   local de `dart analyze` (que muere con el error 231 del sandbox).
4. **Matriz responsive: 186 capturas (29 apartados x 6 perfiles + publicas),
   0 no navegables, 0 page errors.** Galeria: `docs/assets/matriz/index.html`.
5. **Los unicos "desbordes" que quedan son la rejilla de horarios** (`Horarios de
   Clases` y `Mi horario`): es scroll horizontal intencional. Punto **B5**.
6. Esta sesion cerro: navegacion muerta (E1), breadcrumbs (E2), barra de cuota
   (E3), encabezado (E4), nombre "Cloud CFS" (F4), cuota real (G1), tarjeta
   informativa cerrable (G2), Guardias adaptativo (G5), buscador expandible (G7),
   formularios acotados (G8).
7. **La conectividad local estaba rota y ya se diagnostico**: el backend
   escuchaba solo IPv4 y `localhost` resolvia a IPv6. Ver seccion 3.
8. Pendientes en orden logico: **B5, A1, G6, G9 (acotado), F1 > F2 > F3**.
9. Objetivo primordial de Lorenzo: que la app sea **intuitiva, responsive como
   la de Google y a prueba de errores**, usable por un profesor mayor. Una
   captura fea es un defecto.
10. **Regla de oro: medir antes de afirmar.** Ninguna cifra entra en un
    comentario si no sale de un medidor. Un volcado truncado no es evidencia.

---

## 2. Como verificar (comandos exactos, medidos)

Todos desde la raiz del repo. `node` = el gestionado
(`C:/Users/Loro/.workbuddy-ai/binaries/node/versions/22.22.2-6/node.exe`).

| Que | Comando | Resultado esperado |
|---|---|---|
| Analizar Dart (sustituto del analyzer) | `node devops/analizar-dart.mjs` | `241 archivos, 0 errores/avisos/infos` |
| Backend (pruebas) | `cd backend && npm run verify` | suite en verde |
| Compilar front | `flutter build web --release --dart-define-from-file=.env.json` | `Built build/web` |
| Matriz completa con datos reales | ver seccion 3 | 186 capturas, 0 no navegables |
| Regenerar galeria | `node C:/tmp/gen_galeria.mjs` | `docs/assets/matriz/index.html` |

**No serves:** `dart analyze`, `dart format`, `flutter analyze`, `flutter test`.
Mueren con `CreateFile failed 231` (bloqueo del sandbox de Windows sobre
cualquier VM de Dart que spawnea un hijo). La respuesta es CI + los sustitutos,
no insistir en local.

---

## 3. TRAMPAS MEDIDAS DEL ENTORNO (no las redescubras)

### 3.1 El backend tiene que arrancar en dual-stack o `localhost` falla

**Sintoma:** la app muestra "No pudimos conectar con el servidor" y spinners
infinitos, aunque el backend este corriendo.

**Causa medida:** el backend escuchaba en `0.0.0.0` (solo IPv4) y la app llama a
`localhost`, que en Windows resuelve a `::1` (IPv6) -> `ERR_CONNECTION_REFUSED`.

**Comprobado:** con `HOST=0.0.0.0`, `curl http://localhost:3001/salud` -> 000.
Con `HOST=::` -> **200** (y `netstat` muestra `0.0.0.0:3001` + `[::]:3001`).

**Como correr la matriz con datos reales (receta que funciona):**

```bash
BASE="/c/Users/Loro/Desktop/Cuarto Semestre/1. Servicio Comunitario/INCES-LMS-PROJECT"
PID=$(netstat -ano | grep ":3001" | grep -i LISTENING | awk '{print $NF}' | head -1)
[ -n "$PID" ] && taskkill //F //PID "$PID"      # mata huerfanos, si no se reutiliza uno viejo
cd "$BASE/backend"
HOST=:: node --env-file-if-exists=.env dist/server.js > C:/tmp/bp.log 2>&1 &
SRV=$!
for i in $(seq 1 10); do sleep 3; code=$(curl -s -o /dev/null -w "%{http_code}" --noproxy '*' --max-time 3 http://localhost:3001/salud); [ "$code" = "200" ] && break; done
cd "$BASE/e2e"
E2E_ARRANCAR_BACKEND=0 E2E_MATRIZ=1 node node_modules/@playwright/test/cli.js test matriz_responsive --reporter=list
kill $SRV
```

**Detalles que costaron medirlos:**

- El backend tarda **~13 s** en escuchar. Un `sleep 7` no basta: usa el bucle de
  reintentos de arriba.
- `env: { HOST: '::' }` en el `webServer` de `playwright.config.ts` **NO** aplica
  al proceso hijo. Por eso la receta arranca el backend a mano y usa
  `E2E_ARRANCAR_BACKEND=0`.
- `HOST=::` puesto dentro de `backend/.env` **no** funciona (el proceso colgaba
  sin escuchar). Usar el override del shell.
- `e2e/serve.mjs` ahora fija `HOST='0.0.0.0'` a proposito: si hereda el `HOST=::`
  del backend, el navegador no carga la pagina en `127.0.0.1:8090`.
- **Pendiente (A1):** hacer permanente el dual-stack en el backend
  (`src/config/env.ts`, default `HOST` -> `::`) para no depender del arranque
  manual en Windows. Ojo: la CI corre en Linux, donde `localhost` -> IPv4 y no
  se sufre el problema.

### 3.2 La sonda de red: como saber QUE endpoint falla

`e2e/tests/diag_red.spec.ts` (se creo y borro; recrearla si hace falta) registra
respuestas HTTP >= 400 y `requestfailed`:

```ts
page.on('response', (r) => { if (r.status() >= 400) console.log(`[HTTP ${r.status()}] ${r.url()}`); });
page.on('requestfailed', (r) => console.log(`[FAILED] ${r.method()} ${r.url()} :: ${r.failure()?.errorText}`));
```

Correr con `E2E_DIAG=1 node node_modules/@playwright/test/cli.js test diag_red`.
Ojo: en `requestfailed` el parametro **ya es un `Request`**: usar `r.method()`,
no `r.request().method()`.

### 3.3 El detector de desborde dice QUE nodo, no solo cuanto

`e2e/tests/matriz_responsive.spec.ts`, funcion `medirDesborde`, devuelve
`{ max, cuantos, total, peor: { texto, x, w } }`. Eso convirtio un "297 px" opaco
en la linea exacta que habia que corregir. **Instrumentar el detector antes de
adivinar** donde esta el desborde.

### 3.4 Trampas de edicion que ya rompieron el build

- **`cd backend && node ... &` lanza el compound en un subshell**: el `cd ..`
  siguiente sale del proyecto y el analizador no encuentra el script. Poner el
  `cd` en su propia linea.
- **Dos funciones con preambulo IDENTICO + `replace_all`**: en
  `cpanel_guardias_panel.dart`, `_matrizSemanal` y `_pizarraMural` empiezan
  igual; el `replace_all` envolvio las dos y los cierres hay que ponerlos en la
  funcion correcta. Revisar con `grep -n "^  Widget _"` antes y despues.
- **Git Bash corrompe backslashes dentro de un heredoc** (`\s` -> `/s`). No
  verificar con expresiones que lleven backslashes via heredoc.
- **Nunca leer `$?` despues de un pipe**: se lee el exit code del ultimo
  comando del pipe, no el que importa.

---

## 4. CERRADO ESTA SESION (con evidencia, no reabrir sin medir)

| # | Que | Evidencia |
|---|---|---|
| E1 | **Toda la navegacion estaba muerta.** `onTap: () => conGuardia(...)` llamaba a `conGuardia` y **descartaba el callback** que devolvia. ~30 sitios. Compilaba sin error, por eso no se veia. | `conGuardia`/`conGuardiaEn` ahora ejecutan de inmediato y devuelven `void`. Matriz: 29/29 apartados navegan (antes 0/29). |
| E2 | La matriz debe usar `pulsar` (dispatchEvent) para el menu; `pulsarReal` solo abre modales. | Cambiado en `matriz_responsive.spec.ts`. |
| E3 | El Gestor (hoy **Cloud CFS**) desbordaba 297 px a 390. | `_construirBarraCuota` reescrita: dos filas hasta `expanded`, una con `Flexible` desde 840. **0 px en los 6 perfiles.** |
| E4 | El encabezado quedaba en "Ge.../Ar...". | En compacto: titulo "Cloud CFS", sin subtitulo, sin toggle cuadricula/lista, "Nuevo" como icono "+". |
| F4 | Nombre del modulo. | **"Cloud CFS"** en menu, breadcrumb, accesos rapidos, walkthrough y encabezado. |
| G1 | La cuota mostraba "1.84 GB de 10 GB" con la nube casi vacia. | Era `static const double _cuotaUsadaGb = 1.84`. Ahora se calcula sumando `tamanoBytes` de los archivos listados y se formatea (MB si < 0.1 GB). Con las semillas: "6.8 MB". |
| G2 | La tarjeta "Almacenamiento Hibrido..." no se podia cerrar. | Boton X (`_mostrarTarjetaInfo`). |
| B1 | El sidebar a 840 ocupaba una columna de 280 px. | Rail en `expanded` (840-1199) y **solo iconos** (`NavigationRailLabelType.none`, ~80 px); menu permanente solo en `large`+ (>=1200). A 840 el contenido pasa de 1 a 3 columnas. |
| G5 | Guardias desbordaba 15/11/111 px. | `TituloSeccion` con acciones en `Wrap` acotado por `Flexible` (beneficia a todas las cabeceras) + rejilla de ancho adaptativo. **0 px en los 6 perfiles.** |
| G7 | El buscador se veia "Bu..." a 390. | **Lupa que se expande a ancho completo** (`_buscando`, autofoco, flecha para volver). Filtra en vivo por nombre. |
| G8 | Campos de formulario estirados a ~1300-1400 px a 1700. | `cpanel_invitaciones_panel` y `perfil_panel` acotados con `ConstrainedBox(maxWidth: 720)`. |

---

## 5. PENDIENTES EN ORDEN LOGICO

### B5 — Rejilla de horarios en movil (el mas visible)

**Que:** `Horarios de Clases` (admin) y `Mi horario` (docente) son una tabla de
~1124 px con scroll horizontal. Funciona, pero en movil obliga a arrastrar y se
ve cortada. Es el unico "desborde" que reporta la matriz.

**Como lo sugiere Lorenzo:** selector de dia + lista vertical.

**Pista medida:** `cpanel_horarios_panel.dart` (admin) y el panel de horario del
docente. La tabla tiene columnas de ancho fijo; el patron que ya funciona en
Guardias es `LayoutBuilder` + ancho adaptativo, pero para movil lo correcto es
cambiar de forma (tabla -> lista por dia), no solo encoger.

### A1 — Dual-stack permanente en el backend

Cambiar el default de `HOST` a `::` en `backend/src/config/env.ts` (o quitar
`HOST` de `backend/.env`) para que Windows no dependa del arranque manual.
Verificar que la CI (Linux) sigue verde.

### G6 — "Inscripciones y Cupos" no navego una vez

Transitorio. Repetir la matriz; si se repite, revisar si el breadcrumb coincide
con el de la seccion anterior o si la seccion tarda en montar.

### G9 — Patron de enfocado en los campos de busqueda (ACOTADO, no un refactor global)

Lorenzo aclaro: **no** es unificar todos los buscadores (suena peligroso), sino
aplicar el **mismo patron de enfocado** donde se escribe: lupa en la barra, y al
tocarla el campo se expande a ancho completo y recibe el foco. Ya esta en
Cloud CFS. Paneles con buscador inline pendientes: **Usuarios y Roles**
(`cpanel_usuarios_roles_panel.dart`, toolbar de filtros), **Aulas**
(`cpanel_aulas_panel.dart`), **Programas** (`cpanel_programas_panel.dart`).
Hacerlos **de uno en uno**, verificando cada uno con la matriz. Los buscadores
dentro de dialogos (Guardias, Cuadrante) ya estan bien.

### F1 > F2 > F3 — Multi-nube con Google Drive (producto, en ese orden)

Guardado por Lorenzo el 2026-10-21. **No implementar antes de estabilizar lo
anterior.**

- **F1:** login con cuenta Google + importar/gestionar Drive como **espejo**
  (los archivos siguen en Drive; R2 se reserva y nunca se agota).
- **F2:** si un archivo pasa de 25 MB, **ofrecer enlace de Drive** en vez de
  rechazarlo.
- **F3:** visores/editores dentro de la app: doc/docx, xlsx/xls (incluidos
  formatos viejos), **PDF** (ver y editar), **PPTX** (ver y editar).

---

## 6. DECISIONES DE DISENO Y SU POR QUE

| Decision | Por que |
|---|---|
| Rail solo-iconos en `expanded`, menu permanente en `large`+ | Material 3. A 840 un menu de 280 px deja el contenido en 1 columna; el rail de 80 px lo deja en 3. |
| Etiquetas cortas en la barra inferior (`etiquetaCorta`) | 5 destinos con titulos largos se amontonaban a 390. El menu lateral conserva los nombres completos. |
| Rejillas de ancho adaptativo (`LayoutBuilder` + `clamp`) | Columnas fijas desbordaban. Asi cabe sin scroll desde ~840 y solo arrastra en movil. |
| Formularios acotados a 720 px | Una linea de texto de 1300 px cansa la vista y cuesta encontrar el campo. |
| Buscador como lupa que se expande | Un campo inline de 260 px se ve "Bu..." a 390 y no se puede escribir comodo. |
| Cuota calculada, no constante | Un valor de demo que no cambia confia mal al usuario. |
| Tarjetas informativas cerrables | Ocupan media pantalla sin poder quitarse. |
| **Una captura fea es un defecto** | Criterio de Lorenzo: la app la usan profesores mayores; debe verse bien Y entenderse. |

---

## 7. MAPA DE ARCHIVOS CLAVE

| Archivo | Que es |
|---|---|
| `lib/widgets/responsivo.dart` | **Clases de ancho/alto de Material 3** (`Ventana.compact/medium/expanded/large/xlarge`) y helpers `esCompacto/esMedio/esEscritorio`. Fuente de verdad del responsive. |
| `lib/widgets/andamiaje.dart` | Andamio de los dashboards: barra inferior (compact), rail (medium+expanded), menu permanente (large+), cajon lateral, transiciones. `ItemNavegacion.etiquetaCorta` vive aqui. |
| `lib/widgets/comunes.dart` | `TituloSeccion` (acciones en `Wrap` acotado), `AvisoEnLinea`, `PanelVacio`, `rejillaDeTarjetas`, etc. |
| `lib/widgets/guardia_toque.dart` | `conGuardia` / `conGuardiaEn` (anti doble-clic). **Ejecutan de inmediato y devuelven `void`.** |
| `lib/screens/admin_dashboard.dart` | Menu y switch de secciones del admin. La seccion de archivos se llama **"Cloud CFS"**. |
| `lib/screens/admin/cpanel_explorador_archivos_panel.dart` | **Cloud CFS**: buscador expandible, barra de cuota adaptativa, tarjeta informativa cerrable. |
| `lib/screens/admin/cpanel_guardias_panel.dart` | Guardias: `_matrizSemanal` y `_pizarraMural` con rejilla de ancho adaptativo. |
| `lib/screens/admin/cpanel_invitaciones_panel.dart` | Invitacion de docentes (formulario acotado a 720 px). |
| `lib/screens/perfil_panel.dart` | Perfil del usuario (formulario acotado a 720 px). |
| `lib/screens/admin/cpanel_usuarios_roles_panel.dart` | Usuarios y Roles (toolbar de filtros con buscador inline -> pendiente G9). |
| `e2e/tests/matriz_responsive.spec.ts` | **La matriz.** 29 apartados x 6 perfiles + superficies publicas. `medirDesborde` reporta el nodo peor. |
| `e2e/serve.mjs` | Servidor estatico del front para las pruebas. **Fija `HOST='0.0.0.0'` a proposito.** |
| `e2e/playwright.config.ts` | Config de Playwright: webServer del front y del backend, credenciales de prueba. |
| `docs/BACKLOG_PENDIENTES.md` | **Backlog vivo**: secciones A (pruebas), B (responsive), E (bugs de sesion), F (producto), G (hallazgos). |
| `docs/assets/matriz/` | Capturas PNG por rol + `index.html` (galeria) + `reporte.json`. |
| `.workbuddy-ai/memory/2026-10-21.md` | Log diario con lo medido (incluye las trampas de la seccion 3). |

---

## 8. CONVENCIONES DEL PROYECTO (respetalas)

1. **Espanol** para todo lo que escriba Lorenzo o la UI. Las cadenas tecnicas
   (comandos, rutas, salidas) se dejan tal cual.
2. **Medir antes de afirmar.** "No esta" se mide. Una prueba no puede afirmar que
   algo falla sin medirlo con el mismo instrumento con el que afirma que pasa.
3. **Una deuda se cierra en el documento el mismo dia que en el codigo.**
4. **Un conteo de pruebas se lee del CI, no se deduce del diff.**
5. Cuando el unico sitio donde algo se reproduce es la CI, **la CI es el banco
   de pruebas**.
6. **Detectar no es recuperar.** Diagnosticar antes de construir.
7. Lorenzo **pide diagnostico y plan antes de que se escriba codigo**, y da luz
   verde explicita para avanzar de fase. Respetar ese ritmo.
8. Le molesta el relleno y que se afirme algo sin verificar.

---

## 9. POR DONDE EMPEZAR (primera accion recomendada)

1. Leer `docs/BACKLOG_PENDIENTES.md` (esta sincronizado con este informe).
2. Confirmar el estado: `node devops/analizar-dart.mjs` -> 241, 0/0/0.
3. Ir a **B5** (rejilla de horarios en movil): es el ultimo defecto visible que
   reporta la matriz y el que Lorenzo pidio explicitamente.
4. Verificar con la receta de la seccion 3.1 (backend dual-stack + matriz).
5. Regenerar la galeria (`node C:/tmp/gen_galeria.mjs`) y presentarla.
6. **Actualizar `docs/BACKLOG_PENDIENTES.md` y `.workbuddy-ai/memory/` el mismo
   dia** (convencion 3), para que el siguiente agente encuentre el terreno
   limpio.

**Si algo de este informe contradice al codigo, gana el codigo.** Y si una cifra
de aqui no se puede reproducir con el comando indicado, trátala como falsa hasta
medirla de nuevo.

---

*Generado el 2026-10-22. Fuentes: `docs/BACKLOG_PENDIENTES.md`,
`.workbuddy-ai/memory/2026-10-21.md`, `docs/assets/matriz/reporte.json` y las
mediciones de la sesion.*
