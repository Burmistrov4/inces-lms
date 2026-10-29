-- ============================================================================
--  CICLO DE VIDA DEL PERÍODO — congelación real al cerrar
--  Fecha: 2026-10-29
--
--  POR QUÉ EXISTE
--
--  El propietario preguntó: «¿qué debería suceder cuando se cierra un período,
--  cómo afecta, y cómo lo gestiona un administrador?». La respuesta medida el
--  2026-10-29 era que cerrar sólo escribía `closed_at` y archivaba las
--  secciones: **se podía seguir creando clases, guardias y grupos dentro de un
--  período cerrado**, y `periodo_activo` seguía apuntándole. El candado de la
--  interfaz no cerraba nada por debajo.
--
--  QUÉ HACE
--
--   1. **Congela.** Un período cerrado no admite grupos, clases ni guardias
--      nuevos. Lo que ya existe sigue visible y consultable: cerrar es
--      congelar, no borrar. Reabrir (que ya existe) lo descongela.
--   2. **Aplica la ventana de inscripción del CURSO** al estudiante.
--
--  QUÉ **NO** HACE, Y ES DELIBERADO
--
--  · **No añade columnas de fechas.** La ventana de inscripción ya existe desde
--    `202610280001_ventana_inscripciones_programas.sql`, en `programs`
--    (`inscripcion_inicio`, `inscripcion_fin`, `proxima_apertura`), y ya está
--    cableada hasta la landing. Este archivo la **usa**; no crea una segunda.
--    (La primera versión de esta migración la duplicaba en `academic_periods`.
--    Se descartó: dos sitios que dicen cuándo se puede inscribir es exactamente
--    la redundancia que hay que evitar.)
--  · No archiva las aulas virtuales (decisión D8: no ocultar contenido docente).
--  · No borra inscripciones, notas ni asistencias. Son historial.
-- ============================================================================

-- ----------------------------------------------------------------------------
--  1. ¿Está cerrado este período?
-- ----------------------------------------------------------------------------
--
-- `security definer` por una razón concreta: la función se usa desde triggers de
-- tablas cuyos escritores pueden no tener política de lectura sobre
-- `academic_periods` (el caso del service role en un job de barrido). Sin
-- `definer`, el trigger no vería la fila y **dejaría pasar la escritura** — un
-- guardián que se abre cuando no puede leer.
--
-- No se concede EXECUTE a nadie: la llaman los triggers, y un trigger ejecuta su
-- función como el dueño. Exponerla como RPC no aporta nada (D27: una función
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
--  2. Congelación: nada nuevo dentro de un período cerrado
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
--  3. La ventana de inscripción del CURSO se aplica al estudiante
-- ----------------------------------------------------------------------------
--
-- Se reemplaza `solicitar_inscripcion` (la RPC que usa el estudiante para
-- inscribirse a sí misma) añadiendo **una sola** comprobación al principio.
--
-- **De dónde salen las fechas.** De `programs`, que es donde ya viven desde el
-- 2026-10-28. Se llega por `sections.program_id`, que es el curso al que
-- pertenece el grupo. No hay una segunda copia de la ventana: si el
-- administrador cambia la fecha en «Cursos y PNA», cambia aquí.
--
-- **Por qué aquí y no en la API.** Es una regla que se decide con datos de la
-- base (sección → programa → ventana, y sección → período → cerrado). Ponerla en
-- la ruta costaría un viaje de red más en cada solicitud y dejaría la puerta
-- abierta a quien llame a la RPC directamente con la clave publishable, que viaja
-- al cliente (ADR-003).
--
-- **Por qué no en `reincorporar_inscripcion`.** Ahí el que actúa es el
-- administrador y puede tener una razón legítima para admitir a alguien fuera de
-- plazo. La ventana ordena la inscripción pública; no secuestra la decisión de la
-- dirección del centro.
--
-- El resto del cuerpo es **idéntico** al de `202609190001_mod4_inscripciones.sql`.
-- Se copia entero porque `create or replace` no permite parchear: o se reescribe
-- la función completa, o no se toca.

create or replace function public.solicitar_inscripcion(p_section_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor     uuid := auth.uid();
  v_activa    boolean;
  v_programa  uuid;
  v_periodo   text;
  v_existente text;
  v_nuevo     text;
  v_ini       date;
  v_fin       date;
  v_prox      date;
  v_cerrado   timestamptz;
begin
  if v_actor is null then
    raise exception 'Se requiere una sesión para solicitar una inscripción.'
      using errcode = '42501';
  end if;

  select s.is_active, s.program_id, s.period_code
    into v_activa, v_programa, v_periodo
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

  -- --- La ventana de inscripción del curso (nuevo) --------------------------
  --
  -- Tres motivos distintos, tres mensajes distintos. «No puedes inscribirte» a
  -- secas obliga al estudiante a adivinar si el problema es suyo o del centro, y
  -- es exactamente la duda que planteó el propietario: «no saben cuándo empieza
  -- un curso si ya cerraron las inscripciones».
  select p.inscripcion_inicio, p.inscripcion_fin, p.proxima_apertura
    into v_ini, v_fin, v_prox
  from public.programs p
  where p.id = v_programa;

  select ap.closed_at into v_cerrado
  from public.academic_periods ap
  where ap.code = v_periodo;

  if v_cerrado is not null then
    raise exception
      'El período % está cerrado: ya no admite inscripciones.', v_periodo
      using errcode = '23514',
            hint = 'Consulta en la portada cuándo abre el próximo período.';
  end if;

  if v_ini is not null and current_date < v_ini then
    raise exception
      'Las inscripciones de este curso abren el %.', to_char(v_ini, 'DD/MM/YYYY')
      using errcode = '23514';
  end if;

  if v_fin is not null and current_date > v_fin then
    raise exception
      'Las inscripciones de este curso cerraron el %.', to_char(v_fin, 'DD/MM/YYYY')
      using errcode = '23514',
            hint = case
                     when v_prox is not null
                       then 'La próxima apertura es el ' || to_char(v_prox, 'DD/MM/YYYY') || '.'
                     else 'La próxima apertura se anuncia en la portada del centro.'
                   end;
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
  'Inscribe al llamante en una sección: ENROLLED si hay cupo, WAITLISTED si no. Rechaza fuera de la ventana de inscripción del CURSO y en período cerrado (202610290001).';
