// Cloudflare Pages Function: /salud
export async function onRequestGet() {
  return new Response(
    JSON.stringify({
      estado: 'ok',
      servicio: 'inces-lms-edge',
      timestamp: new Date().toISOString(),
    }),
    {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    }
  );
}
