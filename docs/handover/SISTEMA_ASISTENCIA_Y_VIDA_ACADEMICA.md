# Arquitectura de Asistencia Antifraude y Ciclo de Vida Académico — INCES LMS

**Fecha de emisión:** 2026-10-16  
**Ámbito:** Módulo 3 (Cuadrante y Horarios), Módulo 4 (Inscripciones y Cupos), Módulo 7 (Asistencia en Aula)  
**Público objetivo:** Administradores, Docentes, Estudiantes y Desarrolladores

---

## 1. Prevención de Fraude en Asistencia Presencial

### 1.1 El Problema Planteado
En un sistema donde se proyecta un código rotativo de 6 dígitos en la pizarra con una ventana de validez de 15 segundos (algoritmo TOTP):
* **Escenario de vulnerabilidad:** Un estudiante ausente pide a un compañero en el aula que le envíe por mensajería instantánea (WhatsApp/Telegram) el código numérico de 6 dígitos proyectado. Con una conexión rápida, el estudiante en casa puede teclearlo en su teléfono dentro de los 15 segundos y quedar registrado como "presente".

### 1.2 Arquitectura de Defensa en Profundidad Implementada y Planificada

Para mitigar y erradicar este riesgo, INCES LMS establece una arquitectura en capas:

```
[ Capa 1: Ventana Criptográfica TOTP (15s) ]
                    ↓
[ Capa 2: Modo Óptico Estricto (Sólo Escaneo de Cámara) ]
                    ↓
[ Capa 3: Validación Nominal y Cierre por Docente en Aula ]
                    ↓
[ Capa 4: Geovalla GPS y Subred CFS (En desarrollo) ]
```

1. **Capa 1 — Ventana Temporal Efímera:**
   - Cada código expira en 15 segundos. Si el mensaje se retrasa unos segundos, el servidor rechaza la marca con `CODIGO_CADUCADO`.
2. **Capa 2 — Modo Óptico Exclusivo (Cámara en Vivo):**
   - El docente puede exigir escaneo óptico mediante `EscanerQrScreen`. El QR proyectado contiene el par criptográfico `<sesion_uuid>:<codigo_rotativo>`. Al restringir la entrada manual en sesiones presenciales, el dispositivo del estudiante debe apuntar físicamente la lente de su cámara al proyector de la pizarra, impidiendo el reenvío por texto.
3. **Capa 3 — Conciliación Visual por Docente (Juez Final en Aula):**
   - El docente dispone en su panel (`asistencia_qr_panel.dart`) del listado nominal en tiempo real vía WebSocket (`/api/v1/asistencia/rt`).
   - El docente visualiza el conteo exacto: *«18 asistencias registradas / 17 estudiantes presentes en el aula física»*.
   - El docente tiene la potestad institucional de anular o invalidar con 1 toque cualquier marca no justificada antes de ejecutar el botón **«Cerrar Sesión»**.
4. **Capa 4 — Geocerca Institucional (Geofencing GPS y Subred CFS):**
   - Validación del radio geográfico de 150 metros en torno a las coordenadas del CFS La Isabelica / Rafael Urdaneta y detección de la subred Wi-Fi del centro.

---

## 2. Asignación de Aulas, Talleres y Horarios

### ¿Cómo se asigna un aula o taller a profesores y aprendices?

1. **Catálogo de Espacios Físicos:**
   - La institución registra la infraestructura del centro en la tabla `classrooms` (ej: *Taller de Soldadura 1*, *Aula Teórica 3*, *Laboratorio de Computación*). Cada aula tiene una capacidad máxima de puestos de trabajo.
2. **Creación de Secciones y Horarios (Módulo 3):**
   - La administración crea una **Sección** vinculada a una Materia, un Docente responsable y un Lapso Académico (ej: `SA26-2`).
   - En el **Cuadrante Semanal**, el administrador asigna bloques horarios (mañana: 07:30 a 11:45; tarde: 13:00 a 17:15) y asocia un aula física específica a cada bloque.
   - El motor de base de datos (`conflictos_horario`) impide que dos docentes o dos secciones distintas ocupen el mismo taller en la misma franja horaria.
3. **Visibilidad para el Aprendiz y el Docente:**
   - **Para el Aprendiz:** Al inscribirse en una sección, su cuadrante personal (`/api/v1/mi-horario`) y sus aulas virtuales reflejan automáticamente el taller asignado, el horario exacto y el docente titular.
   - **Para el Docente:** El docente ingresa a su panel y visualiza su carga horaria semanal, las aulas donde debe impartir clase presencial y el enlace a la toma de asistencia.

---

## 3. Discrepancia de Ofertas: Oratoria vs. Soldadura y Prevención de Colisiones

### 3.1 ¿Por qué un aspirante de Oratoria ve cupos de Soldadura?
- Al registrarse por primera vez, el aspirante manifiesta su vocación e interés en una especialidad (ej. *Oratoria y Comunicación Efectiva*).
- El catálogo de **Ofertas de cupos** (`/api/v1/ofertas`) muestra las secciones académicas activas del CFS en el período en curso. Si en ese lapso el centro abrió cohortes de *Soldadura por Arco* pero aún no ha publicado secciones de *Oratoria*, el aspirante visualiza las ofertas abiertas del centro.

### 3.2 Salvaguardas Implementadas en la v1.2.8:
1. **Banner Informativo de Lista de Espera:**
   - Si no hay secciones del oficio elegido por el alumno, el sistema le aclara en un panel destacado:
     > *"Tu formación seleccionada: Oratoria. En el lapso actual no hay secciones abiertas para esta especialidad; te encuentras en lista de espera prioritaria para futuras cohortes. A continuación puedes ver otras ofertas formativas del centro."*
2. **Confirmación Modal para Cursos Cruzados:**
   - Si el estudiante pulsa `Inscribirme` en una sección de otro oficio, el sistema solicita confirmación explícita con un diálogo de advertencia antes de enviar la solicitud.
3. **Control de Solapamiento Horario:**
   - El motor relacional (`enrollments_seccion_unica_por_materia`) impide dobles inscripciones en la misma materia y valida choques de horario en el cuadrante.

---

## 4. Ciclo de Vida: Reinscripción Post-Egreso o Culminación de Curso

### ¿Qué ocurre cuando un aprendiz culmina un curso y desea inscribirse en otro?
1. **Identidad Única Institucional:**
   - El estudiante **NO** necesita volver a registrarse ni crear otra cuenta. Su cédula de identidad y perfil permanente (`profiles` y `aspirantes`) quedan registrados en el sistema de por vida.
2. **Historial y Cierre de Calificaciones:**
   - Al terminar el curso, el docente asienta las calificaciones definitivas en las actas de evaluación. El estado de la inscripción pasa a `COMPLETED` (Aprobado) o `CERTIFIED` (Certificado emitido).
3. **Apertura de Nuevas Postulaciones:**
   - Con su cuenta activa, el estudiante simplemente ingresa en el siguiente lapso académico, navega a **«Ofertas de cupos»** y solicita cupo en cualquier nuevo curso o módulo formativo complementario.
   - Su expediente (`Mi Expediente y Planilla`) conserva el historial cronológico de todas las formaciones cursadas.

---

## 5. Modo de Personalización y Accesibilidad (Roadmap de Temas)

A partir de la v1.2.8, el sistema sienta las bases para estilos visuales expandidos más allá del modo Claro/Oscuro tradicional:
- **Modo Institucional INCES:** Paleta heráldica oficial (Azul Real `#003366`, Azul Primario `#0B5CAB`, Blanco y Gris Platino).
- **Modo Alto Contraste (WCAG AAA):** Ratio de contraste superior a 7:1 en todos los textos y bordes reforzados para personas con baja visión.
- **Modo Lectura Cálida (Sepia):** Diseñado para reducir fatiga visual en sesiones prolongadas de estudio o lectura de guías técnicas.
