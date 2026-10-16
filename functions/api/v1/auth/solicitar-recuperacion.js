// Cloudflare Pages Function: /api/v1/auth/solicitar-recuperacion
export async function onRequestOptions() {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey',
    },
  });
}

export async function onRequestPost(context) {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey',
    'Content-Type': 'application/json',
  };

  try {
    const body = await context.request.json();
    const { identificador } = body || {};

    if (!identificador) {
      return new Response(
        JSON.stringify({
          exito: false,
          codigo: 'DATOS_INVALIDOS',
          mensaje: 'Se requiere cédula o correo electrónico.',
        }),
        { status: 400, headers: corsHeaders }
      );
    }

    const backendHost = context.env?.RENDER_BACKEND_URL || 'https://inces-lms-api.onrender.com';
    const targetUrl = `${backendHost}/api/v1/auth/solicitar-recuperacion`;

    const resp = await fetch(targetUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    const data = await resp.json().catch(() => ({}));
    if (resp.status === 404) {
      return new Response(
        JSON.stringify({
          exito: true,
          correoEnviado: false,
          metodo: 'supabase',
          mensaje: 'Solicitud de recuperación procesada. Si los datos coinciden con una cuenta registrada, recibirás el enlace o código de recuperación.',
        }),
        { status: 200, headers: corsHeaders }
      );
    }
    return new Response(JSON.stringify(data), {
      status: resp.status,
      headers: corsHeaders,
    });
  } catch (err) {
    return new Response(
      JSON.stringify({
        exito: false,
        codigo: 'ERROR_CONEXION_BACKEND',
        mensaje: 'No fue posible contactar al servicio de correo del INCES. ' + (err?.message || ''),
      }),
      { status: 502, headers: corsHeaders }
    );
  }
}
