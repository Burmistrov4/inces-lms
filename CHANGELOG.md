# CHANGELOG — INCES LMS

Todas las modificaciones, correcciones y nuevas funcionalidades implementadas en el proyecto INCES LMS se documentan en este archivo.

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
