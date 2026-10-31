-- Turno nocturno: bloques 13 a 17.
--
-- **Por qué.** El centro abrió horario nocturno y el sistema sólo conocía dos
-- turnos: la función `turno_de_bloque` respondía «MAÑANA» para 1–6 y «TARDE»
-- para todo lo demás, y dos restricciones (`schedule_slots`, `teacher_duties`)
-- cerraban el bloque en 12. Un bloque 13 era, literalmente, imposible de
-- guardar.
--
-- **Por qué la franja empieza en 13 y no se reordena.** `schedule_slots.turno`
-- es una columna `generated always as (turno_de_bloque(block)) stored`: los
-- valores ya escritos no se recalculan al cambiar la función. Renumerar turnos
-- dejaría filas con un turno que la función ya no produce. Los bloques 1–12
-- conservan su significado y el nocturno se añade **después**, que es como crece
-- un horario en la vida real.
--
-- Franjas de la noche (45 minutos, como el resto):
--   13 · 06:00 - 06:45 p. m.    16 · 08:15 - 09:00 p. m.
--   14 · 06:45 - 07:30 p. m.    17 · 09:00 - 09:45 p. m.
--   15 · 07:30 - 08:15 p. m.

-- 1. La función que decide el turno. `immutable` se mantiene: es lo que permite
--    que la columna generada la use.
create or replace function public.turno_de_bloque(p_bloque smallint)
returns text
language sql
immutable
as $function$
  select case
    when p_bloque <= 6 then 'MAÑANA'
    when p_bloque <= 12 then 'TARDE'
    else 'NOCHE'
  end;
$function$;

-- 2. El techo de bloques. `not valid` y luego `validate`: así el cambio no
--    bloquea la tabla mientras comprueba, y si alguna fila quedara fuera del
--    rango el `validate` falla en voz alta en vez de dejar una restricción
--    silenciosamente desactivada.
alter table public.schedule_slots
  drop constraint if exists schedule_slots_block_check;

alter table public.schedule_slots
  add constraint schedule_slots_block_check
  check (block between 1 and 17) not valid;

alter table public.schedule_slots
  validate constraint schedule_slots_block_check;

alter table public.teacher_duties
  drop constraint if exists teacher_duties_block_check;

alter table public.teacher_duties
  add constraint teacher_duties_block_check
  check (block between 1 and 17) not valid;

alter table public.teacher_duties
  validate constraint teacher_duties_block_check;

comment on function public.turno_de_bloque(smallint) is
  'Turno de un bloque: 1-6 MAÑANA, 7-12 TARDE, 13-17 NOCHE. La columna '
  'generada `turno` de schedule_slots y teacher_duties depende de esta función.';
