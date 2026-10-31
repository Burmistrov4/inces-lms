import { afterEach, describe, expect, it } from 'vitest';
import {
  conToken,
  crearArnés,
  ID_SECCION_SA,
  TOKEN_ALUMNO,
  TOKEN_DOCENTE,
  type Arnés,
} from './support/arnes.js';

/**
 * Invitación de un aprendiz desde el aula del docente.
 *
 * **Qué se prueba y por qué.** Antes de la migración `202610310003` la
 * activación de una invitación escribía `'docente'` a mano: reutilizar esa vía
 * para alumnos habría creado profesores con permiso para calificar. Estas
 * pruebas fijan que el rol lo pone el **servidor** y que no se puede escalar
 * mandándolo en el cuerpo.
 */
describe('POST /api/v1/aula/secciones/:seccionId/invitar', () => {
  let arnés: Arnés;

  afterEach(async () => {
    await arnés?.app.close();
  });

  it('el docente invita y la invitación nace con rol estudiante', async () => {
    arnés = crearArnés();

    const respuesta = await arnés.app.inject({
      method: 'POST',
      url: `/api/v1/aula/secciones/${ID_SECCION_SA}/invitar`,
      headers: conToken(TOKEN_DOCENTE),
      payload: { email: 'aprendiz@inces.test', nombres: 'Ana', apellidos: 'Pérez' },
    });

    expect(respuesta.statusCode).toBe(201);

    const cuerpo = respuesta.json() as {
      email: string;
      enlaceActivacion: string;
      correoEnviado: boolean;
    };
    expect(cuerpo.email).toBe('aprendiz@inces.test');
    expect(cuerpo.enlaceActivacion).toContain('#/auth/activate?token=');

    const guardada = arnés.estado.invitaciones.at(-1);
    expect(guardada?.email).toBe('aprendiz@inces.test');
    expect(guardada?.rol).toBe('estudiante');
  });

  it('el rol no se puede escalar desde el cuerpo', async () => {
    arnés = crearArnés();

    const respuesta = await arnés.app.inject({
      method: 'POST',
      url: `/api/v1/aula/secciones/${ID_SECCION_SA}/invitar`,
      headers: conToken(TOKEN_DOCENTE),
      // `rol` no está en el esquema: `.strict()` lo rechaza en vez de ignorarlo.
      payload: { email: 'listo@inces.test', rol: 'docente' },
    });

    expect(respuesta.statusCode).toBe(400);
  });

  it('un aprendiz no puede invitar a nadie', async () => {
    arnés = crearArnés();

    const respuesta = await arnés.app.inject({
      method: 'POST',
      url: `/api/v1/aula/secciones/${ID_SECCION_SA}/invitar`,
      headers: conToken(TOKEN_ALUMNO),
      payload: { email: 'otro@inces.test' },
    });

    expect(respuesta.statusCode).toBe(403);
    const cuerpo = respuesta.json() as { error: { codigo: string } };
    expect(cuerpo.error.codigo).toBe('SIN_PERMISO');
  });

  it('un docente no puede invitar a un aula donde no da clase', async () => {
    arnés = crearArnés();

    // Sección que existe pero sin bloque de ese docente.
    const ajena = arnés.estado.secciones.find(
      (s) =>
        s.id !== ID_SECCION_SA &&
        !arnés.estado.clases.some(
          (c) => c.seccionId === s.id && c.docenteId === 'docente-1',
        ),
    );

    expect(ajena, 'el arnés debería tener otra sección sin ese docente').toBeDefined();

    const respuesta = await arnés.app.inject({
      method: 'POST',
      url: `/api/v1/aula/secciones/${ajena!.id}/invitar`,
      headers: conToken(TOKEN_DOCENTE),
      payload: { email: 'ajeno@inces.test' },
    });

    expect(respuesta.statusCode).toBe(403);
    const cuerpo = respuesta.json() as { error: { codigo: string } };
    expect(cuerpo.error.codigo).toBe('AULA_AJENA');
  });

  it('un correo inválido se rechaza antes de crear nada', async () => {
    arnés = crearArnés();
    const antes = arnés.estado.invitaciones.length;

    const respuesta = await arnés.app.inject({
      method: 'POST',
      url: `/api/v1/aula/secciones/${ID_SECCION_SA}/invitar`,
      headers: conToken(TOKEN_DOCENTE),
      payload: { email: 'no-es-un-correo' },
    });

    expect(respuesta.statusCode).toBe(400);
    expect(arnés.estado.invitaciones.length).toBe(antes);
  });
});
