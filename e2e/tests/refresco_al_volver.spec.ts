import { test, expect } from '@playwright/test';
import { LoginPage, SENAL_DE_SESION } from '../src/pages/LoginPage.js';
import { FlutterApp } from '../src/pages/FlutterApp.js';

const ADMIN = process.env.E2E_ADMIN_EMAIL ?? '';
const CLAVE = process.env.E2E_ADMIN_PASSWORD ?? '';

/**
 * Comprueba que volver a una sección **vuelve a pedir los datos** cuando ha
 * pasado el umbral de 45 s, y **no** los pide cuando se vuelve enseguida.
 *
 * Es la prueba que faltaba: el mixin puede estar bien escrito y no dispararse
 * nunca si `marcarCarga()` no se llama, o dispararse para todos los paneles si
 * el título no coincide. Sin esta prueba, «refresco en segundo plano» es una
 * afirmación sin evidencia.
 */
test.describe.serial('refresco al volver', () => {
  test.skip(ADMIN === '' || CLAVE === '', 'Faltan credenciales E2E de admin.');

  test('refresca tras el umbral y no antes', async ({ page }) => {
    const login = new LoginPage(page);
    const app = new FlutterApp(page);

    // Cuenta las peticiones a /admin/acceso que salen del navegador.
    let accesos = 0;
    page.on('request', (r) => {
      if (r.url().includes('/api/v1/admin/acceso')) accesos++;
    });

    await login.abrir();
    await login.entrar(ADMIN, CLAVE, SENAL_DE_SESION);
    await app.encenderSemantica();

    // 1) Primera visita: carga.
    await app.pulsar('Registro de Inicios de Sesión / Accesos');
    await page.waitForTimeout(3500);
    const trasPrimera = accesos;
    expect(trasPrimera, 'La primera visita debe pedir los accesos').toBeGreaterThan(0);

    // 2) Salir y volver ENSEGUIDA: no debe pedir nada (la caché del panel manda).
    await app.pulsar('Centro de Mando');
    await page.waitForTimeout(1200);
    await app.pulsar('Registro de Inicios de Sesión / Accesos');
    await page.waitForTimeout(2500);
    expect(
      accesos,
      'Volver enseguida no debe pedir de nuevo: tiene que ser instantáneo',
    ).toBe(trasPrimera);

    // 3) Salir, esperar más que el umbral (45 s) y volver: debe pedir.
    await app.pulsar('Centro de Mando');
    await page.waitForTimeout(50_000);
    await app.pulsar('Registro de Inicios de Sesión / Accesos');
    await page.waitForTimeout(3500);
    expect(
      accesos,
      'Pasados 45 s, volver debe refrescar en segundo plano',
    ).toBeGreaterThan(trasPrimera);
  });
});
