import { expect, test } from '@playwright/test';
import { LoginPage } from '../src/pages/LoginPage.js';

test('Verificar INCES LMS v1.2.4 en producción con sesión administrativa', async ({ page }) => {
  test.setTimeout(120_000);
  const login = new LoginPage(page);

  console.log('[PROD] Abriendo login...');
  await login.abrir();

  console.log('[PROD] Iniciando sesión con lorenzo-roca11@hotmail.com...');
  await login.entrar('lorenzo-roca11@hotmail.com', 'Codenamelms33$');

  console.log('[PROD] Sesión iniciada con éxito. Capturando Centro de Mando...');
  await page.waitForTimeout(4000);
  await page.screenshot({
    path: 'C:/Users/Loro/.gemini/antigravity/brain/fc938256-e2cd-45cb-99ec-a6d5c97a5f0e/live_01_dashboard.png',
  });

  // 1. Usuarios y Roles
  console.log('[PROD] Navegando a Usuarios y Roles...');
  await page.keyboard.press('Escape');
  await page.waitForTimeout(500);
  await login.app.pulsarReal('Usuarios y Roles', { tiempoLimiteMs: 15000 });
  await page.waitForTimeout(4000);
  // Scroll down in main content to see the full table
  await page.mouse.move(700, 400);
  await page.mouse.wheel(0, 400);
  await page.waitForTimeout(1000);
  await page.screenshot({
    path: 'C:/Users/Loro/.gemini/antigravity/brain/fc938256-e2cd-45cb-99ec-a6d5c97a5f0e/live_02_usuarios.png',
  });

  // 2. Período
  console.log('[PROD] Navegando a Período...');
  await page.keyboard.press('Escape');
  await page.waitForTimeout(500);
  // Scroll sidebar to reveal lower items
  await page.mouse.move(100, 400);
  await page.mouse.wheel(0, 300);
  await page.waitForTimeout(500);
  await login.app.pulsarReal('Período', { tiempoLimiteMs: 15000 });
  await page.waitForTimeout(4000);
  await page.screenshot({
    path: 'C:/Users/Loro/.gemini/antigravity/brain/fc938256-e2cd-45cb-99ec-a6d5c97a5f0e/live_03_lapsos.png',
  });

  // 3. Gestor de Archivos (R2)
  console.log('[PROD] Navegando a Gestor de Archivos (R2)...');
  await page.keyboard.press('Escape');
  await page.waitForTimeout(500);
  await page.mouse.move(100, 400);
  await page.mouse.wheel(0, 300);
  await page.waitForTimeout(500);
  await login.app.pulsarReal('Archivos del Centro', { tiempoLimiteMs: 15000 });
  await page.waitForTimeout(4000);
  await page.screenshot({
    path: 'C:/Users/Loro/.gemini/antigravity/brain/fc938256-e2cd-45cb-99ec-a6d5c97a5f0e/live_04_archivos.png',
  });

  console.log('[PROD] Todas las pantallas fueron navegadas y capturadas exitosamente.');
});
