#!/usr/bin/env node
// Publica el bundle de producción en Cloudflare Pages.
//
// POR QUÉ EXISTE
// --------------
// El despliegue a Pages es manual (el workflow `web_bundle.yml` sólo compila y
// sube el artefacto). Este script junta los tres pasos en uno y, sobre todo,
// **verifica el artefacto antes de publicar**: si el bundle no trae la API de
// producción o contiene `localhost`, se detiene.
//
// USO
// ---
//   node devops/desplegar-pages.mjs
//
// Requiere `CLOUDFLARE_API_TOKEN` y `CLOUDFLARE_ACCOUNT_ID`. El script los lee de
// `backend/.env` si no están en el entorno, así que basta con tenerlos ahí.
//
// El token debe tener `Account` → `Cloudflare Pages` → `Edit`. Las claves de R2
// (`R2_ACCESS_KEY_ID`) **no sirven**: son credenciales S3 del bucket, y Wrangler
// las rechaza con un 400 (medido el 2026-10-25).
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const RAIZ = 'C:/Users/Loro/Desktop/Cuarto Semestre/1. Servicio Comunitario/INCES-LMS-PROJECT';
const BUNDLE = process.argv[2] ?? 'C:/tmp/web-produccion';
const PROYECTO = 'inces-lms';
const API_PRODUCCION = 'https://inces-lms-api.onrender.com';

/** Lee una clave de `backend/.env`. Devuelve null si no está. */
function delEnv(clave) {
  const p = path.join(RAIZ, 'backend/.env');
  if (!fs.existsSync(p)) return null;
  for (const linea of fs.readFileSync(p, 'utf8').split(/\r?\n/)) {
    const m = /^\s*([A-Z_0-9]+)\s*=\s*(.*)$/.exec(linea);
    if (m && m[1] === clave) {
      return m[2].trim().replace(/^["']|["']$/g, '');
    }
  }
  return null;
}

function fallar(msg) {
  console.error('\n  ✗ ' + msg + '\n');
  process.exit(1);
}

// --- 1. Credenciales ---------------------------------------------------------
const token = process.env.CLOUDFLARE_API_TOKEN ?? delEnv('CLOUDFLARE_API_TOKEN');
const cuenta = process.env.CLOUDFLARE_ACCOUNT_ID ?? delEnv('CLOUDFLARE_ACCOUNT_ID');

if (!token) {
  fallar(
    'Falta CLOUDFLARE_API_TOKEN.\n' +
      '    Añádelo a backend/.env (está en .gitignore) o expórtalo.\n' +
      '    Debe ser un token con Account → Cloudflare Pages → Edit.\n' +
      '    Las claves R2_NO sirven: son S3 del bucket.',
  );
}
if (!cuenta) fallar('Falta CLOUDFLARE_ACCOUNT_ID.');

// --- 2. El artefacto ---------------------------------------------------------
if (!fs.existsSync(BUNDLE)) {
  fallar(
    'No existe el bundle en ' + BUNDLE + '.\n' +
      '    Descárgalo con:\n' +
      '    gh run download <RUN_ID> --repo Burmistrov4/inces-lms --name web-produccion --dir ' + BUNDLE,
  );
}

// Las cinco piezas del procedimiento §5.1.
for (const f of ['index.html', 'main.dart.js', '_headers', 'robots.txt', 'sitemap.xml']) {
  if (!fs.existsSync(path.join(BUNDLE, f))) fallar('El bundle no trae ' + f + '. No se publica.');
}

const js = fs.readFileSync(path.join(BUNDLE, 'main.dart.js'), 'utf8');
if (!js.includes(API_PRODUCCION)) {
  fallar('El bundle no contiene la API de producción. No se publica.');
}
if (js.includes('localhost:3001')) {
  fallar('El bundle contiene una API local. No se publica.');
}

console.log('  ✓ artefacto validado (5 archivos, API de producción, sin localhost)');

// --- 3. Publicar -------------------------------------------------------------
const entorno = { ...process.env, CLOUDFLARE_API_TOKEN: token, CLOUDFLARE_ACCOUNT_ID: cuenta };

console.log('  · comprobando la credencial…');
const quien = spawnSync('npx', ['--yes', 'wrangler', 'whoami'], {
  env: entorno,
  encoding: 'utf8',
  shell: true,
});
if (quien.status !== 0) {
  fallar(
    'Wrangler no acepta la credencial.\n' +
      '    Revisa que el token tenga Account → Cloudflare Pages → Edit.\n' +
      (quien.stdout ?? '').split('\n').filter((l) => l.trim()).slice(-4).join('\n'),
  );
}
console.log('  ✓ credencial aceptada');

console.log('  · publicando en Cloudflare Pages…');
const deploy = spawnSync(
  'npx',
  ['--yes', 'wrangler', 'pages', 'deploy', BUNDLE, '--project-name=' + PROYECTO, '--branch=main'],
  { env: entorno, encoding: 'utf8', shell: true, stdio: 'inherit' },
);
if (deploy.status !== 0) fallar('El despliegue falló con código ' + deploy.status + '.');

console.log('\n  ✓ publicado. Confirma que figura como Production en main:');
console.log('    npx --yes wrangler pages deployment list --project-name=' + PROYECTO + '\n');
