-- F2.1 · El aula virtual (que es el grupo) gana un código para entrar.
--
-- Por qué. Hoy el alumno sólo entra a un aula si alguien lo matricula desde
-- administración. Classroom resuelve esto con un código de clase que el docente
-- dicta en voz alta; es la mejora de usabilidad más grande por línea escrita, y
-- la que el dueño pidió al decir que todo esto debería ser «fácil de gestionar».
--
-- Medido antes de escribir: **no existe tabla `aulas_virtuales`**.
-- `CpanelAulasVirtualesPanel` se apoya en `SeccionesRepository`, así que el aula
-- virtual **ya es** el grupo (`sections`). No se inventa entidad: se le añade la
-- puerta de entrada.
--
-- ADITIVO. Añade columnas nulables y una función. No toca tipos existentes, así
-- que ninguna vista depende de esto y no hay que recrear nada —a diferencia de
-- 202610300001, donde el cambio de tipo obligó a rehacer tres vistas—.

-- 1. El código. 8 caracteres del alfabeto sin ambigüedad: fuera I, O, 0 y 1,
--    porque esto se dicta en un aula y «cero u O» se confunden igual que «uno o I».
alter table public.sections
  add column if not exists join_code varchar(8);

alter table public.sections
  add column if not exists join_code_rotado_en timestamptz;

-- 2. Un código por período. Entre períodos puede repetirse: un alumno nunca ve
--    dos períodos a la vez y la búsqueda siempre lleva el período vigente.
create unique index if not exists sections_join_code_periodo_unico
  on public.sections (period_code, join_code)
  where join_code is not null;

-- 3. La generación vive en la base, no en la API.
--    **Por qué.** Si la genera el cliente, dos alumnos pueden recibir el mismo
--    código en una carrera de dos peticiones; y si la genera la API, cada
--    servicio nuevo tendría que reimplementarla. Aquí es una sola función.
--    `security definer` no hace falta: es pura aritmética sobre un alfabeto fijo.
create or replace function public.generar_codigo_aula(largo integer default 8)
returns varchar
language plpgsql
as $$
declare
  alfabeto constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  resultado text := '';
  i integer := 0;
begin
  if largo < 4 or largo > 8 then
    raise exception 'El largo del código de aula debe estar entre 4 y 8 caracteres.';
  end if;

  while i < largo loop
    -- random() no es criptográfico, y aquí no hace falta: el código no es una
    -- contraseña, es una invitación que se rota. Lo que sí hace falta es que no
    -- salga predecible de una vez a otra, y eso lo da el sembrado del motor.
    resultado := resultado ||
      substr(alfabeto, 1 + floor(random() * length(alfabeto))::int, 1);
    i := i + 1;
  end loop;

  return resultado;
end;
$$;

comment on function public.generar_codigo_aula(integer) is
  'Código de aula de 4-8 caracteres sin letras ni dígitos ambiguos (I, O, 0, 1).';

-- 4. Los grupos que ya existen necesitan uno: sin esto, el aula virtual vieja se
--    queda sin puerta y el panel muestra un guion en la columna del código.
do $$
declare
  fila record;
  codigo text;
begin
  for fila in
    select id, period_code from public.sections where join_code is null
  loop
    loop
      codigo := public.generar_codigo_aula(8);
      exit when not exists (
        select 1 from public.sections
        where period_code = fila.period_code and join_code = codigo
      );
    end loop;

    update public.sections set join_code = codigo where id = fila.id;
  end loop;
end
$$;

-- 5. Cómo entró cada alumno al aula.
--
--    Sin esto, una matrícula hecha a mano desde administración es
--    indistinguible de una inscripción formal, y el aula deja de ser auditable.
--    OJO: **no** se toca `enrollments.status`. La vista `v_exportacion_hacer`
--    filtra `status = 'ENROLLED'`, así que cambiar ese enum cambia la planilla
--    oficial de HACER — eso necesita la decisión del dueño, no una migración
--    silenciosa.
alter table public.enrollments
  add column if not exists origen text not null default 'INSCRIPCION';

alter table public.enrollments
  drop constraint if exists enrollments_origen_valido;

alter table public.enrollments
  add constraint enrollments_origen_valido
  check (origen in ('INSCRIPCION', 'CODIGO', 'ADMIN'));

comment on column public.enrollments.origen is
  'Cómo entró el alumno: INSCRIPCION (formulario), CODIGO (canjeó el código de '
  'aula) o ADMIN (lo matriculó un administrador).';
