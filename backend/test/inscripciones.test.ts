import type { FastifyInstance } from 'fastify';
import { afterEach, describe, expect, it } from 'vitest';
import {
  conToken,
  crearArnés,
  ID_ALUMNO,
  ID_ALUMNO_2,
  ID_MATERIA_ALGORITMICA,
  ID_PROGRAMA_SISTEMAS,
  ID_SECCION_SA,
  ID_SECCION_SC,
  PERFIL_ALUMNO_2,
  MODULOS_POR_DEFECTO,
  PERFILES_POR_DEFECTO,
  TOKEN_ADMIN,
  TOKEN_ALUMNO,
  TOKEN_ALUMNO_2,
  type Arnés,
  type InscripcionFalsa,
  type SeccionFalsa,
} from './support/arnes.js';

/**
 * El motor de inscripciones, de punta a punta sobre el arnés en memoria.
 *
 * Lo que se comprueba aquí es el **contrato HTTP** y, sobre todo, las dos reglas
 * que no se ven a simple vista:
 *
 * 1. **Inscripción y cupos.** Al llenarse la sección los aspirantes pasan a
 *    lista de espera (`WAITLISTED`). Al liberarse un cupo, se promueve al siguiente.
 * 2. **La reincorporación puede exceder la capacidad.** «Si el admin autoriza, el
 *    sistema obedece»: es una decisión de administración, no un agujero.
 *
 * Lo que ocurre *dentro* —que el `23514` de las RPC se traduzca bien contra la
 * base real— no se puede ver desde aquí: le corresponde al humo contra Supabase.
 */

let app: FastifyInstance | null = null;

afterEach(async () => {
  await app?.close();
  app = null;
});

const ID_INEXISTENTE = 'ffffffff-0000-4000-8000-000000000000';

/** Las cinco rutas de estudiante. */
const RUTAS_ESTUDIANTE = [
  { method: 'GET' as const, url: '/api/v1/ofertas' },
  { method: 'GET' as const, url: '/api/v1/mis-inscripciones' },
  { method: 'POST' as const, url: '/api/v1/inscripciones' },
  { method: 'POST' as const, url: `/api/v1/inscripciones/${ID_SECCION_SA}/aceptar` },
  { method: 'POST' as const, url: `/api/v1/inscripciones/${ID_SECCION_SA}/renunciar` },
];

/** Las seis rutas de administración. */
const RUTAS_ADMIN = [
  { method: 'GET' as const, url: '/api/v1/admin/ocupacion' },
  { method: 'GET' as const, url: `/api/v1/admin/secciones/${ID_SECCION_SA}/cola` },
  { method: 'GET' as const, url: `/api/v1/admin/secciones/${ID_SECCION_SA}/inscripciones` },
  { method: 'POST' as const, url: `/api/v1/admin/secciones/${ID_SECCION_SA}/promover` },
  { method: 'POST' as const, url: '/api/v1/admin/inscripciones/reincorporar' },
  { method: 'POST' as const, url: '/api/v1/admin/inscripciones/expirar' },
];

/** Arma el arnés con dos estudiantes y las secciones que se pidan. */
function arnesConDosAlumnos(secciones?: SeccionFalsa[], inscripciones?: InscripcionFalsa[]) {
  return crearArnés({
    perfiles: [...PERFILES_POR_DEFECTO, PERFIL_ALUMNO_2],
    identidades: { [TOKEN_ALUMNO_2]: ID_ALUMNO_2 },
    ...(secciones ? { secciones } : {}),
    ...(inscripciones ? { inscripciones } : {}),
  });
}

const SECCION_CAPACIDAD_1: SeccionFalsa[] = [
  {
    id: ID_SECCION_SA,
    programaId: ID_PROGRAMA_SISTEMAS,
    materiaId: ID_MATERIA_ALGORITMICA,
    periodo: '2026-1',
    nombre: 'SA',
    cupoMaximo: 1,
  },
];

const SECCION_CAPACIDAD_2: SeccionFalsa[] = [
  {
    id: ID_SECCION_SA,
    programaId: ID_PROGRAMA_SISTEMAS,
    materiaId: ID_MATERIA_ALGORITMICA,
    periodo: '2026-1',
    nombre: 'SA',
    cupoMaximo: 2,
  },
];

describe('control de acceso a las inscripciones', () => {
  it('exige sesión en las cinco rutas de estudiante', async () => {
    const arnes = crearArnés();
    app = arnes.app;

    for (const ruta of RUTAS_ESTUDIANTE) {
      const respuesta = await app.inject({ method: ruta.method, url: ruta.url });

      expect(respuesta.statusCode, `${ruta.method} ${ruta.url}`).toBe(401);
      expect(respuesta.json().error.codigo).toBe('NO_AUTENTICADO');
    }
  });

  it('exige rol admin en las seis rutas de administración', async () => {
    const arnes = crearArnés();
    app = arnes.app;

    for (const ruta of RUTAS_ADMIN) {
      const sinSesion = await app.inject({ method: ruta.method, url: ruta.url });
      expect(sinSesion.statusCode, `${ruta.method} ${ruta.url} sin sesión`).toBe(401);

      const comoAlumno = await app.inject({
        method: ruta.method,
        url: ruta.url,
        headers: conToken(TOKEN_ALUMNO),
      });
      expect(comoAlumno.statusCode, `${ruta.method} ${ruta.url} como alumno`).toBe(403);
      expect(comoAlumno.json().error.codigo).toBe('SOLO_ADMIN');
    }
  });

  it('un estudiante SÍ puede llegar a la lógica: el módulo es operable', async () => {
    const arnes = arnesConDosAlumnos(SECCION_CAPACIDAD_2);
    app = arnes.app;

    // La contrapartida de la prueba anterior: la guardia protege la
    // administración, no bloquea al estudiante. Si esto fallara con un 403, el
    // módulo estaría inoperable y la suite no lo vería (es la lección de R-20).
    const respuesta = await app.inject({
      method: 'POST',
      url: '/api/v1/inscripciones',
      headers: conToken(TOKEN_ALUMNO_2),
      payload: { seccionId: ID_SECCION_SA },
    });

    expect(respuesta.statusCode).toBe(201);
  });
});

describe('catálogo de ofertas', () => {
  it('devuelve las secciones activas con su ocupación y los nombres resueltos', async () => {
    const arnes = crearArnés();
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'GET',
      url: '/api/v1/ofertas',
      headers: conToken(TOKEN_ALUMNO),
    });

    expect(respuesta.statusCode).toBe(200);

    const { secciones } = respuesta.json();
    expect(secciones).toHaveLength(2);

    const sa = secciones.find((s: { seccionId: string }) => s.seccionId === ID_SECCION_SA);
    expect(sa.materiaNombre).toBe('Algorítmica I');
    expect(sa.programaNombre).toContain('Sistemas');
    // El alumno de ejemplo ya está matriculado en SA.
    expect(sa.cuposOcupados).toBe(1);
    expect(sa.ofertaVigente).toBe(false);
  });

  it('no ofrece una sección archivada', async () => {
    const arnes = crearArnés({
      secciones: [{ ...SECCION_CAPACIDAD_1[0]!, activa: false }],
    });
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'GET',
      url: '/api/v1/ofertas',
      headers: conToken(TOKEN_ALUMNO),
    });

    // Ofrecer una archivada sería ofrecer algo que la base va a rechazar.
    expect(respuesta.json().secciones).toHaveLength(0);
    expect(respuesta.json().total).toBe(0);
  });

  it('el panel de administración SÍ ve las archivadas', async () => {
    const arnes = crearArnés({
      secciones: [{ ...SECCION_CAPACIDAD_1[0]!, activa: false }],
    });
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'GET',
      url: '/api/v1/admin/ocupacion',
      headers: conToken(TOKEN_ADMIN),
    });

    // El administrador necesita poder consultar el histórico de una cerrada.
    expect(respuesta.json().total).toBe(1);
    expect(respuesta.json().secciones[0].activa).toBe(false);
  });

  it('con soloConCupo excluye la sección llena', async () => {
    const arnes = arnesConDosAlumnos(SECCION_CAPACIDAD_1);
    app = arnes.app;

    // SA tiene cupo 1 y el alumno de ejemplo lo ocupa: está llena.
    const conCupo = await app.inject({
      method: 'GET',
      url: '/api/v1/ofertas?soloConCupo=true',
      headers: conToken(TOKEN_ALUMNO),
    });
    expect(conCupo.json().total).toBe(0);

    const todas = await app.inject({
      method: 'GET',
      url: '/api/v1/ofertas',
      headers: conToken(TOKEN_ALUMNO),
    });
    expect(todas.json().total).toBe(1);
  });
});

describe('solicitar un asiento', () => {
  it('entra directo a ENROLLED cuando hay hueco', async () => {
    const arnes = arnesConDosAlumnos(SECCION_CAPACIDAD_2);
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'POST',
      url: '/api/v1/inscripciones',
      headers: conToken(TOKEN_ALUMNO_2),
      payload: { seccionId: ID_SECCION_SA },
    });

    expect(respuesta.statusCode).toBe(201);
    expect(respuesta.json().estado).toBe('ENROLLED');
    expect(respuesta.json().mensaje).toBe('Inscrito');
  });

  it('queda en WAITLISTED cuando la sección está llena', async () => {
    const arnes = arnesConDosAlumnos(SECCION_CAPACIDAD_1);
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'POST',
      url: '/api/v1/inscripciones',
      headers: conToken(TOKEN_ALUMNO_2),
      payload: { seccionId: ID_SECCION_SA },
    });

    expect(respuesta.statusCode).toBe(201);
    expect(respuesta.json().estado).toBe('WAITLISTED');
    expect(respuesta.json().mensaje).toBe('En lista de espera');
  });

  it('devuelve 404 si la sección no existe', async () => {
    const arnes = crearArnés();
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'POST',
      url: '/api/v1/inscripciones',
      headers: conToken(TOKEN_ALUMNO),
      payload: { seccionId: ID_INEXISTENTE },
    });

    expect(respuesta.statusCode).toBe(404);
    expect(respuesta.json().error.codigo).toBe('SECCION_INEXISTENTE');
  });

  it('devuelve 409 si la sección está archivada', async () => {
    const arnes = crearArnés({
      secciones: [{ ...SECCION_CAPACIDAD_1[0]!, activa: false }],
    });
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'POST',
      url: '/api/v1/inscripciones',
      headers: conToken(TOKEN_ALUMNO),
      payload: { seccionId: ID_SECCION_SA },
    });

    expect(respuesta.statusCode).toBe(409);
    expect(respuesta.json().error.codigo).toBe('SECCION_ARCHIVADA');
  });

  it('devuelve 409 REQUIERE_REINCORPORACION a quien ya cursó la sección', async () => {
    const arnes = arnesConDosAlumnos(SECCION_CAPACIDAD_2, [
      { estudianteId: ID_ALUMNO_2, seccionId: ID_SECCION_SA, estado: 'DROPPED', llegada: 1 },
    ]);
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'POST',
      url: '/api/v1/inscripciones',
      headers: conToken(TOKEN_ALUMNO_2),
      payload: { seccionId: ID_SECCION_SA },
    });

    // El `unique (student_id, section_id)` bloquea por diseño: un `DROPPED`
    // conserva su fila como historial, así que volver a entrar NO es una
    // reinscripción libre. El código propio existe para que la interfaz pueda
    // ofrecer «solicitar reincorporación» en vez de un error opaco.
    expect(respuesta.statusCode).toBe(409);
    expect(respuesta.json().error.codigo).toBe('REQUIERE_REINCORPORACION');
  });

  it('devuelve 409 si ya tiene una solicitud activa', async () => {
    const arnes = arnesConDosAlumnos(SECCION_CAPACIDAD_2, [
      { estudianteId: ID_ALUMNO_2, seccionId: ID_SECCION_SA, estado: 'WAITLISTED', llegada: 1 },
    ]);
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'POST',
      url: '/api/v1/inscripciones',
      headers: conToken(TOKEN_ALUMNO_2),
      payload: { seccionId: ID_SECCION_SA },
    });

    expect(respuesta.statusCode).toBe(409);
    expect(respuesta.json().error.codigo).toBe('SOLICITUD_YA_EXISTE');
  });

  it('rechaza un cuerpo sin seccionId', async () => {
    const arnes = crearArnés();
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'POST',
      url: '/api/v1/inscripciones',
      headers: conToken(TOKEN_ALUMNO),
      payload: {},
    });

    expect(respuesta.statusCode).toBe(400);
    expect(respuesta.json().error.codigo).toBe('PETICION_INVALIDA');
  });
});

describe('inscripción y cupos disponibles', () => {
  it('con la sección llena, el aspirante queda en WAITLISTED', async () => {
    const arnes = arnesConDosAlumnos(SECCION_CAPACIDAD_1, [
      {
        estudianteId: ID_ALUMNO,
        seccionId: ID_SECCION_SA,
        estado: 'ENROLLED',
        llegada: 1,
      },
    ]);
    app = arnes.app;

    const ofertas = await app.inject({
      method: 'GET',
      url: '/api/v1/ofertas',
      headers: conToken(TOKEN_ALUMNO_2),
    });
    const sa = ofertas.json().secciones[0];
    expect(sa.cuposOcupados).toBe(1);
    expect(sa.cuposDisponibles).toBe(0);
    expect(sa.ofertaVigente).toBe(false);

    const solicitud = await app.inject({
      method: 'POST',
      url: '/api/v1/inscripciones',
      headers: conToken(TOKEN_ALUMNO_2),
      payload: { seccionId: ID_SECCION_SA },
    });

    expect(solicitud.statusCode).toBe(201);
    expect(solicitud.json().estado).toBe('WAITLISTED');
  });

  it('soloConCupo no ofrece una sección sin cupos disponibles', async () => {
    const arnes = arnesConDosAlumnos(SECCION_CAPACIDAD_1, [
      {
        estudianteId: ID_ALUMNO,
        seccionId: ID_SECCION_SA,
        estado: 'ENROLLED',
        llegada: 1,
      },
    ]);
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'GET',
      url: '/api/v1/ofertas?soloConCupo=true',
      headers: conToken(TOKEN_ALUMNO_2),
    });

    expect(respuesta.json().total).toBe(0);
  });

  it('renunciar al cupo libera el asiento y promueve automáticamente al primero en espera', async () => {
    const arnes = arnesConDosAlumnos(SECCION_CAPACIDAD_1, [
      {
        estudianteId: ID_ALUMNO,
        seccionId: ID_SECCION_SA,
        estado: 'ENROLLED',
        llegada: 1,
      },
      {
        estudianteId: ID_ALUMNO_2,
        seccionId: ID_SECCION_SA,
        estado: 'WAITLISTED',
        llegada: 2,
      },
    ]);
    app = arnes.app;

    const renuncia = await app.inject({
      method: 'POST',
      url: `/api/v1/inscripciones/${ID_SECCION_SA}/renunciar`,
      headers: conToken(TOKEN_ALUMNO),
    });

    expect(renuncia.statusCode).toBe(200);
    expect(renuncia.json().estado).toBe('DROPPED');

    const inscritos = await app.inject({
      method: 'GET',
      url: `/api/v1/admin/secciones/${ID_SECCION_SA}/inscripciones`,
      headers: conToken(TOKEN_ADMIN),
    });

    const alumno2 = inscritos.json().inscripciones.find(
      (i: { estudianteId: string }) => i.estudianteId === ID_ALUMNO_2,
    );
    expect(alumno2.estado).toBe('ENROLLED');
  });
});

describe('aceptar y renunciar', () => {
  it('aceptar confirma la inscripción existente como ENROLLED', async () => {
    const arnes = arnesConDosAlumnos(SECCION_CAPACIDAD_1, [
      {
        estudianteId: ID_ALUMNO_2,
        seccionId: ID_SECCION_SA,
        estado: 'ENROLLED',
        llegada: 1,
      },
    ]);
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'POST',
      url: `/api/v1/inscripciones/${ID_SECCION_SA}/aceptar`,
      headers: conToken(TOKEN_ALUMNO_2),
    });

    expect(respuesta.statusCode).toBe(200);
    expect(respuesta.json().estado).toBe('ENROLLED');
  });

  it('renunciar deja DROPPED y no borra la fila', async () => {
    const arnes = arnesConDosAlumnos(SECCION_CAPACIDAD_2);
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'POST',
      url: `/api/v1/inscripciones/${ID_SECCION_SA}/renunciar`,
      headers: conToken(TOKEN_ALUMNO),
    });

    expect(respuesta.statusCode).toBe(200);
    expect(respuesta.json().estado).toBe('DROPPED');

    // La fila sigue ahí: es el historial que permite reincorporar.
    const mias = await app.inject({
      method: 'GET',
      url: '/api/v1/mis-inscripciones',
      headers: conToken(TOKEN_ALUMNO),
    });
    expect(mias.json().inscripciones).toHaveLength(1);
    expect(mias.json().inscripciones[0].estado).toBe('DROPPED');
  });

  it('renunciar promueve al siguiente de la cola', async () => {
    const arnes = arnesConDosAlumnos(SECCION_CAPACIDAD_1, [
      { estudianteId: ID_ALUMNO, seccionId: ID_SECCION_SA, llegada: 1 },
      { estudianteId: ID_ALUMNO_2, seccionId: ID_SECCION_SA, estado: 'WAITLISTED', llegada: 2 },
    ]);
    app = arnes.app;

    await app.inject({
      method: 'POST',
      url: `/api/v1/inscripciones/${ID_SECCION_SA}/renunciar`,
      headers: conToken(TOKEN_ALUMNO),
    });

    const delSegundo = await app.inject({
      method: 'GET',
      url: '/api/v1/mis-inscripciones',
      headers: conToken(TOKEN_ALUMNO_2),
    });

    expect(delSegundo.json().inscripciones[0].estado).toBe('ENROLLED');
  });

  it('devuelve 400 a quien renuncia sin tener inscripción', async () => {
    const arnes = crearArnés();
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'POST',
      url: `/api/v1/inscripciones/${ID_SECCION_SC}/renunciar`,
      headers: conToken(TOKEN_ALUMNO),
    });

    expect(respuesta.statusCode).toBe(400);
  });
});

describe('mis inscripciones', () => {
  it('devuelve sólo las propias y con la posición en la cola', async () => {
    const arnes = arnesConDosAlumnos(SECCION_CAPACIDAD_1, [
      { estudianteId: ID_ALUMNO, seccionId: ID_SECCION_SA, llegada: 1 },
      { estudianteId: ID_ALUMNO_2, seccionId: ID_SECCION_SA, estado: 'WAITLISTED', llegada: 2 },
    ]);
    app = arnes.app;

    const delSegundo = await app.inject({
      method: 'GET',
      url: '/api/v1/mis-inscripciones',
      headers: conToken(TOKEN_ALUMNO_2),
    });

    const cuerpo = delSegundo.json();
    expect(cuerpo.inscripciones).toHaveLength(1);
    expect(cuerpo.inscripciones[0].estudianteId).toBe(ID_ALUMNO_2);
    expect(cuerpo.inscripciones[0].posicionEnCola).toBe(1);
    expect(cuerpo.inscripciones[0].materiaNombre).toBe('Algorítmica I');
    // La sección no se repite por fila: es la misma para todas.
    expect(cuerpo.inscripciones[0].seccionNombre).toBe('SA');
  });

  it('un ENROLLED no tiene posición en la cola', async () => {
    const arnes = crearArnés();
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'GET',
      url: '/api/v1/mis-inscripciones',
      headers: conToken(TOKEN_ALUMNO),
    });

    // Devolverle un número haría creer que ocupa un turno, y no lo ocupa.
    expect(respuesta.json().inscripciones[0].posicionEnCola).toBeNull();
  });

  it('el administrador no ve las inscripciones de nadie en su propia pantalla', async () => {
    const arnes = arnesConDosAlumnos(SECCION_CAPACIDAD_2);
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'GET',
      url: '/api/v1/mis-inscripciones',
      headers: conToken(TOKEN_ADMIN),
    });

    // La RLS deja al admin leer todas las filas, así que «lo mío» NO se puede
    // dejar al filtro de la base: el repositorio filtra por el id del llamante.
    expect(respuesta.json().inscripciones).toHaveLength(0);
  });
});

describe('cola e inscritos de una sección', () => {
  it('la cola va en orden FIFO y no incluye a quien ya está dentro', async () => {
    const arnes = arnesConDosAlumnos(SECCION_CAPACIDAD_1, [
      { estudianteId: ID_ALUMNO, seccionId: ID_SECCION_SA, llegada: 1 },
      { estudianteId: ID_ALUMNO_2, seccionId: ID_SECCION_SA, estado: 'WAITLISTED', llegada: 2 },
    ]);
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'GET',
      url: `/api/v1/admin/secciones/${ID_SECCION_SA}/cola`,
      headers: conToken(TOKEN_ADMIN),
    });

    const { cola } = respuesta.json();
    expect(cola).toHaveLength(1);
    expect(cola[0].estudianteId).toBe(ID_ALUMNO_2);
    expect(cola[0].posicionEnCola).toBe(1);
    // El administrador sí recibe el nombre: la RLS de profiles se lo permite.
    expect(cola[0].estudianteNombre).toBe('Iris Vega');
  });

  it('los inscritos incluyen a los dados de baja', async () => {
    const arnes = arnesConDosAlumnos(SECCION_CAPACIDAD_2, [
      { estudianteId: ID_ALUMNO, seccionId: ID_SECCION_SA, estado: 'DROPPED', llegada: 1 },
    ]);
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'GET',
      url: `/api/v1/admin/secciones/${ID_SECCION_SA}/inscripciones`,
      headers: conToken(TOKEN_ADMIN),
    });

    // Es la vista de «quién pasó por aquí», que es justo lo que necesita el
    // administrador para decidir una reincorporación.
    expect(respuesta.json().inscripciones).toHaveLength(1);
    expect(respuesta.json().inscripciones[0].estado).toBe('DROPPED');
  });
});

describe('promover al siguiente', () => {
  it('promueve al primero de la cola y lo devuelve', async () => {
    const arnes = arnesConDosAlumnos(SECCION_CAPACIDAD_1, [
      { estudianteId: ID_ALUMNO_2, seccionId: ID_SECCION_SA, estado: 'WAITLISTED', llegada: 1 },
    ]);
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'POST',
      url: `/api/v1/admin/secciones/${ID_SECCION_SA}/promover`,
      headers: conToken(TOKEN_ADMIN),
    });

    expect(respuesta.statusCode).toBe(200);
    expect(respuesta.json().promovida).not.toBeNull();
    expect(respuesta.json().promovida.estudianteId).toBe(ID_ALUMNO_2);
    // Los bids están apagados por defecto, así que pasa directo a ENROLLED.
    expect(respuesta.json().promovida.estado).toBe('ENROLLED');
  });

  it('con la cola vacía devuelve 200 y promovida: null, NO un 404', async () => {
    const arnes = crearArnés();
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'POST',
      url: `/api/v1/admin/secciones/${ID_SECCION_SC}/promover`,
      headers: conToken(TOKEN_ADMIN),
    });

    // Una cola vacía es un estado normal, no un fallo. Un 404 obligaría al
    // administrador a adivinar si no había nadie, si estaba llena o si ya había
    // una oferta en el aire.
    expect(respuesta.statusCode).toBe(200);
    expect(respuesta.json().promovida).toBeNull();
    expect(respuesta.json().mensaje).toContain('cola está vacía');
  });

  it('NO promueve si la sección ya está llena', async () => {
    const arnes = arnesConDosAlumnos(SECCION_CAPACIDAD_1, [
      {
        estudianteId: ID_ALUMNO,
        seccionId: ID_SECCION_SA,
        estado: 'ENROLLED',
        llegada: 1,
      },
      { estudianteId: ID_ALUMNO_2, seccionId: ID_SECCION_SA, estado: 'WAITLISTED', llegada: 2 },
    ]);
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'POST',
      url: `/api/v1/admin/secciones/${ID_SECCION_SA}/promover`,
      headers: conToken(TOKEN_ADMIN),
    });

    expect(respuesta.statusCode).toBe(200);
    expect(respuesta.json().promovida).toBeNull();
    expect(respuesta.json().mensaje).toContain('sección está llena');
  });
});

describe('reincorporar (la regla institucional)', () => {
  it('el administrador PUEDE exceder la capacidad de la sección', async () => {
    // Cupo 1, ya ocupado por el alumno de ejemplo. El segundo fue dado de baja
    // cuando había sitio; ahora la sección está llena.
    const arnes = arnesConDosAlumnos(SECCION_CAPACIDAD_1, [
      { estudianteId: ID_ALUMNO, seccionId: ID_SECCION_SA, llegada: 1 },
      { estudianteId: ID_ALUMNO_2, seccionId: ID_SECCION_SA, estado: 'DROPPED', llegada: 2 },
    ]);
    app = arnes.app;

    const antes = await app.inject({
      method: 'GET',
      url: `/api/v1/admin/ocupacion`,
      headers: conToken(TOKEN_ADMIN),
    });
    expect(antes.json().secciones[0].cuposOcupados).toBe(1);
    expect(antes.json().secciones[0].cupoEfectivo).toBe(1);

    const respuesta = await app.inject({
      method: 'POST',
      url: '/api/v1/admin/inscripciones/reincorporar',
      headers: conToken(TOKEN_ADMIN),
      payload: { estudianteId: ID_ALUMNO_2, seccionId: ID_SECCION_SA },
    });

    expect(respuesta.statusCode).toBe(200);
    expect(respuesta.json().estado).toBe('ENROLLED');

    const despues = await app.inject({
      method: 'GET',
      url: '/api/v1/admin/ocupacion',
      headers: conToken(TOKEN_ADMIN),
    });

    // **La sección queda por encima de su cupo, y eso es lo correcto.** «Si el
    // admin autoriza, el sistema obedece»: la comprobación se quitó a propósito.
    // Si esta aserción fallara, la regla institucional se habría revertido.
    expect(despues.json().secciones[0].cuposOcupados).toBe(2);
    expect(despues.json().secciones[0].cuposOcupados).toBeGreaterThan(
      despues.json().secciones[0].cupoEfectivo,
    );
  });

  it('devuelve 404 si el estudiante nunca cursó esa sección', async () => {
    const arnes = arnesConDosAlumnos(SECCION_CAPACIDAD_2);
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'POST',
      url: '/api/v1/admin/inscripciones/reincorporar',
      headers: conToken(TOKEN_ADMIN),
      payload: { estudianteId: ID_ALUMNO_2, seccionId: ID_SECCION_SA },
    });

    expect(respuesta.statusCode).toBe(404);
    expect(respuesta.json().error.codigo).toBe('SIN_HISTORIAL_EN_SECCION');
  });

  it('devuelve 400 si la inscripción no está dada de baja', async () => {
    const arnes = arnesConDosAlumnos(SECCION_CAPACIDAD_2);
    app = arnes.app;

    // El alumno de ejemplo está ENROLLED, no DROPPED.
    const respuesta = await app.inject({
      method: 'POST',
      url: '/api/v1/admin/inscripciones/reincorporar',
      headers: conToken(TOKEN_ADMIN),
      payload: { estudianteId: ID_ALUMNO, seccionId: ID_SECCION_SA },
    });

    expect(respuesta.statusCode).toBe(400);
  });

  it('exige los dos identificadores', async () => {
    const arnes = crearArnés();
    app = arnes.app;

    const respuesta = await app.inject({
      method: 'POST',
      url: '/api/v1/admin/inscripciones/reincorporar',
      headers: conToken(TOKEN_ADMIN),
      payload: { seccionId: ID_SECCION_SA },
    });

    expect(respuesta.statusCode).toBe(400);
  });
});

describe('expirar ofertas', () => {
  it('es no-op idempotente tras eliminar el sistema de bids', async () => {
    const arnes = arnesConDosAlumnos(SECCION_CAPACIDAD_2);
    app = arnes.app;

    const primera = await app.inject({
      method: 'POST',
      url: '/api/v1/admin/inscripciones/expirar',
      headers: conToken(TOKEN_ADMIN),
    });

    expect(primera.statusCode).toBe(200);
    expect(primera.json().vencidas).toBe(0);

    const segunda = await app.inject({
      method: 'POST',
      url: '/api/v1/admin/inscripciones/expirar',
      headers: conToken(TOKEN_ADMIN),
    });

    expect(segunda.json().vencidas).toBe(0);
    expect(segunda.json().mensaje).toContain('No había ofertas vencidas');
  });
});

/**
 * La guardia de la bandera `m4_inscripciones`.
 *
 * Va aparte del bloque de control de acceso porque comprueba **otra pregunta**:
 * allí se pregunta quién llama; aquí, si el módulo está encendido. Separarlos
 * hace que un fallo diga cuál de las dos se rompió.
 */
describe('la guardia del módulo (m4_inscripciones)', () => {
  /** El arnés con `m4_inscripciones` apagado, como si el administrador lo apagara. */
  function conModuloApagado(): Arnés {
    return crearArnés({
      modulos: MODULOS_POR_DEFECTO.map((m) =>
        m.clave === 'm4_inscripciones' ? { ...m, habilitado: false } : m,
      ),
    });
  }

  it('con el módulo apagado, las once rutas responden 403 y no llegan a tocar nada', async () => {
    // Ésta es la prueba que da sentido a la bandera, y sin ella la guardia sería
    // fe. El módulo arranca **encendido**, así que una guardia cableada a la clave
    // equivocada —una errata en `m4_inscripciones`— nunca se notaría: todas las
    // demás pruebas seguirían verdes. Apagarlo es la única forma de distinguir «la
    // guardia funciona» de «la guardia no se ejecuta».
    const arnés = conModuloApagado();
    app = arnés.app;

    const inscripcionesAntes = arnés.estado.inscripciones.length;

    // Cada mitad con el token que le toca. Con el de admin en las de estudiante,
    // la prueba pasaría por el rol equivocado; al revés, saltaría SOLO_ADMIN antes
    // que la guardia y no estaría comprobando lo que dice.
    for (const ruta of [...RUTAS_ESTUDIANTE, ...RUTAS_ADMIN]) {
      const esAdmin = ruta.url.startsWith('/api/v1/admin');
      const respuesta = await app.inject({
        ...ruta,
        headers: conToken(esAdmin ? TOKEN_ADMIN : TOKEN_ALUMNO),
      });

      expect(respuesta.statusCode, `${ruta.method} ${ruta.url}`).toBe(403);
      expect(respuesta.json().error.codigo, `${ruta.method} ${ruta.url}`).toBe(
        'MODULO_DESHABILITADO',
      );
    }

    // Y el corte ocurre **antes** del efecto: ni una inscripción de más. Una
    // guardia que dejara pasar la escritura y fallara al responder no sería una
    // guardia, sería un 403 que esconde un daño ya hecho. Importa más aquí que en
    // ningún otro módulo: la escritura de cupos pasa por un cerrojo en la base, y
    // un 403 que llegara después de tomarlo dejaría el asiento vendido.
    expect(arnés.estado.inscripciones).toHaveLength(inscripcionesAntes);
  });

  it('sin la fila del módulo el error es 404 MODULO_DESCONOCIDO, y no 403', async () => {
    // La distinción no es cosmética. `comprobarModulo` separa «no está
    // registrado» de «está apagado» a propósito: confundirlos manda a buscar el
    // problema al sitio equivocado —a la bandera, cuando lo que falta es la
    // semilla—.
    const arnés = crearArnés({ modulos: [] });
    app = arnés.app;

    const respuesta = await app.inject({
      method: 'GET',
      url: '/api/v1/ofertas',
      headers: conToken(TOKEN_ALUMNO),
    });

    expect(respuesta.statusCode).toBe(404);
    expect(respuesta.json().error.codigo).toBe('MODULO_DESCONOCIDO');
  });
});
