import { construirApp, VERSION_API } from './app.js';
import { cargarEnv } from './config/env.js';
import { crearRepositorios, crearVerificadorDeTokens } from './infra/repos-supabase.js';
import {
  crearRemitenteTransaccional,
  type EnvioCorreo,
} from './infra/correo.js';
import {
  crearClienteAdmin,
  crearClienteAnonimo,
  crearClienteDeUsuario,
} from './infra/supabase.js';

/**
 * Punto de entrada.
 *
 * Es el único archivo que lee `process.env` y abre conexiones. Todo lo demás
 * recibe sus dependencias por parámetro, y por eso es testeable.
 */
async function main(): Promise<void> {
  // Falla en el arranque si falta configuración: mejor un contenedor que no
  // levanta que un 500 intermitente en producción.
  const env = cargarEnv();

  const clienteAnonimo = crearClienteAnonimo(env);
  const reposAdmin = crearRepositorios(crearClienteAdmin(env));

  // SMTP de Gmail primero; si falla o no está configurado, la invitación de
  // Supabase como red de seguridad (Resend se retiró el 2026-10-20: exigía
  // dominio de pago). `redirectTo` lleva al usuario a la activación propia.
  const enviarCorreo: EnvioCorreo = crearRemitenteTransaccional({
    smtp: (env.SMTP_USER && env.SMTP_PASS)
      ? {
          host: env.SMTP_HOST,
          port: env.SMTP_PORT,
          secure: env.SMTP_SECURE,
          user: env.SMTP_USER,
          pass: env.SMTP_PASS,
          from: env.SMTP_FROM,
        }
      : undefined,
    supabase: (env.SUPABASE_URL && env.SUPABASE_SERVICE_ROLE_KEY)
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
    reposDePeticion: (token) => crearRepositorios(crearClienteDeUsuario(env, token)),
    enviarCorreo,
  });

  const cerrarOrdenadamente = async (senal: string): Promise<void> => {
    app.log.info(`Señal ${senal} recibida: cerrando sin cortar peticiones en vuelo.`);
    try {
      await app.close();
      process.exit(0);
    } catch (error) {
      app.log.error({ err: error }, 'error al cerrar');
      process.exit(1);
    }
  };

  process.on('SIGTERM', () => void cerrarOrdenadamente('SIGTERM'));
  process.on('SIGINT', () => void cerrarOrdenadamente('SIGINT'));

  await app.listen({ port: env.PORT, host: env.HOST });

  app.log.info(
    `INCES LMS API v${VERSION_API} escuchando en ${env.HOST}:${env.PORT} ` +
      `(entorno: ${env.NODE_ENV})`,
  );
}

main().catch((error: unknown) => {
  const mensaje = error instanceof Error ? error.message : String(error);
  console.error('\nNo se pudo arrancar la API:\n');
  console.error(mensaje);
  console.error('');
  process.exit(1);
});
