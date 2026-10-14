import { describe, expect, it } from 'vitest';
import { nombreVisible } from '../src/dominio/reglas-perfiles.js';

/**
 * La regla del nombre visible, que nació de un defecto medido en producción:
 * los perfiles con `nombres` y `apellidos` vacíos dejaban la fila del inscrito
 * **en blanco** en el panel de administración.
 *
 * La causa era de mecanismo, no de dato: la composición devolvía `''` (cadena
 * vacía) en vez de `null`, y `nombre ?? emergencia` **no salta** con `''`
 * porque `??` sólo mira `null`/`undefined`. Estas pruebas fijan el mecanismo:
 * vacío y espacios devuelven `null`, y cualquier resto de nombre real se
 * devuelve recortado.
 */
describe('nombreVisible', () => {
  it('junta nombres y apellidos con un espacio', () => {
    expect(nombreVisible('Ana', 'Pérez')).toBe('Ana Pérez');
  });

  it('devuelve null cuando ambos están vacíos —no una cadena vacía', () => {
    // El caso del defecto: `''` hacía que el `??` del cliente no saltara.
    expect(nombreVisible('', '')).toBeNull();
  });

  it('devuelve null cuando ambos son null o undefined', () => {
    expect(nombreVisible(null, null)).toBeNull();
    expect(nombreVisible(undefined, undefined)).toBeNull();
  });

  it('ignora los espacios en blanco: un perfil «llenado» con espacios también está vacío', () => {
    expect(nombreVisible('   ', '\t')).toBeNull();
  });

  it('conserva la mitad que sí existe, recortada', () => {
    expect(nombreVisible('  Ana  ', '')).toBe('Ana');
    expect(nombreVisible('', ' Pérez ')).toBe('Pérez');
  });

  it('no inventa separadores cuando sólo hay una parte', () => {
    expect(nombreVisible('Ana', null)).toBe('Ana');
  });
});
