// Suite E2E del SEO público: `/robots.txt`, `/sitemap.xml` y los metadatos de la
// portada.
//
// **Por qué existe.** El 2026-10-13 se midió en producción
// (`https://inces-lms.pages.dev`) que `/robots.txt` y `/sitemap.xml`
// devolvían **200 con `text/html` y 2775 bytes**: exactamente el `index.html`
// de la SPA. Cloudflare Pages, sin archivos estáticos con esos nombres, aplica
// el *fallback* a `index.html` a cualquier ruta. Un buscador que pide el
// robots.txt recibe la portada, y ningún rastreador recibe instrucciones
// reales: eso es lo que esta suite impide que vuelva a pasar desapercibido.
//
// **Qué mide que no mida otra prueba.** Son respuestas del **servidor
// estático**, no de la app: `flutter test` no ve HTTP, y el workflow
// `web_bundle.yml` sólo comprueba que los archivos existan dentro del bundle.
// Aquí se piden por HTTP como lo haría un rastreador y se comprueba el tipo de
// contenido y el cuerpo.
//
// **No necesita sesión.** Es la parte pública del sitio; se corre contra el
// servidor que Playwright levanta para la suite (el mismo `serve.mjs` que sirve
// `build/web`), que es exactamente el contenido que se publica.

import { expect, test } from '@playwright/test';

const BASE = process.env.E2E_BASE_URL ?? 'http://127.0.0.1:8090';

test.describe('SEO público', () => {
  test('robots.txt se sirve como texto y declara el sitemap', async ({ request }) => {
    const respuesta = await request.get(`${BASE}/robots.txt`);

    expect(respuesta.status()).toBe(200);

    // El tipo correcto es la mitad del arreglo: `text/html` significa que el
    // servidor está devolviendo la SPA, no el robots.
    const tipo = respuesta.headers()['content-type'] ?? '';
    expect(tipo).toContain('text/plain');

    const cuerpo = await respuesta.text();
    expect(cuerpo).toContain('User-agent:');
    expect(cuerpo).toContain('Sitemap: https://inces-lms.pages.dev/sitemap.xml');

    // Lo privado no se indexa. `Allow: /$` deja pasar sólo la portada.
    expect(cuerpo).toMatch(/Allow:\s*\/\$/);
    expect(cuerpo).toContain('Disallow: /');
  });

  test('sitemap.xml se sirve como XML y lista sólo la portada pública', async ({
    request,
  }) => {
    const respuesta = await request.get(`${BASE}/sitemap.xml`);

    expect(respuesta.status()).toBe(200);

    const tipo = respuesta.headers()['content-type'] ?? '';
    expect(tipo).toContain('xml');

    const cuerpo = await respuesta.text();
    expect(cuerpo).toContain('<urlset');
    expect(cuerpo).toContain('<loc>https://inces-lms.pages.dev/</loc>');

    // Ni una ruta autenticada en el sitemap: los paneles, aulas y datos de
    // estudiantes no son contenido indexable.
    expect(cuerpo).not.toContain('<loc>https://inces-lms.pages.dev/panel');
    expect(cuerpo).not.toContain('<loc>https://inces-lms.pages.dev/aula');
    expect(cuerpo).not.toContain('<loc>https://inces-lms.pages.dev/admin');
  });

  test('la portada lleva canonical, Open Graph e idioma español', async ({ request }) => {
    const respuesta = await request.get(`${BASE}/`);

    expect(respuesta.status()).toBe(200);

    const html = await respuesta.text();
    expect(html).toContain('<html lang="es">');
    expect(html).toContain('rel="canonical"');
    expect(html).toContain('og:title');
    expect(html).toContain('og:description');
    expect(html).toContain('<title>');
  });
});
