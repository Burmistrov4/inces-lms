import { chromium } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';

const BRAIN_DIR = 'C:/Users/Loro/.gemini/antigravity/brain/fc938256-e2cd-45cb-99ec-a6d5c97a5f0e';
const LEGACY_DIR = path.join(BRAIN_DIR, 'capturas_sistema_anterior');
const V2_DIR = path.join(BRAIN_DIR, 'capturas_sistema_nuevo_v2');

[LEGACY_DIR, V2_DIR].forEach(dir => {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
});

async function main() {
  console.log('=== INICIANDO AUDITORÍA VISUAL COMPARATIVA COMPLETA: LEGACY VS V2 ===');

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 1,
  });
  const page = await context.newPage();

  // -------------------------------------------------------------
  // FASE 1: CAPTURAS DEL SISTEMA ANTERIOR (FLUTTER WEB EN :8090)
  // -------------------------------------------------------------
  console.log('\n--- FASE 1: SISTEMA ANTERIOR (FLUTTER WEB) ---');
  const LEGACY_URL = 'http://127.0.0.1:8090';

  try {
    console.log('[Legacy 1/5] Accediendo a Landing pública / Admisión...');
    await page.goto(`${LEGACY_URL}/#/inscripcion`, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await page.waitForTimeout(4000);
    await page.screenshot({ path: path.join(LEGACY_DIR, '01_legacy_inscripcion_aspirante.png') });
    console.log('✓ Capturado 01_legacy_inscripcion_aspirante.png');
  } catch (e) {
    console.warn('Nota Legacy 1:', e.message);
  }

  try {
    console.log('[Legacy 2/5] Accediendo a Pantalla de Login...');
    await page.goto(`${LEGACY_URL}/#/login`, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await page.waitForTimeout(4000);
    await page.screenshot({ path: path.join(LEGACY_DIR, '02_legacy_login_screen.png') });
    console.log('✓ Capturado 02_legacy_login_screen.png');
  } catch (e) {
    console.warn('Nota Legacy 2:', e.message);
  }

  // Copiar capturas fidedignas de dashboards legacy existentes en docs/assets/dashboards
  const docsDir = 'C:/Users/Loro/Desktop/Cuarto Semestre/1. Servicio Comunitario/INCES-LMS-PROJECT/docs/assets/dashboards';
  if (fs.existsSync(docsDir)) {
    const archivosDocs = fs.readdirSync(docsDir);
    archivosDocs.forEach(arch => {
      const origen = path.join(docsDir, arch);
      const destino = path.join(LEGACY_DIR, `legacy_${arch}`);
      fs.copyFileSync(origen, destino);
      console.log(`✓ Copiado archivo institucional previo: legacy_${arch}`);
    });
  }

  // -------------------------------------------------------------
  // FASE 2: CAPTURAS EXHAUSTIVAS DEL SISTEMA NUEVO V2 (:3000)
  // -------------------------------------------------------------
  console.log('\n--- FASE 2: SISTEMA NUEVO V2 (REACT + TAILWIND) ---');
  const V2_URL = 'http://127.0.0.1:3000';

  // 1. Landing Page
  console.log('[V2 1/12] Landing Page Oficial con Catálogo de Formación...');
  await page.goto(`${V2_URL}/`, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(V2_DIR, '01_v2_landing_institucional.png') });
  console.log('✓ Capturado 01_v2_landing_institucional.png');

  // 2. Formulario de Inscripción y Generación de Folio
  console.log('[V2 2/12] Formulario Público de Inscripción en 3 pasos...');
  await page.goto(`${V2_URL}/inscribirse`, { waitUntil: 'networkidle', timeout: 30000 });
  await page.fill('input[name="cedula"]', '28444555');
  await page.fill('input[name="primerNombre"]', 'María');
  await page.fill('input[name="segundoNombre"]', 'Alejandra');
  await page.fill('input[name="primerApellido"]', 'Pérez');
  await page.fill('input[name="segundoApellido"]', 'Silva');
  await page.fill('input[name="telefono"]', '0414-7654321');
  await page.fill('input[name="email"]', 'estudiante.pruebas@inces.gob.ve');
  await page.screenshot({ path: path.join(V2_DIR, '02a_v2_formulario_admision_paso1.png') });

  await page.click('button:has-text("Continuar a Ubicación")');
  await page.waitForTimeout(800);
  await page.fill('textarea[name="direccion"]', 'Urb. La Isabelica, Sector 3, Vereda 12, Valencia');
  await page.screenshot({ path: path.join(V2_DIR, '02b_v2_formulario_admision_paso2.png') });

  await page.click('button:has-text("Elegir Curso y Turno")');
  await page.waitForTimeout(800);
  await page.screenshot({ path: path.join(V2_DIR, '02c_v2_formulario_admision_paso3.png') });

  await page.click('button:has-text("Enviar y Generar Planilla Oficial")');
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(V2_DIR, '02d_v2_admision_exitosa_con_folio.png') });
  console.log('✓ Capturado 02d_v2_admision_exitosa_con_folio.png');

  // 3. Login Split Institucional & Autenticación Cédula
  console.log('[V2 3/12] Login Split Institucional con resolución de cédula...');
  await page.goto(`${V2_URL}/login`, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(1000);
  await page.screenshot({ path: path.join(V2_DIR, '03a_v2_login_split_institucional.png') });

  // Test cédula con formato venezolano V-15.888.999 o 15888999
  console.log('Probando resolución de cédula docente...');
  await page.fill('input[type="text"]', 'V-15888999');
  await page.fill('input[type="password"]', 'IncesPruebas2026!');
  await page.screenshot({ path: path.join(V2_DIR, '03b_v2_login_input_cedula_docente.png') });

  // 4. Login como Administrador Maestro
  console.log('[V2 4/12] Login de Administrador...');
  await page.fill('input[type="text"]', 'lorenzo-roca11@hotmail.com');
  await page.fill('input[type="password"]', 'Codenamelms33$');
  await page.click('button[type="submit"]');
  await page.waitForURL('**/operaciones', { timeout: 15000 });
  await page.waitForTimeout(2000);

  // 5. Pizarra Mural MTP / PNA
  console.log('[V2 5/12] Operaciones: Pizarra Mural MTP / PNA...');
  await page.screenshot({ path: path.join(V2_DIR, '04a_v2_pizarra_mural_mtp_pna.png') });

  // Asignar una guardia reactiva en caliente
  console.log('Abriendo modal de asignación de guardia...');
  const btnAsignar = page.locator('button:has-text("Asignar")').first();
  if (await btnAsignar.count() > 0) {
    await btnAsignar.click();
    await page.waitForTimeout(800);
    await page.screenshot({ path: path.join(V2_DIR, '04b_v2_modal_asignacion_guardia.png') });
    await page.click('button:has-text("Confirmar Asignación")');
    await page.waitForTimeout(1000);
    await page.screenshot({ path: path.join(V2_DIR, '04c_v2_guardia_asignada_persistida.png') });
  }

  // Horarios de Talleres
  console.log('Cambiando a vista Horarios por Talleres...');
  await page.click('button:has-text("Horarios por Talleres")');
  await page.waitForTimeout(1000);
  await page.screenshot({ path: path.join(V2_DIR, '04d_v2_horarios_talleres_lun_sab.png') });

  // 6. Gestión Académica
  console.log('[V2 6/12] Gestión Académica: Secciones y Descarga Planilla/Excel...');
  await page.click('a[href="/academica"]');
  await page.waitForURL('**/academica', { timeout: 15000 });
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(V2_DIR, '05_v2_gestion_academica.png') });

  // 7. Comunidad y Roles
  console.log('[V2 7/12] Comunidad y Roles: Docentes, Aprendices e Invitaciones...');
  await page.click('a[href="/comunidad"]');
  await page.waitForURL('**/comunidad', { timeout: 15000 });
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(V2_DIR, '06_v2_comunidad_usuarios.png') });

  // 8. Gestor de Archivos Cloudflare R2
  console.log('[V2 8/12] Gestor de Archivos en la Nube (R2)...');
  await page.click('a[href="/archivos"]');
  await page.waitForURL('**/archivos', { timeout: 15000 });
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(V2_DIR, '07_v2_archivos_r2.png') });

  // 9. Sistema y Auditoría de Seguridad
  console.log('[V2 9/12] Auditoría y Seguridad...');
  await page.click('a[href="/sistema"]');
  await page.waitForURL('**/sistema', { timeout: 15000 });
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(V2_DIR, '08_v2_auditoria_seguridad.png') });

  // 10. Configuración y Parámetros del CFS
  console.log('[V2 10/12] Parámetros del Centro CFS La Isabelica...');
  await page.click('a[href="/configuracion"]');
  await page.waitForURL('**/configuracion', { timeout: 15000 });
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(V2_DIR, '09a_v2_configuracion_cfs_la_isabelica.png') });
  await page.click('button:has-text("Guardar Cambios")');
  await page.waitForTimeout(800);
  await page.screenshot({ path: path.join(V2_DIR, '09b_v2_configuracion_guardada_exito.png') });

  // 11. Portal Docente (Con credenciales de prueba generadas)
  console.log('[V2 11/12] Acceso Portal Docente con cédula/correo de pruebas...');
  await page.click('button:has-text("Cerrar Sesión")');
  await page.waitForURL('**/login', { timeout: 15000 });

  await page.fill('input[type="text"]', 'docente.pruebas@inces.gob.ve');
  await page.fill('input[type="password"]', 'IncesPruebas2026!');
  await page.click('button[type="submit"]');
  await page.waitForURL('**/docente', { timeout: 15000 });
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(V2_DIR, '10a_v2_portal_docente_facilitador.png') });

  // Registrar asistencia
  console.log('Guardando asistencia de taller...');
  await page.click('button:has-text("Guardar Asistencia")');
  await page.waitForTimeout(1000);
  await page.screenshot({ path: path.join(V2_DIR, '10b_v2_portal_docente_asistencia_asentada.png') });

  // 12. Portal Aprendiz (Carnet Digital INCES + Planilla Oficial PDF)
  console.log('[V2 12/12] Acceso Portal Aprendiz con cédula/correo de pruebas...');
  await page.click('button:has-text("Cerrar Sesión")');
  await page.waitForURL('**/login', { timeout: 15000 });

  await page.fill('input[type="text"]', 'estudiante.pruebas@inces.gob.ve');
  await page.fill('input[type="password"]', 'IncesPruebas2026!');
  await page.click('button[type="submit"]');
  await page.waitForURL('**/aprendiz', { timeout: 15000 });
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(V2_DIR, '11a_v2_portal_aprendiz_carnet_digital.png') });

  // Descargar Planilla Oficial PDF
  console.log('Descargando planilla oficial calibrada...');
  await page.click('button:has-text("Descargar Mi Planilla Oficial")');
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(V2_DIR, '11b_v2_portal_aprendiz_descarga_confirmada.png') });

  await browser.close();
  console.log('\n=== AUDITORÍA VISUAL COMPARATIVA COMPLETADA CON ÉXITO ===');
  console.log(`Carpeta Anterior: ${LEGACY_DIR}`);
  console.log(`Carpeta V2: ${V2_DIR}`);
}

main().catch(err => {
  console.error('Error durante la auditoría:', err);
  process.exit(1);
});
