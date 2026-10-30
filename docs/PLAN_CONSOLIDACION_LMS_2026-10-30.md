# Plan de consolidación — INCES LMS como LMS completo (tipo Classroom + Drive)

> **Para qué sirve este documento.** Es el plan de trabajo autónomo: qué falta
> para que esto sea un LMS de verdad, en qué orden, cómo se verifica cada paso y
> qué evidencia deja. Sustituye a `PLAN_REDISENO_LMS_2026-10-30.md` como
> referencia de fases (aquel sigue siendo válido en el análisis de conceptos).
>
> **Regla de oro:** lo que dice aquí se mide antes de afirmarlo. Estado medido el
> **2026-10-30**, no heredado de ningún resumen.

---

## 0. Punto de partida medido

### Lo que existe (y funciona)

| Pieza | Estado medido |
|---|---|
| `m6_tareas` | `titulo, descripcion, tipo, puntos_maximos, fecha_limite, permitir_entrega_tardia, estado, programado_para, tema, orden, publicado_en` — **existe** |
| `m6_entregas` | `estado, es_tardia, nota_borrador, nota_asignada, entregada_en, devuelta_en` — **existe, con nota** |
| `m6_anuncios` | Anuncios del aula — **existe** |
| `attendance_sessions` / `attendance_marks` | Asistencia con ventana y código — **existe** |
| `enrollments` | Matrícula alumno↔grupo con `status` — **existe** |
| `files_metadata` | R2: `r2_key, nombre_original, tipo_contenido, tamano_bytes, entity_type, entidad_id, estado, confirmado_en` — **existe** |
| `program_subjects` | Pensum (materia ↔ programa, con horas) — **existe** |
| Aula virtual | Es un **grupo** (`sections`: programa + materia + período). 22 pantallas, 7 módulos activos |

### Lo que no existe

| Falta | Consecuencia hoy |
|---|---|
| `certificados` | No se puede emitir un certificado ni que el alumno lo descargue |
| Expediente del alumno | Nadie puede ver «qué cursó, con qué nota, en qué período» en una vista |
| `programs.imagen` / carrusel | Los cursos no tienen foto; el dashboard no los publica |
| Carpetas del aula | El material se sube sin estructura: no hay «Unidad 1 / Materiales» |
| Adjuntos a tareas y anuncios | Una tarea no puede llevar el PDF del enunciado |
| Calificar desde el aula | `nota_asignada` existe en la tabla, pero el docente no tiene la pantalla |
| Portal público de cursos | Un aspirante no puede ver la oferta sin iniciar sesión |
| `m7_calificaciones` / `m8_pasantias` | Encendidos en la nube **sin código**: es la deriva que el verificador marca en rojo |

### Verificado esta sesión

- API real: `PATCH /admin/periodos/{id}` con `{cerrado:true}` → **200**.
- API real: `POST /admin/secciones` repetido → **409 `REGISTRO_DUPLICADO`**.
- `flutter test` **1054/1054** · `npm run verify` **728/728** · analizador **251 archivos 0/0/0**.

---

## 1. Qué significa «tipo Classroom» aquí

Classroom tiene seis cosas y **todas** son una sola entidad con seis pestañas.
Esta es la traducción honesta a este sistema:

| Classroom | Aquí | Estado |
|---|---|---|
| Clase | **Aula virtual** = grupo (programa + materia + período) | Existe, sin CRUD cómodo |
| Tablón (novedades) | `m6_anuncios` | Tabla sí, pantalla de alumno a medias |
| Trabajo en clase | `m6_tareas` + `m6_entregas` | Tablas sí, falta calificar y adjuntar |
| Personas | `enrollments` + docente del aula | Existe; falta poder añadir uno a uno |
| Calificaciones | `m6_entregas.nota_asignada` | Dato sí, **libro y pantalla no** |
| Archivos (Drive) | `files_metadata` + R2 | Subida sí, **carpetas y adjuntos no** |
| Código de clase | No existe | **Falta**: la forma más simple de meter alumnos |

**Decisión de producto ya tomada por el dueño:** no se reintroducen «secciones».
El aula virtual sigue siendo la unidad. Todo lo de arriba cuelga del aula.

---

## 2. Fases

Cada fase lleva: **qué**, **dónde**, **criterio de aceptación** y **cómo se
verifica**. Una fase no se cierra sin evidencia pegada en la entrega.

### F0 — Cerrar la deuda que ya está identificada (1–2 días)

| # | Qué | Criterio |
|---|---|---|
| F0.1 | Migración: `sections.name` de `varchar(5)` a `varchar(24)` + contrato (`esquemas.ts`) + `maxLength` de la UI | Se crea un grupo con nombre «SOLD-B» sin error |
| F0.2 | `m7_calificaciones` y `m8_pasantias` apagados o implementados | Verificador sin rojo (o rojo explicado y firmado por el dueño) |
| F0.3 | Cerrar período: verificar en la UI que el error ya es legible | Un cierre desde la pantalla termina en verde |
| F0.4 | Borrar el período duplicado (`SA26-2`, cerrado) | Una sola tarjeta en «En curso» |
| F0.5 | Rotar la contraseña del admin expuesta en el historial de git | Contraseña nueva usada por la suite E2E |

### F1 — Materias editables y pensum con horas (2–3 días)

Ahora las materias solo se crean. Lo que el dueño pide: **horas, nombre y código**.

- `PATCH /admin/materias/:id` con validación de unicidad del código.
- **Regla de negocio**: el código se puede corregir **solo si la materia no tiene
  notas ni planillas emitidas**; si las tiene, la UI ofrece «duplicar». Un código
  que cambia después de exportar a HACER deja dos documentos que no cuadran.
- Pantalla: edición desde el pensum del curso, con las horas a la vista.
- **Criterio:** se edita la hora de «Metalurgia y Materiales», se guarda, y el
  pensum y el cuadrante la muestran sin recargar la página.

### F2 — Aula virtual con CRUD completo (3–4 días)

- `POST/PATCH/DELETE /admin/aulas-virtuales`: crear, archivar, asignar docente.
- Lista con **estado** (activa/archivada), **dueño** y **número de alumnos**.
- Añadir un aprendiz **individualmente** al aula (hoy solo por inscripción).
- **Código de aula** (tipo Classroom): corto, legible, para que el alumno entre
  sin buscarse en una lista. Es la mejora de usabilidad más grande por línea de
  código.
- **Criterio:** el admin crea un aula, le asigna docente y dos alumnos, y el
  docente la ve al entrar sin tocar la base.

### F3 — Trabajo en clase completo (4–6 días)

- Adjuntos en tareas y anuncios (`files_metadata.entity_type = 'tarea'`).
- **Calificar**: pantalla del docente con la lista de entregas, nota 01–20 con un
  decimal, comentario y devolución. `devolver` cambia `estado` y `devuelta_en`.
- **Libro de calificaciones** por aula: columnas = tareas, filas = alumnos,
  definitiva calculada y **visible el cálculo** (nada de promedios misteriosos).
- Entregas tardías marcadas (`es_tardia` ya existe).
- **Criterio:** un alumno entrega, el docente califica 15.5, el alumno ve 15.5 y
  el libro lo suma; todo sin salir del aula.

### F4 — Archivos tipo Drive (4–6 días)

- **Carpetas del aula**: estructura de dos niveles (Unidad → Material), que es lo
  único que hace navegable un curso de 40 archivos.
- Mover, renombrar y borrar con `deleted_at` (borrado lógico ya previsto).
- **Google Drive**: enlaces con metadatos (título, tipo, tamaño, quién lo vinculó)
  y **aviso claro** de que el archivo vive en la cuenta de quien lo vinculó. No se
  promete OAuth: sin cliente registrado no se puede, y prometerlo deja al centro
  sin material si esa cuenta desaparece.
- `m5_max_bytes` y `m5_max_archivos_por_entidad` **conectados a la UI**: que el
  mensaje diga el número real de la configuración, no un «10 MB» escrito a mano.
- **Criterio:** se crea una carpeta, se suben dos archivos, se mueve uno a otra
  carpeta y el alumno del aula los ve.

### F5 — Expediente, notas finales y certificado (5–7 días)

Es lo que el dueño llama «saber si pasó».

- **Expediente del alumno** (una pantalla): matrículas por período, notas por
  materia, asistencia y entregas. Legible también por el administrador.
- **Nota final por materia** calculada con regla explícita y **editable con
  motivo** (auditoría ya existe en `config_audit_log`).
- **Aprobación**: ≥10 sobre 20. Un 9.5 **no** aprueba salvo que el centro active
  el redondeo; si se activa, la UI dice que fue redondeado.
- **Certificado PDF**: generado desde el expediente, guardado en R2, entregado al
  buzón del alumno y descargable. Con folio y hash para poder verificarlo.
- **Criterio:** el admin emite el certificado de un alumno y ese alumno lo
  descarga desde su cuenta; el PDF lleva su nombre, el curso, la nota y el folio.

### F6 — Vitrina pública y modernización (3–4 días)

- **Foto del curso** (`programs.imagen`) y marca **«mostrar en el carrusel»**.
- El curso creado aparece **de inmediato** en el dashboard público si está
  publicado; si no, se dice por qué (borrador / sin pensum / sin fechas).
- Carrusel de la portada alimentado por esos cursos.
- Modernización: una sola barra, estados con color en todas las listas, y ninguna
  pantalla con dos scrolls.
- **Criterio:** se sube una foto a «Soldadura Básica», se marca el carrusel y
  aparece en la portada sin reiniciar sesión.

### F7 — PNA con especialidades y pasantías (3–5 días, condicionada)

- El PNA hoy es **un programa con materias**. Dos especialidades («Soldadura» y
  «Analista Contable») son **dos programas PNA**, cada uno con su pensum. Falta
  que la pantalla lo muestre agrupado y no como una lista plana.
- **Pasantías**: el PNA dura un año; la bandera «requiere pasantía» ya existe en
  el programa. El módulo 8 (`m8_pasantias`) se implementa **o** se apaga. Hoy está
  encendido sin código, que es lo peor de los dos mundos.
- **Criterio:** dos PNA con pensums distintos se ven separados y cada uno declara
  si exige pasantía.

---

## 3. Cómo trabajo de forma autónoma

Para que el trabajo avance solo, con evidencia y sin volver a preguntar lo ya
decidido:

### 3.1 Capturas de pantalla en cada paso

- **Mecanismo:** la suite E2E ya captura (`e2e/tests/captura_dashboards_roles.spec.ts`).
  Se extiende a un spec por fase que recorre la pantalla tocada en **360, 820 y
  1440 px** y deja los PNG en `docs/capturas/<fase>/`.
- **Regla:** cada entrega trae las capturas de **antes y después** del cambio, con
  el archivo en `docs/capturas/`. Se entregan con `MEDIA:` para poder verlas en el
  chat sin abrir el repo.
- **Por qué:** el dueño prueba en un Redmi 10C y decide mirando. Una captura a
  360 px vale más que un párrafo.

### 3.2 Verificación obligatoria antes de decir «hecho»

```bash
node devops/analizar-dart.mjs                                   # 0/0/0
cd backend && npm run verify                                    # 728/728 o más
env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
  NO_PROXY=127.0.0.1,localhost flutter test                     # suite completa
node supabase/verificar-esquema.mjs                             # 0 fallas reales
```

Y para lo que toca la base: **medir contra la API real** con el script de sonda,
nunca deducir del código.

### 3.3 Ritmo por ciclo

1. Elegir la unidad más pequeña que cierre un criterio de aceptación.
2. Escribir la prueba **que puede fallar** (si no puede fallar, no vale).
3. Implementar.
4. Medir (comandos de arriba) y capturar.
5. Actualizar `ESTADO_DEL_SISTEMA.md` y `docs/BACKLOG_PENDIENTES.md` el mismo día.
6. Commit + push a `main` con el porqué.
7. Desplegar a Cloudflare Pages **con** `--dart-define=API_BASE_URL=…` y verificar
   por huella SHA-256 del bundle antes de decir «está en producción».

### 3.4 Límites que no cruzo solo

Sin preguntar, sólo hasta aquí:

- No aplico migraciones destructivas (borrar columnas o datos) sin autorización.
- No toco RLS de tablas existentes sin medir el efecto en las 3 apps.
- No emito certificados reales durante pruebas (se emiten de prueba y se borran).
- No habilito un módulo sin flujo completo + E2E.

---

## 4. Decisiones que necesitan al dueño

| # | Decisión | Por qué no la tomo yo |
|---|---|---|
| D1 | ¿El **código de materia** se puede editar con notas ya emitidas? | Afecta a documentos oficiales exportados a HACER |
| D2 | ¿Se activa el **redondeo 9.5 → 10**? | Es política del centro, no técnica |
| D3 | ¿El certificado lo firma alguien y lleva sello? | Requiere un arte y un responsable |
| D4 | ¿**Cupo por aula o global**? | Cambia el modelo de datos (migración) |
| D5 | ¿**Campus** o **Aula Virtual**? | Nomenclatura institucional |
| D6 | ¿Se puede **vincular Google Drive** de verdad (OAuth) o solo enlaces? | OAuth necesita cliente registrado y un responsable de la cuenta |
| D7 | `m8_pasantias`: ¿se implementa o se apaga? | Decide si hay módulo nuevo o se retira |

**Mientras no haya respuesta, avanzo en todo lo que no dependa de ellas** (F0,
F1, F2, F3, F4, F6 son independientes).

---

## 5. Orden de ataque (lo próximo, concreto)

1. **F0.1** migración del nombre de grupo → desbloquea lo que el dueño ya reportó dos veces.
2. **F2 código de aula** → la mejora de usabilidad más grande por línea escrita.
3. **F3 calificar** → hoy el dato existe y nadie puede escribirlo.
4. **F5 expediente** → es la pregunta «¿cómo sé si pasó?».
5. **F4 carpetas** → sin carpetas, el material es un vertedero.
6. **F6 vitrina** → lo que ve un aspirante antes de inscribirse.

---

## 6. Riesgos

- **Dos períodos con nombres parecidos** confunden cualquier planificación. Se
  resuelve en F0.4 o el resto del trabajo se mide contra datos sucios.
- **`files_metadata` sin carpetas** ya está en producción: la migración de carpetas
  debe ser **aditiva** (nullable), no reorganizar lo existente.
- **Certificados**: un PDF mal emitido es un problema legal. Se genera con folio,
  hash y plantilla fija; nunca a mano.
- **La suite E2E** tiene 6 specs en rojo de antes: no se declaran verdes por
  omisión; se arreglan o se documentan.