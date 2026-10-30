import { test } from '@playwright/test';
import { LoginPage } from '../src/pages/LoginPage.js';

/**
 * Recorrido largo por las pantallas de administración, con capturas para mirar
 * el resultado a ojo. **No es regresión**: no afirma nada, sólo navega.
 *
 * Dos defectos reales se corrigieron aquí el 2026-10-29:
 *
 *   1. **Credenciales escritas en el archivo.** La contraseña del administrador
 *      estaba en claro y lleva en el historial de git desde `a174718`. Ahora se
 *      leen del entorno, como el resto de la suite; CI ya las inyecta como
 *      `E2E_ADMIN_EMAIL` / `E2E_ADMIN_PASSWORD`. Si faltan, la prueba se
 *      **salta** en vez de fallar. **La contraseña vieja hay que rotarla**:
 *      estar en el historial la deja comprometida aunque este archivo ya no la
 *      tenga.
 *
 *   2. **Rutas absolutas a un directorio de otra herramienta**
 *      (`C:/Users/Loro/.gemini/…`): en cualquier otra máquina —y en CI— ese
 *      directorio no existe y el `screenshot` falla. Ahora escribe en
 *      `informe/live/`, que está en `.gitignore`.
 *
 * Y pasa a ser **opt-in** (`E2E_LIVE=1`): abrir sesión de administrador varias
 * veces por corrida no aporta señal a la regresión y sí gasta cuota y tiempo.
 */
const ADMIN = process.env.E2E_ADMIN_EMAIL ?? '';
const CLAVE = process.env.E2E_ADMIN_PASSWORD ?? '';
const SALIDA = 'informe/live';

test.skip(process.env.E2E_LIVE !== '1', 'Recorrido con capturas: opt-in con E2E_LIVE=1');
test.skip(ADMIN === '' || CLAVE === '', 'Faltan credenciales E2E de admin.');

test('Recorrido de las pantallas de administración', async ({ page }) => {
  test.setTimeout(180_000);
  const login = new LoginPage(page);

  await login.abrir();

  await login.entrar(ADMIN, CLAVE);

  await page.waitForTimeout(4000);
  await page.screenshot({
    path: `${SALIDA}/live_01_dashboard.png`,
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
    path: `${SALIDA}/live_02_usuarios.png`,
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
    path: `${SALIDA}/live_03_periodo.png`,
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
    path: `${SALIDA}/live_04_archivos.png`,
  });
});
