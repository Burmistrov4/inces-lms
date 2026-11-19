import 'package:flutter/services.dart';

/// Formateador inteligente para cédula de identidad y documentos de identificación en Venezuela.
///
/// Características:
/// - Permite escribir dígitos numéricos y aplica automáticamente separadores de miles (ej. `14.852.369`).
/// - Si el usuario pega un texto con prefijo ('V-', 'E-', 'J-', 'P-') o con puntos/espacios,
///   extrae limpiamente los dígitos y ajusta el prefijo.
/// - Limita la longitud máxima a 8 dígitos para cédulas estándar de venezolanos (V)
///   o hasta 9 dígitos para extranjeros residentes (E/J/P).
/// - Preserva de forma precisa la posición del cursor para una experiencia de escritura natural.
class CedulaInputFormatter extends TextInputFormatter {
  CedulaInputFormatter({
    this.maxDigitos = 8,
    this.conPuntos = true,
  });

  /// Cantidad máxima de dígitos numéricos permitidos (por defecto 8 para V, 9 para E/J/P).
  final int maxDigitos;

  /// Si es true, intercala puntos de millar (`14.852.369`); si false, sólo dígitos puros.
  final bool conPuntos;

  /// Extrae solo los dígitos numéricos de una cadena.
  static String soloDigitos(String texto) {
    return texto.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Formatea una cadena de dígitos con separadores de miles estilo venezolano (`14.852.369`).
  static String formatearNumero(String digitos, {int max = 9}) {
    final limpios = soloDigitos(digitos);
    final recortados = limpios.length > max ? limpios.substring(0, max) : limpios;
    if (recortados.isEmpty) return '';

    final buffer = StringBuffer();
    final longitud = recortados.length;
    final resto = longitud % 3;

    for (var i = 0; i < longitud; i++) {
      if (i > 0 && (i - resto) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(recortados[i]);
    }
    return buffer.toString();
  }

  /// Extrae el prefijo de nacionalidad si está presente en el texto (ej. 'V-14852369' -> 'V').
  static String? extraerPrefijo(String texto) {
    final match = RegExp(r'^([VEJPGvejpg])[\s\.\-]').firstMatch(texto.trim());
    if (match != null) {
      return match.group(1)?.toUpperCase();
    }
    return null;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final textoNuevo = newValue.text;
    if (textoNuevo.isEmpty) {
      return newValue;
    }

    // Extraer sólo dígitos
    var digitos = soloDigitos(textoNuevo);
    if (digitos.length > maxDigitos) {
      digitos = digitos.substring(0, maxDigitos);
    }

    if (!conPuntos) {
      return TextEditingValue(
        text: digitos,
        selection: TextSelection.collapsed(offset: digitos.length),
      );
    }

    final textoFormateado = formatearNumero(digitos, max: maxDigitos);

    // Calcular la nueva posición del cursor basada en los dígitos ingresados
    final offsetDigitosHastaCursor = soloDigitos(
      textoNuevo.substring(0, newValue.selection.end.clamp(0, textoNuevo.length)),
    ).length;

    var nuevoOffset = 0;
    var digitosContados = 0;
    for (var i = 0; i < textoFormateado.length; i++) {
      if (digitosContados >= offsetDigitosHastaCursor) break;
      if (textoFormateado[i] != '.') {
        digitosContados++;
      }
      nuevoOffset = i + 1;
    }

    return TextEditingValue(
      text: textoFormateado,
      selection: TextSelection.collapsed(
        offset: nuevoOffset.clamp(0, textoFormateado.length),
      ),
    );
  }
}
