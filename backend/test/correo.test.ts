import { describe, expect, it, vi } from 'vitest';
import {
  crearRemitenteSMTP,
  crearRemitenteResend,
  crearRemitenteTransaccional,
} from '../src/infra/correo.js';

describe('infraestructura de correo transaccional', () => {
  it('sin configuración SMTP ni Resend, devuelve no entregado sin fallar', async () => {
    const remitente = crearRemitenteTransaccional({});
    const resultado = await remitente.enviar({
      para: 'test@inces.test',
      asunto: 'Prueba',
      html: '<p>Hola</p>',
    });

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

    const resultado = await remitente.enviar({
      para: 'test@inces.test',
      asunto: 'Prueba',
      html: '<p>Hola</p>',
    });

    expect(resultado.entregado).toBe(false);
    expect(resultado.proveedor).toBe('ninguno');
  });

  it('crearRemitenteResend sin API key devuelve no entregado', async () => {
    const remitente = crearRemitenteResend({
      apiKey: '',
      from: 'onboarding@resend.dev',
    });

    const resultado = await remitente.enviar({
      para: 'test@inces.test',
      asunto: 'Prueba',
      html: '<p>Hola</p>',
    });

    expect(resultado.entregado).toBe(false);
    expect(resultado.proveedor).toBe('ninguno');
  });

  it('fallback automático: si SMTP no puede enviar, intenta vía Resend', async () => {
    // Simulamos un remitente donde SMTP tiene credenciales pero falla en transporte
    const remitente = crearRemitenteTransaccional({
      smtp: {
        host: 'servidor-inexistente-12345.local',
        port: 465,
        user: 'usuario@gmail.com',
        pass: 'clave-invalida',
      },
      resend: {
        apiKey: 're_dummy_test_key',
        from: 'onboarding@resend.dev',
      },
    });

    // Mockeamos global.fetch para que Resend responda 200
    const fetchOriginal = globalThis.fetch;
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ id: 'email_123' }),
    });

    try {
      const resultado = await remitente.enviar({
        para: 'aspirante@inces.test',
        asunto: 'Confirmación de Registro',
        html: '<p>Bienvenido</p>',
      });

      expect(resultado.entregado).toBe(true);
      expect(resultado.proveedor).toBe('resend');
    } finally {
      globalThis.fetch = fetchOriginal;
    }
  });

  it('si tanto SMTP como Resend fallan, devuelve entregado: false de manera resiliente', async () => {
    const remitente = crearRemitenteTransaccional({
      smtp: {
        host: 'servidor-inexistente-12345.local',
        port: 465,
        user: 'usuario@gmail.com',
        pass: 'clave-invalida',
      },
      resend: {
        apiKey: 're_dummy_test_key',
        from: 'onboarding@resend.dev',
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
});
