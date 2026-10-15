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

    const supabaseUrl = context.env?.SUPABASE_URL || 'https://twdppwnxlnmxkiejbrei.supabase.co';
    const serviceRoleKey = context.env?.SUPABASE_SERVICE_ROLE_KEY;

    // Determinar correo si es cédula
    let emailDestino = identificador.trim().toLowerCase();
    if (!emailDestino.includes('@') && serviceRoleKey) {
      const respPerfil = await fetch(
        `${supabaseUrl}/rest/v1/profiles?select=email&cedula=eq.${encodeURIComponent(identificador.trim())}`,
        {
          headers: {
            'apikey': serviceRoleKey,
            'Authorization': `Bearer ${serviceRoleKey}`,
          },
        }
      );
      if (respPerfil.ok) {
        const perfiles = await respPerfil.json();
        if (perfiles && perfiles.length > 0 && perfiles[0].email) {
          emailDestino = perfiles[0].email;
        }
      }
    }

    return new Response(
      JSON.stringify({
        exito: true,
        correoEnviado: false,
        metodo: 'supabase',
        email: emailDestino.includes('@') ? emailDestino : undefined,
        mensaje: 'Se despachará la recuperación por Supabase Auth.',
      }),
      { status: 200, headers: corsHeaders }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({
        exito: false,
        codigo: 'ERROR_INTERNO',
        mensaje: err?.message || 'Error en Edge recovery.',
      }),
      { status: 500, headers: corsHeaders }
    );
  }
}
