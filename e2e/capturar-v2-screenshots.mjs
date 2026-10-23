import { chromium } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';

const BASE_URL = 'http://127.0.0.1:3000';
const OUT_DIR = 'C:/Users/Loro/.gemini/antigravity/brain/fc938256-e2cd-45cb-99ec-a6d5c97a5f0e/nuevo_sistema_v2';

if (!fs.existsSync(OUT_DIR)) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
}

async function capture() {
  console.log('=== CAPTURANDO SCREENSHOTS DEL SISTEMA V2 (REACT + TAILWIND) ===');
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 1,
  });
  const page = await context.newPage();

  // 1. Landing Page
  console.log('1. Capturando Landing Page...');
  await page.goto(`${BASE_URL}/`, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(OUT_DIR, '01_landing_page_v2.png'), fullPage: false });
  console.log('✓ Guardado 01_landing_page_v2.png');

  // 2. Login Page
  console.log('2. Capturando Login Page...');
  await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(1000);
  await page.screenshot({ path: path.join(OUT_DIR, '02_login_page_v2.png'), fullPage: false });
  console.log('✓ Guardado 02_login_page_v2.png');

  // 3. Inscripcion Aspirante Page
  console.log('3. Capturando Inscripcion Aspirante...');
  await page.goto(`${BASE_URL}/inscribirse`, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(1000);
  await page.screenshot({ path: path.join(OUT_DIR, '03_inscripcion_aspirante_v2.png'), fullPage: false });
  console.log('✓ Guardado 03_inscripcion_aspirante_v2.png');

  // 4. Iniciar sesión como Admin
  console.log('4. Autenticando como Admin...');
  await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle', timeout: 30000 });
  await page.fill('input[type="text"]', 'lorenzo-roca11@hotmail.com');
  await page.fill('input[type="password"]', 'Codenamelms33$');
  await page.click('button[type="submit"]');
  await page.waitForTimeout(3000);

  // 4a. Operaciones
  console.log('4a. Capturando Operaciones / Admin Dashboard...');
  await page.screenshot({ path: path.join(OUT_DIR, '04_operaciones_admin_v2.png'), fullPage: false });
  console.log('✓ Guardado 04_operaciones_admin_v2.png');

  // 4b. Academica
  console.log('4b. Capturando Académica...');
  await page.goto(`${BASE_URL}/academica`, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(OUT_DIR, '05_academica_secciones_v2.png'), fullPage: false });
  console.log('✓ Guardado 05_academica_secciones_v2.png');

  // 4c. Comunidad
  console.log('4c. Capturando Comunidad / Aulas Virtuales...');
  await page.goto(`${BASE_URL}/comunidad`, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(OUT_DIR, '06_comunidad_aulas_v2.png'), fullPage: false });
  console.log('✓ Guardado 06_comunidad_aulas_v2.png');

  // 4d. Archivos R2
  console.log('4d. Capturando Archivos R2...');
  await page.goto(`${BASE_URL}/archivos`, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(OUT_DIR, '07_archivos_r2_v2.png'), fullPage: false });
  console.log('✓ Guardado 07_archivos_r2_v2.png');

  // 4e. Sistema Auditoria
  console.log('4e. Capturando Sistema y Auditoría...');
  await page.goto(`${BASE_URL}/sistema`, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(OUT_DIR, '08_sistema_auditoria_v2.png'), fullPage: false });
  console.log('✓ Guardado 08_sistema_auditoria_v2.png');

  // 5. Iniciar sesión como Docente
  console.log('5. Autenticando como Docente con nuevas credenciales...');
  await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle', timeout: 30000 });
  // Logout first if needed or clear cookies
  await context.clearCookies();
  await page.evaluate(() => localStorage.clear());
  await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle', timeout: 30000 });
  await page.fill('input[type="text"]', 'docente.pruebas@inces.gob.ve');
  await page.fill('input[type="password"]', 'IncesPruebas2026!');
  await page.click('button[type="submit"]');
  await page.waitForTimeout(3000);
  await page.goto(`${BASE_URL}/docente`, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(OUT_DIR, '09_portal_docente_v2.png'), fullPage: false });
  console.log('✓ Guardado 09_portal_docente_v2.png');

  // 6. Iniciar sesión como Estudiante
  console.log('6. Autenticando como Estudiante con nuevas credenciales...');
  await context.clearCookies();
  await page.evaluate(() => localStorage.clear());
  await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle', timeout: 30000 });
  await page.fill('input[type="text"]', 'estudiante.pruebas@inces.gob.ve');
  await page.fill('input[type="password"]', 'IncesPruebas2026!');
  await page.click('button[type="submit"]');
  await page.waitForTimeout(3000);
  await page.goto(`${BASE_URL}/aprendiz`, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(OUT_DIR, '10_portal_aprendiz_v2.png'), fullPage: false });
  console.log('✓ Guardado 10_portal_aprendiz_v2.png');

  await browser.close();
  console.log('=== CAPTURAS DE V2 COMPLETADAS CON ÉXITO ===');
}

capture().catch(e => {
  console.error('Error capturando screenshots V2:', e);
  process.exit(1);
});
