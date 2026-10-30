-- F0.1 · El nombre del grupo deja de ser un código de 5 caracteres.
--
-- Por qué. `sections.name` era `varchar(5)` porque la sección era un
-- identificador interno («A», «B», «M1»). Desde D11 el grupo se crea desde el
-- cuadrante y el administrador escribe el nombre que quiere —«Soldadura Grupo
-- Prueba», «SOLD-B»—, y el límite le cortaba el texto sin explicación. Se
-- reportó dos veces (2026-10-29 y 2026-10-30) como «no me deja añadir más de 5
-- caracteres».
--
-- 24 caracteres alcanza para «SOLD-B», «GRUPO 1 ANALISTA», «MAÑANA SOLDADURA»,
-- sin llegar a convertir el campo en un título que después no cabe en el
-- cuadrante ni en la planilla.
--
-- Esto es ADITIVO: no borra datos, no renombra columnas. Sólo amplía el tipo.
-- Las filas existentes («SA», «PRUEB») siguen siendo válidas porque el índice
-- único `sections_identidad_unica (period_code, subject_id, name)` se
-- reconstruye solo, y su unicidad no cambia al ensanchar el tipo.
--
-- OJO — por qué se recrea la vista. La primera versión de esta migración falló
-- con `0A000: cannot alter type of a column used by a view or rule`, y el
-- detalle señalaba a `v_ocupacion_secciones`: la vista lee `sections.name`, así
-- que Postgres no deja cambiar el tipo mientras dependa de ella. Se elimina,
-- se cambia el tipo y se vuelve a crear **idéntica** (mismo SELECT, mismas
-- columnas calculadas) más los permisos de lectura.

-- 1. Las vistas que leen la columna se guardan y se rehacen en el bloque de
--    abajo (`do $$`). Postgres no deja cambiar el tipo mientras dependan de
--    ella, y transcribir a mano la definición de `v_exportacion_hacer` (60+
--    columnas) es pedir una errata en producción: se leen con
--    `pg_get_viewdef` y se recrean tal cual.

-- 2. El tipo se cambia dentro del bloque de abajo, entre el `drop` y el
--    `create`: es el único orden que Postgres acepta con vistas dependientes.

-- 3. El tipo y la restricción de nombre se cambian dentro del bloque de abajo,
--    entre el `drop` y el `create`: es el único orden que Postgres acepta con
--    vistas dependientes.

-- 4. Las tres vistas que leen `sections.name`, guardadas y rehechas tal cual.
--    Se hace en un bloque porque las definiciones se leen de la propia base:
--    copiarlas a mano es la forma más fácil de dejar una vista distinta.
do $migracion$
declare
  vistas text[] := array[
    'v_cuadrante_clases',
    'v_exportacion_hacer',
    'v_ocupacion_secciones'
  ];
  v_nombre text;
  v_def    text;
  guardadas text[] := '{}';
begin
  foreach v_nombre in array vistas loop
    begin
      v_def := pg_get_viewdef(format('public.%I', v_nombre)::regclass, true);
      guardadas := array_append(guardadas, v_def);
      execute format('drop view if exists public.%I', v_nombre);
    exception when undefined_table then
      -- La vista no existe en este entorno: no hay nada que guardar. Se
      -- mantiene el orden del arreglo con un marcador vacío.
      guardadas := array_append(guardadas, '');
    end;
  end loop;

  -- Con las vistas fuera, el tipo se puede cambiar.
  alter table public.sections
    alter column name type varchar(24);

  -- Un nombre vacío o de sólo espacios rompe el índice único de forma confusa:
  -- dos grupos «  » colisionan sin que se vea por qué. Se prohíbe en la base,
  -- que es donde no se puede saltar.
  alter table public.sections
    add constraint sections_nombre_no_vacio
    check (length(btrim(name)) between 1 and 24);

  for i in 1 .. array_length(vistas, 1) loop
    if guardadas[i] <> '' then
      execute format('create view public.%I as %s', vistas[i], guardadas[i]);
      execute format(
        'grant select on public.%I to authenticated', vistas[i]
      );
    end if;
  end loop;
end
$migracion$;

comment on column public.sections.name is
  'Etiqueta corta del grupo dentro de curso·materia·período («A», «SOLD-B»). '
  'Opcional para el administrador: si no la escribe, se usa «ÚNICA».';