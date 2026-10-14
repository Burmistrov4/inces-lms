# 01 — El proyecto y el producto

## 1. Qué es y para quién

**INCES LMS** es un sistema de gestión académica web para el
**Centro de Formación Socialista (CFS) Nacional de Soldadura "Rafael Urdaneta"**,
del INCES, en el sector La Isabelica de Valencia, estado Carabobo, Venezuela.

No es un ejercicio académico genérico: es el **Trabajo Especial de Grado (TEG)**
de:

| Persona | Rol |
|---|---|
| Lorenzo Roca | Estudiante, 4º semestre, Análisis de Sistemas, IUTEPI, periodo SA26-2 |
| José Tarazón, Sleither Vásquez, Adrián Cedeño | Equipo |
| Prof. Maglis Camacho | Tutora |

**Repositorio:** `https://github.com/Burmistrov4/inces-lms` (rama `main`).
**Admin del sistema:** `lorenzo-roca11@hotmail.com` (correo con guion; el guion
es real — no es errata).

## 2. El problema real que resuelve

El centro lleva su gestión académica (inscripciones, cuadrante de clases,
asistencia, entregas de tareas, planillas) en papel y planillas sueltas. El LMS
digitaliza el ciclo del aprendiz y del docente, y **alimenta** al sistema
institucional **HACER** (la plataforma nacional del INCES) mediante exportaciones
en formato definido.

**Frontera del producto (decisión explícita, no olvido):**

- El LMS **alimenta a HACER, no lo sustituye**.
- **No emite certificados.** El módulo M9 (Certificados/QR) fue **descartado del
  alcance** (ADR, 2026-09-12). No reintroducir.
- La **verificación de identidad** es un procedimiento presencial del centro (con
  cédula). El software no lo sustituye ni finge un autoservicio seguro.

## 3. Los roles

| Rol | Cómo se obtiene | Qué puede |
|---|---|---|
| **estudiante** | Rol por defecto del auto-registro (ADR-008: el auto-registro **nunca** otorga otro rol) | Ver su horario, inscribirse, entregar tareas, marcar asistencia, editar su perfil (nombre y apellido) |
| **docente** | Por **invitación** de un administrador (token de un solo uso; el docente fija su contraseña al activar) | Abrir sesiones de asistencia QR, ver sus clases y guardias, publicar anuncios/tareas, calificar y devolver entregas, gestionar sus archivos |
| **admin** | Promoción manual/administrativa (nunca automática). El cambio de rol se hace desde el cPanel | Todo lo anterior + el cPanel: módulos, parámetros, usuarios, catálogo de la planilla, ocupación, exportaciones, auditoría |

Un cuarto actor, **aspirante**, es la ficha de quien se está inscribiendo
(tabla `aspirantes`); al completar el registro ya tiene perfil de estudiante.
La distinción importa: la cédula vive en `aspirantes`, **no** en `profiles`, y de
eso sale una deuda abierta (§ `02`, login con cédula).

## 4. Los módulos del sistema

El sistema es **modular por diseño**: cada módulo es una fila en la tabla
`system_modules` con su interruptor (`habilitado`), su orden, su categoría y su
lista de roles permitidos. El administrador enciende y apaga módulos desde el
cPanel **sin desplegar**, y la API rechaza con `403 MODULO_DESHABILITADO` las
rutas de un módulo apagado.

| Clave | Módulo | Estado (2026-10-09) |
|---|---|---|
| `m0_cpanel` | Administrador Maestro (núcleo) | 🟢 encendido, **protegido** (no se puede apagar) |
| `m1_onboarding` | Autenticación y onboarding | 🟢 encendido |
| `m2_curriculo` | Currículo y pensum (programas, materias, secciones) | 🟢 encendido |
| `m3_cuadrante` | Cuadrante, aulas, lapsos, guardias | 🟢 encendido |
| `m4_inscripciones` | Inscripciones y cupos (+ planilla y exportación HACER) | 🟢 encendido |
| `m5_archivos` | Almacenamiento de archivos en R2 | 🟢 encendido |
| `m6_aula_virtual` | Aula virtual: anuncios, tareas, entregas, calificaciones | 🟢 encendido |
| `m7_asistencia` | Asistencia por QR en vivo | 🟢 encendido |
| `m6_asistencia` | (fila heredada, sin rutas cableadas) | ⚪ apagado |
| `m7_calificaciones` | Calificaciones formales | ⚪ apagado |
| `m8_pasantias` | Pasantías | ⚪ apagado |

**M8 (pasantías) y M9 (certificados) están fuera del alcance actual.** M8 tiene
diseño en el plan maestro pero no está construido.

## 5. Decisiones de producto que definen el carácter del sistema

Están **tomadas y verificadas**; no son preferencias reversibles sin una
decisión nueva de Lorenzo:

1. **Autenticación sin correo externo.** La recuperación de contraseña y la
   activación de docentes son **flujos internos completos**, independientes de
   Resend, SMTP, correo y SMS. El aspirante se registra y entra directo
   (`mailer_autoconfirm = true` en Supabase). Resend queda relegado a
   notificaciones externas opcionales —y su integración está bloqueada
   (HTTP 401, falta dominio propio verificado).
   - Recuperación: código de **12 caracteres** (alfabeto sin `0/O/1/I/L`,
     ~59 bits), se muestra **una vez**, en la base sólo su **SHA-256**, 30 min
     de vida, un solo uso, emitir otro anula el anterior; canjearlo fija la
     contraseña y **cierra todas las sesiones** abiertas.
   - Invitación docente: token de un solo uso cuyo consumo es **atómico**
   (se reclama antes de crear la cuenta, para que dos activaciones simultáneas
   no creen dos cuentas), con **revocar** y **renovar**.
2. **La asistencia (M7) funciona por dos vías**: el QR que caduca cada 15
   segundos (proyectado por el docente) y la escritura manual de los seis
   dígitos. El servidor resuelve la sesión a partir del código; el alumno nunca
   lee `attendance_sessions`. El panel deja preparado el hueco del lector de
   cámara (`mobile_scanner` ya está en dependencias; la validación en dispositivo
   físico es el único pendiente de M7).
3. **El motor de "bids" de inscripciones existe pero nace apagado**
   (`habilitar_sistema_bids = false`): con bids apagados, una solicitud con cupo
   libre entra directo a `ENROLLED`; sin cupo, a la cola (`WAITLISTED`).
   **Encenderlo es decisión de Lorenzo**, no del que llegue.
4. **El estado de una matrícula nunca se borra**: `renunciar_cupo` deja
   `DROPPED` como historial. Archivar (no borrar) es el patrón del sistema
   (`is_active = false` en aulas, secciones, programas).
5. **Los archivos pesados van a Cloudflare R2**, no a la base. Supabase guarda
   sólo la metadata (`r2_key`). Tope por defecto: 10 MB por archivo, 10 archivos
   por entidad, configurables desde el cPanel sin desplegar.

## 6. A quién le habla el sistema

- **Portada pública** (`/` sin sesión): presenta el centro y la oferta de cursos
  libres.
- **Login / registro** (`/login`, `/inscripcion`): el aspirante se inscribe con
  su ficha completa; el formulario se **renderiza desde un catálogo en base**
  (`inscripcion_campos`), de modo que añadir o marcar campos obligatorios es
  configuración, no código.
- **Dashboards por rol** con menú lateral adaptativo (cajón por debajo de
  900 px).
- **cPanel** (admin): secciones por categoría, cada una con su panel.

## 7. Contexto que condiciona el diseño (Venezuela)

- **Cortes eléctricos.** La arquitectura es **dual Cloud/Local por diseño**
  (ADR-009): el mismo artefacto corre en la nube (free tiers) y en un servidor
  local vía variables de entorno y `docker-compose`. Las tareas programadas
  viven en GitHub Actions, **no** en la máquina de nadie, porque la máquina no
  siempre está encendida.
- **Presupuesto cero.** Todo el stack elegido vive en capas gratuitas
  suficientes para el volumen de un CFS: Supabase free (500 MB), R2 (10 GB),
  Render free, Cloudflare Pages, GitHub Actions.
- **Conectividad irregular en el aula.** De ahí que el lector de QR use la
  variante **empaquetada** de MLKit (modelo dentro de la app, funciona sin red)
  y que el canal en vivo de asistencia sea un WebSocket unidireccional que
  evita el polling.
