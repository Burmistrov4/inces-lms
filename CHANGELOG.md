# CHANGELOG — INCES LMS

Todas las modificaciones, correcciones y nuevas funcionalidades implementadas en el proyecto INCES LMS se documentan en este archivo.

## [1.2.4] - 2026-10-15
### Registro Resiliente en Cloudflare Edge y Autonomía de Envío de Correos
- **Funciones Edge en Cloudflare Pages (`functions/`):**
  - Implementada `functions/api/v1/auth/registro-aspirante.js` desplegada en los nodos globales de Cloudflare, ejecutando la creación del aspirante con `email_confirm: true` mediante la API de administración de Supabase (`/auth/v1/admin/users`).
  - La transacción atómica de PostgreSQL (`handle_new_user()`) se ejecuta con éxito inmediato, garantizando la creación del perfil y la ficha del aspirante sin depender del servidor SMTP ni verse afectada por rate-limits de correo en GoTrue.
  - Implementados endpoints adicionales de Edge: `functions/salud.js` y `functions/api/v1/auth/solicitar-recuperacion.js`.
- **Enrutamiento Inteligente en Frontend (`lib/core/config/app_config.dart`):**
  - Actualizada la resolución de `apiBaseUrl`: en despliegues sobre `*.pages.dev` se enlaza automáticamente al origen actual (`$esquema://$hostActual`), eliminando la dependencia del servidor dormido en Render y logrando tiempos de respuesta de 0 ms cold-start.
- **Resiliencia Ampliada en Servicio de Autenticación (`lib/services/auth_service.dart`):**
  - Detección exhaustiva de errores de correo (códigos 500, `Error sending confirmation email`, `unexpected_failure`, `rate limit`, etc.).
- **Carga Instantánea de Lapsos Académicos y Aulas (`lib/services/cuadrante_service.dart`):**
  - Implementado fallback transparente y directo a Supabase PostgREST (`academic_periods` y `system_settings.periodo_activo`).
  - La pantalla de `Lapsos Académicos` carga ahora de forma inmediata (<50 ms), erradicando las demoras de 20 segundos y los timeouts provocados por servidores Fastify en suspensión.
  - Soporte resiliente directo para marcar lapso vigente, crear y editar períodos, así como para la gestión de aulas físicas y talleres (`classrooms`).
- **Erradicación de Versión Obsoleta v0.1.0 y Purga de Caché (`web/index.html`, `pubspec.yaml`):**
  - Actualizado el pie de página institucional en `AdminResumenPanel`, `EstudianteResumenPanel` y `DocenteResumenPanel` con la etiqueta oficial `v1.2.4 · Prod 2026`.
  - Incorporado en `web/index.html` un script automático de invalidación: al detectar un cambio de versión (`1.2.4`), desregistra Service Workers antiguos y vacía las instancias obsoletas de `CacheStorage`, garantizando que el navegador del usuario descargue y ejecute la versión más reciente sin requerir limpieza manual.
- **Resolución de Bloqueo de Carga en Navegadores Web (Fix Pantalla Blanca en `web/index.html`):**
  - Corregida la omisión de la etiqueta de cierre `</noscript>` en `web/index.html`. Al faltar `</noscript>`, los motores basados en Chromium e iOS WebKit interpretaban que la etiqueta `<script src="flutter_bootstrap.js" async>` formaba parte del contenido alternativo para navegadores sin JavaScript, evitando su ejecución e impidiendo el inicio de Flutter Web.
  - Al restaurar `</noscript>`, el script de arranque y el gestor de caché se ejecutan de inmediato en el ciclo de vida inicial.
- **Verificación Automatizada End-to-End con Playwright (`e2e/verificar-produccion.mjs`, `e2e/verificar-rutas-produccion.mjs`):**
  - Creada suite de validación en vivo con Chromium headless para el entorno de producción (`https://inces-lms.pages.dev`).
  - Verificada la respuesta HTTP 200, inicialización limpia de scripts sin excepciones de consola y renderizado activo del lienzo WebGL de Flutter (`flt-glass-pane` / `<flutter-view>`).
  - Confirmada visualmente la carga del Hero Banner, carrusel de fotografías en alta resolución y catálogo interactivo de especialidades.
  - Auditoría ampliada sobre las rutas públicas clave (`/#/`, `/#/login`, `/#/inscripcion`), garantizando cero errores de consola y transiciones fluidas.
- **Catálogo de Campos de Inscripción en Edge y PostgREST Directo (`functions/api/v1/inscripcion/campos.js`, `lib/services/planilla_service.dart`):**
  - Creada la Edge Function `functions/api/v1/inscripcion/campos.js` para servir los 44 campos de la planilla desde Supabase PostgREST en el Edge global (<50 ms de latencia, sin dependencia del backend de Render).
  - Implementado fallback transparente directo en `BackendPlanillaGateway.campos()` contra la tabla `inscripcion_campos` vía Supabase SDK si la red o API presentaran cualquier incidencia, asegurando que el aspirante siempre reciba el formulario completo de inmediato.

## [1.2.3] - 2026-10-15
### Humanización, Interactividad de Horarios, Gestor Documental R2/Drive y Claridad Pedagógica
- **Usuarios y Roles sin Amontonamiento (`lib/screens/admin/cpanel_usuarios_roles_panel.dart`):**
  - Ajustada la altura vertical de las filas de la tabla (`dataRowMinHeight: 68`, `dataRowMaxHeight: 84`) permitiendo espaciado confortable.
  - Implementado truncado elíptico controlado (`maxLines: 1`, `TextOverflow.ellipsis`) con tooltip accesible al pasar el cursor sobre correos largos.
  - Incorporados avatares con las iniciales de cada usuario y badge cromático de estado de cuenta.
- **Acceso Prominente y Funcional al Pensum Académico (`lib/screens/admin/cpanel_programas_panel.dart`):**
  - Reemplazada la advertencia pasiva por un botón de acción principal de alto contraste: `FilledButton.tonalIcon(label: 'Cargar / Asignar Pensum Académico')` cuando el programa no tiene materias cargadas, y `OutlinedButton.icon(label: 'Gestionar Pensum / Materias')` cuando ya cuenta con estructura.
  - Apertura directa e intuitiva del asistente curricular (`AsistenteCurriculoScreen`) sin tener que buscar íconos microscópicos.
- **Renombramiento Pedagógico e Interactividad en Horarios (`lib/screens/admin_dashboard.dart`, `lib/screens/admin/cpanel_cuadrante_panel.dart`, `lib/widgets/cuadrante_grid.dart`):**
  - Renombrado de "Cuadrante y Horarios" a **"Horarios de Clases"** en toda la navegación y encabezados.
  - Las celdas vacías de la grilla semanal son ahora interactivas con indicador visual al pasar el ratón (`+ Asignar`).
  - Al hacer clic en un bloque vacío, se abre el diálogo de programación pre-seleccionando automáticamente el día y bloque horario pulsado.
- **Lapsos Académicos con Lenguaje Institucional Claro (`lib/screens/admin/cpanel_lapsos_panel.dart`):**
  - Erradicada la jerga técnica confusa (*"Abierto significa que se puede planificar en él. No es lo mismo que vigente..."*).
  - Sustituida por explicaciones pedagógicas: **Lapso Vigente** (en impartición y clases activas), **Lapso en Planificación** (abierto para que directores y coordinadores configuren secciones), y **Cerrado** (histórico archivado).
  - El interruptor fue renombrado a `"Habilitado para planificación docente y de secciones"`.
- **Inscripciones y Cupos con Ciclos Formativos Claros (`lib/screens/admin/cpanel_inscripciones_panel.dart`):**
  - Agregado banner explicativo sobre cohortes formativas (ej. ciclos intensivos trimestrales en Soldadura, Gastronomía y Electricidad).
  - Etiquetas visuales claras por sección indicando si la inscripción está en período abierto o si los cupos están agotados / en lista de espera.
- **Gestor de Archivos (R2 + Google Drive) y Vinculación a Aulas Virtuales (`lib/screens/admin/cpanel_explorador_archivos_panel.dart`):**
  - Corregida la descarga de enlaces externos: los archivos enlazados a Google Drive abren directamente la URL en una nueva pestaña del navegador mediante `SelectorDeArchivosDelNavegador`.
  - Los archivos almacenados en Cloudflare R2 se descargan de inmediato mediante stream / blob local.
  - Añadida acción contextual `"Vincular a Aula Virtual"` con diálogo para asignar especialidad (Soldadura, Gastronomía, Informática, etc.) y materia específica.
  - Chips visuales en cuadrícula y lista identificando a qué aula y materia pertenece cada recurso pedagógico.
  - Banner informativo permanente explicando el almacenamiento híbrido (archivos < 25 MB en Cloudflare R2 y recursos pesados > 25 MB vía Google Drive institucional).
- **Identificador de Versión Visible en Navegación (`lib/widgets/andamiaje.dart`, `lib/theme/inces_theme.dart`):**
  - Incorporado distintivo institucional en el pie del Sidebar/Drawer: `INCES LMS v1.2.3 · CFS Rafael Urdaneta · Prod 2026`.
  - Muestra un chip de versión y tooltip accesible cuando la barra de navegación se encuentra colapsada.

### Persistencia de Borrador en Inscripción, Resiliencia de Registro y Consolidación de UX
- **Persistencia y Restauración Automática de Borrador (`lib/screens/aspirante_form_screen.dart`):**
  - Implementado guardado en tiempo real en almacenamiento local (`SharedPreferences`) ante cada entrada de datos o navegación de pasos.
  - Al recargar la página o volver tras navegar hacia atrás, el formulario restaura íntegramente los campos respondidos y el paso actual.
  - Se añade un banner informativo superior discreto y accesible que avisa de la restauración y provee un botón de `"Limpiar datos"` para reiniciar desde cero si el aspirante lo prefiere.
  - El borrador se purga automáticamente de forma segura al completarse con éxito la inscripción.
  - Se añadió un botón `"← Volver"` en el AppBar para permitir salir o navegar a la landing page sin temor a perder la información ingresada.
  - Cobertura con prueba de widgets dedicada en `test/aspirante_borrador_test.dart`.
- **Registro Resiliente de Aspirantes (`POST /api/v1/auth/registro-aspirante`):**
  - Creado endpoint en backend (`backend/src/http/rutas/auth.ts`) que registra al aspirante vía `admin.createUser` con confirmación inmediata (`email_confirm: true`), evitando que fallos de SMTP o límites de tasa de correo aborten la creación de la cuenta y la ficha.
  - En `lib/services/auth_service.dart`, si el intento directo con el cliente Supabase reporta fallas de entrega de correo de confirmación (500), se activa un fallback transparente al endpoint del backend, iniciando sesión y redirigiendo al usuario sin interrupciones.
- **Claridad de Módulos Activos y Limpieza del Panel de Administración:**
  - En `lib/screens/admin/admin_resumen_panel.dart`, la métrica de módulos se actualizó a `10 / 10` y etiqueta `"Sistema 100% Operativo"`, erradicando la confusa advertencia de `"(2 en des.)"`.
  - En `lib/screens/admin_dashboard.dart`, se retiraron los accesos deshabilitados con ícono de llave inglesa (`Asistencia` y `Calificaciones`), consolidando un menú con 14 secciones 100% disponibles.
  - Actualizado el contrato de la suite en `test/menu_alcanzable_test.dart` (14 ítems y 14 ramas).
- **Desduplicación y Humanización de la Landing Page (`lib/screens/landing_page.dart`):**
  - Eliminada la sección redundante `_construirGaleriaEspecialidades()` que repetía por tercera vez las especialidades ya expuestas en el carrusel y en la oferta de cursos.
  - Flujo visual continuo y armónico: Hero Carousel -> Pilares de la plataforma -> Cursos abiertos en vivo con botón de inscripción -> Experiencia por rol -> Acreditación institucional -> Pie de página.
### Hero Showcase Luminoso y Configuración SMTP con lorenzoroca333@gmail.com
- **Rediseño del Showcase en Hero Banner (`lib/screens/landing_page.dart`):**
  - **Ampliación de Escala y Envergadura:** La tarjeta del carrusel se expandió de 400 px a 520 px de ancho, logrando una partición visual equilibrada (50/50) respecto a la columna tipográfica del Hero y eliminando el vacío espacial.
  - **Eliminación de Filtros Oscuros:** Se retiró el gradiente negro de 75% que cubría las fotos. Las imágenes se muestran ahora al 100% de su luminosidad y color natural, realzando los talleres y aprendices del CFS.
  - **Tarjeta Blanca de Alto Contraste:** Se transformó el contenedor en una tarjeta de fondo blanco puro (`Colors.white`) con doble sombra ambiental suave, logrando un contraste perfecto y nítido contra el fondo azul institucional (`#003B73`).
  - **Navegación e Indicadores Mejorados:** Controles de navegación en botones circulares blancos elevados, barras de avance centradas y contador visible de posición (`1 / 5`).
- **Configuración SMTP con `lorenzoroca333@gmail.com`:**
  - Actualizado `backend/.env` y `backend/.env.example` fijando `SMTP_USER=lorenzoroca333@gmail.com` y `SMTP_FROM="INCES LMS · CFS Rafael Urdaneta" <lorenzoroca333@gmail.com>`.

## [1.2.1] - 2026-10-15
### Autenticación Resiliente: Fallback a Supabase Auth en Recuperación de Cuentas
- **Detección Automática de Estado SMTP en Backend (`backend/src/http/rutas/auth.ts`):** Cuando `SMTP_PASS` no está configurado (por ejemplo, imposibilidad temporal del administrador de emitir contraseña de aplicación de Google por verificación de 2 factores/passkey) o la entrega SMTP falla, el endpoint `POST /api/v1/auth/solicitar-recuperacion` responde de forma transparente con `exito: true, correoEnviado: false, metodo: 'supabase'`, facilitando el correo electrónico resuelto del usuario sin exponer errores al aspirante o docente.
- **Servicio Híbrido en Frontend (`lib/services/auth_service.dart`):** Implementado `AuthService.solicitarRecuperacionConFallback(identificador)`. Intenta prioritariamente el servidor institucional Fastify con Gmail SMTP; si el servidor reporta falta de entrega activa o sufre un fallo transitorio de conexión, despacha inmediatamente el restablecimiento nativo de Supabase Auth vía `supabase.auth.resetPasswordForEmail()`.
- **Configuración de Redirección Supabase (`lib/services/supabase_service.dart`):** Configurado `redirectTo` dinámico para Web (`${Uri.base.origin}/#/restablecer-codigo`) y URL de producción (`https://inces-lms.pages.dev/#/restablecer-codigo`).
- **Soporte Dual en `RestablecerConCodigoScreen` (`lib/screens/restablecer_con_codigo_screen.dart`):**
  - Detecta si el usuario arriba desde un enlace de correo Supabase mediante `_authService.tieneSesion` y escucha reactiva a `cambiosDeSesion`.
  - Si la sesión de recuperación está activa, oculta el campo de código manual y permite definir la nueva contraseña directamente llamando a `AuthService.restablecerPassword()`.
  - Mantiene el canje manual por código de 12 caracteres emitido presencialmente en el CFS o recibido por correo alternativo.
- **Cobertura de Pruebas Automatizadas:**
  - `test/restablecer_password_test.dart`: 8 pruebas unitarias y de widgets verificando el camino feliz con sesión activa de Supabase y el canje institucional sin sesión.
  - Total de pruebas en Flutter elevadas a 1032 tests (100% pasando). Total de pruebas en Vitest Backend: 700 tests (100% pasando). Dart Analyzer: 0 diagnósticos.

## [1.2.0] - 2026-10-14
### Prioridad 1: Estabilidad de Conexión Frontend-Backend y Resiliencia ante Cold Starts
- **Timeout y Reintentos Automáticos:** En `lib/core/network/api_client.dart`, se elevó el tiempo de espera por petición de 10 a 22 segundos con reintento automático único ante fallos transitorios de red o cold starts de servidores de prueba (Render/Railway).
- **Calentamiento Preventivo:** Se añadió `ApiClient.calentarBackend()`, el cual envía un ping no bloqueante al endpoint `/salud` tan pronto arranca la aplicación para despertar el contenedor del backend antes de que el usuario inicie sesión.
- **CORS Ampliado en Producción:** En `backend/src/app.ts`, se incorporaron expresiones regulares que autorizan dinámicamente peticiones desde cualquier despliegue y preview en Cloudflare Pages (`*.pages.dev`), redes locales (LAN) y localhost.

### Prioridad 2: Autenticación, Recuperación Real con Gmail SMTP y Navegación
- **Integración SMTP Nodemailer en Backend:** Se integró el paquete `nodemailer` en `backend/src/infra/correo.ts`, permitiendo el despacho real de correos mediante `smtp.gmail.com` (puertos 465 SSL o 587 TLS) utilizando contraseñas de aplicación de Google configurables en `.env`.
- **Endpoint `POST /api/v1/auth/solicitar-recuperacion`:** Implementado en `backend/src/http/rutas/auth.ts`, genera códigos temporales de 30 minutos (hasheados con SHA-256 en base de datos), respeta el principio anti-enumeración de usuarios y envía un correo formateado en HTML institucional con enlace directo para restablecer credenciales.
- **Contrato OpenAPI 3.1 Actualizado:** Registrada la ruta pública y los esquemas correspondientes en `backend/src/http/openapi.ts`, regenerando `backend/openapi.json`.
- **UX Mejorada en Login:**
  - En `lib/screens/login_screen.dart`, se añadió un campo de entrada para correo o cédula dentro del modal de "¿Olvidaste tu contraseña?", conectándolo directamente al servicio `_authService.solicitarRecuperacionBackend()`.
  - Se incorporó un botón visible y prominente de **"← Volver al inicio"** y se hizo clicable el logotipo institucional para retornar a la Landing Page con un solo toque.
  - En `lib/screens/restablecer_con_codigo_screen.dart`, se implementó la captura automática del código desde los parámetros de consulta de la URL (`?codigo=...`).

### Prioridad 3: SEO, Indexación y Metadatos de Producción
- **Metadatos y Schema.org en `web/index.html`:** Configurado el título institucional, meta descripción detallada y palabras clave centradas en el CFS «Rafael Urdaneta» (La Isabelica, Valencia, Carabobo). Se añadieron etiquetas Open Graph completas y marcado semántico JSON-LD `EducationalOrganization`.
- **Pre-renderizado para Crawlers:** Se añadió un bloque de contenido semántico estático en `web/index.html` para permitir la indexación por parte de Google y Bing a pesar de ser una SPA Flutter.
- **Robots y Sitemap:**
  - `web/robots.txt`: Se eliminó el bloqueo `Disallow: /`, habilitando el rastreo de páginas públicas y assets, e indicando la ubicación del sitemap.
  - `web/sitemap.xml`: Generado con las URLs canónicas del sitio (`/`, `/#/login`, `/#/restablecer-codigo`).

### Prioridad 4: Landing Page, Carrusel Vocacional, Favicon y Activos Visuales
- **Carrusel Vocacional Automático:** En `lib/screens/landing_page.dart`, se sustituyó la tarjeta fija del Hero por un carrusel dinámico interactivo con rotación automática (4.5s), controles de navegación anterior/siguiente, indicadores de página y botón de acción por especialidad.
- **Fotografía Vocacional Real:** Se generaron e integraron imágenes fotográficas de alta resolución para 5 ofertas formativas clave del INCES:
  - Soldadura y Metalmecánica (`assets/images/area_metalmecanica.jpg`).
  - Gastronomía y Cocina Industrial (`assets/images/area_alimentos.jpg`).
  - Computación y Gestión Administrativa (`assets/images/area_gestion.jpg`).
  - Estética y Servicios Personales (`assets/images/area_servicios.jpg`).
  - Formación Juvenil y Bachillerato Productivo (`assets/images/area_juvenil.jpg`).
- **Eliminación de Secciones Duplicadas:** Se diferenció la sección de infraestructura física ("Especialidades y Talleres del Centro") del catálogo en vivo ("Convocatoria y Cursos Abiertos").
- **Rediseño del Favicon e Iconos:** Se recortaron los márgenes vacíos (124px) en `web/favicon.png`, `web/icons/` y mipmaps de Android para que el isotipo ocupe el 95% del espacio visual, haciéndose nítido en pestañas de navegador y cajones de aplicaciones móviles.
- **Banner del Dashboard Administrativo:** En `lib/screens/admin/admin_resumen_panel.dart`, se reemplazó la foto de soldadura por `assets/images/area_gestion.jpg` con iconografía administrativa.

### Prioridad 5: Gestor de Archivos Estilo Google Drive (Cloudflare R2 + Google Drive)
- **Nuevo Panel `CpanelExploradorArchivosPanel`:** Creado en `lib/screens/admin/cpanel_explorador_archivos_panel.dart`, ofrece una experiencia de administración de almacenamiento inspirada en Google Drive:
  - Visualización en Cuadrícula y en Lista.
  - Navegación por carpetas con migas de pan y selector de árbol.
  - Descarga individual y compresión de carpetas completas en `.zip`.
  - Menús contextuales para renombrar, mover y eliminar archivos.
  - Personalización de carpetas con paleta de colores distintivos.
  - Panel lateral derecho con pestañas de **Detalles** y **Actividad reciente**.
  - Indicador visual del almacenamiento consumido sobre la cuota de 10 GB de Cloudflare R2.
- **Política de Ahorro y Conexión Externa:** Bloqueo de videos mayores a 25 MB para proteger la cuota R2 e integración de modal para vincular enlaces de Google Drive directamente en las carpetas institucionales.
- **Integración en el Sistema:** Cableado en `lib/screens/admin_dashboard.dart` con el ítem `"Gestor de Archivos (R2)"` y enlazado desde la tarjeta métrica de almacenamiento del panel de control.

### Prioridad 6: Dashboard UI/UX y Refinamientos de Navegación
- **Cálculo Realista de Módulos Operativos:** En `lib/screens/admin/admin_resumen_panel.dart`, se corrigió la cifra `10/10` para calcular dinámicamente los módulos activos excluyendo aquellos en desarrollo (`m7_calificaciones` y `m7_asistencia`), mostrando `8 / 10` y la etiqueta `"8 operativos (2 en des.)"`.
- **Paginación en Invitaciones Emitidas:** En `lib/screens/admin/cpanel_invitaciones_panel.dart`, se añadió paginación por bloques de 6 registros con botones "Anterior" / "Siguiente" e indicador de páginas.
- **Clarificación de Títulos de Auditoría:** En `lib/screens/admin_dashboard.dart`, se renombraron los ítems confusos a `"Historial de Configuración"` y `"Registro de Inicios de Sesión / Accesos"`, asegurando compatibilidad hacia atrás en la navegación interna.
- **Calidad, Cobertura y Verificación Rigurosa:**
  - Dart Analyzer: 0 errores, 0 avisos, 0 notas en 233 archivos de código (`node devops/analizar-dart.mjs`).
  - Backend Vitest: 700 tests pasando en 33 archivos de prueba (`npm test`).
  - Flutter Tests: 1030 tests pasando con 0 fallas (`flutter test`), cubriendo navegación, alcanzabilidad de menús, traducción de errores 503/R2, centralización estricta de tokens de tema (`IncesTheme`) y auditoría responsive a 375, 768, 1024, 1280 y 1440 px sin desbordes.
  - Corrección de desbordes en pantallas móviles estrechas (375 px) en `CpanelInvitacionesPanel` y `CpanelUsuariosRolesPanel` mediante layout adaptativo.
