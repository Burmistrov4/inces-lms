# 04 — PLAN MAESTRO DELEGABLE (qué ejecuta el siguiente agente)

> **Este es el documento de trabajo.** Es la síntesis de `01` (hecho), `02`
> (pendiente) y `03` (planes). Contiene paquetes de trabajo ordenados por impacto y
> dependencias, cada uno con alcance, archivos a tocar, criterios de aceptación y
> cómo verificar. Diseñado para que **otro agente de IA** lo retome sin contexto
> previo y sepa exactamente por dónde empezar.
>
> Regla del proyecto: **medir antes de afirmar**. Cada cierre se anota en
> `ESTADO_DEL_SISTEMA.md` el mismo día, y en `docs/BACKLOG_PENDIENTES.md` si aplica.

---

## 0. Cómo verificar en este equipo (obligatorio leer)

`flutter test` / `flutter build web` **no arrancan** en la máquina local (tuberías
nombradas / `ERROR_PIPE_BUSY`, y el proxy del sandbox rompe el health check de
Playwright). **CI es el verificador.** Comandos locales válidos:

```bash
# Frontend (análisis estático,等同 a flutter analyze pero sin subproceso hijo)
node devops/analizar-dart.mjs            # 249 archivos · 0/0/0 esperado

# Backend
cd backend && npm run verify             # 728/728 esperado
cd backend && npm run typecheck
cd backend && npm run openapi            # regenera openapi.json (D6)

# Esquema en la nube (fuera del repo, contra Supabase)
node supabase/apply-migrations.mjs --check
node supabase/verificar-esquema.mjs      # OJO: 5 expectativas obsoletas (ver P0.1)

# E2E (Playwright) — requiere backend en 3001 + NO_PROXY
NO_PROXY=localhost,127.0.0.1 playwright test        # en e2e/
```

> Si una prueba local muere con `CreateFile failed 231` / `ERROR_PIPE_BUSY`, **no es
> el proyecto: es el sandbox**. Sube el cambio y deja que CI lo confirme.

---

## P0 — Quick wins de visibilidad (empezar aquí, ~horas)

### P0.1 · `verificar-esquema.mjs` con expectativas obsoletas
- **Qué:** el verificador espera `habilitar_sistema_bids` (borrado por
  `202610260001`), `password_resets`/`planilla_observaciones`/`planilla_versiones`,
  otro recuento de cursos libres, otros límites M5 y otro estado de módulos.
- **Archivo:** `supabase/verificar-esquema.mjs`.
- **Aceptación:** el script corre sin rojos por expectativas muertas; un rojo suyo
  significa deriva real de la base.
- **Fuente:** `ESTADO_DEL_SISTEMA.md:45` · `02_PENDIENTES_Y_ERRORES.md:B4`.

### P0.2 · Estabilizar las 6 specs E2E en rojo
- **Qué:** `live_prod_v124` (espera «v1.2.4» → actualizar a versión vigente),
  `admin_cpanel_p0` (nombre viejo → «Cursos y PNA»), `export_csv` (flaky de login →
  estabilizar), `aula_virtual` («una tarjeta por sección»), `auditoria_completa_sistema`
  (2), `refresco_al_volver`.
- **Archivos:** `e2e/tests/*.spec.ts`, `e2e/src/pages/*`.
- **Aceptación:** las 6 dejan de estar en rojo (o se documenta por qué son
  intencionales). Son deuda de pruebas, **no del producto**.
- **Fuente:** `02:B1`.

---

## P1 — Defectos de UX de video (ALTA prioridad, objetivo primordial)

> Reproducir en navegador real a 390 px y con el flujo del usuario **antes** de dar
> por cerrado. Varios fueron marcados "cerrados" en el backlog y el usuario los
> volvió a señalar en video.

### P1.1 · Cuadrante usable en móvil + filtro por día
- **Alcance:** `N2` (inutilizable en teléfono) y `V4` (no filtra por día en el
  cuadrante dentro de `CpanelProgramasPanel`). El `SelectorDeDias` existe en
  Horarios/Guardias; extenderlo al cuadrante de programas.
- **Archivos:** `lib/screens/admin/cpanel_programas_panel.dart`,
  `lib/widgets/selector_de_dias.dart` (si existe), `CuadranteGrid`.
- **Aceptación:** a 390 px el cuadrante se lee sin scroll Horizontal innecesario y
  filtra por día. Verificar con la matriz E2E responsive.

### P1.2 · Cupo por sección (no global)
- **Alcance:** `T2` — el cupo máximo es global y debería ser **por sección**.
- **Decisión requerida (Lorenzo):** modelo de cupo en `sections` vs global.
- **Archivos:** esquema M4 (`enrollments`/`sections`), `ResumenCurso`,
  `CpanelProgramasPanel`.
- **Aceptación:** cada sección muestra su cupo propio; el global (si queda) no
  pisa al por-sección.

### P1.3 · «Próxima apertura» + semáforo de inscripción (arranca Fase 4)
- **Alcance:** `V9`, `C5` — en «Cursos y PNA» avisar cuándo abre la próxima
  inscripción y pintar semáforo abierta/cerrada en los 3 dashboards.
- **Datos:** `academic_periods` (ventana `inscripcion_inicio`/`fin`).
- **Aceptación:** la tarjeta de curso muestra «Próxima apertura: <fecha>» y el
  semáforo es coherente con el estado del período vigente.

### P1.4 · Encadenamiento de bloques + herencia de horario
- **Alcance:** `V5` (los bloques no se recalculan solos: 9:15+45m→10:00) y `N3`
  (al cerrar un lapso, copiar el horario al siguiente).
- **Archivos:** lógica de cuadrante / generación de bloques, cierre de período.
- **Aceptación:** los bloques no se solapan; al cerrar un período el horario se
  hereda y no se rehace desde cero.

### P1.5 · PNA como un programa + cursos PNA en cuadrante
- **Alcance:** `V7` (PNA = un programa con materias y fechas) y `V10` (cursos PNA
  con nombre y docente en el cuadrante).
- **Aceptación:** el cuadrante de `CpanelProgramasPanel` lista cursos PNA con
  nombre y docente; MTP y PNA se ven separados (`V6`).

---

## P2 — Fase 4 (Landing por curso) + Fase 5 (borrar panel huérfano)

### P2.1 · Fase 4 — Landing por curso
- **Alcance:** tarjeta de curso con cupos ocupados/disponibles, ventana de
  inscripción y «próxima apertura»; agrupar cuadrante/PNA **por curso**.
- **Depende de:** P1.3 (datos de ventana) y de la decisión "uno o varios grupos por
  curso y período" (Lorenzo).
- **Archivos:** `cpanel_programas_panel.dart`, modelo `ResumenCurso`, gateway/servicio.
- **Aceptación:** ver `docs/PLAN_SIMPLIFICACION_SECCIONES_2026-10-29.md` (Fase 4).

### P2.2 · Fase 5 — Borrar `CpanelSeccionesPanel`
- **Alcance:** una vez que crear/editar/archivar sección viva en la tarjeta del
  curso (P2.1), **borrar** `lib/screens/admin/cpanel_secciones_panel.dart` y su
  prueba. Hoy es inalcanzable (R-22) y no se puede crear sección desde la UI.
- **Aceptación:** `menu_alcanzable_test.dart` sigue en verde; `grep -rn
  "CpanelSeccionesPanel"` da 0; se puede crear una sección desde la interfaz.
- **Fuente:** `ESTADO_DEL_SISTEMA.md:123` · `BACKLOG_PENDIENTES.md:C10`.

---

## P3 — Deuda técnica y funcional media

- **P3.1 Responsive de detalle:** `A4` (diálogos 390 px), `A5` (texto 200 %),
  `A6` (DPR 2–3), `B2r` (ratio panel lateral gestor), `B3r`
  (`cabeDoblePanelLadoALado` sin consumidores), `B4r` (rejillas landing).
- **P3.2 Deuda `LayoutBuilder` (15/143):** migrar al patrón híbrido
  tarjetas(<900)/tabla(≥900) de `cpanel_usuarios_roles_panel.dart`.
- **P3.3 Guardia anti doble-clic:** usar `conGuardia` en todo botón que abra diálogo
  o mute estado.
- **P3.4 `admin_dashboard.dart:242`:** quitar `SA26-2` hardcodeado de la cabecera.
- **P3.5 Paginación/select mínimo:** `AspiranteGateway.todos()` y `miFicha()`
  (`PLAN_CIERRE_100_FUNCIONAL_2026.md:1074`).
- **P3.6 `trustProxy` + vistas sin `security_invoker`:** medir contra producción.
- **P3.7 Funcional:** `C2` (docx/xlsx/pdf desde gestor), `C3` (Drive auto-título),
  `C4` (reedición planilla rechazada), `C7` (asistente virtual), `B9` (expediente
  del aprendiz), `B10/B11` (D17 lista de campos, D7 opciones/editables).
- **P3.8 Cierres F-series:** `F-PLN` (comparación visual planilla), `F-R2` (prueba
  UI alumno R2), `F-ASIS` (cierre físico/dispositivo QR).

---

## P4 — Bloqueados por humano / credenciales (escalar solo lo independiente)

- **P4.1 H1 SMTP real** (🔒 Lorenzo carga `SMTP_USER`+`SMTP_PASS` en Render). Sin
  eso no sale correo; `F1.1` recuperación de contraseña queda DEFERIDA.
- **P4.2 Región Render + `SUPABASE_JWT_SECRET`** (🔒 propietario) — palancas de
  velocidad.
- **P4.3 Verificación navegador** de «Invitar docente» y promoción de administradores
  (🔒 falta cuenta de prueba autorizada).
- **P4.4 M7 cámara QR en dispositivo físico** (🔒 sin dispositivo en pruebas).
- **P4.5 Módulo 8 Pasantías** (OFF): diseñar flujo y E2E antes de habilitar
  (`PLAN_CIERRE_100_FUNCIONAL_2026.md:59`).

---

## Qué NO tocar (para no romper lo verde)

- **Migraciones ya aplicadas** — nunca editarlas; nuevas con `YYYYMMDDNNN_*.sql`.
- **`flutter analyze` / `flutter test` localmente** — no corre en el sandbox; usar
  `analizar-dart.mjs` + CI.
- **La frontera de autorización es la RLS**, no la API. Cualquier política RLS que
  llame a una función con `EXECUTE` revocado es inalcanzable (`42501`).
- **`ESTADO_DEL_SISTEMA.md` gana al código**; actualízalo el mismo día que cierras.

## Secrets / variables que necesita el próximo agente
- `SUPABASE_URL`, `SUPABASE_ANON_KEY` (ya en CI/`.env`).
- `SMTP_USER`, `SMTP_PASS` (🔒 Lorenzo, para correo real).
- `SUPABASE_JWT_SECRET` (🔒 para verificar JWT en local, palanca de velocidad).
- 6 secretos del barrido diario de R2 (D9) — ver `docs/CONFIGURACION_R2.md`.

## Handoff
1. Lee `docs/MAESTRO/00_INDICE_MAESTRO.md` → `01` → `02` → `03` → este `04`.
2. Empieza por **P0** (visibilidad) y luego **P1** (impacto de UX alto).
3. Cada cierre: confírmalo con los comandos de la sección 0, anótalo en
   `ESTADO_DEL_SISTEMA.md` y (si aplica) en `BACKLOG_PENDIENTES.md`.
4. Si una decisión requiere a Lorenzo (P1.2, P2.1 agrupación, Campus/Aula Virtual,
   periodos con duración), **pregunta antes de implementar** — no la inventes.
5. El push es el respaldo; confirma con CI (Flutter/Backend/Supabase) antes de dar
   por bueno un cambio de Flutter/Dart.
