import fs from 'fs';

function cargarEnv(archivo) {
  if (!fs.existsSync(archivo)) return {};
  const lineas = fs.readFileSync(archivo, 'utf8').split('\n');
  const env = {};
  for (const l of lineas) {
    const lim = l.trim();
    if (!lim || lim.startsWith('#')) continue;
    const idx = lim.indexOf('=');
    if (idx !== -1) {
      const k = lim.substring(0, idx).trim();
      const v = lim.substring(idx + 1).trim().replace(/^['"]|['"]$/g, '');
      env[k] = v;
    }
  }
  return env;
}

const env = {
  ...process.env,
  ...cargarEnv('backend/.env'),
  ...cargarEnv('.env.e2e'),
  ...cargarEnv('.env'),
};


async function verificar() {
  const url = env.SUPABASE_URL;
  const key = env.SUPABASE_SERVICE_ROLE_KEY || env.SUPABASE_ANON_KEY;
  console.log('=== VERIFICACIÓN DE BASE DE DATOS SUPABASE ===');
  console.log('URL Supabase:', url);

  const tables = [
    'profiles',
    'academic_periods',
    'programs',
    'subjects',
    'program_subjects',
    'sections',
    'classrooms',
    'enrollments',
    'aspirantes',
    'system_settings',
    'inscripcion_campos',
  ];

  for (const t of tables) {
    try {
      const res = await fetch(`${url}/rest/v1/${t}?select=count`, {
        headers: {
          'apikey': key,
          'Authorization': `Bearer ${key}`,
          'Range': '0-0',
          'Prefer': 'count=exact'
        }
      });
      const cr = res.headers.get('content-range');
      console.log(`Tabla [${t}]: status ${res.status}, conteo registros: ${cr || 'N/A'}`);
    } catch (e) {
      console.error(`Tabla [${t}] error:`, e.message);
    }
  }

  try {
    const resProfiles = await fetch(`${url}/rest/v1/profiles?select=rol,active`, {
      headers: {
        'apikey': key,
        'Authorization': `Bearer ${key}`
      }
    });
    const profiles = await resProfiles.json();
    const roles = {};
    let activos = 0;
    for (const p of profiles) {
      roles[p.rol] = (roles[p.rol] || 0) + 1;
      if (p.active) activos++;
    }
    console.log(`\nDistribución de Roles (${profiles.length} total, ${activos} activos):`, roles);
  } catch (e) {
    console.error('Error obteniendo perfiles:', e.message);
  }

  try {
    const resAspirantes = await fetch(`${url}/rest/v1/aspirantes?select=*&limit=1`, {
      headers: {
        'apikey': key,
        'Authorization': `Bearer ${key}`
      }
    });
    const aspirantes = await resAspirantes.json();
    if (Array.isArray(aspirantes) && aspirantes.length > 0) {
      console.log('Columnas de aspirantes:', Object.keys(aspirantes[0]));
      console.log('Ejemplo aspirante estado/status:', aspirantes[0].estado || aspirantes[0].status || 'sin columna estado');
    } else {
      console.log('Respuesta aspirantes:', aspirantes);
    }
  } catch (e) {
    console.error('Error obteniendo aspirantes:', e.message);
  }

  try {
    const resUsers = await fetch(`${url}/rest/v1/profiles?select=id,email,nombres,apellidos,rol,active&limit=100`, {
      headers: {
        'apikey': key,
        'Authorization': `Bearer ${key}`
      }
    });
    const allUsers = await resUsers.json();
    const realUsers = allUsers.filter(u => !u.email.endsWith('@semilla.invalid'));
    console.log('\nUsuarios reales registrados (no-semilla):', realUsers.length);
    for (const u of realUsers) {
      console.log(`- [${u.rol}] ${u.email} : ${u.nombres || ''} ${u.apellidos || ''}`);
    }
  } catch (e) {
    console.error('Error obteniendo usuarios de muestra:', e.message);
  }

  console.log('\n=== VERIFICACIÓN DE ENDPOINTS CLOUDFLARE PAGES EDGE ===');
  try {
    const cfSalud = await fetch('https://inces-lms.pages.dev/salud');
    console.log('/salud status:', cfSalud.status, await cfSalud.text());
  } catch (e) {
    console.error('/salud error:', e.message);
  }

  try {
    const cfCampos = await fetch('https://inces-lms.pages.dev/api/v1/inscripcion/campos');
    const data = await cfCampos.json();
    console.log('/api/v1/inscripcion/campos status:', cfCampos.status, 'total campos:', Array.isArray(data.campos) ? data.campos.length : 'N/A');
  } catch (e) {
    console.error('/api/v1/inscripcion/campos error:', e.message);
  }

  try {
    const cfProxy = await fetch('https://inces-lms.pages.dev/api/v1/admin/usuarios', {
      headers: {
        'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`
      }
    });
    console.log('/api/v1/admin/usuarios (Reverse Proxy a Render) status:', cfProxy.status, 'Content-Type:', cfProxy.headers.get('content-type'));
    const body = await cfProxy.json();
    console.log('Usuarios retornados vía proxy:', Array.isArray(body) ? body.length : (body.usuarios?.length || Object.keys(body)));
  } catch (e) {
    console.error('Proxy a Render error:', e.message);
  }

  console.log('\n=== VERIFICACIÓN DE SERVIDOR FASTIFY RENDER DIRECTO ===');
  try {
    const renderSalud = await fetch('https://inces-lms-api.onrender.com/salud');
    console.log('Render /salud status:', renderSalud.status, await renderSalud.text());
  } catch (e) {
    console.error('Render /salud error:', e.message);
  }
}

verificar();
