-- =============================================================================
--  Limpieza: cuatro parámetros que NO HACE NADA configurar
--
--  Medido el 2026-10-24, no deducido:
--
--  · Las funciones SQL que leen `system_settings` leen exactamente cuatro
--    claves: `periodo_activo`, `cupo_maximo_por_seccion`,
--    `habilitar_sistema_bids` y `bid_ttl_horas`.
--  · En `backend/src/` las cuatro claves de abajo aparecen sólo en comentarios.
--  · En `lib/` aparecen sólo en el filtro del panel y en un docstring.
--
--  Es decir: se pintaban como interruptores en «Configuración del Centro», el
--  administrador los cambiaba y **no pasaba nada**. Un control que no hace nada
--  es peor que no tenerlo, porque el usuario cree que configuró algo.
--
--  Se borran las filas. Si algún día se implementa lo que prometían —la
--  expulsión automática por faltas, por ejemplo—, su migración volverá a
--  sembrar la clave **junto con el código que la lee**, que es el orden
--  correcto: primero el lector, después el dato.
--
--  `modo_mantenimiento`, `periodo_activo`, `cupo_maximo_por_seccion`,
--  `habilitar_sistema_bids`, `bid_ttl_horas`, `m5_max_bytes` y
--  `m5_max_archivos_por_entidad` se quedan: ésas sí se leen.
-- =============================================================================

delete from public.system_settings
where clave in (
  'inscripciones_abiertas',    -- nadie la lee: el cierre de inscripciones lo decide el período
  'max_faltas_consecutivas',   -- prometía expulsión automática; esa lógica no existe
  'enrollment_lock_days',      -- nadie la lee
  'r2_presign_ttl_minutos'     -- el TTL real sale de config.ttlSubidaSegundos
);

-- Comprobación en la propia migración: si alguna de las cuatro siguiera ahí,
-- algo la recreó y esta limpieza no sirvió de nada.
do $$
declare
  quedan integer;
begin
  select count(*) into quedan
  from public.system_settings
  where clave in (
    'inscripciones_abiertas',
    'max_faltas_consecutivas',
    'enrollment_lock_days',
    'r2_presign_ttl_minutos'
  );

  if quedan <> 0 then
    raise exception 'Quedaron % parámetros sin efecto tras la limpieza', quedan;
  end if;
end
$$;

comment on table public.system_settings is
  'Configuración del centro. Sólo se siembran claves que alguna función SQL o '
  'algún camino del backend lea de verdad: un parámetro sin lector es un '
  'interruptor que miente al administrador.';
