-- Código de aula automático al crear una sección.
--
-- **Qué estaba roto.** `generar_codigo_aula(8)` existe en la base desde el
-- principio, pero **nadie la invocaba al insertar**: no hay default en la columna
-- ni trigger. Medido el 2026-10-31: las secciones `GRUPO1` y `A`, creadas ese
-- mismo día, quedaron con `join_code = NULL`, mientras las anteriores lo tenían
-- porque lo puso otra ruta. Consecuencia: esas aulas no tienen código que dictar,
-- así que un aprendiz no puede unirse a ellas por código.
--
-- **Por qué en la base y no en la API.** Cualquier camino que cree una sección
-- —la ruta actual, una futura, un `insert` a mano en el editor de Supabase— pasa
-- por el trigger. Ponerlo sólo en el backend deja el mismo agujero abierto para
-- el siguiente que escriba la consulta.
--
-- El choque de códigos se resuelve **en el trigger** y no con un `unique` a
-- secas: si dos inserciones sortean el mismo código, la segunda reintenta en vez
-- de fallar la creación del aula entera. El índice único sigue estando abajo como
-- invariante.

-- 1) Índice único parcial: el código identifica un aula, pero NULL se repite sin
--    problema (una sección sin código nunca se podrá unir, y eso se corrige con
--    el backfill de abajo).
create unique index if not exists sections_join_code_unico
  on public.sections (join_code)
  where join_code is not null;

-- 2) El trigger.
create or replace function public.sections_asignar_join_code()
returns trigger
language plpgsql
as $function$
declare
  intento integer := 0;
  candidato text;
begin
  if new.join_code is not null and length(trim(new.join_code)) > 0 then
    new.join_code := upper(trim(new.join_code));
    return new;
  end if;

  -- 40 intentos con 32^8 combinaciones: agotar esto significa que algo raro pasa
  -- (o que alguien puso un alfabeto de dos letras), no mala suerte.
  while intento < 40 loop
    candidato := public.generar_codigo_aula(8);
    if not exists (
      select 1 from public.sections s where s.join_code = candidato
    ) then
      new.join_code := candidato;
      return new;
    end if;
    intento := intento + 1;
  end loop;

  raise exception 'No se pudo generar un código de aula único tras 40 intentos.'
    using errcode = '23505';
end;
$function$;

drop trigger if exists tr_sections_join_code on public.sections;

create trigger tr_sections_join_code
  before insert on public.sections
  for each row
  execute function public.sections_asignar_join_code();

-- 3) Backfill: las secciones que ya quedaron sin código lo reciben ahora, para
--    que las aulas de hoy sean usables sin recrearlas.
update public.sections
   set join_code = public.generar_codigo_aula(8)
 where join_code is null;

comment on function public.sections_asignar_join_code() is
  'Asigna join_code al insertar una sección si no viene. Cierra el hueco de las '
  'aulas creadas sin código (medido 2026-10-31: GRUPO1 y A).';
