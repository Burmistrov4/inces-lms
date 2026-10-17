/**
 * Envío de correo transaccional.
 *
 * Soporta dos vías de entrega:
 *  1. SMTP de Gmail (Nodemailer): vía prioritaria y sin restricciones de dominio,
 *     usando `smtp.gmail.com` (465 SSL o 587 TLS) con Contraseña de Aplicación de Google.
 *  2. API REST de Resend: vía secundaria cuando se configura `RESEND_API_KEY`.
 *
 * El envío nunca es bloqueante ni lanza excepciones no controladas: si el proveedor
 * falla o no está configurado, devuelve `{ entregado: false }` para que el flujo
 * de negocio continúe de forma íntegra.
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
  proveedor?: 'smtp' | 'resend' | 'ninguno';
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
    .replace(/<br\s*[\/]?>/gi, '\n')
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

export interface OpcionesRemitenteResend {
  /** API key de Resend (`re_...`). Sin ella, el envío se considera no entregado. */
  apiKey?: string;
  /** Remitente. Sin dominio verificado, Resend exige `onboarding@resend.dev`. */
  from: string;
}

/**
 * Remitente basado en la API REST de Resend (`https://api.resend.com/emails`).
 */
export function crearRemitenteResend(opciones: OpcionesRemitenteResend): EnvioCorreo {
  const { apiKey, from } = opciones;

  return {
    async enviar(mensaje: MensajeCorreo): Promise<ResultadoEnvio> {
      if (!apiKey) return { entregado: false, proveedor: 'ninguno' };

      try {
        const cuerpoTexto = mensaje.texto ?? extraerTextoDeHtml(mensaje.html);
        const respuesta = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${apiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            from,
            to: [mensaje.para],
            subject: mensaje.asunto,
            html: mensaje.html,
            text: cuerpoTexto,
          }),
        });

        if (!respuesta.ok) {
          const errText = await respuesta.text().catch(() => '');
          console.warn(`Envío vía Resend rechazado (HTTP ${respuesta.status}): ${errText}`);
          return { entregado: false, proveedor: 'resend', detalle: errText };
        }
        return { entregado: true, proveedor: 'resend' };
      } catch (error) {
        return {
          entregado: false,
          proveedor: 'resend',
          detalle: error instanceof Error ? error.message : String(error),
        };
      }
    },
  };
}

export interface OpcionesRemitenteTransaccional {
  smtp?: OpcionesRemitenteSMTP;
  resend?: OpcionesRemitenteResend;
}

/**
 * Remitente transaccional resiliente con tolerancia a fallos en cascada:
 * 1. Prioriza Gmail SMTP (Nodemailer) cuando están configuradas las credenciales de aplicación.
 * 2. Si SMTP falla o no está configurado, efectúa fallback automático a Resend (si tiene API Key).
 * 3. Si ambos fallan o no hay credenciales, devuelve `{ entregado: false, proveedor: 'ninguno' }`
 *    sin jamás lanzar excepciones no controladas que puedan abortar el flujo del usuario.
 */
export function crearRemitenteTransaccional(opciones: OpcionesRemitenteTransaccional): EnvioCorreo {
  const remitenteSmtp = (opciones.smtp?.user && opciones.smtp?.pass)
    ? crearRemitenteSMTP(opciones.smtp)
    : null;

  const remitenteResend = opciones.resend?.apiKey
    ? crearRemitenteResend(opciones.resend)
    : null;

  if (!remitenteSmtp && !remitenteResend) {
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
          console.warn('Entrega SMTP no exitosa; recurriendo a fallback transaccional si está disponible...');
        } catch (error) {
          console.error('Error al intentar entrega SMTP:', error);
        }
      }

      if (remitenteResend) {
        try {
          const resResend = await remitenteResend.enviar(mensaje);
          if (resResend.entregado) {
            return resResend;
          }
        } catch (error) {
          console.error('Error al intentar entrega fallback con Resend:', error);
        }
      }

      return { entregado: false, proveedor: 'ninguno' };
    },
  };
}
