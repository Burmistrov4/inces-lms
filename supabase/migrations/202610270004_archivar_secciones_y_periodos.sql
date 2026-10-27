-- INCES LMS — D8: Archivar funciona (secciones y períodos)
--
-- 1. `sections.archived_at` registra cuándo se archivó la sección.
-- 2. Trigger en `academic_periods`: al archivar/desactivar un período,
--    cierra automáticamente sus secciones activas (no en cascada a aulas).
-- 3. Trigger en `sections`: al cambiar `is_active` a false, registra `archived_at`;
--    al reactivar, limpia `archived_at`.

alter table public.sections
  add column if not exists archived_at timestamptz;

comment on column public.sections.archived_at is
  'Fecha y hora en que la sección fue archivada/desactivada (D8). Null si está activa.';

create or replace function public.tr_sections_archived_at()
returns trigger
language plpgsql
as $$
begin
  if (new.is_active = false and (old.is_active = true or old.is_active is null)) then
    new.archived_at = coalesce(new.archived_at, now());
  elsif (new.is_active = true and old.is_active = false) then
    new.archived_at = null;
  end if;
  return new;
end;
$$;

drop trigger if exists tr_sections_archived_at on public.sections;
create trigger tr_sections_archived_at
before update of is_active on public.sections
for each row
execute function public.tr_sections_archived_at();

create or replace function public.tr_archivar_secciones_de_periodo()
returns trigger
language plpgsql
security definer
as $$
begin
  if (old.is_active = true and new.is_active = false) then
    update public.sections
    set is_active = false,
        archived_at = now()
    where period_code = new.code
      and is_active = true;
  end if;
  return new;
end;
$$;

drop trigger if exists tr_archivar_secciones_de_periodo on public.academic_periods;
create trigger tr_archivar_secciones_de_periodo
after update of is_active on public.academic_periods
for each row
when (old.is_active is distinct from new.is_active)
execute function public.tr_archivar_secciones_de_periodo();

-- D10: Unicidad de cédula en perfiles (admin y docentes)
create unique index if not exists idx_profiles_cedula_digits
  on public.profiles (public.solo_digitos(cedula))
  where cedula is not null and btrim(cedula) <> '';
