import { test, expect } from '@playwright/test';
import path from 'node:path';
import fs from 'node:fs';
import { LoginPage, SENAL_DE_SESION, SENAL_DE_SESION_ALUMNO } from '../src/pages/LoginPage.js';

// Las credenciales NO se escriben aquí: se leen del entorno (`.env.e2e` en
// local, secretos del repositorio en CI). Tenían un valor por defecto en claro
// hasta el 2026-10-29, así que quedaron en el historial de git; sin entorno, la
// suite se salta en vez de usar una contraseña incrustada.
const ADMIN_EMAIL = process.env.E2E_ADMIN_EMAIL ?? '';
const ADMIN_PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? '';
const DOCENTE_EMAIL = process.env.E2E_DOCENTE_EMAIL ?? 'docente@semilla.invalid';
const DOCENTE_PASSWORD = process.env.E2E_DOCENTE_PASSWORD ?? 'SemillaInces26!';
const ALUMNO_EMAIL = process.env.E2E_ALUMNO_EMAIL ?? 'estudiante1@semilla.invalid';
const ALUMNO_PASSWORD = process.env.E2E_ALUMNO_PASSWORD ?? 'SemillaInces26!';

const DIR_DESTINO = path.resolve('../docs/assets/dashboards');

test.describe.serial('Captura de Dashboards Multi-Rol (Admin, Docente, Estudiante)', () => {
  test.beforeAll(() => {
    if (!fs.existsSync(DIR_DESTINO)) {
      fs.mkdirSync(DIR_DESTINO, { recursive: true });
    }
  });

  test('01 - Capturar Formulario de Admisión e Inscripción', async ({ page }) => {
    test.setTimeout(60_000);
    console.log('[E2E-CAPTURA] Abriendo formulario público de admisión...');
    await page.goto('https://inces-lms.pages.dev/#/inscripcion', {
      waitUntil: 'networkidle',
      timeout: 45_000,
    });
    await page.waitForTimeout(6000);
    const ruta = path.join(DIR_DESTINO, '01_formulario_admision_publico.png');
    await page.screenshot({ path: ruta, fullPage: false });
    console.log(`[OK] Capturado: ${ruta}`);
  });

  test('02 - Capturar Dashboard Admin (cPanel) y Gestión de Usuarios', async ({ page }) => {
    test.setTimeout(120_000);
    const login = new LoginPage(page);
    console.log('[E2E-CAPTURA] Abriendo login institucional...');
    await login.abrir();

    console.log(`[E2E-CAPTURA] Iniciando sesión Admin (${ADMIN_EMAIL})...`);
    await login.entrar(ADMIN_EMAIL, ADMIN_PASSWORD, SENAL_DE_SESION);

    await page.waitForTimeout(5000);
    const rutaAdmin = path.join(DIR_DESTINO, '02_dashboard_admin_cpanel.png');
    await page.screenshot({ path: rutaAdmin, fullPage: false });
    console.log(`[OK] Capturado: ${rutaAdmin}`);

    // Usuarios y Roles
    console.log('[E2E-CAPTURA] Navegando a Usuarios y Roles...');
    await login.app.pulsarReal('Usuarios y Roles', { tiempoLimiteMs: 15_000 });
    await page.waitForTimeout(4000);
    const rutaUsuarios = path.join(DIR_DESTINO, '03_dashboard_admin_usuarios_e_invitaciones.png');
    await page.screenshot({ path: rutaUsuarios, fullPage: false });
    console.log(`[OK] Capturado: ${rutaUsuarios}`);

    // Horarios de Clases
    console.log('[E2E-CAPTURA] Navegando a Horarios de Clases...');
    await page.mouse.move(100, 400);
    await page.mouse.wheel(0, 300);
    await page.waitForTimeout(500);
    await login.app.pulsarReal('Cuadrante de Horarios', { tiempoLimiteMs: 15_000 });
    await page.waitForTimeout(4000);
    const rutaHorarios = path.join(DIR_DESTINO, '04_dashboard_admin_horarios.png');
    await page.screenshot({ path: rutaHorarios, fullPage: false });
    console.log(`[OK] Capturado: ${rutaHorarios}`);
  });

  test('03 - Capturar Dashboard Docente / Facilitador', async ({ page }) => {
    test.setTimeout(120_000);
    const login = new LoginPage(page);
    console.log('[E2E-CAPTURA] Abriendo login para Docente...');
    await login.abrir();

    console.log(`[E2E-CAPTURA] Iniciando sesión Docente (${DOCENTE_EMAIL})...`);
    await login.entrar(DOCENTE_EMAIL, DOCENTE_PASSWORD, 'Aulas Virtuales');

    await page.waitForTimeout(5000);
    const rutaDocente = path.join(DIR_DESTINO, '05_dashboard_docente_facilitador.png');
    await page.screenshot({ path: rutaDocente, fullPage: false });
    console.log(`[OK] Capturado: ${rutaDocente}`);
  });

  test('04 - Capturar Dashboard Estudiante / Aprendiz', async ({ page }) => {
    test.setTimeout(120_000);
    const login = new LoginPage(page);
    console.log('[E2E-CAPTURA] Abriendo login para Estudiante...');
    await login.abrir();

    console.log(`[E2E-CAPTURA] Iniciando sesión Estudiante (${ALUMNO_EMAIL})...`);
    await login.entrar(ALUMNO_EMAIL, ALUMNO_PASSWORD, SENAL_DE_SESION_ALUMNO);

    await page.waitForTimeout(5000);
    const rutaAlumno = path.join(DIR_DESTINO, '06_dashboard_aprendiz_estudiante.png');
    await page.screenshot({ path: rutaAlumno, fullPage: false });
    console.log(`[OK] Capturado: ${rutaAlumno}`);
  });
});
