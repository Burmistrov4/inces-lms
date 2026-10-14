-- ============================================================================
-- INCES LMS — Bloque E: Duración configurable, caducidad y auditoría de períodos
-- ============================================================================

-- 1. Duración del programa (total) — programs
alter table public.programs
  add column if not exists duration_value integer,
  add column if not exists duration_unit  text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'programs_duracion_coherente'
  ) then
    alter table public.programs
      add constraint programs_duracion_coherente check (
        (duration_value is null and duration_unit is null)
        or (duration_value > 0 and duration_unit in ('DIAS','SEMANAS','MESES'))
      );
  end if;
end $$;

-- 2. Cierre explícito de academic_periods
alter table public.academic_periods
  add column if not exists closed_at timestamptz,
  add column if not exists closed_by uuid;

-- 3. Motivo en config_audit_log
alter table public.config_audit_log
  add column if not exists motivo text;

-- 4. Función de auditoría para academic_periods
create or replace function public.audit_academic_period_change()
returns trigger language plpgsql security definer
set search_path = public, pg_temp as $$
declare
  v_actor uuid := auth.uid();
  v_email text;
begin
  if v_actor is not null then
    select u.email into v_email from auth.users u where u.id = v_actor;
  end if;

  insert into public.config_audit_log
    (tabla, clave, valor_anterior, valor_nuevo, actor_id, usuario_email, motivo)
  values (
    'academic_periods',
    coalesce(new.code, old.code),
    case when tg_op = 'UPDATE' then to_jsonb(old) else null end,
    case when tg_op = 'DELETE' then null else to_jsonb(new) end,
    v_actor, v_email,
    nullif(current_setting('app.audit_motivo', true), '')
  );
  return null;
end; $$;

drop trigger if exists academic_periods_audit on public.academic_periods;
create trigger academic_periods_audit
after insert or update or delete on public.academic_periods
for each row execute function public.audit_academic_period_change();

-- 5. Permisos
grant update (closed_at, closed_by) on public.academic_periods to authenticated;
grant update (duration_value, duration_unit) on public.programs to authenticated;
