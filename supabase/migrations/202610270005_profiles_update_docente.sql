-- =============================================================================
-- Permite a docentes y estudiantes actualizar su propio perfil (nombre y cédula).
-- Los administradores siguen cubiertos por `profiles_admin_all`.
-- =============================================================================

drop policy if exists profiles_update_own on public.profiles;

create policy profiles_update_own
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid() and rol in ('estudiante', 'docente'));

comment on policy profiles_update_own on public.profiles is
  'Permite a aprendices y docentes corregir su nombre y cédula en su propio perfil.';
