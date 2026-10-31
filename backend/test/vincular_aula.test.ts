import { afterEach, describe, expect, it } from 'vitest';
import {
  conToken,
  crearArnés,
  ID_ARCHIVO_CONFIRMADO,
  ID_SECCION_SA,
  TOKEN_ADMIN,
  type Arnés,
} from './support/arnes.js';

/**
 * `PATCH /api/v1/admin/archivos/{id}/aula` — vínculo archivo → aula virtual.
 *
 * **Qué se prueba.** Que el aula se guarde de verdad y que se pueda desvincular.
 * Hasta el 2026-10-31 el aula era una cadena en memoria del explorador: elegirla
 * cambiaba la pantalla y nada más, y al refrescar se perdía.
 */
describe('PATCH /api/v1/admin/archivos/:id/aula', () => {
  let arnés: Arnés;

  afterEach(async () => {
    await arnés?.app.close();
  });

  it('vincula el archivo a un aula y lo devuelve en la respuesta', async () => {
    arnés = crearArnés();

    const respuesta = await arnés.app.inject({
      method: 'PATCH',
      url: `/api/v1/admin/archivos/${ID_ARCHIVO_CONFIRMADO}/aula`,
      headers: conToken(TOKEN_ADMIN),
      payload: { seccionId: ID_SECCION_SA },
    });

    expect(respuesta.statusCode).toBe(200);

    const cuerpo = respuesta.json() as { archivo: { seccionId: string | null } };
    expect(cuerpo.archivo.seccionId).toBe(ID_SECCION_SA);

    // Y queda en el estado, que es lo que sobrevive al refresco.
    const fila = arnés.estado.archivos.find((a) => a.id === ID_ARCHIVO_CONFIRMADO);
    expect(fila?.seccionId).toBe(ID_SECCION_SA);
  });

  it('`null` desvincula sin borrar el archivo', async () => {
    arnés = crearArnés();
    arnés.estado.archivos.push({
      id: ID_ARCHIVO_CONFIRMADO,
      propietarioId: 'perfil-docente-1',
      r2Key: 'llave/x.pdf',
      nombreOriginal: 'x.pdf',
      seccionId: ID_SECCION_SA,
      estado: 'CONFIRMED',
    });

    const respuesta = await arnés.app.inject({
      method: 'PATCH',
      url: `/api/v1/admin/archivos/${ID_ARCHIVO_CONFIRMADO}/aula`,
      headers: conToken(TOKEN_ADMIN),
      payload: { seccionId: null },
    });

    expect(respuesta.statusCode).toBe(200);
    const cuerpo = respuesta.json() as { archivo: { seccionId: string | null } };
    expect(cuerpo.archivo.seccionId).toBeNull();

    const fila = arnés.estado.archivos.find((a) => a.id === ID_ARCHIVO_CONFIRMADO);
    expect(fila, 'el archivo no se borra al desvincular').toBeDefined();
  });

  it('un id que no es UUID se rechaza antes de tocar la base', async () => {
    arnés = crearArnés();

    const respuesta = await arnés.app.inject({
      method: 'PATCH',
      url: '/api/v1/admin/archivos/no-es-uuid/aula',
      headers: conToken(TOKEN_ADMIN),
      payload: { seccionId: ID_SECCION_SA },
    });

    expect(respuesta.statusCode).toBe(400);
  });
});
