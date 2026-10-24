// Matriz responsive EXHAUSTIVA: cada apartado del sistema × cada perfil de
// ventana. Es opt-in (E2E_MATRIZ=1) para no alargar la suite normal: recorre
// 29 apartados × 5 perfiles = 145 capturas y tarda varios minutos.
//
// Por qué existe: la verificación anterior era "la landing a 5 anchos". Eso no
// es probar el sistema; es probar la portada. Aquí se entra con cada rol, se
// navega a CADA sección del menú y se captura a los 5 breakpoints canónicos de
// Material 3 (compact <600, medium 600-839, expanded 840-1199, large 1200-1599,
// extra-large >=1600).
//
// Cómo se detecta un desborde: en release Flutter RECORTA sin dibujar la franja
// de debug, así que no hay aviso. La señal programática es la geometría del
// árbol semántico: si un nodo termina más allá del ancho de la ventana
// (`x + width > ancho`), hay contenido que no cabe. Se registra el exceso
// máximo en px por sección/perfil para inspeccionar las capturas marcadas.
//
// La navegación se hace a un viewport ALTO (1280x1400) para que el menú lateral
// tenga visibles las 16 entradas del admin; luego se redimensiona a cada perfil
// para capturar. Navegar a 390 px no serviría: la entrada estaría en el cajón.
import { test, type Page } from '@playwright/test';
import path from 'node:path';
import fs from 'node:fs';
import { LoginPage, SENAL_DE_SESION, SENAL_DE_SESION_ALUMNO } from '../src/pages/LoginPage.js';
import { FlutterApp } from '../src/pages/FlutterApp.js';

test.skip(process.env.E2E_MATRIZ !== '1', 'Matriz responsive: opt-in con E2E_MATRIZ=1');

const ADMIN = {
  email: process.env.E2E_ADMIN_EMAIL ?? 'lorenzo-roca11@hotmail.com',
  pass: process.env.E2E_ADMIN_PASSWORD ?? 'Codenamelms33$',
};
const DOCENTE = {
  email: process.env.E2E_DOCENTE_EMAIL ?? 'docente@semilla.invalid',
  pass: process.env.E2E_DOCENTE_PASSWORD ?? 'SemillaInces26!',
};
const ALUMNO = {
  email: process.env.E2E_ALUMNO_EMAIL ?? 'estudiante1@semilla.invalid',
  pass: process.env.E2E_ALUMNO_PASSWORD ?? 'SemillaInces26!',
};

// Las 16 secciones del admin, tal como las declara `admin_dashboard.dart`.
const SECCIONES_ADMIN = [
  'Centro de Mando',
  'Módulos del Sistema',
  'Configuración del Centro',
  'Historial de Configuración',
  'Registro de Inicios de Sesión / Accesos',
  'Usuarios y Roles',
  'Programas Académicos',
  'Inscripciones y Cupos',
  'Campos de Inscripción',
  'Secciones del Período',
  'Lapsos Académicos',
  'Archivos del Centro',
  'Cuadrante de Horarios',
  'Espacios y Aulas',
  'Guardias Docentes',
  'Mi Perfil',
];

// Las 5 del docente (`docente_dashboard.dart`).
const SECCIONES_DOCENTE = [
  'Mis aulas',
  'Pasar lista',
  'Calificaciones',
  'Guías y materiales',
  'Mi horario',
];

// Las 8 del estudiante (`aspirante_dashboard.dart`).
const SECCIONES_ALUMNO = [
  'Mis aulas',
  'Marcar asistencia',
  'Mis tareas',
  'Inscribirme en un curso',
  'Mis inscripciones',
  'Mi inscripción',
  'Guías y materiales',
  'Mi Perfil',
];

// Los cinco perfiles canónicos de Material 3, con alturas realistas de cada
// dispositivo (móvil vertical, tablet vertical, tablet horizontal, laptop,
// monitor de escritorio).
const PERFILES = [
  { w: 390, h: 844, nombre: '390-movil' },
  { w: 600, h: 960, nombre: '600-tablet' },
  { w: 840, h: 900, nombre: '840-tablet-horizontal' },
  // Móvil en HORIZONTAL: ancho `expanded` (844) pero altura `compact` (390).
  // Es el caso que Material 3 advierte: el ancho sugiere doble panel, pero el
  // alto no lo permite. Sin este perfil, esa combinación nunca se probaba.
  { w: 844, h: 390, nombre: '844-movil-horizontal' },
  { w: 1280, h: 800, nombre: '1280-laptop' },
  { w: 1700, h: 1000, nombre: '1700-escritorio' },
];

// Viewport de navegación: alto para que el menú lateral muestre todas las
// entradas del admin sin tener que hacer scroll.
const NAV = { width: 1280, height: 1400 };

const DIR = path.resolve('../docs/assets/matriz');

interface FilaMatriz {
  rol: string;
  seccion: string;
  perfil: string;
  navegable: boolean;
  pageerrors?: number;
  desbordeMaxPx?: number;
  nodosDesbordados?: number;
  archivo?: string;
  detalle?: string;
  /** El panel mostro el aviso de error: no cargo datos del backend. */
  sinDatos?: boolean;
}

const reporte: FilaMatriz[] = [];

/** Slug ASCII para nombres de archivo estables. */
function slug(texto: string): string {
  return texto
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

/**
 * Exceso horizontal máximo (px) de cualquier nodo semántico respecto al ancho
 * de la ventana. >0 significa que hay contenido que no cabe en el viewport.
 */
async function medirDesborde(
  page: Page,
  ancho: number,
): Promise<{
  max: number;
  cuantos: number;
  total: number;
  peor?: { texto: string; x: number; w: number };
}> {
  return page.evaluate((w) => {
    let max = 0;
    let cuantos = 0;
    let total = 0;
    let peor: { texto: string; x: number; w: number } | undefined;

    // **Un nodo dentro de un scroll horizontal NO desborda.** Medido el
    // 2026-10-23: la pizarra de guardias vive dentro de un
    // `SingleChildScrollView` horizontal, así que su contenido pasa de largo
    // el viewport a propósito —el usuario lo desplaza—. Medirlo contra el ancho
    // de la ventana daba un rojo falso de 197 px. Un desborde de verdad es el
    // que se sale de la pantalla **y** de todo ancestro que pueda desplazarse.
    const enScrollHorizontal = (n: Element): boolean => {
      let p: Element | null = n.parentElement;
      while (p) {
        const st = getComputedStyle(p);
        if (
          (st.overflowX === 'auto' || st.overflowX === 'scroll') &&
          p.scrollWidth > p.clientWidth
        ) {
          return true;
        }
        p = p.parentElement;
      }
      return false;
    };

    for (const nodo of [...document.querySelectorAll('flt-semantics')]) {
      const r = nodo.getBoundingClientRect();
      total++;
      if (r.width <= 0) continue;
      const exceso = r.x + r.width - w;
      if (exceso > 2 && !enScrollHorizontal(nodo)) {
        cuantos++;
        if (exceso > max) {
          max = exceso;
          // Se guarda el nodo PEOR para saber qué desborda, no sólo cuánto.
          peor = {
            texto: (nodo.textContent ?? '').trim().slice(0, 70),
            x: Math.round(r.x),
            w: Math.round(r.width),
          };
        }
      }
    }
    return { max: Math.round(max), cuantos, total, peor };
  }, ancho);
}

test.describe.configure({ mode: 'serial' });

test.beforeAll(() => {
  fs.mkdirSync(DIR, { recursive: true });
});

/**
 * El texto del breadcrumb actual (concatenación de los nodos de su fila).
 *
 * **Por qué comparar antes/después y no buscar el nombre de la sección.** El
 * breadcrumb usa etiquetas CORTAS que no coinciden con el título del menú
 * (`Módulos del Sistema` → «Módulos», `Lapsos Académicos` → «Lapsos»,
 * `Registro de Inicios de Sesión / Accesos` → «Accesos», etc.), así que buscar
 * el título completo daba 6 falsos «no navegables» (medido el 2026-10-21). Si
 * el breadcrumb CAMBIA al pulsar, la vista cambió; si no, no.
 */
async function breadcrumbActual(page: Page): Promise<string> {
  return page.evaluate(() => {
    const partes: string[] = [];
    for (const nodo of document.querySelectorAll('flt-semantics')) {
      const r = nodo.getBoundingClientRect();
      if (r.y < 85 || r.y > 130) continue; // fila del breadcrumb
      const t = (nodo.textContent ?? '').trim();
      if (t) partes.push(t);
    }
    return partes.join(' › ');
  });
}

async function correrRol(
  page: Page,
  rol: string,
  cred: { email: string; pass: string },
  senal: string,
  secciones: string[],
): Promise<void> {
  test.setTimeout(1_800_000); // 30 min de margen para un rol completo.
  const login = new LoginPage(page);

  const errores: string[] = [];
  page.on('pageerror', (e) => errores.push(String(e)));
  // **Peticiones fallidas:** medido el 2026-10-23, 72 de 186 capturas
  // cargaban sin datos y la matriz no lo veia. Esto dice QUE url falla y POR QUE.
  page.on('requestfailed', (r) =>
    console.log(
      `    [FALLO] ${r.method()} ${r.url()} :: ${r.failure()?.errorText}`,
    ),
  );

  // **El viewport alto se pone DESPUES de iniciar sesion.** Medido el
  // 2026-10-23: con 1280x1400 el motor de Flutter tarda 22 s en montar, frente
  // a 8,8 s con el viewport por defecto; con la maquina cargada pasaba de los
  // 60 s del timeout y el login caducaba (tres roles sin arrancar).
  try {
    await login.abrir();
    await login.entrar(cred.email, cred.pass, senal);
    await page.waitForTimeout(3500);
    await page.setViewportSize(NAV);
  } catch (e) {
    reporte.push({
      rol,
      seccion: '(login)',
      perfil: '(login)',
      navegable: false,
      detalle: String(e).slice(0, 400),
    });
    console.log(`[${rol}] LOGIN FALLÓ: ${String(e).slice(0, 240)}`);
    return;
  }

  let breadcrumbPrevio = '';
  for (const seccion of secciones) {
    // `pulsar` (dispatchEvent) es el gesto medido para ENTRADAS DE MENÚ; el
    // click real (`pulsarReal`) es para abrir modales y aquí dejaba la vista
    // clavada en «Centro de Mando» (medido el 2026-10-21: todas las capturas
    // salían con ese breadcrumb).
    let navego = false;
    try {
      await login.app.pulsar(seccion);
      await page.waitForTimeout(2200);
      const actual = await breadcrumbActual(page);
      navego = actual !== breadcrumbPrevio;
      breadcrumbPrevio = actual;
    } catch (e) {
      reporte.push({
        rol,
        seccion,
        perfil: '(nav)',
        navegable: false,
        detalle: String(e).slice(0, 300),
      });
      console.log(`[${rol}] ${seccion}: NO PULSABLE`);
      continue;
    }

    if (!navego) {
      reporte.push({
        rol,
        seccion,
        perfil: '(nav)',
        navegable: false,
        detalle: 'la vista no quedó en la sección (breadcrumb)',
      });
      console.log(`[${rol}] ${seccion}: NO NAVEGÓ`);
      continue;
    }

    for (const perfil of PERFILES) {
      const antes = errores.length;
      await page.setViewportSize({ width: perfil.w, height: perfil.h });
      await page.waitForTimeout(1800); // reflow + repintado de CanvasKit

      const desborde = await medirDesborde(page, perfil.w);

      // **Comprobacion de datos.** Medido el 2026-10-22: la matriz media
      // desbordes pero no si el panel habia cargado datos; una corrida con el
      // backend caido dio 0 desbordes con paneles vacios. Ahora se detecta el
      // aviso de error del panel.
      const sinDatos = await page.evaluate(() =>
        [...document.querySelectorAll('flt-semantics')].some((n) =>
          (n.textContent ?? '').includes('No pudimos conectar'),
        ),
      );

      const carpeta = path.join(DIR, rol);
      fs.mkdirSync(carpeta, { recursive: true });
      const archivo = path.join(carpeta, `${slug(seccion)}__${perfil.nombre}.png`);
      await page.screenshot({ path: archivo, fullPage: false });

      const fila: FilaMatriz = {
        rol,
        seccion,
        perfil: perfil.nombre,
        navegable: true,
        pageerrors: errores.length - antes,
        desbordeMaxPx: desborde.max,
        nodosDesbordados: desborde.cuantos,
        archivo,
        sinDatos,
      };
      reporte.push(fila);

      const marca = desborde.max > 2 ? '  <<< DESBORDE' : '';
      const marcaDatos = sinDatos ? '  <<< SIN DATOS (backend caido)' : '';
      const detalle = desborde.peor
        ? ` | peor: x=${desborde.peor.x} w=${desborde.peor.w} "${desborde.peor.texto}"`
        : '';
      console.log(
        `[${rol}] ${seccion} @ ${perfil.nombre}: desborde=${desborde.max}px ` +
          `nodos=${desborde.cuantos} pageerrors=${fila.pageerrors}${marca}${marcaDatos}${detalle}`,
      );
    }

    await page.setViewportSize(NAV);
    await page.waitForTimeout(800);
  }
}

test('matriz - admin (16 apartados x 5 perfiles)', async ({ page }) => {
  await correrRol(page, 'admin', ADMIN, SENAL_DE_SESION, SECCIONES_ADMIN);
});

test('matriz - docente (5 apartados x 5 perfiles)', async ({ page }) => {
  await correrRol(page, 'docente', DOCENTE, 'Mis aulas', SECCIONES_DOCENTE);
});

test('matriz - estudiante (8 apartados x 5 perfiles)', async ({ page }) => {
  await correrRol(page, 'estudiante', ALUMNO, SENAL_DE_SESION_ALUMNO, SECCIONES_ALUMNO);
});

// Superficies públicas: no requieren sesión ni backend de datos, así que se
// prueban completas en todos los perfiles. Son las que ve un aspirante antes
// de entrar —tan críticas como los paneles y nunca verificadas a 5 anchos—.
test('matriz - superficies publicas (login, inscripcion) x perfiles', async ({ page }) => {
  test.setTimeout(600_000);
  const app = new FlutterApp(page);
  const errores: string[] = [];
  page.on('pageerror', (e) => errores.push(String(e)));
  // **Peticiones fallidas:** medido el 2026-10-23, 72 de 186 capturas
  // cargaban sin datos y la matriz no lo veia. Esto dice QUE url falla y POR QUE.
  page.on('requestfailed', (r) =>
    console.log(
      `    [FALLO] ${r.method()} ${r.url()} :: ${r.failure()?.errorText}`,
    ),
  );

  const rutas = [
    { ruta: '/#/login', nombre: 'login' },
    { ruta: '/#/inscripcion', nombre: 'inscripcion' },
  ];

  for (const { ruta, nombre } of rutas) {
    for (const perfil of PERFILES) {
      const antes = errores.length;
      await page.setViewportSize({ width: perfil.w, height: perfil.h });

      try {
        await app.abrir(ruta);
      } catch (e) {
        reporte.push({
          rol: 'publico',
          seccion: nombre,
          perfil: perfil.nombre,
          navegable: false,
          detalle: String(e).slice(0, 200),
        });
        console.log(`[publico] ${nombre} @ ${perfil.nombre}: NO ABRIÓ`);
        continue;
      }

      await page.waitForTimeout(4000); // CanvasKit pinta el primer frame

      const desborde = await medirDesborde(page, perfil.w);
      const carpeta = path.join(DIR, 'publico');
      fs.mkdirSync(carpeta, { recursive: true });
      const archivo = path.join(carpeta, `${nombre}__${perfil.nombre}.png`);
      await page.screenshot({ path: archivo, fullPage: false });

      reporte.push({
        rol: 'publico',
        seccion: nombre,
        perfil: perfil.nombre,
        navegable: true,
        pageerrors: errores.length - antes,
        desbordeMaxPx: desborde.max,
        nodosDesbordados: desborde.cuantos,
        archivo,
      });
      console.log(
        `[publico] ${nombre} @ ${perfil.nombre}: desborde=${desborde.max}px ` +
          `pageerrors=${errores.length - antes}`,
      );
    }
  }
});

test.afterAll(() => {
  const destino = path.join(DIR, 'reporte.json');
  fs.writeFileSync(destino, JSON.stringify(reporte, null, 2), 'utf8');

  const capturadas = reporte.filter((r) => r.navegable);
  const conDesborde = capturadas.filter((r) => (r.desbordeMaxPx ?? 0) > 2);
  const noNavegables = reporte.filter((r) => !r.navegable);
  const conErrores = capturadas.filter((r) => (r.pageerrors ?? 0) > 0);

  console.log('\n================ RESUMEN DE LA MATRIZ ================');
  console.log(`  Capturas:        ${capturadas.length}`);
  console.log(`  Con desborde:    ${conDesborde.length}`);
  console.log(`  Con pageerrors:  ${conErrores.length}`);
  console.log(`  No navegables:   ${noNavegables.length}`);
  if (conDesborde.length > 0) {
    console.log('\n  DESBORDES (sección @ perfil -> exceso px):');
    for (const r of conDesborde) {
      console.log(`   · ${r.rol}/${r.seccion} @ ${r.perfil} -> ${r.desbordeMaxPx}px`);
    }
  }
  if (noNavegables.length > 0) {
    console.log('\n  NO NAVEGABLES:');
    for (const r of noNavegables) {
      console.log(`   · ${r.rol}/${r.seccion}`);
    }
  }
  console.log(`\n  Informe: ${destino}`);
  console.log('======================================================\n');
});
