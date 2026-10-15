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
}

export interface ResultadoEnvio {
  /** `true` si el proveedor aceptó el mensaje. */
  entregado: boolean;
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

/**
 * Remitente basado en SMTP (Nodemailer), ideal para Gmail.
 */
export function crearRemitenteSMTP(opciones: OpcionesRemitenteSMTP): EnvioCorreo {
  const { host, port, user, pass, from } = opciones;

  if (!user || !pass) {
    return {
      async enviar(): Promise<ResultadoEnvio> {
        return { entregado: false };
      },
    };
  }

  const secure = opciones.secure ?? (port === 465);
  const transporter = nodemailer.createTransport({
    host,
    port,
    secure,
    auth: {
      user,
      pass,
    },
  });

  const remitente = from ?? `"INCES LMS" <${user}>`;

  return {
    async enviar(mensaje: MensajeCorreo): Promise<ResultadoEnvio> {
      try {
        await transporter.sendMail({
          from: remitente,
          to: mensaje.para,
          subject: mensaje.asunto,
          html: mensaje.html,
        });
        return { entregado: true };
      } catch (error) {
        console.error('Error al enviar correo vía SMTP:', error);
        return { entregado: false };
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
      if (!apiKey) return { entregado: false };

      try {
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
          }),
        });

        if (!respuesta.ok) return { entregado: false };
        return { entregado: true };
      } catch {
        return { entregado: false };
      }
    },
  };
}
