-- ============================================================================
--  CICLO DE VIDA DEL PERÍODO — ventana de inscripción y congelación real
--  Fecha: 2026-10-29
--
--  POR QUÉ EXISTE
--
--  El propietario preguntó, con razón: «¿qué debería suceder cuando se cierra un
--  período, cómo afecta, y cómo lo gestiona un administrador?». La respuesta
--  medida el 2026-10-29 era que cerrar sólo escribía `closed_at` y archivaba las
--  secciones: **se podía seguir creando clases, guardias y grupos dentro de un
--  período cerrado**, y `periodo_activo` seguía apuntándole. Es decir, el
--  candado de la interfaz no cerraba nada por debajo.
--
--  Este archivo hace dos cosas, y ninguna cambia el modelo de datos:
--
--   1. **Ventana de inscripción.** Dos columnas en `academic_periods`. Es un
--      dato que hoy no existe en ninguna parte, y sin él el estudiante no puede
--      saber si todavía puede inscribirse ni cuándo abre el siguiente ciclo.
--      Va en el PERÍODO y no en cada curso a propósito: abrir inscripciones es
--      un acto único del centro («del 15 al 30 de septiembre»), y el CFS tiene
--      un solo PNA. Pedir seis fechas para seis cursos es exactamente el tipo de
--      formulario que hace que nadie lo llene.
--
--   2. **Congelación.** Un período cerrado no admite grupos, clases ni guardias
--      nuevos. Lo que ya existe sigue visible y consultable: cerrar es
--      congelar, no borrar. Reabrir (que ya existe) lo descongela.
--
--  LO QUE **NO** HACE
--
--  · No bloquea las inscripciones en la base. El administrador puede
--    «reincorporar» a un aprendiz fuera de plazo, y esa es una decisión suya
--    (ver `POST /admin/inscripciones/reincorporar`). La ventana se aplica en la
--    ruta del estudiante, donde no hay nada que overridear.
--  · No archiva las aulas virtuales (decisión D8: no ocultar contenido docente).
--  · No borra inscripciones, notas ni asistencias. Son historial.
-- ============================================================================

-- ----------------------------------------------------------------------------
--  1. La ventana de inscripción del período
-- ----------------------------------------------------------------------------

alter table public.academic_periods
  add column if not exists inscripcion_inicio date,
  add column if not exists inscripcion_fin    date;

comment on column public.academic_periods.inscripcion_inicio is
  'Primer día en que el estudiante puede inscribirse en este período. NULL = sin restricción de apertura.';
comment on column public.academic_periods.inscripcion_fin is
  'Último día (inclusive) para inscribirse. NULL = sin fecha límite. Es lo que la landing y «Mis inscripciones» enseñan como «Inscripciones cerradas».';

-- Una ventana invertida es un error de tecleo, no una decisión: si empieza
-- después de terminar, no hay ningún día en que se pueda inscribir y el
-- estudiante vería «cerradas» para siempre sin que nadie sepa por qué.
alter table public.academic_periods
  drop constraint if exists periodos_ventana_inscripcion_coherente;
alter table public.academic_periods
  add constraint periodos_ventana_inscripcion_coherente
  check (
    inscripcion_inicio is null
    or inscripcion_fin is null
    or inscripcion_inicio <= inscripcion_fin
  );

-- Las columnas nuevas se escriben por el mismo camino que las demás: la tabla ya
-- tiene `grant select, insert, update` a `authenticated`, así que no hace falta
-- un grant por columna. Se deja escrito para que nadie lo "arregle" añadiéndolo.

-- ----------------------------------------------------------------------------
--  2. ¿Está cerrado este período?
-- ----------------------------------------------------------------------------
--
-- `security definer` por una razón concreta: la función se usa desde triggers de
-- tablas cuyos escritores pueden no tener política de lectura sobre
-- `academic_periods` (el caso del service role en un job de barrido). Sin
-- `definer`, el trigger no vería la fila y **dejaría pasar la escritura** — un
-- guardián que se abre cuando no puede leer.
--
-- No se concede EXECUTE a nadie: la llaman los triggers, y un trigger ejecuta su
-- función como el dueño. Exponerla como RPC no aporta nada (ver D27: una función
-- concedida de más es un oráculo).

create or replace function public.periodo_cerrado(p_code text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select p.closed_at is not null
       from public.academic_periods p
      where p.code = p_code),
    -- Un código que no existe no se bloquea aquí: la FK de `sections` y de
    -- `teacher_duties` ya impide crearlo, y bloquearlo daría un error confuso
    -- («está cerrado») para un problema distinto («no existe»).
    false
  );
$$;

comment on function public.periodo_cerrado(text) is
  'TRUE si el período tiene closed_at. Lo usan los triggers de congelación; no es un oráculo de existencia.';

-- ----------------------------------------------------------------------------
--  3. Congelación: nada nuevo dentro de un período cerrado
-- ----------------------------------------------------------------------------
--
-- Tres tablas, un solo guardián. `schedule_slots` no guarda el período (lo
-- implica la sección), así que ahí se resuelve con una lectura por `section_id`;
-- es una fila por inserción y el índice de la PK la hace trivial.
--
-- **Sólo INSERT.** Editar o archivar lo que ya existe sigue permitido: cerrar
-- congela la creación, no secuestra el historial. Y mover una clase de sección
-- dentro del mismo período cerrado no crea nada nuevo.

create or replace function public.exigir_periodo_no_cerrado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
begin
  if tg_table_name = 'schedule_slots' then
    select s.period_code into v_code
      from public.sections s
     where s.id = new.section_id;
  else
    v_code := new.period_code;
  end if;

  if v_code is not null and public.periodo_cerrado(v_code) then
    raise exception
      'El período % está cerrado: no admite grupos, clases ni guardias nuevos.',
      v_code
      using
        errcode = '23514',
        hint = 'Reabre el período desde «Período» o trabaja en el período vigente.';
  end if;

  return new;
end;
$$;

comment on function public.exigir_periodo_no_cerrado() is
  'Congela la creación de grupos, clases y guardias en un período cerrado. Cerrar es congelar, no borrar.';

drop trigger if exists tr_sections_periodo_abierto on public.sections;
create trigger tr_sections_periodo_abierto
before insert on public.sections
for each row execute function public.exigir_periodo_no_cerrado();

drop trigger if exists tr_slots_periodo_abierto on public.schedule_slots;
create trigger tr_slots_periodo_abierto
before insert on public.schedule_slots
for each row execute function public.exigir_periodo_no_cerrado();

drop trigger if exists tr_duties_periodo_abierto on public.teacher_duties;
create trigger tr_duties_periodo_abierto
before insert on public.teacher_duties
for each row execute function public.exigir_periodo_no_cerrado();

-- ----------------------------------------------------------------------------
--  4. Estado de inscripción, calculado en la base
-- ----------------------------------------------------------------------------
--
-- La landing y «Mis inscripciones» necesitan responder «¿puedo inscribirme
-- todavía?» sin replicar la regla de fechas en Dart. Se expone como función
-- `stable` y se lee por PostgREST con el cliente del llamante: no expone nada
-- que la fila del período no exponga ya (las fechas son públicas a propósito,
-- es información para el aspirante).
--
-- `security invoker` a propósito: sólo lee columnas que `anon` ya puede leer.

create or replace function public.estado_inscripcion(p_code text)
returns text
language sql
stable
set search_path = public
as $$
  select case
    when p.closed_at is not null then 'CERRADO'
    when p.inscripcion_inicio is null and p.inscripcion_fin is null then 'ABIERTO'
    when p.inscripcion_inicio is not null and current_date < p.inscripcion_inicio then 'PROXIMO'
    when p.inscripcion_fin is not null and current_date > p.inscripcion_fin then 'VENCIDO'
    else 'ABIERTO'
  end
  from public.academic_periods p
  where p.code = p_code;
$$;

comment on function public.estado_inscripcion(text) is
  'ABIERTO | PROXIMO | VENCIDO | CERRADO para la ventana de inscripción de un período. Sin ventana cargada, ABIERTO.';

-- ----------------------------------------------------------------------------
--  5. La ventana se aplica al estudiante, no al administrador
-- ----------------------------------------------------------------------------
--
-- Se reemplaza `solicitar_inscripcion` (la RPC que usa el estudiante para
-- inscribirse a sí misma) añadiendo **una sola** comprobación al principio.
--
-- **Por qué aquí y no en la API.** Es una regla de calendario que se decide con
-- datos de la base (la sección → su período → su ventana). Ponerla en la ruta
-- costaría un viaje de red más en cada solicitud y dejaría la puerta abierta a
-- cualquiera que llame a la RPC directamente con la clave publishable, que viaja
-- al cliente (ADR-003).
--
-- **Por qué no en `reincorporar_inscripcion`.** Porque ahí el que actúa es el
-- administrador y puede tener una razón legítima para admitir a alguien fuera de
-- plazo. La ventana ordena la inscripción pública; no secuestra la decisión de
-- la dirección del centro.
--
-- El resto del cuerpo es **idéntico** al de `202609190001_mod4_inscripciones.sql`.
-- Se copia entero porque `create or replace` no permite parchear: o se reescribe
-- la función completa, o no se toca. Cualquier cambio futuro en la lógica de
-- cupos tiene que hacerse aquí a partir de esta versión.

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
  v_periodo   text;
  v_ini       date;
  v_fin       date;
  v_cerrado   timestamptz;
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

  -- --- LA VENTANA DE INSCRIPCIÓN (nuevo) -----------------------------------
  --
  -- Tres motivos distintos, tres mensajes distintos. «No puedes inscribirte» a
  -- secas obliga al estudiante a adivinar si el problema es suyo o del centro, y
  -- es exactamente la duda que el propietario planteó: «no saben cuándo empieza
  -- un curso si ya cerraron las inscripciones».
  select p.code, p.inscripcion_inicio, p.inscripcion_fin, p.closed_at
    into v_periodo, v_ini, v_fin, v_cerrado
  from public.sections s
  join public.academic_periods p on p.code = s.period_code
  where s.id = p_section_id;

  if v_cerrado is not null then
    raise exception
      'El período % está cerrado: ya no admite inscripciones.', v_periodo
      using errcode = '23514',
            hint = 'Consulta en la portada cuándo abre el próximo período.';
  end if;

  if v_ini is not null and current_date < v_ini then
    raise exception
      'Las inscripciones del período % abren el %.', v_periodo, to_char(v_ini, 'DD/MM/YYYY')
      using errcode = '23514';
  end if;

  if v_fin is not null and current_date > v_fin then
    raise exception
      'Las inscripciones del período % cerraron el %.', v_periodo, to_char(v_fin, 'DD/MM/YYYY')
      using errcode = '23514',
            hint = 'La próxima apertura se anuncia en la portada del centro.';
  end if;
  -- -------------------------------------------------------------------------

  -- ¿Ya existe fila para (estudiante, sección)? El `unique` la protege, pero un
  -- error crudo de unicidad no explica la salida. Un DROPPED es historial: para
  -- volver hay una RPC de administración, no una reinscripción libre.
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

  -- Cerrojo por sección: serializa la decisión de cupo.
  perform pg_advisory_xact_lock(hashtext('inscripcion|' || p_section_id::text));

  -- Decisión 3 y 5: con hueco, directo a ENROLLED (los bids sólo actúan al
  -- liberarse un cupo, no en la solicitud inicial); sin hueco, a la cola.
  if public.cupos_ocupados(p_section_id) < public.cupo_efectivo(p_section_id) then
    v_nuevo := 'ENROLLED';
  else
    v_nuevo := 'WAITLISTED';
  end if;

  -- La regla anti-acaparamiento (decisión 6) la aplica el trigger, no esta
  -- función: una sola fuente de verdad para cada invariante.
  insert into public.enrollments (student_id, section_id, status)
  values (v_actor, p_section_id, v_nuevo);

  return v_nuevo;
end;
$$;

comment on function public.solicitar_inscripcion(uuid) is
  'Inscribe al llamante en una sección: ENROLLED si hay cupo, WAITLISTED si no. Rechaza fuera de la ventana de inscripción del período (202610290001).';
