import { chromium } from '@playwright/test';
import path from 'node:path';

const OUT_DIR = 'C:/Users/Loro/.gemini/antigravity/brain/fc938256-e2cd-45cb-99ec-a6d5c97a5f0e/nuevo_sistema_v2';

async function main() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
  });
  const page = await context.newPage();

  page.on('console', msg => {
    if (msg.type() === 'error') console.log(`[BROWSER ERROR]:`, msg.text());
  });

  console.log('1. Autenticando como Admin...');
  await page.goto('http://127.0.0.1:3000/login', { waitUntil: 'networkidle' });
  await page.fill('input[type="text"]', 'lorenzo-roca11@hotmail.com');
  await page.fill('input[type="password"]', 'Codenamelms33$');
  await page.click('button[type="submit"]');

  await page.waitForURL('**/operaciones', { timeout: 15000 });
  await page.waitForTimeout(2000);
  console.log('En Operaciones:', page.url());
  await page.screenshot({ path: path.join(OUT_DIR, '04_operaciones_admin_v2.png'), fullPage: false });
  console.log('✓ Guardado 04_operaciones_admin_v2.png');

  // Navegar a Académica
  console.log('2. Navegando a Académica...');
  await page.click('a[href="/academica"]');
  await page.waitForURL('**/academica', { timeout: 15000 });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(OUT_DIR, '05_academica_secciones_v2.png'), fullPage: false });
  console.log('✓ Guardado 05_academica_secciones_v2.png');

  // Navegar a Comunidad
  console.log('3. Navegando a Comunidad...');
  await page.click('a[href="/comunidad"]');
  await page.waitForURL('**/comunidad', { timeout: 15000 });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(OUT_DIR, '06_comunidad_aulas_v2.png'), fullPage: false });
  console.log('✓ Guardado 06_comunidad_aulas_v2.png');

  // Navegar a Archivos R2
  console.log('4. Navegando a Archivos...');
  await page.click('a[href="/archivos"]');
  await page.waitForURL('**/archivos', { timeout: 15000 });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(OUT_DIR, '07_archivos_r2_v2.png'), fullPage: false });
  console.log('✓ Guardado 07_archivos_r2_v2.png');

  // Navegar a Sistema / Auditoría
  console.log('5. Navegando a Sistema...');
  await page.click('a[href="/sistema"]');
  await page.waitForURL('**/sistema', { timeout: 15000 });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(OUT_DIR, '08_sistema_auditoria_v2.png'), fullPage: false });
  console.log('✓ Guardado 08_sistema_auditoria_v2.png');

  // Navegar a Portal Docente
  console.log('6. Navegando a Docente...');
  await page.click('a[href="/docente"]');
  await page.waitForURL('**/docente', { timeout: 15000 });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(OUT_DIR, '09_portal_docente_v2.png'), fullPage: false });
  console.log('✓ Guardado 09_portal_docente_v2.png');

  // Navegar a Portal Aprendiz
  console.log('7. Navegando a Aprendiz...');
  await page.click('a[href="/aprendiz"]');
  await page.waitForURL('**/aprendiz', { timeout: 15000 });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(OUT_DIR, '10_portal_aprendiz_v2.png'), fullPage: false });
  console.log('✓ Guardado 10_portal_aprendiz_v2.png');

  await browser.close();
  console.log('=== TODAS LAS VISTAS CAPTURADAS EXITOSAMENTE ===');
}

main().catch(console.error);
