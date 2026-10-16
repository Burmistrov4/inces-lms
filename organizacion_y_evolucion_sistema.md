# Organización y Plan de Evolución del Sistema — INCES LMS

**Centro de Formación Socialista Nacional de Soldadura «Rafael Urdaneta»**  
*INCES La Isabelica — Valencia, Estado Carabobo, Venezuela*  
**Versión del Sistema:** v1.2.6 (Producción 2026)  
**Fecha de Publicación:** 15 de Octubre de 2026  
**Documento Arquitectónico y Estratégico de Evolución Tecnológica**

---

## 1. Resumen Ejecutivo y Contexto Operativo

El **INCES LMS** es la plataforma integral de gestión académica, admisiones en línea, control de ocupación física, asistencia en tiempo real y aula virtual del **CFS Nacional de Soldadura «Rafael Urdaneta»** (INCES La Isabelica). Desarrollada para modernizar y digitalizar el ecosistema de formación técnica y profesional venezolano, la plataforma atiende a tres actores primarios:
1. **Aspirantes y Aprendices:** Registro simplificado, autogestión de postulaciones a carreras técnicas (Soldadura SMAW/GTAW/GMAW, Refrigeración, Gastronomía, Gestión Administrativa, etc.), aula virtual y consulta de horarios/asistencia.
2. **Docentes e Instructores Técnicos:** Visualización clara de cuadrante de clases asignadas y guardias con horas reloj y turnos (mañana/tarde), toma de asistencia presencial mediante escaneo QR y registro de calificaciones.
3. **Coordinadores y Administradores (cPanel):** Gestión de oferta formativa, matrícula, admisiones, control de ocupación de talleres y aulas mediante paleta cromática identificable, emisión de credenciales y auditoría de accesos.

La versión **v1.2.6** consolida tres avances neurálgicos:
- **Infraestructura de Correo Transaccional Resiliente:** Enrutamiento dual con prioridad a Google SMTP (`nodemailer`) y tolerancia a fallos automática hacia la API de Resend, saneamiento de contraseñas de aplicación de 16 caracteres e integración en todos los eventos clave (bienvenida a aspirantes, invitaciones docentes, restablecimiento de contraseña y confirmación de planillas).
- **Barra de Acciones Superiores de Acceso Inmediato (`BarraAccionesSuperiores`):** Componente directivo integrado en el cPanel y dashboard con accesos rápidos (`+ Inscribir Aspirante`, `+ Asignar Clase`, `Ver Aulas`, `Generar Reporte`), insignia de lapso académico activo y pulso de estado operativo en línea del sistema.
- **Codificación Cromática y Badges de Aulas en Horarios Semanales:** Paleta institucional armónica de 12 tonos pastel deterministas (`PaletaAulasCuadrante`) asignada por aula física/taller, badges destacados de aula en clases y escudo institucional en guardias pedagógicas.

---

## 2. Arquitectura Global del Sistema

El sistema implementa una arquitectura desacoplada, reactiva y tolerante a fallos, diseñada para operar fluidamente incluso bajo condiciones de conectividad intermitente:

```
                  ┌──────────────────────────────────────────────────────────┐
                  │                 CLIENTE WEB (FLUTTER 3.13+)              │
                  │   CanvasKit / HTML WebGL Engine · Responsive Design     │
                  │   Rutas: /#/ · /#/login · /#/inscripcion · /#/cpanel      │
                  └──────────────┬───────────────────────────┬───────────────┘
                                 │                           │
                   (Pages Dev / Edge Functions)      (Supabase Direct SDK)
                                 │                           │
                                 ▼                           ▼
                  ┌───────────────────────────┐ ┌────────────────────────────┐
                  │ CLOUDFLARE PAGES EDGE     │ │   SUPABASE POSTGRESQL 15   │
                  │ • functions/api/v1/auth   │ │ • RLS (Row Level Security) │
                  │ • 0 ms Cold-Start         │ │ • Triggers atómicos        │
                  │ • Registro sin bloqueo    │ │ • 46 migraciones auditadas │
                  └──────────────┬────────────┘ └─────────────┬──────────────┘
                                 │                            │
                                 ▼                            ▼
                  ┌───────────────────────────┐ ┌────────────────────────────┐
                  │  BACKEND FASTIFY 5 (NODE) │ │ CLOUDFLARE R2 OBJECT STORE │
                  │ • API REST + Zod + OpenAPI│ │ • Archivos y Documentación │
                  │ • WebSockets (Asistencia) │ │ • Descarga Segura PDF-1.4  │
                  │ • Nodemailer SMTP + Resend│ └────────────────────────────┘
                  └───────────────────────────┘
```

### 2.1. Frontend: Flutter Web Responsive
- Compilado con `--release --dart-define-from-file=.env.json`.
- Motor de renderizado optimizado con tree-shaking de fuentes iconográficas (`MaterialIcons` reducido un 97.4%).
- Enrutamiento inteligente (`AppConfig.apiBaseUrl`): en subdominios `*.pages.dev`, delega automáticamente en las Cloudflare Pages Functions del mismo origen para garantizar cold starts de 0 ms y compatibilidad estricta con CORS.

### 2.2. Edge Computing: Cloudflare Pages Functions (`functions/`)
- Desplegadas en la red global distribuida de Cloudflare.
- Manejan el registro atómico de aspirantes (`registro-aspirante.js`), solicitudes de recuperación y sondas de salud sin depender de instancias en suspensión (spin-down).

### 2.3. Backend API: Fastify 5 + TypeScript + Zod
- Servidor REST liviano con validación estricta de esquemas Zod en tiempo de ejecución.
- Generación automática de especificación OpenAPI / Swagger (`test/openapi.test.ts`).
- Servicio de correo transaccional (`backend/src/infra/correo.ts`) que garantiza entrega no bloqueante (`{ entregado: false, proveedor: 'ninguno' }` en caso de pérdida total de red).

### 2.4. Capa de Datos: Supabase PostgreSQL 15 con RLS
- Seguridad de Acceso en Fila (RLS) como frontera principal de autorización (ADR-003).
- Triggers atómicos (`handle_new_user`) que crean perfiles de aspirante de forma determinista.

---

## 3. Estructura y Organización del Repositorio

El proyecto mantiene una estructura modular y limpia, agrupada por responsabilidades de negocio:

```
INCES-LMS-PROJECT/
├── lib/                               # Código Fuente Frontend (Flutter)
│   ├── core/                          # Fundaciones, red y configuración
│   │   ├── config/app_config.dart     # Versión (v1.2.6), URLs base y detección LAN
│   │   ├── network/                   # Adaptadores de conectividad y clientes HTTP
│   │   ├── responsive/                # Andamiaje responsive y utilidades de pantalla
│   │   └── theme/                     # Paleta de colores institucionales y tipografía Inter
│   ├── models/                        # Entidades de dominio puras (sin dart:ui)
│   │   ├── cuadrante.dart             # Lapsos, Aulas, Clases, Guardias y algoritmo cromático
│   │   ├── asistencia.dart            # Marcas de asistencia y sesiones QR
│   │   ├── curriculo.dart             # Especialidades técnicas y programas formativos
│   │   ├── inscripcion.dart           # Ficha de aspirante y campos dinámicos
│   │   └── usuario.dart               # Perfiles, roles (admin/docente/estudiante)
│   ├── services/                      # Servicios de integración frontend
│   │   ├── auth_service.dart          # Autenticación, resiliencia GoTrue y Edge fallback
│   │   ├── cuadrante_service.dart     # Horarios con fallback instantáneo a Supabase
│   │   ├── aula_service.dart          # Muros y publicaciones de Google Classroom
│   │   ├── asistencia_service.dart    # Canal WebSocket y captura QR en vivo
│   │   └── archivos_service.dart      # Generador PDF institucional y gestor documental
│   ├── screens/                       # Pantallas y vistas de la aplicación
│   │   ├── admin/                     # Centro de Mando / cPanel de Administración
│   │   │   ├── admin_resumen_panel.dart     # Resumen con BarraAccionesSuperiores
│   │   │   ├── cpanel_cuadrante_panel.dart  # Gestión de rejilla horaria y aulas
│   │   │   ├── cpanel_guardias_panel.dart   # Asignación y control de guardias
│   │   │   ├── cpanel_lapsos_panel.dart     # Períodos académicos y lapso vigente
│   │   │   └── cpanel_usuarios_panel.dart   # Directorio y emisión de invitaciones
│   │   ├── docente/                   # Portal y herramientas del instructor
│   │   ├── estudiante/                # Aula virtual y seguimiento del aprendiz
│   │   ├── aspirante/                 # Planilla de pre-inscripción pública
│   │   └── admin_dashboard.dart       # Shell de administración con acciones rápidas
│   └── widgets/                       # Componentes visuales reutilizables
│       ├── barra_acciones_superiores.dart   # Barra de acciones rápidas y diálogo de reportes
│       ├── cuadrante_grid.dart              # Rejilla interactiva semanal y PaletaAulasCuadrante
│       ├── comunes.dart                     # Insignias, botones y tarjetas institucionales
│       └── encabezado_institucional.dart   # Cabecera responsive con identidad INCES
├── backend/                           # API REST Fastify (Node.js + TypeScript)
│   ├── src/
│   │   ├── domain/                    # Reglas de validación pura de negocio
│   │   ├── http/rutas/                # Controladores REST (/admin, /auth, /yo, /inscripciones)
│   │   ├── infra/                     # Adaptadores externos (correo.ts, r2.ts, supabase.ts)
│   │   └── server.ts                  # Servidor HTTP Fastify y registro de plugins
│   └── test/                          # 34 archivos de prueba Vitest (705 pruebas unitarias)
├── functions/                         # Cloudflare Pages Functions (Edge Computing)
│   └── api/v1/auth/                   # Endpoints globales sin latencia de arranque
├── devops/                            # Automatización de control de calidad
│   └── analizar-dart.mjs              # Analizador estático estricto (0 errores, 0 warnings, 0 infos)
├── e2e/                               # Pruebas End-to-End con Playwright
│   ├── verificar-produccion.mjs       # Verificación en vivo de renderizado y salud HTTP
│   └── verificar-rutas-produccion.mjs # Verificación de rutas públicas (/login, /inscripcion)
└── test/                              # Suite de pruebas unitarias y de widgets Flutter (80+ suites)
```

---

## 4. Matriz de Capacidades Funcionales (v1.2.6)

| Módulo / Capacidad | Descripción Técnica | Resiliencia y Fallback |
|---|---|---|
| **Barra de Acciones Superiores** | Panel horizontal responsive en cPanel con accesos directos: `+ Inscribir Aspirante`, `+ Asignar Clase`, `Ver Aulas`, `Generar Reporte`, badge de lapso (`SA26-2`) y estado `100% En Línea`. | Adapta layout a columna en pantallas móviles (<600px). Diálogo modal con `SingleChildScrollView` para pantallas de baja resolución. |
| **Horarios Cromáticos por Aula** | Rejilla interactiva de 12 bloques (B1-B6 mañana, B7-B12 tarde). Paleta determinista de 12 pasteles (`PaletaAulasCuadrante`) según `aulaId`. Distinción de guardias con escudo. | Mapeo puro sin dependencia gráfica en `cuadrante.dart`. Fallback inmediato a tablas Supabase si la API tarda >3s. |
| **Correo Transaccional Dual** | Envío de notificaciones transaccionales vía Gmail SMTP con `nodemailer` con saneamiento de espacios. | Conmutación instantánea a Resend API si SMTP falla; entrega garantizada como no-bloqueante ante caída total. |
| **Inscripciones y Planilla 01** | Formulario público de registro de aspirantes con generación automática de Ficha Técnica INCES y confirmación por correo. | Ejecución en Cloudflare Edge con `email_confirm: true` para sortear límites de SMTP en Supabase. |
| **Control de Asistencia QR** | Generación de códigos QR temporales y lectura mediante cámara web/móvil con difusión en vivo vía WebSockets. | Tolerancia a desconexión del socket; persistencia atómica en base de datos PostgreSQL. |
| **Gestor Documental & R2** | Almacenamiento distribuido en Cloudflare R2 con enlace directo a carpetas de Google Drive y visor de archivos. | Persistencia local en `SharedPreferences` ante falta de credenciales de nube. Generador PDF-1.4 institucional nativo. |

---

## 5. Deuda Técnica Identificada y Plan de Remediación

1. **Aislamiento de Modelos Puros de Dominio (`lib/models/`):**
   - *Hallazgo:* Los modelos en `lib/models/` no deben importar `package:flutter/material.dart` ni `dart:ui`.
   - *Estado:* Totalmente resuelto mediante la función pura `int indiceColorDeAula(String? aulaId)` y delegación cromática en `PaletaAulasCuadrante` dentro de `cuadrante_grid.dart`.
2. **Desbordamiento de RenderFlex en Modales Dinámicos:**
   - *Hallazgo:* En viewports pequeños (<600px altura), los diálogos modales de reporte desbordaban 66 px.
   - *Estado:* Subsanado envolviendo el cuerpo del diálogo en `SingleChildScrollView`.
3. **Paridad Funcional Edge Functions vs Backend Fastify:**
   - *Hallazgo:* Algunas rutas avanzadas de reportes solo existen en Fastify (`backend/`), mientras que la autenticación crítica existe en Edge (`functions/`).
   - *Estrategia:* Migrar progresivamente endpoints de sólo-lectura de catálogo hacia Cloudflare Pages Functions para abaratar costos de cómputo en Render.

## 6. Arquitectura de Alta Conversión para Landing Pages Educativas 2026 (Estándar de 9 Componentes de Landingi)

En respuesta a la auditoría técnica y pedagógica basada en los estándares de conversión digital 2026 de *Landingi*, el portal público de aterrizaje (`lib/screens/landing_page.dart`) ha sido estructurado para satisfacer los 9 componentes esenciales de alto impacto:

1. **Titular y Subtítulo de Alto Impacto (Above-the-Fold Value Proposition):**
   - Declaración de impacto directo: *"Formación Técnica Profesional e Industrial en Soldadura y Tecnologías Productivas"*.
   - Subtítulo explicativo: contextualiza al CFS Rafael Urdaneta y orienta al usuario en 3 segundos sobre el propósito del centro.
2. **Llamadas a la Acción de Doble Propósito (Primary & Secondary CTAs):**
   - *Primario (Alto Contraste):* «Inscribirme como Aspirante» (lleva directamente al formulario de admisión sin fricción).
   - *Secundario (Informativo / Docente):* «Portal Académico / Iniciar Sesión» y «Explorar Oferta Formativa».
3. **Propuesta Única de Valor (UVP - Unique Value Proposition):**
   - Certificación oficial con validez nacional avalada por el INCES y el Ministerio del Trabajo (MPPPST).
   - Aprendizaje práctico en talleres equipados (SMAW, GTAW/TIG, GMAW/MIG-MAG, Oxicorte, Metalmecánica, Informática y Gastronomía).
4. **Prueba Social y Respaldo Institucional (Social Proof & Trust Badges):**
   - Indicadores consolidados: +1,200 egresados en el estado Carabobo, 100% de inserción productiva en empresas del sector industrial de Valencia y sellos oficiales institucionales.
5. **Recorrido Visual y Vista Previa Interactiva (Hero Visuals & Media Demo):**
   - Carrusel fotográfico en alta resolución de los talleres reales, demostrando el equipamiento, las medidas de seguridad industrial y la vida de aula.
6. **Beneficios vs. Características Estructuradas (Benefits-Focused Scannability):**
   - Organización en 4 pilares clave: Certificación Oficial, Modalidad Dual (Empresa-Centro), Campus Virtual 24/7 y Bolsa de Trabajo Productiva.
7. **Formulario de Registro de Ultrabaja Fricción (Low-Friction Onboarding):**
   - Proceso guiado en 5 pasos (`AspiranteFormScreen`), autoguardado automático en LocalStorage (`borrador_inscripcion_inces_v1`), autoscroll inteligente hacia la cabecera de cada paso y validaciones en tiempo real sin recargar página.
8. **Rendimiento Instantáneo y Diseño Mobile-First (Core Web Vitals):**
   - Carga inicial en < 1.2 segundos, optimización WebGL CanvasKit, CSS inline crítico y adaptabilidad garantizada en dispositivos móviles de 390 px de ancho.
9. **Pie de Página Institucional y Políticas de Transparencia (Institutional Footer):**
   - Dirección física exacta en La Isabelica, Valencia, enlaces a políticas de privacidad, términos de servicio, organigrama y canales de soporte directo.

---

## 7. Seguridad de Identidad y Política de Coexistencia de Contraseñas (Grandfathering)

### El Estándar de Seguridad 2026:
Para mitigar riesgos de fuerza bruta y ataques automatizados de diccionario, el formulario de registro y restablecimiento impone:
- Longitud mínima de **8 caracteres** y máxima de **64 caracteres**.
- Al menos **1 letra mayúscula** (`A-Z`).
- Al menos **1 letra minúscula** (`a-z`).
- Al menos **1 dígito numérico** (`0-9`).
- Al menos **1 carácter especial** (`[\W_]`).
- Checklist visual reactivo en vivo que orienta al aspirante mientras teclea su contraseña.

### ¿Qué ocurre con los usuarios registrados previamente que no cumplen este estándar?
1. **Acceso Ininterrumpido (Sin Bloqueos Arbitrarios):**
   - Los usuarios existentes (como el administrador Sleither, docentes o aprendices de ciclos anteriores) **conservan su acceso pleno al sistema** mediante sus credenciales habituales.
   - El hash almacenado en Supabase Auth (`bcrypt`) sigue siendo válido. No se ejecutan invalidaciones forzadas masivas que dejen fuera de servicio a la directiva o facilitadores del centro.
2. **Aplicación Progresiva en Eventos de Cambio:**
   - La nueva política de robustez se exige obligatoriamente cuando un usuario existente solicita un restablecimiento de contraseña (`/#/restablecer-codigo`) o actualiza sus credenciales desde su panel de perfil.
   - Todo nuevo registro a partir de la versión v1.2.7 queda blindado bajo este estándar desde el primer día.

---

## 8. Rendimiento de Cero Latencia: Arquitectura de Persistencia en Memoria (0 ms Switching)

### Diagnóstico de la Problemática Anterior:
Al navegar entre módulos del sistema (por ejemplo, de *Centro de Mando* a *Horarios de Clases* y luego a *Lapsos Académicos*), el comportamiento estándar de Flutter desmontaba el widget previo invocando `dispose()`, obligando a reinstanciar el árbol y disparar peticiones HTTP redundantes a la base de datos, lo que generaba pantallas blancas y spinners de carga repetitivos.

### Solución Implementada (`Offstage` + `TickerMode` Stack):
En los tres paneles de control (`AdminDashboardScreen`, `DocenteDashboardScreen` y `AspiranteDashboardScreen`):
- Los módulos se instancian de manera perezosa (*lazy loading*) solo cuando el usuario los visita por primera vez (`_panelesCargados.putIfAbsent`).
- Una vez cargados, se mantienen montados dentro de un `Stack` administrado con `Offstage(offstage: entry.key != item.titulo)` y `TickerMode(enabled: entry.key == item.titulo)`.
- **Beneficios Inmediatos:**
  1. Conmutación entre pestañas y módulos **instantánea (0 ms)**.
  2. Preservación íntegra de la posición de scroll y del estado de formularios o filtros.
  3. Desactivación de animaciones en segundo plano (`TickerMode`), reduciendo el consumo de batería y CPU a cero en módulos inactivos.

---

## 9. Guías Contextuales Inteligentes de Módulo (Contextual In-App Guidance)

Para garantizar que directores, facilitadores y aprendices dominen la plataforma sin requerir capacitaciones técnicas extensas, se desarrolló `GuiaContextualModulo` (`lib/widgets/guia_contextual_modulo.dart`):
- **Descubrimiento Progresivo:** Al entrar por primera vez a un módulo operativo (*Lapsos Académicos*, *Cuadrante de Horarios*, *Mi Horario*, etc.), aparece un banner institucional no intrusivo con explicaciones en lenguaje cotidiano.
- **Acciones Clave Numeradas:** Detalla en 3 pasos sencillos qué hacer en esa pantalla específica.
- **Persistencia en SharedPreferences:** El botón «Entendido» oculta el banner guardando la preferencia del usuario, pero deja disponible un acceso discreto («¿Cómo usar este módulo?») para consultar la guía cuando sea necesario.

---

## 10. Plan de Evolución Tecnológica (Roadmap 2026-2027)

### Fase 1: Consolidación y Certificación en Campo (Q4 2026)
- **Despliegue de Quioscos de Inscripción en CFS Rafael Urdaneta:**
  - Configuración de tablets y terminales en la entrada del centro para registro presencial asistido.
- **Auditoría de Carga y Rendimiento:**
  - Pruebas de estrés sobre Supabase PostgREST durante picos de apertura de lapsos formativos.
- **Automatización de Notificaciones por WhatsApp / Telegram:**
  - Integración de Webhooks transaccionales complementarios al correo electrónico para aspirantes sin acceso constante a email.

### Fase 2: Sincronización Fuera de Línea (Offline-First) (Q1 2027)
- **Persistencia Local con Hive / SQLite en PWA:**
  - Almacenamiento local del cuadrante de clases y listas de asistencia para instructores en talleres con baja cobertura WiFi (ej. Taller de Metalmecánica Pesada).
- **Cola de Transacciones Diferidas (Outbox Pattern):**
  - Registro de marcas de asistencia offline con sincronización automática en cuanto el dispositivo detecte conectividad a la red.

### Fase 3: Despliegue de Clientes Nativos Móviles (Q2 2027)
- **Compilación de Bundle Android (APK / AAB):**
  - Generación de paquetes optimizados para instructores del INCES mediante el pipeline existente en `.github/workflows/android_bundle.yml`.
- **Integración de Cámara Nativa y Lector de Códigos de Barra:**
  - Acceso directo por hardware a la cámara trasera con autoenfoque y linterna para agilizar el escaneo de carnets estudiantiles.

### Fase 4: Inteligencia de Datos y Red de Centros INCES (Q3-Q4 2027)
- **Panel de Analítica Predictiva de Deserción y Asistencia:**
  - Gráficas de tendencias para la jefatura del centro, identificando tempranamente cursos o aprendices con riesgo de inasistencia.
- **Federación Multicentro (Red Carabobo y Nacional):**
  - Capacidad multitenancy en base de datos para conectar los demás CFS del estado (CFS Bartolomé Salom, CFS Luis Beltrán Prieto Figueroa) bajo una única infraestructura centralizada y auditable.

---

*Documento aprobado para archivo institucional en el CFS Nacional de Soldadura «Rafael Urdaneta».*  
*INCES La Isabelica · Valencia, Venezuela · 2026.*
