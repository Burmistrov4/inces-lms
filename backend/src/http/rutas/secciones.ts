import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import {
  esquemaActualizarSeccion,
  esquemaCrearSeccion,
  esquemaIdSeccion,
  esquemaListadoSecciones,
  esquemaMatricular,
  esquemaResolverGrupo,
  esquemaUnirse,
} from '../esquemas.js';
import { exigirAdmin, exigirSesion, reposDe } from '../plugins/autenticacion.js';

/**
 * Rutas del catálogo de secciones.
 *
 * **Módulo 3 por alcance, Módulo 4 por consumo.** Una sección es el grupo
 * concreto de una materia en un lapso: es lo que el cuadrante usa para colgar sus
 * clases y lo que un estudiante elige al inscribirse. Vive en su propio archivo y
 * no dentro de `cuadrante.ts` porque son ciclos de vida distintos —una sección se
 * crea una vez por lapso; una clase se reordena cada semana— y mezclarlos habría
 * dejado un módulo con dos responsabilidades.
 *
 * **Ninguna ruta borra.** Archivar es `activa: false`. Y no es una convención que
 * se pueda olvidar: el `DELETE` está **revocado** en la base para
 * `authenticated`, así que no existe la opción de borrar. Una sección borrada se
 * llevaría por delante el historial de inscripciones que cuelga de su `id`, que es
 * justo lo que `DROPPED` existe para conservar.
 *
 * El porqué de cada decisión está en `docs/BRIEFING_BACKEND_MODULO4.md`.
 */

/** Envoltorio de `params`: Fastify tipa `params` como objeto y el esquema es del valor suelto. */
const esquemaRutaIdSeccion = z.object({ id: esquemaIdSeccion });

export function rutasSecciones(app: FastifyInstance): void {
  app.register(
    async (admin) => {
      admin.addHook('preHandler', exigirAdmin());

      admin.get('/secciones', async (request) => {
        const { busqueda, periodo, programaId, materiaId, activa, limite, desplazamiento } =
          esquemaListadoSecciones.parse(request.query);

        const { secciones, total } = await reposDe(request).secciones.listar({
          busqueda,
          periodo,
          programaId,
          materiaId,
          activa,
          limite,
          desplazamiento,
        });

        // El eco de la paginación se devuelve junto a las filas, igual que en
        // /aulas, /usuarios y /programas: la pantalla pinta «1 a 25 de 9» con él,
        // sin conservar su propia copia de lo que pidió.
        return { secciones, total, limite, desplazamiento };
      });

      admin.post('/secciones', async (request, reply) => {
        const entrada = esquemaCrearSeccion.parse(request.body);

        // Un nombre repetido dentro del mismo lapso y materia choca con
        // `sections_identidad_unica` y sale como 409 REGISTRO_DUPLICADO. Dos
        // secciones «SA» de la misma materia en el mismo lapso hacen imposible
        // saber a cuál se refiere una inscripción, así que no es un aviso.
        const seccion = await reposDe(request).secciones.crear(entrada);

        // 201 y no 200: se creó un recurso y la respuesta trae su identificador.
        return reply.status(201).send({ seccion });
      });

      admin.patch<{ Params: { id: string } }>('/secciones/:id', async (request) => {
        const { id } = esquemaRutaIdSeccion.parse(request.params);
        const cambios = esquemaActualizarSeccion.parse(request.body);

        // No se comprueba la existencia antes: si el `id` no existe, el `update`
        // no toca ninguna fila y PostgREST responde `PGRST116`, que el repositorio
        // convierte en un 404 SECCION_INEXISTENTE. Comprobar antes costaría una
        // consulta para adelantar un error que la escritura ya sabe dar.
        const seccion = await reposDe(request).secciones.actualizar(id, cambios);

        return { seccion };
      });

      /**
       * Devuelve —o crea— el grupo de una materia en un período.
       *
       * **Es la pieza que quita «sección» de la cara visible.** La interfaz pide
       * curso + materia + período, que es lo que el administrador sabe nombrar, y
       * esta ruta resuelve la fila que liga los tres. Responde 200 si el grupo ya
       * existía y 201 si lo acaba de crear, para que la pantalla pueda decir cuál
       * de las dos cosas pasó sin adivinarlo.
       *
       * No es un `GET` porque **puede escribir**: un `GET` que crea filas rompe
       * la promesa de que leer no cambia nada, y cualquier reintento de un proxy
       * o de un navegador acabaría creando grupos de más.
       */
      admin.post('/grupos/resolver', async (request, reply) => {
        const entrada = esquemaResolverGrupo.parse(request.body);

        const { seccion, creada } = await reposDe(request).secciones.resolverGrupo(entrada);

        return reply.status(creada ? 201 : 200).send({ seccion, creada });
      });

      /**
       * Matricula a un aprendiz en un aula.
       *
       * **No es un `insert`.** `enrollments` tiene la escritura revocada para
       * `authenticated` (R-23), así que esto llama a la RPC
       * `matricular_por_administrador`, que hace su propia autorización. Es
       * idempotente: matricular a quien ya está devuelve 200, no un conflicto —
       * el panel no tiene por qué tragarse un error que no aporta nada.
       */
      admin.post<{ Params: { id: string } }>(
        '/aulas/:id/matricular',
        async (request) => {
          const seccionId = esquemaIdSeccion.parse(request.params.id);
          const { estudianteId } = esquemaMatricular.parse(request.body);

          const estado = await reposDe(request).inscripciones
            .matricularPorAdministrador(estudianteId, seccionId);

          return { estado, seccionId };
        },
      );
    },
    { prefix: '/api/v1/admin' },
  );

  /**
   * El aprendiz canjea el código de su aula.
   *
   * Va fuera del plugin `admin` porque no es administración: es la puerta del
   * alumno. El rol lo comprueba la RPC (no esta ruta): si se comprobara aquí,
   * habría dos sitios donde equivocarse.
   */
  app.post(
    '/api/v1/aulas/unirse',
    // La sesión se exige aquí, y el **rol** dentro de la RPC: si el rol se
    // comprobara también en la ruta, habría dos sitios donde equivocarse.
    { preHandler: exigirSesion() },
    async (request) => {
      const { codigo } = esquemaUnirse.parse(request.body);
      const seccionId = await reposDe(request).inscripciones.unirsePorCodigo(codigo);

      return { seccionId, estado: 'ENROLLED' as const };
    },
  );
}
