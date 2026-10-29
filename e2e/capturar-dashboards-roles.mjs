import { chromium } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';

function leerEnv() {
  const envPath = path.resolve('.env.e2e');
  const env = {
    E2E_ADMIN_EMAIL: 'lorenzo-roca11@hotmail.com',
    E2E_ADMIN_PASSWORD: 'Codenamelms33$',
    E2E_DOCENTE_EMAIL: 'docente@semilla.invalid',
    E2E_DOCENTE_PASSWORD: 'SemillaInces26!',
    E2E_ALUMNO_EMAIL: 'estudiante1@semilla.invalid',
    E2E_ALUMNO_PASSWORD: 'SemillaInces26!',
    BASE_URL: process.env.BASE_URL ?? 'https://inces-lms.pages.dev',
  };

  if (fs.existsSync(envPath)) {
    const lineas = fs.readFileSync(envPath, 'utf8').split('\n');
    for (const linea of lineas) {
      const match = linea.match(/^\s*([\w]+)\s*=\s*(.*)?\s*$/);
      if (match) {
        const [, k, v] = match;
        if (v !== undefined) env[k] = v.trim();
      }
    }
  }

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

async function capturarDashboards() {
  console.log('=== SISTEMA DE SCREENSHOTS ROBUSTO: VISTAS MULTI-ROL (PRODUCCIÓN) ===');
  const dirDestino = path.resolve('../docs/assets/dashboards');
  if (!fs.existsSync(dirDestino)) {
    fs.mkdirSync(dirDestino, { recursive: true });
  }

  const env = leerEnv();
  console.log(`URL objetivo: ${env.BASE_URL}`);

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 1,
  });

  const page = await context.newPage();

  page.on('console', msg => {
    if (msg.type() === 'error') {
      console.warn(`[BROWSER ERROR] ${msg.text()}`);
    }
  });

  // ---------------------------------------------------------------------------
  // 1. CAPTURA PÚBLICA Y ADMISIÓN
  // ---------------------------------------------------------------------------
  console.log('\n[1/6] Capturando Formulario de Admisión e Inscripción...');
  try {
    await page.goto(`${env.BASE_URL}/#/inscripcion`, { waitUntil: 'networkidle', timeout: 40000 });
    await page.waitForTimeout(5000);
    const ruta1 = path.join(dirDestino, '01_formulario_admision_inscripcion.png');
    await page.screenshot({ path: ruta1, fullPage: false });
    console.log(`✅ Guardado: ${ruta1}`);
  } catch (err) {
    console.warn('⚠️ Error capturando formulario de inscripción:', err.message);
  }

  // ---------------------------------------------------------------------------
  // 2. DASHBOARD ADMINISTRADOR (cPanel)
  // ---------------------------------------------------------------------------
  console.log('\n[2/6] Autenticando como Administrador Maestro...');
  try {
    await page.goto(`${env.BASE_URL}/#/login`, { waitUntil: 'domcontentloaded', timeout: 40000 });
    await encenderSemantica(page);
    await page.waitForTimeout(2000);

    const inputUser = page.locator('input[aria-label="Cédula o Correo"]').first();
    await inputUser.click();
    await inputUser.pressSequentially(env.E2E_ADMIN_EMAIL, { delay: 40 });

    const inputPass = page.locator('input[aria-label="Contraseña"]').first();
    await inputPass.click();
    await inputPass.pressSequentially(env.E2E_ADMIN_PASSWORD, { delay: 40 });

    const btnEntrar = page.locator('flt-semantics[role="button"]:has-text("Ingresar al sistema")').first();
    await btnEntrar.click();

    console.log('Esperando carga del cPanel...');
    const entroAdmin = await esperarTexto(page, 'Cursos y PNA', 45000);
    if (entroAdmin) {
      await page.waitForTimeout(5000);
      const rutaAdmin = path.join(dirDestino, '02_dashboard_admin_cpanel.png');
      await page.screenshot({ path: rutaAdmin, fullPage: false });
      console.log(`✅ Guardado: ${rutaAdmin}`);

      // Captura Usuarios y Roles
      console.log('Navegando a Usuarios y Roles...');
      await pulsarTexto(page, 'Usuarios y Roles');
      await esperarTexto(page, 'Invitar docente', 20000);
      await page.waitForTimeout(4000);
      const rutaUsuarios = path.join(dirDestino, '03_admin_usuarios_e_invitaciones.png');
      await page.screenshot({ path: rutaUsuarios, fullPage: false });
      console.log(`✅ Guardado: ${rutaUsuarios}`);

      // Captura Horarios de Clases
      console.log('Navegando a Horarios de Clases...');
      await pulsarTexto(page, 'Horarios de Clases');
      await esperarTexto(page, 'Horarios de Clases', 20000);
      await page.waitForTimeout(4000);
      const rutaHorarios = path.join(dirDestino, '04_admin_horarios_cuadrante.png');
      await page.screenshot({ path: rutaHorarios, fullPage: false });
      console.log(`✅ Guardado: ${rutaHorarios}`);
    } else {
      console.warn('⚠️ No se detectó la carga del cPanel de administrador');
    }
  } catch (err) {
    console.warn('⚠️ Error en flujo de administrador:', err.message);
  }

  // ---------------------------------------------------------------------------
  // 3. DASHBOARD DOCENTE
  // ---------------------------------------------------------------------------
  console.log('\n[3/6] Autenticando como Docente / Facilitador...');
  try {
    await page.goto(`${env.BASE_URL}/#/login`, { waitUntil: 'domcontentloaded', timeout: 40000 });
    await encenderSemantica(page);
    await page.waitForTimeout(2000);

    const inputUser = page.locator('input[aria-label="Cédula o Correo"]').first();
    await inputUser.click();
    await inputUser.pressSequentially(env.E2E_DOCENTE_EMAIL, { delay: 40 });

    const inputPass = page.locator('input[aria-label="Contraseña"]').first();
    await inputPass.click();
    await inputPass.pressSequentially(env.E2E_DOCENTE_PASSWORD, { delay: 40 });

    const btnEntrar = page.locator('flt-semantics[role="button"]:has-text("Ingresar al sistema")').first();
    await btnEntrar.click();

    console.log('Esperando carga del portal Docente...');
    const entroDocente = await esperarTexto(page, 'Aulas Virtuales', 45000);
    if (entroDocente) {
      await page.waitForTimeout(5000);
      const rutaDocente = path.join(dirDestino, '05_dashboard_docente_facilitador.png');
      await page.screenshot({ path: rutaDocente, fullPage: false });
      console.log(`✅ Guardado: ${rutaDocente}`);
    } else {
      console.warn('⚠️ No se detectó la carga del portal Docente');
    }
  } catch (err) {
    console.warn('⚠️ Error en flujo de docente:', err.message);
  }

  // ---------------------------------------------------------------------------
  // 4. DASHBOARD APRENDIZ / ESTUDIANTE
  // ---------------------------------------------------------------------------
  console.log('\n[4/6] Autenticando como Estudiante / Aprendiz...');
  try {
    await page.goto(`${env.BASE_URL}/#/login`, { waitUntil: 'domcontentloaded', timeout: 40000 });
    await encenderSemantica(page);
    await page.waitForTimeout(2000);

    const inputUser = page.locator('input[aria-label="Cédula o Correo"]').first();
    await inputUser.click();
    await inputUser.pressSequentially(env.E2E_ALUMNO_EMAIL, { delay: 40 });

    const inputPass = page.locator('input[aria-label="Contraseña"]').first();
    await inputPass.click();
    await inputPass.pressSequentially(env.E2E_ALUMNO_PASSWORD, { delay: 40 });

    const btnEntrar = page.locator('flt-semantics[role="button"]:has-text("Ingresar al sistema")').first();
    await btnEntrar.click();

    console.log('Esperando carga del portal Aprendiz...');
    const entroAlumno = await esperarTexto(page, 'Mi Expediente', 45000);
    if (entroAlumno) {
      await page.waitForTimeout(5000);
      const rutaAlumno = path.join(dirDestino, '06_dashboard_aprendiz_estudiante.png');
      await page.screenshot({ path: rutaAlumno, fullPage: false });
      console.log(`✅ Guardado: ${rutaAlumno}`);
    } else {
      console.warn('⚠️ No se detectó la carga del portal Aprendiz');
    }
  } catch (err) {
    console.warn('⚠️ Error en flujo de estudiante:', err.message);
  }

  await browser.close();
  console.log('\n=== CAPTURA ROBUSTA MULTI-ROL COMPLETADA CON ÉXITO ===');
  console.log(`Directorio de artefactos: ${dirDestino}`);
}

capturarDashboards().catch(err => {
  console.error('Error general capturando dashboards:', err);
  process.exit(1);
});
