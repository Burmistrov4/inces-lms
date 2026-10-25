-- =============================================================================
--  Rango de edad del PNA (14 a 18) y limpieza de la etiqueta [SEMILLA]
--
--  Dos arreglos de datos que salieron del mismo sitio: el video de revisión del
--  2026-10-25 y la lectura de la base ese día.
--
--  -------------------------------------------------------------------------
--  1. RANGO DE EDAD DEL PNA: 14 a 18
--  -------------------------------------------------------------------------
--  El dato estaba en cuatro sitios con tres valores distintos:
--
--    a. `landing_page.dart` — `kEdadPnaMax = '17'` → corregido en el código.
--    b. `temas_formacion.dart` — clasificaba el área buscando «15-16» → ahora
--       acepta 14-18, 14-17 y 15-16.
--    c. `campo_planilla.dart` — el selector de fecha de nacimiento cortaba en
--       `hoy - 15`, así que **un aspirante de 14 años no podía ni elegir su
--       fecha** → corregido a `hoy - 14`.
--    d. **El nombre del programa en la base** (`CUR-INT-01`), que es lo que
--       arregla esta migración.
--
--  Corregir sólo uno deja la app contando dos verdades, que es justo el fallo
--  que el comentario de `kEdadPnaTexto` describe.
--
--  -------------------------------------------------------------------------
--  2. LA ETIQUETA [SEMILLA]
--  -------------------------------------------------------------------------
--  `202610070001_remove_semilla_soldadura_basica.sql` retiró la etiqueta de
--  **un solo** programa (`SEM-SOL-CL`), y su propio comentario avisaba de que
--  no tocaba otras filas. Medido el 2026-10-25 contra la base:
--
--      SEM-SOL-01   Soldadura [SEMILLA]      ← seguía con la etiqueta
--      SEM-SOL-CL   Soldadura Básica         ← ya limpia
--
--  Lorenzo lo señaló viéndolo en pantalla: «quítale eso de semilla, es muy
--  raro». Es jerga de desarrollo (fila sembrada de prueba) filtrada a la
--  oferta que ve el aspirante. Aquí se quita de **todas** las filas, no de una
--  por código: si mañana aparece otra, esta migración ya no sirve y habrá que
--  buscarla, pero el patrón queda claro.
--
--  Ambas operaciones son `update` de datos e idempotentes: si ya está hecho, no
--  hacen nada. Se busca por `code` para no depender de cómo esté escrito hoy el
--  nombre —el administrador puede haberlo cambiado desde el panel—.
-- =============================================================================

-- 1. El rango del PNA en el nombre del programa.
update public.programs
   set name = regexp_replace(name, '\([0-9]{1,2}\s*[-–a]\s*[0-9]{1,2}\s*años\)', '(14-18 años)'),
       updated_at = now()
 where code = 'CUR-INT-01'
   and name ~ '\([0-9]{1,2}\s*[-–a]\s*[0-9]{1,2}\s*años\)'
   and name !~ '\(14-18 años\)';

-- 2. Fuera [SEMILLA] de cualquier programa, esté donde esté en el nombre.
update public.programs
   set name = btrim(regexp_replace(name, '\s*\[SEMILLA\]', '', 'gi')),
       updated_at = now()
 where name ~* '\[SEMILLA\]';

comment on column public.programs.name is
  'Nombre visible del programa. El rango de edad del PNA es 14-18 desde el '
  '2026-10-25 (antes 14-17, y el programa semilla decía 15-16). La etiqueta '
  '[SEMILLA] era jerga de desarrollo y se retiró de todas las filas.';
