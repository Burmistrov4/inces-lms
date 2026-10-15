import { chromium } from '@playwright/test';

async function verifyAllRoutes() {
  console.log('--- Iniciando Auditoría Visual y de Consola en Producción ---');
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 800 },
  });
  const page = await context.newPage();

  const errors = [];
  page.on('console', msg => {
    if (msg.type() === 'error') {
      errors.push(`[CONSOLE ERROR] ${msg.text()}`);
      console.error(`[CONSOLE ERROR] ${msg.text()}`);
    }
  });
  page.on('pageerror', err => {
    errors.push(`[PAGE ERROR] ${err.message}`);
    console.error(`[PAGE ERROR] ${err.message}`);
  });

  // 1. Landing Page
  console.log('\n[1/3] Verificando Landing Page (#/)...');
  await page.goto('https://inces-lms.pages.dev/#/', { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(5000);
  const landingFlutterView = await page.$('flutter-view, flt-glass-pane, [flt-renderer]');
  console.log(`- Flutter activo en Landing: ${landingFlutterView !== null}`);
  await page.screenshot({ path: 'C:/Users/Loro/.gemini/antigravity/brain/fc938256-e2cd-45cb-99ec-a6d5c97a5f0e/screenshot_landing.png' });

  // 2. Login Screen
  console.log('\n[2/3] Verificando Login (#/login)...');
  await page.goto('https://inces-lms.pages.dev/#/login', { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(5000);
  const loginFlutterView = await page.$('flutter-view, flt-glass-pane, [flt-renderer]');
  console.log(`- Flutter activo en Login: ${loginFlutterView !== null}`);
  await page.screenshot({ path: 'C:/Users/Loro/.gemini/antigravity/brain/fc938256-e2cd-45cb-99ec-a6d5c97a5f0e/screenshot_login.png' });

  // 3. Formulario de Inscripción
  console.log('\n[3/3] Verificando Inscripción (#/inscripcion)...');
  await page.goto('https://inces-lms.pages.dev/#/inscripcion', { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(5000);
  const inscripcionFlutterView = await page.$('flutter-view, flt-glass-pane, [flt-renderer]');
  console.log(`- Flutter activo en Inscripción: ${inscripcionFlutterView !== null}`);
  await page.screenshot({ path: 'C:/Users/Loro/.gemini/antigravity/brain/fc938256-e2cd-45cb-99ec-a6d5c97a5f0e/screenshot_inscripcion.png' });

  await browser.close();

  console.log('\n--- Resumen de Errores de Consola ---');
  if (errors.length === 0) {
    console.log('✅ CERO errores de consola o runtime en todas las rutas.');
  } else {
    console.warn(`⚠️ Se encontraron ${errors.length} errores:`, errors);
  }
}

verifyAllRoutes().catch(err => {
  console.error('Error durante la verificación de rutas:', err);
  process.exit(1);
});
