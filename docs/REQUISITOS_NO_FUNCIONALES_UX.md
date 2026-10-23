# REQUISITOS NO FUNCIONALES — UX, INTERACTIVIDAD Y RENDIMIENTO

> **Para qué existe.** Lorenzo pidió "investigar mejores terminos" para lo que
> describio como *"muy interactiva con el usuario"* y *"demasiado facil de usar"*.
> Este documento fija el vocabulario estandar (para poder exigirlo y medirlo) y
> los objetivos concretos de ESTE proyecto. Es un requisito no funcional, no un
> adorno: se mide como cualquier otro.

---

## 1. El vocabulario correcto (dejar de decir "interactiva" a secas)

| Termino correcto | Que significa | En esta app se ve como |
|---|---|---|
| **Usabilidad** (ISO/IEC 25010) | La capacidad de un producto de ser entendido, aprendido y usado con facilidad. | Un profesor mayor invita un docente sin leer un manual. |
| **Aprendibilidad** (*learnability*) | Cuanto tarda un usuario nuevo en hacer la tarea solo. | La primera invitacion de docente se completa sin ayuda. |
| **Operabilidad** (*operability*) | Cuanto control tiene el usuario sobre la app. | Poder cerrar la tarjeta informativa, volver atras, deshacer. |
| **Visibilidad del estado del sistema** (heuristica 1 de Nielsen) | El usuario siempre sabe que esta pasando. | "Subiendo… 40%", "Guardando…", nunca un boton que no responde. |
| **Retroalimentacion** (*system feedback*) | Confirmacion inmediata de que la accion se recibio. | El boton responde al toque en el acto, no 2 segundos despues. |
| **Affordance** (Norman) | La forma de un control sugiere su funcion. | Una lupa significa buscar; un "+", crear. |
| **Signifier** | La senal visible de donde actuar. | El icono, el color, el hover. |
| **Microinteraccion** | La respuesta pequena y con animacion a una accion. | El ripple de Material, el fade al cambiar de seccion. |
| **Descubribilidad** (*discoverability*) | Que las funciones se encuentren sin buscarlas. | Las acciones estan donde el usuario espera. |
| **Proteccion contra errores** | Evitar que el usuario se equivoque, y si lo hace, recuperarse. | Confirmacion antes de revocar una invitacion. |
| **Rendimiento percibido** | Cuanto rapida *se siente* la app, aunque no lo sea. | Skeletons, carga progresiva, *optimistic UI*. |
| **Optimistic UI** | Mostrar el resultado antes de confirmarlo con el servidor. | El archivo aparece en la lista mientras sube. |

**Frase correcta para el TEG:** "La app debe tener **alta usabilidad**
(aprendibilidad, operabilidad y proteccion contra errores, segun ISO/IEC 25010),
con **retroalimentacion inmediata del sistema** y **microinteracciones** segun
Material 3, y un **tiempo de respuesta** dentro de los limites de Nielsen."

---

## 2. Objetivos medibles de ESTE proyecto

### 2.1 Tiempos de respuesta (limites de Nielsen, 1993)

| Limite | Objetivo | Regla de diseno |
|---|---|---|
| **0,1 s** | Se siente instantaneo. | **Toda accion debe dar senal en <100 ms**: el ripple, el cambio de estado del boton, el foco del campo. Si no, el usuario cree que no lo toco. |
| **1 s** | Flujo sin interrupcion. | Navegar entre secciones debe sentirse continuo. La animacion de transicion (fade + escala) ya existe: **no alargarla**. |
| **10 s** | Limite de la atencion. | Si una operacion tarda mas, **mostrar progreso** con porcentaje o pasos ("Subiendo… 40%"). |

**Estado actual (medido 2026-10-22):** la transicion entre secciones es un
`FadeTransition` + `ScaleTransition` (0.97 -> 1) con `easeOutCubic`. Correcto.
**Pendiente de medir:** el tiempo real de respuesta del backend por endpoint
(hay un diagnostico en `docs/handover/REPORTE_CONTINUIDAD_2026-10-22.md` §3.2).

### 2.2 Nunca dejar una accion sin respuesta

Regla dura: **ningun boton, campo o gesto puede quedarse sin feedback**. Si la
accion es asincrona, el control pasa a estado ocupado **en el mismo frame** del
toque (no tras el `await`). Patron ya aplicado: `conGuardia` (anti doble-clic) y
`_ocupado`/`_cargando` en los paneles.

### 2.3 Errores que se entienden y de los que se sale

- El mensaje dice **que paso, por que y que hacer**: "No pudimos conectar con el
  servidor. Verifica tu conexion a internet e intentalo de nuevo." (ya existe).
- **Siempre hay salida**: boton de reintentar, estado vacio con accion, nunca
  una pantalla en blanco ni un spinner infinito.

### 2.4 Rendimiento backend/frontend

| Frente | Objetivo | Como se mide |
|---|---|---|
| Front | Primera carga util rapida; navegacion entre secciones sin recargar. | La app es una SPA Flutter: cambiar de seccion **no** debe golpear la red. |
| Back | Respuestas por debajo del limite de atencion. | Diagnostico de red por endpoint (ver §2.1). |
| Red | **Paralelizar lecturas independientes.** El coste de una ruta autenticada son viajes de red: 2 viajes en serie = ~421 ms fijos + ~190 ms por consulta. | Regla ya anotada en la memoria del proyecto. |

---

## 3. Como se verifica (para que no sea papel mojado)

1. **La matriz responsive** (`e2e/tests/matriz_responsive.spec.ts`) mide
   desbordes, page errors y navegabilidad en 186 capturas. Es el banco de pruebas
   del responsive.
2. **La sonda de red** mide tiempos y fallos por endpoint.
3. **Revision de capturas**: una captura fea es un defecto (criterio de Lorenzo).
4. **Lista de control por panel nuevo** (aplicar siempre):
   - [ ] Todo control da feedback en <100 ms.
   - [ ] Toda operacion >1 s muestra progreso.
   - [ ] Todo error tiene mensaje accionable y salida.
   - [ ] Todo estado vacio explica que hacer.
   - [ ] Funciona en los 6 perfiles (390/600/840/844/1280/1700).
   - [ ] Se entiende sin explicacion (probarlo con ojos de profesor mayor).

---

## 4. Lo que NO es negociable (resumen para el TEG)

1. **Usabilidad alta** (ISO 25010): aprendibilidad, operabilidad, proteccion
   contra errores.
2. **Retroalimentacion inmediata** en cada accion (limite de 0,1 s de Nielsen).
3. **Progreso visible** en toda espera (limite de 1 s / 10 s).
4. **Responsive real** como Material 3 (ya medido en la matriz).
5. **Rendimiento**: lecturas independientes en paralelo; navegacion sin recargar.
6. **Español** en toda la UI y la documentacion.
