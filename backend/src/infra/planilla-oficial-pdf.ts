/**
 * Renderizador de la Planilla Oficial INCES física (612 × 792 pt, 1 página).
 *
 * Cumple con los requisitos de la auditoría y diseño técnico:
 *  - 612 × 792 pt (US Letter exacto).
 *  - Exactamente 1 página.
 *  - Embebe o sobreimprime sobre la plantilla oficial preimpresa preservando
 *    la fidelidad institucional completa (logos, sellos, títulos vectoriales).
 *  - Posicionamiento medido empíricamente sobre los 425 segmentos de rejilla.
 *  - Centrado geométrico milimétrico de marcas 'X' en casillas de verificación.
 *  - Sanitización a Latin-1 (WinAnsi) para evitar excepciones de codificación.
 *  - NO modifica ni depende del renderer genérico A4 (`planilla-pdf.ts`).
 */

import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { PDFDocument, StandardFonts, type PDFFont, type PDFPage, rgb } from 'pdf-lib';
import type { PlanillaOficialData } from '../dominio/planilla-oficial-tipos.js';

export const ANCHO_OFICIAL = 612.0;
export const ALTO_OFICIAL = 792.0;

const COLOR_TEXTO = rgb(0.05, 0.05, 0.15); // Azul tinta institucional oscuro
const COLOR_MARCA = rgb(0.1, 0.1, 0.1);     // Negro para casillas

function aLatin1(texto: string): string {
  let salida = '';
  for (const caracter of texto) {
    const codigo = caracter.codePointAt(0) ?? 0;
    if (codigo <= 0x7f) salida += caracter;
    else if (codigo === 0xa0) salida += ' ';
    else if (codigo >= 0xa1 && codigo <= 0xff) salida += caracter;
    else salida += '?';
  }
  return salida;
}

function dibujarTexto(
  page: PDFPage,
  texto: string | null | undefined,
  x: number,
  y: number,
  size: number,
  font: PDFFont,
  maxAncho?: number,
  color = COLOR_TEXTO,
): void {
  if (!texto) return;
  let str = aLatin1(String(texto).trim());
  if (!str) return;

  if (maxAncho && maxAncho > 0) {
    while (font.widthOfTextAtSize(str, size) > maxAncho && str.length > 3) {
      str = str.slice(0, -4) + '...';
    }
  }

  page.drawText(str, {
    x,
    y,
    size,
    font,
    color,
  });
}

/**
 * Centra matemáticamente el glifo 'X' en el centro geométrico (cx, cy) de la casilla.
 */
function dibujarMarcaCentrada(
  page: PDFPage,
  cx: number,
  cy: number,
  boldFont: PDFFont,
  size = 6.0,
): void {
  const w = boldFont.widthOfTextAtSize('X', size);
  const h = size * 0.718; // Cap-height estándar de HelveticaBold
  page.drawText('X', {
    x: cx - w / 2,
    y: cy - h / 2,
    size,
    font: boldFont,
    color: COLOR_MARCA,
  });
}

/**
 * Obtiene y valida la plantilla institucional; falla explícitamente si falta o está dañada.
 */
async function obtenerDocumentoBase(): Promise<PDFDocument> {
  const rutaActual = dirname(fileURLToPath(import.meta.url));
  const posiblesRutas = [
    join(rutaActual, '../../assets/planilla-oficial-template.pdf'),
    join(rutaActual, '../assets/planilla-oficial-template.pdf'),
    join(process.cwd(), 'backend/assets/planilla-oficial-template.pdf'),
    join(process.cwd(), 'assets/planilla-oficial-template.pdf'),
  ];

  for (const ruta of posiblesRutas) {
    if (existsSync(ruta)) {
      try {
        const bytes = readFileSync(ruta);
        const doc = await PDFDocument.load(bytes);
        const paginas = doc.getPages();
        if (paginas.length !== 1) {
          throw new Error(`se esperaba 1 página y se encontraron ${paginas.length}`);
        }
        const pagina = paginas[0];
        if (
          !pagina ||
          Math.abs(pagina.getWidth() - ANCHO_OFICIAL) > 0.5 ||
          Math.abs(pagina.getHeight() - ALTO_OFICIAL) > 0.5
        ) {
          const dimensiones = pagina ? `${pagina.getWidth()} × ${pagina.getHeight()}` : 'indisponibles';
          throw new Error(`dimensiones esperadas 612 × 792 pt; recibidas ${dimensiones}`);
        }
        return doc;
      } catch (error) {
        const detalle = error instanceof Error ? error.message : String(error);
        throw new Error(`PLANTILLA_PLANILLA_OFICIAL_INVALIDA: no se pudo cargar ${ruta}: ${detalle}`);
      }
    }
  }

  throw new Error('PLANTILLA_PLANILLA_OFICIAL_AUSENTE: no se encontró una plantilla PDF institucional válida.');
}

/**
 * Renderiza la Planilla Oficial física a un buffer PDF de exactamente 1 página (612 × 792 pt).
 */
export async function renderizarPlanillaOficialPdf(
  data: PlanillaOficialData,
): Promise<Uint8Array> {
  const doc = await obtenerDocumentoBase();
  const page = doc.getPages()[0] ?? doc.addPage([ANCHO_OFICIAL, ALTO_OFICIAL]);
  page.setSize(ANCHO_OFICIAL, ALTO_OFICIAL);

  const font = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);

  // 1. Encabezado
  dibujarTexto(page, data.cabecera.fecha, 250.0, 710.0, 7.0, font, 75);
  dibujarTexto(page, data.cabecera.numeroPreimpreso, 395.0, 710.0, 7.5, bold, 185);
  dibujarTexto(page, data.cabecera.proyecto, 275.0, 684.0, 7.0, font, 305);
  dibujarTexto(page, data.cabecera.espacioIntegralSocialista, 145.0, 659.0, 7.0, font, 180);
  dibujarTexto(page, data.cabecera.horario, 375.0, 659.0, 7.0, font, 205);

  // 2. Datos Personales: Identificación (Línea de nombres)
  dibujarTexto(page, data.identidad.primerNombre, 31.2, 586.0, 7.5, font, 102);
  dibujarTexto(page, data.identidad.segundoNombre, 141.0, 586.0, 7.5, font, 102);
  dibujarTexto(page, data.identidad.primerApellido, 250.0, 586.0, 7.5, font, 102);
  dibujarTexto(page, data.identidad.segundoApellido, 360.0, 586.0, 7.5, font, 102);
  dibujarTexto(page, data.identidad.cedula, 470.0, 586.0, 7.5, font, 108);

  // 3. Demografía y Nacimiento
  dibujarTexto(page, data.identidad.nacionalidad, 32.0, 547.0, 7.5, font, 125);
  dibujarTexto(page, data.nacimiento.dia, 171.0, 547.0, 7.5, font, 20);
  dibujarTexto(page, data.nacimiento.mes, 198.0, 547.0, 7.5, font, 20);
  dibujarTexto(page, data.nacimiento.anio, 221.0, 547.0, 7.5, font, 22);
  if (data.nacimiento.edad !== null && data.nacimiento.edad !== undefined) {
    dibujarTexto(page, String(data.nacimiento.edad), 251.0, 547.0, 7.5, font, 25);
  }

  // Género (Centrado exacto en casillas)
  if (data.sexo === 'F') dibujarMarcaCentrada(page, 307.12, 553.62, bold, 6.0);
  if (data.sexo === 'M') dibujarMarcaCentrada(page, 328.38, 553.62, bold, 6.0);

  // Estado Civil (Centrado exacto en casillas)
  if (data.estadoCivil === 'SOLTERO') dibujarMarcaCentrada(page, 354.88, 558.88, bold, 6.0);
  if (data.estadoCivil === 'CASADO') dibujarMarcaCentrada(page, 396.12, 558.88, bold, 6.0);
  if (data.estadoCivil === 'DIVORCIADO') dibujarMarcaCentrada(page, 437.12, 558.88, bold, 6.0);
  if (data.estadoCivil === 'VIUDO') dibujarMarcaCentrada(page, 374.62, 549.62, bold, 6.0);
  if (data.estadoCivil === 'CONCUBINATO') dibujarMarcaCentrada(page, 408.62, 549.62, bold, 6.0);

  // Pueblo Indígena (Centrado exacto en casillas SI: 511.12, NO: 541.88)
  if (data.puebloIndigena.pertenece === true) {
    dibujarMarcaCentrada(page, 511.12, 558.88, bold, 6.0);
    dibujarTexto(page, data.puebloIndigena.cual, 530.0, 547.0, 6.5, font, 50);
  } else if (data.puebloIndigena.pertenece === false) {
    dibujarMarcaCentrada(page, 541.88, 558.88, bold, 6.0);
  }

  // 4. Diversidad Funcional (Centrado exacto en casillas)
  if (data.discapacidad.fisicaMano) dibujarMarcaCentrada(page, 34.88, 506.12, bold, 6.0);
  if (data.discapacidad.sensorialCeguera) dibujarMarcaCentrada(page, 97.88, 506.12, bold, 6.0);
  if (data.discapacidad.fisicaPiernas) dibujarMarcaCentrada(page, 34.88, 496.88, bold, 6.0);
  if (data.discapacidad.debilidadIntelectual) dibujarMarcaCentrada(page, 97.88, 496.88, bold, 6.0);
  if (data.discapacidad.sensorialAuditiva) dibujarMarcaCentrada(page, 34.88, 487.62, bold, 6.0);
  if (data.discapacidad.ninguna) dibujarMarcaCentrada(page, 97.88, 487.62, bold, 6.0);
  dibujarTexto(page, data.discapacidad.indiqueCual, 85.0, 469.0, 6.0, font, 75);

  // Prácticas
  dibujarTexto(page, data.practicas.deporte.valor, 166.0, 476.0, 6.5, font, 90);
  dibujarTexto(page, data.practicas.deporte.desde, 262.0, 476.0, 6.5, font, 35);
  dibujarTexto(page, data.practicas.cultural.valor, 304.0, 476.0, 6.5, font, 90);
  dibujarTexto(page, data.practicas.cultural.desde, 397.0, 476.0, 6.5, font, 40);
  dibujarTexto(page, data.practicas.organizacion.valor, 445.0, 476.0, 6.5, font, 90);
  dibujarTexto(page, data.practicas.organizacion.desde, 539.0, 476.0, 6.5, font, 40);

  // 5. Ubicación y Contacto (Líneas elevadas para evitar colisión con bordes de celdas)
  dibujarTexto(page, data.ubicacion.estado, 65.0, 422.0, 7.0, font, 70);
  dibujarTexto(page, data.ubicacion.municipio, 185.0, 422.0, 7.0, font, 85);
  dibujarTexto(page, data.ubicacion.parroquia, 330.0, 422.0, 7.0, font, 110);
  dibujarTexto(page, data.ubicacion.comunidad, 495.0, 422.0, 7.0, font, 85);

  dibujarTexto(page, data.ubicacion.direccion, 31.2, 395.0, 7.0, font, 390);
  dibujarTexto(page, data.ubicacion.telefonoCelular, 429.0, 395.0, 7.0, font, 70);
  dibujarTexto(page, data.ubicacion.telefonoFijo, 507.0, 395.0, 7.0, font, 72);

  dibujarTexto(page, data.ubicacion.email, 115.0, 371.0, 7.0, font, 165);
  dibujarTexto(page, data.ubicacion.twitter, 315.0, 371.0, 7.0, font, 100);
  dibujarTexto(page, data.ubicacion.facebook, 460.0, 371.0, 7.0, font, 120);

  // 6. Familiares (hasta 5 filas)
  const yFilasFamiliares = [322.0, 304.5, 287.0, 269.5, 252.0];
  data.familiares.slice(0, 5).forEach((fam, idx) => {
    const yRow = yFilasFamiliares[idx];
    if (yRow === undefined) return;
    dibujarTexto(page, fam.cedula, 31.2, yRow, 6.5, font, 74);
    dibujarTexto(page, fam.nombres, 110.0, yRow, 6.5, font, 76);
    dibujarTexto(page, fam.apellidos, 190.0, yRow, 6.5, font, 82);
    dibujarTexto(page, fam.fechaNac, 276.0, yRow, 6.5, font, 67);
    dibujarTexto(page, fam.genero, 357.0, yRow, 6.5, font, 20);
    dibujarTexto(page, fam.parentesco, 381.0, yRow, 6.5, font, 62);
    dibujarTexto(page, fam.diversidadFuncional, 446.0, yRow, 6.5, font, 71);
    dibujarTexto(page, fam.estadoCivil, 521.0, yRow, 6.5, font, 60);
  });

  // 7. Misiones (Matriz 5 columnas x 4 filas con coordenadas medidas al milímetro)
  const xMisionesChecks = [34.88, 146.12, 257.12, 368.12, 479.12];
  const yMisionesFilas = [219.12, 205.12, 191.12, 177.12];
  const xMisionesDesde = [98.0, 205.0, 324.0, 435.0, 544.0];
  const yMisionesDesde = [217.5, 203.5, 189.5, 175.5];

  data.misiones.slice(0, 20).forEach((mis, idx) => {
    const col = Math.floor(idx / 4);
    const fila = idx % 4;
    const cx = xMisionesChecks[col];
    const cy = yMisionesFilas[fila];
    const xDesde = xMisionesDesde[col];
    const yDesde = yMisionesDesde[fila];

    if (cx !== undefined && cy !== undefined && mis.marcada) {
      dibujarMarcaCentrada(page, cx, cy, bold, 6.0);
      if (mis.desde && xDesde !== undefined && yDesde !== undefined) {
        dibujarTexto(page, mis.desde, xDesde, yDesde, 6.0, font, 40);
      }
    }
  });

function formatearNivelEducativoParaPdf(val: string | null | undefined): string | null {
  if (!val) return null;
  const s = String(val).trim();
  const upper = s.toUpperCase().replace(/[\s-]+/g, '_');
  const mapa: Record<string, string> = {
    'PRIMARIO': 'Educación Básica',
    'EDUCACION_BASICA': 'Educación Básica',
    'BASICA': 'Educación Básica',
    'PRIMARIA': 'Primaria',
    'SECUNDARIO': 'Educación Media General',
    'EDUCACION_MEDIA': 'Educación Media General',
    'EDUCACION_MEDIA_GENERAL': 'Educación Media General',
    'MEDIA_GENERAL': 'Educación Media General',
    'BACHILLER': 'Bachiller',
    'BACHILLERATO': 'Bachiller',
    'TECNICO': 'Técnico Medio',
    'TECNICO_MEDIO': 'Técnico Medio',
    'UNIVERSITARIO': 'Universitario',
    'TSU': 'T.S.U.',
    'PREGRADO': 'Universitario / Pregrado',
    'POSTGRADO': 'Postgrado',
  };
  return mapa[upper] ?? s;
}

  // 8. Formación (Centrado en casillas de avance y baselines elevadas)
  dibujarTexto(page, formatearNivelEducativoParaPdf(data.formacion.nivelEducativo), 31.2, 127.5, 7.0, font, 122);
  if (data.formacion.estadoAvance === 'CULMINO') dibujarMarcaCentrada(page, 163.88, 130.88, bold, 6.0);
  if (data.formacion.estadoAvance === 'NO_COMPLETO') dibujarMarcaCentrada(page, 204.88, 130.88, bold, 6.0);
  if (data.formacion.estadoAvance === 'EN_PROGRESO') dibujarMarcaCentrada(page, 259.88, 130.88, bold, 6.0);
  dibujarTexto(page, data.formacion.ultimoAnio, 312.0, 127.5, 7.0, font, 130);
  dibujarTexto(page, data.formacion.especialidad, 448.0, 127.5, 7.0, font, 132);

  // 9. Otras Formaciones
  const descOtras = data.otrasFormaciones.map((o) => o.descripcion).filter(Boolean).join('; ');
  dibujarTexto(page, descOtras, 31.2, 88.0, 7.0, font, 550);

  // 10. Experiencias Empíricas (Fila 1)
  const exp = data.experiencias[0];
  if (exp) {
    dibujarTexto(page, exp.area, 31.2, 38.0, 7.0, font, 133);
    dibujarTexto(page, exp.tiempoMeses, 170.0, 38.0, 7.0, font, 133);
    dibujarTexto(page, exp.portafolio ? 'SI' : 'NO', 309.0, 38.0, 7.0, font, 133);
    dibujarTexto(page, exp.enlace, 448.0, 38.0, 7.0, font, 133);
  }

  // 11. Espacio formal de firmas institucionales y pie de página de verificación
  dibujarTexto(page, 'Firma del Aspirante: ___________________________', 45.0, 14.0, 6.0, font);
  dibujarTexto(page, 'Firma y Sello CFS Receptor: ___________________________', 335.0, 14.0, 6.0, font);
  dibujarTexto(
    page,
    'Documento generado por INCES LMS - CFS Rafael Urdaneta (La Isabelica) - Válido para expediente interno',
    55.0,
    5.0,
    4.5,
    font,
    500,
    rgb(0.4, 0.4, 0.4),
  );

  return await doc.save();
}
