-- F2.3 · Las dos puertas del aula: matricular a un tercero y entrar con código.
--
-- Contexto que manda (medido). `enrollments` tiene INSERT/UPDATE/DELETE revocados
-- para `anon` y `authenticated` (R-23): toda escritura de matrícula pasa por RPC
-- `security definer` que autoriza sola con `auth.uid()`. Por eso esto **no puede**
-- ser una ruta que haga `insert`: contra la base real daría 42501.
--
-- Las RPC que ya existen tampoco sirven. `solicitar_inscripcion` autoriza al
-- **llamante** como alumno que pide su propio asiento; aquí hacen falta dos casos
-- distintos:
--   1. un administrador matriculando a un **tercero**,
--   2. un alumno canjeando un **código** de aula.
--
-- El código de verificación va en la API, no aquí: contar intentos fallidos en la
-- base convierte un escaneo de códigos en escrituras, que es peor que el escaneo.

-- ---------------------------------------------------------------------------
-- 1. Matricular a un tercero (sólo administración)
-- ---------------------------------------------------------------------------
create or replace function public.matricular_por_administrador(
  p_student_id uuid,
  p_section_id uuid,
  p_origen text default 'ADMIN'
)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor    uuid := auth.uid();
  v_rol      text;
  v_activo   boolean;
  v_activa   boolean;
  v_periodo  text;
  v_existe   text;
  v_efectivo integer;
  v_ocupados integer;
begin
  if v_actor is null then
    raise exception 'Se requiere una sesión para matricular a un alumno.'
      using errcode = '42501';
  end if;

  select p.rol, p.active into v_rol, v_activo
  from public.profiles p
  where p.id = v_actor;

  if v_rol is distinct from 'admin' or not coalesce(v_activo, false) then
    raise exception 'Sólo un administrador activo puede matricular a un alumno.'
      using errcode = '42501';
  end if;

  if p_origen not in ('INSCRIPCION', 'CODIGO', 'ADMIN') then
    raise exception 'Origen de matrícula inválido: %.', p_origen
      using errcode = '22023';
  end if;

  select s.is_active, s.period_code into v_activa, v_periodo
  from public.sections s
  where s.id = p_section_id;

  if v_activa is null then
    raise exception 'El aula % no existe.', p_section_id
      using errcode = '23514';
  end if;

  if not v_activa then
    raise exception 'El aula está archivada y no admite matrículas nuevas.'
      using errcode = '23514';
  end if;

  -- El período cerrado se congela: no admite matrículas. Es la misma regla que
  -- el trigger de horarios, aplicada aquí porque esta RPC escribe con permisos
  -- de dueño y ningún trigger de sección la va a frenar.
  if exists (
    select 1 from public.academic_periods ap
    where ap.code = v_periodo and ap.closed_at is not null
  ) then
    raise exception 'El período % está cerrado: no admite matrículas nuevas.', v_periodo
      using errcode = '23514';
  end if;

  select p.rol into v_rol from public.profiles p where p.id = p_student_id;
  if v_rol is distinct from 'estudiante' then
    raise exception 'Ese usuario no es un aprendiz.'
      using errcode = '23514';
  end if;

  select e.status into v_existe
  from public.enrollments e
  where e.student_id = p_student_id and e.section_id = p_section_id;

  if v_existe = 'ENROLLED' then
    -- Idempotente: volver a matricular a quien ya está no es un error, es que ya
    -- lo estaba. Devolver el estado evita un 409 que el panel tendría que tragar.
    return 'ENROLLED';
  end if;

  if v_existe is not null then
    raise exception 'El alumno ya tiene una matrícula en esta aula (estado %). Usa reincorporar, que deja rastro del motivo.', v_existe
      using errcode = '23505';
  end if;

  -- El cupo se respeta también por esta vía. Sin esto, la administración podría
  -- dejar un aula en 41 alumnos cuando declara 40, y el motor de cupos del
  -- aspirante quedaría decorativo en cuanto alguien matricula a mano.
  v_efectivo := public.cupo_efectivo(p_section_id);
  v_ocupados := public.cupos_ocupados(p_section_id);
  if v_efectivo is not null and v_efectivo > 0 and v_ocupados >= v_efectivo then
    raise exception 'El aula está llena: % de % puestos ocupados.', v_ocupados, v_efectivo
      using errcode = '23514';
  end if;

  insert into public.enrollments (student_id, section_id, status, origen)
  values (p_student_id, p_section_id, 'ENROLLED', p_origen);

  return 'ENROLLED';
end;
$$;

comment on function public.matricular_por_administrador(uuid, uuid, text) is
  'Matricula a un aprendiz en un aula. security definer con autorización propia: '
  'exige rol admin activo, aula viva, período abierto y cupo disponible. '
  'Idempotente si el alumno ya estaba. No crea usuarios.';

-- ---------------------------------------------------------------------------
-- 2. Entrar con el código de aula (el alumno, sobre sí mismo)
-- ---------------------------------------------------------------------------
create or replace function public.unirse_por_codigo(p_codigo text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor   uuid := auth.uid();
  v_rol     text;
  v_seccion uuid;
  v_periodo text;
  v_existe  text;
  v_efectivo integer;
  v_ocupados integer;
begin
  if v_actor is null then
    raise exception 'Se requiere una sesión para unirse a un aula.'
      using errcode = '42501';
  end if;

  select p.rol into v_rol from public.profiles p where p.id = v_actor;
  if v_rol is distinct from 'estudiante' then
    raise exception 'Sólo un aprendiz puede unirse a un aula con un código.'
      using errcode = '42501';
  end if;

  -- Se busca en el período vigente: un código de un período cerrado no sirve
  -- para entrar a clase hoy, y el alumno no elige período.
  select s.id, s.period_code into v_seccion, v_periodo
  from public.sections s
  join public.academic_periods ap on ap.code = s.period_code
  where upper(trim(s.join_code)) = upper(trim(p_codigo))
    and s.is_active
    and ap.closed_at is null
  order by ap.start_date desc nulls last
  limit 1;

  if v_seccion is null then
    -- Mismo mensaje para «no existe» y «está cerrada»: distinguirlos convertiría
    -- la RPC en un oráculo para adivinar códigos.
    raise exception 'Ese código no corresponde a ninguna aula abierta.'
      using errcode = '23514';
  end if;

  select e.status into v_existe
  from public.enrollments e
  where e.student_id = v_actor and e.section_id = v_seccion;

  if v_existe = 'ENROLLED' then
    return v_seccion;
  end if;

  if v_existe is not null then
    raise exception 'Ya estuviste en esta aula (estado %). Pide a administración que te reincorpore.', v_existe
      using errcode = '23505';
  end if;

  v_efectivo := public.cupo_efectivo(v_seccion);
  v_ocupados := public.cupos_ocupados(v_seccion);
  if v_efectivo is not null and v_efectivo > 0 and v_ocupados >= v_efectivo then
    raise exception 'El aula está llena: % de % puestos ocupados. Pide a administración que te ubique.', v_ocupados, v_efectivo
      using errcode = '23514';
  end if;

  insert into public.enrollments (student_id, section_id, status, origen)
  values (v_actor, v_seccion, 'ENROLLED', 'CODIGO');

  return v_seccion;
end;
$$;

comment on function public.unirse_por_codigo(text) is
  'El aprendiz canjea el código de aula del período vigente y queda matriculado '
  '(origen CODIGO). No distingue «no existe» de «está cerrada» a propósito: sería '
  'un oráculo para adivinar códigos.';

-- Permisos: son funciones para usuarios con sesión, no para `anon`.
revoke all on function public.matricular_por_administrador(uuid, uuid, text) from public;
revoke all on function public.unirse_por_codigo(text) from public;
grant execute on function public.matricular_por_administrador(uuid, uuid, text) to authenticated;
grant execute on function public.unirse_por_codigo(text) to authenticated;
