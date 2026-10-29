import { expect, test } from '@playwright/test';
import { LoginPage } from '../src/pages/LoginPage.js';

const BRAIN_DIR = 'C:/Users/Loro/.gemini/antigravity/brain/fc938256-e2cd-45cb-99ec-a6d5c97a5f0e';

test.use({ serviceWorkers: 'block' });


test('1. Flujo Público y Responsive (Landing, Oferta, Móvil, Inscripción, Login, Recuperación)', async ({ page }) => {
  test.setTimeout(240_000);
    // A. Landing Page Desktop
    console.log('[AUDITORÍA] Verificando Landing Page en Desktop...');
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto('https://inces-lms.pages.dev/#/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(5000);
    await page.screenshot({ path: `${BRAIN_DIR}/audit_01_landing_desktop.png` });

    // B. Catálogo de Oferta Formativa (Scroll)
    console.log('[AUDITORÍA] Verificando Catálogo de Oferta Formativa...');
    await page.mouse.wheel(0, 900);
    await page.waitForTimeout(2000);
    await page.screenshot({ path: `${BRAIN_DIR}/audit_02_oferta_formativa.png` });

    // C. Responsive Móvil (iPhone 13 / 390x844)
    console.log('[AUDITORÍA] Verificando Vista Móvil Responsive...');
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto('https://inces-lms.pages.dev/#/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(5000);
    await page.screenshot({ path: `${BRAIN_DIR}/audit_03_landing_mobile.png` });

    // D. Planilla de Inscripción
    console.log('[AUDITORÍA] Verificando Planilla de Inscripción...');
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto('https://inces-lms.pages.dev/#/inscripcion', { waitUntil: 'networkidle' });
    await page.waitForTimeout(5000);
    await page.screenshot({ path: `${BRAIN_DIR}/audit_04_inscripcion.png` });

    // E. Pantalla de Acceso / Login
    console.log('[AUDITORÍA] Verificando Pantalla de Login...');
    await page.goto('https://inces-lms.pages.dev/#/login', { waitUntil: 'networkidle' });
    await page.waitForTimeout(4000);
    await page.screenshot({ path: `${BRAIN_DIR}/audit_05_login.png` });

    // F. Recuperación de Contraseña
    console.log('[AUDITORÍA] Verificando Pantalla de Recuperación...');
    await page.goto('https://inces-lms.pages.dev/#/restablecer-codigo', { waitUntil: 'networkidle' });
    await page.waitForTimeout(4000);
    await page.screenshot({ path: `${BRAIN_DIR}/audit_06_recuperacion.png` });
  });

  test('2. Panel Administrativo Integral y Módulos Institucionales', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    const login = new LoginPage(page);

    console.log('[AUDITORÍA ADMIN] Iniciando sesión institucional...');
    await login.abrir();
    await login.entrar('lorenzo-roca11@hotmail.com', 'Codenamelms33$');
    await page.waitForTimeout(5000);

    // G. Centro de Mando / Resumen con Walkthrough
    console.log('[AUDITORÍA ADMIN] Capturando Centro de Mando...');
    await page.screenshot({ path: `${BRAIN_DIR}/audit_07_admin_dashboard.png` });

    // H. Horarios de Clases
    console.log('[AUDITORÍA ADMIN] Navegando a Horarios de Clases...');
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);
    await login.app.pulsarReal('Cuadrante de Horarios', { tiempoLimiteMs: 15000 });
    await page.waitForTimeout(7000);
    await page.screenshot({ path: `${BRAIN_DIR}/audit_08_admin_horarios.png` });

    // I. Cursos y PNA (antes «Programas Académicos»)
    console.log('[AUDITORÍA ADMIN] Navegando a Cursos y PNA...');
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);
    await login.app.pulsarReal('Cursos y PNA', { tiempoLimiteMs: 15000 });
    await page.waitForTimeout(4000);
    await page.screenshot({ path: `${BRAIN_DIR}/audit_09_admin_programas.png` });

    // J. Cursos y PNA (absorbió «Inscripciones y Cupos»: cupos, colas y exportación HACER)
    console.log('[AUDITORÍA ADMIN] Navegando a Cursos y PNA (cupos)...');
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);
    await login.app.pulsarReal('Cursos y PNA', { tiempoLimiteMs: 15000 });
    await page.waitForTimeout(4000);
    await page.screenshot({ path: `${BRAIN_DIR}/audit_10_admin_inscripciones.png` });

    // K. Período
    console.log('[AUDITORÍA ADMIN] Navegando a Período...');
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);
    await page.mouse.move(100, 400);
    await page.mouse.wheel(0, 300);
    await page.waitForTimeout(500);
    await login.app.pulsarReal('Período', { tiempoLimiteMs: 15000 });
    await page.waitForTimeout(4000);
    await page.screenshot({ path: `${BRAIN_DIR}/audit_11_admin_lapsos.png` });

    // L. Usuarios y Roles
    console.log('[AUDITORÍA ADMIN] Navegando a Usuarios y Roles...');
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);
    await login.app.pulsarReal('Usuarios y Roles', { tiempoLimiteMs: 15000 });
    await page.waitForTimeout(4000);
    await page.mouse.move(700, 400);
    await page.mouse.wheel(0, 350);
    await page.waitForTimeout(1000);
    await page.screenshot({ path: `${BRAIN_DIR}/audit_12_admin_usuarios.png` });

    // M. Gestor de Archivos (R2)
    console.log('[AUDITORÍA ADMIN] Navegando a Gestor de Archivos (R2)...');
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);
    await page.mouse.move(100, 400);
    await page.mouse.wheel(0, 300);
    await page.waitForTimeout(500);
    await login.app.pulsarReal('Archivos del Centro', { tiempoLimiteMs: 15000 });
    await page.waitForTimeout(4000);
    await page.screenshot({ path: `${BRAIN_DIR}/audit_13_admin_archivos.png` });

    // N. Módulos del Sistema
    console.log('[AUDITORÍA ADMIN] Navegando a Módulos del Sistema...');
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);
    await page.mouse.move(100, 400);
    await page.mouse.wheel(0, -600);
    await page.waitForTimeout(500);
    await login.app.pulsarReal('Módulos del Sistema', { tiempoLimiteMs: 15000 });
    await page.waitForTimeout(4000);
    await page.screenshot({ path: `${BRAIN_DIR}/audit_14_admin_modulos.png` });

    console.log('[AUDITORÍA ADMIN] Todos los módulos fueron auditados y capturados exitosamente.');
  });
