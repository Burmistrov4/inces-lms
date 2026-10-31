# Guion de demostración — INCES LMS v1.11.0

Escrito para una defensa corta. Cada paso dice **qué hacer**, **qué debería verse**
y **qué hacer si falla**. Si algo no sale, el paso siguiente no depende de ello.

> Antes de entrar: `Ctrl + Shift + R` en el navegador. El pie debe decir
> **v1.11.0**. Si dice otra cosa, la caché no se limpió y estás viendo código
> viejo — eso ya ha pasado dos veces y no es un fallo del sistema.

---

## 0. Lo que se muestra primero (30 segundos)

1. Abre `https://inces-lms.pages.dev`.
2. Señala el pie: **v1.11.0** y el nombre del centro.
3. Di en voz alta: «Flutter Web, API en Vercel, base en Supabase con RLS».

**Qué demuestra:** que hay una aplicación desplegada, con versionado, no una
maqueta.

---

## 1. Administrador (3 minutos)

Entra con la cuenta de Administrador Maestro.

| Paso | Dónde | Qué debe verse |
|---|---|---|
| 1.1 | **Centro de Mando** | Tarjetas de estado y accesos rápidos |
| 1.2 | **Cursos y PNA** | «Curso Introductorio (14-17 años)» con sus materias |
| 1.3 | **Cuadrante de Horarios** | Rejilla con bloques 1–17 (mañana, tarde y **noche**) |
| 1.4 | Toca «+» en una celda | Abre «Asignar clase»: aula virtual, docente, espacio opcional |
| 1.5 | **Horario PNA** | Bloque de Alcides, lunes 07:30, «Metalurgia y Materiales» |
| 1.6 | **Aulas Virtuales** → icono de personas | Listado de aprendices + buscador |

**Qué demuestra:** catálogo, horario con turno nocturno, matrícula por aula.

**Si falla:** el mensaje importa. «Contenido HTML» = la web no está apuntando a
la API (recarga forzada). «Ocurrió un error» genérico = mira el log de Vercel.

---

## 2. Docente (3 minutos)

Cierra sesión y entra como docente.

| Paso | Dónde | Qué debe verse |
|---|---|---|
| 2.1 | **Mi horario** | Sus bloques del período vigente |
| 2.2 | **Aulas Virtuales** → su aula | Pestañas de tablón, trabajo de clase, guías |
| 2.3 | «Nueva tarea» | Diálogo con título, descripción y fecha |
| 2.4 | **Publicar** la tarea | Aviso de que se crearon las entregas |
| 2.5 | **Calificaciones** | Lista de entregas con casilla de nota 01–20 |

**Qué demuestra:** el ciclo de trabajo de clase completo desde el lado del
profesor.

**Ojo:** una tarea **nace en borrador**. Si no se publica, el aprendiz no la ve y
parece que no se guardó.

---

## 3. Aprendiz (2 minutos)

Cierra sesión y entra como aprendiz.

| Paso | Dónde | Qué debe verse |
|---|---|---|
| 3.1 | **Mis aulas** | El aula con el código del docente |
| 3.2 | «Unirme con un código» | Campo de 8 caracteres |
| 3.3 | **Mis tareas** | La tarea publicada en el paso 2.4 |
| 3.4 | **Mi inscripción** | Planilla con notas por materia |

**Qué demuestra:** que lo que publica el docente llega al alumno.

---

## 4. Brújula (1 minuto) — lo nuevo

1. Botón flotante abajo a la derecha.
2. Escribe **«calificar»** → «Ir a Calificaciones».
3. Escribe **«no carga»** → explica la caché y la versión del pie.

**Qué demuestra:** ayuda contextual que no depende de que el usuario conozca el
menú. Y que no inventa: si escribes «xyzzy», lo dice.

---

## 5. Responsive (1 minuto)

1. `F12` → modo dispositivo → **360 × 740**.
2. Recorre Cuadrante, Horario PNA y Aulas Virtuales.
3. La rejilla se convierte en lista por día; el menú pasa a cajón; Brújula queda
   como botón pequeño.

**Qué demuestra:** la misma aplicación en un teléfono real (Redmi 10C).

---

## Lo que NO conviene afirmar en la defensa

Si te preguntan, es mejor decir la verdad que improvisar:

- **El aviso en vivo de asistencia (WebSocket) no funciona en Vercel**: las
  funciones serverless no mantienen el canal abierto. La asistencia por REST sí.
- **Subir archivos** va firmado a Cloudflare R2; no se ha podido probar el CORS
  del bucket desde fuera, así que pruébalo **antes** de la defensa.
- **Notificaciones por correo** dependen de SMTP; si no hay credenciales, el
  registro funciona igual pero no envía.
- **El plan de Vercel es Hobby**: uso no comercial. Un centro público encaja, pero
  no es un plan empresarial.

---

## Plan B si algo cae en directo

1. **Recarga forzada** (`Ctrl + Shift + R`).
2. Comprueba la salud de la API:
   `https://inces-lms-api.vercel.app/salud` → debe decir `{"estado":"ok"}`.
3. Si la API está caída, muestra el repositorio y el historial de pruebas
   (backend 742, Flutter 1073+) y explica la arquitectura con las capturas.
