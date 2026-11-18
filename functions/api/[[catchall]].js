// Cloudflare Pages Function: /api/[[catchall]]
// Proxy inverso desde Cloudflare Pages hacia el backend Fastify.
//
// **Histórico operativo, no se despliega.** El bundle de producción se publica
// con `wrangler pages deploy build/web` (subida directa), que **no incluye**
// esta carpeta; y desde el 2026-10-31 la web compila con `API_BASE_URL`
// apuntando a Vercel, así que ni siquiera se usa el mismo origen. Se conserva
// corregido para que nadie reactive un proxy hacia un servicio retirado.
//
// Backend vigente: Vercel (`https://inces-lms-api.vercel.app`). Render se retiró
// al agotar sus 750 h/mes.

export async function onRequest(context) {
  const { request, params, env } = context;
  const path = Array.isArray(params.catchall)
      ? params.catchall.join('/')
      : (params.catchall || '');
  const url = new URL(request.url);

  // Preflight CORS (OPTIONS)
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey, x-client-info',
      },
    });
  }

  const backendHost = env.BACKEND_URL || 'https://inces-lms-api.vercel.app';
  const targetUrl = `${backendHost}/api/${path}${url.search}`;

  const headers = new Headers(request.headers);
  headers.set('host', new URL(backendHost).host);

  try {
    const fetchOptions = {
      method: request.method,
      headers,
      redirect: 'follow',
    };

    if (request.method !== 'GET' && request.method !== 'HEAD') {
      fetchOptions.body = await request.arrayBuffer();
    }

    const response = await fetch(targetUrl, fetchOptions);
    const newHeaders = new Headers(response.headers);
    newHeaders.set('Access-Control-Allow-Origin', '*');
    newHeaders.set('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
    newHeaders.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, apikey, x-client-info');

    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers: newHeaders,
    });
  } catch (err) {
    return new Response(
      JSON.stringify({
        error: {
          codigo: 'ERROR_PROXY_BACKEND',
          mensaje: 'El backend de Render está iniciando o no respondió a tiempo.',
          detalle: err.message,
        },
      }),
      {
        status: 502,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  }
}
