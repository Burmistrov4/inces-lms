-- FIX de 202610300001 · Las tres vistas vuelven a ejecutarse como quien consulta.
--
-- Qué pasó. `202610300001_ampliar_nombre_grupo.sql` tenía que cambiar el tipo de
-- `sections.name`, y Postgres no lo permite mientras una vista dependa de la
-- columna (`0A000`). Para no transcribir a mano la definición de
-- `v_exportacion_hacer` —60+ columnas, una errata asegurada— se guardaron las
-- definiciones con `pg_get_viewdef()`, se borraron las vistas, se cambió el tipo
-- y se recrearon.
--
-- El error: **`pg_get_viewdef()` devuelve el SELECT, no las opciones de la
-- vista.** `security_invoker = true` es una opción de la vista, no parte de su
-- consulta, así que las tres se recrearon con el valor por defecto
-- (`security_invoker = false`) y pasaron a ejecutarse con los permisos del
-- **dueño** de la vista, no de quien consulta.
--
-- Por qué importa. Con `security_invoker = false`, una vista se salta la RLS de
-- las tablas de abajo: cualquier `authenticated` que la consulte ve lo que vería
-- el dueño. En `v_exportacion_hacer` eso son datos personales de todos los
-- aspirantes del centro. Lo detectó `supabase/verificar-esquema.mjs` con tres
-- comprobaciones en rojo — una prueba que existía justo para esto.
--
-- Lección para la próxima: cuando se recrea una vista, hay que releer sus
-- opciones (`pg_class.reloptions`), no sólo su consulta.

alter view public.v_cuadrante_clases set (security_invoker = true);
alter view public.v_exportacion_hacer set (security_invoker = true);
alter view public.v_ocupacion_secciones set (security_invoker = true);

comment on view public.v_exportacion_hacer is
  'Planilla de inscripción exportable a HACER. `security_invoker = true`: se '
  'ejecuta con los permisos de quien consulta, así que la RLS de `enrollments` y '
  '`aspirantes` sigue aplicando. Se perdió en 202610300001 al recrear la vista y '
  'se restauró en esta migración.';
