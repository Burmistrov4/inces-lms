import { chromium } from '@playwright/test';

async function main() {
  console.log('Iniciando Chromium headless...');
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 800 },
  });
  const page = await context.newPage();

  const consoleMessages = [];
  const errors = [];
  page.on('console', msg => {
    consoleMessages.push(`[${msg.type()}] ${msg.text()}`);
    console.log(`[BROWSER CONSOLE] ${msg.type()}: ${msg.text()}`);
  });
  page.on('pageerror', err => {
    errors.push(err.message);
    console.error(`[PAGE ERROR] ${err.message}`);
  });

  console.log('Navegando a https://inces-lms.pages.dev ...');
  const response = await page.goto('https://inces-lms.pages.dev', {
    waitUntil: 'networkidle',
    timeout: 30000,
  });
  console.log(`Status de respuesta HTTP: ${response.status()}`);

  console.log('Esperando renderizado de la UI de Flutter...');
  await page.waitForTimeout(6000);

  const title = await page.title();
  console.log(`Título de la página: ${title}`);

  // Verificar presencia del contenedor de Flutter Web
  const hasFlutterView = await page.$('flutter-view, flt-glass-pane, [flt-renderer]');
  console.log(`¿Contenedor Flutter renderizado?: ${hasFlutterView !== null}`);

  const screenshotPath = 'C:/Users/Loro/.gemini/antigravity/brain/fc938256-e2cd-45cb-99ec-a6d5c97a5f0e/live_verification.png';
  await page.screenshot({ path: screenshotPath, fullPage: true });
  console.log(`Captura de pantalla guardada en: ${screenshotPath}`);

  await browser.close();

  if (errors.length > 0) {
    console.error('Se detectaron errores en la página:', errors);
    process.exit(1);
  } else {
    console.log('¡Verificación exitosa! La página cargó limpiamente y la interfaz está activa.');
  }
}

main().catch(err => {
  console.error('Fallo en la prueba de verificación:', err);
  process.exit(1);
});
