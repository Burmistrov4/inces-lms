-- Vínculo entre un archivo y un aula virtual.
--
-- **Qué resolvía.** El explorador de archivos guardaba el aula como una
-- **cadena del modelo en memoria** (`aulaVirtual: 'General CFS'`), no como una
-- relación. Elegir el aula en el diálogo cambiaba el texto de la pantalla y nada
-- más: al refrescar se perdía, y ningún módulo podía saber qué archivo pertenece
-- a qué aula. Medido el 2026-10-31.
--
-- **Por qué `section_id` y no el nombre.** El "aula virtual" es una fila de
-- `sections`: tiene período, materia y código de acceso. Guardar el nombre
-- obliga a buscarla por texto, y un renombrado deja vínculos huérfanos que nadie
-- puede detectar.
--
-- `on delete set null`: si algún día se borrara la sección (hoy no se puede: se
-- archiva), el archivo no desaparece con ella. El archivo es del centro; el
-- vínculo es lo prescindible.

alter table public.files_metadata
  add column if not exists section_id uuid
  references public.sections(id) on delete set null;

create index if not exists files_metadata_section_idx
  on public.files_metadata (section_id)
  where section_id is not null and deleted_at is null;

comment on column public.files_metadata.section_id is
  'Aula virtual a la que se vinculó el archivo. NULL = material general del '
  'centro. Es una relación y no un texto: el nombre de la sección puede cambiar.';
