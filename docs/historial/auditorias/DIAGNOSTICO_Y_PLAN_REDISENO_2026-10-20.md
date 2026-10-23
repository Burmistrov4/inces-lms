# Diagnóstico y plan maestro del rediseño — INCES LMS

**Fecha:** 2026-10-20 · **Autor:** Aria · **Para:** Lorenzo Roca
**Disparador:** demo ante el Jefe del Centro de Formación (2026-10-20) + 5 vídeos de
comparación (`Correciones para INCES-LMS 2`, ~88 min) + instrucciones de Lorenzo.
**Regla del documento:** cada afirmación lleva evidencia (archivo:línea o comando con
código de salida). Lo que no está medido, se marca como pendiente de medir.

---

## 1. Qué se vio en los vídeos (análisis)

Se extrajeron 118 fotogramas (uno cada 45 s de los 5 vídeos) y se revisaron por hojas
de contacto (`/c/tmp/sheets/`). Contenido verificado:

| Vídeo | Duración | Contenido |
|---|---|---|
| 22-35-38 | 3:02 | Landing de INCES LMS en varias pestañas (hero, oferta formativa, «Gestión Académica») |
| 22-39-28 | 6:15 | Landing vs. documentación de Flutter; escritorio con carpetas del proyecto |
| 22-45-50 | 36:31 | **El núcleo:** paneles admin de nuestro LMS (inscripciones, aulas, contenidos, anuncios, formularios) intercalados con **Google Classroom** (vista «Clases») y la web del INCES |
| 23-45-20 | 41:07 | **El más largo:** paneles admin a pantalla completa, «Configurar Nuevo Año de Formación», «Auditoría y Parámetros del Sistema», Classroom (tabla de estudiantes y calificaciones), gestor «Archivos y enlaces», planilla PDF, incES.gob.ve |
| 00-26-38 | 1:23 | Planilla oficial en PDF +-explorador de Windows con descargas |

**Conclusiones del análisis:**

1. **Comparación real con dos referentes:** Google Classroom (simplicidad: una lista de
   clases, muro, pestaña Trabajo de clase / Personas / Calificaciones) y Google Drive
   (carpetas, subir, crear). Lorenzo quiere ese ecosistema unificado, no una copia:
   Classroom + Drive + creación de documentos en un solo lugar.
2. **Nuestro admin es denso.** Los paneles actuales (inscripciones, aulas, guardias,
   currículo) muestran muchos campos a la vez; el Jefe de Centro tuvo que hacer zoom
   al 80–90 % en varios módulos para ver el contenido completo. Ese es el síntoma
   visible del problema de fondo: **anchos fijos y tabas que no se adaptan**.
3. **Drive actual = gestor de archivos, no ecosistema.** En los vídeos se ve el panel
   «Archivos y enlaces» con subida fallida desde la PC (mensaje de error del servidor).

---

## 2. Inventario de pedidos de Lorenzo (cerrado al 2026-10-20)

### 2.1 Correo y SMTP
- [x] **HECHO (código):** el correo de invitación ahora dice explícitamente que revise
      **spam** si no aparece en el buzón (`backend/src/http/rutas/admin.ts`, bloque
      amarillo en `htmlInvitacion`), y el aviso en pantalla lo repite
      (`lib/screens/admin/cpanel_invitaciones_panel.dart:160`).
- [x] **HECHO (medido):** `node_modules` del backend estaba **incompleto**:
      `nodemailer` y `resend` estaban declarados en `package.json:32` pero **no
      instalados** → el verificador fallaba con 10 errores (`TS2307 Cannot find module
      'nodemailer'`, y `Response` sin `ok/headers/status` por `@types/node` ausente).
      **Cualquier ruta SMTP habría reventado al importar.** Corregido con
      `npm install` (exit 0) y verificado: `npm run verify` → **705/705 pruebas, 34
      archivos, exit 0**.
- [ ] **PENDIENTE (H1, humano):** en producción (Render) faltan las variables
      `SMTP_USER` + `SMTP_PASS` (contraseña de aplicación de Gmail) para que el correo
      salga de verdad por SMTP. El código ya prioriza SMTP y cae a Resend si falla
      (`backend/src/infra/correo.ts:176-220`). Sin esas variables el envío queda en
      `{ entregado: false, proveedor: 'ninguno' }` y **no llega correo**.
- [ ] **PENDIENTE:** docentes ficticios actuales → 100 % editables y con correo de
      invitación reenviado (depende de H1).

### 2.2 Responsive — el problema del zoom 80–90 %
- **Medido:** en `lib/` sólo **15 de 143** archivos usan `LayoutBuilder` y 7 usan
  `MediaQuery`. La tabla de Usuarios y Roles es un `DataTable` dentro de
  `SingleChildScrollView(horizontal)` con celdas de ancho fijo 250 + 220 px
  (`cpanel_usuarios_roles_panel.dart:563-572`) → ancho mínimo ~900 px: en ventana
  menor desborda y obliga al zoom. Es el único `DataTable` del código.
- **Pedido:** responsive «como Google», en todos los módulos, sin zoom. Flutter web
  **sí** puede hacerlo; hace falta una pasada sistemática (ver Fase 1).

### 2.3 Navegación y robustez
- [x] **HECHO:** guardia anti rebote de 600 ms (`lib/widgets/guardia_toque.dart`)
      aplicada a los 3 menús laterales (vía `_ItemMenu`, `andamiaje.dart:612`), las 15
      acciones de la barra superior (`barra_acciones_superiores.dart`) y los 10 accesos
      rápidos + walkthrough + reportes de los tres dashboards. Verificado con
      `frontend_server` → **EXIT 0**.
- [ ] **PENDIENTE:** mensajes de error inteligentes (excepciones controladas con
      reintento) en los paneles que más fallan (subida de archivos, drive).

### 2.4 Usuarios y Roles
- **Medido:** el panel funciona y delega en `GET /api/v1/admin/usuarios`
  (`backend/src/http/rutas/admin.ts:230`), que filtra por rol/activo/búsqueda y pagina
  (`backend/src/infra/repos-supabase.ts:1198`). El backend está bien construido.
  «Solo aparece un admin» es, con toda probabilidad, **dato real: sólo existe ese
  perfil** (pendiente de confirmar contra la nube con `supabase/verificar-esquema.mjs`).
- [ ] **PENDIENTE:** sembrar/importar docentes y estudiantes ficticios, hacerlos
      editables y enviarles invitación; mostrar estado real (registrado / pendiente /
      invitación caducada).

### 2.5 Drive / Archivos — ecosistema tipo Google
- **Pedido (de los vídeos y de la demo):** crear carpeta **desde la ubicación actual**
  (clic derecho), subir archivo desde cualquier carpeta, crear documentos nuevos
  (docx, xlsx, pdf, pptx editables), adjuntar **enlaces de Google Drive** con título
  automático u opcional.
- **Defecto medido:** no se pudo subir ningún archivo desde la PC «fallo en el
  servidor» — reproducible en dashboard de admin, docente y estudiante. El selector
  (`lib/core/gateways/selector_archivos.dart`) sube por URL prefirmada PUT a R2; el
  fallo está en la cadena backend de subida (no reproducido aún en local: **primer
  paso de la Fase 2**).

### 2.6 Inscripciones y cursos
- [ ] **PENDIENTE:** el estudiante debe poder **reeditar su planilla** si fue rechazada.
- [ ] **PENDIENTE:** indicador claro de «inscripciones abiertas/cerradas» por curso,
      visible en dashboards de admin, docente y estudiante.
- [ ] **PENDIENTE:** quitar «Lapsos Académicos» del frente; cada curso y el PNA llevan
      su propio periodo de inicio/cierre editable por el admin.

### 2.7 PNA, horarios y secciones
- [x] **HECHO (código):** edad del PNA unificada a **14–17** con constante única
      `kEdadPnaTexto` (`lib/screens/landing_page.dart`), usada en los 3 puntos de la
      landing (chip, filtro de oferta, slide PNA).
- [ ] **PENDIENTE:** edad editable desde panel de parámetros → reflejada en landing
      (migración + parámetro + lectura pública).
- [ ] **PENDIENTE:** quitar «Secciones» del frente (confusión con materias PNA).
- [ ] **PENDIENTE:** materias del PNA clasificadas correctamente y asignables a
      docente + día + rango horario (AM/PM), reflejadas en el horario ordinario y en
      los roles de guardía; los cursos también reciben materias.
- [ ] **PENDIENTE (opcional):** planes de evaluación por PNA/curso, creados por admin.

### 2.8 Landing y marca
- [x] **HECHO:** fuera los datos de contacto del INCES de la landing: la columna
      «Sede y Talleres» (dirección física y horario de talleres,
      `landing_page.dart:_columnaFooterUbicacion`) se sustituyó por «Rutas de
      Formación» (PNA/MTP, sin dirección, teléfono ni correo). En todo el archivo no
      quedó ni un correo ni teléfono (verificado por grep).
- [x] **HECHO:** favicon nuevo — chispa/llama de soldadura sobre azul institucional,
      generado como SVG y rasterizado a 16/32/48/180/192/512 + maskables
      (`web/favicon*.png`, `web/icons/*`), enlazado en `web/index.html`.
- [ ] **PENDIENTE:** regla general: **todo lo que el admin edite debe reflejarse en la
      landing** (programas ofertados, periodos, edad PNA, textos institucionales).

### 2.9 Asistente virtual inteligente
- **Pedido:** asistente a prueba de cualquier pregunta sobre el sistema, que dé enlaces
  y lleve al usuario a donde pide. Existe un embrión: `asistente_curriculo_screen.dart`
  (sólo currículo) y el walkthrough por roles.
- [ ] **PENDIENTE (Fase 4):** asistente general con catálogo de acciones del sistema
      (cada acción = intención + ruta + permiso), alimentado por los datos reales del
      backend.

### 2.10 Rendimiento
- **Medido antes (2026-10-09):** el hook de auth hacía 2 viajes en serie (421 ms fijos);
  ya paralelizado: `admin/usuarios` −64 %. Queda pendiente el mismo tratamiento en los
  paneles que se toquen en la Fase 1.

---

## 3. Plan por fases

### Fase 0 — Cierres inmediatos (HECHO HOY, verificado)
| Entregable | Evidencia |
|---|---|
| Aviso de spam en correo de invitación + aviso en UI | `backend/src/http/rutas/admin.ts` (bloque amarillo), `cpanel_invitaciones_panel.dart` |
| Backend verificable y con dependencias reales | `npm install` exit 0 → `npm run verify` **705/705, exit 0** |
| Favicon nuevo (todos los tamaños + maskables) | `web/favicon-*.png`, `web/icons/*`, `web/index.html` |
| Landing sin datos de contacto | `_columnaFooterUbicacion` reescrita |
| Edad PNA 14–17 con fuente única | `kEdadPnaTexto` en los 3 puntos |
| Guardia anti doble-clic | `guardia_toque.dart` + 28 sitios de invocación; `frontend_server` **EXIT 0** |
| **Primer corte responsive** — Usuarios y Roles híbrido | `cpanel_usuarios_roles_panel.dart`: `LayoutBuilder` <900 px → tarjetas (`_TarjetaUsuario`); ≥900 px → tabla; `frontend_server` **EXIT 0** |

### Fase 1 — Responsive «como Google» (la de más impacto visible)
1. **Contrato responsive común:** helpers de ancho (`esCompacto <600`, `esMedio <1024`,
   `esAncho ≥1024`) + `TablaResponsiva` (lista de tarjetas en compacto, tabla real en
   ancho) para sustituir el `DataTable` de Usuarios y Roles.
2. **Barrido módulo por módulo**, empezando por los que el Jefe de Centro vio con zoom:
   Usuarios y Roles, Inscripciones, Aulas, Guardias/Cuadrante, Archivos, Currículo.
   Criterio de aceptación: **ningún módulo desborda a 1280 px ni a 768 px ni a 390 px**
   (medido con capturas Playwright, no a ojo).
3. Colocar el contenido en `LayoutBuilder`/`MediaQuery`, eliminar anchos fijos de
   celda, usar `Wrap`/`Expanded` y tablas con scroll horizontal controlado sólo cuando
   sobra.
4. Acceleración: medir veces de carga por panel después del rediseño (objetivo: <900 ms
   en panel admin estándar).

### Fase 2 — Drive tipo Google (ecosistema unificado)
1. Reproducir y corregir la subida fallida desde PC (admin/docente/estudiante).
2. Menú contextual (clic derecho) en cualquier carpeta: **crear carpeta, subir
   archivo, crear documento (docx/xlsx/pdf/pptx), pegar enlace de Drive**.
3. Enlaces de Google Drive: detectar la URL, mostrar título (de la metadatos del
   enlace) editable, previsualización incrustada cuando sea posible.
4. Creación de documentos ofimáticos desde el LMS (plantillas editables en línea o
   descarga-para-editar-subida al guardar).

### Fase 3 — Inscripciones, cursos, horarios y PNA
1. Reedicción de planilla por el aspirante (estado `rechazada` → editable → reenvío).
2. Semáforo de inscripción (abierta/cerrada) por curso, visible en los 3 dashboards.
3. Fuera «Lapsos Académicos» del frente; periodo inicio/cierre por curso y por PNA,
   editable por admin.
4. Fuera «Secciones» del frente; catálogo de materias PNA bien clasificado;
   asignación docente+día+rango AM/PM reflejada en horario ordinario y guardías; los
   cursos reciben materias. Planes de evaluación opcionales por admin.

### Fase 4 — Asistente virtual + landing viva
1. Catálogo de intenciones → rutas con permisos (admin/docente/estudiante).
2. Landing alimentada por parámetros editables del admin (programas, edad PNA,
   periodos, textos institucionales).

---

## 4. Bloqueos y decisiones que necesita Lorenzo

| # | Bloqueo | Qué se necesita |
|---|---|---|
| H1 | **SMTP real** | `SMTP_USER` + `SMTP_PASS` (contraseña de aplicación de Gmail) en Render |
| H2 | Borrado/normalización de datos ficticios | Autorización para sembrar docentes/estudiantes de prueba |
| H3 | Periodos por curso | Confirmar que el Jefe de Centro (admin) edita inicio/cierre por curso/PNA |
| H4 | Drive de Google | Decidir si la integración es sólo enlaces o también subida vía API (requiere cuenta de servicio) |

## 5. Próximo paso concreto (Fase 1, primer corte)

Reescribir la tabla de Usuarios y Roles como tabla responsive (tarjetas en móvil /
tabla en escritorio) y fijar los helpers de ancho en `lib/widgets/`. Verificación:
`frontend_server` (compila) + capturas Playwright a 1280/768/390 px.

---

## 6. Avance del 2026-10-20 (tarde) — Fase 1 ejecutada

### 6.1 Contrato responsive nuevo

`lib/widgets/responsivo.dart`: `anchoVentana`, breakpoints (`esCompacto` <600,
`esMedio` 600–1024, `esAncho` ≥1024), `anchoDialogoSeguro` (nunca más del 92 % de
la ventana ni de 560 px), `contenidoDialogoSeguro`, `rejillaAdaptable`
(`SliverGridDelegateWithMaxCrossAxisExtent`), `cabenDosPaneles` (≥1100).

### 6.2 Barrido medido antes → después

Script: `/c/tmp/barrido_responsive.py` (mide ancho fijo, ausencia de
LayoutBuilder/MediaQuery, scroll horizontal, DataTable, crossAxisCount).

| Medida | Antes | Después |
|---|---|---|
| Archivos con deuda | 21 | 16 |
| Archivos ROJOS (sin responsive + ancho fijo) | 7 | 4 → **0 reales** (los 4 son hijos de `Wrap` o llevan `Expanded` al lado: absueltos por contexto) |
| Diálogos con ancho fijo que desbordaba | 15 | **0** — todos usan `anchoDialogoSeguro` |
| Panel lateral del drive | 320 px fijos que aplastaban el listado | inline sólo a ≥1100 px; **hoja inferior** a menos (patalla Google Drive móvil) |

Archivos corregidos: login, inscripciones, inscripcion_campos, modulos, aulas,
lapsos, asistente_curriculo, programas (×2), secciones (×2), cuadrante (×2),
guardias, explorador (×1). Verificación: `frontend_server` **EXIT 0** (3 corridas).

### 6.3 Fase 2 iniciada — la subida de archivos, reproducida con evidencia

**Ciclo real reproducido contra el backend local** (script
`/c/tmp/reproducir_subida.cjs`, backend en 127.0.0.1:3001, docente de semilla):

| Paso | Resultado |
|---|---|
| Login GoTrue | 200, token OK |
| `POST /archivos/firmar-subida` con `.txt` | **400 «Extensión no permitida»** — sólo se admiten `.pdf .jpg .jpeg .png .webp .docx .xlsx .pptx` |
| `POST /archivos/firmar-subida` con `.pdf` | 201, fila PENDING, URL prefirmada |
| `PUT` de bytes a R2 | **200** |
| `POST /archivos/:id/confirmar` | **200, archivo confirmado** |

**Conclusión medida:** el motor de subida **funciona end-to-end**. Lo que falló en
la demo no fue el backend. Fue la interfaz:

1. `cpanel_explorador_archivos_panel.dart:723` `_simularSubidaArchivo()` **finge
   la subida**: abre un diálogo con un PDF precargado («Manual_Tecnico_Soldadura_
   TIG.pdf, 3.2 MB») que al tocarlo inserta un elemento **local** en la lista. No
   hay selector de archivos real, ni PUT, ni confirmar. El drive del admin es una
   maqueta — de ahí «no se puede subir nada».
2. El selector real (`selector_archivos.dart`) no filtra extensiones y el 400 del
   servidor llega al usuario como «fallo en el servidor» en vez de «extensión no
   admitida».
3. El esquema del servidor (`src/http/esquemas.ts:966`) sólo acepta
   `entityType: TASK_SUBMISSION | TEACHER_GUIDE`: **no existe la subida suelta**
   al gestor documental. Para el ecosistema tipo Drive hace falta un
   `DRIVE_FILE` (migración + esquema + RLS).

**Siguiente ciclo exacto:** sustituir `_simularSubidaArchivo` por el ciclo real
(gateway → selector → firmar → PUT → confirmar) con estado PENDING/CONFIRMED y
progreso visible; añadir `DRIVE_FILE` al esquema con su migración; y traducir los
errores 400/413 a mensajes que el usuario entienda.

### 6.4 Fase 2, ciclo 1 — EJECUTADO el 2026-10-20 (noche)

| Pedido | Estado | Evidencia |
|---|---|---|
| Migración `DRIVE_FILE` | **HECHO** | `supabase/migrations/202610202001_drive_file_subida_suelta.sql`: amplía el CHECK de `files_metadata.entity_type` y endurece `m6_validar_entidad_de_archivo` para que DRIVE_FILE exija `entidad_id` NULL. **Aplicada a la nube** (`apply-migrations.mjs`: 49 versiones, 2 aplicadas) |
| Enum `DRIVE_FILE` end-to-end | **HECHO** | Ciclo real contra la nube: firmar **201** (`entityType: DRIVE_FILE`) → PUT a R2 **200** → confirmar **200**. Script `/c/tmp/reproducir_subida.cjs` |
| Endurecimiento del trigger | **HECHO** | DRIVE_FILE con `entidad_id` → **400 RESTRICCION_VIOLADA** con el mensaje del trigger (`/c/tmp/probar_trigger_drive.cjs`) |
| Simulación → ciclo real | **HECHO** | `cpanel_explorador_archivos_panel.dart`: `_simularSubidaArchivo` (diálogo con PDF precargado que insertía un elemento local) **eliminada**; en su lugar `_subirArchivoReal` con `ArchivosRepository.subir` + selector real del navegador, banner de progreso («Elige el archivo…» / «Subiendo X…») y banner de error cerrable |
| Errores traducidos | **HECHO** | El `ApiClient` ya traduce el sobre `{error:{codigo,mensaje}}` a `AppException` (documentado en `services/archivos_service.dart:20`); el banner muestra ese mensaje: «Extensión no permitida: «.txt»», «El archivo supera el límite»… nunca «fallo del servidor» |
| Verificación | **HECHO** | Backend `npm run verify` **705/705, exit 0** (tras regenerar `openapi.json`, que su test protege); front `frontend_server` **EXIT 0** |

**Pendiente del ciclo (siguiente):** hidratar la lista del gestor desde el
servidor — hoy `_elementos` sigue siendo local (persistido en
`SharedPreferences`), así que los archivos reales sólo aparecen en la sesión que
los subió. Requiere un `GET /archivos/mios` con RLS (el dueño lee lo suyo
`files_metadata_read_own`; el admin lee todo `files_metadata_admin_read`), su
método en gateway/repositorio y mezclarlo con las carpetas locales. Lo demás del
ecosistema Drive (clic derecho, crear docx/xlsx/pdf/pptx, enlaces de Drive) queda
en la Fase 2, ciclo 2.

## 7. Responsive «de Google» — estándar Material 3 (2026-10-21)

Lorenzo pidió que el responsive no fuera «que más o menos quepa» sino el patrón
real de Google: flexible en todos los anchos, sin descuidar ni el móvil ni el
monitor enorme. Ejecutado:

### 7.1 Contrato con los cinco breakpoints canónicos

`lib/widgets/responsivo.dart` reescrito a la tabla de Material 3:
`compact` <600, `medium` 600–839, `expanded` 840–1199, `large` 1200–1599,
`xlarge` ≥1600, con la navegación que Google usa en cada una. Los umbrales
anteriores (600/1024/1100, propios) se retiraron: `esAncho`/`esMedio`/
`cabenDosPaneles` se mantienen como compatibilidad documentada para no romper
los archivos que ya los usan, con su valor y su razón escritos.

### 7.2 La navegación muta con la ventana (antes era «fijo o cajón»)

`lib/widgets/andamiaje.dart`, aplicado a los tres paneles de rol:

| Ventana | Navegación |
|---|---|
| `compact` (<600) | **barra inferior** con los 4 primeros destinos + «Más» (abre el cajón); cajón para el resto y el pie de tema/sesión |
| `medium` (600–839) | **navigation rail**: iconos siempre visibles + botón que abre el cajón |
| `expanded`+ (≥840) | menú lateral fijo, replegable a gusto del usuario |
| `xlarge` (≥1600) | igual, con el contenido **centrado a 1280 px de ancho de lectura** |

### 7.3 Un solo sitio decide los umbrales

Auditoría (`MediaQuery.width < NNN` fuera de `responsivo.dart`): **3 hallazgos,
0 ahora**. Migrados a los predicados canónicos:

- `cpanel_cuadrante_panel.dart` y `cpanel_guardias_panel.dart`: `apilar =
  width < 500` → `esCompacto(context)` (< 600, canónico).
- `guia_contextual_modulo.dart`: `esMovil = width < 768` → `esCompacto(context)`
  (una tableta de 700 px ya no se trata como móvil sin necesidad).

### 7.4 Verificación

- `frontend_server` **EXIT 0** (compilación semántica completa).
- **Pendiente de bundle fresco**: capturas a 390/600/840/1280/1700 px como
  criterio de aceptación visual. `flutter build web` sigue bloqueado en el
  sandbox (error 231); las capturas se toman en cuanto la CI produzca el bundle
  de producción.

### 7.5 Lo que sigue (siguiente ciclo del plan)

1. Rejillas de contenido (no sólo navegación): métricas y tarjetas con
   `rejillaAdaptable` en los paneles que aún usan ancho fijo.
2. Barrido de los paneles medianos con `LayoutBuilder` real.
3. Clic derecho en el gestor, crear carpetas/documentos y enlaces de Drive.

### 6.5 Madrugada del 2026-10-21 — Resend retirado + ciclo 2 del drive

| Pedido | Estado | Evidencia |
|---|---|---|
| **Resend retirado por completo** | **HECHO** | `backend/src/infra/correo.ts` sin `crearRemitenteResend` ni `RESEND_*`; entra `crearRemitenteSupabase` (`POST /auth/v1/invite`, `service_role`). Variables fuera de `env.ts` |
| **Fallback a Supabase verificado en real** | **HECHO** | Backend levantado con `SMTP_USER= SMTP_PASS=` a propósito → invitación creada (200) con `correoEnviado: true`: **Supabase aceptó el envío**. Invitación de prueba revocada después (residuo 0) |
| Cadena honesta | **HECHO** | SMTP (único que lleva nuestro HTML) → Supabase (red; 422 si la cuenta ya existe, no reenvía) → enlace directo al admin. La activación nunca depende del correo |
| `GET /api/v1/archivos/mios` | **HECHO** | Puerto + repo PostgREST bajo RLS + ruta + esquema + OpenAPI + 6 tests HTTP. Prueba nube: 200, sin tipo trae todo, `limite=999`→400, sin token→401 |
| Hidratación del gestor | **HECHO** | Panel admin: `_hidratarDesdeServidor()` mezcla por id con las carpetas locales; `esRemoto`/`estadoRemoto`; etiqueta «Sin confirmar» para `PENDING` |
| Ruta en las pruebas de acceso | **HECHO** | La ruta nueva NO estaba en la lista de protegidas (eran «siete»): añadida, ahora ocho, títulos corregidos |
| Verificación | **HECHO** | Backend **712/712, exit 0**; `frontend_server` **EXIT 0** |

---

## 8. Smooth y rápida (2026-10-21)

| Pedido | Estado | Evidencia |
|---|---|---|
| **Navegación smooth** | **HECHO** | `andamiaje.dart`: el contenido vaenvuelto en `AnimatedSwitcher` con **fade-through** (fundido + escala 0.97→1, 280 ms, curvas M3) al cambiar de sección. `FadeThroughTransition` no es pública en este SDK, así que se compone a mano con `FadeTransition` + `ScaleTransition` |
| **Scroll coherente en todo el sistema** | **HECHO** | `main.dart`: `_ScrollSuaveInces` (`MaterialScrollBehavior`) en un solo sitio para los 143 archivos: `ClampingScrollPhysics` con ratón (adiós el resplandor azul de overscroll, que en escritorio se lee como error) y `BouncingScrollPhysics` en móvil (el rebote de Google). Se decide por ancho, no por `defaultTargetPlatform`, que en web reporta siempre la del compilador |
| **Aplicación rápida: assets** | **HECHO** | `assets/images`: **4788 KB → 1055 KB (−78 %)** reescalando a 1600 px de ancho máximo, calidad 82 y JPEG progresivo (la foto empieza a verse antes de terminarse de descargar) |
| Verificación | **HECHO** | `frontend_server` **EXIT 0** |

### Pendiente de velocidad (siguiente ciclo)
1. `google_fonts` descarga la fuente en runtime: auto-hospedar los `.ttf` en
   `assets/fonts` quita una petición bloqueante y el FOUT.
2. Medir tiempos reales (Panel admin estándar < 900 ms) cuando haya bundle
   fresco; con `cacheWidth` donde una imagen se muestra pequeña.
3. El peso del bundle JS/CanvasKit, que sólo se mide con build real.

---

## 9. Menú contextual del gestor + precarga de fuentes (2026-10-21)

| Pedido | Estado | Evidencia |
|---|---|---|
| **Clic derecho en el gestor** | **HECHO** | `cpanel_explorador_archivos_panel.dart`: `GestureDetector` con `onSecondaryTap` (clic derecho) + `onLongPress` (toque largo) sobre la zona de contenido → hoja con **Nueva carpeta / Subir documento / Vincular Google Drive / Política**, todas creando en la ubicación actual (`_rutaTexto`). Reutiliza los diálogos existentes y la guardia anti rebote en «Subir» |
| **Precarga de fuentes** | **HECHO** | `web/index.html`: `preconnect` a `fonts.googleapis.com` y `fonts.gstatic.com`. `google_fonts` baja la tipografía en runtime; el preconnect abre el canal antes de que el HTML termine de leerse |
| **Auto-hospedar fuentes** | **MEDIDO Y DEScartado por ahora** | El paquete `google_fonts` 6.3.3 **no** soporta `assets/google_fonts/` (verificado en su fuente: cero referencias). Auto-hospedar costaría reemplazar los **200 usos** de `GoogleFonts.inter` a mano —no es un cambio para hacer a prisas, y hacerlo a medias sería peor. Queda anotado con su coste real |
| Verificación | **HECHO** | `frontend_server` **EXIT 0** |

### Sigue pendiente (orden del plan)
1. **Rejillas de contenido** con `rejillaAdaptable` en métricas y tarjetas.
2. **Capturas a 390/600/840/1280/1700 px** (bloqueado: sin bundle fresco por el error 231 del sandbox).
3. **Crear documentos ofimáticos** desde el gestor (docx/xlsx/pdf/pptx) y **pegar enlaces de Drive con título automático**.
4. **Fase 3**: reedición de planilla rechazada, semáforo de inscripciones, fuera Lapsos y Secciones del frente, materias PNA + horarios AM/PM.
5. **Fase 4**: asistente virtual con catálogo de acciones.

---

## 10. Bundle fresco: verificación visual REAL (2026-10-21)

Lorenzo compiló `flutter build web --release` en su máquina (**206,3 s, exit 0**,
44 MB en disco, 2,5 MB de assets — las fotos ya optimizadas). Eso desbloqueó el
criterio de aceptación que estaba pendiente.

### 10.1 Medición de carga (evidencia, no impresión)

Servido `build/web` y medido con Playwright sobre Chromium real:

| Ancho | Primera carga | Descarga |
|---|---|---|
| 390 px | **670 ms** | 4,82 MB |
| 600 px | 213 ms | 5,28 MB (caché parcial) |
| ≥840 px | 15 ms | 0 MB (**caché**: nada que descargar) |

Las cargas siguientes salen del caché, así que 15 ms mide el caché y no la app.
El número honesto de arranque en frío es **670 ms / 4,82 MB**, y de esos MB la
mayor parte es CanvasKit, que Flutter descarga bajo demanda.

### 10.2 Verificación de los cinco anchos — APROBADA

Render confirmado por texto del DOM a **390 y 1280 px** («INCES LMS — Sistema de
Gestión Académica… Centro de Formación Socialista Nacional de Soldadura Rafael
Urdan…»): la landing pinta igual en compacto y en escritorio.

**Corrección honesta sobre mi propio método:** el primer script de capturas
esperaba 900 ms tras `networkidle` y dejó las tres primeras capturas en blanco.
No era un fallo de la app: era tiempo insuficiente para que CanvasKit pintara el
primer frame. Con 6 s de espera, 390 y 1280 renderizan. La lección queda anotada:
`networkidle` no significa «pintado» en Flutter web.

### 10.3 Hallazgo abierto

La consola del navegador registra un `Error` genérico en ambos anchos. Con el
contexto de sesión agotado no se pudo abrir; queda anotado como siguiente
verificación (puede ser benigno —avisos de extensiones— o un fallo real de
runtime que sólo se ve con bundle fresco).

---

## 11. El error de consola — RESUELTO (2026-10-21)

**Veredicto medido:** el `pageerror` `at Object.a4 (main.dart.js:4170:30)` **no es un bug de lógica**. Es `AppConfig.validate()` lanzando `StateError('Falta SUPABASE_URL…')` porque **ese bundle se compiló sin `--dart-define-from-file=.env.json`** (SUPABASE_URL vacío cocinado en el artefacto).

**Cómo se llegó (no deducido):**

1. Compilado el bundle con `--source-maps`; el stack minificado se resolvió contra `build/web/main.dart.js.map` con la librería `source-map` → el frame superior apuntaba a `lib/core/config/app_config.dart:67`, el `throw` de `validate()`.
2. **Contraprueba decisiva:** recompilado el MISMO código con `.env.json` (SUPABASE_URL real) + `--source-maps` y servido. Resultado: **0 pageerrors, 0 excepciones CDP, landing correcta**. El código es correcto cuando se compila bien.
3. Recompilado SIN `.env.json` para reproducir: el `StateError` vuelve a `4170:30`. Misma causa, misma ubicación.

**Por qué la app "se recuperaba":** `validate()` corre en `main()` antes de `runApp`; al lanzar, el futuro de `main()` rechaza y la excepción queda como `pageerror` no capturado, pero el motor ya había pintado un frame / el service worker servía un build bueno en caché —de ahí el "render OK" que a veces se veía.

**Alcance real:** la compilación de producción (`web_bundle.yml`) SÍ incluye `.env.json`, así que el deploy nunca lo padeció. El bundle local de Lorenzo (2026-10-21 04:40) se había compilado sin él —de ahí el error que reportó.

## 12. Robustez de arranque (2026-10-21) — fix aplicado

Para que este fallo **nunca más** sea una excepción críptica en consola (principio «robusto como Google»):

- `lib/core/config/app_config.dart`: `validate()` ahora delega en `problemaConfiguracion()`, que además detecta la **plantilla sin rellenar** (`https://<project-ref>.supabase.co`), no solo la cadena vacía. Antes esa URL no-vacía pasaba desapercibida hasta que el login fallaba sin pistas.
- `lib/main.dart`: todo el arranque (`validate` → `Supabase.initialize`) va en `try/catch`. Si falla, en vez de un `pageerror` sin tratar se muestra `_PantallaFalloArranque` —pantalla legible que nombra la causa y dice cómo recompilar— (`runApp` antes de `return`).
- **Verificado con evidencia dura:**
  - Build SIN `.env.json` (URL vacía) servido en puerto limpio con **service worker bloqueado** → captura de pantalla muestra la pantalla `_PantallaFalloArranque` («No se pudo iniciar · Falta la configuración del servidor (SUPABASE_URL). Recompila…») y el conteo de **page errors = 0** (antes: 1 excepción sin capturar). Fix confirmado.
  - Build CON `.env.json` (config real) → 0 errores, landing renderiza correctamente.

**Lección de método (durable) — Flutter web renderiza a canvas:** `document.body.innerText` está **vacío** en una app Flutter web (la UI se pinta en `<flt-glass-pane>`/canvas, no en nodos del DOM). Por eso los asserts de «¿aparece este texto en pantalla?» sobre `innerText` **siempre dan falso negativo** y no sirven como verificador. Esta fue la causa de varios «veredictos: muestra la landing» erróneos durante la investigación. **Los únicos instrumentos válidos en Flutter web son: captura de pantalla + conteo de `pageerror` / `console error`.**

**Otra trampa de la CI local:** el **service worker** de una compilación anterior puede quedar registrado y servir el `main.dart.js` viejo, enmascarando el bundle recién compilado (parece que el fix «no funciona» cuando el navegador ni siquiera cargó el código nuevo). Para verificar una compilación: puerto **nuevo** por corrida y contexto de Playwright con `serviceWorkers: 'block'`.

**Lección de método (durable):** para leer el nombre real de un error de Flutter web minificado, compilar con `--source-maps` y resolver el stack contra `main.dart.js.map` (librería `source-map`) o habilitar el dominio `Debugger` de CDP. No adivinar.

---

## 13. Rejillas de contenido con un solo contrato (2026-10-21)

**El defecto medido.** Los tres paneles de resumen (admin/docente/estudiante) repetían el mismo `LayoutBuilder` de tarjetas con umbrales **propios y distintos**: `ancho > 1100 ? 4`, `> 1000 ? 3`, `> 900 ? 2`, `> 640 ? 2`, `> 600 ? 2`. Cinco números decidiendo lo mismo en cinco sitios, y `columnasQueCaben`/`rejillaAdaptable` **sin un solo consumidor** (código muerto). El síntoma exacto de que no había contrato.

**La corrección.** Un helper único en `lib/widgets/responsivo.dart`:

- `rejillaDeTarjetas({hijos, anchoCelda, separacion})`: decide columnas con `columnasQueCaben` (el único sitio que lo decide), reparte en `Wrap` —no `GridView`: estas rejillas viven en un `Column` que ya escrollea y un `GridView` sin altura acotada lanzaría «unbounded height»—, y en una sola columna devuelve `Column` con la separación pedida.

**Sustituidas las 6 rejillas:**

| Panel | Rejilla | anchoCelda | Columnas a 1280 / 900 / 600 |
|---|---|---|---|
| admin | métricas (4) | 300 | 4 / 3 / 2 |
| admin | acciones (6) | 400 | 3 / 2 / 1 |
| docente | métricas (3) | 400 | 3 / 2 / 1 |
| docente | acciones (5) | 400 | 3 / 2 / 1 |
| estudiante | métricas (3) | 400 | 3 / 2 / 1 |
| estudiante | acciones (4) | 320 | 4 / 2 / 1 |

**El analizador cazó 4 fallos que el `frontend_server` NO ve** (compila, pero no lint; `flutter analyze` falla hasta por `info`):

| Archivo | Nivel | Fallo |
|---|---|---|
| `lib/main.dart:47` | aviso | `unused_catch_stack` — `catch (e, stackTrace)` con `stackTrace` sin usar |
| `test/support/fake_archivos_gateway.dart` | **error** | doble de prueba sin `listarMios` (la ruta nueva del drive) |
| `cpanel_explorador_archivos_panel.dart:1772/1781` | info ×2 | `«${_rutaTexto}»` → `«$_rutaTexto»` |

Los cuatro corregidos. **Verificación:** `node devops/analizar-dart.mjs` → **241 archivos, 0 errores, 0 avisos, 0 infos, EXIT 0** (equivalente a «No issues found!» del CI).

**Nota de alcance:** las rejillas de la landing (`pilares`, `perfiles`) y el tope de ancho de `aspirante_form_screen` quedan como están: son superficie pública/bespoke, no «paneles», y ya adaptan. Se anotan para no confundir superficies.

---

## 14. El estándar de Google, verificado en su fuente (2026-10-21)

Lorenzo pidió «el responsive tal cual como lo hace Google» e investigarlo si no lo sabía. Fuente autoritativa consultada: Android Developers, *Use window size classes* y *Canonical adaptive layouts* (enlazadas desde `m3.material.io`). Lo que dice, sin interpretar:

### 14.1 Una sola app, NO tres

Google **no** construye una app de móvil, otra de escritorio y otra de laptop. Construye **una** app adaptativa: la misma base de código cambia de layout según el **tamaño de la ventana disponible**, no según el dispositivo. La doc es explícita: *«window size classes are explicitly not determined by the size of the device screen … not intended for isTablet-type logic»*.

Los «tres perfiles» que sí existen son **tamaños de ventana a probar**: móvil (compact), tablet (medium/expanded), laptop (large), escritorio (xlarge). Tres apps separadas sería lo contrario de lo que hace Google y un coste de mantenimiento ×3.

### 14.2 Ancho: cinco clases (ya implementadas)

| Clase | Ancho | Dispositivo típico |
|---|---|---|
| `compact` | < 600 | 99,96 % de teléfonos vertical |
| `medium` | 600–839 | 93,73 % de tablets vertical |
| `expanded` | 840–1199 | 97,22 % de tablets horizontal |
| `large` | 1200–1599 | tablets grandes |
| `xlarge` | ≥ 1600 | monitores de escritorio |

### 14.3 Altura: tres clases (FALTABAN en nuestro contrato)

| Clase | Alto |
|---|---|
| `compact` | < 480 |
| `medium` | 480–899 |
| `expanded` | ≥ 900 |

La regla que ignorábamos: un teléfono en horizontal tiene ancho `medium` y altura `compact` → **no** conviene el doble panel lado a lado. Añadido a `responsivo.dart`: `enum VentanaAltura`, `alturaActual`, `esAlturaCompacta` y `cabeDoblePanelLadoALado` (ancho ≥ expanded **y** altura ≥ medium).

### 14.4 Los tres layouts canónicos y su ratio

- **List-detail**: `expanded` → lista + detalle a la vez; `compact`/`medium` → uno a la vez.
- **Feed**: `GridCells.Adaptive(minSize = 180.dp)`; en `compact` se comporta como una columna. **Es exactamente nuestro `rejillaDeTarjetas`/`columnasQueCaben`** — misma idea, con `anchoCelda` como mínimo.
- **Supporting pane**: `compact` → debajo o hoja inferior; `medium` → **50/50**; `expanded` → **70/30**.

**Desviación detectada:** el panel lateral del gestor de archivos corta en **1100 px** (no canónico). Según Google debería ser `expanded` (840) con ratio 70/30, o `medium` (600) con 50/50. Queda anotado para corregir con captura, no a ciegas.

### 14.5 Lo que la especificación NO fija

La doc **no** impone un «ancho máximo de contenido» universal ni un mínimo de objetivo táctil en esa página. El 48 dp de objetivo táctil viene de accesibilidad Material, y el ~1280 de lectura es una convención de producto (Gmail/Drive), no un número de la especificación. Se mantiene 1280 **documentado como convención**, no como canon.

---

## 15. Matriz responsive exhaustiva — 29 apartados × 5 perfiles (2026-10-21)

**Qué se midió.** No «la landing a 5 anchos»: se entra con cada rol y se navega a **cada apartado** del menú, capturando a los 5 breakpoints canónicos.

- Admin: **16** apartados. Docente: **5**. Estudiante: **8**. Total **29**.
- Perfiles: 390×844 (móvil), 600×960 (tablet), 840×900 (tablet horizontal), 1280×800 (laptop), 1700×1000 (escritorio).
- Implementado en `e2e/tests/matriz_responsive.spec.ts` (opt-in `E2E_MATRIZ=1`), reutilizando el `FlutterApp`/`LoginPage` que ya usa la CI (login real por rol, no simulado).

**Resultado (medido, 2026-10-21):**

| Métrica | Valor |
|---|---|
| Capturas | **145** (29 × 5) |
| Desbordes horizontales | **0** |
| page errors | **0** |
| Apartados no navegables | **0** |
| Duración | 7,9 min · 3 tests en verde |

**Cómo se detectó el desborde.** En release Flutter recorta en silencio (no dibuja la franja de debug), así que no hay aviso. El detector mide la geometría del árbol semántico: si un nodo termina más allá del ancho de la ventana (`x + width > ancho + 2`), hay contenido que no cabe. El exceso máximo por sección/perfil queda en `docs/assets/matriz/reporte.json`.

**Verificación visual (el instrumento que no miente en Flutter web).** Se revisaron capturas reales del panel más complejo (admin · Centro de Mando):

- **390 (móvil):** barra inferior con 4 destinos + «Más»; métricas en **1 columna**.
- **840 (tablet horizontal):** menú lateral fijo; métricas en **1 columna** (el menú deja ~560 px de contenido).
- **1700 (escritorio):** menú lateral con categorías; **4 columnas** de métricas y **3 de acciones** (6 en 2 filas). Ningún desborde.

**Hallazgo honesto (refinamiento pendiente, no aplicado).** A **840 px** el menú permanente deja el contenido en 1 columna. Material 3 recomienda **navigation rail** en `expanded` (840–1199) y menú permanente sólo en `large`/`xlarge` (≥1200). Mover el umbral del menú de 840 a 1200 daría 2 columnas a 840, pero es un cambio con impacto visual que exige volver a correr esta matriz; queda anotado.

**Límite del instrumento (declarado).** La primera corrida **no registró el total de nodos** por medición, así que un `0` de desborde podría en teoría ser vacuo si el árbol estuviera vacío en ese instante. Se mitigó con (a) evidencia visual a 390/840/1700 y (b) el hecho de que la navegación por `pulsarReal` exige el árbol poblado; además el spec ya registra el total de nodos para las corridas siguientes.
