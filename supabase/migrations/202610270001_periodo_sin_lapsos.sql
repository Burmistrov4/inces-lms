-- =============================================================================
--  INCES LMS — TAREA 2: «Lapsos» desaparece; queda «Período» (D2)
--  Archivo: 202610270001_periodo_sin_lapsos.sql
-- =============================================================================
--
--  POR QUÉ EXISTE (Decisión D2 de la especificación maestra 1.5)
--  -------------------------------------------------------------
--  En el sistema coexistían dos nombres para la misma entidad: «lapso» y
--  «período» (apuntando ambos a la tabla `academic_periods`). El menú llamaba
--  al módulo «Lapsos Académicos» y la fila existente se llamaba «Lapso SA26-2».
--
--  Lorenzo unificó la terminología institucional: queda únicamente «Período».
--  Además, al crear el período siguiente, el sistema debe ofrecer heredar el
--  horario del anterior (secciones, clases/bloques y guardias de docentes).
--
--  La tabla `academic_periods` NO se borra porque `sections.period_code` y
--  múltiples referencias dependen de ella.
-- =============================================================================

-- -----------------------------------------------------------------------------
--  PARTE 1 — Normalización del registro histórico a «Período»
-- -----------------------------------------------------------------------------
update public.academic_periods
set name = 'Período SA26-2'
where code = 'SA26-2' and name = 'Lapso SA26-2';

-- -----------------------------------------------------------------------------
--  PARTE 2 — Función para heredar el horario de un período a otro
-- -----------------------------------------------------------------------------
create or replace function public.heredar_horario_periodo(
  p_nuevo_codigo text,
  p_origen_codigo text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_seccion record;
  v_nueva_seccion_id uuid;
  v_slot record;
  v_guardia record;
  v_secciones_copiadas integer := 0;
  v_clases_copiadas integer := 0;
  v_guardias_copiadas integer := 0;
begin
  if not public.is_admin() then
    raise exception 'Sólo un administrador puede heredar horarios de un período.'
      using errcode = '42501';
  end if;

  if not exists (select 1 from public.academic_periods where code = p_nuevo_codigo) then
    raise exception 'El período destino «%» no está registrado.', p_nuevo_codigo
      using errcode = '23503';
  end if;

  if not exists (select 1 from public.academic_periods where code = p_origen_codigo) then
    raise exception 'El período origen «%» no está registrado.', p_origen_codigo
      using errcode = '23503';
  end if;

  -- 1. Heredar secciones activas y sus clases (schedule_slots)
  for v_seccion in
    select * from public.sections
    where period_code = p_origen_codigo and is_active = true
  loop
    select id into v_nueva_seccion_id
    from public.sections
    where period_code = p_nuevo_codigo
      and subject_id = v_seccion.subject_id
      and name = v_seccion.name;

    if v_nueva_seccion_id is null then
      insert into public.sections (
        program_id,
        subject_id,
        period_code,
        name,
        max_capacity,
        is_active
      ) values (
        v_seccion.program_id,
        v_seccion.subject_id,
        p_nuevo_codigo,
        v_seccion.name,
        v_seccion.max_capacity,
        true
      ) returning id into v_nueva_seccion_id;
      v_secciones_copiadas := v_secciones_copiadas + 1;
    end if;

    for v_slot in
      select * from public.schedule_slots
      where section_id = v_seccion.id and is_active = true
    loop
      if not exists (
        select 1 from public.schedule_slots
        where section_id = v_nueva_seccion_id
          and day_of_week = v_slot.day_of_week
          and block = v_slot.block
          and classroom_id = v_slot.classroom_id
      ) then
        insert into public.schedule_slots (
          section_id,
          teacher_id,
          classroom_id,
          day_of_week,
          block,
          is_active
        ) values (
          v_nueva_seccion_id,
          v_slot.teacher_id,
          v_slot.classroom_id,
          v_slot.day_of_week,
          v_slot.block,
          true
        );
        v_clases_copiadas := v_clases_copiadas + 1;
      end if;
    end loop;
  end loop;

  -- 2. Heredar guardias docentes activas (teacher_duties)
  for v_guardia in
    select * from public.teacher_duties
    where period_code = p_origen_codigo and is_active = true
  loop
    if not exists (
      select 1 from public.teacher_duties
      where period_code = p_nuevo_codigo
        and teacher_id = v_guardia.teacher_id
        and classroom_id = v_guardia.classroom_id
        and day_of_week = v_guardia.day_of_week
        and block = v_guardia.block
    ) then
      insert into public.teacher_duties (
        period_code,
        teacher_id,
        classroom_id,
        day_of_week,
        block,
        notes,
        is_active
      ) values (
        p_nuevo_codigo,
        v_guardia.teacher_id,
        v_guardia.classroom_id,
        v_guardia.day_of_week,
        v_guardia.block,
        v_guardia.notes,
        true
      );
      v_guardias_copiadas := v_guardias_copiadas + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'secciones_copiadas', v_secciones_copiadas,
    'clases_copiadas', v_clases_copiadas,
    'guardias_copiadas', v_guardias_copiadas
  );
end;
$$;

comment on function public.heredar_horario_periodo(text, text) is
  'Hereda el horario (secciones, clases y guardias) de un período anterior hacia un nuevo período. Sólo administradores.';

grant execute on function public.heredar_horario_periodo(text, text) to authenticated;
