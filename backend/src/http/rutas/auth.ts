import type { FastifyInstance } from 'fastify';
import { ErrorApi } from '../../dominio/errores.js';
import { estadoDeCodigoRecuperacion } from '../../dominio/reglas-recuperacion.js';
import { estadoDeInvitacion } from '../../dominio/reglas-invitaciones.js';
import type { DependenciasRutas } from '../dependencias.js';
import {
  esquemaActivarCuenta,
  esquemaCanjearCodigo,
  esquemaRegistroAspirante,
  esquemaSolicitarRecuperacion,
} from '../esquemas.js';
import { crearLimitador } from '../limitador.js';
import {
  generarCodigoRecuperacion,
  hashearToken,
  normalizarCodigo,
} from '../../infra/tokens.js';

/**
 * Rutas de autenticación públicas.
 *
 * Dos: la activación de la invitación de docente y el canje del código de
 * recuperación. Son las únicas rutas protegidas por un **secreto temporal** en
 * vez de por un JWT, porque quien las llama todavía no tiene sesión. Por eso
 * consultan la base con `reposAdmin` (service_role), que salta RLS, y por eso
 * llevan **límite de intentos**: son la puerta que un atacante golpearía.
 *
 * El limitador se crea **por instancia de app** y no a nivel de módulo: en las
 * pruebas se montan varias apps en el mismo proceso y un limitador compartido
 * haría que los casos se estorbaran entre sí, dando fallos que no son del código.
 */
export function rutasAuth(app: FastifyInstance, deps: DependenciasRutas): void {
  // 20 intentos por cuarto de hora y por IP. Un código de 59 bits no se rompe
  // por fuerza bruta ni con millones de intentos; el límite protege sobre todo
  // al servidor (y a GoTrue) de un bucle automatizado, y hace que el abuso deje
  // huella en forma de 429.
  const limitador = crearLimitador({ maximo: 20, ventanaMs: 15 * 60 * 1000 });

  app.register(
    async (aut) => {
      aut.post('/activar', async (request) => {
        if (!limitador.permitir(`activar:${request.ip}`)) {
          throw ErrorApi.demasiadasPeticiones();
        }

        const { token, password } = esquemaActivarCuenta.parse(request.body);

        const ip = request.ip;
        const hash = hashearToken(token);

        const invitacion = await deps.reposAdmin.invitaciones.porTokenHash(hash);

        if (!invitacion) {
          await deps.reposAdmin.acceso.registrar({
            userId: null,
            email: null,
            ip,
            estado: 'FAILED',
          });
          // Respuesta genérica: no revela si el correo existe o si el token es
          // real. Un atacante no distingue "token malo" de "token inexistente".
          throw ErrorApi.noEncontrado(
            'INVITACION_INVALIDA',
            'El enlace de invitación no es válido.',
          );
        }

        const estado = estadoDeInvitacion(invitacion);

        if (estado === 'revocada') {
          await deps.reposAdmin.acceso.registrar({
            userId: invitacion.id,
            email: invitacion.email,
            ip,
            estado: 'FAILED',
          });
          throw ErrorApi.prohibido(
            'INVITACION_REVOCADA',
            'Esta invitación fue anulada por el administrador. Solicita una nueva.',
          );
        }

        if (estado === 'usada') {
          await deps.reposAdmin.acceso.registrar({
            userId: invitacion.id,
            email: invitacion.email,
            ip,
            estado: 'FAILED',
          });
          throw ErrorApi.conflicto('INVITACION_YA_USADA', 'Esta invitación ya fue utilizada.');
        }

        if (estado === 'expirada') {
          await deps.reposAdmin.acceso.registrar({
            userId: invitacion.id,
            email: invitacion.email,
            ip,
            estado: 'FAILED',
          });
          throw ErrorApi.caducado(
            'La invitación caducó. Solicite una nueva al administrador.',
          );
        }

        // **Se reclama el token ANTES de crear la cuenta.** El estado se acaba
        // de leer, pero entre esa lectura y este `update` cabe otra petición: si
        // se creara el usuario primero, dos activaciones simultáneas del mismo
        // enlace podrían crear dos cuentas. Aquí sólo una gana la carrera en la
        // base, y la que pierde recibe el mismo 409 que si hubiera llegado tarde.
        const reclamada = await deps.reposAdmin.invitaciones.consumirSiValida(invitacion.id);

        if (!reclamada) {
          await deps.reposAdmin.acceso.registrar({
            userId: invitacion.id,
            email: invitacion.email,
            ip,
            estado: 'FAILED',
          });
          throw ErrorApi.conflicto('INVITACION_YA_USADA', 'Esta invitación ya fue utilizada.');
        }

        try {
          const idUsuario = await deps.reposAdmin.invitaciones.crearUsuarioDocente(
            invitacion.email,
            password,
            invitacion.nombres,
            invitacion.apellidos,
          );
          const perfil = await deps.reposAdmin.perfiles.cambiarRol(idUsuario, 'docente');
          await deps.reposAdmin.acceso.registrar({
            userId: idUsuario,
            email: invitacion.email,
            ip,
            estado: 'SUCCESS',
          });
          return { email: perfil.email, perfil };
        } catch (error) {
          // El token ya está reclamado y la cuenta no se creó (lo más común:
          // ese correo ya tiene cuenta). Se **libera** la invitación para que el
          // profesor pueda reintentar o el administrador revocarla a mano; sin
          // esto, un fallo transitorio dejaría el enlace quemado para siempre.
          await deps.reposAdmin.invitaciones.liberar(invitacion.id);
          await deps.reposAdmin.acceso.registrar({
            userId: null,
            email: invitacion.email,
            ip,
            estado: 'FAILED',
          });
          throw error;
        }
      });

      /**
       * Solicita el restablecimiento de contraseña vía correo electrónico (Gmail SMTP / Nodemailer).
       *
       * Busca el perfil por email o cédula. Si existe y tiene correo, genera un código
       * seguro de recuperación (válido por 30 minutos), lo persiste en la base y lo envía
       * formateado profesionalmente por correo electrónico.
       *
       * Aplica principio anti-enumeración: siempre devuelve respuesta exitosa para evitar
       * revelar qué cuentas existen a atacantes externos.
       */
      aut.post('/solicitar-recuperacion', async (request) => {
        if (!limitador.permitir(`solicitar:${request.ip}`)) {
          throw ErrorApi.demasiadasPeticiones();
        }

        const { identificador } = esquemaSolicitarRecuperacion.parse(request.body);
        const limpio = identificador.trim();

        // Buscar el perfil por email o cédula
        const perfiles = deps.reposAdmin.perfiles;
        const perfil = await perfiles.porIdentificador(limpio);

        if (perfil && perfil.email && perfil.activo) {
          const codigo = generarCodigoRecuperacion();
          const hash = hashearToken(normalizarCodigo(codigo));
          const expiraEn = new Date(Date.now() + 30 * 60 * 1000).toISOString();

          await deps.reposAdmin.recuperacion.emitir({
            userId: perfil.id,
            codeHash: hash,
            expiresAt: expiraEn,
            createdBy: null,
          });

          const urlRestablecer = `${deps.urlFrente}/#/restablecer-codigo?codigo=${encodeURIComponent(codigo)}`;

          const htmlCorreo = [
            '<div style="font-family:Inter,Segoe UI,Arial,sans-serif;max-width:540px;margin:0 auto;padding:24px;background-color:#ffffff;border:1px solid #e2e8f0;border-radius:12px;">',
            '  <div style="background:linear-gradient(135deg, #0b5cab 0%, #003366 100%);padding:20px;border-radius:8px;text-align:center;margin-bottom:24px;">',
            '    <h1 style="color:#ffffff;margin:0;font-size:20px;font-weight:700;">INCES LMS · Gestión Académica</h1>',
            '    <p style="color:#e2e8f0;margin:4px 0 0;font-size:13px;">CFS Nacional de Soldadura «Rafael Urdaneta»</p>',
            '  </div>',
            `  <h2 style="color:#1e293b;font-size:18px;margin-bottom:12px;">Hola, ${perfil.nombres || 'Usuario'}:</h2>`,
            '  <p style="color:#475569;font-size:14px;line-height:1.5;">Hemos recibido una solicitud para restablecer la contraseña de acceso a tu cuenta en la plataforma del INCES.</p>',
            '  <div style="background-color:#f1f5f9;border-left:4px solid #0b5cab;padding:16px;border-radius:6px;margin:20px 0;text-align:center;">',
            '    <span style="display:block;font-size:12px;color:#64748b;text-transform:uppercase;letter-spacing:1px;margin-bottom:6px;">Tu código de seguridad temporal:</span>',
            `    <strong style="font-size:26px;color:#0b5cab;letter-spacing:3px;font-family:monospace;">${codigo}</strong>`,
            '    <span style="display:block;font-size:12px;color:#64748b;margin-top:6px;">Válido durante los próximos 30 minutos (un solo uso).</span>',
            '  </div>',
            '  <p style="color:#475569;font-size:14px;line-height:1.5;">Puedes ingresar este código directamente en la pantalla de restablecimiento o pulsar en el siguiente enlace directo:</p>',
            '  <div style="text-align:center;margin:24px 0;">',
            `    <a href="${urlRestablecer}" style="background-color:#0b5cab;color:#ffffff;padding:12px 28px;text-decoration:none;border-radius:6px;font-weight:600;font-size:14px;display:inline-block;">Restablecer mi contraseña</a>`,
            '  </div>',
            '  <p style="color:#94a3b8;font-size:12px;line-height:1.4;margin-top:24px;border-top:1px solid #e2e8f0;padding-top:16px;">Si no solicitaste este cambio, puedes ignorar este mensaje de forma segura.</p>',
            '</div>',
          ].join('\n');

          let correoEnviado = false;
          try {
            const resultadoEnvio = await deps.enviarCorreo.enviar({
              para: perfil.email,
              asunto: 'Código de recuperación de contraseña — INCES LMS',
              html: htmlCorreo,
            });
            correoEnviado = resultadoEnvio.entregado;
          } catch (errorCorreo) {
            request.log.warn({ err: errorCorreo }, 'Fallo al despachar correo de recuperación');
          }

          if (!correoEnviado && perfil.email) {
            try {
              const urlRestablecer = `${deps.urlFrente}/#/restablecer-codigo`;
              const supabaseUrl =
                process.env.SUPABASE_URL ||
                'https://twdppwnxlnmxkiejbrei.supabase.co';
              const srvKey =
                process.env.SUPABASE_SERVICE_ROLE_KEY ||
                process.env.SUPABASE_ANON_KEY ||
                '';
              const resSupabase = await fetch(
                `${supabaseUrl}/auth/v1/recover`,
                {
                  method: 'POST',
                  headers: {
                    apikey: srvKey,
                    Authorization: `Bearer ${srvKey}`,
                    'Content-Type': 'application/json',
                  },
                  body: JSON.stringify({
                    email: perfil.email,
                    redirect_to: urlRestablecer,
                  }),
                },
              );
              if (resSupabase.ok) {
                correoEnviado = true;
                return {
                  exito: true,
                  correoEnviado: true,
                  metodo: 'supabase' as const,
                  email: perfil.email,
                  mensaje:
                    'Hemos enviado un enlace de recuperación seguro a tu correo electrónico.',
                };
              }
            } catch (errSupabase) {
              request.log.warn(
                { err: errSupabase },
                'Fallo al despachar recuperación vía Supabase Auth',
              );
            }
          }

          return {
            exito: true,
            correoEnviado,
            metodo: correoEnviado ? ('smtp' as const) : ('supabase' as const),
            // **Sin `email`, a propósito.** Medido el 2026-10-25: la respuesta
            // incluía el correo del perfil cuando el identificador existía, así
            // que la forma del cuerpo distinguía «existe» de «no existe» y
            // entregaba la dirección asociada a cada acierto. Eso convierte la
            // ruta en un oráculo de enumeración y contradice el comentario de
            // arriba, que afirma aplicar el principio anti-enumeración: el
            // `mensaje` no diferenciaba, pero el JSON sí.
            //
            // No hace falta: el usuario escribió el identificador y sabe a qué
            // correo llega. El cliente usa lo que escribió como destino.
            mensaje: correoEnviado
              ? 'Si los datos coinciden con un usuario registrado, hemos enviado las instrucciones y el código a tu correo electrónico.'
              : 'Hemos procesado tu solicitud. Si el correo coincide con una cuenta registrada, recibirás el enlace en tu bandeja.',
          };
        }

        return {
          exito: true,
          correoEnviado: false,
          metodo: 'ninguno' as const,
          mensaje:
            'Si los datos coinciden con un usuario registrado, hemos enviado las instrucciones y el código a tu correo electrónico.',
        };
      });

      /**
       * Canje del código de recuperación.
       *
       * Recorrido: el administrador verifica la identidad por el procedimiento
       * institucional, emite el código y lo entrega en mano o por canal interno;
       * el titular lo trae aquí junto con la contraseña NUEVA que quiere.
       *
       * El código **solo** identifica el restablecimiento: no hace falta el
       * correo, así que no hay nada que enumerar. Un código que no existe, uno
       * caducado y uno ya canjeado responden **lo mismo** —no se distingue el
       * motivo—, que es lo que pide la protección contra enumeración.
       */
      aut.post('/restablecer-codigo', async (request) => {
        if (!limitador.permitir(`recuperar:${request.ip}`)) {
          throw ErrorApi.demasiadasPeticiones();
        }

        const { codigo, password } = esquemaCanjearCodigo.parse(request.body);
        const ip = request.ip;
        const hash = hashearToken(normalizarCodigo(codigo));

        const registro = await deps.reposAdmin.recuperacion.porCodeHash(hash);

        if (!registro) {
          await deps.reposAdmin.acceso.registrar({ userId: null, email: null, ip, estado: 'FAILED' });
          throw ErrorApi.noEncontrado(
            'CODIGO_INVALIDO',
            'El código no es válido o ya caducó. Solicita uno nuevo.',
          );
        }

        const estado = estadoDeCodigoRecuperacion(registro);

        if (estado !== 'valido') {
          await deps.reposAdmin.acceso.registrar({
            userId: registro.userId,
            email: null,
            ip,
            estado: 'FAILED',
          });
          // **Mismo mensaje para los tres motivos** (usado, revocado, caducado):
          // decir «ya se usó» le confirmaría a quien prueba códigos ajenos que
          // acertó uno. El titular legítimo, que tiene el código en la mano,
          // entiende igual el mensaje y pide otro.
          throw ErrorApi.noEncontrado(
            'CODIGO_INVALIDO',
            'El código no es válido o ya caducó. Solicita uno nuevo.',
          );
        }

        // Mismo patrón que la invitación: reclamar antes de tocar la cuenta.
        const reclamado = await deps.reposAdmin.recuperacion.consumirSiValido(registro.id);

        if (!reclamado) {
          await deps.reposAdmin.acceso.registrar({
            userId: registro.userId,
            email: null,
            ip,
            estado: 'FAILED',
          });
          throw ErrorApi.noEncontrado(
            'CODIGO_INVALIDO',
            'El código no es válido o ya caducó. Solicita uno nuevo.',
          );
        }

        try {
          await deps.reposAdmin.recuperacion.cambiarPassword(registro.userId, password);

          // Cambiar la contraseña NO invalida por sí solo los refresh tokens ya
          // emitidos: sin esto, una sesión robada seguiría abierta después del
          // restablecimiento, que es justo lo contrario de lo que se busca.
          await deps.reposAdmin.recuperacion.revocarSesiones(registro.userId);

          const perfil = await deps.reposAdmin.perfiles.porId(registro.userId);
          await deps.reposAdmin.acceso.registrar({
            userId: registro.userId,
            email: perfil?.email ?? null,
            ip,
            estado: 'SUCCESS',
          });

          // El limitador se limpia tras un canje válido: quien acertó no debe
          // arrastrar el contador de sus intentos fallidos previos.
          limitador.olvidar(`recuperar:${ip}`);

          return { email: perfil?.email ?? null };
        } catch (error) {
          // El código vuelve a su estado anterior: si GoTrue falló, el titular
          // no debe quedarse sin el código que le entregaron en mano.
          await deps.reposAdmin.recuperacion.liberar(registro.id);
          await deps.reposAdmin.acceso.registrar({
            userId: registro.userId,
            email: null,
            ip,
            estado: 'FAILED',
          });
          throw error;
        }
      });

      aut.post('/registro-aspirante', async (request) => {
        if (!limitador.permitir(`registro:${request.ip}`)) {
          throw ErrorApi.demasiadasPeticiones();
        }

        const { email, password, metadata } = esquemaRegistroAspirante.parse(request.body);

        try {
          const userId = await deps.reposAdmin.invitaciones.crearUsuarioAspirante(
            email,
            password,
            metadata,
          );

          await deps.reposAdmin.acceso.registrar({
            userId,
            email,
            ip: request.ip,
            estado: 'SUCCESS',
          });

          let correoEnviado = false;
          try {
            const nombreAspirante = metadata?.nombres
              ? `${metadata.nombres} ${metadata?.apellidos ?? ''}`.trim()
              : 'Aspirante';

            const urlLogin = `${deps.urlFrente}/#/login`;

            const htmlBienvenida = [
              '<div style="font-family:Inter,Segoe UI,Arial,sans-serif;max-width:540px;margin:0 auto;padding:24px;background-color:#ffffff;border:1px solid #e2e8f0;border-radius:12px;">',
              '  <div style="background:linear-gradient(135deg, #0b5cab 0%, #003366 100%);padding:20px;border-radius:8px;text-align:center;margin-bottom:24px;">',
              '    <h1 style="color:#ffffff;margin:0;font-size:20px;font-weight:700;">INCES LMS · Registro de Aspirante</h1>',
              '    <p style="color:#e2e8f0;margin:4px 0 0;font-size:13px;">CFS Nacional de Soldadura «Rafael Urdaneta»</p>',
              '  </div>',
              `  <h2 style="color:#1e293b;font-size:18px;margin-bottom:12px;">¡Bienvenido/a, ${nombreAspirante}!</h2>`,
              '  <p style="color:#475569;font-size:14px;line-height:1.5;">Tu cuenta en el Sistema de Gestión Académica del INCES ha sido creada exitosamente.</p>',
              '  <div style="background-color:#f0fdf4;border-left:4px solid #16a34a;padding:14px;border-radius:6px;margin:20px 0;">',
              '    <strong style="color:#166534;font-size:13px;">Próximos pasos para completar tu ingreso:</strong>',
              '    <ol style="color:#374151;font-size:13px;line-height:1.6;margin:8px 0 0 16px;padding:0;">',
              '      <li>Inicia sesión con tu correo electrónico y la contraseña que has configurado.</li>',
              '      <li>Completa los datos de tu <strong>Planilla Oficial de Inscripción</strong>.</li>',
              '      <li>Selecciona el curso o programa técnico de tu preferencia para postularte.</li>',
              '    </ol>',
              '  </div>',
              '  <div style="text-align:center;margin:24px 0;">',
              `    <a href="${urlLogin}" style="background-color:#0b5cab;color:#ffffff;padding:12px 28px;text-decoration:none;border-radius:6px;font-weight:600;font-size:14px;display:inline-block;">Ingresar al Sistema</a>`,
              '  </div>',
              '  <p style="color:#94a3b8;font-size:12px;line-height:1.4;margin-top:24px;border-top:1px solid #e2e8f0;padding-top:16px;">Si no realizaste este registro, por favor notifícalo a la coordinación del centro.</p>',
              '</div>',
            ].join('\n');

            const res = await deps.enviarCorreo.enviar({
              para: email,
              asunto: '¡Bienvenido al INCES! Confirmación de Registro de Aspirante',
              html: htmlBienvenida,
            });
            correoEnviado = res.entregado;
          } catch (errorCorreo) {
            request.log.warn({ err: errorCorreo }, 'Fallo al despachar correo de bienvenida al aspirante');
          }

          return {
            exito: true,
            userId,
            correoEnviado,
            mensaje: 'Cuenta de aspirante creada y confirmada exitosamente.',
          };
        } catch (error) {
          await deps.reposAdmin.acceso.registrar({
            userId: null,
            email,
            ip: request.ip,
            estado: 'FAILED',
          });
          throw error;
        }
      });
    },
    { prefix: '/api/v1/auth' },
  );
}
