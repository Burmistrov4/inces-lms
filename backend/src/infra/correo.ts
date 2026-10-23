/**
 * Envío de correo transaccional.
 *
 * **Dos vías, en este orden** (decisión de Lorenzo, 2026-10-20):
 *
 *  1. **Gmail SMTP (Nodemailer)** — vía prioritaria. Sin restricciones de dominio
 *     y sin coste: basta una Contraseña de Aplicación de Google.
 *  2. **Supabase Auth (`/auth/v1/invite`)** — red de seguridad cuando SMTP no
 *     está configurado o falla. Supabase envía su propio correo de invitación
 *     (plantilla del panel de Auth), así que el mensaje llega aunque nuestro
 *     HTML no pueda salir. Es lo que permite no depender de ningún proveedor de
 *     pago: **Resend se retiró por completo el 2026-10-20** porque exigía un
 *     dominio de pago para enviar a destinatarios reales.
 *
 * **Honestidad sobre la vía 2.** Supabase sólo invita: si la dirección ya tiene
 * cuenta en Auth, responde `422` y no reenvía nada. En ese caso el sistema queda
 * en `{ entregado: false }` y la activación se apoya en el enlace directo que el
 * administrador recibe en pantalla (el flujo de invitación lo devuelve siempre).
 * La activación **nunca** depende del correo.
 *
 * El envío nunca es bloqueante ni lanza excepciones no controladas: si el
 * proveedor falla o no está configurado, devuelve `{ entregado: false }` para
 * que el flujo de negocio continúe íntegro.
 */

import nodemailer from 'nodemailer';

export interface MensajeCorreo {
  para: string;
  asunto: string;
  html: string;
  texto?: string;
}

export interface ResultadoEnvio {
  /** `true` si el proveedor aceptó el mensaje. */
  entregado: boolean;
  proveedor?: 'smtp' | 'supabase' | 'ninguno';
  detalle?: string;
}

export interface EnvioCorreo {
  enviar(mensaje: MensajeCorreo): Promise<ResultadoEnvio>;
}

export interface OpcionesRemitenteSMTP {
  host: string;
  port: number;
  secure?: boolean;
  user?: string;
  pass?: string;
  from?: string;
}

function extraerTextoDeHtml(html: string): string {
  return html
    .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n\n')
    .replace(/<\/li>/gi, '\n')
    .replace(/<\/div>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

/**
 * Remitente basado en SMTP (Nodemailer), ideal para Gmail.
 */
export function crearRemitenteSMTP(opciones: OpcionesRemitenteSMTP): EnvioCorreo {
  const { host, port, user, pass, from } = opciones;

  if (!user || !pass) {
    return {
      async enviar(): Promise<ResultadoEnvio> {
        return { entregado: false, proveedor: 'ninguno' };
      },
    };
  }

  const secure = opciones.secure ?? (port === 465);
  const passLimpia = pass.replace(/\s+/g, '');
  const transporter = nodemailer.createTransport({
    host,
    port,
    secure,
    auth: {
      user: user.trim(),
      pass: passLimpia,
    },
    connectionTimeout: 2500,
    greetingTimeout: 2500,
    socketTimeout: 3500,
  });

  const remitente = from ?? `"INCES LMS · CFS Rafael Urdaneta" <${user.trim()}>`;

  return {
    async enviar(mensaje: MensajeCorreo): Promise<ResultadoEnvio> {
      try {
        const cuerpoTexto = mensaje.texto ?? extraerTextoDeHtml(mensaje.html);
        await transporter.sendMail({
          from: remitente,
          to: mensaje.para,
          subject: mensaje.asunto,
          html: mensaje.html,
          text: cuerpoTexto,
        });
        return { entregado: true, proveedor: 'smtp' };
      } catch (error) {
        console.error('Error al enviar correo vía SMTP:', error);
        return {
          entregado: false,
          proveedor: 'smtp',
          detalle: error instanceof Error ? error.message : String(error),
        };
      }
    },
  };
}

export interface OpcionesRemitenteSupabase {
  /** URL del proyecto Supabase (`https://xxx.supabase.co`). */
  url: string;
  /** Clave `service_role`: la invites exigen privilegio de administrador. */
  serviceRoleKey: string;
  /** A dónde lleva el enlace del correo que Supabase envía. */
  redirectTo?: string;
}

/**
 * Remitente de reserva: delegа el envío en Supabase Auth.
 *
 * **Sólo sabe invitar.** La Admin API de Supabase no envía correos arbitrarios:
 * `/auth/v1/invite` crea (o reutiliza) el usuario y hace que el panel de Auth le
 * mande su correo de invitación. Por eso la interfaz [MensajeCorreo] se degrada
 * con honestidad: se usa `para` y, si viene, el `redirectTo`; el `asunto` y el
 * `html` propios se descartan porque no hay dónde meterlos en la plantilla de
 * Supabase. Es una red de seguridad, no un canal equivalente.
 *
 * El `422` de «usuario ya registrado» es el caso esperado cuando alguien reenvía
 * una invitación: se devuelve `entregado: false` y quien llama decide (el flujo
 * de invitación muestra el enlace directo al administrador).
 */
export function crearRemitenteSupabase(opciones: OpcionesRemitenteSupabase): EnvioCorreo {
  const { url, serviceRoleKey, redirectTo } = opciones;

  return {
    async enviar(mensaje: MensajeCorreo): Promise<ResultadoEnvio> {
      if (!serviceRoleKey || !url) {
        return { entregado: false, proveedor: 'ninguno' };
      }

      try {
        const respuesta = await fetch(`${url}/auth/v1/invite`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${serviceRoleKey}`,
            'Content-Type': 'application/json',
            apikey: serviceRoleKey,
          },
          body: JSON.stringify({
            email: mensaje.para,
            ...(redirectTo ? { redirect_to: redirectTo } : {}),
          }),
        });

        if (respuesta.status === 422) {
          // Usuario ya existe: no hay reenvío posible por esta vía.
          console.warn(
            `Supabase no pudo invitar a ${mensaje.para}: la cuenta ya existe.`,
          );
          return {
            entregado: false,
            proveedor: 'supabase',
            detalle: 'La cuenta ya existe en Supabase; el correo no se reenvía.',
          };
        }

        if (!respuesta.ok) {
          const errText = await respuesta.text().catch(() => '');
          console.warn(
            `Invitación de Supabase rechazada (HTTP ${respuesta.status}): ${errText}`,
          );
          return {
            entregado: false,
            proveedor: 'supabase',
            detalle: errText,
          };
        }

        return { entregado: true, proveedor: 'supabase' };
      } catch (error) {
        return {
          entregado: false,
          proveedor: 'supabase',
          detalle: error instanceof Error ? error.message : String(error),
        };
      }
    },
  };
}

export interface OpcionesRemitenteTransaccional {
  smtp?: OpcionesRemitenteSMTP;
  supabase?: OpcionesRemitenteSupabase;
}

/**
 * Remitente transaccional resiliente con tolerancia a fallos en cascada:
 * 1. Prioriza Gmail SMTP (Nodemailer) cuando están configuradas las credenciales
 *    de aplicación —es el único canal que lleva NUESTRO asunto y NUESTRO HTML.
 * 2. Si SMTP falla o no está configurado, delega en Supabase (`/auth/v1/invite`),
 *    que envía su propio correo de invitación. Red de seguridad, no equivalente.
 * 3. Si ambos fallan o no hay credenciales, devuelve
 *    `{ entregado: false, proveedor: 'ninguno' }` sin jamás lanzar excepciones
 *    que puedan abortar el flujo del usuario.
 */
export function crearRemitenteTransaccional(opciones: OpcionesRemitenteTransaccional): EnvioCorreo {
  const remitenteSmtp = (opciones.smtp?.user && opciones.smtp?.pass)
    ? crearRemitenteSMTP(opciones.smtp)
    : null;

  const remitenteSupabase = (opciones.supabase?.url && opciones.supabase?.serviceRoleKey)
    ? crearRemitenteSupabase(opciones.supabase)
    : null;

  if (!remitenteSmtp && !remitenteSupabase) {
    return {
      async enviar(): Promise<ResultadoEnvio> {
        return { entregado: false, proveedor: 'ninguno' };
      },
    };
  }

  return {
    async enviar(mensaje: MensajeCorreo): Promise<ResultadoEnvio> {
      if (remitenteSmtp) {
        try {
          const resSmtp = await remitenteSmtp.enviar(mensaje);
          if (resSmtp.entregado) {
            return resSmtp;
          }
          console.warn(
            'Entrega SMTP no exitosa; recurriendo a la invitación de Supabase como red de seguridad...',
          );
        } catch (error) {
          console.error('Error al intentar entrega SMTP:', error);
        }
      }

      if (remitenteSupabase) {
        try {
          const resSupabase = await remitenteSupabase.enviar(mensaje);
          if (resSupabase.entregado) {
            return resSupabase;
          }
        } catch (error) {
          console.error('Error al intentar entrega vía Supabase:', error);
        }
      }

      return { entregado: false, proveedor: 'ninguno' };
    },
  };
}
