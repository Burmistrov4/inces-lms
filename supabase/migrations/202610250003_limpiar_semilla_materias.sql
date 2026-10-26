-- =============================================================================
--  Fuera [SEMILLA] de las materias
--
--  `202610250002` limpió la etiqueta de `programs`, pero se olvidó de `subjects`.
--  Medido el 2026-10-25 contra la base: **las 3 materias** la llevaban.
--
--      SEM-SOL-ARCO  Soldadura por Arco [SEMILLA]
--      SEM-SOL-MET   Metalurgia y Materiales [SEMILLA]
--      SEM-SOL-SEG   Seguridad e Higiene en el Taller [SEMILLA]
--
--  Lorenzo lo señaló en el tercer video mientras miraba el banco de materias:
--  «no puedo cambiar nombres, son materias feas […] evitar este nombre de
--  semilla». La etiqueta es jerga de desarrollo —marca las filas que sembró el
--  script de datos de prueba— y no debe llegar a nada que vea un usuario.
--
--  Va en una migración nueva y no editando la 002 porque esa ya está aplicada, y
--  una migración aplicada no se toca: es el historial de lo que pasó en la base.
--
--  Idempotente: si ya está limpio, no hace nada.
-- =============================================================================

update public.subjects
   set name = btrim(regexp_replace(name, '\s*\[SEMILLA\]', '', 'gi')),
       updated_at = now()
 where name ~* '\[SEMILLA\]';

comment on column public.subjects.name is
  'Nombre visible de la materia. La etiqueta [SEMILLA] era jerga de desarrollo '
  'y se retiró de todas las filas el 2026-10-25, igual que en `programs`.';
