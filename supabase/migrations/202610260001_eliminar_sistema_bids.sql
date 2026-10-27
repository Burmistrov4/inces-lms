-- =============================================================================
--  INCES LMS — TAREA 1: Eliminar el sistema de bids (ofertas de cupo)
--  Archivo: 202610260001_eliminar_sistema_bids.sql
-- =============================================================================
--
--  POR QUÉ EXISTE (Decisión D1 de la especificación maestra 1.5)
--  -------------------------------------------------------------
--  En la concepción original (202609190001 / 202609200001), al liberarse un
--  cupo se ofrecía a la cola en estado PENDING_BID con un vencimiento
--  (bid_expires_at). Si el alumno no respondía a tiempo, la oferta se vencía.
--
--  En una institución de formación técnica pública como el INCES los cupos
--  no se subastan ni se negocian: se asignan. El ciclo simplificado queda:
--  WAITLISTED (cola) → ENROLLED (matriculado) → DROPPED (baja / historial).
--  Al liberarse un cupo, el primero de la cola entra automáticamente a ENROLLED.
--
--  En producción medido al 2026-10-25: 0 filas en PENDING_BID. No hay datos que
--  migrar.
-- =============================================================================

-- -----------------------------------------------------------------------------
--  PARTE 1 — Limpieza de índices y columna bid_expires_at
-- -----------------------------------------------------------------------------
drop index if exists public.enrollments_oferta_vigente_idx;

drop index if exists public.enrollments_ocupacion_idx;
create index if not exists enrollments_ocupacion_idx
  on public.enrollments (section_id)
  where status = 'ENROLLED';

alter table public.enrollments drop column if exists bid_expires_at;

-- Actualizar restricción de estados en enrollments
alter table public.enrollments drop constraint if exists enrollments_status_check;
alter table public.enrollments add constraint enrollments_status_check
  check (status in ('ENROLLED', 'WAITLISTED', 'DROPPED'));

-- -----------------------------------------------------------------------------
--  PARTE 2 — Eliminar parámetros obsoletos del sistema de bids
-- -----------------------------------------------------------------------------
delete from public.system_settings where clave in ('habilitar_sistema_bids', 'bid_ttl_horas');

-- -----------------------------------------------------------------------------
--  PARTE 3 — Actualizar funciones de cupos y ocupación
-- -----------------------------------------------------------------------------

-- Asientos ocupados: SÓLO ENROLLED
create or replace function public.cupos_ocupados(p_section_id uuid)
returns integer
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select count(*)::int
  from public.enrollments e
  where e.section_id = p_section_id
    and e.status = 'ENROLLED';
$$;

comment on function public.cupos_ocupados(uuid) is
  'Asientos ocupados por una sección: SÓLO ENROLLED. Bids eliminados según D1.';

-- existe_oferta_vigente: mantenida por compatibilidad de vistas/consultas, devuelve siempre false
create or replace function public.existe_oferta_vigente(p_section_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select false;
$$;

comment on function public.existe_oferta_vigente(uuid) is
  'Devuelve false siempre: el sistema de bids fue eliminado en D1.';

-- Solicitar inscripción: sin ofertas intermedias
create or replace function public.solicitar_inscripcion(p_section_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor     uuid := auth.uid();
  v_activa    boolean;
  v_existente text;
  v_nuevo     text;
begin
  if v_actor is null then
    raise exception 'Se requiere una sesión para solicitar una inscripción.'
      using errcode = '42501';
  end if;

  select s.is_active into v_activa
  from public.sections s
  where s.id = p_section_id;

  if v_activa is null then
    raise exception 'La sección % no existe.', p_section_id
      using errcode = '23514';
  end if;

  if not v_activa then
    raise exception 'La sección % está archivada y no admite inscripciones.', p_section_id
      using errcode = '23514';
  end if;

  select e.status into v_existente
  from public.enrollments e
  where e.student_id = v_actor
    and e.section_id = p_section_id;

  if v_existente is not null then
    if v_existente = 'DROPPED' then
      raise exception
        'Ya cursaste la sección %: un administrador debe reincorporarte explícitamente.',
        p_section_id
        using errcode = '23514';
    else
      raise exception
        'Ya tienes una solicitud activa (%) para la sección %.',
        v_existente, p_section_id
        using errcode = '23514';
    end if;
  end if;

  -- Cerrojo por sección
  perform pg_advisory_xact_lock(hashtext('inscripcion|' || p_section_id::text));

  if public.cupos_ocupados(p_section_id) < public.cupo_efectivo(p_section_id) then
    v_nuevo := 'ENROLLED';
  else
    v_nuevo := 'WAITLISTED';
  end if;

  insert into public.enrollments (student_id, section_id, status)
  values (v_actor, p_section_id, v_nuevo);

  return v_nuevo;
end;
$$;

comment on function public.solicitar_inscripcion(uuid) is
  'Inscribe al llamante: ENROLLED si hay cupo, WAITLISTED si no. Sin bids (D1).';

-- Promover al siguiente de la cola: directamente a ENROLLED
create or replace function public.promover_siguiente_de_cola(p_section_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id        uuid;
  v_promovido uuid;
begin
  perform pg_advisory_xact_lock(hashtext('inscripcion|' || p_section_id::text));

  if public.cupos_ocupados(p_section_id) >= public.cupo_efectivo(p_section_id) then
    return null;
  end if;

  select e.id
    into v_id
  from public.enrollments e
  where e.section_id = p_section_id
    and e.status = 'WAITLISTED'
  order by e.created_at, e.id
  limit 1;

  if v_id is null then
    return null;
  end if;

  update public.enrollments
     set status = 'ENROLLED'
   where id = v_id
  returning student_id into v_promovido;

  return v_promovido;
end;
$$;

comment on function public.promover_siguiente_de_cola(uuid) is
  'Promueve al primero de la cola FIFO directo a ENROLLED al haber cupo.';

-- Renunciar cupo: pasa a DROPPED y promueve al primero de la cola a ENROLLED
create or replace function public.renunciar_cupo(p_section_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor  uuid := auth.uid();
  v_id     uuid;
  v_status text;
begin
  if v_actor is null then
    raise exception 'Se requiere una sesión para renunciar a un cupo.'
      using errcode = '42501';
  end if;

  select e.id, e.status
    into v_id, v_status
  from public.enrollments e
  where e.student_id = v_actor
    and e.section_id = p_section_id;

  if v_id is null then
    raise exception 'No tienes ninguna inscripción en la sección %.', p_section_id
      using errcode = '23514';
  end if;

  if v_status = 'DROPPED' then
    raise exception 'Tu inscripción en la sección % ya estaba dada de baja.', p_section_id
      using errcode = '23514';
  end if;

  perform pg_advisory_xact_lock(hashtext('inscripcion|' || p_section_id::text));

  update public.enrollments
     set status = 'DROPPED'
   where id = v_id;

  perform public.promover_siguiente_de_cola(p_section_id);

  return 'DROPPED';
end;
$$;

comment on function public.renunciar_cupo(uuid) is
  'Renuncia al asiento (DROPPED) y promueve automáticamente al primero de la cola a ENROLLED.';

-- Reincorporar: sin tocar bid_expires_at
create or replace function public.reincorporar_inscripcion(
  p_student_id uuid,
  p_section_id uuid
)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id     uuid;
  v_status text;
begin
  if not public.is_admin() then
    raise exception 'Sólo un administrador puede reincorporar una inscripción.'
      using errcode = '42501';
  end if;

  select e.id, e.status
    into v_id, v_status
  from public.enrollments e
  where e.student_id = p_student_id
    and e.section_id = p_section_id;

  if v_id is null then
    raise exception
      'No existe una inscripción previa del estudiante % en la sección %.',
      p_student_id, p_section_id
      using errcode = '23514';
  end if;

  if v_status <> 'DROPPED' then
    raise exception
      'La inscripción del estudiante % en la sección % no está dada de baja (estado actual: %).',
      p_student_id, p_section_id, v_status
      using errcode = '23514';
  end if;

  perform pg_advisory_xact_lock(hashtext('inscripcion|' || p_section_id::text));

  update public.enrollments
     set status = 'ENROLLED'
   where id = v_id;

  return 'ENROLLED';
end;
$$;

comment on function public.reincorporar_inscripcion(uuid, uuid) is
  'Vuelve a ENROLLED una inscripción DROPPED, sin tocar bid_expires_at.';

-- expirar_ofertas_cupo: idempotente, ya no hay ofertas que expirar
create or replace function public.expirar_ofertas_cupo()
returns integer
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select 0;
$$;

comment on function public.expirar_ofertas_cupo() is
  'Devuelve 0 siempre: las ofertas con vencimiento fueron eliminadas en D1.';

-- aceptar_cupo: idempotente por compatibilidad
create or replace function public.aceptar_cupo(p_section_id uuid)
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select 'ENROLLED'::text;
$$;

comment on function public.aceptar_cupo(uuid) is
  'Devuelve ENROLLED por compatibilidad: la asignación de cupo es ahora automática (D1).';
