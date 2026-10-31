-- Choque de horario al inscribirse.
--
-- **Qué resuelve.** Un aprendiz podía solicitar dos secciones cuyos bloques caen
-- el mismo día a la misma hora: la base aceptaba las dos y la persona aparecía
-- matriculada en dos aulas a la vez. El cuadrante sí detecta choques de docente y
-- de espacio (triggers de M3), pero nadie miraba el del **estudiante**.
--
-- **Por qué un trigger y no la RPC.** La solicitud entra por
-- `solicitar_inscripcion`, pero también por `matricular_por_administrador` y por
-- reincorporaciones. Poner la comprobación en una sola de ellas dejaría las otras
-- dos abiertas; reescribir la RPC entera para añadir seis líneas es pedir una
-- errata en un bloque de cien. El trigger cubre **todas** las puertas de entrada.
--
-- **A quién no se le aplica.** Cuando la fila la crea otra persona —administración
-- matriculando a un aprendiz— el actor no es el estudiante. Ahí se deja pasar: es
-- una decisión consciente de quien coordina (y a veces legítima, como una
-- reincorporación a un horario que ya tenía). La regla es del **autoservicio**.

create or replace function public.comprobar_choque_de_horario()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_actor     uuid := auth.uid();
  v_dia       smallint;
  v_bloque    smallint;
  v_choque    text;
begin
  -- Sólo el propio estudiante. El administrador conserva la potestad de
  -- matricular, y aquí no hay forma de distinguir "se equivocó" de "lo decidió".
  if v_actor is null or NEW.student_id <> v_actor then
    return NEW;
  end if;

  -- Una baja no ocupa horario; una solicitud en cola sí compromete al aprendiz
  -- con ese bloque, porque puede acabar dentro.
  if NEW.status not in ('ENROLLED', 'WAITLISTED', 'ACCEPTED') then
    return NEW;
  end if;

  select s.day_of_week, s.block
    into v_dia, v_bloque
  from public.schedule_slots s
  where s.section_id = NEW.section_id
    and s.is_active
  limit 1;

  -- Sección sin horario asignado todavía: no hay nada que comparar. Se permite y
  -- el choque se detectará cuando el cuadrante tenga la clase.
  if v_dia is null then
    return NEW;
  end if;

  select format('%s (%s, bloque %s)',
                sec.name,
                case s2.day_of_week
                  when 1 then 'lunes'
                  when 2 then 'martes'
                  when 3 then 'miércoles'
                  when 4 then 'jueves'
                  when 5 then 'viernes'
                  when 6 then 'sábado'
                  else 'día ' || s2.day_of_week
                end,
                s2.block)
    into v_choque
  from public.schedule_slots s2
  join public.enrollments e
    on e.section_id = s2.section_id
   and e.student_id = NEW.student_id
   and e.status in ('ENROLLED', 'WAITLISTED', 'ACCEPTED')
   and e.section_id <> NEW.section_id
  join public.sections sec on sec.id = e.section_id
  where s2.is_active
    and s2.day_of_week = v_dia
    and s2.block = v_bloque
  limit 1;

  if v_choque is not null then
    raise exception
      'Ese horario choca con «%»: coincide el mismo día y el mismo bloque.',
      v_choque
      using errcode = '23514',
            hint = 'Elige otra sección o renuncia a la anterior antes de inscribirte en esta.';
  end if;

  return NEW;
end;
$function$;

comment on function public.comprobar_choque_de_horario() is
  'Impide que un aprendiz quede en dos secciones con el mismo día y bloque. No '
  'aplica cuando la matrícula la crea administración (el actor no es el alumno).';

drop trigger if exists enrollments_sin_choque_de_horario on public.enrollments;

create trigger enrollments_sin_choque_de_horario
  before insert on public.enrollments
  for each row
  execute function public.comprobar_choque_de_horario();
