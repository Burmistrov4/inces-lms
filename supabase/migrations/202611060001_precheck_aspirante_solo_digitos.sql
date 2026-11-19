-- 202611060001_precheck_aspirante_solo_digitos.sql
-- ============================================================================
-- Comparar cédulas por dígitos en el prechequeo de aspirantes para evitar
-- duplicados con distintos formatos (ej. V-12345678 vs 12345678 vs 12.345.678).
-- ============================================================================

create or replace function public.precheck_aspirante(
  p_cedula text,
  p_email  text
)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_cedula text := nullif(trim(coalesce(p_cedula, '')), '');
  v_email  text := nullif(lower(trim(coalesce(p_email, ''))), '');
begin
  if v_cedula is null then
    return 'CEDULA_REQUERIDA';
  end if;

  if v_email is null or position('@' in v_email) < 2 then
    return 'EMAIL_INVALIDO';
  end if;

  -- Compara por dígitos limpios para evitar que formatos con prefijo o puntos burlen el chequeo
  if exists (
    select 1
      from public.aspirantes a
     where public.solo_digitos(a.cedula) = public.solo_digitos(v_cedula)
  ) then
    return 'CEDULA_DUPLICADA';
  end if;

  if exists (select 1 from public.profiles p where lower(p.email) = v_email) then
    return 'EMAIL_DUPLICADO';
  end if;

  if exists (select 1 from public.aspirantes a where lower(a.email) = v_email) then
    return 'EMAIL_DUPLICADO';
  end if;

  return 'OK';
end;
$$;

comment on function public.precheck_aspirante(text, text) is
  'Devuelve OK | CEDULA_DUPLICADA | EMAIL_DUPLICADO | EMAIL_INVALIDO | CEDULA_REQUERIDA (evalúa cédula por solo_digitos)';

revoke all on function public.precheck_aspirante(text, text) from public;
grant execute on function public.precheck_aspirante(text, text) to anon, authenticated;
