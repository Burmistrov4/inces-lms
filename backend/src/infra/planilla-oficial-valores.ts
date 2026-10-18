import type {
  PlanillaOficialData,
  ContextoPlanillaOficial,
  FamiliarOficial,
  MisionOficial,
  OtraFormacionOficial,
  ExperienciaOficial,
  EstadoAvanceFormacion,
} from '../dominio/planilla-oficial-tipos.js';
import type { EntradaPlanilla } from './planilla-valores.js';
import { esVerdadero } from './planilla-valores.js';

export const MISIONES_OFICIALES_ORDENADAS: Array<{ codigo: string; etiqueta: string }> = [
  // Columna 1
  { codigo: 'RIBAS', etiqueta: 'Ribas' },
  { codigo: 'MERCAL', etiqueta: 'Mercal' },
  { codigo: 'MADRES_DEL_BARRIO', etiqueta: 'Madres del Barrio' },
  { codigo: 'HABITAT', etiqueta: 'Hábitat' },
  // Columna 2
  { codigo: 'PIAR', etiqueta: 'PIAR' },
  { codigo: 'NEGRA_HIPOLITA', etiqueta: 'Negra Hipólita' },
  { codigo: 'BARRIO_ADENTRO', etiqueta: 'Barrio Adentro' },
  { codigo: 'MIRANDA', etiqueta: 'Miranda' },
  // Columna 3
  { codigo: 'IDENTIDAD', etiqueta: 'Identidad' },
  { codigo: 'CASA_DE_ALIMENTACION', etiqueta: 'Casa de Alimentación' },
  { codigo: 'GUAICAIPURO', etiqueta: 'Guaicaipuro' },
  { codigo: 'ROBINSON_I_Y_II', etiqueta: 'Robinson I y II' },
  // Columna 4
  { codigo: 'HIJOS_DE_VZLA', etiqueta: 'Hijos de Venezuela' },
  { codigo: 'SUCRE', etiqueta: 'Sucre' },
  { codigo: 'VUELVAN_CARAS', etiqueta: 'Vuelvan Caras' },
  { codigo: 'VUELVAN_CARAS_JOVENES', etiqueta: 'Vuelvan Caras Jóvenes' },
  // Columna 5
  { codigo: 'GM_VIVIENDA_VZLA', etiqueta: 'Gran Misión Vivienda Venezuela' },
  { codigo: 'GM_AGROVENEZUELA', etiqueta: 'Gran Misión Agrovenezuela' },
  { codigo: 'GM_SABER_Y_TRABAJO', etiqueta: 'Gran Misión Saber y Trabajo' },
  { codigo: 'NINGUNA', etiqueta: 'Ninguna' },
];

function str(val: unknown): string | null {
  if (val === undefined || val === null) return null;
  const s = String(val).trim();
  return s.length > 0 ? s : null;
}

function calcularEdad(fechaIsoOTexto: string | null): number | null {
  if (!fechaIsoOTexto) return null;
  const matchIso = /^(\d{4})-(\d{2})-(\d{2})/.exec(fechaIsoOTexto);
  if (matchIso) {
    const [_, a, m, d] = matchIso;
    const nac = new Date(Number(a), Number(m) - 1, Number(d));
    if (isNaN(nac.getTime())) return null;
    const hoy = new Date();
    let edad = hoy.getFullYear() - nac.getFullYear();
    const mesDiff = hoy.getMonth() - nac.getMonth();
    if (mesDiff < 0 || (mesDiff === 0 && hoy.getDate() < nac.getDate())) {
      edad--;
    }
    return edad >= 0 && edad <= 120 ? edad : null;
  }

  const matchVen = /^(\d{2})[/-](\d{2})[/-](\d{4})/.exec(fechaIsoOTexto);
  if (matchVen) {
    const [_, d, m, a] = matchVen;
    const nac = new Date(Number(a), Number(m) - 1, Number(d));
    if (isNaN(nac.getTime())) return null;
    const hoy = new Date();
    let edad = hoy.getFullYear() - nac.getFullYear();
    const mesDiff = hoy.getMonth() - nac.getMonth();
    if (mesDiff < 0 || (mesDiff === 0 && hoy.getDate() < nac.getDate())) {
      edad--;
    }
    return edad >= 0 && edad <= 120 ? edad : null;
  }
  return null;
}

function desglosarFechaNac(fechaTexto: string | null): {
  dia: string | null;
  mes: string | null;
  anio: string | null;
} {
  if (!fechaTexto) return { dia: null, mes: null, anio: null };
  const iso = /^(\d{4})-(\d{2})-(\d{2})/.exec(fechaTexto);
  if (iso) {
    return { dia: iso[3] ?? null, mes: iso[2] ?? null, anio: iso[1] ?? null };
  }
  const ven = /^(\d{2})[/-](\d{2})[/-](\d{4})/.exec(fechaTexto);
  if (ven) {
    return { dia: ven[1] ?? null, mes: ven[2] ?? null, anio: ven[3] ?? null };
  }
  return { dia: null, mes: null, anio: null };
}

function normalizarSexo(val: unknown): 'F' | 'M' | null {
  const s = str(val)?.toUpperCase();
  if (!s) return null;
  if (s.startsWith('F')) return 'F';
  if (s.startsWith('M')) return 'M';
  return null;
}

function normalizarEstadoCivil(val: unknown): 'SOLTERO' | 'CASADO' | 'DIVORCIADO' | 'VIUDO' | 'CONCUBINATO' | null {
  const s = str(val)?.toUpperCase();
  if (!s) return null;
  if (s.includes('SOLTER')) return 'SOLTERO';
  if (s.includes('CASAD')) return 'CASADO';
  if (s.includes('DIVORC') || s.includes('DIVORS')) return 'DIVORCIADO';
  if (s.includes('VIUD')) return 'VIUDO';
  if (s.includes('CONCUBIN') || s.includes('UNION') || s.includes('UNIDO')) return 'CONCUBINATO';
  return null;
}

function normalizarEstadoAvance(val: unknown): EstadoAvanceFormacion {
  const s = str(val)?.toUpperCase();
  if (!s) return null;
  if (s.includes('CULMIN') || s.includes('COMPLET') || s.includes('GRADUAD')) return 'CULMINO';
  if (s.includes('NO') || s.includes('INCOMPLET')) return 'NO_COMPLETO';
  if (s.includes('PROGRESO') || s.includes('CURSANDO') || s.includes('ACTUAL')) return 'EN_PROGRESO';
  return null;
}

/**
 * Adapta la entrada genérica `EntradaPlanilla` al modelo semántico fuertemente tipado
 * de la Planilla Oficial INCES física (612 × 792 pt).
 */
export function adaptarAPlanillaOficial(
  entrada: EntradaPlanilla,
  contexto?: ContextoPlanillaOficial,
): PlanillaOficialData {
  const entradaObj = entrada as unknown as Record<string, unknown>;
  const datos = (entrada.datosPlanilla ?? {}) as Record<string, unknown>;
  const iden = (entrada.identidad ?? {}) as Record<string, unknown>;

  const hoyStr = (): string => {
    const d = new Date();
    const dd = String(d.getDate()).padStart(2, '0');
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    const yyyy = d.getFullYear();
    return `${dd}/${mm}/${yyyy}`;
  };

  // 1. Cabecera (Derivada del contexto o datos)
  const cabeceraCtx = contexto?.cabecera ?? {};
  const cursoEntrada =
    str(iden.curso_seleccionado) ??
    str(datos.proyecto) ??
    str(datos.curso_seleccionado) ??
    str(datos.curso) ??
    str(entradaObj.curso_nombre) ??
    str(entradaObj.programa);

  const proyectoResuelto =
    cabeceraCtx.proyecto ??
    (cursoEntrada && !/^[0-9a-fA-F-]{36}$/.test(cursoEntrada)
      ? cursoEntrada
      : 'Soldadura Universal y Forja Industrial');

  const cabecera = {
    fecha: cabeceraCtx.fecha ?? str(datos.fecha_inscripcion) ?? str(datos.fecha) ?? hoyStr(),
    numeroPreimpreso: cabeceraCtx.numeroPreimpreso ?? str(datos.numero_preimpreso) ?? null,
    proyecto: proyectoResuelto,
    espacioIntegralSocialista:
      cabeceraCtx.espacioIntegralSocialista ??
      str(datos.espacio_integral_socialista) ??
      str(datos.espacio) ??
      'CFS Rafael Urdaneta (La Isabelica)',
    horario: cabeceraCtx.horario ?? str(datos.horario) ?? '07:30 - 12:00',
  };

  // 2. Identidad y Nombres
  const nombresCompletos = str(entrada.nombres) ?? str(datos.nombres) ?? str(iden.nombres);
  const apellidosCompletos = str(entrada.apellidos) ?? str(datos.apellidos) ?? str(iden.apellidos);

  const primerNombre =
    str(datos.primer_nombre) ??
    str(iden.primer_nombre) ??
    (nombresCompletos ? nombresCompletos.split(/\s+/)[0] ?? null : null);
  const segundoNombre =
    str(datos.segundo_nombre) ??
    str(iden.segundo_nombre) ??
    (nombresCompletos && nombresCompletos.split(/\s+/).length > 1
      ? nombresCompletos.split(/\s+/).slice(1).join(' ')
      : null);
  const primerApellido =
    str(datos.primer_apellido) ??
    str(iden.primer_apellido) ??
    (apellidosCompletos ? apellidosCompletos.split(/\s+/)[0] ?? null : null);
  const segundoApellido =
    str(datos.segundo_apellido) ??
    str(iden.segundo_apellido) ??
    (apellidosCompletos && apellidosCompletos.split(/\s+/).length > 1
      ? apellidosCompletos.split(/\s+/).slice(1).join(' ')
      : null);
  const cedula = str(datos.cedula) ?? str(iden.cedula) ?? entrada.cedula;
  const nacionalidad =
    str(datos.nacionalidad) ??
    str(iden.nacionalidad) ??
    (cedula && cedula.toUpperCase().startsWith('E') ? 'Extranjero' : 'Venezolana');

  // 3. Nacimiento
  const fechaNacRaw =
    str(datos.fecha_nac) ??
    str(datos.fecha_nacimiento) ??
    str(iden.fecha_nac) ??
    str(iden.fecha_nacimiento) ??
    str(entradaObj.fechaNacimiento) ??
    str(entradaObj.fecha_nacimiento) ??
    str(entradaObj.fechaNac) ??
    str((entradaObj.aspirante as Record<string, unknown> | undefined)?.fechaNacimiento) ??
    str((entradaObj.aspirante as Record<string, unknown> | undefined)?.fecha_nacimiento);

  const { dia, mes, anio } = desglosarFechaNac(fechaNacRaw);
  const edadCalculada = calcularEdad(fechaNacRaw);
  const edad =
    typeof datos.edad === 'number' && !isNaN(datos.edad)
      ? datos.edad
      : (edadCalculada ?? (datos.edad && !isNaN(Number(datos.edad)) ? Number(datos.edad) : null));

  // 4. Sexo y Estado Civil
  const sexo = normalizarSexo(datos.sexo ?? iden.sexo);
  const estadoCivil = normalizarEstadoCivil(datos.estado_civil ?? iden.estado_civil);

  // 5. Pueblo Indígena
  const indigenaBool = esVerdadero(datos.pueblo_indigena);
  const indigenaCual = str(datos.pueblo_indigena_cual);

  // 6. Diversidad Funcional
  const discRaw = datos.tipo_discapacidad ?? datos.discapacidad;
  let discTexto = '';
  if (Array.isArray(discRaw)) {
    discTexto = discRaw.map(String).join(' ').toUpperCase();
  } else if (typeof discRaw === 'string') {
    discTexto = discRaw.toUpperCase();
  } else if (discRaw && typeof discRaw === 'object') {
    discTexto = Object.keys(discRaw as Record<string, unknown>).join(' ').toUpperCase();
  }
  const tieneDiscapacidad = esVerdadero(datos.discapacidad) || discTexto.length > 0;
  const fisicaMano = discTexto.includes('MANO');
  const fisicaPiernas = discTexto.includes('PIERNA');
  const sensorialAuditiva = discTexto.includes('AUDITIV') || discTexto.includes('SORD');
  const sensorialCeguera = discTexto.includes('CEGUER') || discTexto.includes('VISUAL') || discTexto.includes('CIEG');
  const debilidadIntelectual = discTexto.includes('INTELECT') || discTexto.includes('COGNIT');
  const ninguna = !tieneDiscapacidad || discTexto.includes('NINGUNA');

  // 7. Prácticas
  const deporteVal = str(datos.deporte);
  const deporteDesde = str(datos.deporte_desde);
  const culturalVal = str(datos.actividad_cultural);
  const culturalDesde = str(datos.actividad_cultural_desde);
  const orgVal = str(datos.organizacion_social);
  const orgDesde = str(datos.organizacion_social_desde);

  // 8. Ubicación y Contacto
  const ubicacion = {
    estado: str(datos.estado) ?? str(iden.estado) ?? 'CARABOBO',
    municipio: str(datos.municipio) ?? str(iden.municipio) ?? null,
    parroquia: str(datos.parroquia) ?? str(iden.parroquia) ?? null,
    comunidad: str(datos.comunidad) ?? null,
    direccion: str(datos.direccion) ?? str(iden.direccion) ?? null,
    telefonoCelular:
      str(datos.telefono) ??
      str(iden.telefono) ??
      str(datos.telefono_celular) ??
      str(datos.celular) ??
      null,
    telefonoFijo: str(datos.telefono_fijo) ?? str(datos.fijo) ?? null,
    email: str(datos.email) ?? str(iden.email) ?? entrada.email,
    twitter: str(datos.twitter) ?? null,
    facebook: str(datos.facebook) ?? null,
  };

  // 9. Familiares (hasta 5 filas para el formato físico)
  const familiaresRaw = Array.isArray(datos.familiares) ? (datos.familiares as Record<string, unknown>[]) : [];
  const familiares: FamiliarOficial[] = familiaresRaw.slice(0, 5).map((f) => ({
    cedula: str(f.cedula),
    nombres: str(f.nombres) ?? str(f.primer_nombre),
    apellidos: str(f.apellidos) ?? str(f.primer_apellido),
    fechaNac: str(f.fecha_nac),
    genero: normalizarSexo(f.genero),
    parentesco: str(f.parentesco),
    diversidadFuncional: str(f.diversidad_funcional),
    estadoCivil: str(f.estado_civil),
  }));

  // 10. Misiones (20 misiones exactas)
  const misionesRaw = datos.misiones;
  const mapaMisiones: Record<string, string> = {};
  if (Array.isArray(misionesRaw)) {
    for (const item of misionesRaw) {
      if (typeof item === 'string') mapaMisiones[item.toUpperCase()] = '';
      else if (item && typeof item === 'object') {
        const o = item as Record<string, unknown>;
        const cod = String(o.codigo ?? o.valor ?? '').toUpperCase();
        if (cod) mapaMisiones[cod] = str(o.desde) ?? '';
      }
    }
  } else if (misionesRaw && typeof misionesRaw === 'object') {
    for (const [k, v] of Object.entries(misionesRaw as Record<string, unknown>)) {
      mapaMisiones[k.toUpperCase()] = v == null ? '' : String(v);
    }
  }
  const misiones: MisionOficial[] = MISIONES_OFICIALES_ORDENADAS.map((m) => {
    const codUpper = m.codigo.toUpperCase();
    const marcada = codUpper in mapaMisiones;
    return {
      codigo: m.codigo,
      etiqueta: m.etiqueta,
      marcada,
      desde: marcada ? mapaMisiones[codUpper] || null : null,
    };
  });

  // 11. Formación
  const formacion = {
    nivelEducativo: str(datos.nivel_educativo) ?? str(iden.nivel_educativo) ?? null,
    estadoAvance: normalizarEstadoAvance(datos.nivel_avance ?? datos.estado_avance),
    ultimoAnio:
      str(datos.ultimo_anio) ??
      str(datos.ultimo_anio_cursado) ??
      str(datos.anio_graduacion) ??
      str(datos.anio) ??
      str(iden.ultimo_anio) ??
      null,
    especialidad:
      str(datos.especialidad) ??
      str(datos.titulo_obtenido) ??
      str(datos.mencion) ??
      str(iden.especialidad) ??
      null,
  };

  // 12. Otras Formaciones
  const otrasFormaciones: OtraFormacionOficial[] = [];
  if (typeof datos.otras_formaciones === 'string') {
    otrasFormaciones.push({ descripcion: datos.otras_formaciones });
  } else if (Array.isArray(datos.otras_formaciones)) {
    for (const oform of datos.otras_formaciones) {
      if (typeof oform === 'string') otrasFormaciones.push({ descripcion: oform });
      else if (oform && typeof oform === 'object') {
        otrasFormaciones.push({ descripcion: str((oform as Record<string, unknown>).descripcion) });
      }
    }
  }

  // 13. Experiencias Empíricas
  const experienciasRaw = Array.isArray(datos.experiencias) ? (datos.experiencias as Record<string, unknown>[]) : [];
  const experiencias: ExperienciaOficial[] = experienciasRaw.slice(0, 3).map((exp) => ({
    area: str(exp.area ?? exp.area_conocimiento),
    tiempoMeses: str(exp.tiempo_meses ?? exp.meses),
    portafolio: esVerdadero(exp.portafolio ?? exp.portafolio_evidencias),
    enlace: str(exp.enlace),
  }));

  return {
    cabecera,
    identidad: {
      primerNombre,
      segundoNombre,
      primerApellido,
      segundoApellido,
      cedula,
      nacionalidad,
    },
    nacimiento: {
      fecha: fechaNacRaw,
      dia,
      mes,
      anio,
      edad,
    },
    sexo,
    estadoCivil,
    puebloIndigena: {
      pertenece: indigenaBool,
      cual: indigenaCual,
    },
    discapacidad: {
      fisicaMano,
      fisicaPiernas,
      sensorialAuditiva,
      sensorialCeguera,
      debilidadIntelectual,
      ninguna,
      indiqueCual: tieneDiscapacidad ? discTexto : null,
    },
    practicas: {
      deporte: { valor: deporteVal, desde: deporteDesde },
      cultural: { valor: culturalVal, desde: culturalDesde },
      organizacion: { valor: orgVal, desde: orgDesde },
    },
    ubicacion,
    familiares,
    misiones,
    formacion,
    otrasFormaciones,
    experiencias,
  };
}
