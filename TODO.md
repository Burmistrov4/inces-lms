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
- [x] **Corregir discrepancia de módulos activos:**
  - [x] Actualizado cálculo dinámico de módulos operativos en `lib/screens/admin/admin_resumen_panel.dart`: excluye módulos en desarrollo (`m7_calificaciones` y `m7_asistencia`) del cálculo operativo activo, mostrando la métrica realista `8 / 10` y etiqueta `"8 operativos (2 en des.)"`.
- [x] **Paginación en "Invitaciones emitidas":**
  - [x] Añadida paginación (6 registros por página) con controles de "Anterior", "Siguiente" e indicador de páginas en `lib/screens/admin/cpanel_invitaciones_panel.dart`.
- [x] **Clarificar títulos de Auditoría:**
  - [x] Menú de `AdminDashboardScreen` actualizado:
    - `"Historial de Configuración"` (sustituye al ambiguo "Auditoría").
    - `"Registro de Inicios de Sesión / Accesos"` (sustituye a "Auditoría de Accesos").
  - [x] Navegación interna tolerante a alias en `_navegarA`.
- [x] **Verificación y Cobertura de Calidad:**
  - [x] Dart Analyzer: 0 errores, 0 avisos, 0 notas en 233 archivos (`node devops/analizar-dart.mjs`).
  - [x] Suite de Pruebas Backend: 33 archivos, 700 tests pasando exitosamente (`npm test`).
  - [x] Suite Completa de Pruebas Frontend / Flutter: 1030 tests pasando exitosamente (`flutter test`), incluyendo:
    - Pruebas de alcanzabilidad de menú (`test/menu_alcanzable_test.dart`).
    - Auditoría de adaptabilidad responsive en pantallas de 375 px a 1440 px (`test/barrido_responsive_test.dart`).
    - Consistencia visual y centralización estricta de tokens de color (`test/theme_literales_test.dart`).
    - Traducción y resiliencia de errores de red y backend (`test/archivos_gateway_test.dart`).
    - Landing page y catálogo formativo dinámico (`test/landing_page_test.dart`).
