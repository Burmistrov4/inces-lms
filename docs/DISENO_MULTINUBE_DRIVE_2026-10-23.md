# DISEÑO — Multi-nube con Google Drive (F1 → F2 → F3)

> **Para qué existe.** Lorenzo me pidió seguir mejorando la app «acorde a los
> planes». La Fase D del plan (`docs/PLAN_DE_TRABAJO_2026-10-23.md`) es la única
> que queda, y su primer paso es **documento de diseño y decisión de Lorenzo**
> antes de escribir código. Este documento es ese paso: estado medido, opciones
> con consecuencias y una recomendación. **Nada de esto está implementado.**

---

## 1. Estado real (medido el 2026-10-23, no supuesto)

| Pieza | Estado | Dónde |
|---|---|---|
| **Gestor documental propio** | **Ya existe.** Subida suelta de archivos, tipo `DRIVE_FILE`, guardado en R2 | `backend/src/http/rutas/archivos.ts`, migración `202610202001_drive_file_subida_suelta.sql` |
| **Límite de subida** | **10 MB** (`TAMANO_MAXIMO_BYTES = 10 * 1024 * 1024`) | `backend/src/dominio/almacenamiento.ts:51` |
| **¿El límite es configurable?** | **Sí**, por el parámetro `m5_max_bytes` | `backend/src/http/rutas/archivos.ts:58` |
| **Explorador de archivos** | Ya existe, con papelera y barrido diario | `lib/screens/admin/cpanel_explorador_archivos_panel.dart` |
| **Login con Google** | **No existe.** El login es por correo/contraseña (Supabase Auth) | — |
| **Integración con Google Drive** | **No existe.** No hay ni una línea de código de Drive | — |

**Conclusión importante:** el sistema **ya tiene su propio «Drive»** (el gestor
documental sobre R2). La Fase D no es «añadir un Drive», es **conectar el de
Google** al que ya tenemos. Eso cambia el planteamiento: Drive sería una **nube
más**, no un reemplazo.

---

## 2. El problema que se quiere resolver

R2 en el plan gratuito de Cloudflare da **10 GB de almacenamiento** y **1 millón
de peticiones de lectura al mes**. Para un CFS con aulas virtuales, entregas de
estudiantes y guías del docente, eso se acaba. Cuando se acaba, las subidas
empiezan a fallar.

**La restricción de fondo** (de `USER.md`): el sistema debe poder operar 24/7 en
capas gratuitas **y** correr en un servidor local como respaldo, porque hay
cortes eléctricos. Google Drive da **15 GB gratis** por cuenta institucional.

---

## 3. Opciones

### Opción A — Drive como **espejo** (la del plan original)

- El usuario puede **vincular su cuenta de Google** (OAuth) y, opcionalmente,
  subir archivos a su Drive en vez de a R2.
- R2 sigue siendo el almacén principal; Drive es una **salida de emergencia**
  cuando R2 se llena o el archivo no cabe.

**A favor:** no se toca lo que ya funciona; R2 no se agota tan rápido.
**En contra:** dos códigos de subida, dos permisos, dos formas de listar. El
usuario tiene que entender dónde quedó su archivo.

### Opción B — Drive como **único** almacén de los archivos grandes

- Los archivos **por debajo del límite** van a R2 (rápido, ya funciona).
- Los que **lo superan** se rechazan con un mensaje que ofrece **subirlos a Drive**
  con un clic, y el sistema guarda sólo el **enlace**.

**A favor:** resuelve el problema del límite sin duplicar la lógica; el coste de
R2 only baja; el flujo es «si no cabe, te doy la alternativa».
**En contra:** el archivo vive fuera del sistema: si el usuario borra su Drive,
el enlace muere.

### Opción C — No integrar Drive; subir el límite y rotar R2

- Subir `m5_max_bytes` y, si R2 se llena, migrar a otro bucket o a un plan pago.

**A favor:** cero código nuevo.
**En contra:** no escala; vuelve al problema en unos meses.

---

## 4. Recomendación

**B primero, A después, C descartada.**

1. **B (F2) es la que resuelve un dolor real y cotidiano**: hoy un archivo de más
   de 10 MB **se rechaza sin alternativa**. Ofrecer Drive en ese momento exacto
   es ayuda, no una función que haya que ir a buscar.
2. **A (F1) sólo si la vinculación de cuentas se usa para algo más** que subir
   archivos (por ejemplo, avisos por Calendar). Si no, es complejidad sin
   beneficio.
3. **C se descarta**: no escala y el plan gratuito es una restricción real del
   proyecto.

**Orden sugerido:** F2 → F3 → F1. F2 primero porque es el que el usuario
necesita ya; F1 al final porque es el más invasivo (toca el login, que hoy
funciona).

---

## 5. Lo que hace falta decidir (para Lorenzo)

1. **¿B, A, ambos o ninguno?** (recomiendo B)
2. **¿Qué cuenta de Drive?** La del centro (una sola, institucional) o la de cada
   usuario. La del centro es más simple y evita que un estudiante borre sus
   archivos; la de cada usuario da 15 GB por persona.
3. **¿Se permite el enlace muerto?** Si el archivo vive en el Drive del usuario y
   él lo borra, el enlace del sistema queda roto. ¿Se avisa, o se asume?
4. **F3 (visores dentro de la app)**: ¿hace falta, o basta con abrir el enlace en
   una pestaña nueva? Abrir en pestaña nueva es cero código y cero riesgo.

---

## 6. Riesgos que hay que mirar antes de escribir código

- **OAuth de Google** exige una pantalla de consentimiento verificada si se pide
  acceso a datos de terceros. Para una app de un centro de formación es
  razonable, pero **hay que crear el proyecto en Google Cloud Console** y eso es
  trámite, no código.
- **El backend en Render** tendría que guardar tokens de refresco de Drive:
  otra cosa que custodiar.
- **La regla de RLS** (`docs` de arquitectura): la frontera de autorización es la
  base. Un enlace a Drive **no pasa por RLS**, así que habría que decidir quién
  puede verlo y guardarlo con la misma disciplina que los archivos.

---

*Este documento no autoriza nada. Cuando Lorenzo decida, se implementa por fases
con verificación (analizador + matriz) en cada una, como el resto del trabajo.*
