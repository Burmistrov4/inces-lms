import type { IncomingMessage, ServerResponse } from 'node:http';
import { Readable } from 'node:stream';

import { construirApp } from './app.js';
import { cargarEnv } from './config/env.js';
import { crearRemitenteTransaccional, type EnvioCorreo } from './infra/correo.js';
import {
  crearClienteAdmin,
  crearClienteAnonimo,
  crearClienteDeUsuario,
} from './infra/supabase.js';
import { crearRepositorios, crearVerificadorDeTokens } from './infra/repos-supabase.js';

/**
 * Adaptador de Vercel.
 *
 * **Por qué existe.** Render agota sus 750 horas al mes y suspende; Cloud Run y
 * Fly exigen tarjeta, y las del dueño son prepagadas (`OR_CCR_104`). Vercel
 * Hobby es la única pieza del mercado que es gratis, no pide tarjeta, no tiene
 * techo de horas y no duerme el servicio.
 *
 * **No hay reescritura.** `construirApp` ya recibe todo por parámetro y no lee
 * `process.env`; este archivo hace exactamente lo que hacía `server.ts` —cargar
 * el entorno, construir los clientes de Supabase y la app— y en vez de
 * `app.listen()` entrega la petición al servidor interno de Fastify. Las ~100
 * rutas, los hooks, las guardias y la RLS siguen intactos.
 *
 * Lo que **no** funciona en Vercel y se acepta a sabiendas:
 *
 * - **WebSocket** (`/api/v1/asistencia/rt`, M7). Las funciones serverless son de
 *   una sola petición: el canal no puede quedarse abierto. La ruta ya responde
 *   200 con una descripción del upgrade a un GET plano, así que la pantalla del
 *   docente recibe el aviso y la lista de asistencia sigue funcionando por REST;
 *   lo que se pierde es el empujón en vivo.
 * - **`@fastify/rate-limit` en memoria**: cada instancia arranca con su propio
 *   contador, así que el límite real es más alto que `RATE_LIMIT_MAX`. El límite
 *   de verdad lo pone Supabase con la RLS y el propio Vercel.
 * - **Caché de módulos y parámetros**: igual, por instancia y de vida corta.
 */

/**
 * La app se construye **una vez por instancia** y se reutiliza entre
 * invocaciones mientras el contenedor siga caliente.
 *
 * Se guarda la *promesa* y no la app: dos peticiones que llegan a la vez durante
 * el arranque en frío compartirían la misma construcción en vez de montar dos
 * aplicaciones y duplicar el registro de rutas —que en Fastify lanzaría por
 * ruta duplicada.
 */
let appLista: Promise<ReturnType<typeof construirApp>> | null = null;

/**
 * Vercel entrega el cuerpo **ya parseado** en `req.body`, así que el stream que
 * Fastify espera leer llega vacío y la petición se queda colgada hasta el
 * timeout. Este hook devuelve el contenido al stream en el formato que el
 * cliente envió.
 *
 * Se prefiere esto a `bodyParser: false` porque en las funciones sueltas de
 * `api/` (sin Next.js) no hay forma de desactivar el parser de `@vercel/node`.
 */
function devolverCuerpoAlStream(
  app: ReturnType<typeof construirApp>,
): void {
  app.addHook('preParsing', async (request, _reply, payload) => {
    const crudo = (request.raw as IncomingMessage & { body?: unknown }).body;
    if (crudo === undefined || crudo === null) return payload;

    if (Buffer.isBuffer(crudo)) return Readable.from(crudo);
    if (typeof crudo === 'string') return Readable.from(Buffer.from(crudo));

    const tipo = String(request.headers['content-type'] ?? '');
    if (tipo.includes('application/x-www-form-urlencoded')) {
      const pares: [string, string][] = Object.entries(
        crudo as Record<string, unknown>,
      ).map(([k, v]) => [k, String(v)]);
      const plano = new URLSearchParams(pares).toString();
      return Readable.from(Buffer.from(plano));
    }

    return Readable.from(Buffer.from(JSON.stringify(crudo)));
  });
}

async function obtenerApp(): Promise<ReturnType<typeof construirApp>> {
  if (!appLista) {
    appLista = (async () => {
      const env = cargarEnv();

      const clienteAnonimo = crearClienteAnonimo(env);
      const reposAdmin = crearRepositorios(crearClienteAdmin(env));

      const enviarCorreo: EnvioCorreo = crearRemitenteTransaccional({
        smtp:
          env.SMTP_USER && env.SMTP_PASS
            ? {
                host: env.SMTP_HOST,
                port: env.SMTP_PORT,
                secure: env.SMTP_SECURE,
                user: env.SMTP_USER,
                pass: env.SMTP_PASS,
                from: env.SMTP_FROM,
              }
            : undefined,
        supabase:
          env.SUPABASE_URL && env.SUPABASE_SERVICE_ROLE_KEY
            ? {
                url: env.SUPABASE_URL,
                serviceRoleKey: env.SUPABASE_SERVICE_ROLE_KEY,
                redirectTo: env.FRONTEND_URL
                  ? `${env.FRONTEND_URL}/#/auth/activate`
                  : undefined,
              }
            : undefined,
      });

      const app = construirApp(env, {
        verificarToken: crearVerificadorDeTokens(clienteAnonimo),
        reposAdmin,
        reposDePeticion: (token) =>
          crearRepositorios(crearClienteDeUsuario(env, token)),
        enviarCorreo,
      });

      devolverCuerpoAlStream(app);

      // `ready()` y no `listen()`: en Vercel no hay puerto que abrir, pero los
      // plugins asíncronos (cors, helmet, rate-limit, websocket) tienen que
      // terminar de registrarse antes de la primera petición.
      await app.ready();
      return app;
    })();
  }
  return appLista;
}

/**
 * Handler que Vercel invoca en cada petición.
 *
 * `server.emit('request')` es la vía documentada por Fastify para correr sobre
 * un `IncomingMessage` ajeno: se salta el servidor HTTP pero conserva enrutado,
 * hooks, serialización y manejo de errores.
 */
export default async function handler(
  req: IncomingMessage,
  res: ServerResponse,
): Promise<void> {
  try {
    const app = await obtenerApp();
    app.server.emit('request', req, res);
  } catch (error) {
    // Si el arranque falla (falta una variable, Supabase inalcanzable), el
    // error tiene que verse en los logs de Vercel y no quedarse en un 504 mudo.
    console.error('No se pudo arrancar la API en Vercel:', error);
    if (!res.headersSent) {
      res.statusCode = 500;
      res.setHeader('content-type', 'application/json');
      res.end(
        JSON.stringify({
          error: {
            codigo: 'ARRANQUE_FALLIDO',
            mensaje: 'La API no pudo arrancar. Revisa la configuración.',
          },
        }),
      );
    }
  }
}
