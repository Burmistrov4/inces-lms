# Análisis del segundo video — 2026-10-25 18:25

**Archivo:** `2026-10-25 18-25-31.mp4` · 15:59 · 1152×720 · versión 1.3.2
**Método:** 96 fotogramas cada 10 s y **audio transcrito** con Vosk.
Errores de reconocimiento: «pene a» = **PNA**, «metepec» = **MTP**, «laxas» =
**lapsos**, «draghi» = **Drive**, «catorce y siete» = **14-17**.

Este video **profundiza** el anterior. Los temas grandes coinciden —el cuadrante,
el PNA separado, las fechas de disponibilidad— pero aquí aparecen **siete
problemas nuevos**, y dos de ellos son los más graves que he visto hoy.

---

## Los dos hallazgos nuevos que más pesan

### N1 · La lista de usuarios está rota por paginación — **CORREGIDO HOY**

> «por cada página se mantiene un solo usuario […] voy a página siguiente y el
> profesor […] aparece nada más uno y otro me aparece en [otra página] […] es
> algo tan simple como listar una lista de usuarios registrados y **no funciona
> bien**. El colmo» (10:11 – 11:15)

**Medido y confirmado.** No era impresión: era un bug real.

| Dato | Valor |
|---|---|
| Perfiles en producción | **72** |
| Con dominio `@semilla.invalid` | **61** |
| Usuarios reales | **11** |
| Página 1 (límite 25) | 8 reales |
| **Página 2** | **0 reales** |
| Página 3 | 3 reales |

**La causa:** el panel ocultaba las cuentas de siembra **en el cliente, después
de paginar**. El servidor paginaba 72 perfiles (61 sembrados) y el cliente
escondía lo sembrado de cada página. Resultado: páginas casi vacías y un contador
que decía «de 72» cuando en realidad hay 11 personas.

**El arreglo:** el filtro pasa al servidor. Como `contarUsuarios` reutiliza la
misma consulta que la página, filtrar ahí arregla **las dos mitades** —el total y
las filas— de una vez. Verificado contra la base: el total baja de 72 a 11 y la
página 1 trae los 11.

También se corrigió que el chip «Ocultar pruebas» sólo hacía `setState` sin
recargar: con el filtro en el servidor, cambiarlo sin volver a pedir dejaba la
lista anterior en pantalla.

### N2 · El cuadrante es inutilizable en el teléfono — **ALTO, PENDIENTE**

> «no se puede ver todo […] la parte técnica responsive […] la experiencia de los
> usuarios **se ve mermada al punto de que es inutilizable desde el teléfono** […]
> hay que usar la computadora […] la aplicación debería tener como **un deslice**»
> (01:01 – 01:40)

Y da la medida exacta:

> «la pantalla se muestra un width de **393 por 852**» (03:45)

**393 × 852 es un iPhone 15.** En ese ancho el cuadrante no cabe y no hay forma
de verlo: no hay scroll horizontal, no hay vista alternativa. La matriz de
responsividad pasa porque **no desborda**, pero «no desbordar» y «ser usable» no
son lo mismo. Es el ejemplo perfecto de por qué la matriz a cero no basta.

**Lo que hace falta:** una vista de cuadrante para móvil que no sea el mismo
grid encogido. El propio Lorenzo propone «un deslice».

---

## Los otros hallazgos nuevos

### N3 · Herencia de horario al archivar un lapso — **ALTO, PENDIENTE**

> «si se conservan lapsos, supone que se archiva uno automáticamente cuando
> termina […] y se pueda editar en cualquier momento el nombre del [lapso] […]
> **que el horario herede el horario anterior del archivado**» (00:38 – 01:01)

Al cerrar un lapso y abrir el siguiente, el horario debería **copiarse solo**.
Hoy hay que rehacerlo desde cero cada período, que es el trabajo más tedioso del
panel.

### N4 · Facilitador suplente — **MEDIO, PENDIENTE**

> «de escritorio se puede añadir al profesor, añadir en este caso **un facilitador
> suplente** a veces de un profesor» (01:52)

Falta poder asignar un suplente a un bloque, además del titular.

### N5 · Rol elegible al invitar — **MEDIO, PENDIENTE**

> «cuando uno manda un enlace, **uno selecciona si se manda como profesor o como
> administrador** […] evita la necesidad de estar cambiando el rol después»
> (05:33 – 06:01)

**Verificado:** el panel de invitaciones **no tiene selector de rol**. Obliga a
invitar como docente y luego cambiar el rol a mano, que es el doble de pasos y un
error esperando a pasar.

### N6 · No se puede borrar una invitación — **MEDIO, PENDIENTE**

> «**no hay un botón para eliminar** este registro porque de repente tengo […] no
> quiere mostrar porque ya se hizo» (07:02)

**Verificado:** no existe acción de borrado en `cpanel_invitaciones_panel.dart`.

### N7 · Aviso de correo enviado poco visible — **BAJO, PENDIENTE**

> «debe aparecer aquí un mensaje de **correo enviado** un poquito más grande […]
> que diga **revisa en la carpeta de spam**» (09:17 – 09:42)

### N8 · Los filtros tapan el contenido — **MEDIO, PENDIENTE**

> «**no te dejan ocultar ciertas cosas** […] ocupa mucho espacio […] **casi ni se
> ve, tapa prácticamente todo y está ocultando lo que uno quiere ver**» (11:30 – 12:14)

Los filtros del cuadrante y de guardias ocupan tanto que dejan sin espacio al
contenido, y no se pueden plegar.

### N9 · Logo del INCES pequeño — **BAJO, PENDIENTE**

> «debe ser un poco más grande […] **el logo oficial no aparece aquí**» (15:30 – 15:50)

---

## Lo que coincide con el primer video

| Tema | Video 1 | Video 2 |
|---|---|---|
| Filtro del cuadrante roto | ✅ (04:04) | ✅ (00:06, 03:06) — «el de guardias está más decente» |
| MTP ≠ PNA | ✅ (01:17) | ✅ (02:12–03:06) — «aquí PNA, aquí MTP que son los roles de guardia» |
| Cuadrante y guardias casi iguales | — | ✅ (12:38) — «muy muy similar, prácticamente igual» |
| PNA como programa aparte | ✅ (07:03) | ✅ (12:46–13:39) — «totalmente separado» |
| Fechas de disponibilidad por curso | ✅ (14:10) | ✅ (15:10) — «que aparezca si está disponible y si no, cuándo» |
| Login con cédula | — | ✅ (05:08) — **ya corregido hoy** |
| Horario debe mostrar curso y docente | ✅ (07:10) | ✅ (02:27) — «profesor asignado y materia asignada» |

**Dos videos de 16 minutos coincidiendo en los mismos siete temas no es
casualidad: son el núcleo del problema.**

---

## Lo que se corrigió hoy

| # | Qué | Estado |
|---|---|---|
| N1 | Paginación de usuarios (72 → 11) | ✅ servidor + test de regresión |
| — | Chip «Ocultar pruebas» recarga | ✅ |
| — | Login con cédula para admin y docente | ✅ migración aplicada |
| — | PNA 14-18 en los cuatro sitios | ✅ migración aplicada |
| — | «[SEMILLA]» fuera de los nombres | ✅ migración aplicada |

## Lo que queda, por orden

**Sesión 1 — el cuadrante (N2, filtro, nombre del curso)**
Es lo que más duele y lo que más se repite en los dos videos. Incluye la vista
móvil, que es el único hallazgo que hace el sistema **inutilizable** para un rol
completo de usuarios.

**Sesión 2 — MTP y PNA separados, con sus fechas (V6, V7, V8, V9)**
Los dos videos insisten. Requiere migración de esquema.

**Sesión 3 — invitaciones (N5, N6, N7)**
Rol elegible, borrado y aviso. Son tres cambios acotados y de bajo riesgo.

**Sesión 4 — horarios (N3, N4, N8, N9)**
Herencia al archivar, suplente, filtros plegables, logo.

**Nota sobre N2:** la matriz responsiva da 0 desbordes en los seis perfiles y aun
así el cuadrante es inusable a 393 px. **Ese contraste es una lección**: «no
desborda» no significa «se puede usar». Habría que añadir a la matriz una
comprobación de *legibilidad mínima* (¿cuántas columnas quedan visibles?), no sólo
de desborde.
