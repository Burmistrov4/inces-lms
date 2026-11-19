import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/inscripcion_campo.dart';
import '../../theme/inces_theme.dart';
import 'cedula_input_formatter.dart';
import 'estilos_campo.dart';

/// Campo interactivo especializado para la Cédula de Identidad venezolana y documentos de identidad.
///
/// Características clave de diseño:
/// 1. **Selector de prefijo integrado (V / E / J / P):** Permite elegir la nacionalidad
///    o tipo de documento directamente al lado del número, con sincronización automática.
/// 2. **Formateo en tiempo real:** Formatea los dígitos con puntos de millar (`14.852.369`)
///    sin trabar el cursor ni exigir al usuario teclear puntos manualmente.
/// 3. **Tolerancia a pegado:** Si el estudiante copia `V-14852369` o `14.852.369` de WhatsApp o correo,
///    se detecta el prefijo y los dígitos se limpian al instante.
/// 4. **Validación semántica:** Valida longitud real venezolana (6 a 8 dígitos para V; hasta 9 para E/J/P).
/// 5. **Retroalimentación amigable:** Mensajes claros y comprensibles para cualquier aspirante.
class CampoCedula extends StatefulWidget {
  const CampoCedula({
    super.key,
    required this.campo,
    required this.valor,
    required this.onCambio,
    required this.etiqueta,
    this.prefijoInicial = 'V',
    this.onPrefijoCambio,
    this.error,
  });

  final CampoInscripcion campo;
  final Object? valor;
  final ValueChanged<Object?> onCambio;
  final String etiqueta;
  final String prefijoInicial;
  final ValueChanged<String>? onPrefijoCambio;
  final String? error;

  @override
  State<CampoCedula> createState() => _CampoCedulaState();
}

class _CampoCedulaState extends State<CampoCedula> {
  late final TextEditingController _controller;
  late String _prefijoSeleccionado;

  static const List<String> _prefijosDisponibles = ['V', 'E', 'J', 'P'];

  @override
  void initState() {
    super.initState();
    _prefijoSeleccionado = widget.prefijoInicial;
    _descomponerValorInicial(widget.valor?.toString() ?? '');
  }

  void _descomponerValorInicial(String crudo) {
    var texto = crudo.trim();
    if (texto.isEmpty) {
      _controller = TextEditingController();
      return;
    }

    final pref = CedulaInputFormatter.extraerPrefijo(texto);
    if (pref != null && _prefijosDisponibles.contains(pref)) {
      _prefijoSeleccionado = pref;
      texto = texto.substring(1).replaceAll(RegExp(r'^[\s\.\-]+'), '');
    }

    final digitos = CedulaInputFormatter.soloDigitos(texto);
    final formateado = CedulaInputFormatter.formatearNumero(
      digitos,
      max: _prefijoSeleccionado == 'V' ? 8 : 9,
    );
    _controller = TextEditingController(text: formateado);
  }

  @override
  void didUpdateWidget(covariant CampoCedula oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.prefijoInicial != oldWidget.prefijoInicial &&
        widget.prefijoInicial != _prefijoSeleccionado &&
        _prefijosDisponibles.contains(widget.prefijoInicial)) {
      setState(() {
        _prefijoSeleccionado = widget.prefijoInicial;
      });
    }

    if (widget.valor != oldWidget.valor) {
      final nuevoCrudo = widget.valor?.toString() ?? '';
      final digitosNuevos = CedulaInputFormatter.soloDigitos(nuevoCrudo);
      final digitosActuales = CedulaInputFormatter.soloDigitos(_controller.text);

      if (digitosNuevos != digitosActuales) {
        final formateado = CedulaInputFormatter.formatearNumero(
          digitosNuevos,
          max: _prefijoSeleccionado == 'V' ? 8 : 9,
        );
        _controller.value = TextEditingValue(
          text: formateado,
          selection: TextSelection.collapsed(offset: formateado.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _notificarCambio() {
    final digitos = CedulaInputFormatter.soloDigitos(_controller.text);
    if (digitos.isEmpty) {
      widget.onCambio(null);
      return;
    }
    // Formato canónico estándar: prefijo + dígitos limpios (ej. V-14852369)
    widget.onCambio('$_prefijoSeleccionado-$digitos');
  }

  String? _validarFormato(String? texto) {
    final digitos = CedulaInputFormatter.soloDigitos(texto ?? '');
    if (widget.campo.obligatorio && digitos.isEmpty) {
      return 'La cédula es obligatoria';
    }
    if (digitos.isEmpty) return null;

    if (_prefijoSeleccionado == 'V') {
      if (digitos.length < 6) {
        return 'Cédula incompleta (mínimo 6 dígitos)';
      }
      if (digitos.length > 8) {
        return 'Cédula venezolana no debe exceder 8 dígitos';
      }
    } else {
      if (digitos.length < 6 || digitos.length > 9) {
        return 'El documento debe tener entre 6 y 9 dígitos';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final paleta = PaletaInces.de(context);
    final maxDigitos = _prefijoSeleccionado == 'V' ? 8 : 9;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d\.\s\-]')),
            CedulaInputFormatter(maxDigitos: maxDigitos, conPuntos: true),
          ],
          decoration: InputDecoration(
            labelText: widget.etiqueta,
            labelStyle: GoogleFonts.inter(
              fontSize: 14,
              color: paleta.textoSecundario,
            ),
            helperText: 'Ej. 14.852.369 (solo números)',
            helperStyle: GoogleFonts.inter(
              fontSize: 11,
              color: paleta.textoApagado,
            ),
            errorText: widget.error,
            filled: true,
            fillColor: paleta.rellenoDeCampo,
            prefixIcon: Container(
              margin: const EdgeInsets.only(left: 8, right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    iconoDeCampo(widget.campo.codigo),
                    color: paleta.textoSecundario,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: paleta.bordeDeCampo.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: paleta.bordeDeCampo),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _prefijoSeleccionado,
                        isDense: true,
                        borderRadius: BorderRadius.circular(8),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: paleta.textoPrincipal,
                        ),
                        items: _prefijosDisponibles.map((pref) {
                          return DropdownMenuItem<String>(
                            value: pref,
                            child: Text(
                              '$pref-',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: paleta.textoPrincipal,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (nuevoPref) {
                          if (nuevoPref == null || nuevoPref == _prefijoSeleccionado) return;
                          setState(() {
                            _prefijoSeleccionado = nuevoPref;
                          });
                          widget.onPrefijoCambio?.call(nuevoPref);
                          _notificarCambio();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    tooltip: 'Limpiar',
                    onPressed: () {
                      setState(() {
                        _controller.clear();
                      });
                      _notificarCambio();
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: paleta.bordeDeCampo),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: paleta.bordeDeCampo),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: IncesTheme.azulPrimario, width: 1.6),
            ),
          ),
          validator: _validarFormato,
          onChanged: (texto) {
            final pref = CedulaInputFormatter.extraerPrefijo(texto);
            if (pref != null && pref != _prefijoSeleccionado && _prefijosDisponibles.contains(pref)) {
              setState(() {
                _prefijoSeleccionado = pref;
              });
              widget.onPrefijoCambio?.call(pref);
            }
            setState(() {});
            _notificarCambio();
          },
        ),
      ],
    );
  }
}
