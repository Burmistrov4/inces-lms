import { chromium } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';

async function capturarVistas() {
  console.log('--- Iniciando captura visual para presentación institucional ---');
  const dirDestino = path.resolve('../docs/assets/production_ready');
  if (!fs.existsSync(dirDestino)) {
    fs.mkdirSync(dirDestino, { recursive: true });
  }

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1366, height: 768 },
  });
  const page = await context.newPage();

  page.on('console', msg => {
    if (msg.type() === 'error') {
      console.error(`[CONSOLE ERROR] ${msg.text()}`);
    }
  });

  const vistas = [
    {
      nombre: '01_landing_institucional.png',
      url: 'https://inces-lms.pages.dev/#/',
      descripcion: 'Portada pública y catálogo de formación técnica',
    },
    {
      nombre: '02_login_institucional.png',
      url: 'https://inces-lms.pages.dev/#/login',
      descripcion: 'Acceso seguro al sistema de gestión académica',
    },
    {
      nombre: '03_formulario_inscripcion.png',
      url: 'https://inces-lms.pages.dev/#/inscripcion',
      descripcion: 'Formulario dinámico de admisión con geografía en cascada',
    },
    {
      nombre: '04_restablecer_codigo.png',
      url: 'https://inces-lms.pages.dev/#/restablecer-codigo',
      descripcion: 'Canje seguro de código temporal de recuperación',
    },
  ];

  for (let i = 0; i < vistas.length; i++) {
    const v = vistas[i];
    console.log(`\n[${i + 1}/${vistas.length}] Capturando ${v.descripcion}...`);
    try {
      await page.goto(v.url, { waitUntil: 'networkidle', timeout: 35000 });
      await page.waitForTimeout(6000);
      const rutaArchivo = path.join(dirDestino, v.nombre);
      await page.screenshot({ path: rutaArchivo, fullPage: false });
      console.log(`✅ Guardado: ${rutaArchivo}`);
    } catch (e) {
      console.warn(`⚠️ Error capturando ${v.nombre}:`, e.message);
    }
  }

  await browser.close();
  console.log('\n--- Capturas completadas con éxito en docs/assets/production_ready/ ---');
}

capturarVistas().catch(err => {
  console.error('Error general en capturador visual:', err);
  process.exit(1);
});
