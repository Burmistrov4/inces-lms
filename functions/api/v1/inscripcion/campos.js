// Cloudflare Pages Function: /api/v1/inscripcion/campos
// Sirve el catálogo de campos de inscripción desde Supabase PostgREST directamente en el Edge.

export async function onRequestOptions() {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey',
    },
  });
}

export async function onRequestGet(context) {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey',
    'Content-Type': 'application/json',
    'Cache-Control': 'public, max-age=300, stale-while-revalidate=60',
  };

  try {
    const supabaseUrl = context.env?.SUPABASE_URL || 'https://twdppwnxlnmxkiejbrei.supabase.co';
    const anonKey = context.env?.SUPABASE_ANON_KEY || 'sb_publishable_3nmupQBjT0gKZ_FKD8vFkg_eMdnWgmk';

    const url = `${supabaseUrl}/rest/v1/inscripcion_campos?select=codigo,etiqueta,grupo,tipo,obligatorio,orden,opciones,fuente,condicion,ayuda&activo=eq.true&order=orden.asc,codigo.asc`;

    const resp = await fetch(url, {
      method: 'GET',
      headers: {
        'apikey': anonKey,
        'Authorization': `Bearer ${anonKey}`,
        'Content-Type': 'application/json',
      },
    });

    if (!resp.ok) {
      const errText = await resp.text();
      return new Response(
        JSON.stringify({ campos: [], error: errText }),
        { status: resp.status, headers: corsHeaders }
      );
    }

    const campos = await resp.json();
    return new Response(
      JSON.stringify({ campos: Array.isArray(campos) ? campos : [] }),
      { status: 200, headers: corsHeaders }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ campos: [], error: err.message }),
      { status: 500, headers: corsHeaders }
    );
  }
}
