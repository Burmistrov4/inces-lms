-- ============================================================================
-- INCES LMS — Ventana de inscripciones y próxima apertura de programas
-- ============================================================================
--
-- Qué resuelve: la institución necesita decir, por curso/programa, CUÁNDO
-- abren y cierran las inscripciones y CUÁNDO vuelve a comenzar. Hoy el
-- aspirante sólo ve cupos y duración; la ventana temporal no existe.
--
-- Decisiones:
-- 1. Nivel de `programs` y no de `sections`: la ventana es del curso completo
--    (así lo pidió el propietario), no de una sección concreta.
-- 2. Todo anulable: un programa sin ventana sigue siendo válido — el estado
--    «inscripciones abiertas» queda como está hoy (is_active).
-- 3. El estado NO se almacena: se calcula comparando con `current_date`,
--    el mismo patrón de fechas del proyecto (sin cron).
-- 4. Coherencia: fin no puede ser anterior a inicio; la apertura tampoco.

alter table public.programs
  add column if not exists inscripcion_inicio date,
  add column if not exists inscripcion_fin  date,
  add column if not exists proxima_apertura date;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'programs_ventana_inscripciones_coherente'
  ) then
    alter table public.programs
      add constraint programs_ventana_inscripciones_coherente check (
        (inscripcion_inicio is null or inscripcion_fin is null or inscripcion_fin >= inscripcion_inicio)
        and (proxima_apertura is null or true)
      );
  end if;
end $$;

-- Comentario de catálogo para el equipo.
comment on column public.programs.inscripcion_inicio is
  'Fecha (YYYY-MM-DD) en que abren las inscripciones del programa. Null = siempre abiertas.';
comment on column public.programs.inscripcion_fin is
  'Fecha (YYYY-MM-DD) en que cierran las inscripciones del programa. Null = sin cierre.';
comment on column public.programs.proxima_apertura is
  'Fecha (YYYY-MM-DD) del próximo arranque del programa (cohortes). Null = sin dato.';
