# Lote 5 — cierre, reparación y handoff

**Fecha:** 2026-10-29 · **Rama:** `main` · **Base:** `21cbdaf` (Lote 5)
**Estado:** Lote 5 **cerrado con la regresión reparada**; suite completa en verde.

> Este documento **sustituye** a `docs/HISTORICO_RESUMEN_LOTE_5.md` y a
> `docs/PROMPT_DELEGACION_AGENTE.md`, que se retiraron el mismo día por contener
> afirmaciones que el árbol desmiente (detalle en §4). Los dos eran locales: no
> estaban en `origin`, así que no se pierde trazabilidad de nada publicado.

---

## 1. Qué trajo el Lote 5 (y se conserva)

| Pieza | Qué hace |
|---|---|
| `lib/screens/admin/cpanel_aulas_virtuales_panel.dart` | Lista las secciones del centro con su aula virtual y abre cada una en modo docente. Nombres de programa/materia resueltos en local; si el catálogo falla, degrada al identificador y el aula sigue abriendo. Archivadas separadas. |
| `lib/screens/admin_dashboard.dart` | Entrada «Aulas Virtuales» (grupo *Dar clase*), con migas propias. |
| `lib/screens/aula_virtual_dashboard.dart` | El tablón pasa a **una sola `ListView`**; los anuncios son hijos de esa lista, no un scrollable anidado. Es la causa raíz correcta del scroll muerto en móvil. |
| `test/scroll_movil_redmi10c_test.dart` | Grupo nuevo que mide lista, arrastre al final, vuelta arriba y apertura del aula a 360×740. |

**El admin sí puede escribir en el aula**: `m6_dicta_seccion()` incluye
`is_admin()` (`supabase/migrations/202609220001_mod6_aula_virtual.sql:339`), así que
publicar anuncios desde el cPanel no acaba en 42501.

## 2. Qué rompió el Lote 5

El menú del docente pasó de «Mis aulas» a «Aulas Virtuales» **y la rama del
`switch` se quedó como `case 'Mis aulas'`**. El `switch` caía en el `default` y el
docente veía *«Esta sección está pendiente de construir»* en su primer apartado: el
Aula Virtual quedaba **inalcanzable**.

Lo cazaron seis pruebas, no una revisión visual:

| Prueba | Síntoma |
|---|---|
| `aula_produccion_test.dart` (3) | `Found 0 widgets with text "Soldadura · Sección A · Formación Profesional"` |
| `menu_alcanzable_test.dart` (1) | `Set [Aulas Virtuales, …] does not contain 'Mis aulas'` — el contrato menú↔`switch` que existe desde R-22 |
| `menu_gobernado_por_modulos_test.dart` (2) | `Found 0 widgets with type "PanelMisAulas"` |

Además, `_navegarA('Mis aulas')` **no hacía nada, en silencio** (índice −1 sin error):
tres accesos del propio panel docente quedaron mudos.

## 3. Qué se reparó (2026-10-29)

| Archivo | Cambio |
|---|---|
| `lib/screens/docente_dashboard.dart` | `case 'Aulas Virtuales'` + comentario con el porqué y la medición; **alias** `'Mis aulas' → 'Aulas Virtuales'` en `_navegarA` para que un renombrado no deje un botón mudo |
| `lib/screens/docente/docente_resumen_panel.dart` | 2 llamadas y una tarjeta alineadas al nombre real |
| `lib/screens/docente/docente_calificaciones_panel.dart` | «Crear tarea en el aula» navega al nombre real |
| `lib/screens/mis_aulas_panel.dart` | `titulo` configurable (título, migas y «Volver a…»); por defecto «Mis aulas» (aprendiz) |
| `lib/screens/aula_virtual_dashboard.dart` | Icono `onPrimaryContainer` en vez de `Colors.white` (contraste ≈1,3:1 → rol); `Flexible` en vez de `Expanded` para que el botón no baje de línea a 1440 px |
| `e2e/tests/matriz_responsive.spec.ts` | Admin a **17** secciones reales (3 nombres muertos fuera, 5 ausentes dentro); docente a «Aulas Virtuales»; señal de login del docente corregida |
| `e2e/src/pages/AulaVirtualPage.ts` | Resuelve la entrada del menú **por presencia** entre «Aulas Virtuales» y «Mis aulas» (lo usan las dos suites) |
| `e2e/tests/aula_virtual_ciclo.spec.ts`, `captura_dashboards_roles.spec.ts`, `performance_baseline.spec.ts`, `e2e/capturar-dashboards-roles.mjs` | Señal de login del docente |
| `test/menu_alcanzable_test.dart` | Suelo del admin de 14 → **17**, con el comentario corregido (un suelo por debajo del real deja de avisar) |
| `CHANGELOG.md` | Entrada `[1.5.5]` con lo bueno, lo roto y la evidencia |
| `lib/core/config/app_config.dart` | **`version` estaba en `1.5.1`** con el pubspec en 1.5.5+7: el menú, el pie y la portada pintaban «v1.5.1». Corregido a `1.5.5` |
| `test/version_coherente_test.dart` | **Guardia nueva**: compara `pubspec.yaml` ↔ `AppConfig.version` ↔ primera entrada del `CHANGELOG` y falla si se separan |
| `lib/screens/admin/cpanel_cuadrante_panel.dart` | El aviso mandaba a «Secciones del Período», apartado retirado en D11. Ahora no nombra un sitio inexistente |
| `pubspec.yaml` | `1.5.5+7` |
| `backend/dist/` | **Reconstruido.** Estaba del **2026-10-22** y seguía seleccionando `enrollments.bid_expires_at`, que la migración `202610260001` eliminó: `GET /api/v1/mis-inscripciones` devolvía **500 `ESQUEMA_DESACTUALIZADO`** en la corrida de la matriz. Es un artefacto ignorado por git, no un defecto del código: `backend/src` tiene **0** referencias. Tras `npm run build`: 0 referencias y el 500 desaparece |

## 4. Lo que decían los documentos retirados, y no era cierto

| Afirmación | Realidad medida |
|---|---|
| «CHANGELOG actualizado con 1.5.5» | No existía: el commit `21cbdaf` no toca `CHANGELOG.md` |
| «14 tests nuevos pasan» | El archivo tiene **8** tests; se añadió **1**. Los 14 son de `aula_virtual_dashboard_test.dart` |
| «1 test falla, preexistente» | Fallaban **6**, todos nuevos y causados por el renombrado. La suite pasó de 1057 a 1058 pruebas: exactamente una añadida |
| «8 migraciones pendientes de aplicar» | Contradice al commit `a96c3aa`: se aplicaron el 2026-10-28 (61 versiones, 0 deriva) |
| «Despliegue: Pages + Cloudflare Functions» | El backend es Render (Fastify); no hay Functions |
| «GitHub Actions con dependencias obsoletas» | Lo rojo es **E2E** (`export_csv`) y `cleanstack-ci.yml`, que está **vacío (0 bytes)** y falla en 0 s |

## 5. Verificación de este cierre (medida, no deducida)

| Control | Comando | Resultado |
|---|---|---|
| Analizador | `node devops/analizar-dart.mjs` | 249 archivos · 0/0/0 · exit 0 |
| Analizador real | `flutter analyze` | *No issues found!* (51,2 s) · exit 0 |
| Suite Flutter | `flutter test` | **1060/1060** · exit 0 |
| Backend | `cd backend && npm run verify` | 34 suites · **721/721** · exit 0 |
| Migraciones (SQL real) | `cd supabase/tests && node validate.mjs` | **555 aserciones · 0 fallidas** · exit 0 |
| Build web | `flutter build web --release --dart-define-from-file=.env.json` | **√ Built build\web** (139,5 s) |
| **Matriz responsiva** | `E2E_MATRIZ=1 playwright test matriz_responsive` | **192 capturas · 0 desbordes · 0 page errors · 0 no navegables · 4/4 roles** (9 min 12 s). El rol docente, antes perdido en el login, entra y recorre sus 5 apartados × 6 perfiles. **Re-corrida la del estudiante tras reconstruir `backend/dist`: 48 capturas, 0 no navegables, sin `ESQUEMA_DESACTUALIZADO`** |
| Galería | `node C:/tmp/gen_galeria.mjs` | 198 imágenes en 4 grupos → `docs/assets/matriz/index.html` |
| Migraciones en disco | `ls supabase/migrations/*.sql` | **61** |
| CI en `origin/main` | `gh run list` | Flutter CI ✅ · Web bundle ✅ · **E2E ❌** (2 corridas) · cleanstack ❌ (0 s) |

> **El bloqueo `CreateFile failed 231` no se reproduce el 2026-10-29**: `flutter
> test`, `flutter analyze` y `flutter build` corren en este equipo. La entrada
> «BLOCKED» de `ESTADO_DEL_SISTEMA.md` pasa a histórica, con fecha.

## 6. Lo que queda, en orden

1. **P1 funcional — crear secciones no tiene puerta.** `CpanelSeccionesPanel`
   (676 líneas, con 8 pruebas) no lo instancia nadie desde D11 y `crearSeccion` no
   tiene otro llamador: **el administrador no puede crear una sección**. Falta la
   mitad de D11 («desde Programas se llega a las secciones en un clic»). Exige
   decidir la forma —recomendado: pestaña «Secciones» dentro de «Cursos y PNA»,
   filtrada por programa— y capturas en 3 posiciones de scroll. Ficha: backlog C10.
2. **Push.** Hay 10 commits locales sin publicar; CI nunca los vio. Sin push no hay
   despliegue ni verificación en la nube.
3. **E2E rojo en `main`**: `export_csv` (job «Exportación CSV en navegador real»).
   Es la *flaky* del login ya documentada; hay que estabilizarla, no reintentarla.
4. **`cleanstack-ci.yml` vacío**: borrarlo o escribirlo. Hoy ensucia cada push.
5. **Documentación desincronizada** (ver `ESTADO_DEL_SISTEMA.md`, foto 2026-10-29):
   `MEMORY.md` sigue en 658 pruebas de septiembre; `docs/contexto-ia/` en 46
   migraciones; `docs/CATALOGO_DOCUMENTAL.md` apunta a rutas de antes del
   movimiento del 2026-10-22.
6. **Decisión pendiente de producto:** «Campus» (Especificación maestra, TAREA 9)
   vs «Aula Virtual» (anulada el 2026-10-27 por instrucción directa). El código dice
   «Aula Virtual»; la maestra sigue ordenando el renombrado. Hay que marcar la
   tarea como anulada o ejecutarla, pero no dejar las dos vivas.
7. **`verificar-esquema.mjs`**: 5 comprobaciones desactualizadas respecto al
   Rediseño 1.5 (bids eliminado, mapa de módulos, cursos sembrados, límite de
   archivos, tablas heredadas). Es deriva del verificador, no del esquema.
8. **Deuda menor**: `tsc --noEmit` en `e2e/` da **5 errores de tipos preexistentes**
   (`FlutterApp.ts` ×2, `_explorar_dialogos`, `export_csv`, `matriz_responsive:223`);
   Playwright transpila sin comprobar tipos, así que no bloquean, pero ensucian
   cualquier intento de typecheck. Y `CpanelLapsosPanel` conserva el nombre viejo
   aunque el menú ya diga «Período» (cosmético, no visible).

## 7. Cómo retomar en frío

```bash
git log --oneline -3              # 21cbdaf + este cierre
node devops/analizar-dart.mjs     # 249 · 0/0/0
cd backend && npm run verify      # 721/721
cd ../supabase/tests && node validate.mjs   # 555 aserciones
cd ../.. && flutter test          # 1060/1060
flutter analyze                   # No issues found!
```

Si algo de aquí contradice al código, **gana el código**: se vuelve a medir con el
comando de arriba y se corrige este documento el mismo día.
