-- ============================================================================
-- INCES LMS — Migración 202610270003: Cupo por curso, no global (D5)
--
-- Rediseño 1.5:
-- 1. programs añade columnas `cupo` (integer, default 25, check >= 0) y
--    `mostrar_disponibilidad` (boolean, default true).
-- 2. El parámetro global `cupo_maximo_por_seccion` actúa como valor por defecto,
--    pero `sections.max_capacity` y `programs.cupo` gobiernan la capacidad efectiva
--    sin que el global la pise.
-- 3. public.cupo_efectivo(uuid) resuelve en jerarquía:
--    s.max_capacity -> p.cupo -> system_settings.cupo_maximo_por_seccion -> 25.
-- 4. public.cupos_ocupados_programa(uuid) para consultar inscripciones por programa.
-- ============================================================================

alter table public.programs
  add column if not exists cupo integer not null default 25 check (cupo >= 0),
  add column if not exists mostrar_disponibilidad boolean not null default true;

-- Permisos de actualización para administradores
grant update (cupo, mostrar_disponibilidad) on public.programs to authenticated;

-- Cupo efectivo con prioridad de sección y curso
create or replace function public.cupo_efectivo(p_section_id uuid)
returns integer
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    (select s.max_capacity from public.sections s where s.id = p_section_id),
    (select p.cupo from public.programs p join public.sections s on s.program_id = p.id where s.id = p_section_id),
    (select (ss.valor #>> '{}')::int from public.system_settings ss where ss.clave = 'cupo_maximo_por_seccion'),
    25
  );
$$;

grant execute on function public.cupo_efectivo(uuid) to authenticated;
comment on function public.cupo_efectivo(uuid) is
  'Cupo efectivo de una sección: prioridad sections.max_capacity, luego programs.cupo, luego system_settings.cupo_maximo_por_seccion, fallback 25.';

-- Conteo de inscripciones confirmadas para un programa
create or replace function public.cupos_ocupados_programa(p_program_id uuid)
returns integer
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select count(*)::int
  from public.enrollments e
  join public.sections s on s.id = e.section_id
  where s.program_id = p_program_id
    and e.status = 'ENROLLED';
$$;

grant execute on function public.cupos_ocupados_programa(uuid) to anon, authenticated;
comment on function public.cupos_ocupados_programa(uuid) is
  'Número de cupos ocupados (estudiantes ENROLLED) en las secciones de un programa formativo.';
