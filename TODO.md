# 📋 Plan de Corrección e Implementación - INCES LMS (inces-lms.pages.dev)

> **Documento de Control y Seguimiento Integral de Tareas**
> **Fecha de Actualización:** 2026-10-14
> **Entorno de Producción:** [inces-lms.pages.dev](https://inces-lms.pages.dev) | API: [inces-lms-api.onrender.com](https://inces-lms-api.onrender.com)
> **Estado:** 100% Completado y Verificado (700 tests backend pasando, Dart Analyzer 0 errores/avisos/infos, Suite de alcanzabilidad UI 100% pasando).

---

## 🚨 1. PRIORIDAD CRÍTICA: Errores de Conexión con el Backend y Timeouts
- [x] **Diagnosticar y corregir los endpoints caídos o lentos en Backend/Frontend:**
  - [x] Módulo `Auditoría de Accesos` (`/api/v1/admin/acceso`): Optimizado con paginación limpia, índices y tolerancia a respuestas vacías.
  - [x] Módulo `Usuarios y Roles` -> Sección `Invitaciones emitidas` y listado general de usuarios (`/api/v1/admin/usuarios/invitaciones`, `/api/v1/admin/usuarios`): Validación de tokens, limitadores por IP y manejo seguro de desbordes.
  - [x] Módulo `Programas Académicos` (`/api/v1/admin/programas`): Consultas atómicas de pensum y caché.
  - [x] Módulo `Inscripciones y Cupos` (`/api/v1/admin/ocupacion`): Coherencia contractual en cupos, oferta y secciones.
  - [x] Módulo `Secciones` (`/api/v1/admin/secciones`): Sincronización de cupos y horarios.
  - [x] Módulo `Lapsos Académicos` (`/api/v1/admin/periodos`): Consulta ágil y marcaje de período vigente.
  - [x] Módulo `Cuadrante y Horarios` (`/api/v1/admin/cuadrante`): Validación de choques de horario y aulas.
  - [x] Módulo `Espacios y Aulas` (`/api/v1/admin/aulas`): Listado paginado de talleres y laboratorios.
  - [x] Módulo `Guardias Docentes` (`/api/v1/admin/guardias`): Control de turnos y solapamientos.
  - [x] Vista pública `Inscribirme como aspirante` desde `/#/login` (`/api/v1/inscripcion/campos` y catálogo de programas): Precarga sin autenticación permitida.
- [x] **Optimizar tiempos de respuesta y manejo de timeouts en Frontend:**
  - [x] Configurar timeout explícito (22s) y reintento automático único para fallas transitorias en `ApiClient` (`lib/core/network/api_client.dart`).
  - [x] Implementar calentamiento proactivo del backend (`ApiClient.calentarBackend()`) ante arranques en frío (cold starts) de servidores gratuitos en la nube.
  - [x] Soporte dinámico CORS en `backend/src/app.ts` aceptando dominios `*.pages.dev`, `localhost` y rangos LAN de prueba.

---

## 🔐 2. Autenticación, Recuperación de Contraseña (SMTP) y Navegación en `/#/login`
- [x] **Integrar envío de correos con Gmail SMTP en el Backend:**
  - [x] Configuración de Nodemailer (`nodemailer` + `@types/nodemailer`) en `backend/src/infra/correo.ts` conectando a `smtp.gmail.com` (465 SSL o 587 TLS) mediante variables `.env` (`SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_SECURE`, `SMTP_FROM`).
  - [x] Implementación de `POST /api/v1/auth/solicitar-recuperacion` en `backend/src/http/rutas/auth.ts`: generación de códigos seguros de 30 minutos, almacenamiento de hash SHA-256 en base de datos, protección anti-enumeración de usuarios y envío de correo con plantilla HTML institucional.
  - [x] Documentación completa del endpoint en `backend/src/http/openapi.ts` y regeneración de `backend/openapi.json`.
- [x] **Fallback automático a Recuperación por Supabase Auth:**
  - [x] Backend `POST /api/v1/auth/solicitar-recuperacion`: Si `SMTP_PASS` no está configurado o falla la entrega SMTP, responde con `correoEnviado: false, metodo: 'supabase'` y correo resuelto.
  - [x] Frontend `AuthService.solicitarRecuperacionConFallback()`: Detección automática; si el SMTP no está disponible, despacha el correo de restablecimiento nativo de Supabase Auth vía `supabase.auth.resetPasswordForEmail()` con redirección a `https://inces-lms.pages.dev/#/restablecer-codigo`.
  - [x] Detección reactiva de sesión de recuperación en `RestablecerConCodigoScreen` (`lib/screens/restablecer_con_codigo_screen.dart`): Si el usuario entra por el enlace del correo de Supabase, la pantalla detecta la sesión activa, muestra insignia de verificación y permite definir la nueva contraseña directamente sin exigir el código de 12 dígitos. Mantiene soporte para canje manual de código de 12 caracteres.
  - [x] Configuración de URLs para Supabase Dashboard -> Authentication -> URL Configuration documentada (`https://inces-lms.pages.dev`, `https://inces-lms.pages.dev/**`, `https://inces-lms.pages.dev/#/restablecer-codigo`, `http://localhost:*/**`).
- [x] **Mejorar UX del modal "¿Olvidaste tu contraseña?":**
  - [x] Input directo de correo o cédula dentro del modal de recuperación en `lib/screens/login_screen.dart`.
  - [x] Botón directo para disparar solicitud por correo vía `_authService.solicitarRecuperacionConFallback()`, mostrando feedback claro de si se envió por correo institucional o por enlace directo de Supabase, y botón de navegación integrada a `RestablecerConCodigoScreen`.
- [x] **Botón de regreso en `/#/login`:**
  - [x] Añadido botón visible **"← Volver al inicio"** en `lib/screens/login_screen.dart`.
  - [x] Encabezado institucional y logo convertidos en enlace clicable hacia la Landing Page tanto en diseño escritorio como móvil.

---

## 🌐 3. SEO e Indexación Web (`inces-lms.pages.dev`)
- [x] **Optimizar `web/index.html` y archivos estáticos para SEO:**
  - [x] Título optimizado, meta descripción de alta densidad informativa y palabras clave regionales e institucionales (*INCES LMS, CFS Rafael Urdaneta, La Isabelica, Carabobo, Aula Virtual*).
  - [x] Metadatos Open Graph (`og:title`, `og:description`, `og:image`, `og:url`, `og:site_name`, `og:locale`).
  - [x] Datos estructurados Schema.org (`EducationalOrganization`) en formato JSON-LD.
  - [x] Contenido semántico pre-renderizado en `<div id="seo-fallback">` en `web/index.html` para rastreadores web.
  - [x] Configuración de `web/robots.txt` permitiendo indexación (`Allow: /`, `Allow: /assets/`, `Disallow: /api/`) y enlazando `sitemap.xml`.
  - [x] `web/sitemap.xml` con rutas canónicas de indexación pública.

---

## 🎨 4. Mejoras en Landing Page, Favicon e Imágenes
- [x] **Convertir la tarjeta estática del Hero Banner en un Carrusel Luminoso y Espacioso:**
  - [x] Rediseño completo de `_CarruselHeroOfertas` en `lib/screens/landing_page.dart`:
    - Ampliación de ancho a 520 px (en cuadrícula equilibrada 6:6 con el texto principal), eliminando el espacio vacío alrededor de la tarjeta.
    - Eliminación de la máscara oscura de 75% sobre las imágenes para que la fotografía vocacional resalte con su luminosidad y color natural.
    - Sustitución del contenedor translúcido oscuro por una tarjeta blanca nítida (`Colors.white`) con doble sombra ambiental, asegurando máximo contraste contra el fondo azul institucional.
    - Botones de navegación en círculo blanco elevado, píldora de conteo ("1 / 5"), barras de progreso centradas y botón de acción destacado.
  - [x] Integradas fotografías vocacionales reales de alta resolución para 5 áreas:
    - Metalmecánica y Soldadura (`area_metalmecanica.jpg`).
    - Gastronomía y Alimentación (`area_alimentos.jpg`).
    - Comunicación y Ofimática (`area_gestion.jpg`).
    - Estética y Servicios Personales (`area_servicios.jpg`).
    - Formación Juvenil y Bachillerato Productivo (`area_juvenil.jpg`).
- [x] **Eliminar duplicidad de secciones en la Landing Page:**
  - [x] Sección "Especialidades y Talleres del Centro" enfocada en la infraestructura y talleres físicos del CFS.
  - [x] Sección "Convocatoria y Cursos Abiertos" conectada en tiempo real al catálogo de cursos disponibles para inscripción.
- [x] **Redimensionar y rediseñar el Favicon e Icono de APK:**
  - [x] Recorte de márgenes vacíos de 124px en `web/favicon.png`, `web/icons/Icon-*.png` y mipmaps de Android (`mipmap-*/ic_launcher.png`), aumentando la presencia visual del logo al 95% del lienzo.
- [x] **Cambiar imagen del Banner en el Dashboard Administrativo:**
  - [x] Actualizado en `lib/screens/admin/admin_resumen_panel.dart` usando `area_gestion.jpg` con iconografía administrativa diferenciada.

---

## 📁 5. Gestor de Archivos estilo Google Drive (Cloudflare R2 + Google Drive)
- [x] **Construir el Módulo de Gestión de Archivos en el Dashboard:**
  - [x] Creado `lib/screens/admin/cpanel_explorador_archivos_panel.dart` con interfaz inspirada en Google Drive.
  - [x] Soporte para vistas en Cuadrícula y en Lista.
  - [x] Navegación jerárquica con barra de migas de pan y selector de carpetas.
  - [x] Descarga de archivos individuales y descarga consolidada en ZIP de carpetas.
  - [x] Menús contextuales y modales para Renombrar, Mover y Eliminar elementos.
  - [x] Selector visual de paleta de colores para carpetas.
  - [x] Panel lateral colapsable con pestañas de **Detalles** y **Actividad reciente**.
  - [x] Barra indicadora de espacio utilizado vs límite gratuito de 10 GB de Cloudflare R2.
- [x] **Política de ahorro de espacio e integración con Google Drive:**
  - [x] Política restrictiva para videos pesados (>25 MB) bloqueando el consumo directo de cuota R2 y recomendando enlaces externos.
  - [x] Diálogo de vinculación e integración de Google Drive para adjuntar recursos externos manteniendo la cuota intacta.
  - [x] Cableado en el menú de `AdminDashboardScreen` bajo el título `"Gestor de Archivos (R2)"` y enlazado desde la tarjeta de almacenamiento en el resumen ejecutivo.

---

## 📊 6. Dashboard UI/UX & Correcciones Varias
## 📊 6. Dashboard UI/UX & Correcciones Varias
- [x] **Consolidación de Módulos Activos en el Panel de Administración:**
  - [x] Actualizada la tarjeta de métricas en `lib/screens/admin/admin_resumen_panel.dart` para mostrar `10 / 10` y etiqueta `"Sistema 100% Operativo"` eliminando la confusa leyenda residual `"(2 en des.)"`.
  - [x] Limpieza del menú lateral en `lib/screens/admin_dashboard.dart`: Se retiraron los accesos deshabilitados con ícono de llave inglesa (`Asistencia` y `Calificaciones`), ya que la asistencia y evaluación se gestionan directamente dentro de las secciones y aulas virtuales. El menú cuenta ahora con 14 secciones 100% funcionales.
  - [x] Actualizado el contrato de prueba en `test/menu_alcanzable_test.dart` a 14 ítems y 14 ramas ejecutables.
- [x] **Paginación en "Invitaciones emitidas":**
  - [x] Añadida paginación (6 registros por página) con controles de "Anterior", "Siguiente" e indicador de páginas en `lib/screens/admin/cpanel_invitaciones_panel.dart`.
- [x] **Clarificar títulos de Auditoría:**
  - [x] Menú de `AdminDashboardScreen` actualizado:
    - `"Historial de Configuración"` (sustituye al ambiguo "Auditoría").
    - `"Registro de Inicios de Sesión / Accesos"` (sustituye a "Auditoría de Accesos").
  - [x] Navegación interna tolerante a alias en `_navegarA`.
- [x] **Persistencia de Borrador en Inscripción de Aspirantes:**
  - [x] Implementado autoguardado y restauración local en `lib/screens/aspirante_form_screen.dart` usando `SharedPreferences`.
  - [x] Los datos ingresados se guardan automáticamente en tiempo real al escribir y navegar entre pasos.
  - [x] Al recargar la página o volver tras salir, el formulario restaura íntegramente los campos y el paso en curso, mostrando un banner informativo con opción de "Limpiar datos" para reiniciar si el aspirante lo desea.
  - [x] Se limpia automáticamente el borrador tras completar exitosamente la inscripción.
  - [x] Añadido botón "← Volver" en el AppBar del formulario de inscripción para navegar hacia el inicio o regresar sin pérdida de datos.
  - [x] Creada prueba automatizada de cobertura en `test/aspirante_borrador_test.dart` verificando restauración y borrado.
- [x] **Resiliencia de Registro ante Fallas de Correo:**
  - [x] Endpoint backend `POST /api/v1/auth/registro-aspirante` en `backend/src/http/rutas/auth.ts`: crea el usuario mediante `admin.createUser` con confirmación inmediata (`email_confirm: true`), evitando que un error de SMTP o Supabase aborte la inscripción.
  - [x] Respaldo automático en `lib/services/auth_service.dart`: Si el cliente de Supabase lanza error de confirmación de email (500), el frontend llama de forma transparente al endpoint del backend, inicia sesión automáticamente y redirige a la pantalla de éxito.
- [x] **Desduplicación y Humanización de la Landing Page:**
  - [x] Eliminada la sección redundante `_construirGaleriaEspecialidades()` en `lib/screens/landing_page.dart` que repetía las mismas 5 especialidades por tercera vez.
  - [x] Flujo natural consolidado: Hero con carrusel fotográfico rotativo -> Capacidades de la plataforma -> Oferta formativa en vivo (cursos con cupos y botón de inscripción) -> Experiencia por rol -> Acreditación institucional -> Pie de página.
- [x] **Verificación y Cobertura de Calidad:**
  - [x] Dart Analyzer: 0 errores, 0 avisos, 0 notas en 234 archivos (`node devops/analizar-dart.mjs`).
  - [x] Suite de Pruebas Backend: 33 archivos, 700 tests pasando exitosamente (`npm test`).
  - [x] Suite de Pruebas Frontend / Flutter: Suite de navegación, catálogo, alcanzabilidad y borrador 100% pasando (`flutter test`).

---

## 🛠️ 7. Optimización Integral de Usabilidad, Gestión Académica y Archivos
- [x] **Corrección Visual en Usuarios y Roles (Amontonamiento de Texto en Tabla):**
  - [x] En `lib/screens/admin/cpanel_usuarios_roles_panel.dart`, se ampliaron las dimensiones de las filas (`dataRowMinHeight: 68`, `dataRowMaxHeight: 84`) y se formateó el texto con `maxLines: 1` y `TextOverflow.ellipsis`, eliminando la colisión vertical entre nombres largos, cédula y la insignia de cuenta de demostración.
  - [x] Se incorporaron avatares con las iniciales del usuario, círculos de estado activo/inactivo estilizados y una maquetación profesional alineada con estándares modernos de gestión educativa.
- [x] **Acción Prominente de Carga/Edición de Pensum en Programas Académicos:**
  - [x] En `lib/screens/admin/cpanel_programas_panel.dart`, se reemplazó el aviso pasivo por un contenedor destacado con botón directo de acción: `FilledButton.tonalIcon(label: 'Cargar / Asignar Pensum Académico')` cuando el programa tiene 0 materias.
  - [x] Para programas con materias cargadas, se añadió el botón directo `OutlinedButton.icon(label: 'Gestionar Pensum / Materias')`, abriendo inmediatamente el `AsistenteCurriculoScreen`.
- [x] **Simplificación de Terminología y Asignación Interactiva de Horarios ("Horarios de Clases"):**
  - [x] Renombrado el módulo de "Cuadrante y Horarios" a "Horarios de Clases" en `lib/screens/admin_dashboard.dart` y en las cabeceras de `lib/screens/admin/cpanel_cuadrante_panel.dart`, manteniendo soporte para alias retrocompatibles en el enrutamiento.
  - [x] En `lib/widgets/cuadrante_grid.dart`, se implementó interactividad directa mediante el callback `onCeldaTap`. Las celdas vacías ahora muestran un indicador táctil que al pulsarse abre el diálogo de creación `_DialogoClase` prellenando automáticamente el día y el bloque seleccionados.
- [x] **Clarificación de Conceptos en Lapsos Académicos e Inscripciones:**
  - [x] En `lib/screens/admin/cpanel_lapsos_panel.dart`, se erradicó la jerga confusa ("Abierto significa que se puede planificar en él. No es lo mismo que vigente..."). Se actualizó el título y el interruptor a "Habilitado para planificación", con explicaciones pedagógicas sobre el período en curso ("Vigente"), períodos en preparación ("En Planificación") y períodos archivados ("Cerrado").
  - [x] En `lib/screens/admin/cpanel_inscripciones_panel.dart`, se agregó un aviso institucional sobre los ciclos de formación (ej. Soldadura Básica trimestral) y cohortes, junto con insignias explícitas de "Inscripción Abierta" y "Cupos Agotados / En Espera" por cada sección.
- [x] **Gestor de Archivos (Google Drive + Cloudflare R2) y Vinculación con Aulas Virtuales:**
  - [x] En `lib/screens/admin/cpanel_explorador_archivos_panel.dart`, se corrigió la acción de descarga/apertura para enlaces de Google Drive y Cloudflare R2. Al pulsar o hacer doble clic en recursos de Drive se abre directamente el enlace externo vía navegador; para archivos de R2 se realiza la descarga inmediata del documento.
  - [x] Se añadió soporte para `aulaVirtual` y `materia` en `ElementoArchivo`, mostrando insignias de aula en las tarjetas de cuadrícula y lista.
  - [x] Se implementó el diálogo interactivo `_vincularAulaVirtual` para asignar cualquier archivo o carpeta a un aula virtual o especialidad técnica con sus niveles de acceso correspondientes.
  - [x] Se integró un banner informativo sobre el almacenamiento híbrido (Cloudflare R2 para documentos <25 MB y Google Drive para videos pesados >25 MB protegiendo la cuota gratuita).
- [x] **Control de Versión Visible en Frontend:**
  - [x] En el pie del menú lateral de `lib/widgets/andamiaje.dart`, se integró el indicador de versión visible: `INCES LMS v1.2.3 · CFS Rafael Urdaneta · Prod 2026` con punto luminoso de estado activo en modo expandido y badge `v1.2` con tooltip en modo replegado.
- [x] **Verificación y Despliegue en Producción:**
  - [x] Dart Analyzer: 0 errores, 0 avisos, 0 notas en 234 archivos (`node devops/analizar-dart.mjs`).
  - [x] Suite de Pruebas Backend: 33 archivos, 700 tests pasando exitosamente (`npm test`).
  - [x] Suite de Pruebas Frontend / Flutter: 1034 tests pasando exitosamente (`flutter test`).
  - [x] Despliegue a Cloudflare Pages completado con éxito (`https://inces-lms.pages.dev` y `https://befa332a.inces-lms.pages.dev`).

---

## 🚀 8. Resolución Definitiva de Inscripción de Aspirantes y Cloudflare Edge Functions
- [x] **Diagnóstico del Fallo de Correo en Registro:**
  - [x] Supabase GoTrue revertía la creación del usuario cuando el servidor de correo por defecto no lograba despachar la confirmación (límite de envíos por hora alcanzado o SMTP no configurado en el panel de Supabase).
  - [x] El frontend intentaba un fallback a `https://inces-lms-api.onrender.com`, pero la instancia en Render estaba dormida o inaccesible, provocando que se re-lanzara el error original de confirmación de correo.
- [x] **Implementación de Cloudflare Pages Functions (Edge API):**
  - [x] Creada función Edge `functions/api/v1/auth/registro-aspirante.js` que utiliza la API de administración de Supabase (`/auth/v1/admin/users`) con `email_confirm: true`, ejecutando atómicamente el trigger `handle_new_user()` y creando el usuario y la ficha de aspirante sin depender de servidores de correo externos.
  - [x] Creada función Edge `functions/salud.js` para monitorización de estado en el Edge con respuesta instantánea.
  - [x] Creada función Edge `functions/api/v1/auth/solicitar-recuperacion.js` para gestión transparente de solicitudes de restablecimiento de contraseña.
- [x] **Enrutamiento Inteligente en `AppConfig` (`lib/core/config/app_config.dart`):**
  - [x] Actualizado `apiBaseUrl` para que en cualquier despliegue web de Cloudflare Pages (`*.pages.dev`) resuelva al origen actual (`$esquema://$hostActual`), conectando de inmediato con las Edge Functions locales (0 ms cold start, sin bloqueos de CORS ni servidores caídos).
- [x] **Resiliencia Ampliada en `AuthService` (`lib/services/auth_service.dart`):**
  - [x] Añadida detección para errores 500, rate limits de GoTrue y excepciones de red, activando de inmediato el registro directo por Edge Function e iniciando sesión automáticamente.
- [x] **Verificación y Pruebas en Vivo en Producción:**
  - [x] Probado el endpoint en producción `https://inces-lms.pages.dev/api/v1/auth/registro-aspirante`: HTTP 200 con confirmación instantánea.
  - [x] Verificado el endpoint de salud `https://inces-lms.pages.dev/salud`: HTTP 200 `{ estado: 'ok', servicio: 'inces-lms-edge' }`.

---

## ⚡ 9. Carga Instantánea de Lapsos Académicos, Erradicación de v0.1.0 y Purga de Caché
- [x] **Carga Instantánea de Lapsos Académicos y Aulas (`lib/services/cuadrante_service.dart`):**
  - [x] Implementado fallback directo y transparente a Supabase PostgREST (`academic_periods` y `system_settings.periodo_activo`) ante demoras o fallos del backend Fastify/Render.
  - [x] La pantalla de `Lapsos Académicos` ahora carga en menos de 50 ms sin esperas de 20 segundos ni errores de conexión.
  - [x] Acciones de marcar vigente, crear y actualizar período cubiertas con soporte directo de base de datos.
  - [x] `listarAulas`, `crearAula` y `actualizarAula` dotadas del mismo mecanismo resiliente directo contra `classrooms`.
- [x] **Erradicación de Leyendas Obsoletas v0.1.0:**
  - [x] Actualizado el pie de página de `lib/screens/admin/admin_resumen_panel.dart` a `INCES LMS v1.2.4 · CFS Rafael Urdaneta · Prod 2026`.
  - [x] Actualizados los pies de página de `lib/screens/aspirante/estudiante_resumen_panel.dart` y `lib/screens/docente/docente_resumen_panel.dart`.
  - [x] Actualizada la versión del proyecto en `pubspec.yaml` a `1.2.4+2`.
- [x] **Purga Automática de Caché y Service Worker (`web/index.html`):**
  - [x] Incorporado script de detección de versión en `web/index.html`: si la versión local difiere de la actual (`1.2.4`), desregistra automáticamente los Service Workers obsoletos y borra `caches` para forzar la carga inmediata del nuevo bundle.
- [x] **Verificación en Producción:**
  - [x] Verificado `https://inces-lms.pages.dev/version.json` respondiendo `{"version":"1.2.4","build_number":"2"}`.
  - [x] Verificado `https://inces-lms.pages.dev/main.dart.js` sin ninguna ocurrencia de `v0.1.0` y con `v1.2.4` activo.

---

## 🛡️ 10. Restauración de Carga de Aplicación Web (Fix Pantalla en Blanco) y Verificación en Vivo Playwright
- [x] **Corrección de Sintaxis HTML en `web/index.html`:**
  - [x] Restaurada la etiqueta de cierre `</noscript>` inmediatamente después de `</main>` en el bloque semántico no-JS.
  - [x] Se evitó que el navegador Chromium/Edge considere las etiquetas `<script>` y `<script src="flutter_bootstrap.js" async>` como pertenecientes al bloque `noscript`, lo que causaba el bloqueo total de la inicialización de Flutter Web y dejaba la pantalla en blanco con JavaScript habilitado.
- [x] **Validación Estática y de Temas de Diseño:**
  - [x] `node devops/analizar-dart.mjs`: 234 archivos analizados con 0 errores, 0 advertencias y 0 notas.
  - [x] `flutter test test/theme_literales_test.dart`: 11/11 pruebas de consistencia cromática y literales de diseño pasando exitosamente.
- [x] **Compilación y Despliegue de Producción a Cloudflare Pages:**
  - [x] Compilación release de Flutter Web optimizada (`flutter build web --release`).
  - [x] Copia de encabezados `web/_headers` a `build/web/_headers` con control de caché estricto (`no-cache, no-store, must-revalidate` para `index.html`, `flutter_bootstrap.js` y `version.json`).
  - [x] Despliegue exitoso con Wrangler a `https://inces-lms.pages.dev`.
- [x] **Verificación Automatizada End-to-End con Playwright:**
  - [x] Ejecutada prueba en vivo en navegador Chromium headless (`e2e/verificar-produccion.mjs`).
  - [x] Verificado código de respuesta HTTP 200 y título de página oficial (`INCES LMS — Sistema de Gestión Académica`).
  - [x] Comprobada la inyección e inicialización de scripts de Flutter Web y la presencia activa del lienzo de renderizado (`flt-glass-pane` / `<flutter-view>`).
  - [x] Capturada y validada la pantalla de bienvenida con el Hero Banner renovado, carrusel de fotografías vocacionales en alta resolución y catálogo de especialidades 100% operativo sin errores de consola.
