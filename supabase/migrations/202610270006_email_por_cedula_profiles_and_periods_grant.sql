-- ============================================================================
-- 202610270006_email_por_cedula_profiles_and_periods_grant.sql
-- ============================================================================
-- 1. Resolver login con cédula para TODOS los usuarios (admin, docente, estudiante)
--    revisando tanto `profiles` como `aspirantes` con `public.solo_digitos`.
-- 2. Conceder actualización de `is_active` en `academic_periods` a `authenticated`
--    para permitir cerrar/reabrir períodos sin error de privilegios.
-- ============================================================================

create or replace function public.email_por_cedula(p_cedula text)
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    (select p.email
       from public.profiles p
      where public.solo_digitos(p.cedula) = public.solo_digitos(p_cedula)
        and p.email is not null
      limit 1),
    (select a.email
       from public.aspirantes a
      where public.solo_digitos(a.cedula) = public.solo_digitos(p_cedula)
        and a.email is not null
      limit 1)
  )
$$;

comment on function public.email_por_cedula(text) is
  'El correo de la cuenta o ficha cuya cédula coincida por dígitos (en profiles o aspirantes), o NULL. Concede EXECUTE a anon y authenticated para el login.';

revoke all on function public.email_por_cedula(text) from public;
grant execute on function public.email_por_cedula(text) to anon, authenticated;

-- Permisos de actualización para cierre y reactivación de períodos
grant update (closed_at, closed_by, is_active) on public.academic_periods to authenticated;
