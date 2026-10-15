// Cloudflare Pages Function: /api/v1/auth/registro-aspirante
// Alta de aspirantes en el Edge con confirmación inmediata (inmune a fallos de SMTP o rate-limits de email).

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
    const { email, password, metadata } = body || {};

    if (!email || !password) {
      return new Response(
        JSON.stringify({
          exito: false,
          codigo: 'DATOS_INVALIDOS',
          mensaje: 'El correo y la contraseña son requeridos para la inscripción.',
        }),
        { status: 400, headers: corsHeaders }
      );
    }

    const supabaseUrl = context.env?.SUPABASE_URL || 'https://twdppwnxlnmxkiejbrei.supabase.co';
    const serviceRoleKey = context.env?.SUPABASE_SERVICE_ROLE_KEY;

    if (!serviceRoleKey) {
      return new Response(
        JSON.stringify({
          exito: false,
          codigo: 'ERROR_CONFIGURACION',
          mensaje: 'Falta la variable SUPABASE_SERVICE_ROLE_KEY en el entorno de Cloudflare Pages.',
        }),
        { status: 500, headers: corsHeaders }
      );
    }

    const resp = await fetch(`${supabaseUrl}/auth/v1/admin/users`, {
      method: 'POST',
      headers: {
        'apikey': serviceRoleKey,
        'Authorization': `Bearer ${serviceRoleKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: email.trim().toLowerCase(),
        password: password,
        email_confirm: true,
        user_metadata: {
          ...(metadata || {}),
          rol: 'estudiante',
        },
      }),
    });

    const data = await resp.json();

    if (!resp.ok) {
      const msg = data?.msg || data?.message || data?.error_description || 'Error al procesar inscripción';
      if (/already|duplicat/i.test(msg)) {
        return new Response(
          JSON.stringify({
            exito: false,
            codigo: 'CORREO_YA_REGISTRADO',
            mensaje: 'Ese correo ya tiene una cuenta registrada en el sistema.',
          }),
          { status: 409, headers: corsHeaders }
        );
      }
      return new Response(
        JSON.stringify({
          exito: false,
          codigo: 'ERROR_ADMIN',
          mensaje: msg,
        }),
        { status: resp.status, headers: corsHeaders }
      );
    }

    return new Response(
      JSON.stringify({
        exito: true,
        userId: data.id,
        mensaje: 'Cuenta de aspirante creada y confirmada exitosamente.',
      }),
      { status: 200, headers: corsHeaders }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({
        exito: false,
        codigo: 'ERROR_INTERNO',
        mensaje: err?.message || 'Error interno al procesar registro en el Edge.',
      }),
      { status: 500, headers: corsHeaders }
    );
  }
}
