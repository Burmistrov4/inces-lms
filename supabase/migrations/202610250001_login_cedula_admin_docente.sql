-- =============================================================================
--  Login con cédula para administradores y docentes
--
--  Medido el 2026-10-25: `email_por_cedula` buscaba **sólo** en `aspirantes`.
--  Consecuencia: un estudiante podía entrar con su cédula, pero un administrador
--  o un docente no — su cédula vive en `profiles.cedula`, no en `aspirantes`.
--
--  Y la interfaz ya lo prometía: `login_screen.dart:264` dice «Correo o Cédula»
--  para todos. Un docente escribía su cédula, recibía «no encontrado» y no había
--  forma de entrar salvo recordar el correo institucional.
--
--  Esta migración **no edita** `202610020001_rpc_email_por_cedula.sql` (aplicada):
--  la reemplaza con `create or replace`, que es la forma correcta de cambiar una
--  función sin tocar el historial.
--
--  Se conserva el contrato anterior a propósito:
--    · Devuelve UN texto (el correo) o NULL. No expone el padrón.
--    · `security definer` con `search_path` fijado.
--    · EXECUTE a `anon`: el login ocurre sin sesión.
--    · Acepta el oráculo de existencia que eso implica —aprobado explícitamente
--      por Lorenzo el 2026-10-02— y que esta migración no amplía: sigue
--      devolviendo sólo el correo de la ficha que coincide, ni más ni menos.
-- =============================================================================

create or replace function public.email_por_cedula(p_cedula text)
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  -- `coalesce` y no `union all`: con dos `select ... limit 1` unidos, el parser
  -- se pierde en el `limit` que precede al `union` (medido: «syntax error at or
  -- near "union»). Además el orden de prioridad queda escrito sin ambigüedad:
  -- primero la ficha del aspirante, que es la más específica, y sólo si no
  -- aparece se mira `profiles`.
  select coalesce(
    (select a.email
       from public.aspirantes a
      where public.solo_digitos(a.cedula) = public.solo_digitos(p_cedula)
      limit 1),
    (select p.email
       from public.profiles p
      where public.solo_digitos(p.cedula) = public.solo_digitos(p_cedula)
        -- Sin este filtro, un perfil sin correo (NULL) podría colarse como
        -- coincidencia vacía y el login fallaría con un mensaje confuso.
        and p.email is not null
      limit 1)
  )
$$;

comment on function public.email_por_cedula(text) is
  'El correo cuya cédula coincida por dígitos, o NULL. Busca en `aspirantes` '
  '(estudiantes) y en `profiles` (administradores y docentes), en ese orden. '
  'Devuelve UN text: no expone el padrón. Concede EXECUTE a anon a propósito —el '
  'login ocurre sin sesión— y acepta el oráculo de existencia que eso implica '
  '(aprobado 2026-10-02, ampliado a admin/docente el 2026-10-25).';

-- Los permisos no se heredan al reemplazar una función: hay que reafirmarlos.
revoke all on function public.email_por_cedula(text) from public;
grant execute on function public.email_por_cedula(text) to anon, authenticated;
