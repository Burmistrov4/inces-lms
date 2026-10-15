import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/selector_archivos_navegador.dart';
import '../../theme/inces_theme.dart';


/// Tipo de elemento en el explorador de archivos.
enum TipoElemento {
  carpeta,
  documento,
  hojaCalculo,
  presentacion,
  imagen,
  enlaceDrive,
}

/// Registro de actividad histórica sobre un archivo o carpeta.
class EventoActividad {
  const EventoActividad({
    required this.accion,
    required this.tiempo,
    required this.usuario,
    required this.icono,
  });

  final String accion;
  final String tiempo;
  final String usuario;
  final IconData icono;
}

/// Representa un archivo o carpeta dentro del almacenamiento Cloudflare R2 / Google Drive.
class ElementoArchivo {
  ElementoArchivo({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.tamanoBytes,
    required this.fechaModificacion,
    required this.propietario,
    required this.ruta,
    this.colorCarpeta,
    this.esDrive = false,
    this.urlDrive,
    this.permiso = 'Docentes y Estudiantes',
    this.actividad = const [],
    this.aulaVirtual = 'General CFS (Todos)',
    this.materia = 'Formación Técnica General',
  });

  final String id;
  String nombre;
  final TipoElemento tipo;
  final int tamanoBytes;
  DateTime fechaModificacion;
  final String propietario;
  String ruta;
  Color? colorCarpeta;
  final bool esDrive;
  String? urlDrive;
  String permiso;
  List<EventoActividad> actividad;
  String aulaVirtual;
  String materia;

  bool get esCarpeta => tipo == TipoElemento.carpeta;

  String get tamanoFormateado {
    if (esCarpeta) return '--';
    if (esDrive) return 'Google Drive';
    if (tamanoBytes < 1024) return '$tamanoBytes B';
    if (tamanoBytes < 1024 * 1024) {
      return '${(tamanoBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(tamanoBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'tipo': tipo.name,
        'tamanoBytes': tamanoBytes,
        'fechaModificacion': fechaModificacion.toIso8601String(),
        'propietario': propietario,
        'ruta': ruta,
        'colorIndice': _colorAIndice(colorCarpeta),
        'esDrive': esDrive,
        'urlDrive': urlDrive,
        'permiso': permiso,
        'aulaVirtual': aulaVirtual,
        'materia': materia,
      };

  factory ElementoArchivo.fromMap(Map<String, dynamic> map) {
    final colIndice = (map['colorIndice'] as num?)?.toInt();
    final col = (colIndice != null &&
            colIndice >= 0 &&
            colIndice < _paletaColores.length)
        ? _paletaColores[colIndice]
        : null;
    return ElementoArchivo(
      id: map['id'] as String? ??
          'id_${DateTime.now().millisecondsSinceEpoch}',
      nombre: map['nombre'] as String? ?? 'Archivo',
      tipo: TipoElemento.values.firstWhere(
        (t) => t.name == map['tipo'],
        orElse: () => TipoElemento.documento,
      ),
      tamanoBytes: (map['tamanoBytes'] as num?)?.toInt() ?? 0,
      fechaModificacion:
          DateTime.tryParse(map['fechaModificacion'] as String? ?? '') ??
              DateTime.now(),
      propietario: map['propietario'] as String? ?? 'Administrador',
      ruta: map['ruta'] as String? ?? 'Mi Unidad (R2)',
      colorCarpeta: col,
      esDrive: map['esDrive'] as bool? ?? false,
      urlDrive: map['urlDrive'] as String?,
      permiso: map['permiso'] as String? ?? 'Docentes y Estudiantes',
      aulaVirtual: map['aulaVirtual'] as String? ?? 'General CFS (Todos)',
      materia: map['materia'] as String? ?? 'Formación Técnica General',
    );
  }
}

const List<Color> _paletaColores = [
  IncesTheme.azulPrimario,
  IncesTheme.advertencia,
  IncesTheme.exito,
  IncesTheme.rojoInces,
  IncesTheme.carpetaVioleta,
  IncesTheme.carpetaTeal,
  IncesTheme.carpetaNaranja,
  IncesTheme.carpetaPizarra,
];

int? _colorAIndice(Color? c) {
  if (c == null) return null;
  final idx = _paletaColores.indexOf(c);
  return idx >= 0 ? idx : null;
}

/// Explorador de Archivos estilo Google Drive para Cloudflare R2.
class CpanelExploradorArchivosPanel extends StatefulWidget {
  const CpanelExploradorArchivosPanel({super.key});

  @override
  State<CpanelExploradorArchivosPanel> createState() =>
      _CpanelExploradorArchivosPanelState();
}

class _CpanelExploradorArchivosPanelState
    extends State<CpanelExploradorArchivosPanel> {
  bool _vistaCuadricula = true;
  bool _mostrarPanelLateral = true;
  int _tabLateral = 0; // 0: Detalles, 1: Actividad
  String _filtroBusqueda = '';
  final _busquedaController = TextEditingController();

  /// Pila de navegación para las migas de pan (Breadcrumbs).
  final List<String> _rutaActual = ['Mi Unidad (R2)'];

  ElementoArchivo? _seleccionado;

  /// Cuota utilizada de Cloudflare R2: 1.84 GB de 10.0 GB (18.4%)
  static const double _cuotaUsadaGb = 1.84;
  static const double _cuotaTotalGb = 10.0;

  static const String _prefArchivosKey = 'inces_gestor_archivos_elementos_v2';

  /// Catálogo de archivos y carpetas del centro.
  late List<ElementoArchivo> _elementos;

  @override
  void initState() {
    super.initState();
    _inicializarDatos();
    _cargarArchivosPersistidos();
    _busquedaController.addListener(() {
      setState(() {
        _filtroBusqueda = _busquedaController.text.trim().toLowerCase();
      });
    });
  }

  Future<void> _cargarArchivosPersistidos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getString(_prefArchivosKey);
      if (guardado != null && guardado.isNotEmpty) {
        final List<dynamic> decodificado =
            jsonDecode(guardado) as List<dynamic>;
        final listaCargada = decodificado
            .map((item) =>
                ElementoArchivo.fromMap(item as Map<String, dynamic>))
            .toList();
        if (listaCargada.isNotEmpty && mounted) {
          setState(() {
            final idsExistentes = <String>{};
            final combinados = <ElementoArchivo>[];
            for (final el in listaCargada) {
              if (idsExistentes.add(el.id)) {
                combinados.add(el);
              }
            }
            for (final el in _elementos) {
              if (idsExistentes.add(el.id)) {
                combinados.add(el);
              }
            }
            _elementos = combinados;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _guardarArchivosPersistidos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final codificado =
          jsonEncode(_elementos.map((e) => e.toMap()).toList());
      await prefs.setString(_prefArchivosKey, codificado);
    } catch (_) {}
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _inicializarDatos() {
    _elementos = [
      ElementoArchivo(
        id: 'c1',
        nombre: 'Metalmecánica y Soldadura',
        tipo: TipoElemento.carpeta,
        tamanoBytes: 0,
        colorCarpeta: IncesTheme.azulPrimario,
        fechaModificacion: DateTime.now().subtract(const Duration(days: 2)),
        propietario: 'Ing. Carlos Mendoza (Docente)',
        ruta: 'Mi Unidad (R2)',
        permiso: 'Docentes y Estudiantes',
        actividad: const [
          EventoActividad(
            accion: 'Carpeta creada y permisos asignados',
            tiempo: 'Hace 2 días',
            usuario: 'Administrador Maestro',
            icono: Icons.create_new_folder_outlined,
          ),
          EventoActividad(
            accion: 'Se agregaron 4 guías prácticas de soldadura TIG/MIG',
            tiempo: 'Ayer, 03:20 PM',
            usuario: 'Ing. Carlos Mendoza',
            icono: Icons.upload_file_outlined,
          ),
        ],
      ),
      ElementoArchivo(
        id: 'c2',
        nombre: 'Alimentación y Gastronomía',
        tipo: TipoElemento.carpeta,
        tamanoBytes: 0,
        colorCarpeta: IncesTheme.advertencia,
        fechaModificacion: DateTime.now().subtract(const Duration(days: 4)),
        propietario: 'Lic. Elena Ramos (Docente)',
        ruta: 'Mi Unidad (R2)',
        permiso: 'Docentes y Estudiantes',
        actividad: const [
          EventoActividad(
            accion: 'Manual de Manipulación de Alimentos subido',
            tiempo: 'Hace 4 días',
            usuario: 'Lic. Elena Ramos',
            icono: Icons.upload_file_outlined,
          ),
        ],
      ),
      ElementoArchivo(
        id: 'c3',
        nombre: 'Administración y Gestión',
        tipo: TipoElemento.carpeta,
        tamanoBytes: 0,
        colorCarpeta: IncesTheme.carpetaTeal,
        fechaModificacion: DateTime.now().subtract(const Duration(days: 1)),
        propietario: 'Coordinación Académica',
        ruta: 'Mi Unidad (R2)',
        permiso: 'Solo Coordinación',
        actividad: const [
          EventoActividad(
            accion: 'Planillas de control de aforo sincronizadas',
            tiempo: 'Hoy, 09:15 AM',
            usuario: 'Coordinación Académica',
            icono: Icons.sync_rounded,
          ),
        ],
      ),
      ElementoArchivo(
        id: 'c4',
        nombre: 'Guías de Estudio y Normativas 2026',
        tipo: TipoElemento.carpeta,
        tamanoBytes: 0,
        colorCarpeta: IncesTheme.carpetaVioleta,
        fechaModificacion: DateTime.now().subtract(const Duration(days: 6)),
        propietario: 'Dirección del Centro',
        ruta: 'Mi Unidad (R2)',
        permiso: 'Público',
        actividad: const [
          EventoActividad(
            accion: 'Carpeta compartida con toda la comunidad',
            tiempo: 'Hace 6 días',
            usuario: 'Dirección del Centro',
            icono: Icons.share_outlined,
          ),
        ],
      ),
      // Archivos en raíz
      ElementoArchivo(
        id: 'f1',
        nombre: 'Reglamento_Interno_CFS_Rafael_Urdaneta_2026.pdf',
        tipo: TipoElemento.documento,
        tamanoBytes: 2450000, // 2.3 MB
        fechaModificacion: DateTime.now().subtract(const Duration(days: 3)),
        propietario: 'Coordinación Legal',
        ruta: 'Mi Unidad (R2)',
        permiso: 'Público',
        actividad: const [
          EventoActividad(
            accion: 'Documento oficial cargado a Cloudflare R2',
            tiempo: 'Hace 3 días',
            usuario: 'Coordinación Legal',
            icono: Icons.file_upload_outlined,
          ),
        ],
      ),
      ElementoArchivo(
        id: 'f2',
        nombre: 'Calendario_Academico_SA26_2.xlsx',
        tipo: TipoElemento.hojaCalculo,
        tamanoBytes: 520000, // 520 KB
        fechaModificacion: DateTime.now().subtract(const Duration(hours: 5)),
        propietario: 'Coordinador de Cuadrante',
        ruta: 'Mi Unidad (R2)',
        permiso: 'Docentes y Estudiantes',
        actividad: const [
          EventoActividad(
            accion: 'Actualización de horarios y turnos vespertinos',
            tiempo: 'Hoy, 01:40 PM',
            usuario: 'Coordinador de Cuadrante',
            icono: Icons.edit_note_rounded,
          ),
        ],
      ),
      ElementoArchivo(
        id: 'f3',
        nombre: 'Presentacion_Induccion_Aprendices_PNA.pptx',
        tipo: TipoElemento.presentacion,
        tamanoBytes: 4200000, // 4.0 MB
        fechaModificacion: DateTime.now().subtract(const Duration(days: 5)),
        propietario: 'Prof. Mario Alvarado',
        ruta: 'Mi Unidad (R2)',
        permiso: 'Docentes y Estudiantes',
        actividad: const [
          EventoActividad(
            accion: 'Subido a Cloudflare R2 para descarga formativa',
            tiempo: 'Hace 5 días',
            usuario: 'Prof. Mario Alvarado',
            icono: Icons.slideshow_outlined,
          ),
        ],
      ),
      ElementoArchivo(
        id: 'f4',
        nombre: 'Clases_Magistrales_Soldadura_TIG_AWS.drive',
        tipo: TipoElemento.enlaceDrive,
        tamanoBytes: 0,
        esDrive: true,
        urlDrive: 'https://drive.google.com/drive/folders/inces-soldadura-tig',
        fechaModificacion: DateTime.now().subtract(const Duration(hours: 12)),
        propietario: 'Ing. Carlos Mendoza (Docente)',
        ruta: 'Mi Unidad (R2)',
        permiso: 'Docentes y Estudiantes',
        actividad: const [
          EventoActividad(
            accion: 'Carpeta de Google Drive vinculada (ahorro de espacio R2)',
            tiempo: 'Hace 12 horas',
            usuario: 'Ing. Carlos Mendoza',
            icono: Icons.add_link_rounded,
          ),
        ],
      ),
    ];
  }

  String get _rutaTexto => _rutaActual.join(' > ');

  List<ElementoArchivo> get _elementosFiltrados {
    return _elementos.where((item) {
      final coincideRuta = item.ruta == _rutaTexto;
      if (_filtroBusqueda.isEmpty) return coincideRuta;
      return coincideRuta &&
          item.nombre.toLowerCase().contains(_filtroBusqueda);
    }).toList();
  }

  List<ElementoArchivo> get _carpetasVisibles =>
      _elementosFiltrados.where((e) => e.esCarpeta).toList();

  List<ElementoArchivo> get _archivosVisibles =>
      _elementosFiltrados.where((e) => !e.esCarpeta).toList();

  void _abrirCarpeta(ElementoArchivo carpeta) {
    setState(() {
      _rutaActual.add(carpeta.nombre);
      _seleccionado = null;
    });
  }

  void _navegarARuta(int indice) {
    setState(() {
      while (_rutaActual.length > indice + 1) {
        _rutaActual.removeLast();
      }
      _seleccionado = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Acciones y diálogos
  // ---------------------------------------------------------------------------

  void _mostrarPoliticaSubida() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        ),
        title: Row(
          children: [
            const Icon(Icons.shield_outlined,
                color: IncesTheme.azulPrimario, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Política de Almacenamiento R2',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: IncesTheme.advertencia.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(IncesTheme.radioControl),
                border: Border.all(
                  color: IncesTheme.advertencia.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: IncesTheme.advertencia, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Límite asignado: 10 GB en Cloudflare R2 sin costo de transferencia.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Reglas de carga directa en Cloudflare R2:\n\n'
              '• Archivos admitidos: PDF, Word, Excel, presentaciones e imágenes optimizadas (hasta 25 MB por archivo).\n'
              '• Videos y contenido pesado (> 25 MB): Deben alojarse en Google Drive y vincularse con la opción «Vincular Google Drive» para no agotar la cuota del centro.',
              style: TextStyle(fontSize: 13.5, height: 1.45),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _crearCarpetaDialogo() {
    final controller = TextEditingController();
    Color colorElegido = IncesTheme.azulPrimario;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (contextoModal, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
            ),
            title: const Text('Nueva carpeta'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la carpeta',
                    hintText: 'ej. Guías de Soldadura TIG',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Color de la carpeta:',
                    style:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    IncesTheme.azulPrimario,
                    IncesTheme.advertencia,
                    IncesTheme.exito,
                    IncesTheme.rojoInces,
                    IncesTheme.carpetaVioleta,
                    IncesTheme.carpetaTeal,
                    IncesTheme.carpetaNaranja,
                    IncesTheme.carpetaPizarra,
                  ].map((color) {
                    final seleccionada = color == colorElegido;
                    return InkWell(
                      onTap: () => setModalState(() => colorElegido = color),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: seleccionada ? Colors.white : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: seleccionada
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                        child: seleccionada
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final nombre = controller.text.trim();
                  if (nombre.isEmpty) return;
                  setState(() {
                    _elementos.insert(
                      0,
                      ElementoArchivo(
                        id: 'c_${DateTime.now().millisecondsSinceEpoch}',
                        nombre: nombre,
                        tipo: TipoElemento.carpeta,
                        tamanoBytes: 0,
                        colorCarpeta: colorElegido,
                        fechaModificacion: DateTime.now(),
                        propietario: 'Administrador Maestro',
                        ruta: _rutaTexto,
                        permiso: 'Docentes y Estudiantes',
                        actividad: [
                          EventoActividad(
                            accion: 'Carpeta creada',
                            tiempo: 'Hace un momento',
                            usuario: 'Administrador Maestro',
                            icono: Icons.create_new_folder_outlined,
                          ),
                        ],
                      ),
                    );
                  });
                  _guardarArchivosPersistidos();
                  Navigator.of(ctx).pop();
                },
                child: const Text('Crear'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _vincularDriveDialogo() {
    final nombreCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        ),
        title: Row(
          children: [
            const Icon(Icons.add_to_drive_rounded,
                color: IncesTheme.verdeGoogleDrive, size: 24),
            const SizedBox(width: 10),
            const Text('Vincular desde Google Drive'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Añade un enlace directo a un archivo o carpeta compartida de Google Drive (ideal para videos pesados y carpetas multimedia).',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nombreCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Título o nombre del recurso',
                hintText: 'ej. Video_Taller_Soldadura_Arco.mp4',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Enlace de Google Drive',
                hintText: 'https://drive.google.com/file/d/...',
                prefixIcon: Icon(Icons.link_rounded),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              final nombre = nombreCtrl.text.trim();
              final url = urlCtrl.text.trim();
              if (nombre.isEmpty || url.isEmpty) return;
              var urlLimpia = url;
              if (!urlLimpia.startsWith('http://') &&
                  !urlLimpia.startsWith('https://')) {
                urlLimpia = 'https://$urlLimpia';
              }
              setState(() {
                _elementos.insert(
                  0,
                  ElementoArchivo(
                    id: 'drv_${DateTime.now().millisecondsSinceEpoch}',
                    nombre: nombre,
                    tipo: TipoElemento.enlaceDrive,
                    tamanoBytes: 0,
                    esDrive: true,
                    urlDrive: urlLimpia,
                    fechaModificacion: DateTime.now(),
                    propietario: 'Administrador Maestro',
                    ruta: _rutaTexto,
                    permiso: 'Docentes y Estudiantes',
                    actividad: [
                      EventoActividad(
                        accion: 'Recurso de Google Drive vinculado al centro',
                        tiempo: 'Hace un momento',
                        usuario: 'Administrador Maestro',
                        icono: Icons.add_link_rounded,
                      ),
                    ],
                  ),
                );
              });
              _guardarArchivosPersistidos();
              Navigator.of(ctx).pop();
            },
            icon: const Icon(Icons.link_rounded, size: 18),
            label: const Text('Vincular'),
          ),
        ],
      ),
    );
  }

  void _simularSubidaArchivo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        ),
        title: const Text('Subir documento a Cloudflare R2'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecciona un documento para almacenar en la nube segura de Cloudflare R2.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Manual_Tecnico_Soldadura_TIG.pdf'),
              subtitle: const Text('3.2 MB • Documento PDF'),
              tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _elementos.insert(
                    0,
                    ElementoArchivo(
                      id: 'f_${DateTime.now().millisecondsSinceEpoch}',
                      nombre: 'Manual_Tecnico_Soldadura_TIG.pdf',
                      tipo: TipoElemento.documento,
                      tamanoBytes: 3355443, // 3.2 MB
                      fechaModificacion: DateTime.now(),
                      propietario: 'Administrador Maestro',
                      ruta: _rutaTexto,
                      permiso: 'Docentes y Estudiantes',
                      actividad: [
                        EventoActividad(
                          accion: 'Documento subido a Cloudflare R2',
                          tiempo: 'Hace un momento',
                          usuario: 'Administrador Maestro',
                          icono: Icons.file_upload_outlined,
                        ),
                      ],
                    ),
                  );
                });
                _guardarArchivosPersistidos();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Archivo subido con éxito a Cloudflare R2.'),
                    backgroundColor: IncesTheme.exito,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.video_file, color: Colors.deepOrange),
              title: const Text('Clase_Practica_Video_Taller.mp4'),
              subtitle: const Text('185 MB • Video de alta definición'),
              tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                // Simulación de bloqueo por política de video pesado > 25MB
                showDialog<void>(
                  context: context,
                  builder: (ctxAviso) => AlertDialog(
                    title: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: IncesTheme.advertencia),
                        SizedBox(width: 8),
                        Text('Archivo superior a 25 MB'),
                      ],
                    ),
                    content: const Text(
                      'Este archivo de video pesa 185 MB y supera el límite de 25 MB para Cloudflare R2.\n\n'
                      'Para no saturar los 10 GB de almacenamiento gratuito del centro, por favor súbelo a Google Drive y usa el botón «Vincular Google Drive».',
                      style: TextStyle(height: 1.4),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctxAviso).pop(),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(ctxAviso).pop();
                          _vincularDriveDialogo();
                        },
                        icon: const Icon(Icons.add_to_drive_rounded, size: 16),
                        label: const Text('Vincular vía Google Drive'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _renombrarElemento(ElementoArchivo item) {
    final controller = TextEditingController(text: item.nombre);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar nombre'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nuevo nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final nuevo = controller.text.trim();
              if (nuevo.isNotEmpty) {
                setState(() {
                  item.nombre = nuevo;
                  item.actividad.insert(
                    0,
                    EventoActividad(
                      accion: 'Nombre cambiado a «$nuevo»',
                      tiempo: 'Hace un momento',
                      usuario: 'Administrador Maestro',
                      icono: Icons.drive_file_rename_outline,
                    ),
                  );
                });
                _guardarArchivosPersistidos();
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _eliminarElemento(ElementoArchivo item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.esCarpeta ? 'Eliminar carpeta' : 'Eliminar archivo'),
        content: Text(
          '¿Estás seguro de que deseas eliminar «${item.nombre}»? Esta acción liberará espacio en Cloudflare R2.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: IncesTheme.rojoInces),
            onPressed: () {
              setState(() {
                _elementos.remove(item);
                if (_seleccionado == item) _seleccionado = null;
              });
              _guardarArchivosPersistidos();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('«${item.nombre}» eliminado.')),
              );
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _descargarZipCarpeta(ElementoArchivo carpeta) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.archive_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Generando archivo ZIP de «${carpeta.nombre}» desde Cloudflare R2...',
              ),
            ),
          ],
        ),
        backgroundColor: IncesTheme.azulPrimario,
      ),
    );
  }

  Future<void> _abrirODescargarElemento(ElementoArchivo item) async {
    final selector = SelectorDeArchivosDelNavegador();
    if (item.esDrive && item.urlDrive != null) {
      var urlLimpia = item.urlDrive!.trim();
      if (!urlLimpia.startsWith('http://') &&
          !urlLimpia.startsWith('https://')) {
        urlLimpia = 'https://$urlLimpia';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Abriendo enlace de Google Drive en una nueva pestaña...'),
          backgroundColor: IncesTheme.verdeGoogleDrive,
          duration: Duration(seconds: 3),
        ),
      );
      try {
        await selector.descargar(url: urlLimpia, nombre: item.nombre);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir el enlace: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    if (!item.esCarpeta) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Descargando «${item.nombre}» desde Cloudflare R2...'),
          backgroundColor: IncesTheme.azulPrimario,
          duration: const Duration(seconds: 3),
        ),
      );
      try {
        final pdfBytes = _generarDocumentoPdfInstitucional(item);
        final nombreDescarga = item.nombre.toLowerCase().endsWith('.pdf')
            ? item.nombre
            : '${item.nombre}.pdf';
        await selector.descargarBytes(
          nombre: nombreDescarga,
          contenido: pdfBytes,
          tipoMime: 'application/pdf',
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar «${item.nombre}»: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Uint8List _generarDocumentoPdfInstitucional(ElementoArchivo item) {
    String escapePdf(String s) {
      return s
          .replaceAll('\\', '\\\\')
          .replaceAll('(', '\\(')
          .replaceAll(')', '\\)')
          .replaceAll('\r', '')
          .replaceAll('\n', ' ');
    }

    final buf = BytesBuilder();
    void writeStr(String s) => buf.add(utf8.encode(s));

    writeStr('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n');
    final offsets = <int>[];

    void startObj(int num) {
      while (offsets.length < num) {
        offsets.add(0);
      }
      offsets.add(buf.length);
      writeStr('$num 0 obj\n');
    }

    // 1: Catalog
    startObj(1);
    writeStr('<<\n  /Type /Catalog\n  /Pages 2 0 R\n>>\nendobj\n');

    // 2: Pages
    startObj(2);
    writeStr('<<\n  /Type /Pages\n  /Kids [3 0 R]\n  /Count 1\n>>\nendobj\n');

    // 3: Page
    startObj(3);
    writeStr(
      '<<\n'
      '  /Type /Page\n'
      '  /Parent 2 0 R\n'
      '  /MediaBox [0 0 612 792]\n'
      '  /Resources <<\n'
      '    /Font <<\n'
      '      /F1 4 0 R\n'
      '      /F2 5 0 R\n'
      '    >>\n'
      '  >>\n'
      '  /Contents 6 0 R\n'
      '>>\nendobj\n',
    );

    // 4: Font F1 (Helvetica-Bold)
    startObj(4);
    writeStr(
      '<<\n'
      '  /Type /Font\n'
      '  /Subtype /Type1\n'
      '  /BaseFont /Helvetica-Bold\n'
      '  /Encoding /WinAnsiEncoding\n'
      '>>\nendobj\n',
    );

    // 5: Font F2 (Helvetica)
    startObj(5);
    writeStr(
      '<<\n'
      '  /Type /Font\n'
      '  /Subtype /Type1\n'
      '  /BaseFont /Helvetica\n'
      '  /Encoding /WinAnsiEncoding\n'
      '>>\nendobj\n',
    );

    final fechaStr = '${item.fechaModificacion.day.toString().padLeft(2, '0')}/'
        '${item.fechaModificacion.month.toString().padLeft(2, '0')}/'
        '${item.fechaModificacion.year}';

    final sb = StringBuffer();
    // Header bar (INCES blue)
    sb.writeln('0.07 0.22 0.44 rg');
    sb.writeln('36 700 540 56 re f');

    // Header text
    sb.writeln('1 1 1 rg');
    sb.writeln('BT');
    sb.writeln('/F1 14 Tf');
    sb.writeln('48 732 Td');
    sb.writeln('(INSTITUTO NACIONAL DE CAPACITACION Y EDUCACION SOCIALISTA) Tj');
    sb.writeln('/F2 10 Tf');
    sb.writeln('0 -16 Td');
    sb.writeln('(CFS Rafael Urdaneta - Centro de Formacion Socialista) Tj');
    sb.writeln('ET');

    // Document title
    sb.writeln('0.1 0.1 0.1 rg');
    sb.writeln('BT');
    sb.writeln('/F1 14 Tf');
    sb.writeln('40 650 Td');
    sb.writeln('(${escapePdf(item.nombre)}) Tj');
    sb.writeln('ET');

    // Separator line
    sb.writeln('0.8 0.8 0.8 RG');
    sb.writeln('1 w');
    sb.writeln('40 635 m 572 635 l S');

    // Metadata body
    sb.writeln('BT');
    sb.writeln('/F1 11 Tf');
    sb.writeln('0.15 0.15 0.15 rg');
    sb.writeln('40 605 Td');
    sb.writeln('(DETALLES Y METADATOS DEL RECURSO FORMATIVO:) Tj');
    sb.writeln('/F2 10 Tf');
    sb.writeln('0 -22 Td');
    sb.writeln('(Aula Virtual / Taller: ${escapePdf(item.aulaVirtual)}) Tj');
    sb.writeln('0 -18 Td');
    sb.writeln('(Materia / Especialidad: ${escapePdf(item.materia)}) Tj');
    sb.writeln('0 -18 Td');
    sb.writeln('(Propietario / Instructor: ${escapePdf(item.propietario)}) Tj');
    sb.writeln('0 -18 Td');
    sb.writeln('(Permiso de acceso: ${escapePdf(item.permiso)}) Tj');
    sb.writeln('0 -18 Td');
    sb.writeln('(Fecha de Registro: $fechaStr) Tj');
    sb.writeln('0 -18 Td');
    sb.writeln('(Almacenamiento: Cloudflare R2 Object Storage - Edge Global) Tj');
    sb.writeln('0 -18 Td');
    sb.writeln('(Tamano Reportado: ${escapePdf(item.tamanoFormateado)}) Tj');
    sb.writeln('ET');

    // Explanatory note box
    sb.writeln('0.95 0.96 0.98 rg');
    sb.writeln('40 370 532 90 re f');
    sb.writeln('0.85 0.88 0.92 RG');
    sb.writeln('40 370 532 90 re S');

    sb.writeln('BT');
    sb.writeln('/F1 10 Tf');
    sb.writeln('0.07 0.22 0.44 rg');
    sb.writeln('52 435 Td');
    sb.writeln('(VALIDEZ INSTITUCIONAL Y CONTROL DE RECURSOS:) Tj');
    sb.writeln('/F2 9 Tf');
    sb.writeln('0.2 0.2 0.2 rg');
    sb.writeln('0 -16 Td');
    sb.writeln('(Este archivo ha sido verificado por la administracion del CFS Rafael Urdaneta y) Tj');
    sb.writeln('0 -14 Td');
    sb.writeln('(asignado al entorno curricular para su uso por estudiantes, aprendices e instructores.) Tj');
    sb.writeln('0 -14 Td');
    sb.writeln('(Alojado bajo protocolo de alta disponibilidad con CDN Cloudflare R2.) Tj');
    sb.writeln('ET');

    // Footer line
    sb.writeln('0.8 0.8 0.8 RG');
    sb.writeln('40 60 m 572 60 l S');

    // Footer text
    sb.writeln('BT');
    sb.writeln('/F2 8 Tf');
    sb.writeln('0.5 0.5 0.5 rg');
    sb.writeln('40 45 Td');
    sb.writeln('(INCES LMS v1.2.4 - Centro de Formacion Socialista Rafael Urdaneta - Prod 2026) Tj');
    sb.writeln('ET');

    final streamBytes = utf8.encode(sb.toString());

    // 6: Stream
    startObj(6);
    writeStr('<< /Length ${streamBytes.length} >>\nstream\n');
    buf.add(streamBytes);
    writeStr('\nendstream\nendobj\n');

    // 7: Info
    startObj(7);
    writeStr(
      '<<\n'
      '  /Title (${escapePdf(item.nombre)})\n'
      '  /Author (${escapePdf(item.propietario)})\n'
      '  /Subject (${escapePdf(item.materia)})\n'
      '  /Creator (INCES LMS Cloudflare R2 Storage)\n'
      '  /Producer (INCES CFS Rafael Urdaneta)\n'
      '>>\nendobj\n',
    );

    final xrefOffset = buf.length;
    writeStr('xref\n0 8\n');
    writeStr('0000000000 65535 f \n');
    for (var i = 1; i <= 7; i++) {
      final offStr = offsets[i].toString().padLeft(10, '0');
      writeStr('$offStr 00000 n \n');
    }

    writeStr(
      'trailer\n'
      '<<\n'
      '  /Size 8\n'
      '  /Root 1 0 R\n'
      '  /Info 7 0 R\n'
      '>>\n'
      'startxref\n'
      '$xrefOffset\n'
      '%%EOF\n',
    );

    return buf.toBytes();
  }

  void _vincularAulaVirtual(ElementoArchivo item) {
    String aulaSeleccionada = item.aulaVirtual;
    String permisoSeleccionado = item.permiso;

    final aulasDisponibles = [
      'General CFS (Todos los programas)',
      'Soldadura Básica - Taller 1',
      'Soldadura Avanzada TIG/MIG - Taller 2',
      'Electricidad y Mantenimiento Industrial',
      'Refrigeración y Climatización',
      'Alimentación y Gastronomía Industrial',
      'Asistente Administrativo y Ofimática',
      'Diseño Gráfico y Computación',
      'Formación Juvenil y Bachillerato Productivo',
    ];

    final permisosDisponibles = [
      'Docentes y Estudiantes',
      'Sólo Docente / Instructor',
      'Público Institucional (Todo el CFS)',
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.school_outlined, color: IncesTheme.azulPrimario),
              SizedBox(width: 8),
              Expanded(child: Text('Vincular a Aula Virtual')),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asigna «${item.nombre}» a un aula virtual para que sus estudiantes y profesores tengan acceso directo desde su módulo formativo.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: aulasDisponibles.contains(aulaSeleccionada)
                      ? aulaSeleccionada
                      : aulasDisponibles.first,
                  decoration: const InputDecoration(
                    labelText: 'Aula Virtual / Especialidad',
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                  ),
                  items: aulasDisponibles
                      .map((a) => DropdownMenuItem(value: a, child: Text(a, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => aulaSeleccionada = val);
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: permisosDisponibles.contains(permisoSeleccionado)
                      ? permisoSeleccionado
                      : permisosDisponibles.first,
                  decoration: const InputDecoration(
                    labelText: 'Nivel de Acceso en el Aula',
                    prefixIcon: Icon(Icons.lock_person_outlined),
                  ),
                  items: permisosDisponibles
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => permisoSeleccionado = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  item.aulaVirtual = aulaSeleccionada;
                  item.permiso = permisoSeleccionado;
                  item.actividad = [
                    EventoActividad(
                      accion: 'Asignado a $aulaSeleccionada ($permisoSeleccionado)',
                      tiempo: 'Hace un momento',
                      usuario: 'Administrador Maestro',
                      icono: Icons.school_outlined,
                    ),
                    ...item.actividad,
                  ];
                });
                _guardarArchivosPersistidos();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('«${item.nombre}» asignado a «$aulaSeleccionada».'),
                    backgroundColor: IncesTheme.azulPrimario,
                  ),
                );
              },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Guardar Asignación'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Construcción de Interfaz
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _construirBarraSuperior(theme),
          const Divider(height: 1),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _construirBarraRuta(theme),
                      const Divider(height: 1),
                      Expanded(child: _construirContenidoPrincipal(theme)),
                    ],
                  ),
                ),
                if (_mostrarPanelLateral) ...[
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 320,
                    child: _construirPanelLateral(theme),
                  ),
                ],
              ],
            ),
          ),
          _construirBarraCuota(theme),
        ],
      ),
    );
  }

  Widget _construirBarraSuperior(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: IncesTheme.azulPrimario.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(IncesTheme.radioControl),
            ),
            child: const Icon(
              Icons.cloud_done_rounded,
              color: IncesTheme.azulPrimario,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gestor de Archivos y Documentos',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Cloudflare R2 Storage (10 GB) • Integrado con Google Drive',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Barra de búsqueda rápida
          SizedBox(
            width: 260,
            height: 38,
            child: TextField(
              controller: _busquedaController,
              decoration: InputDecoration(
                hintText: 'Buscar archivo o carpeta...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _filtroBusqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => _busquedaController.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            tooltip: 'Crear o subir',
            onSelected: (val) {
              if (val == 'carpeta') _crearCarpetaDialogo();
              if (val == 'archivo') _simularSubidaArchivo();
              if (val == 'drive') _vincularDriveDialogo();
              if (val == 'politica') _mostrarPoliticaSubida();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'carpeta',
                child: Row(
                  children: [
                    Icon(Icons.create_new_folder_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Nueva carpeta'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'archivo',
                child: Row(
                  children: [
                    Icon(Icons.upload_file_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Subir documento (<25MB)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'drive',
                child: Row(
                  children: [
                    Icon(Icons.add_to_drive_rounded,
                        color: IncesTheme.verdeGoogleDrive, size: 18),
                    SizedBox(width: 10),
                    Text('Vincular Google Drive'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'politica',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18),
                    SizedBox(width: 10),
                    Text('Ver política de 10 GB'),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: IncesTheme.azulPrimario,
                borderRadius: BorderRadius.circular(IncesTheme.radioControl),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Nuevo',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Alternador de cuadrícula / lista
          IconButton(
            tooltip: _vistaCuadricula ? 'Vista de lista' : 'Vista de cuadrícula',
            icon: Icon(
              _vistaCuadricula ? Icons.view_list_rounded : Icons.grid_view_rounded,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _vistaCuadricula = !_vistaCuadricula),
          ),
          // Alternador de panel lateral
          IconButton(
            tooltip:
                _mostrarPanelLateral ? 'Ocultar detalles' : 'Ver detalles',
            icon: Icon(
              _mostrarPanelLateral
                  ? Icons.info_rounded
                  : Icons.info_outline_rounded,
              size: 20,
              color: _mostrarPanelLateral ? IncesTheme.azulPrimario : null,
            ),
            onPressed: () =>
                setState(() => _mostrarPanelLateral = !_mostrarPanelLateral),
          ),
        ],
      ),
    );
  }

  Widget _construirBarraRuta(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Row(
        children: [
          const Icon(Icons.home_outlined, size: 16),
          const SizedBox(width: 6),
          for (var i = 0; i < _rutaActual.length; i++) ...[
            if (i > 0)
              const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
            InkWell(
              onTap: () => _navegarARuta(i),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  _rutaActual[i],
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: i == _rutaActual.length - 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: i == _rutaActual.length - 1
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _construirContenidoPrincipal(ThemeData theme) {
    final carpetas = _carpetasVisibles;
    final archivos = _archivosVisibles;

    if (carpetas.isEmpty && archivos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined,
                size: 56,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'Esta carpeta está vacía',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Usa el botón «Nuevo» para crear carpetas o subir documentos a Cloudflare R2.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Almacenamiento Híbrido: Cloudflare R2 + Google Drive + Aulas Virtuales',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '• Documentos y Pensum (< 25 MB): Se almacenan directamente en Cloudflare R2 con descargas de alta velocidad.\n'
                      '• Videos y Clases Grabadas (> 25 MB): Se enlazan vía Google Drive sin consumir la cuota de 10 GB de R2.\n'
                      '• Asignación a Aulas: Puedes vincular cualquier archivo o carpeta a un aula o taller (ej. Soldadura Básica) para que sus docentes y aprendices lo tengan a mano.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (carpetas.isNotEmpty) ...[
          Text('Carpetas', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          _vistaCuadricula
              ? _rejillaCarpetas(carpetas, theme)
              : _listaCarpetas(carpetas, theme),
          const SizedBox(height: 24),
        ],
        if (archivos.isNotEmpty) ...[
          Text('Archivos y Enlaces', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          _vistaCuadricula
              ? _rejillaArchivos(archivos, theme)
              : _listaArchivos(archivos, theme),
        ],
      ],
    );
  }

  Widget _rejillaCarpetas(List<ElementoArchivo> carpetas, ThemeData theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: carpetas.map((c) {
        final seleccionada = _seleccionado == c;
        final colorCarpeta = c.colorCarpeta ?? IncesTheme.azulPrimario;

        return SizedBox(
          width: 220,
          child: Card(
            elevation: seleccionada ? 2 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: seleccionada
                    ? IncesTheme.azulPrimario
                    : theme.colorScheme.outline.withValues(alpha: 0.6),
                width: seleccionada ? 1.8 : 1,
              ),
            ),
            child: InkWell(
              onTap: () => setState(() => _seleccionado = c),
              onDoubleTap: () => _abrirCarpeta(c),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.folder_rounded, color: colorCarpeta, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        c.nombre,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      padding: EdgeInsets.zero,
                      onSelected: (val) {
                        if (val == 'abrir') _abrirCarpeta(c);
                        if (val == 'zip') _descargarZipCarpeta(c);
                        if (val == 'renombrar') _renombrarElemento(c);
                        if (val == 'eliminar') _eliminarElemento(c);
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'abrir',
                          child: Text('Abrir'),
                        ),
                        const PopupMenuItem(
                          value: 'zip',
                          child: Text('Descargar carpeta (.ZIP)'),
                        ),
                        const PopupMenuItem(
                          value: 'renombrar',
                          child: Text('Cambiar nombre'),
                        ),
                        const PopupMenuItem(
                          value: 'eliminar',
                          child: Text('Eliminar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _listaCarpetas(List<ElementoArchivo> carpetas, ThemeData theme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: carpetas.map((c) {
          final seleccionada = _seleccionado == c;
          return ListTile(
            dense: true,
            selected: seleccionada,
            leading: Icon(Icons.folder_rounded,
                color: c.colorCarpeta ?? IncesTheme.azulPrimario),
            title: Text(c.nombre,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(c.permiso),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.folder_open, size: 18),
                  tooltip: 'Abrir',
                  onPressed: () => _abrirCarpeta(c),
                ),
                IconButton(
                  icon: const Icon(Icons.archive_outlined, size: 18),
                  tooltip: 'Descargar ZIP',
                  onPressed: () => _descargarZipCarpeta(c),
                ),
              ],
            ),
            onTap: () => setState(() => _seleccionado = c),
          );
        }).toList(),
      ),
    );
  }

  Widget _rejillaArchivos(List<ElementoArchivo> archivos, ThemeData theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: archivos.map((f) {
        final seleccionada = _seleccionado == f;

        return SizedBox(
          width: 220,
          child: Card(
            elevation: seleccionada ? 2 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: seleccionada
                    ? IncesTheme.azulPrimario
                    : theme.colorScheme.outline.withValues(alpha: 0.6),
                width: seleccionada ? 1.8 : 1,
              ),
            ),
            child: InkWell(
              onTap: () => setState(() => _seleccionado = f),
              onDoubleTap: () => _abrirODescargarElemento(f),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _iconoPorTipo(f),
                        const Spacer(),
                        if (f.esDrive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: IncesTheme.verdeGoogleDrive.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Drive',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: IncesTheme.verdeGoogleDrive,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18),
                          padding: EdgeInsets.zero,
                          onSelected: (val) {
                            if (val == 'abrir') _abrirODescargarElemento(f);
                            if (val == 'vincular') _vincularAulaVirtual(f);
                            if (val == 'renombrar') _renombrarElemento(f);
                            if (val == 'eliminar') _eliminarElemento(f);
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'abrir',
                              child: Row(
                                children: [
                                  Icon(f.esDrive ? Icons.open_in_new_rounded : Icons.download_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(f.esDrive ? 'Abrir en Drive' : 'Descargar'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'vincular',
                              child: Row(
                                children: [
                                  Icon(Icons.school_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Asignar a Aula Virtual'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'renombrar',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Cambiar nombre'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'eliminar',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 18),
                                  SizedBox(width: 8),
                                  Text('Eliminar'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      f.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '🏛️ ${f.aulaVirtual}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          f.tamanoFormateado,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          f.esDrive ? 'Google Drive' : 'R2 Cloudflare',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _listaArchivos(List<ElementoArchivo> archivos, ThemeData theme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: archivos.map((f) {
          final seleccionada = _seleccionado == f;
          return GestureDetector(
            onDoubleTap: () => _abrirODescargarElemento(f),
            child: ListTile(
              dense: true,
              selected: seleccionada,
              leading: _iconoPorTipo(f),
              title: Text(f.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  '${f.tamanoFormateado} • ${f.propietario} • 🏛️ ${f.aulaVirtual}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    f.esDrive ? 'Google Drive' : 'Cloudflare R2',
                    style: TextStyle(
                      fontSize: 12,
                      color: f.esDrive
                          ? IncesTheme.verdeGoogleDrive
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      f.esDrive
                          ? Icons.open_in_new_rounded
                          : Icons.download_rounded,
                      size: 18,
                    ),
                    tooltip: f.esDrive ? 'Abrir en Drive' : 'Descargar',
                    onPressed: () => _abrirODescargarElemento(f),
                  ),
                  IconButton(
                    icon: const Icon(Icons.school_outlined, size: 18),
                    tooltip: 'Asignar a Aula Virtual',
                    onPressed: () => _vincularAulaVirtual(f),
                  ),
                ],
              ),
              onTap: () => setState(() => _seleccionado = f),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _iconoPorTipo(ElementoArchivo item) {
    if (item.esDrive) {
      return const Icon(Icons.add_to_drive_rounded,
          color: IncesTheme.verdeGoogleDrive, size: 24);
    }
    switch (item.tipo) {
      case TipoElemento.carpeta:
        return Icon(Icons.folder_rounded,
            color: item.colorCarpeta ?? IncesTheme.azulPrimario, size: 24);
      case TipoElemento.documento:
        return const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24);
      case TipoElemento.hojaCalculo:
        return const Icon(Icons.table_chart, color: Colors.green, size: 24);
      case TipoElemento.presentacion:
        return const Icon(Icons.slideshow, color: Colors.orange, size: 24);
      case TipoElemento.imagen:
        return const Icon(Icons.image, color: Colors.purple, size: 24);
      case TipoElemento.enlaceDrive:
        return const Icon(Icons.add_to_drive_rounded,
            color: IncesTheme.verdeGoogleDrive, size: 24);
    }
  }

  // ---------------------------------------------------------------------------
  // Panel lateral: Detalles y Actividad
  // ---------------------------------------------------------------------------

  Widget _construirPanelLateral(ThemeData theme) {
    final item = _seleccionado;

    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _tabLateral = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _tabLateral == 0
                              ? IncesTheme.azulPrimario
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Text(
                      'Detalles',
                      style: TextStyle(
                        fontWeight: _tabLateral == 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _tabLateral == 0 ? IncesTheme.azulPrimario : null,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _tabLateral = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _tabLateral == 1
                              ? IncesTheme.azulPrimario
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Text(
                      'Actividad',
                      style: TextStyle(
                        fontWeight: _tabLateral == 1
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _tabLateral == 1 ? IncesTheme.azulPrimario : null,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: item == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Selecciona un archivo o carpeta para ver sus propiedades.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : _tabLateral == 0
                    ? _vistaDetalles(item, theme)
                    : _vistaActividad(item, theme),
          ),
        ],
      ),
    );
  }

  Widget _vistaDetalles(ElementoArchivo item, ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _iconoPorTipo(item),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          item.nombre,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 18),
        const Divider(),
        const SizedBox(height: 12),
        _propiedadFila('Tipo', item.tipo.name.toUpperCase()),
        _propiedadFila('Tamaño', item.tamanoFormateado),
        _propiedadFila('Almacenamiento',
            item.esDrive ? 'Google Drive (Enlace)' : 'Cloudflare R2 (Directo)'),
        _propiedadFila('🏛️ Aula Virtual', item.aulaVirtual),
        _propiedadFila('📚 Materia', item.materia),
        _propiedadFila('Ubicación', item.ruta),
        _propiedadFila('Propietario', item.propietario),
        _propiedadFila('Permiso de acceso', item.permiso),
        _propiedadFila(
          'Modificado',
          '${item.fechaModificacion.day}/${item.fechaModificacion.month}/${item.fechaModificacion.year}',
        ),
        const SizedBox(height: 18),
        if (!item.esCarpeta) ...[
          if (item.esDrive)
            FilledButton.icon(
              onPressed: () => _abrirODescargarElemento(item),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Abrir en Google Drive'),
              style: FilledButton.styleFrom(
                backgroundColor: IncesTheme.verdeGoogleDrive,
              ),
            )
          else
            FilledButton.icon(
              onPressed: () => _abrirODescargarElemento(item),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Descargar archivo (R2)'),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _vincularAulaVirtual(item),
            icon: const Icon(Icons.school_outlined, size: 17),
            label: const Text('Asignar a Aula Virtual'),
          ),
        ] else ...[
          FilledButton.tonalIcon(
            onPressed: () => _descargarZipCarpeta(item),
            icon: const Icon(Icons.archive_outlined, size: 18),
            label: const Text('Descargar carpeta en ZIP'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _vincularAulaVirtual(item),
            icon: const Icon(Icons.school_outlined, size: 17),
            label: const Text('Asignar carpeta a Aula Virtual'),
          ),
        ],
      ],
    );
  }

  Widget _propiedadFila(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              etiqueta,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vistaActividad(ElementoArchivo item, ThemeData theme) {
    final actividad = item.actividad;

    if (actividad.isEmpty) {
      return Center(
        child: Text(
          'Sin actividad registrada reciente.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: actividad.length,
      itemBuilder: (ctx, idx) {
        final ev = actividad[idx];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(ev.icono, size: 16, color: IncesTheme.azulPrimario),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ev.accion,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ev.tiempo} • ${ev.usuario}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Barra inferior: Medidor de Cuota Cloudflare R2
  // ---------------------------------------------------------------------------

  Widget _construirBarraCuota(ThemeData theme) {
    const porcentaje = _cuotaUsadaGb / _cuotaTotalGb;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Row(
        children: [
          const Icon(Icons.cloud_queue_rounded,
              size: 18, color: IncesTheme.azulPrimario),
          const SizedBox(width: 8),
          Text(
            'Almacenamiento Cloudflare R2:',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: porcentaje,
                minHeight: 6,
                backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.3),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(IncesTheme.azulPrimario),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$_cuotaUsadaGb GB de $_cuotaTotalGb GB (${(porcentaje * 100).toStringAsFixed(1)}%)',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _mostrarPoliticaSubida,
            icon: const Icon(Icons.shield_outlined, size: 14),
            label: const Text('Política de 10 GB'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}
