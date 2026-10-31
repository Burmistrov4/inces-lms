import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/gateways/aula_gateway.dart';
import '../../core/result.dart';
import '../../services/asistencia_service.dart';
import '../../services/aula_service.dart';
import '../../widgets/comunes.dart';

/// Panel del docente «Pasar lista» (M7).
///
/// Tres pasos:
///   1. elegir la sección (la lista sale de `/mi-horario`, igual que «Mis aulas»);
///   2. proyectar el QR —rota sólo, cada `ventanaSeg`, derivado LOCALMENTE
///      (sin red: la LAN puede caerse medio minuto y la pizarra sigue válida);
///   3. ver la marca llegar por WebSocket y pintar la fila en verde, sin recargar.
///
/// El listado inicial se pide UNA vez por REST; de ahí en adelante es empuje.
/// El código del QR lo deriva este dispositivo: el servidor devolvió el secreto
/// UNA vez al abrir la sesión, y sólo la base sabe validarlo.
class AsistenciaQrPanel extends StatefulWidget {
  const AsistenciaQrPanel({super.key, this.servicio, this.aulas});

  /// Opcional, sólo para las pruebas: inyectar un servicio falso.
  final AsistenciaService? servicio;

  /// El listado de secciones del docente. Opcional para las pruebas.
  final AulasPropiasGateway? aulas;

  @override
  State<AsistenciaQrPanel> createState() => _AsistenciaQrPanelState();
}

class _AsistenciaQrPanelState extends State<AsistenciaQrPanel> {
  late final AsistenciaService _servicio = widget.servicio ?? AsistenciaService();
  late final AulasPropiasGateway _aulas = widget.aulas ?? BackendAulaGateway();

  /// Las secciones del docente (una entrada por aula).
  MisAulas? _misSecciones;
  String? _aulaSeleccionada;
  String _aulaEtiqueta = '';

  Map<String, dynamic>? _sesion;
  final List<MarcaAsistencia> _marcas = [];
  Timer? _sondeo;
  Timer? _rotador;

  String _error = '';
  bool _cargando = false;

  /// Duración del código QR de esta sesión, en segundos.
  ///
  /// Antes eran 15 fijos: el docente no llegaba a proyectarlo. Ahora 45 por
  /// defecto y ajustable antes de abrir la sesión, que es cuando el servidor fija
  /// la ventana (`ventanaSeg`).
  int _ventanaSeg = 45;

  @override
  void initState() {
    super.initState();
    _cargarSecciones();
  }

  @override
  void dispose() {
    _rotador?.cancel();
    _sondeo?.cancel();
    super.dispose();
  }

  /// Carga las secciones que el docente tiene a nombre.
  ///
  /// Se apoya en la misma ruta que «Mis aulas» (m3), así que lo que este panel
  /// ofrece para tomar asistencia es exactamente lo que la pantalla vecina
  /// abre. No se repite la lógica de «de quién es la sección»: la RLS la hace.
  Future<void> _cargarSecciones() async {
    final resultado = await Result.guard(() => _aulas.misAulas());
    if (!mounted) return;
    resultado.when(
      success: (mis) => setState(() => _misSecciones = mis),
      failure: (e) => setState(() => _error = e.message),
    );
  }

  /// Abre sesión: una por clase. El secreto viene una vez, en la respuesta.
  Future<void> _abrir() async {
    final seccionId = _aulaSeleccionada;
    if (seccionId == null) return;

    setState(() { _cargando = true; _error = ''; });

    final creada = await _servicio.abrirSesion(
      seccionId: seccionId,
      ventanaSeg: _ventanaSeg,
    );
    creada.when(
      success: (sesion) {
        setState(() { _sesion = sesion; _cargando = false; });
        _arrancar(sesion);
      },
      failure: (e) => setState(() { _cargando = false; _error = e.message; }),
    );
  }

  /// El «servidor lógico» de la pantalla: un rotador para el QR y el canal WS.
  void _arrancar(Map<String, dynamic> sesion) {

    // Un tick por segundo: el QR rota sólo. La app no pregunta a la base ni al
    // servidor entre un tick y el siguiente.
    _rotador = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    // Un intento de canal: sin bucle de reconexión, porque la clase se acaba y
    // el panel cierra; un retry aquí sería ruido sin diagnóstico.
    //
    // `onError` **y** `onDone`, que no son lo mismo: `WebSocketChannel` emite
    // `error` cuando la conexión falla, pero emite `done` —sin error— cuando el
    // otro extremo la cierra limpiamente: el servidor reiniciándose, la sesión
    // terminando de su lado. Con sólo `onError`, ese cierre dejaba el tablero
    // congelado **sin decir nada**, que es exactamente lo que este mensaje
    // existe para evitar. Ver D22.
    // **Sondeo, no WebSocket.** Una función serverless no puede mantener el
    // canal abierto: el intento fallaba siempre y la pantalla mostraba «la
    // conexión en vivo se cayó» en cada clase, aunque las marcas se estuvieran
    // guardando. Preguntar cada 4 s da la misma sensación de vivo y no miente.
    _sondeo = Timer.periodic(const Duration(seconds: 4), (_) => _refrescarMarcas());

    _refrescarMarcas();
  }

  /// Trae las marcas y las fusiona sin duplicar.
  Future<void> _refrescarMarcas() async {
    final sesion = _sesion;
    if (sesion == null || !mounted) return;

    final resultado = await _servicio.marcas(sesionId: sesion['id'] as String);
    if (!mounted) return;

    resultado.when(
      success: (lista) {
        final conocidas = _marcas.map((m) => m.studentId).toSet();
        final nuevas = lista.where((m) => !conocidas.contains(m.studentId));
        if (nuevas.isNotEmpty) {
          setState(() => _marcas.addAll(nuevas));
        }
      },
      failure: (_) {
        // Un sondeo que falla no es una avería que anunciar: el siguiente
        // intento llega en cuatro segundos.
      },
    );
  }


  Future<void> _cerrar() async {
    final sesion = _sesion;
    if (sesion == null) return;
    final id = sesion['id'] as String;

    final resultado = await _servicio.cerrarSesion(sesionId: id);
    await resultado.when(
      success: (_) async {
        setState(() => _sesion = {...sesion, 'status': 'CLOSED'});
        _sondeo?.cancel();
        _rotador?.cancel();
        _rotador = null;
      },
      failure: (e) async => setState(() => _error = e.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_sesion == null) return _selector();

    final ventana = _sesion!['ventana_seg'] as int? ?? 15;
    final secreto = _sesion!['qr_secret'] as String;
    final sesionId = _sesion!['id'] as String;
    final cerrada = _sesion!['status'] == 'CLOSED';

    final qr = AsistenciaService.codigoQr(
      qrSecret: secreto,
      sesionId: sesionId,
      ventanaSeg: ventana,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '{} · Pasar lista'.replaceFirst('{}', _aulaEtiqueta.isEmpty ? 'Sección' : _aulaEtiqueta),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      cerrada ? 'Sesión cerrada —las marcas se conservan.' : 'Sesión abierta',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: cerrada ? null : _cerrar,
                icon: const Icon(Icons.stop_circle),
                label: const Text('Cerrar'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, limites) {
                final qrWidget = Semantics(
                  label: 'Código QR de asistencia. Caduca en ${qr.venceEnSegundos} segundos.',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      QrImageView(
                        data: '$sesionId:${qr.codigo}',
                        version: QrVersions.auto,
                        size: 260,
                      ),
                      const SizedBox(height: 12),
                      // El contador NO es un adorno: es la única señal de que el
                      // QR que se proyecta sigue vigente. Si llega a 0 y no rota,
                      // la pantalla se congeló, y eso hay que verlo.
                      Text('Rota en ${qr.venceEnSegundos} s',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                );

                final lista = _listado();

                final enFila = limites.maxWidth >= 740;
                if (enFila) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!cerrada) Expanded(child: Center(child: qrWidget)),
                      if (!cerrada) const SizedBox(width: 24),
                      Expanded(child: lista),
                    ],
                  );
                }
                return Column(
                  children: [
                    if (!cerrada) qrWidget,
                    const SizedBox(height: 16),
                    Expanded(child: lista),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Pedazos --------------------------------------------------------------

  Widget _selector() {
    if (_error.isNotEmpty && _misSecciones == null) {
      return _Centro(icono: Icons.wifi_off, mensaje: _error, onReintentar: _cargarSecciones);
    }
    final mis = _misSecciones;
    if (mis == null) return const Center(child: CircularProgressIndicator());
    if (mis.vacio) {
      return const _Centro(
        icono: Icons.info_outline,
        mensaje: 'No tienes secciones asignadas en este período. La guardia del RLS es la misma: no puedes abrir asistencia en la sección de otro.',
        onReintentar: null,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Pasar lista', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Elige la sección. El QR lo proyectas en tu pantalla y caduca cada pocos segundos.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        // **Cuánto dura cada código.** El docente lo elige antes de abrir la
        // sesión porque la ventana la fija el servidor al crearla. 45 s por
        // defecto: con 15 no daba tiempo a proyectarlo.
        Row(
          children: [
            Icon(
              Icons.timer_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'Cada código dura',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: _ventanaSeg,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 30, child: Text('30 s')),
                DropdownMenuItem(value: 45, child: Text('45 s')),
                DropdownMenuItem(value: 60, child: Text('60 s')),
                DropdownMenuItem(value: 90, child: Text('90 s')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _ventanaSeg = v);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          for (final aula in mis.aulas)
            Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: Text(aula.etiqueta),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                setState(() {
                  _aulaSeleccionada = aula.seccionId;
                  _aulaEtiqueta = aula.etiqueta;
                });
                _abrir();
              },
            ),
          ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_error, style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }

  Widget _listado() {
    if (_marcas.isEmpty) {
      // El vacío enseña qué hacer en vez de quedarse en «no hay nada»: el
      // docente que acaba de abrir la sesión no sabe aún que este tablero se
      // llena solo, sin recargar, cuando los estudiantes marcan.
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: AvisoEnLinea(
            texto: 'Cuando pases lista, aquí verás quién marcó: cada '
                'estudiante aparecerá en cuanto escanee el QR o teclee el '
                'código de 6 dígitos.',
            tono: TonoAviso.info,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: _marcas.length,
      itemBuilder: (context, i) {
        final m = _marcas[i];
        return ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Text(m.studentId, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(m.marcadaEn),
        );
      },
    );
  }
}

/// Un hueco con icono, usado por los dos fallos (sin secciones, sin conexión).
class _Centro extends StatelessWidget {
  const _Centro({required this.icono, required this.mensaje, required this.onReintentar});

  final IconData icono;
  final String mensaje;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            if (onReintentar != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onReintentar, child: const Text('Reintentar')),
            ],
          ],
        ),
      ),
    );
  }
}
