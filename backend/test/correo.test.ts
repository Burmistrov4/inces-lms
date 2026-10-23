import { describe, expect, it, vi } from 'vitest';
import {
  crearRemitenteSMTP,
  crearRemitenteSupabase,
  crearRemitenteTransaccional,
} from '../src/infra/correo.js';

/**
 * Cadena de entrega (decisión de Lorenzo, 2026-10-20):
 *
 *   1. Gmail SMTP — única vía que lleva NUESTRO asunto y NUESTRO HTML.
 *   2. Supabase `/auth/v1/invite` — red de seguridad: el correo lo manda el
 *      panel de Auth de Supabase. **Resend se retiró**: exigía dominio de pago.
 *
 * Estos pruebas fijan la cascada: si SMTP cae, la invitación de Supabase
 * responde; si Supabase además falla (o la cuenta ya existe, 422), el sistema
 * degrada a `entregado: false` y el flujo de invitación se apoya en el enlace
 * directo. Un `entregado: false` nunca debe lanzar.
 */
describe('infraestructura de correo transaccional', () => {
  const mensaje = {
    para: 'test@inces.test',
    asunto: 'Prueba',
    html: '<p>Hola</p>',
  };

  it('sin configuración SMTP ni Supabase, devuelve no entregado sin fallar', async () => {
    const remitente = crearRemitenteTransaccional({});
    const resultado = await remitente.enviar(mensaje);

    expect(resultado.entregado).toBe(false);
    expect(resultado.proveedor).toBe('ninguno');
  });

  it('crearRemitenteSMTP sin credenciales completas devuelve no entregado', async () => {
    const remitente = crearRemitenteSMTP({
      host: 'smtp.gmail.com',
      port: 465,
      user: '',
      pass: '',
    });

    const resultado = await remitente.enviar(mensaje);

    expect(resultado.entregado).toBe(false);
    expect(resultado.proveedor).toBe('ninguno');
  });

  it('crearRemitenteSupabase sin service role devuelve no entregado', async () => {
    const remitente = crearRemitenteSupabase({
      url: 'https://proyecto.supabase.co',
      serviceRoleKey: '',
    });

    const resultado = await remitente.enviar(mensaje);

    expect(resultado.entregado).toBe(false);
    expect(resultado.proveedor).toBe('ninguno');
  });

  it('fallback automático: si SMTP no puede enviar, invita vía Supabase', async () => {
    const remitente = crearRemitenteTransaccional({
      smtp: {
        host: 'servidor-inexistente-12345.local',
        port: 465,
        user: 'usuario@gmail.com',
        pass: 'clave-invalida',
      },
      supabase: {
        url: 'https://proyecto.supabase.co',
        serviceRoleKey: 'service_role_de_prueba',
        redirectTo: 'https://inces-lms.pages.dev/#/auth/activate',
      },
    });

    const fetchOriginal = globalThis.fetch;
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ id: 'usuario-123' }),
    });

    try {
      const resultado = await remitente.enviar({
        para: 'aspirante@inces.test',
        asunto: 'Confirmación de Registro',
        html: '<p>Bienvenido</p>',
      });

      expect(resultado.entregado).toBe(true);
      expect(resultado.proveedor).toBe('supabase');
    } finally {
      globalThis.fetch = fetchOriginal;
    }
  });

  it('si tanto SMTP como Supabase fallan, devuelve entregado: false de manera resiliente', async () => {
    const remitente = crearRemitenteTransaccional({
      smtp: {
        host: 'servidor-inexistente-12345.local',
        port: 465,
        user: 'usuario@gmail.com',
        pass: 'clave-invalida',
      },
      supabase: {
        url: 'https://proyecto.supabase.co',
        serviceRoleKey: 'service_role_de_prueba',
      },
    });

    const fetchOriginal = globalThis.fetch;
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 401,
      text: async () => 'Unauthorized',
    });

    try {
      const resultado = await remitente.enviar({
        para: 'aspirante@inces.test',
        asunto: 'Confirmación de Registro',
        html: '<p>Bienvenido</p>',
      });

      expect(resultado.entregado).toBe(false);
      expect(resultado.proveedor).toBe('ninguno');
    } finally {
      globalThis.fetch = fetchOriginal;
    }
  });

  it('Supabase no reenvía si la cuenta ya existe (422): entregado false, sin lanzar', async () => {
    const remitente = crearRemitenteSupabase({
      url: 'https://proyecto.supabase.co',
      serviceRoleKey: 'service_role_de_prueba',
    });

    const fetchOriginal = globalThis.fetch;
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 422,
      text: async () => 'A user with this email address has already been registered',
    });

    try {
      const resultado = await remitente.enviar(mensaje);

      expect(resultado.entregado).toBe(false);
      expect(resultado.proveedor).toBe('supabase');
      expect(resultado.detalle).toContain('ya existe');
    } finally {
      globalThis.fetch = fetchOriginal;
    }
  });
});
