# Contexto para otra IA — INCES LMS

> **Qué es esta carpeta.** Es un paquete de documentos escritos para una IA que
> **no tiene acceso** a este repositorio ni a sus archivos. Su objetivo es que
> entienda el proyecto entero —qué es, cómo está construido, en qué estado está,
> cómo se trabaja y qué trampas han costado caras— **sin necesidad de leerse los
> miles de archivos del repo**.
>
> **Fuente de verdad.** Este paquete se nutre de `ESTADO_DEL_SISTEMA.md` (el
> documento que manda cuando contradice a otro), de la memoria del proyecto
> (`.workbuddy-ai/memory/`), de los workflows de CI y del código medido el
> **2026-10-12**. Cada cifra lleva su fecha de medición. **Si una cifra de aquí
> contradice al código, gana el código**: este proyecto mide antes de afirmar, y
> un número sin comando que lo produzca es una nota, no un dato.
>
> ** Idioma de trabajo del proyecto: español.** Los comentarios, identificadores
> y mensajes al usuario están en español a propósito.

---

## Cómo leer este paquete

| Orden | Archivo | Para qué |
|---|---|---|
| 1 | `00_INDICE.md` | Este mapa. Empieza aquí. |
| 2 | `01_PROYECTO_Y_PRODUCTO.md` | Qué es el sistema, para quién, qué hace y qué **no** hace. |
| 3 | `02_ESTADO_ACTUAL.md` | Estado verificado hoy: qué funciona, qué está en producción, qué queda abierto. |
| 4 | `03_STACK_TECNOLOGICO.md` | Cada tecnología con su versión y el porqué de la decisión (ADRs). |
| 5 | `04_ARQUITECTURA.md` | Cómo encajan frontend, backend y base de datos; esquema, RLS, contrato de error. |
| 6 | `05_CICLO_DE_VIDA.md` | La vida de un cambio: del diagnóstico al despliegue, y las cinco redes de verificación. |
| 7 | `06_REGLAS_Y_LECCIONES.md` | Las reglas que sostienen el proyecto y las trampas medidas. **Léelo antes de tocar nada.** |
| 8 | `07_MAPA_Y_COMANDOS.md` | Mapa de archivos y los comandos exactos para verificar cada cosa. |
| 9 | `08_GLOSARIO.md` | D1–D29, R-xx, M0–M8, ADRs y vocabulario del proyecto. |

**Lectura mínima para poder trabajar sin romper nada:** `01` → `02` → `06` → `07`.
**Lectura completa recomendada:** las nueve, en orden.

---

## El proyecto en cinco líneas

- **LMS (plataforma educativa) para el CFS Nacional de Soldadura "Rafael Urdaneta"**
  del INCES, La Isabelica (Valencia, Venezuela). Es el **Trabajo Especial de
  Grado** de Lorenzo Roca y su equipo (IUTEPI, Análisis de Sistemas, 4º semestre).
- **Tres roles:** administrador (cPanel), docente y estudiante; más el aspirante
  en su registro previo. La autorización real vive en la base de datos
  (PostgreSQL + RLS), no en la API.
- **Stack:** Flutter Web + Fastify (Node/TypeScript) + Supabase (PostgreSQL) +
  Cloudflare R2. Cero Python. Producción en Render (API) y Cloudflare Pages
  (frontend); la base es Supabase en la nube.
- **Estado:** módulos 0–5, 6 (aula virtual) y 7 (asistencia QR) construidos,
  verificados y en producción; M8 (pasantías) y certificados fuera de alcance.
- **Filosofía:** cada afirmación se mide; un verde que no midió es peor que un
  rojo, porque tranquiliza.

## Cifras de cabecera (con fecha — ninguna es intemporal)

| Cifra | Valor | Medida |
|---|---|---|
| Migraciones en repo y en nube | **46 / 46**, 0 pendientes, 0 deriva | 2026-10-09 |
| Rutas API documentadas (OpenAPI 3.1) | **80 rutas · 89 operaciones · 125 esquemas** | 2026-10-12 (artefacto del repo) |
| Pruebas backend (vitest) | **675 / 675**, 32 archivos | 2026-10-09 |
| Aserciones SQL (PGlite) | **546**, 0 fallos | 2026-10-09 |
| Pruebas Flutter | **974**, todas en verde | 2026-10-09 |
| E2E (Playwright, navegador real) | **24 / 24** | 2026-10-09 |
| Análisis estático Dart (`analizar-dart.mjs`) | **223 archivos**, sin errores/avisos/infos | 2026-10-10 |
| Módulos sembrados | **11 filas, 8 encendidos** | 2026-10-09 |

> **Estas cifras envejecen solas.** El proyecto ha documentado cuatro veces la
> misma lección: un número escrito a mano se desincroniza. Antes de citar
> cualquiera, vuelve a medirla con el comando de `07_MAPA_Y_COMANDOS.md`.

## Las cinco reglas que no se negocian (resumen)

1. **Medir antes de afirmar.** «No está» se mide, no se deduce; «no se puede»
   también se mide.
2. **Nunca editar una migración ya aplicada.** Se añade otra que la corrija.
3. **La frontera de autorización es la RLS**, no la API (ADR-003).
4. **El push es el respaldo.** Dos ediciones al mismo archivo en un mismo
   mensaje: una se pierde.
5. **Puede haber otro agente editando los mismos documentos.** Releer justo
   antes de editar; ediciones aditivas y acotadas.

El detalle y el porqué de cada una están en `06_REGLAS_Y_LECCIONES.md`.
