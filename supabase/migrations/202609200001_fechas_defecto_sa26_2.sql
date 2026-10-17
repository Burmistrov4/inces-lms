-- 202609200001_fechas_defecto_sa26_2.sql
-- ---------------------------------------------------------------------------
-- Asignar fechas por defecto realistas al lapso vigente SA26-2 si están vacías,
-- garantizando coherencia temporal y evitando "Sin fechas cargadas".
-- ---------------------------------------------------------------------------

update public.academic_periods
set start_date = '2026-09-15',
    end_date = '2027-01-30'
where code = 'SA26-2' and (start_date is null or end_date is null);
