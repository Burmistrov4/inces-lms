import { chromium } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';

const BASE_URL = 'http://127.0.0.1:3000';
const OUT_DIR = 'C:/Users/Loro/.gemini/antigravity/brain/fc938256-e2cd-45cb-99ec-a6d5c97a5f0e/cierre_ciclo_produccion';

if (!fs.existsSync(OUT_DIR)) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
}

async function runCierreCiclo() {
  console.log('=== INICIANDO CIERRE DE CICLO COMPLETO E2E (MODO PRODUCCIÓN INSTITUCIONAL) ===');
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
  });
  const page = await context.newPage();

  page.on('console', msg => {
    if (msg.type() === 'error') console.log(`[BROWSER ERROR]: ${msg.text()}`);
  });

  // -------------------------------------------------------------
  // PASO 1: PORTAL PÚBLICO Y CATÁLOGO FORMATIVO
  // -------------------------------------------------------------
  console.log('\n[Paso 1/7] Verificando Landing Page y Catálogo Institucional...');
  await page.goto(`${BASE_URL}/`, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(OUT_DIR, '01_portal_publico_landing.png') });
  console.log('✓ Capturado 01_portal_publico_landing.png');

  // -------------------------------------------------------------
  // PASO 2: ADMISIÓN E INSCRIPCIÓN DE ASPIRANTE
  // -------------------------------------------------------------
  console.log('\n[Paso 2/7] Ejecutando Formulario de Admisión e Inscripción...');
  await page.goto(`${BASE_URL}/inscribirse`, { waitUntil: 'networkidle', timeout: 30000 });
  await page.fill('input[name="cedula"]', '28444555');
  await page.fill('input[name="primerNombre"]', 'María');
  await page.fill('input[name="segundoNombre"]', 'Alejandra');
  await page.fill('input[name="primerApellido"]', 'Pérez');
  await page.fill('input[name="segundoApellido"]', 'Silva');
  await page.fill('input[name="telefono"]', '0414-7654321');
  await page.fill('input[name="email"]', 'estudiante.pruebas@inces.gob.ve');
  await page.screenshot({ path: path.join(OUT_DIR, '02a_formulario_admision_paso1.png') });
  console.log('✓ Capturado 02a_formulario_admision_paso1.png');

  // Avanzar a paso 2
  await page.click('button:has-text("Continuar a Ubicación")');
  await page.waitForTimeout(1000);
  await page.fill('textarea[name="direccion"]', 'Urb. La Isabelica, Sector 3, Vereda 12, Valencia');
  await page.screenshot({ path: path.join(OUT_DIR, '02b_formulario_admision_paso2.png') });
  console.log('✓ Capturado 02b_formulario_admision_paso2.png');

  // Avanzar a paso 3 y enviar
  await page.click('button:has-text("Elegir Curso y Turno")');
  await page.waitForTimeout(1000);
  await page.screenshot({ path: path.join(OUT_DIR, '02c_formulario_admision_paso3.png') });
  console.log('✓ Capturado 02c_formulario_admision_paso3.png');

  await page.click('button:has-text("Enviar y Generar Planilla Oficial")');
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(OUT_DIR, '02d_admision_exitosa_con_folio.png') });
  console.log('✓ Capturado 02d_admision_exitosa_con_folio.png');

  // -------------------------------------------------------------
  // PASO 3: LOGIN INSTITUCIONAL MULTI-ROL
  // -------------------------------------------------------------
  console.log('\n[Paso 3/7] Verificando Pantalla de Login Institucional Split...');
  await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(1000);
  await page.screenshot({ path: path.join(OUT_DIR, '03_login_institucional_split.png') });
  console.log('✓ Capturado 03_login_institucional_split.png');

  // -------------------------------------------------------------
  // PASO 4: ADMINISTRACIÓN — PIZARRA MURAL Y CONTROL OPERATIVO
  // -------------------------------------------------------------
  console.log('\n[Paso 4/7] Autenticando como Administrador Maestro...');
  await page.fill('input[type="text"]', 'lorenzo-roca11@hotmail.com');
  await page.fill('input[type="password"]', 'Codenamelms33$');
  await page.click('button[type="submit"]');
  await page.waitForURL('**/operaciones', { timeout: 15000 });
  await page.waitForTimeout(2000);

  // Pizarra Mural MTP / PNA
  await page.screenshot({ path: path.join(OUT_DIR, '04a_admin_pizarra_mural_mtp_pna.png') });
  console.log('✓ Capturado 04a_admin_pizarra_mural_mtp_pna.png');

  // Horarios por Talleres
  await page.click('button:has-text("Horarios por Talleres")');
  await page.waitForTimeout(1000);
  await page.screenshot({ path: path.join(OUT_DIR, '04b_admin_horarios_por_talleres.png') });
  console.log('✓ Capturado 04b_admin_horarios_por_talleres.png');

  // Gestión Académica y Asignación de Secciones
  console.log('Navegando a Gestión Académica...');
  await page.click('a[href="/academica"]');
  await page.waitForURL('**/academica', { timeout: 15000 });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(OUT_DIR, '04c_admin_gestion_academica.png') });
  console.log('✓ Capturado 04c_admin_gestion_academica.png');

  // Comunidad y Roles (Docentes y Aprendices)
  console.log('Navegando a Comunidad y Roles...');
  await page.click('a[href="/comunidad"]');
  await page.waitForURL('**/comunidad', { timeout: 15000 });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(OUT_DIR, '04d_admin_comunidad_usuarios.png') });
  console.log('✓ Capturado 04d_admin_comunidad_usuarios.png');

  // Auditoría y Parámetros
  console.log('Navegando a Auditoría y Parámetros...');
  await page.click('a[href="/sistema"]');
  await page.waitForURL('**/sistema', { timeout: 15000 });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(OUT_DIR, '04e_admin_auditoria_sistema.png') });
  console.log('✓ Capturado 04e_admin_auditoria_sistema.png');

  // -------------------------------------------------------------
  // PASO 5: PORTAL DOCENTE Y TOMA DE ASISTENCIA
  // -------------------------------------------------------------
  console.log('\n[Paso 5/7] Autenticando como Docente con nuevas credenciales (docente.pruebas@inces.gob.ve)...');
  await page.click('button:has-text("Cerrar Sesión")');
  await page.waitForURL('**/login', { timeout: 15000 });

  await page.fill('input[type="text"]', 'docente.pruebas@inces.gob.ve');
  await page.fill('input[type="password"]', 'IncesPruebas2026!');
  await page.click('button[type="submit"]');

  await page.waitForURL('**/docente', { timeout: 15000 });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(OUT_DIR, '05a_portal_docente_horarios.png') });
  console.log('✓ Capturado 05a_portal_docente_horarios.png');

  // Registrar Asistencia
  console.log('Tomando asistencia de taller...');
  await page.click('button:has-text("Guardar Asistencia")');
  await page.waitForTimeout(1000);
  await page.screenshot({ path: path.join(OUT_DIR, '05b_portal_docente_asistencia_guardada.png') });
  console.log('✓ Capturado 05b_portal_docente_asistencia_guardada.png');

  // -------------------------------------------------------------
  // PASO 6: PORTAL APRENDIZ — CARNET DIGITAL Y PLANILLA OFICIAL
  // -------------------------------------------------------------
  console.log('\n[Paso 6/7] Autenticando como Estudiante con nuevas credenciales (estudiante.pruebas@inces.gob.ve)...');
  await page.click('button:has-text("Cerrar Sesión")');
  await page.waitForURL('**/login', { timeout: 15000 });

  await page.fill('input[type="text"]', 'estudiante.pruebas@inces.gob.ve');
  await page.fill('input[type="password"]', 'IncesPruebas2026!');
  await page.click('button[type="submit"]');

  await page.waitForURL('**/aprendiz', { timeout: 15000 });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(OUT_DIR, '06a_portal_aprendiz_carnet_digital.png') });
  console.log('✓ Capturado 06a_portal_aprendiz_carnet_digital.png');

  // Descargar Planilla Oficial
  console.log('Ejecutando descarga de Planilla Oficial PDF...');
  await page.click('button:has-text("Descargar Mi Planilla Oficial")');
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(OUT_DIR, '06b_portal_aprendiz_planilla_descargada.png') });
  console.log('✓ Capturado 06b_portal_aprendiz_planilla_descargada.png');

  // -------------------------------------------------------------
  // PASO 7: CIERRE DE CICLO Y RESUMEN
  // -------------------------------------------------------------
  await browser.close();
  console.log('\n=== CIERRE DE CICLO COMPLETADO 100% CON ÉXITO ===');
  console.log(`Todos los artefactos visuales fueron guardados en: ${OUT_DIR}`);
}

runCierreCiclo().catch(err => {
  console.error('Error durante cierre de ciclo:', err);
  process.exit(1);
});
