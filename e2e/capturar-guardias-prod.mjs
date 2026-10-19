import { chromium } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';

function leerEnv() {
  const env = {
    E2E_ADMIN_EMAIL: 'lorenzo-roca11@hotmail.com',
    E2E_ADMIN_PASSWORD: 'Codenamelms33$',
    BASE_URL: process.env.BASE_URL ?? 'https://inces-lms.pages.dev',
  };
  return env;
}

async function encenderSemantica(page) {
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 45000 });
  await page.waitForSelector('flt-semantics-placeholder, flt-semantics', { state: 'attached', timeout: 45000 });
  const count = await page.locator('flt-semantics').count();
  if (count === 0) {
    const placeholder = page.locator('flt-semantics-placeholder').first();
    if (await placeholder.count() > 0) {
      await placeholder.dispatchEvent('click');
      await page.waitForSelector('flt-semantics', { state: 'attached', timeout: 30000 });
    }
  }
}

async function esperarTexto(page, texto, timeoutMs = 35000) {
  const inicio = Date.now();
  while (Date.now() - inicio < timeoutMs) {
    const cantidad = await page.locator(`flt-semantics:has-text("${texto}")`).count();
    if (cantidad > 0) return true;
    await page.waitForTimeout(1000);
  }
  return false;
}

async function pulsarTexto(page, texto) {
  const nodo = page.locator(`flt-semantics:has-text("${texto}")`).last();
  await nodo.scrollIntoViewIfNeeded().catch(() => {});
  await nodo.click({ force: true });
}

async function main() {
  const env = leerEnv();
  console.log(`Abriendo navegador contra: ${env.BASE_URL}`);

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 1,
  });

  const page = await context.newPage();

  page.on('response', resp => {
    if (resp.url().includes('guardia') || resp.url().includes('cuadrante')) {
      console.log(`[API RESPONSE] ${resp.status()} ${resp.url()}`);
    }
  });

  console.log('1. Navegando al login...');
  await page.goto(`${env.BASE_URL}/#/login`, { waitUntil: 'domcontentloaded', timeout: 45000 });
  await encenderSemantica(page);
  await page.waitForTimeout(2000);

  console.log('2. Introduciendo credenciales...');
  const inputUser = page.locator('input[aria-label="Cédula o Correo"]').first();
  await inputUser.click();
  await inputUser.pressSequentially(env.E2E_ADMIN_EMAIL, { delay: 30 });

  const inputPass = page.locator('input[aria-label="Contraseña"]').first();
  await inputPass.click();
  await inputPass.pressSequentially(env.E2E_ADMIN_PASSWORD, { delay: 30 });

  const btnEntrar = page.locator('flt-semantics[role="button"]:has-text("Ingresar al sistema")').first();
  await btnEntrar.click();

  console.log('3. Esperando carga del cPanel...');
  const entro = await esperarTexto(page, 'Inscripciones y Cupos', 45000);
  if (!entro) {
    throw new Error('No cargó el cPanel a tiempo');
  }

  await page.waitForTimeout(3000);

  console.log('4. Navegando a Guardias Docentes...');
  await pulsarTexto(page, 'Guardias Docentes');
  
  // Esperar a que cargue el panel de guardias y las peticiones terminen
  console.log('Esperando carga completa de la matriz de guardias...');
  await page.waitForTimeout(12000);

  const destArtifact = 'C:/Users/Loro/.gemini/antigravity/brain/fc938256-e2cd-45cb-99ec-a6d5c97a5f0e/07_guardias_docentes_produccion.png';
  const destDocs = path.resolve('../docs/assets/dashboards/07_guardias_docentes_produccion.png');

  await page.screenshot({ path: destArtifact, fullPage: false });
  try {
    fs.copyFileSync(destArtifact, destDocs);
  } catch (_) {}

  console.log(`✅ CAPTURA GUARDADA EN: ${destArtifact}`);
  await browser.close();
}

main().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
