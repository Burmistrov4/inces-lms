-- F2.4 · Dar de baja a un aprendiz, sin borrar nada.
--
-- Decisión del dueño (2026-10-30): «un alumno dado de baja puede seguir
-- conservando sus datos... el estudiante debe seguir conservando un registro de
-- su planilla accesible para los administradores y para el estudiante».
--
-- Consecuencia de diseño: la baja es un **cambio de estado**, no un `delete`.
-- `renunciar_cupo` ya existía, pero es la renuncia del propio alumno; faltaba la
-- baja administrativa, que tiene otro motivo (mala conducta, abandono, error de
-- matrícula) y debe quedar auditada con quién la hizo y por qué.
--
-- No se toca `v_exportacion_hacer`: sigue exportando sólo `ENROLLED`, es decir,
-- a los inscritos vigentes. El historial del retirado vive en la aplicación y se
-- ve en `misInscripciones` y `inscritosDeSeccion`, que **no filtran por estado**.
-- Si el centro quiere que HACER reciba también a los retirados, es un cambio de
-- una línea en la vista y necesita su decisión, no la mía.

create or replace function public.dar_de_baja_por_administrador(
  p_student_id uuid,
  p_section_id uuid,
  p_motivo text
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
  v_email    text;
  v_id       uuid;
  v_status   text;
  v_motivo   text := btrim(coalesce(p_motivo, ''));
begin
  if v_actor is null then
    raise exception 'Se requiere una sesión para dar de baja a un alumno.'
      using errcode = '42501';
  end if;

  select p.rol, p.active, p.email into v_rol, v_activo, v_email
  from public.profiles p
  where p.id = v_actor;

  if v_rol is distinct from 'admin' or not coalesce(v_activo, false) then
    raise exception 'Sólo un administrador activo puede dar de baja a un alumno.'
      using errcode = '42501';
  end if;

  -- El motivo es obligatorio y no es decorativo: es lo único que explicará,
  -- dentro de dos años, por qué Fulano no terminó el curso.
  if length(v_motivo) < 3 then
    raise exception 'Indica el motivo de la baja (al menos 3 caracteres).'
      using errcode = '22023';
  end if;

  select e.id, e.status into v_id, v_status
  from public.enrollments e
  where e.student_id = p_student_id and e.section_id = p_section_id;

  if v_id is null then
    raise exception 'Ese aprendiz no está matriculado en esta aula.'
      using errcode = '23514';
  end if;

  -- Idempotente: darla de baja dos veces no es un error, es que ya lo estaba.
  if v_status = 'DROPPED' then
    return 'DROPPED';
  end if;

  perform pg_advisory_xact_lock(hashtext('inscripcion|' || p_section_id::text));

  update public.enrollments
     set status = 'DROPPED',
         updated_at = now()
   where id = v_id;

  -- La fila se conserva entera: nombre, planilla, fechas. Sólo cambia el estado.
  insert into public.config_audit_log (
    tabla, clave, valor_anterior, valor_nuevo, actor_id, usuario_email, motivo
  )
  values (
    'enrollments',
    v_id::text,
    jsonb_build_object('status', v_status),
    jsonb_build_object('status', 'DROPPED', 'section_id', p_section_id),
    v_actor,
    v_email,
    v_motivo
  );

  -- Liberar un cupo promueve al siguiente de la cola, igual que la renuncia.
  perform public.promover_siguiente_de_cola(p_section_id);

  return 'DROPPED';
end;
$$;

comment on function public.dar_de_baja_por_administrador(uuid, uuid, text) is
  'Da de baja (status DROPPED) sin borrar: el expediente y la planilla del alumno '
  'quedan intactos y visibles. Exige motivo, que se guarda en config_audit_log con '
  'quién lo hizo. Idempotente. Libera el cupo y promueve al siguiente de la cola.';

revoke all on function public.dar_de_baja_por_administrador(uuid, uuid, text) from public;
grant execute on function public.dar_de_baja_por_administrador(uuid, uuid, text) to authenticated;
