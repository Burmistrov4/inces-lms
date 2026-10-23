# 📘 Manual Arquitectónico y Protocolo Operativo Autónomo: INCES LMS (CFS «Rafael Urdaneta», La Isabelica)
**Para:** Gemini Argon (AI Engineering Agent / Pair Programmer)  
**Proyecto:** INCES LMS — Sistema de Gestión Académica, Matrícula, Cuadrante de Talleres y Planilla Digital  
**Institución:** Instituto Nacional de Capacitación y Educación Socialista (INCES) — Centro de Formación Socialista Nacional de Soldadura «Rafael Urdaneta» (La Isabelica, Valencia, Edo. Carabobo, Venezuela)  
**Versión de Producción:** `v1.3.2 (Prod 2026)`  
**Dominio de Producción:** [https://inces-lms.pages.dev](https://inces-lms.pages.dev)  
**API REST Backend:** [https://inces-lms-api.onrender.com](https://inces-lms-api.onrender.com)  
**Repositorio GitHub:** `https://github.com/Burmistrov4/inces-lms.git`  
**Último Commit de Producción:** `19adf82`  
**Fecha de Emisión:** 19 de Octubre de 2026  

---

## 🧭 1. Resumen Ejecutivo y Misión para Gemini Argon

Este documento constituye la **guía maestra de transferencia de ingeniería** para que cualquier agente de inteligencia artificial (particularmente Gemini Argon) pueda integrarse de inmediato, entender la totalidad de la arquitectura técnica e histórica, y operar de manera autónoma bajo un ciclo continuo estricto de:
$$\text{AUDITAR} \longrightarrow \text{PROGRAMAR} \longrightarrow \text{VERIFICAR / REVISAR} \longrightarrow \text{ARREGLAR} \longrightarrow \text{VOLVER AL CICLO}$$

### El Contexto Social e Institucional
El CFS Rafael Urdaneta ubicado en la Zona Industrial La Isabelica es el centro insignia nacional del INCES para la enseñanza de **Soldadura Universal (SMAW, GTAW/TIG, GMAW/MIG-MAG, Oxicorte)**, Refrigeración Industrial, Gastronomía, Informática y Mecánica. El sistema atiende a tres actores:
1. **Aspirantes y Estudiantes:** Inscripción en línea con planilla digital milimétrica, autogestión de matrícula, consulta de calificaciones, aula virtual y descarga dual de planilla (PDF oficial HACER y Excel `.xlsx` editable).
2. **Docentes e Instructores de Taller:** Visualización del cuadrante semanal con horarios y turnos (mañana 07:30-11:45 / tarde 12:15-16:30), registro y pase de asistencia por escaneo QR en vivo y carga de notas.
3. **Coordinadores y Administradores (cPanel):** Gestión de oferta académica, pensum, lapsos académicos, ocupación de aulas físicas mediante codificación cromática determinista, asignación docente y emisión de credenciales.

### La Regla de Oro ($0 Cost Cloud Infrastructure)
El sistema opera bajo **Coste Cero Absoluto ($0 USD)** mediante el apilamiento de capas gratuitas de alta disponibilidad:
- **Cloudflare Pages:** Hosting frontend global en edge con 0 ms de latencia inicial.
- **Supabase Cloud (PostgreSQL 15):** Autenticación y base de datos relacional con Row Level Security (RLS).
- **Render Fastify 5 (Node.js):** Microservicios de backend, pasarela SMTP, validación de esquemas Zod y generación de documentos.
- **Cloudflare R2:** Almacenamiento seguro de objetos y expedientes digitales.

---

## 🏛️ 2. Arquitectura Global y Topología del Código

El repositorio contiene **~90,200 líneas de código auditadas** divididas entre frontend, backend y pruebas automatizadas:
- `lib/` (Flutter Web Frontend): 143 archivos `.dart` (~49,600 líneas).
- `backend/` (Fastify 5 + TypeScript REST API): ~18,700 líneas.
- `test/` (Flutter Unit, Widget & Golden Tests): ~21,900 líneas.
- `e2e/` (Playwright Browser Automation): Pruebas funcionales de extremo a extremo y captura fotográfica de roles.

```
                              ┌──────────────────────────────────────────────┐
                              │          CLIENTE WEB (FLUTTER 3.13+)         │
                              │        CanvasKit WebGL Engine + Responsive   │
                              │  /#/ (Landing) · /#/login · /#/inscripcion   │
                              │   /#/cpanel · /#/docente · /#/aspirante      │
                              └──────────────────────┬───────────────────────┘
                                                     │
                             ┌───────────────────────┴───────────────────────┐
                             │                                               │
               (API Gateway Client via HTTPS)                   (Supabase SDK Direct RLS)
                             │                                               │
                             ▼                                               ▼
              ┌──────────────────────────────┐                ┌──────────────────────────────┐
              │   BACKEND FASTIFY 5 (NODE)   │                │    SUPABASE POSTGRESQL 15    │
              │  Fastify + TypeScript + Zod  │                │  RLS (Row Level Security)    │
              │  OpenAPI /api/v1/*           │                │  Triggers y Procedimientos   │
              │  Nodemailer SMTP + Resend    │                │  46 Migraciones Históricas   │
              └──────────────┬───────────────┘                └──────────────┬───────────────┘
                             │                                               │
                             ▼                                               ▼
              ┌──────────────────────────────┐                ┌──────────────────────────────┐
              │     CLOUDFLARE R2 BUCKET     │                │   INFRAESTRUCTURA DE EMAIL   │
              │  Archivos de Alumnos y PDFs  │                │  Google Workspace SMTP       │
              │  Gestor Documental Seguro    │                │  Fallback dinámico a Resend  │
              └──────────────────────────────┘                └──────────────────────────────┘
```

### 2.1. Desglose del Frontend (`lib/`)
- `lib/core/`:
  - `config/app_config.dart`: Resolución dinámica de endpoints (`apiBaseUrl`, URLs de Supabase, timeouts de 22s y reintentos ante cold-starts).
  - `errors/app_exception.dart`: Excepciones tipadas con códigos de fallo inmutables.
  - `gateways/`: Interfaces abstractas de acceso a datos (`planilla_gateway.dart`, `cuadrante_gateway.dart`, `invitacion_gateway.dart`, etc.). Permiten inyección de fakes para testing sin mocks frágiles.
  - `reglas_cuadrante.dart`: Lógica matemática y temporal de la rejilla horaria de talleres.
  - `result.dart`: Mónada `Result<T>` (`success(T)` o `failure(AppException)`) para flujo funcional libre de excepciones no controladas.
- `lib/models/`: Modelos inmutables con deserialización segura (`cuadrante.dart`, `seccion.dart`, `materia.dart`, `programa.dart`, `archivo.dart`, `invitacion_docente.dart`).
- `lib/screens/`:
  - `landing_page.dart`: Portada institucional con carrusel hero, catálogo de cursos, buscador inteligente en vivo con auto-scroll y footer directivo.
  - `login_screen.dart`: Autenticación con fallback de recuperación de contraseña y selección de roles.
  - `aspirante_form_screen.dart`: Formulario interactivo por pasos para la planilla de admisión INCES.
  - `admin_dashboard.dart` y `screens/admin/*`: cPanel maestro con submódulos gobernados por interruptores de estado.
  - `docente_dashboard.dart`: Horario semanal, toma de asistencia QR y calificaciones del facilitador.
  - `aspirante_dashboard.dart`: Resumen de admisión, estatus de matrícula y descarga de planilla (PDF y Excel).
- `lib/theme/inces_theme.dart`: Sistema de diseño institucional inviolable. Centraliza colores institucionales (`azulPrimario: #003B73`, `rojoInces: #D32F2F`), modo oscuro (`fondoOscuro: #0F172A`) y paleta de 12 colores armónicos para aulas (`coloresAulasCuadrante`).
- `lib/widgets/`:
  - `andamiaje.dart`: Shell principal con sidebar colapsable en escritorio y drawer nativo en móvil.
  - `barra_acciones_superiores.dart`: Barra de acceso rápido para acciones operativas frecuentes.
  - `guia_contextual_modulo.dart`: Píldora móvil de 36px y bottom sheet deslizable con instrucciones operativas paso a paso.
  - `walkthrough_interactivo.dart`: Guía paso a paso superpuesta para onboarding de administradores, docentes y alumnos.

### 2.2. Desglose del Backend (`backend/`)
- `src/server.ts`: Bootstrap del servidor Fastify con soporte CORS, WebSockets y compresión.
- `src/app.ts`: Registro modular de rutas bajo prefijo `/api/v1/`.
- `src/http/rutas/`: Endpoints tipados con Zod (`auth.ts`, `admin.ts`, `inscripciones.ts`, `cuadrante.ts`, `yo.ts`, `archivos.ts`, `asistencia.ts`).
- `src/infra/correo.ts`: Enrutamiento dual SMTP (Nodemailer hacia Google Workspace con fallback resiliente hacia Resend).

---

## ⚙️ 3. El Ciclo Autónomo para Agentes de IA

Cualquier agente que trabaje en esta base de código debe seguir rigurosamente este ciclo de 5 fases sin excepciones:

```
      ┌─────────────────────────────────────────────────────────────┐
      │                                                             │
      ▼                                                             │
┌──────────────┐     ┌──────────────┐     ┌──────────────┐          │
│   FASE 1:    │ ──> │   FASE 2:    │ ──> │   FASE 3:    │          │
│   AUDITAR    │     │  PROGRAMAR   │     │  VERIFICAR   │          │
└──────────────┘     └──────────────┘     └──────┬───────┘          │
                                                 │                  │
                                           ¿Fallos o Lints?         │
                                                 │                  │
                                       ┌─────────┴─────────┐        │
                                       ▼                   ▼        │
                                   [ SI ]                [ NO ]     │
                                       │                   │        │
                                       ▼                   ▼        │
                                ┌──────────────┐     ┌───────────┐  │
                                │   FASE 4:    │     │  FASE 5:  │  │
                                │   ARREGLAR   │     │ DESPLEGAR │──┘
                                └──────┬───────┘     └───────────┘
                                       │
                                       └───────────────────┘
```

### Fase 1: Auditar (Inspección Previa Obligatoria)
Antes de modificar una sola línea de código:
1. Inspeccionar el estado de Git:
   ```powershell
   git status -s
   ```
2. Ejecutar análisis estático para garantizar que se parte de una base limpia:
   ```powershell
   dart analyze --fatal-infos
   ```
3. Si el cambio involucra el backend, validar la suite previa:
   ```powershell
   cd backend && npm test && cd ..
   ```
4. **Revisar restricciones cromáticas:** Leer `test/theme_literales_test.dart`. **Prohibido terminantemente** añadir `Color(0x...)` fuera de `lib/theme/inces_theme.dart` o escribir `fillColor: Colors.white` a mano.

### Fase 2: Programar (Implementación Quirúrgica)
1. **Preservar Invariantes de Base de Datos:**
   - **CERO `DELETE` FÍSICOS.** Toda eliminación es lógica mediante `activa = false` o marcas de archivo.
   - Jamás romper la compatibilidad con esquemas Zod en `backend/src/esquemas/`.
2. **Patrón Gateway / Repositorio:**
   - La UI nunca llama a clientes HTTP directos. La UI habla con un `Repository`, el `Repository` habla con un `Gateway`.
   - Si se añade un método al Gateway, debe agregarse en:
     1. La interfaz abstracta (`lib/core/gateways/*_gateway.dart`).
     2. El repositorio correspondiente (`lib/repositories/*_repository.dart`).
     3. El fake de testing (`test/support/fake_*_gateway.dart`).
3. **Manejo de Errores Tipados:**
   - Retornar siempre `Result.success(valor)` o `Result.failure(AppException)`. No lanzar excepciones no tipadas en capas de dominio.
4. **Diseño Visual Responsivo:**
   - Todos los diálogos deben soportar pantallas móviles (375 px) sin desbordes `RenderFlex`.
   - Utilizar `Builder(builder: (ctx) => MediaQuery.sizeOf(ctx).width < 500 ? Column(...) : Row(...))` en lugar de `LayoutBuilder` dentro de `AlertDialog` para evitar colisiones con dimensiones intrínsecas.

### Fase 3: Verificar y Revisar (Doble Barrera de Calidad)
Ejecutar la batería completa de pruebas:
1. **Análisis Estático (Frontend):**
   ```powershell
   dart analyze --fatal-infos
   ```
   *Criterio de aprobación:* 0 issues, 0 warnings, 0 infos.
2. **Pruebas de Backend (Vitest):**
   ```powershell
   cd backend && npm test && cd ..
   ```
   *Criterio de aprobación:* 34/34 archivos pasados, 705/705 tests aprobados.
3. **Pruebas de Barrido Responsivo y Temas (Flutter):**
   ```powershell
   flutter test test/barrido_responsive_test.dart test/theme_literales_test.dart test/cuadrante_paneles_test.dart
   ```
4. **Suite Completa de Flutter:**
   ```powershell
   flutter test
   ```
   *Criterio de aprobación:* 1,045/1,045 pruebas aprobadas.

### Fase 4: Arreglar (Resolución Inmediata de Regresiones)
Si algún test falla durante la Fase 3:
- **Falla en `theme_literales_test.dart`:** Significa que se colocó un `Color(0x...)` o `Colors.white` en una pantalla o widget de formulario. Mover el color a `IncesTheme` o usar `theme.colorScheme.onPrimary`.
- **Falla en `cuadrante_rejilla_panel_test.dart`:** Comprobar que no haya un `LayoutBuilder` directo en un `AlertDialog`.
- **Falla en aserciones de texto:** Comprobar si un commit previo refinó la redacción institucional (ejemplo: «Módulo / Trimestre» en lugar de «Período»).
- Volver inmediatamente a la **Fase 3** hasta que todo esté en verde.

### Fase 5: Desplegar y Cerrar Ciclo
Una vez verificada la suite con 0 errores:
1. Comprobar diferencias:
   ```powershell
   git status -s
   ```
2. Realizar commit con convención semántica:
   ```powershell
   git add .
   git commit -m "feat(modulo): descripcion concisa de la mejora operativa"
   ```
3. Publicar en producción:
   ```powershell
   git push origin <rama_actual>:main
   git push origin <rama_actual>
   ```
4. Confirmar que [https://inces-lms.pages.dev](https://inces-lms.pages.dev) responda en línea (HTTP 200).

---

## 📋 4. Los Tres Dashboards Principales y su Estado Operativo

### 4.1. Dashboard de Administración (cPanel)
- **Ruta:** `/#/cpanel`
- **Submódulos:** 
  1. *Programas y Pensum:* Asistente de 3 pasos para carreras técnicas (ej. Soldadura por Arco, PNA).
  2. *Lapsos Académicos:* Configuración de períodos con presets automáticos (`+3 meses`, `+6 meses`, `Iniciar hoy`).
  3. *Cuadrante de Clases:* Rejilla matricial 6 días × 12 bloques horarios con coloreado determinista de aulas físicas.
  4. *Espacios y Talleres:* Gestión de talleres de soldadura, aulas de teoría y laboratorios.
  5. *Guardias Pedagógicas:* Turnos de custodia técnica docente.
  6. *Usuarios y Roles:* Gestión de permisos (Admin, Docente, Alumno), emisión de invitaciones por email y auditoría.
  7. *Campos de Inscripción:* Motor dinámico de preguntas de la planilla oficial.
  8. *Gestor Documental:* Subida y descarga de archivos vinculados a Cloudflare R2.
- **Acciones Rápidas Superiores:** `BarraAccionesSuperiores` con botón de invitación rápida de docentes y atajo a inscripciones.

### 4.2. Dashboard de Docente / Facilitador
- **Ruta:** `/#/docente`
- **Funcionalidades:**
  - Consulta de cuadrante semanal personal con indicación de turnos y bloques en hora militar/reloj.
  - Generador de QR dinámico para pase de asistencia en tiempo real por WebSocket.
  - Listado de secciones asignadas y módulo de calificaciones continuas.

### 4.3. Dashboard de Estudiante / Aspirante
- **Ruta:** `/#/aspirante`
- **Funcionalidades:**
  - Consulta del estatus de su postulación e inscripción en cursos.
  - **Doble botón de descarga:**
    - `📄 Descargar planilla oficial (PDF)`: Formato milimétrico oficial INCES-HACER (1 página A4 optimizada).
    - `📊 Descargar en Excel (.xlsx) editable`: Archivo estructurado con todos los campos rellenados por el usuario.
  - Acceso al aula virtual y material didáctico.

---

## 🛠️ 5. Puntos Clave de Mantenimiento y Extensión Futura

1. **Gestión de Invitaciones por Correo:**
   - La pantalla de *Usuarios y Roles* incluye ahora un botón modal para invitar facilitadores mediante su correo electrónico (`POST /api/v1/admin/usuarios/invitaciones`).
   - El backend genera un token de un solo uso y despacha un correo HTML formal.
   - En caso de testing local o sin SMTP, la interfaz muestra el enlace de activación directo para copiar en el portapapeles.

2. **Walkthrough Interactivo Multi-Rol:**
   - Implementado en `lib/widgets/walkthrough_interactivo.dart`. Permite a los usuarios recién registrados recorrer las áreas clave de la plataforma mediante un overlay contextual animado con globos explicativos.

3. **Verificación Visual E2E con Screenshots:**
   - El script `e2e/capturar-dashboards-roles.mjs` utiliza Playwright para navegar automáticamente por la plataforma en modo emulado, conectarse con las credenciales de cada rol y generar capturas de alta resolución de todos los módulos sin romper la capa semántica de Flutter Web (`flt-semantics`).

---

## 🎯 6. Comandos de Supervivencia para Gemini Argon

| Operación | Comando Exacto |
|---|---|
| **Auditar código Dart** | `dart analyze --fatal-infos` |
| **Pruebas Flutter específicas** | `flutter test test/barrido_responsive_test.dart test/cuadrante_paneles_test.dart` |
| **Pruebas Flutter completas** | `flutter test` |
| **Pruebas Backend completas** | `cd backend && npm test && cd ..` |
| **Generar Screenshots E2E** | `node e2e/capturar-dashboards-roles.mjs` |
| **Despliegue a Producción** | `git push origin <tu_rama>:main` |

---
*Manual generado para preservación de la continuidad de ingeniería del INCES LMS. Sistema en producción activa en [https://inces-lms.pages.dev](https://inces-lms.pages.dev).*
