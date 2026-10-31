import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/gateways/selector_archivos.dart';
import '../../models/archivo.dart';
import '../../repositories/archivos_repository.dart';
import '../../services/selector_archivos_navegador.dart';
import '../../services/supabase_service.dart';
import '../../repositories/modulo_repository.dart';
import '../../theme/inces_theme.dart';
import '../../widgets/comunes.dart';
import '../../widgets/guardia_toque.dart';
import '../../widgets/responsivo.dart';
import '../../models/seccion.dart';
import '../../repositories/secciones_repository.dart';

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

/// Representa un archivo o carpeta dentro del almacenamiento del centro o de Google Drive.
class ElementoArchivo {
  ElementoArchivo({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.tamanoBytes,
    required this.fechaModificacion,
    required this.propietario,
    // **Opcional desde la Fase E.** El panel ya no navega por carpetas (Opción A
    // de docs/DECISION_CARPETAS_2026-10-24.md), asi que la ruta dejo de ser un
    // dato: se conserva el campo para no romper los mapas guardados y porque el
    // modelo lo usan tambien las tarjetas de detalle.
    this.ruta = 'Mi Unidad',
    this.colorCarpeta,
    this.esDrive = false,
    this.urlDrive,
    this.permiso = 'Docentes y Estudiantes',
    this.actividad = const [],
    this.aulaVirtual = 'General CFS (Todos)',
    this.materia = 'Formación Técnica General',
    this.esRemoto = false,
    this.estadoRemoto,
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

  /// `true` si el elemento llegó del servidor (hidratado o subido y confirmado).
  ///
  /// La distinción importa: un archivo remoto vive en R2 y su borrado pasa por
  /// el backend, mientras que una carpeta local sólo existe en este dispositivo.
  /// Confundirlos haría que «borrar» mintiera sobre lo que borra.
  final bool esRemoto;

  /// Estado del archivo remoto (`PENDING`, `CONFIRMED`), si es remoto.
  ///
  /// Un `PENDING` es una subida que no llegó a confirmarse: se muestra con su
  /// etiqueta en vez de esconderse, para que quien subió sepa que sigue ahí.
  final String? estadoRemoto;

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
    'esRemoto': esRemoto,
    'estadoRemoto': estadoRemoto,
    'materia': materia,
  };

  factory ElementoArchivo.fromMap(Map<String, dynamic> map) {
    final colIndice = (map['colorIndice'] as num?)?.toInt();
    final col =
        (colIndice != null &&
            colIndice >= 0 &&
            colIndice < _paletaColores.length)
        ? _paletaColores[colIndice]
        : null;
    return ElementoArchivo(
      id: map['id'] as String? ?? 'id_${DateTime.now().millisecondsSinceEpoch}',
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
      ruta: map['ruta'] as String? ?? 'Mi Unidad',
      colorCarpeta: col,
      esDrive: map['esDrive'] as bool? ?? false,
      urlDrive: map['urlDrive'] as String?,
      permiso: map['permiso'] as String? ?? 'Docentes y Estudiantes',
      aulaVirtual: map['aulaVirtual'] as String? ?? 'General CFS (Todos)',
      materia: map['materia'] as String? ?? 'Formación Técnica General',
      esRemoto: map['esRemoto'] as bool? ?? false,
      estadoRemoto: map['estadoRemoto'] as String?,
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

/// Explorador de Archivos estilo Google Drive para la nube del centro.
class CpanelExploradorArchivosPanel extends StatefulWidget {
  const CpanelExploradorArchivosPanel({
    super.key,
    this.repositorio,
    this.selector,
  });

  /// Inyectables para pruebas; en producción se resuelven solos.
  final ArchivosRepository? repositorio;
  final SelectorDeArchivos? selector;

  @override
  State<CpanelExploradorArchivosPanel> createState() =>
      _CpanelExploradorArchivosPanelState();
}

class _CpanelExploradorArchivosPanelState
    extends State<CpanelExploradorArchivosPanel> {
  bool _vistaCuadricula = true;
  bool _mostrarPanelLateral = true;

  /// Motor real de subida (Módulo 5): selector del navegador + los tres pasos
  /// firmar → PUT a R2 → confirmar. Desde el 2026-10-20 la subida es de verdad;
  /// antes era una simulación que insertía un elemento local sin tocar R2.
  /// Las aulas virtuales de verdad, para el vínculo de archivos.
  late final SeccionesRepository _repoSecciones = SeccionesRepository();

  late final ArchivosRepository _repoArchivos =
      widget.repositorio ?? ArchivosRepository();
  late final SelectorDeArchivos _selectorArchivos =
      widget.selector ?? SelectorDeArchivosDelNavegador();
  bool _subiendoArchivo = false;
  String _pasoSubida = '';
  String? _errorSubida;
  bool _cargandoArchivos = true;

  /// `true` cuando el último fallo fue «el archivo no cabe».
  ///
  /// **Fase D, decisión B** (docs/DISENO_MULTINUBE_DRIVE_2026-10-23.md): si el
  /// archivo se pasa del límite, la interfaz no deja al usuario en un callejón
  /// sin salida — le ofrece subirlo a su Drive y pegar el enlace. El código del
  /// error es lo único que separa ese caso de un fallo de red, y con el mensaje
  /// solo no basta: los dos son «no se pudo subir».
  bool _errorPorTamano = false;
  int _tabLateral = 0; // 0: Detalles, 1: Actividad
  String _filtroBusqueda = '';
  final _busquedaController = TextEditingController();

  /// ¿Se muestra la tarjeta informativa de almacenamiento híbrido?
  ///
  /// **Antes era fija** y ocupaba media pantalla sin poder cerrarse; Lorenzo lo
  /// señaló el 2026-10-21 («no se puede ni deslizar ni ocultar»). Ahora el
  /// usuario puede quitarla y no vuelve hasta recargar.
  bool _mostrarTarjetaInfo = true;

  /// ¿El buscador está expandido a ancho completo?
  ///
  /// **Patrón de Google.** Medido el 2026-10-22: el campo inline de 260 px
  /// quedaba en «Bu…» a 390 y no se podía escribir cómodo. En la barra va una
  /// lupa; al tocarla, el buscador ocupa todo el ancho con flecha para volver.
  bool _buscando = false;

  /// Pila de navegación para las migas de pan (Breadcrumbs).

  ElementoArchivo? _seleccionado;
  final Set<String> _seleccionadosIds = {};
  String? _ultimoSeleccionadoId;
  bool _descargandoZip = false;

  /// Tope de subida, **leído de `system_settings.m5_max_bytes`**.
  ///
  /// Antes era un literal de 10 MB con una nota admitiendo la deuda: «si alguien
  /// lo cambia en Configuración del Centro, estos textos vuelven a mentir». Lo
  /// preguntó el dueño el 2026-10-30 —«¿acaso la limitación de 10 MB no se
  /// ajusta al parámetro m5_max_bytes?»— y la respuesta era que no: coincidían
  /// por casualidad. Ahora el valor por defecto es el de la semilla y el real
  /// llega del servidor; si la consulta falla, se queda el de la semilla y el
  /// texto dice «hasta N MB» en vez de prometer otra cosa.
  static const int _limiteBytesPorDefecto = 10485760;
  int _limiteBytes = _limiteBytesPorDefecto;
  int _maxArchivosPorEntidad = 10;

  /// Cuota visible de la nube del centro. **No** es el tope por archivo: es el
  /// total del espacio contratado, y por eso sigue siendo una constante aparte
  /// de `m5_max_bytes`.
  static const double _cuotaTotalGb = 10.0;

  /// El tope en la unidad que se lee de un vistazo: «10 MB» o «1,5 GB».
  String get _limiteTexto {
    final mb = _limiteBytes / (1024 * 1024);
    if (mb >= 1024) {
      final gb = mb / 1024;
      return '${gb.toStringAsFixed(gb.truncateToDouble() == gb ? 0 : 1)} GB';
    }
    return '${mb.toStringAsFixed(mb.truncateToDouble() == mb ? 0 : 1)} MB';
  }

  late final ModuloRepository _moduloRepo = ModuloRepository();

  /// Lee los dos parámetros de M5 que la interfaz menciona.
  ///
  /// `m5_max_archivos_por_entidad` existe para que un aula no acumule cientos de
  /// adjuntos: es el tope por sección/entidad, no por archivo. El panel lo
  /// enseñaba mezclado con el de tamaño, y el dueño preguntó para qué servía.
  Future<void> _cargarLimites() async {
    final resultado = await _moduloRepo.obtenerSettings();
    if (!mounted) return;
    resultado.when(
      success: (ajustes) {
        for (final ajuste in ajustes) {
          final valor = ajuste.valor;
          if (valor is! num) continue;
          if (ajuste.clave == 'm5_max_bytes' && valor.toInt() > 0) {
            setState(() => _limiteBytes = valor.toInt());
          } else if (ajuste.clave == 'm5_max_archivos_por_entidad' &&
              valor.toInt() > 0) {
            setState(() => _maxArchivosPorEntidad = valor.toInt());
          }
        }
      },
      failure: (_) {
        // Con la semilla el texto sigue siendo cierto en el caso normal.
      },
    );
  }

  /// Cuota REALMENTE usada, calculada de los archivos de la unidad.
  ///
  /// **Antes era `const 1.84`** —un valor de demostración que se mostraba aunque
  /// la nube estuviera vacía— y Lorenzo lo detectó en la captura del
  /// 2026-10-21: «¿por qué 1.84 GB si no se ha subido nada?». Ahora se suma el
  /// tamaño de los archivos listados; sin archivos, es 0.
  double get _cuotaUsadaGb =>
      _elementos.fold<int>(0, (suma, e) => suma + e.tamanoBytes) /
      (1024 * 1024 * 1024);

  /// Catálogo de archivos y carpetas del centro.
  late List<ElementoArchivo> _elementos;

  @override
  void initState() {
    super.initState();
    _inicializarDatos();
    _hidratarDesdeServidor();
    _cargarLimites();
    _busquedaController.addListener(() {
      setState(() {
        _filtroBusqueda = _busquedaController.text.trim().toLowerCase();
      });
    });
  }

  /// Hidrata la lista del gestor desde la base al abrir el panel.
  ///
  /// **Qué trae y qué no.** Del servidor sólo vienen los archivos reales
  /// (`DRIVE_FILE`, la subida suelta); las carpetas y los vínculos de Google
  /// Drive siguen siendo locales —no tienen tabla en la base—, así que se
  /// conservan donde estaban. La mezcla es por id: un archivo que ya está en la
  /// lista local (porque se subió en esta sesión) no se duplica.
  ///
  /// Un fallo aquí **no** vacía la lista: si la lectura falla, el panel se queda
  /// con lo local y con el banner de error, que es mejor que una pantalla en
  /// blanco que parece «no tienes archivos».
  Future<void> _hidratarDesdeServidor() async {
    final resultado = await _repoArchivos.listarMios(
      entityType: TipoEntidadArchivo.driveFile,
    );

    if (!mounted) return;

    resultado.when(
      success: (archivos) {
        final idsLocales = _elementos.map((e) => e.id).toSet();
        final nuevos = archivos
            .where((a) => !idsLocales.contains(a.id))
            .map(
              (a) => ElementoArchivo(
                id: a.id,
                nombre: a.nombreOriginal,
                tipo: TipoElemento.documento,
                tamanoBytes: a.tamanoBytes ?? 0,
                fechaModificacion:
                    DateTime.tryParse(a.creadoEn) ?? DateTime.now(),
                propietario: _origenDelArchivo(a.entityType),
                ruta: 'Mi Unidad',
                permiso: 'Docentes y Estudiantes',
                // Sólo lectura: el archivo vive en R2 y su borrado pasa por el
                // backend, no por esta lista.
                esRemoto: true,
                estadoRemoto: a.estado.name,
              ),
            )
            .toList();

        setState(() {
          _cargandoArchivos = false;
        });
        if (nuevos.isEmpty) return;
        setState(() {
          // Los archivos del servidor van primero: son los más nuevos
          // (`created_at` descendente en la consulta) y es lo que la persona
          // espera encontrar arriba.
          _elementos.insertAll(0, nuevos);
        });
      },
      failure: (fallo) {
        setState(() {
          _cargandoArchivos = false;
          _errorSubida =
              'No pudimos cargar los archivos del centro: ${fallo.message}';
        });
      },
    );
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _inicializarDatos() {
    // **Vacío a propósito.** Antes sembraba carpetas y archivos de mentira
    // —«Ing. Carlos Mendoza (Docente)», «Prof. Mario Alvarado», «Hace 5 días»—
    // para que el panel no se viera vacío en la demostración. El problema: el
    // administrador abría «Archivos del Centro» y veía personas y documentos
    // que no existen. Los archivos reales llegan de `/archivos/mios`; lo que
    // no hay, no se pinta. Un panel vacío con una frase que lo explica es más
    // honesto que uno lleno de datos inventados.
    _elementos = [];
  }

  /// De donde salio un archivo del servidor, para no inventarle un autor.
  ///
  /// El API solo devuelve `propietarioId` (un UUID), no el nombre. Antes se
  /// pintaba «Administrador Maestro» para todos: un autor falso. Lo que el
  /// administrador necesita saber no es quien lo subio sino **que es**, y eso si
  /// lo dice el servidor.
  static String _origenDelArchivo(TipoEntidadArchivo tipo) => switch (tipo) {
    TipoEntidadArchivo.taskSubmission => 'Entrega de tarea',
    TipoEntidadArchivo.teacherGuide => 'Guia del docente',
    TipoEntidadArchivo.driveFile => 'Documento del centro',
  };

  /// Quien esta usando la app ahora mismo, para firmar lo que crea.
  ///
  /// Antes era la cadena «Administrador Maestro» escrita a mano: si un docente
  /// entraba al panel, la carpeta seguia diciendo «Administrador Maestro».
  String get _nombreDelUsuario {
    final usuario = SupabaseService.instance.client.auth.currentUser;
    final metadatos = usuario?.userMetadata;
    final nombre =
        (metadatos?['nombres'] as String?) ??
        (metadatos?['full_name'] as String?);
    if (nombre != null && nombre.trim().isNotEmpty) return nombre.trim();
    return usuario?.email ?? 'Usuario del sistema';
  }

  /// Tiempo relativo de verdad. «Hace un momento» escrito a mano mentia a los
  /// dos dias.
  static String _cuandoFue(DateTime cuando) {
    final diferencia = DateTime.now().difference(cuando);
    if (diferencia.inMinutes < 1) return 'Ahora mismo';
    if (diferencia.inMinutes < 60) return 'Hace ${diferencia.inMinutes} min';
    if (diferencia.inHours < 24) return 'Hace ${diferencia.inHours} h';
    return 'Hace ${diferencia.inDays} dias';
  }

  List<ElementoArchivo> get _elementosFiltrados {
    if (_filtroBusqueda.isEmpty) return _elementos;
    return _elementos
        .where((item) => item.nombre.toLowerCase().contains(_filtroBusqueda))
        .toList();
  }

  /// **Siempre vacía.** La Opción A (docs/DECISION_CARPETAS_2026-10-24.md) quitó
  /// las carpetas: el eje de organización es el tipo de archivo, que ya viene del
  /// servidor. La lista se queda para no reescribir el layout, que ya sabe pintar
  /// una pantalla sin carpetas.
  List<ElementoArchivo> get _carpetasVisibles => const [];

  List<ElementoArchivo> get _archivosVisibles => _elementosFiltrados;

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
            const Icon(
              Icons.shield_outlined,
              color: IncesTheme.azulPrimario,
              size: 24,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Política de Almacenamiento',
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
                  // **`PaletaInces.de(context).advertencia`, no `IncesTheme.advertencia`.**
                  // Medido el 2026-10-25: el color de relleno #F59E0B sobre el
                  // tinte del propio bloque da 1.96:1 en tema claro, por debajo
                  // del 3:1 que exige WCAG a un gráfico con significado. El
                  // comentario de `inces_theme.dart:104-135` ya lo advierte:
                  // esos cuatro colores son de relleno y «no son el color de una
                  // letra ni de un icono». `PaletaInces` es justo el que cambia
                  // con el brillo y está medido contra las superficies.
                  Icon(
                    Icons.info_outline,
                    color: PaletaInces.de(context).advertencia,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Límite asignado: 10 GB en la nube del centro, sin costo de transferencia.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Reglas de carga en la nube del centro:\n\n'
              '• Archivos admitidos: PDF, Word, Excel, presentaciones e imágenes optimizadas (hasta $_limiteTexto por archivo).\n'
              '• Tope de adjuntos por aula o sección: $_maxArchivosPorEntidad archivos.\n'
              '• Videos y contenido pesado (> $_limiteTexto): deben alojarse en Google Drive y vincularse con «Vincular Google Drive» para no agotar la cuota del centro.',
              style: const TextStyle(fontSize: 13.5, height: 1.45),
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
            const Icon(
              Icons.add_to_drive_rounded,
              color: IncesTheme.verdeGoogleDrive,
              size: 24,
            ),
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
                    propietario: _nombreDelUsuario,
                    ruta: 'Mi Unidad',
                    permiso: 'Docentes y Estudiantes',
                    actividad: [
                      EventoActividad(
                        accion: 'Recurso de Google Drive vinculado al centro',
                        tiempo: _cuandoFue(DateTime.now()),
                        usuario: _nombreDelUsuario,
                        icono: Icons.add_link_rounded,
                      ),
                    ],
                  ),
                );
              });
              Navigator.of(ctx).pop();
            },
            icon: const Icon(Icons.link_rounded, size: 18),
            label: const Text('Vincular'),
          ),
        ],
      ),
    );
  }

  /// Sube un archivo **de verdad**: selector del navegador → firmar → `PUT`
  /// directo a R2 → confirmar. Es el mismo motor que usa el gestor documental
  /// del docente (`gestor_documental_panel.dart`), con `DRIVE_FILE` como tipo de
  /// entidad: la subida suelta al gestor que habilito la migracion
  /// `202610202001_drive_file_subida_suelta.sql` el 2026-10-20.
  ///
  /// **Que cambia respecto a la simulacion que habia aqui.** Antes el dialogo
  /// ofrecia dos archivos precargados y, al tocarlos, insertia un elemento
  /// LOCAL en la lista: R2 no recibia un solo byte. La demo del 2026-10-20 lo
  /// dejo en evidencia («no se puede subir nada desde ninguna parte»). El
  /// backend, medido end-to-end ese mismo dia (firmar 201, PUT 200, confirmar
  /// 200), siempre funciono: lo que faltaba era que la UI lo llamase.
  ///
  /// Los errores llegan traducidos por el repositorio: «Extension no
  /// permitida», «El archivo supera el limite», etc. —nunca «fallo del
  /// servidor».
  Future<void> _subirArchivoReal() async {
    if (_subiendoArchivo) return;

    setState(() {
      _subiendoArchivo = true;
      _pasoSubida = 'Elige el archivo...';
      _errorSubida = null;
      _errorPorTamano = false;
    });

    ArchivoElegido? elegido;
    Object? falloSelector;
    try {
      elegido = await _selectorArchivos.elegir();
    } catch (e) {
      falloSelector = e;
    }
    if (!mounted) return;

    if (falloSelector != null) {
      setState(() {
        _subiendoArchivo = false;
        _pasoSubida = '';
        _errorSubida =
            'No pudimos abrir el selector de archivos del navegador.';
      });
      return;
    }
    if (elegido == null) {
      // Cancelar no es un error: no se muestra ningun aviso.
      setState(() {
        _subiendoArchivo = false;
        _pasoSubida = '';
      });
      return;
    }

    // Copia local NO nula: la promocion de nulabilidad no entra en el closure
    // de `success` de abajo, y sin esto el compilador se niega a compilar.
    final elegidoNoNulo = elegido;

    setState(() => _pasoSubida = 'Subiendo "${elegidoNoNulo.nombre}"...');

    final resultado = await _repoArchivos.subir(
      nombreOriginal: elegidoNoNulo.nombre,
      entityType: TipoEntidadArchivo.driveFile,
      contenido: elegidoNoNulo.contenido,
    );
    if (!mounted) return;

    setState(() {
      _subiendoArchivo = false;
      _pasoSubida = '';
    });

    resultado.when(
      success: (archivo) {
        final bytes = elegidoNoNulo.bytes;
        setState(() {
          _elementos.insert(
            0,
            ElementoArchivo(
              id: archivo.id,
              nombre: archivo.nombreOriginal,
              tipo: TipoElemento.documento,
              tamanoBytes: archivo.tamanoBytes ?? bytes,
              fechaModificacion: DateTime.now(),
              propietario: _nombreDelUsuario,
              ruta: 'Mi Unidad',
              permiso: 'Docentes y Estudiantes',
              esRemoto: true,
              estadoRemoto: archivo.estado == EstadoArchivo.confirmed
                  ? 'CONFIRMED'
                  : 'PENDING',
              actividad: [
                EventoActividad(
                  accion: 'Documento subido y confirmado',
                  tiempo: _cuandoFue(DateTime.now()),
                  usuario: _nombreDelUsuario,
                  icono: Icons.cloud_upload_outlined,
                ),
              ],
            ),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('«${archivo.nombreOriginal}» subido y confirmado.'),
            backgroundColor: IncesTheme.exito,
          ),
        );
      },
      failure: (fallo) {
        setState(() {
          _errorSubida = fallo.message;
          _errorPorTamano = fallo.code == 'ARCHIVO_DEMASIADO_GRANDE';
        });
      },
    );
  }

  /// Estado visible de la subida: progreso mientras ocurre, error traducido
  /// cuando falla. Nada cuando no hay nada, para no robar alto al listado.
  Widget _bannerEstadoSubida(ThemeData theme) {
    if (_subiendoArchivo) {
      return Container(
        width: double.infinity,
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_pasoSubida, style: theme.textTheme.bodySmall),
            ),
          ],
        ),
      );
    }
    if (_errorSubida != null) {
      return Container(
        width: double.infinity,
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorSubida!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            if (_errorPorTamano)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _errorSubida = null;
                    _errorPorTamano = false;
                  });
                  _vincularDriveDialogo();
                },
                icon: const Icon(Icons.add_link_rounded, size: 16),
                label: const Text('Subirlo a Drive'),
              ),
            IconButton(
              tooltip: 'Cerrar',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => setState(() {
                _errorSubida = null;
                _errorPorTamano = false;
              }),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
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
                      tiempo: _cuandoFue(DateTime.now()),
                      usuario: _nombreDelUsuario,
                      icono: Icons.drive_file_rename_outline,
                    ),
                  );
                });
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
          '¿Estás seguro de que deseas eliminar «${item.nombre}»? Esta acción liberará espacio en la nube del centro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: IncesTheme.rojoInces,
            ),
            onPressed: () async {
              if (item.esRemoto) {
                final resultado = await _repoArchivos.borrarComoAdmin(item.id);
                if (!mounted) return;
                resultado.when(
                  success: (_) {
                    setState(() {
                      _elementos.remove(item);
                      if (_seleccionado == item) _seleccionado = null;
                      _seleccionadosIds.remove(item.id);
                    });
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('«${item.nombre}» eliminado del centro.'),
                      ),
                    );
                  },
                  failure: (fallo) {
                    final yaNoExiste =
                        fallo.message.toLowerCase().contains(
                          'no encontramos',
                        ) ||
                        fallo.message.toLowerCase().contains('not found') ||
                        fallo.message.toLowerCase().contains('404');
                    if (yaNoExiste) {
                      setState(() {
                        _elementos.remove(item);
                        if (_seleccionado == item) _seleccionado = null;
                        _seleccionadosIds.remove(item.id);
                      });
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '«${item.nombre}» ha sido eliminado de la vista.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('No se pudo eliminar: ${fallo.message}'),
                        backgroundColor: IncesTheme.rojoInces,
                      ),
                    );
                  },
                );
              } else {
                setState(() {
                  _elementos.remove(item);
                  if (_seleccionado == item) _seleccionado = null;
                  _seleccionadosIds.remove(item.id);
                });
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('«${item.nombre}» eliminado.')),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
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
          content: Text(
            'Abriendo enlace de Google Drive en una nueva pestaña...',
          ),
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
          content: Text('Descargando «${item.nombre}»...'),
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

    final fechaStr =
        '${item.fechaModificacion.day.toString().padLeft(2, '0')}/'
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
    sb.writeln(
      '(INSTITUTO NACIONAL DE CAPACITACION Y EDUCACION SOCIALISTA) Tj',
    );
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
    sb.writeln('(Almacenamiento: Nube del Centro) Tj');
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
    sb.writeln(
      '(Este archivo ha sido verificado por la administracion del CFS Rafael Urdaneta y) Tj',
    );
    sb.writeln('0 -14 Td');
    sb.writeln(
      '(asignado al entorno curricular para su uso por estudiantes, aprendices e instructores.) Tj',
    );
    sb.writeln('0 -14 Td');
    sb.writeln(
      '(Alojado bajo protocolo de alta disponibilidad en la nube del centro.) Tj',
    );
    sb.writeln('ET');

    // Footer line
    sb.writeln('0.8 0.8 0.8 RG');
    sb.writeln('40 60 m 572 60 l S');

    // Footer text
    sb.writeln('BT');
    sb.writeln('/F2 8 Tf');
    sb.writeln('0.5 0.5 0.5 rg');
    sb.writeln('40 45 Td');
    sb.writeln(
      '(INCES LMS v1.2.4 - Centro de Formacion Socialista Rafael Urdaneta - Prod 2026) Tj',
    );
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
      '  /Creator (INCES LMS - Archivos del Centro)\n'
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

  /// Vincula un archivo a un aula virtual.
  ///
  /// **La lista sale de la base, no del código.** Estaba escrita a mano con
  /// nombres de talleres que no existen en el centro («Soldadura Avanzada
  /// TIG/MIG - Taller 2», «Refrigeración y Climatización»…), así que el
  /// administrador no reconocía ninguna de sus aulas y las que tenía no
  /// aparecían. Medido el 2026-10-31.
  Future<void> _vincularAulaVirtual(ElementoArchivo item) async {
    String aulaSeleccionada = item.aulaVirtual;
    String permisoSeleccionado = item.permiso;

    final aulasDisponibles = <String>[
      'General CFS (Todos los programas)',
    ];
    // La etiqueta es para leer; el id es lo que se guarda.
    final idPorEtiqueta = <String, String?>{
      'General CFS (Todos los programas)': null,
    };

    try {
      final resultado = await _repoSecciones.listarTodasLasSecciones(
        soloActivas: true,
      );
      for (final s in resultado.valueOrNull ?? const <Seccion>[]) {
        // Nombre reconocible sin depender del catálogo: el grupo, el lapso y el
        // código que el docente dicta en clase.
        final etiqueta = 'Aula ${s.nombre} · ${s.periodo}'
            '${s.codigoAula != null && s.codigoAula!.isNotEmpty ? ' · código ${s.codigoAula}' : ''}';
        aulasDisponibles.add(etiqueta);
        idPorEtiqueta[etiqueta] = s.id;
      }
    } catch (_) {
      // Sin catálogo se ofrece al menos lo que ya tenía el archivo: peor sería
      // una lista vacía que borre la asignación al abrir el diálogo.
    }

    // Lo que ya estaba asignado no puede desaparecer del desplegable.
    if (!aulasDisponibles.contains(aulaSeleccionada)) {
      aulasDisponibles.add(aulaSeleccionada);
    }

    final permisosDisponibles = [
      'Docentes y Estudiantes',
      'Sólo Docente / Instructor',
      'Público Institucional (Todo el CFS)',
    ];

    // El `await` de arriba puede haber desmontado el panel.
    if (!mounted) return;

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
            width: anchoDialogoSeguro(context, 440),
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
                      .map(
                        (a) => DropdownMenuItem(
                          value: a,
                          child: Text(a, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => aulaSeleccionada = val);
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue:
                      permisosDisponibles.contains(permisoSeleccionado)
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
                    if (val != null) {
                      setDlgState(() => permisoSeleccionado = val);
                    }
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
              onPressed: () async {
                // **Se guarda en la base, no en memoria.** Antes sólo cambiaba
                // el texto del modelo y al refrescar se perdía.
                //
                // El mensajero y el navegador se capturan **antes** del `await`:
                // después, el `context` del diálogo puede haberse ido y usarlo
                // sería el clásico «BuildContext across async gaps».
                final mensajero = ScaffoldMessenger.of(ctx);
                final navegador = Navigator.of(ctx);
                final seccionId = idPorEtiqueta[aulaSeleccionada];

                try {
                  await _repoArchivos.vincularAula(item.id, seccionId);
                } catch (_) {
                  mensajero.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No pudimos guardar el vínculo con el aula. '
                        'Inténtalo otra vez.',
                      ),
                    ),
                  );
                  return;
                }

                if (!mounted) return;

                setState(() {
                  item.aulaVirtual = aulaSeleccionada;
                  item.permiso = permisoSeleccionado;
                  item.actividad = [
                    EventoActividad(
                      accion:
                          'Asignado a $aulaSeleccionada ($permisoSeleccionado)',
                      tiempo: _cuandoFue(DateTime.now()),
                      usuario: _nombreDelUsuario,
                      icono: Icons.school_outlined,
                    ),
                    ...item.actividad,
                  ];
                });
                navegador.pop();
                mensajero.showSnackBar(
                  SnackBar(
                    content: Text(
                      '«${item.nombre}» asignado a «$aulaSeleccionada».',
                    ),
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
      body: Stack(
        children: [
          Column(
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
                          const Divider(height: 1),
                          _bannerEstadoSubida(theme),
                          Expanded(child: _construirContenidoPrincipal(theme)),
                        ],
                      ),
                    ),
                    if (_mostrarPanelLateral && cabenDosPaneles(context)) ...[
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
          if (_seleccionadosIds.isNotEmpty)
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: _construirBarraFlotanteSeleccion(theme),
            ),
        ],
      ),
    );
  }

  Widget _construirBarraSuperior(ThemeData theme) {
    // **Buscador expandido a ancho completo** (patrón de Google). Al pulsar la
    // lupa, la cabecera entera se convierte en el campo de búsqueda, con
    // autofoco y flecha para volver.
    if (_buscando) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Volver',
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              onPressed: () => setState(() {
                _buscando = false;
                _busquedaController.clear();
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _busquedaController,
                  autofocus: true,
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

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
          // `Expanded`: el título y el subtítulo tienen que poder ENCOGER. Sin
          // esto, el subtítulo (una línea larga) fija el ancho intrínseco y la
          // barra entera desborda en móvil/tablet —medido en la matriz: 297 px
          // de exceso a 390 (2026-10-21)—. Con `Expanded` + `ellipsis`, el texto
          // se recorta en vez de empujar la fila.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Archivos del Centro',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!esCompacto(context))
                  Text(
                    // **Corto a proposito.** Medido el 2026-10-24 a 840 px:
                    // «Archivos · la nube del centro (10 GB) · Google Drive» no
                    // cabia y salia «(10 ...». Lo que el admin necesita saber es
                    // de que va la pantalla, y eso cabe en cinco palabras.
                    'Archivos del centro',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          // **Buscador que se expande.** Medido el 2026-10-22: el campo inline
          // de 260 px quedaba en «Bu…» a 390 y no se podía escribir cómodo. En
          // la barra va una lupa; al tocarla, el buscador ocupa todo el ancho
          // (patrón de Google). El filtrado es en vivo: `_busquedaController`
          // ya alimenta `_filtroBusqueda`.
          IconButton(
            tooltip: 'Buscar',
            icon: const Icon(Icons.search_rounded, size: 20),
            onPressed: () => setState(() => _buscando = true),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            tooltip: 'Crear o subir',
            onSelected: (val) {
              // Guardia anti rebote: dos pulsaciones rapidas lanzarian dos
              // subidas del mismo archivo.
              if (val == 'archivo') {
                conGuardia(_subirArchivoReal, 'subir-archivo-drive');
              }
              if (val == 'drive') _vincularDriveDialogo();
              if (val == 'politica') _mostrarPoliticaSubida();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'archivo',
                child: Row(
                  children: [
                    const Icon(Icons.upload_file_outlined, size: 18),
                    const SizedBox(width: 10),
                    Text('Subir documento (<$_limiteTexto)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'drive',
                child: Row(
                  children: [
                    Icon(
                      Icons.add_to_drive_rounded,
                      color: IncesTheme.verdeGoogleDrive,
                      size: 18,
                    ),
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
              // En compacto, «Nuevo» va como icono «+» (patrón de Google en
              // móvil): el texto robaba el ancho que necesita el título, que
              // quedaba en «Archi…». El tooltip del menú explica la acción.
              child: Row(
                children: [
                  const Icon(Icons.add, color: Colors.white, size: 18),
                  if (!esCompacto(context)) ...[
                    const SizedBox(width: 6),
                    const Text(
                      'Nuevo',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // En compacto el alternador de cuadrícula/lista se oculta: a 390 el
          // encabezado se sobrecargaba (búsqueda + Nuevo + 2 iconos) y el
          // título quedaba en «Ar…». El toggle es una preferencia secundaria;
          // los detalles y «Nuevo» sí se conservan.
          if (!esCompacto(context)) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: _vistaCuadricula
                  ? 'Vista de lista'
                  : 'Vista de cuadrícula',
              icon: Icon(
                _vistaCuadricula
                    ? Icons.view_list_rounded
                    : Icons.grid_view_rounded,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _vistaCuadricula = !_vistaCuadricula),
            ),
          ],
          // Alternador de panel lateral
          IconButton(
            tooltip: _mostrarPanelLateral ? 'Ocultar detalles' : 'Ver detalles',
            icon: Icon(
              _mostrarPanelLateral
                  ? Icons.info_rounded
                  : Icons.info_outline_rounded,
              size: 20,
              color: _mostrarPanelLateral ? IncesTheme.azulPrimario : null,
            ),
            onPressed: () {
              if (cabenDosPaneles(context)) {
                setState(() => _mostrarPanelLateral = !_mostrarPanelLateral);
                return;
              }
              // Ventana estrecha: el panel lateral al lado aplastaba el
              // listado a unas decenas de pixeles (medido: Row con Expanded
              // + SizedBox fijo de 320). En su lugar se abre como hoja
              // inferior, que es donde Google Drive pone los detalles en
              // movil.
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.6,
                  child: _construirPanelLateral(theme),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _construirContenidoPrincipal(ThemeData theme) {
    final carpetas = _carpetasVisibles;
    final archivos = _archivosVisibles;

    // **Menú contextual de la zona de contenido.** En Drive, el clic derecho
    // sobre el espacio vacío de una carpeta abre «Nueva carpeta / Subir
    // archivo / Pegar»; aquí eso sólo existía en el botón «Crear o subir» de la
    // barra. El gesto es el mismo que el usuario espera por costumbre, y crea
    // en la ubicación actual porque `_rutaActual` es la que consultan los
    // diálogos. `onSecondaryTap` es el clic derecho en escritorio y el toque
    // largo en móvil: un solo gesto, las dos plataformas.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTap: _mostrarMenuContextual,
      onLongPress: _mostrarMenuContextual,
      child: _contenidoVisible(theme, carpetas, archivos),
    );
  }

  void _mostrarMenuContextual() {
    // La guardia anti rebote va en el MENÚ, no aquí: este método puede
    // invocarse desde el gesto o desde el botón, y el rebote de cualquiera de
    // los dos abre dos diálogos.
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Subir documento'),
              subtitle: const Text('Se guarda en la nube del centro'),
              onTap: () {
                Navigator.pop(ctx);
                conGuardia(_subirArchivoReal, 'subir-archivo-drive');
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_to_drive_rounded),
              title: const Text('Vincular Google Drive'),
              onTap: () {
                Navigator.pop(ctx);
                _vincularDriveDialogo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Política de subida'),
              onTap: () {
                Navigator.pop(ctx);
                _mostrarPoliticaSubida();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _contenidoVisible(
    ThemeData theme,
    List<ElementoArchivo> carpetas,
    List<ElementoArchivo> archivos,
  ) {
    if (carpetas.isEmpty && archivos.isEmpty) {
      if (_cargandoArchivos) {
        return const _EsqueletoArchivos();
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Todavía no hay archivos',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sube un documento con el botón de arriba. Aquí verás todo lo del '
              'centro: las guías que suban los docentes, las entregas de los '
              'estudiantes y los documentos sueltos.',
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
        if (_mostrarTarjetaInfo)
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
                Icon(
                  Icons.info_outline_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Almacenamiento Híbrido: la nube del centro + Google Drive + Aulas Virtuales',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '• Documentos y Pensum (< $_limiteTexto): se almacenan directamente en la nube del centro con descargas de alta velocidad.\n'
                        '• Videos y Clases Grabadas (> $_limiteTexto): se enlazan vía Google Drive sin consumir la cuota de 10 GB del centro.\n'
                        '• Asignación a Aulas: Puedes vincular cualquier archivo a un aula o taller (ej. Soldadura Básica) para que sus docentes y aprendices lo tengan a mano.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Ocultar',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => setState(() => _mostrarTarjetaInfo = false),
                ),
              ],
            ),
          ),
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

  Widget _rejillaArchivos(List<ElementoArchivo> archivos, ThemeData theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: archivos.map((f) {
        final seleccionada =
            _seleccionado == f || _seleccionadosIds.contains(f.id);

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
              onTap: () => _seleccionarElemento(f, archivos),
              onDoubleTap: () => _abrirODescargarElemento(f),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _seleccionadosIds.contains(f.id),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: (_) => _seleccionarElemento(f, archivos),
                        ),
                        const SizedBox(width: 4),
                        _iconoPorTipo(f),
                        const Spacer(),
                        if (f.esDrive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: IncesTheme.verdeGoogleDrive.withValues(
                                alpha: 0.12,
                              ),
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
                                  Icon(
                                    f.esDrive
                                        ? Icons.open_in_new_rounded
                                        : Icons.download_rounded,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    f.esDrive ? 'Abrir en Drive' : 'Descargar',
                                  ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.7),
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
                        Flexible(
                          child: Text(
                            f.tamanoFormateado,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Un archivo remoto sin confirmar se etiqueta en vez de
                        // esconderse: quien subió y no llegó a confirmar tiene
                        // que ver que su archivo sigue ahí, no que desapareció.
                        if (f.estadoRemoto == 'PENDING')
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Etiqueta(
                              texto: 'Sin confirmar',
                              color: IncesTheme.advertencia,
                            ),
                          ),
                        Flexible(
                          child: Text(
                            f.esDrive ? 'Google Drive' : 'Nube del centro',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
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
          final seleccionada =
              _seleccionado == f || _seleccionadosIds.contains(f.id);
          return GestureDetector(
            onDoubleTap: () => _abrirODescargarElemento(f),
            child: ListTile(
              dense: true,
              selected: seleccionada,
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _seleccionadosIds.contains(f.id),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (_) => _seleccionarElemento(f, archivos),
                  ),
                  const SizedBox(width: 4),
                  _iconoPorTipo(f),
                ],
              ),
              title: Text(
                f.nombre,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${f.tamanoFormateado} • ${f.propietario} • 🏛️ ${f.aulaVirtual}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    f.esDrive ? 'Google Drive' : 'Nube del centro',
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
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: 'Eliminar',
                    onPressed: () => _eliminarElemento(f),
                  ),
                ],
              ),
              onTap: () => _seleccionarElemento(f, archivos),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _iconoPorTipo(ElementoArchivo item) {
    if (item.esDrive) {
      return const Icon(
        Icons.add_to_drive_rounded,
        color: IncesTheme.verdeGoogleDrive,
        size: 24,
      );
    }
    switch (item.tipo) {
      case TipoElemento.carpeta:
        return Icon(
          Icons.folder_rounded,
          color: item.colorCarpeta ?? IncesTheme.azulPrimario,
          size: 24,
        );
      case TipoElemento.documento:
        return const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24);
      case TipoElemento.hojaCalculo:
        return const Icon(Icons.table_chart, color: Colors.green, size: 24);
      case TipoElemento.presentacion:
        return const Icon(Icons.slideshow, color: Colors.orange, size: 24);
      case TipoElemento.imagen:
        return const Icon(Icons.image, color: Colors.purple, size: 24);
      case TipoElemento.enlaceDrive:
        return const Icon(
          Icons.add_to_drive_rounded,
          color: IncesTheme.verdeGoogleDrive,
          size: 24,
        );
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
                        color: _tabLateral == 0
                            ? IncesTheme.azulPrimario
                            : null,
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
                        color: _tabLateral == 1
                            ? IncesTheme.azulPrimario
                            : null,
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
        _propiedadFila(
          'Almacenamiento',
          item.esDrive ? 'Google Drive (Enlace)' : 'Nube del centro (Directo)',
        ),
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
              label: const Text('Descargar archivo'),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _vincularAulaVirtual(item),
            icon: const Icon(Icons.school_outlined, size: 17),
            label: const Text('Asignar a Aula Virtual'),
          ),
        ] else ...[
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
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
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
  // Barra inferior: Medidor de Cuota de la Nube
  // ---------------------------------------------------------------------------

  Widget _construirBarraCuota(ThemeData theme) {
    final porcentaje = _cuotaUsadaGb / _cuotaTotalGb;
    // Dos filas hasta `expanded` (<840), no solo en compacto: medido el
    // 2026-10-21, a 600 px exactos la fila ancha aún se pasaba 11 px (el botón
    // «Política de 10 GB»). Desde 840 la fila única cabe.
    final compacto = !esEscritorio(context);

    final icono = const Icon(
      Icons.cloud_queue_rounded,
      size: 18,
      color: IncesTheme.azulPrimario,
    );
    final etiqueta = Text(
      'Almacenamiento:',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
    );
    final progreso = SizedBox(
      width: compacto ? 96 : 140,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: porcentaje,
          minHeight: 6,
          backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.3),
          valueColor: const AlwaysStoppedAnimation<Color>(
            IncesTheme.azulPrimario,
          ),
        ),
      ),
    );
    // Formato legible: en MB si es poco, en GB con 2 decimales si no. Antes se
    // interpolaba el double crudo y salía «0.006677582859929981 GB».
    final usadaTexto = _cuotaUsadaGb < 0.1
        ? '${(_cuotaUsadaGb * 1024).toStringAsFixed(1)} MB'
        : '${_cuotaUsadaGb.toStringAsFixed(2)} GB';
    final detalle = Text(
      '$usadaTexto de ${_cuotaTotalGb.toStringAsFixed(0)} GB',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        fontSize: 11.5,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    // **El porcentaje va en su propio elemento, no dentro del texto.** Medido
    // el 2026-10-23 a 840 px: «6.8 GB de 10 GB (68.0%)» no cabía y el ellipsis
    // se comía el final, dejando «6.8 GB de 10 GB (0...». Ahora el número
    // importante no depende de que sobre sitio.
    final porcentajeTexto = Text(
      '${(porcentaje * 100).toStringAsFixed(0)}%',
      maxLines: 1,
      style: GoogleFonts.inter(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final politica = TextButton.icon(
      onPressed: _mostrarPoliticaSubida,
      icon: const Icon(Icons.shield_outlined, size: 14),
      label: const Text('Política de 10 GB'),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 11.5),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      // **Responsive de verdad, no un `Row` rígido.** Medido el 2026-10-21: en
      // un `Row` con icono + texto + barra de 140 + texto + Spacer + botón, la
      // suma (~640 px) empujaba «Política de 10 GB» fuera de pantalla a 390
      // (297 px de desborde). En compacto se reparte en dos filas; en ancho,
      // una sola con los textos `Flexible` para que encojan con puntos
      // suspensivos en vez de desbordar.
      child: compacto
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    icono,
                    const SizedBox(width: 8),
                    Expanded(child: etiqueta),
                    const SizedBox(width: 8),
                    progreso,
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: detalle),
                    const SizedBox(width: 6),
                    porcentajeTexto,
                    politica,
                  ],
                ),
              ],
            )
          : Row(
              children: [
                icono,
                const SizedBox(width: 8),
                Flexible(child: etiqueta),
                const SizedBox(width: 8),
                progreso,
                const SizedBox(width: 10),
                Flexible(child: detalle),
                const SizedBox(width: 6),
                porcentajeTexto,
                const Spacer(),
                politica,
              ],
            ),
    );
  }

  void _seleccionarElemento(ElementoArchivo f, List<ElementoArchivo> lista) {
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    setState(() {
      if (isShift && _ultimoSeleccionadoId != null) {
        final idxAnterior = lista.indexWhere(
          (e) => e.id == _ultimoSeleccionadoId,
        );
        final idxActual = lista.indexWhere((e) => e.id == f.id);
        if (idxAnterior != -1 && idxActual != -1) {
          final start = idxAnterior < idxActual ? idxAnterior : idxActual;
          final end = idxAnterior > idxActual ? idxAnterior : idxActual;
          for (var i = start; i <= end; i++) {
            _seleccionadosIds.add(lista[i].id);
          }
        }
      } else {
        if (_seleccionadosIds.contains(f.id)) {
          _seleccionadosIds.remove(f.id);
        } else {
          _seleccionadosIds.add(f.id);
        }
      }
      _ultimoSeleccionadoId = f.id;
      _seleccionado = f;
    });
  }

  Future<void> _descargarSeleccionadosComoZip() async {
    final archivosR2 = _elementos
        .where(
          (e) => _seleccionadosIds.contains(e.id) && !e.esDrive && !e.esCarpeta,
        )
        .toList();
    if (archivosR2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Los enlaces de Google Drive y carpetas se gestionan individualmente. Selecciona al menos un archivo del centro.',
          ),
        ),
      );
      return;
    }

    setState(() => _descargandoZip = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Preparando la descarga / Comprimiendo ${archivosR2.length} ${archivosR2.length == 1 ? 'archivo' : 'archivos'}...',
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    try {
      final ids = archivosR2.map((e) => e.id).toList();
      final res = await _repoArchivos.descargarZip(ids);
      if (!mounted) return;

      res.when(
        success: (bytes) async {
          await _selectorArchivos.descargarBytes(
            nombre:
                'archivos_inces_${DateTime.now().millisecondsSinceEpoch}.zip',
            contenido: bytes,
            tipoMime: 'application/zip',
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Descarga completada con éxito.'),
              backgroundColor: IncesTheme.verdeGoogleDrive,
            ),
          );
        },
        failure: (err) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al descargar ZIP: ${err.message}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fallo de red al preparar el ZIP: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _descargandoZip = false);
      }
    }
  }

  void _eliminarSeleccionados() {
    final cant = _seleccionadosIds.length;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar elementos'),
        content: Text(
          '¿Estás seguro de eliminar los $cant elementos seleccionados?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: IncesTheme.rojoInces,
            ),
            onPressed: () {
              setState(() {
                _elementos.removeWhere((e) => _seleccionadosIds.contains(e.id));
                _seleccionadosIds.clear();
                _seleccionado = null;
              });
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$cant elementos eliminados.')),
              );
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Widget _construirBarraFlotanteSeleccion(ThemeData theme) {
    final cant = _seleccionadosIds.length;
    final r2Count = _elementos
        .where(
          (e) => _seleccionadosIds.contains(e.id) && !e.esDrive && !e.esCarpeta,
        )
        .length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Material(
          elevation: 6,
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Limpiar selección',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() {
                    _seleccionadosIds.clear();
                  }),
                ),
                const SizedBox(width: 8),
                Text(
                  '$cant ${cant == 1 ? 'seleccionado' : 'seleccionados'}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_descargandoZip)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: r2Count > 0
                        ? _descargarSeleccionadosComoZip
                        : null,
                    icon: const Icon(Icons.archive_outlined, size: 18),
                    label: Text(
                      r2Count > 1
                          ? 'Descargar ZIP ($r2Count)'
                          : 'Descargar ZIP',
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Eliminar seleccionados',
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: _eliminarSeleccionados,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Esqueleto de carga para el explorador de archivos estilo Google Drive.
class _EsqueletoArchivos extends StatelessWidget {
  const _EsqueletoArchivos();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorBase = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.5,
    );

    Widget caja({double? ancho, double? alto, double radio = 8}) {
      return Container(
        width: ancho,
        height: alto,
        decoration: BoxDecoration(
          color: colorBase,
          borderRadius: BorderRadius.circular(radio),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        caja(alto: 48, radio: 10),
        const SizedBox(height: 16),
        caja(ancho: 140, alto: 16, radio: 4),
        const SizedBox(height: 12),
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.15),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  caja(ancho: 36, alto: 36, radio: 8),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        caja(ancho: 200, alto: 14, radio: 4),
                        const SizedBox(height: 6),
                        caja(ancho: 120, alto: 10, radio: 4),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  caja(ancho: 60, alto: 12, radio: 4),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
