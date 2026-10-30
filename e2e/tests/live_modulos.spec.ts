import { test } from '@playwright/test';
import { LoginPage } from '../src/pages/LoginPage.js';

/**
 * Captura del panel de módulos. **No es regresión** (no afirma nada), y desde el
 * 2026-10-29 es opt-in con `E2E_LIVE=1`.
 *
 * Tenía la contraseña del administrador en claro y subía la captura a un
 * directorio absoluto de otra herramienta —`C:/Users/Loro/.gemini/…`— que no
 * existe ni en CI ni en otra máquina. Ahora lee las credenciales del entorno y
 * escribe en `informe/live/` (ignorado por git).
 */
const ADMIN = process.env.E2E_ADMIN_EMAIL ?? '';
const CLAVE = process.env.E2E_ADMIN_PASSWORD ?? '';

test.skip(process.env.E2E_LIVE !== '1', 'Captura con sesión real: opt-in con E2E_LIVE=1');
test.skip(ADMIN === '' || CLAVE === '', 'Faltan credenciales E2E de admin.');

test('Verificar Modulos del Sistema sin redundancia', async ({ page }) => {
  const login = new LoginPage(page);
  await login.abrir();
  await login.entrar(ADMIN, CLAVE);
  await page.waitForTimeout(2000);

  // Click on "Módulos del Sistema"
  await login.app.pulsarReal('Módulos del Sistema');
  await page.waitForTimeout(3000);
  await page.screenshot({ path: 'informe/live/live_05_modulos.png' });
});
