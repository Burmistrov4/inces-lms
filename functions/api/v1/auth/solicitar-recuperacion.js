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

    // Si el backend no pudo entregar vía SMTP directo (o dio fallback),
    // aseguramos el despacho inmediato vía Supabase Auth desde el Edge.
    const emailDestino = (data && data.email) || (identificador.includes('@') ? identificador : null);
    if ((!data || !data.correoEnviado) && emailDestino) {
      try {
        const supabaseUrl = context.env?.SUPABASE_URL || 'https://twdppwnxlnmxkiejbrei.supabase.co';
        const anonKey = context.env?.SUPABASE_ANON_KEY || 'sb_publishable_3nmupQBjT0gKZ_FKD8vFkg_eMdnWgmk';
        const resRecov = await fetch(`${supabaseUrl}/auth/v1/recover`, {
          method: 'POST',
          headers: {
            apikey: anonKey,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            email: emailDestino,
            redirect_to: 'https://inces-lms.pages.dev/#/restablecer-codigo',
          }),
        });

        if (resRecov.ok) {
          return new Response(
            JSON.stringify({
              exito: true,
              correoEnviado: true,
              metodo: 'supabase',
              email: emailDestino,
              mensaje: 'Hemos enviado un enlace de recuperación seguro a tu correo electrónico.',
            }),
            { status: 200, headers: corsHeaders }
          );
        }
      } catch (_) {}
    }

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
