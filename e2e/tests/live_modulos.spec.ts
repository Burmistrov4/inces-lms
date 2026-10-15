import { expect, test } from '@playwright/test';
import { LoginPage } from '../src/pages/LoginPage.js';

test('Verificar Modulos del Sistema sin redundancia', async ({ page }) => {
  const login = new LoginPage(page);
  await login.abrir();
  await login.entrar('lorenzo-roca11@hotmail.com', 'Codenamelms33$');
  await page.waitForTimeout(2000);

  // Click on "Módulos del Sistema"
  await login.app.pulsarReal('Módulos del Sistema');
  await page.waitForTimeout(3000);
  await page.screenshot({
    path: 'C:/Users/Loro/.gemini/antigravity/brain/fc938256-e2cd-45cb-99ec-a6d5c97a5f0e/live_05_modulos.png',
  });
});
