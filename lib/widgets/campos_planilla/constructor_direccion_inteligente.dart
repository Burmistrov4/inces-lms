import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/inscripcion_campo.dart';
import '../../theme/inces_theme.dart';
import 'estilos_campo.dart';

/// El campo de **dirección de habitación** del formulario de inscripción.
///
/// **Qué resuelve.** En Venezuela una dirección rara vez cabe en una línea: la
/// gente escribe «Urb. La Isabelica, vereda 12, casa 4, frente al CDI», y la
/// Planilla Oficial del INCES tiene un solo renglón. Este widget compone ese
/// renglón a partir de dos datos que el aspirante reconoce sin pensar:
///
/// 1. la **dirección** (calle, avenida, vereda, número de casa), y
/// 2. el **punto de referencia** («frente al CDI», «al lado de la bodega»), que
///    es lo que de verdad sirve para llegar.
///
/// Se guarda como `dirección (Ref: referencia)`. **El formato no es decorativo**:
/// es lo que ya viaja en `datos_planilla` y lo que imprime el PDF oficial, así
/// que cambiarlo sería una migración de datos, no un retoque de pantalla.
///
/// **Por qué dos campos visibles y no un asistente escondido (2026-11-19).** La
/// versión anterior metía el punto de referencia dentro de un desplegable
/// «Asistente de dirección», junto a un selector de tipo de ubicación (urbana,
/// barrio, rural, industrial) que en realidad **no se guardaba**: solo filtraba
/// los chips de prefijos. El resultado era un formulario que pedía pulsar para
/// descubrir el dato más útil —y en la práctica nadie lo llenaba—, más un
/// contador de caracteres, una vista previa que repetía lo ya escrito y dos
/// caminos para lo mismo. Ahora:
///
/// - los dos campos están **a la vista**, con el ejemplo dentro del campo;
/// - los prefijos frecuentes (`Urb.`, `Av.`, `Calle`, `Sector`, `Vereda`…) siguen
///   ahí, en una tira compacta que inserta en el cursor —sin preguntar antes qué
///   tipo de zona es, porque el aspirante ya lo está escribiendo;
/// - las comunidades de la parroquia se **añaden** al texto en vez de
///   reemplazarlo (antes, un toque borraba lo que ya se había tecleado).
///
/// Nada de esto cambia el contrato con `campo_planilla.dart`: mismo nombre, misma
/// firma, mismo valor compuesto.
class ConstructorDireccionInteligente extends StatefulWidget {
  const ConstructorDireccionInteligente({
    super.key,
    required this.campo,
    required this.valor,
    required this.onCambio,
    required this.etiqueta,
    this.sugerenciasGeograficas,
    this.error,
  });

  final CampoInscripcion campo;
  final Object? valor;
  final ValueChanged<Object?> onCambio;
  final String etiqueta;
  final List<OpcionCampo>? sugerenciasGeograficas;
  final String? error;

  @override
  State<ConstructorDireccionInteligente> createState() =>
      _ConstructorDireccionInteligenteState();
}

class _ConstructorDireccionInteligenteState
    extends State<ConstructorDireccionInteligente> {
  /// Los controladores se crean **una vez** y después solo se les cambia el
  /// texto. En la versión anterior `didUpdateWidget` volvía a asignarlos y, como
  /// eran `late final`, eso reventaba con `LateInitializationError` en cuanto el
  /// padre reenviaba un valor (al volver a un paso, por ejemplo).
  final _direccionController = TextEditingController();
  final _referenciaController = TextEditingController();

  /// Prefijos que la gente usa de verdad al escribir su casa. El orden importa:
  /// los primeros cubren la mayoría de las direcciones urbanas del país.
  static const List<String> _prefijosRapidos = [
    'Urb. ',
    'Av. ',
    'Calle ',
    'Sector ',
    'Vereda ',
    'Manzana ',
    'Casa N° ',
    'Km ',
    'Zona Industrial ',
    'Galpón ',
  ];

  /// El valor compuesto. Admite `(Ref: …)` y la forma vieja `(Punto de ref: …)`,
  /// que ya hay guardada en la base.
  static final RegExp _patronReferencia = RegExp(
    r'^(.*?)\s*\((?:Punto de ref:|Ref:)\s*(.*?)\)$',
    caseSensitive: false,
    dotAll: true,
  );

  @override
  void initState() {
    super.initState();
    _cargarDesde(widget.valor?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant ConstructorDireccionInteligente oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.valor == oldWidget.valor) return;

    final nuevo = widget.valor?.toString() ?? '';
    // Solo se reescribe si el padre manda algo **distinto** de lo que ya está
    // compuesto aquí: si no, cada reconstrucción movería el cursor al final
    // mientras el aspirante escribe.
    if (nuevo == _componer()) return;
    _cargarDesde(nuevo);
  }

  @override
  void dispose() {
    _direccionController.dispose();
    _referenciaController.dispose();
    super.dispose();
  }

  /// Separa `dirección (Ref: referencia)` en los dos campos.
  void _cargarDesde(String crudo) {
    final texto = crudo.trim();
    final coincide = _patronReferencia.firstMatch(texto);

    if (coincide != null) {
      _direccionController.text = (coincide.group(1) ?? '').trim();
      _referenciaController.text = (coincide.group(2) ?? '').trim();
    } else {
      _direccionController.text = texto;
      _referenciaController.text = '';
    }
  }

  /// El valor que se guarda. Sin dirección no hay nada que guardar, aunque haya
  /// referencia escrita: media dirección no le sirve a nadie.
  String _componer() {
    final direccion = _direccionController.text.trim();
    final referencia = _referenciaController.text.trim();

    if (direccion.isEmpty) return '';
    if (referencia.isEmpty) return direccion;
    return '$direccion (Ref: $referencia)';
  }

  void _notificarCambio() {
    final compuesta = _componer();
    widget.onCambio(compuesta.isEmpty ? null : compuesta);
  }

  /// Inserta un prefijo **en el cursor**, no al final: quien ya escribió «Calle 5»
  /// y quiere poner «Urb. » delante no tiene que reescribir nada.
  ///
  /// Si el prefijo se pegaría a la palabra anterior («Calle 5» + «Urb. » →
  /// «Calle 5Urb. »), se mete una coma y un espacio en medio. Es lo que el
  /// aspirante escribiría a mano, y evita dos palabras soldadas que después
  /// nadie puede separar en la planilla.
  void _insertar(String texto) {
    final actual = _direccionController.text;
    final seleccion = _direccionController.selection;
    final inicio = seleccion.isValid ? seleccion.start : actual.length;
    final fin = seleccion.isValid ? seleccion.end : actual.length;

    final pegadoAntes =
        inicio > 0 && !actual[inicio - 1].trim().isEmpty && !texto.startsWith(' ');
    final conSeparador = pegadoAntes ? ', $texto' : texto;

    final nuevo = actual.replaceRange(inicio, fin, conSeparador);
    _direccionController.value = TextEditingValue(
      text: nuevo,
      selection: TextSelection.collapsed(
        offset: inicio + conSeparador.length,
      ),
    );
    setState(() {});
    _notificarCambio();
  }

  /// Un toque sobre una comunidad de la parroquia **añade** al final de la
  /// dirección; nunca la sustituye.
  void _agregarComunidad(String comunidad) {
    final actual = _direccionController.text.trim();
    final separador = actual.isEmpty ? '' : ', ';
    final nuevo = '$actual$separador$comunidad';

    _direccionController.value = TextEditingValue(
      text: nuevo,
      selection: TextSelection.collapsed(offset: nuevo.length),
    );
    setState(() {});
    _notificarCambio();
  }

  Widget _chip(String texto, {IconData? icono, VoidCallback? onTap}) {
    final paleta = PaletaInces.de(context);
    return InkWell(
      onTap: onTap ?? () => _insertar(texto),
      borderRadius: BorderRadius.circular(IncesTheme.radioControl),
      child: Container(
        // Alto mínimo para que se pueda tocar con el pulgar sin fallar.
        constraints: const BoxConstraints(minHeight: 34),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: paleta.superficie,
          borderRadius: BorderRadius.circular(IncesTheme.radioControl),
          border: Border.all(color: paleta.bordeDeCampo),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              Icon(icono, size: 13, color: IncesTheme.azulPrimario),
              const SizedBox(width: 4),
            ],
            Text(
              texto,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: paleta.textoPrincipal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paleta = PaletaInces.de(context);
    final sugerencias = widget.sugerenciasGeograficas ?? const <OpcionCampo>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. La dirección. Es el **primer** `TextFormField` del árbol a
        //    propósito: es la entrada principal de este campo compuesto.
        TextFormField(
          controller: _direccionController,
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.streetAddress,
          decoration: decoracionDeCampo(
            etiqueta: widget.etiqueta,
            paleta: paleta,
            icono: Icons.home_rounded,
            ayuda: 'Calle, avenida, vereda, edificio y número de casa.',
            sufijo: _direccionController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    tooltip: 'Limpiar dirección',
                    onPressed: () {
                      setState(_direccionController.clear);
                      _notificarCambio();
                    },
                  ),
            error: widget.error,
          ),
          validator: (texto) {
            final limpio = (texto ?? '').trim();
            if (widget.campo.obligatorio && limpio.isEmpty) {
              return 'La dirección de habitación es obligatoria';
            }
            if (limpio.isNotEmpty && limpio.length < 5) {
              return 'Escribe una dirección más completa';
            }
            return null;
          },
          onChanged: (_) {
            setState(() {});
            _notificarCambio();
          },
        ),

        const SizedBox(height: 8),

        // 2. Prefijos frecuentes en una sola línea desplazable. No se pregunta
        //    «¿urbana o rural?»: los diez prefijos caben y cada uno ahorra teclas.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final prefijo in _prefijosRapidos) ...[
                _chip(prefijo),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),

        // 3. Comunidades de la parroquia elegida: se añaden al final.
        if (sugerencias.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Comunidades de tu parroquia',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: paleta.textoSecundario,
            ),
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final opcion in sugerencias) ...[
                  _chip(
                    opcion.etiqueta,
                    icono: Icons.location_city_rounded,
                    onTap: () => _agregarComunidad(opcion.etiqueta),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 10),

        // 4. El punto de referencia: siempre visible y opcional. Es el dato que
        //    hace una dirección encontrable en Venezuela; escondido no se llena.
        TextFormField(
          controller: _referenciaController,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Punto de referencia (opcional)',
            helperText: 'Ej. frente al CDI, al lado de la bodega, '
                'detrás de la escuela.',
            helperMaxLines: 2,
            labelStyle: GoogleFonts.inter(
              fontSize: 13,
              color: paleta.textoSecundario,
            ),
            prefixIcon: const Icon(Icons.pin_drop_outlined, size: 18),
            filled: true,
            fillColor: paleta.rellenoDeCampo,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(IncesTheme.radioControl),
              borderSide: BorderSide(color: paleta.bordeDeCampo),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(IncesTheme.radioControl),
              borderSide: BorderSide(color: paleta.bordeDeCampo),
            ),
          ),
          onChanged: (_) {
            setState(() {});
            _notificarCambio();
          },
        ),
      ],
    );
  }
}
