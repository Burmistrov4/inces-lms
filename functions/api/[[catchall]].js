// Cloudflare Pages Function: /api/[[catchall]]
// Proxy inverso transparente desde Cloudflare Pages hacia el backend Fastify en Render.
// Conecta todas las rutas de administración, horarios, módulos y usuarios con cero errores de CORS.

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

  const backendHost = env.RENDER_BACKEND_URL || 'https://inces-lms-api.onrender.com';
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
