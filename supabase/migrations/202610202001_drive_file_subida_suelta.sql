-- DRIVE_FILE: la subida suelta al gestor documental.
--
-- **El problema que resuelve.** El Módulo 5 nació para archivos atados a una
-- entidad del aula: `TASK_SUBMISSION` (entrega del alumno) y `TEACHER_GUIDE`
-- (material del docente). El gestor documental —el «Drive» del sistema— necesita
-- subir archivos que no cuelgan de ninguna tarea ni entrega todavía, y el CHECK
-- de la tabla los rechazaba: la app tuvo que fingirlos como TEACHER_GUIDE con
-- `entidad_id` NULL, que es una mentira en los datos. Medido el 2026-10-20: el
-- ciclo real (firmar 201 -> PUT 200 -> confirmar 200) funciona end-to-end contra
-- el backend local; lo único que faltaba era un tipo honesto para la subida
-- suelta.
--
-- **Qué NO cambia.** El trigger de integridad de M6 sólo mira archivos con
-- `entidad_id` no nulo; `DRIVE_FILE` siempre tendrá `entidad_id` NULL, así que
-- pasa sin tocar M6. La escritura sigue siendo sólo por RPC `security definer`
-- (M5). Las políticas de lectura no cambian: el dueño lee lo suyo
-- (`files_metadata_read_own`) y el administrador lee todo
-- (`files_metadata_admin_read`, que no filtra por tipo).

-- 1. El CHECK nuevo, con el valor honesto.
alter table public.files_metadata
  drop constraint if exists files_metadata_entity_type_check;

alter table public.files_metadata
  add constraint files_metadata_entity_type_check
  check (entity_type in ('TASK_SUBMISSION', 'TEACHER_GUIDE', 'DRIVE_FILE'));

-- 2. Endurecimiento: DRIVE_FILE no puede colgarse de una entidad.
--    M6 ya rechaza (por trigger) que una entrega o guía apunte a entidad ajena;
--    DRIVE_FILE no tiene entidad posible, así que exigir NULL aquí cierra el
--    agujero simétrico: nadie debería poder atar un archivo del drive a, por
--    ejemplo, una entrega cualquiera.
create or replace function public.m6_validar_entidad_de_archivo()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  -- DRIVE_FILE: subida suelta al gestor. Sin entidad por definición.
  if new.entity_type = 'DRIVE_FILE' then
    if new.entidad_id is not null then
      raise exception
        'Un archivo DRIVE_FILE no puede colgarse de una entidad (entidad_id debe ser NULL).'
        using errcode = '23514';
    end if;
    return new;
  end if;

  if new.entidad_id is null then
    return new;
  end if;

  if new.entity_type = 'TASK_SUBMISSION' then
    -- La entrega tiene que existir Y ser de quien sube el archivo. Se compara
    -- contra `propietario_id` y no contra `auth.uid()` porque un administrador
    -- puede registrar en nombre de otro (M5 lo permite explícitamente).
    if not exists (
      select 1
      from public.m6_entregas e
      where e.id = new.entidad_id
        and e.estudiante_id = new.propietario_id
    ) then
      raise exception
        'La entrega % no existe o no pertenece al propietario del archivo.',
        new.entidad_id
        using errcode = '23503';
    end if;

  elsif new.entity_type = 'TEACHER_GUIDE' then
    -- La guía se cuelga de una tarea que el usuario dicta (o de cualquiera, si
    -- es administrador). Sin esto, un alumno publicaría material en la tarea
    -- de toda la sección.
    if not exists (
      select 1
      from public.m6_tareas t
      where t.id = new.entidad_id
        and public.m6_dicta_seccion(t.seccion_id)
    ) then
      raise exception
        'La tarea % no existe o no la dicta quien sube la guía.',
        new.entidad_id
        using errcode = '23503';
    end if;
  end if;

  return new;
end;
$$;

comment on function public.m6_validar_entidad_de_archivo() is
  'Impide que un archivo se ate a una entidad ajena: una entrega de otro alumno o la tarea de una sección que no se dicta. Desde 2026-10-20 también exige que DRIVE_FILE (subida suelta al gestor) no lleve entidad.';
