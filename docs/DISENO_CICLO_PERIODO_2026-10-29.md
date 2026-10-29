# Ciclo de vida del período — qué pasa, qué debería pasar y cómo se gestiona

**Fecha:** 2026-10-29 · **Estado:** diseño + lo ya implementado · **Decide:** Lorenzo

> Nace de una pregunta legítima del propietario: «no sé qué debería suceder cuando
> se cierra un período, cómo afecta y cómo lo gestiona un administrador sin
> equivocarse». La primera parte está **medida** en producción; la segunda es la
> propuesta, y marca lo que falta.

---

## 1. Qué es un período hoy

Una fila de `academic_periods`: `code` (`SA26-2`), `name`, `start_date`,
`end_date`, `is_active`, `closed_at`. Es el **marco temporal** de todo:

- `sections.period_code` dice a qué período pertenece cada grupo.
- `system_settings.periodo_activo` dice cuál está **vigente** (el que el sistema
  usa por defecto en cuadrante, horarios y aula).
- Inscripciones, asistencia y calificaciones cuelgan de la sección, y la sección
  del período.

Dos conceptos que se confunden y no son lo mismo:

| | Qué significa | Quién lo cambia |
|---|---|---|
| **Activo** (`is_active`) | «está abierto, se puede planificar en él» | la lista de períodos |
| **Vigente** (`periodo_activo`) | «es el que el sistema considera en curso» | botón «Hacer vigente» |

Puede haber varios activos y **sólo uno vigente**: así se prepara el siguiente
mientras el actual se sigue dictando.

## 2. Qué pasa **hoy** al cerrar (medido el 2026-10-29 en producción)

| Efecto | ¿Ocurre? |
|---|---|
| `closed_at` se escribe | **Sí** |
| `is_active` pasa a `false` | **Sí** |
| Sus secciones activas se archivan (`archived_at`) | **Sí** (trigger `tr_archivar_secciones_de_periodo`) |
| Las aulas virtuales se archivan | **No**, a propósito (decisión D8: no ocultar contenido docente) |
| Las inscripciones se borran o cambian | **No** (se conservan; es historial) |
| `periodo_activo` se limpia o cambia | **No** — y aquí estaba el hueco |
| Se impide crear horarios nuevos en ese período | **No** |

**El hueco:** se podía cerrar el período **vigente** y `periodo_activo` seguía
apuntándole. El cuadrante, los horarios y el aula continuaban tomándolo por
defecto aunque el centro ya no lo estuviera dictando. Desde el 2026-10-29 el
diálogo lo avisa en rojo antes de confirmar, pero **no lo impide**.

## 3. Qué debería pasar (propuesta)

Cerrar un período = **congelarlo**, no borrarlo:

1. **Nada nuevo dentro.** No se crean clases, ni guardias, ni inscripciones, ni
   sesiones de asistencia en un período cerrado. El backend lo rechaza con un
   mensaje claro («El período SA26-2 está cerrado. Elige el vigente.»).
2. **Lo que existe sigue visible.** Horarios, notas, asistencias e inscripciones
   se consultan en modo lectura, desde «Historial de períodos».
3. **El vigente no se puede cerrar sin sucesor.** O se bloquea, o se pide
   declarar otro antes; en ningún caso queda el sistema sin período en curso de
   forma silenciosa.
4. **Las secciones se archivan** (ya ocurre) y **dejan de aparecer** en los
   desplegables de trabajo, pero siguen en el historial.
5. **Al estudiante se le dice la verdad:** «Inscripciones cerradas. La próxima
   apertura es el dd/mm» — usando la ventana del programa
   (`inscripcion_inicio/fin/proxima_apertura`, ya en la base).
6. **Heredar el horario** al crear el siguiente (ya existe
   `heredar_horario_periodo`, hay que exponerlo en el formulario).

## 4. Cómo lo gestiona un administrador (3 pasos, sin ambigüedad)

| Cuándo | Qué hace | Dónde | Qué ve |
|---|---|---|---|
| **Antes** de que acabe el período | «Registrar período» del siguiente, con sus fechas y **heredando el horario** | Período → Registrar | Aparece como **activo**, no vigente, listo para planificar |
| **El día que empieza** | «Hacer vigente» el nuevo | Período → fila → Hacer vigente | El cuadrante y las aulas pasan a ese período |
| **Cuando termina el anterior** | «Cerrar período» | Período → candado | Se archiva, sus secciones se archivan, queda en «Historial» |

Regla de oro para el administrador: **nunca cerrar el vigente antes de declarar
el siguiente**. La interfaz debe decirlo, y hoy ya lo advierte.

## 5. Lo que faltaba para que esto sea cierto — **estado al 2026-10-29 (v1.7.0)**

| # | Pieza | Estado |
|---|---|---|
| 1 | **Bloquear escrituras en período cerrado** | **HECHO** · migración `202610290001`: trigger `exigir_periodo_no_cerrado` en `sections`, `schedule_slots` y `teacher_duties`. Sólo INSERT: editar lo existente sigue permitido. |
| 2 | **Exigir sucesor** al cerrar el vigente | **HECHO** · `409 PERIODO_VIGENTE_SIN_SUCESOR`; `forzar: true` cierra y **suelta `periodo_activo`**. El diálogo ofrece «Cerrar y activar el siguiente». |
| 3 | **Ventana de inscripción aplicada** | **HECHO** · la RPC `solicitar_inscripcion` lee `programs.inscripcion_inicio/fin/proxima_apertura` y rechaza con mensaje que dice cuándo. La ventana ya existía (2026-10-28); **no se duplicó**. |
| 4 | **Exponer «heredar horario»** | **HECHO** desde 1.6.0 (interruptor en el formulario de alta). |
| 5 | **Historial legible** | **PARCIAL** · el período cerrado se lista con sus fechas y su estado, pero **no** abre un resumen con secciones/inscritos/notas. Es la pieza que falta. |

### Corrección a este documento

Decía que `programs.inscripcion_inicio/fin/proxima_apertura` «ya están en la
base». **Es cierto**, pero la primera versión de la migración de hoy lo puso en
duda y duplicó la ventana en `academic_periods`. La causa del error: un `grep`
que **murió por SIGTERM** se leyó como «cero resultados». La lección es la de
siempre —**un comando interrumpido no es una medición**— y el arreglo fue borrar
el duplicado antes de aplicarlo, no convivir con él.

## 6. Cómo se despliega esto (orden obligatorio)

La migración **ya está aplicada** (62 versiones, 0 pendientes, 0 deriva).

```bash
# 1. Comprobar (no debería quedar nada)
SUPABASE_ACCESS_TOKEN=... node supabase/apply-migrations.mjs --check

# 2. Publicar backend (push a main → Render redespliega)
git push origin main

# 3. Bundle y despliegue del frente
gh workflow run web_bundle.yml --ref main
gh run download <run-id> -n web-produccion -D build_web
npx wrangler pages deploy build_web --project-name=inces-lms \
  --commit-dirty=true --branch=main
```


