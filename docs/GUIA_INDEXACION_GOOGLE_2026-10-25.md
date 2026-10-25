# Cómo aparecer en Google — INCES LMS

**Estado medido el 2026-10-25.** Buscar «inces lms» en Google y en Bing no
devuelve el sitio. Antes de tocar nada hay que separar dos problemas que se
confunden todo el tiempo:

1. **Que Google no sepa que el sitio existe** → se arregla indexando.
2. **Que Google no pueda leer el sitio** → se arregla con contenido en el HTML.

El segundo es el grave en este proyecto, y no se arregla con metaetiquetas.

---

## El problema de fondo: Flutter Web pinta en un canvas

La landing es una app Flutter compilada a JavaScript. El texto que ve el usuario
se dibuja en un `<canvas>`, no en el DOM. Para Google, la página es
prácticamente un lienzo en blanco: puede ejecutar el JavaScript, pero **no
extrae el texto del canvas como contenido indexable**.

Lo que sí lee Google es el HTML de `web/index.html`. Hoy ese archivo tiene:

| Pieza | Estado |
|---|---|
| `<title>` y `description` | ✅ presentes y bien escritos |
| Open Graph y Twitter Card | ✅ |
| JSON-LD `EducationalOrganization` + 5 `Course` | ✅ |
| JSON-LD `WebSite` + `SearchAction` | ✅ añadido el 2026-10-25 |
| `robots.txt` con política inversa | ✅ corregido el 2026-10-24 |
| `sitemap.xml` | ✅ |
| `canonical` | ✅ |
| **Texto visible en el HTML** | ⚠️ **sólo en `#seo-static-content`, oculto con `left:-9999px`** |

**Sobre ese texto oculto:** Google lo ignora o, peor, lo trata como *cloaking*
si no coincide con lo que ve el usuario. Aquí coincide (es un resumen real de la
landing), así que no hay riesgo de penalización, pero **tampoco aporta mucho**:
un bloque escondido a 9999 px no compite por posiciones.

---

## Lo que hay que hacer, en orden

### 1. Verificar el dominio en Google Search Console (lo hace Lorenzo, 5 minutos)

Sin esto no hay indexación ni diagnóstico. Es el paso que desbloquea todo lo demás.

1. Entrar a <https://search.google.com/search-console>.
2. **Añadir propiedad** → tipo **Prefijo de URL** → `https://inces-lms.pages.dev/`.
3. Verificar por **etiqueta HTML**: Google da una línea como
   `<meta name="google-site-verification" content="ABC123...">`.
4. Pegarla en `web/index.html`, dentro del `<head>`, y desplegar.
5. Volver a Search Console y pulsar **Verificar**.

> **Por qué por etiqueta y no por archivo:** el método «archivo HTML» exige
> subir un `googleXXXX.html` a la raíz, y `flutter build web` copia `web/`
> entero, así que también funcionaría. La etiqueta es más simple porque vive en
> el mismo `index.html` que ya se edita.

### 2. Enviar el sitemap

En Search Console → **Sitemaps** → añadir `sitemap.xml`. Tarda entre horas y
semanas. Es lo que le dice a Google «estas son las páginas que quiero que
indexes».

### 3. Pedir la indexación de la portada

Search Console → **Inspección de URL** → pegar `https://inces-lms.pages.dev/` →
**Solicitar indexación**. Fuerza una revisión en lugar de esperar al rastreo
periódico.

### 4. Contenido real en el HTML (lo que de verdad mueve la aguja)

Esto es trabajo de código, y es la única forma de competir por posiciones. Tres
opciones, de menor a mayor esfuerzo:

**a) Mover el bloque `#seo-static-content` a visible.** En vez de esconderlo a
9999 px, ponerlo como sección al final de la landing, con estilo sobrio. El texto
ya está escrito y es bueno. Requiere que Flutter deje hueco para él (un `div`
antes del `<script>` de arranque, con altura propia).

**b) Prerenderizar.** Generar un `index.html` estático con el HTML real de la
landing para los rastreadores. Exige un paso de build (puppeteer sobre el sitio
compilado) y es la opción que más se acerca a «aparecer primero».

**c) Página de aterrizaje separada en HTML puro.** Una `/inicio.html` sin
Flutter, con el contenido completo, enlazada desde la portada. Es lo que hacen
muchos sitios con front en SPA: el marketing en HTML, la app en canvas. Es la
opción más barata y la que recomendaría si hay prisa por el TEG.

### 5. Lo que NO se puede prometer

**Nadie puede garantizar «aparecer de primero».** Google ordena por relevancia,
autoridad y comportamiento de los usuarios, y esos tres factores no se
programan. Lo que sí se puede hacer es:

- Que el sitio **esté indexado** (pasos 1-3).
- Que el HTML **diga claramente qué es** (JSON-LD, title, description — ya está).
- Que **alguien enlace al sitio**: el `README` del repositorio, el perfil de
  GitHub, la página del INCES si se puede. Sin enlaces entrantes, un dominio
  nuevo tarda meses en posicionar.

**Expectativa honesta:** con los pasos 1-3, el sitio aparecerá al buscar
«INCES LMS» y «INCES La Isabelica» en unas semanas. Para «inces cfs isabelica
aula virtual» —lo que Lorenzo buscó en la captura— competir requiere contenido
visible y enlaces, porque hoy Google ni sabe que la página habla de eso.

---

## Lo que ya está hecho en el código

- `robots.txt`: `Allow: /$` + `Disallow: /` + assets. Antes decía `Allow: /` y
  enumeraba a mano las rutas privadas, que falla por omisión.
- `theme-color` unificado (había dos y el navegador usaba el viejo).
- JSON-LD `WebSite` con `SearchAction` y `publisher` apuntando a la
  organización, para que Google asocie el dominio con la institución.
- `sitemap.xml` y `canonical` ya existían y son correctos.

## Lo que depende de Lorenzo

| # | Tarea | Tiempo |
|---|---|---|
| 1 | Verificar el dominio en Search Console | 5 min |
| 2 | Enviar el sitemap | 1 min |
| 3 | Solicitar indexación de la portada | 1 min |
| 4 | Enlazar el sitio desde el README de GitHub y el perfil del proyecto | 10 min |

Con eso el sitio entra en el índice. Para posicionar de verdad hace falta el
paso 4 de la sección anterior, que es trabajo de código y merece su propia
sesión.
