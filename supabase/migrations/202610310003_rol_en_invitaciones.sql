-- Rol en las invitaciones: ahora un docente puede invitar aprendices.
--
-- **Qué resolvía antes.** `teacher_invitations` sólo sabía de docentes, y la
-- activación lo daba por hecho: `auth/activar` hacía
-- `cambiarRol(idUsuario, 'docente')` con el rol escrito a mano. Reutilizar esa
-- invitación para un alumno habría creado **docentes**: con acceso a calificar,
-- publicar tareas y ver notas ajenas. Por eso el docente no podía invitar a sus
-- aprendices sin pasar por administración.
--
-- **Por qué una columna y no una tabla nueva.** Una invitación es la misma cosa
-- en los dos casos: un correo, un token con hash, una caducidad y un uso. Lo que
-- cambia es qué rol se otorga al activarla. Duplicar la tabla duplicaría también
-- la revocación, la caducidad y el panel.
--
-- `default 'docente'` deja intactas las filas que ya existen y cualquier código
-- que inserte sin decirlo.

alter table public.teacher_invitations
  add column if not exists rol text not null default 'docente';

-- El `check` se añade aparte para poder repetir la migración sin fallar.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.teacher_invitations'::regclass
      and conname = 'teacher_invitations_rol_check'
  ) then
    alter table public.teacher_invitations
      add constraint teacher_invitations_rol_check
      check (rol in ('docente', 'estudiante'));
  end if;
end $$;

comment on column public.teacher_invitations.rol is
  'Rol que se otorga al activar la invitación. Default docente para no cambiar '
  'el comportamiento anterior; estudiante cuando la crea el docente de un aula.';
