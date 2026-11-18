# Cierre 2026-11-18 — consolidación Vercel y corrección documental

**Estado:** rama `main`, cambios **sin commitear** (los deja el agente para revisión del propietario).
**Alcance:** cerrar la contradicción Render/Vercel, registrar los entornos en un
único sitio, corregir el `403` del período y dejar el árbol listo para publicar.

## 1. Qué se decidió

El backend de producción es **Vercel Hobby** (`https://inces-lms-api.vercel.app`).
Render se retiró el 2026-10-31 por el techo de 750 h/mes y la suspensión. El
objetivo es **todo en capas gratuitas**: Cloudflare Pages + Vercel + Supabase +
R2 + GitHub Actions. La fuente única es
[`../ENTORNOS_Y_DESPLIEGUE.md`](../ENTORNOS_Y_DESPLIEGUE.md).

## 2. Contradicciones cerradas

| Antes | Ahora |
|---|---|
| `web_bundle.yml` compilaba con `API_PRODUCCION = onrender.com` | `https://inces-lms-api.vercel.app` |
| `devops/desplegar-pages.mjs` validaba contra Render y tenía una ruta fija de otra máquina | Vercel + `import.meta.dirname` |
| `functions/api/**` proxyaba a Render con `RENDER_BACKEND_URL` | `BACKEND_URL` → Vercel, y aviso de que **no se despliega** |
| `render.yaml` en la raíz (Blueprint activo) | archivado en `docs/historial/configuracion/render.yaml` con cabecera de retiro |
| `PROCEDIMIENTO_DESPLIEGUE_PRODUCCION.md` §1/§5/§9/§10.1/§11/§12 en Render | alineado a Vercel; §7 marcada como histórica |
| `docs/README.md` decía «Render + Cloudflare Pages» | apunta a `ENTORNOS_Y_DESPLIEGUE.md` |
| `docs/MAESTRO/00` enlazaba `docs/ESTADO_DEL_SISTEMA.md` (no existe) | `../ESTADO_DEL_SISTEMA.md` + nota de jerarquía (manda el código) |
| `LEVANTAR_EN_LOCAL.md` mandaba `apply-migrations.mjs --confirmar` (bandera inexistente) | el comando real, con la advertencia de que no hay confirmación |
| `LEVANTAR_EN_LOCAL.md` daba `flutter build web` por imposible | medido: `pub get`, `analyze`, `test` y `build` corren con Flutter 3.50 |
| `e2e/README.md` pedía 6 secretos | 9 (faltaban ALUMNO y DOCENTE) |
| `ESTADO_DEL_SISTEMA.md` decía v1.9.0 | v1.14.0, con nota de la corrección |
| `docs/contexto-ia/04` decía 89 operaciones | 103 operaciones / 94 rutas (medido) |
| `docs/contexto-ia/07` decía 46 migraciones | 73 en disco |
| `ARQUITECTURA…SDD.md` declaraba v1.2.9 y API en Render | cabecera corregida + aviso de cifras históricas |

## 3. Defecto de producto corrigido

`GET /api/v1/admin/periodos` se pedía desde los paneles de **docente** y
**estudiante** para pintar el período de la cabecera. La API respondía
**403 SOLO_ADMIN** en cada carga; el cliente lo tapaba con un respaldo a
PostgREST, así que el error solo se veía en consola y en el registro del servidor.

- Ruta nueva `GET /api/v1/periodo-vigente` (sesión, sin guardia de módulo).
- `CuadranteGateway.obtenerPeriodoVigente()` + repositorio + dashboards.
- 5 pruebas de backend y 6 de Flutter.

## 4. Evidencia medida

| Control | Resultado |
|---|---|
| `cd backend && npm run verify` | **755/755**, 36 archivos, exit 0 |
| `npm run openapi` + `vitest test/openapi.test.ts` | 9/9, contrato regenerado (94 rutas / 103 operaciones) |
| Ruta nueva contra **Supabase real** (backend local) | admin 200 · docente 200 · estudiante 200 · sin token 401 · lapso `INCES26-3`, `vigente: true` |
| Ruta vieja como docente (control) | 403 `SOLO_ADMIN` |
| `flutter analyze` (SDK 3.50) | solo avisos de deprecación del propio SDK (`package:flutter/material.dart` → `material_ui`), 127 avisos, **0 errores** |
| `flutter test` (suite completa, SDK 3.50) | **1163/1191**; 28 rojos **preexistentes**, en 6 archivos (ver §5) |
| `flutter test test/periodo_vigente_test.dart` + paneles de cuadrante | **42/42** |
| `flutter build web --release` con `API_BASE_URL` de Vercel | OK, 91,6 s, `build/web` 4,86 MB de `main.dart.js` |
| Playwright, 3 roles contra producción | admin 16/16 · docente 5/5 · estudiante 8/8 |

## 5. Lo que queda fuera de este cierre

- **Commit y push**: los cambios están en el árbol, sin commitear.
- **Despliegue**: no se publicó nada. El bundle ya está compilado y verificado.

  ```bash
  # 1) API (desde backend/, con la sesión del propietario)
  cd backend && npx vercel --prod

  # 2) Web (token de Cloudflare en backend/.env)
  cd .. && node devops/desplegar-pages.mjs build/web
  ```

  El bundle de `build/web` se compiló el 2026-11-18 con
  `--dart-define=API_BASE_URL=https://inces-lms-api.vercel.app` (4,86 MB de
  `main.dart.js`, `version.json` = `1.14.1/34`; sin `onrender.com`, sin
  `localhost`, sin `127.0.0.1`). **Si se recompila, repetir ese `--dart-define`**:
  `--dart-define-from-file=.env.json` solo aporta las claves de Supabase y deja
  `API_BASE_URL` en `http://127.0.0.1:3001`.
- **Migración `202611060001_precheck_aspirante_solo_digitos.sql`**: sigue sin
  seguimiento en git y **no se ha aplicado** a la nube.
- **Decisiones del propietario pendientes**: `m7_calificaciones`/`m8_pasantias`
  encendidos sin código; rotación de credenciales expuestas; confirmar que el
  servicio de Render quedó apagado.
- **Pruebas Flutter que ya venían en rojo** — 28 de 1191, medida el 2026-11-18.
  Ninguna toca el período ni el cuadrante; se comprobó ejecutando aparte los
  archivos implicados (42/42 en verde). Reparto:

  | Archivo | Rojos | Causa medida |
  |---|---|---|
  | `test/aspirante_form_catalogo_test.dart` | 11 | formulario de aspirante **en curso** (`lib/screens/aspirante_form_screen.dart` modificado sin commitear) |
  | `test/gestor_documental_panel_test.dart` | 6 | el panel llama `listarMios` sin entidad; la prueba espera que no lo haga |
  | `test/asistencia_paneles_test.dart` | 5 | la pantalla pide ventana de **45 s** (`_ventanaSeg = 45`), la prueba espera **15** |
  | `test/aspirante_form_navegacion_test.dart` | 4 | mismo formulario en curso |
  | `test/cedula_y_ubicacion_test.dart` | 1 | **no compila**: llama `CampoInscripcion(...)` con argumentos que el modelo ya no acepta |
  | `test/barrido_responsive_test.dart` | 1 | `StateError` recorriendo el formulario de aspirante |

  Son deuda previa; arreglarlas exige decidir cuál manda, si el código o la
  prueba. No se tocaron sin decisión del propietario.

## 6. Trampas que encontró esta sesión

1. **El árbol no compilaba** antes de este cierre: `constructor_direccion_inteligente.dart`
   (archivo nuevo, sin seguimiento) llamaba a `paleta.tarjeta`, que no existe en
   `PaletaInces`. Se corrigió a `paleta.superficie`. Con eso `flutter test` pasa.
2. **`flutter pub get` con el SDK 3.50 reescribió `pubspec.lock`** (6 paquetes
   menores). Se revirtió para no cambiar dependencias que CI resuelve con 3.47.
3. **Playwright necesita navegador**: no había Chromium de Playwright ni Chrome;
   se usó el **Edge del sistema** (`channel: 'msedge'`).
4. La sonda de navegación debe esperar el **árbol semántico** de Flutter
   (`flt-semantics`), no el DOM: sin eso, todos los localizadores dan 0.
