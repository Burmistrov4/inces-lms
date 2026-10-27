-- =============================================================================
-- Migración 202610270002: Tres horarios distintos (D3, D4)
--
--  1. Separación de modalidades:
--     - Ordinario: Formación regular (exige curso; materia y espacio opcionales).
--     - MTP: Guardias de docentes (docente + espacio obligatorios; sin materia).
--     - PNA: Formación de aprendices PNA (materia + docente obligatorios; espacio opcional).
--
--  2. En `schedule_slots`:
--     - `classroom_id` pasa a ser nullable (espacio opcional en Ordinario y PNA).
--     - `teacher_id` pasa a ser nullable (docente opcional en Ordinario).
--
--  3. Función `exigir_agenda_libre()`:
--     - Si `p_docente` es null, no evalúa colisión de docente.
--     - Si `p_aula` es null, no evalúa colisión de espacio.
--
--  4. Vista `v_cuadrante_clases`:
--     - `left join public.classrooms c on c.id = ss.classroom_id`
--     - Proyecta los campos de curso, materia, sección, docente y aula con seguridad invoker.
-- =============================================================================

-- 1. Permitir que classroom_id y teacher_id sean anulables en schedule_slots
alter table public.schedule_slots
  alter column classroom_id drop not null;

alter table public.schedule_slots
  alter column teacher_id drop not null;

-- 2. Actualizar función anti-colisión exigir_agenda_libre para ignorar nulls
create or replace function public.exigir_agenda_libre(
  p_periodo  text,
  p_dia      smallint,
  p_bloque   smallint,
  p_docente  uuid,
  p_aula     uuid,
  p_origen   text,
  p_id       uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_dia text := public.dia_legible(p_dia);
begin
  perform pg_advisory_xact_lock(
    hashtext(p_periodo),
    ((p_dia::int << 16) | p_bloque::int)
  );

  -- --- ¿Está ocupado el docente? (si se especificó docente) ------------------
  if p_docente is not null and exists (
    select 1
    from public.teacher_duties td
    where td.is_active
      and td.period_code = p_periodo
      and td.day_of_week = p_dia
      and td.block       = p_bloque
      and td.teacher_id  = p_docente
      and not (p_origen = 'teacher_duties' and td.id = p_id)

    union all

    select 1
    from public.schedule_slots ss
    join public.sections s on s.id = ss.section_id
    where ss.is_active
      and s.period_code  = p_periodo
      and ss.day_of_week = p_dia
      and ss.block       = p_bloque
      and ss.teacher_id  = p_docente
      and not (p_origen = 'schedule_slots' and ss.id = p_id)
  ) then
    raise exception
      'Ese docente ya tiene una clase o guardia asignada el % en el bloque %. Un docente no puede estar en dos sitios a la vez.',
      v_dia, p_bloque
      using errcode = '23514';
  end if;

  -- --- ¿Está ocupado el espacio? (si se especificó espacio) ------------------
  if p_aula is not null and exists (
    select 1
    from public.teacher_duties td
    where td.is_active
      and td.period_code  = p_periodo
      and td.day_of_week  = p_dia
      and td.block        = p_bloque
      and td.classroom_id = p_aula
      and not (p_origen = 'teacher_duties' and td.id = p_id)

    union all

    select 1
    from public.schedule_slots ss
    join public.sections s on s.id = ss.section_id
    where ss.is_active
      and s.period_code   = p_periodo
      and ss.day_of_week  = p_dia
      and ss.block        = p_bloque
      and ss.classroom_id = p_aula
      and not (p_origen = 'schedule_slots' and ss.id = p_id)
  ) then
    raise exception
      'Ese espacio ya está ocupado el % en el bloque %. Dos grupos no pueden compartir el mismo sitio a la misma hora.',
      v_dia, p_bloque
      using errcode = '23514';
  end if;
end;
$$;

revoke all on function public.exigir_agenda_libre(text, smallint, smallint, uuid, uuid, text, uuid)
  from public, anon, authenticated;

-- 3. Actualizar la vista v_cuadrante_clases con left join a aulas
create or replace view public.v_cuadrante_clases
with (security_invoker = true)
as
select
  ss.id,
  s.period_code,
  s.program_id,
  p.code as program_code,
  p.name as program_name,
  s.subject_id,
  su.code as subject_code,
  su.name as subject_name,
  ss.section_id,
  s.name as section_name,
  ss.teacher_id,
  case
    when ss.teacher_id is not null then public.nombre_para_mostrar(ss.teacher_id)
    else ''
  end as teacher_name,
  ss.classroom_id,
  c.name as classroom_name,
  coalesce(c.is_workshop, false) as is_workshop,
  ss.day_of_week,
  public.dia_legible(ss.day_of_week) as day_name,
  ss.block,
  ss.turno,
  ss.is_active
from public.schedule_slots ss
join public.sections   s  on s.id  = ss.section_id
join public.programs   p  on p.id  = s.program_id
join public.subjects   su on su.id = s.subject_id
left join public.classrooms c  on c.id  = ss.classroom_id;

comment on view public.v_cuadrante_clases is
  'El cuadrante con los nombres resueltos. Admite aulas y docentes no asignados (espacio/docente opcional).';

revoke all on public.v_cuadrante_clases from anon, authenticated;
grant select on public.v_cuadrante_clases to authenticated;
