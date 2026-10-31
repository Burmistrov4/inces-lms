import 'package:flutter/material.dart';

import '../core/gateways/aula_gateway.dart';
import '../core/result.dart';
import '../theme/inces_theme.dart';
import '../theme/temas_formacion.dart';
import '../widgets/andamiaje.dart';
import '../widgets/comunes.dart';
import 'aula_virtual_dashboard.dart';
import 'docente/docente_resumen_panel.dart';

/// Listado «Mis aulas»: las secciones de quien mira y la puerta al Aula Virtual.
///
/// ## De dónde salen las aulas
///
/// De `GET /api/v1/mi-horario`, vía [AulasPropiasGateway]. Es la única ruta del
/// sistema que lista las secciones de **quien mira**, y sirve igual a un docente
/// y a un estudiante: el rol viene en el payload y aquí sólo decide si el aula
/// se abre en modo docente o en modo estudiante.
///
/// Una misma sección aparece en `clases` **una vez por franja** del cuadrante;
/// la reducción a una fila por sección la hace el gateway, no esta pantalla.
/// Aquí se pinta lo que llega: un [AulaResumen] ya es un aula.
///
/// ## Por qué el contenido es opcional
///
/// [aulaGateway] es la puerta del **contenido** del aula (tablón, trabajo de
/// clase, entregas). El dashboard de producción **sí** la inyecta —la resuelve
/// `resolverPuertaDeContenido` en `lib/services/aula_service.dart`—, así que en
/// producción la tarjeta siempre se puede pulsar.
///
/// Sigue siendo opcional porque hay un caso legítimo en que no la hay: quien
/// quiere el listado **sin** aula abrible. Entonces el listado **sigue siendo
/// real** (viene de la ruta congelada) y la pantalla lo dice, en vez de abrir un
/// aula que no puede cargar nada. Es el estado que usan las pruebas de widget
/// para fijar que sin puerta la tarjeta **no** se puede pulsar.
///
/// **No lo «simplifiques» a `BackendAulaGateway()` aquí dentro.** El valor nulo
/// es una decisión del llamante, no un hueco que rellenar: quien lo deja nulo
/// está pidiendo justamente esto.
class PanelMisAulas extends StatefulWidget {
  const PanelMisAulas({
    super.key,
    required this.gateway,
    this.aulaGateway,
    this.onNavegarA,
    this.titulo = 'Mis aulas',
  });

  /// De dónde sale el listado de secciones.
  final AulasPropiasGateway gateway;

  /// La puerta del contenido del aula. Ver la nota de la clase.
  final AulaGateway? aulaGateway;

  /// Permite navegar a otra pestaña del dashboard docente.
  final void Function(String seccion)? onNavegarA;

  /// Cómo se llama esta sección **en el menú de quien la abre**.
  ///
  /// Medido el 2026-10-29: el docente la llama «Aulas Virtuales» y el aprendiz
  /// «Mis aulas», pero el panel escribía «Mis aulas» en el título, en las migas
  /// y en el botón de vuelta. El resultado era una pantalla que se contradecía
  /// con el menú que acababa de pulsarse. Se deja por defecto el nombre del
  /// aprendiz porque es el único que no cambia y así las pruebas existentes
  /// siguen midiendo lo mismo.
  final String titulo;

  @override
  State<PanelMisAulas> createState() => _PanelMisAulasState();
}

class _PanelMisAulasState extends State<PanelMisAulas> {
  bool _cargando = true;
  String? _error;
  MisAulas? _misAulas;

  /// La sección abierta, si la hay.
  ///
  /// Se resuelve con estado y no empujando una ruta por la misma razón que el
  /// detalle de tarea del aula: así el aula hereda la altura acotada de
  /// [ContenidoSeccion] y sus `Expanded` y `ListView` reciben un alto finito.
  /// Una ruta nueva perdería ese contrato y habría que reconstruirlo a mano.
  AulaResumen? _abierta;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Pide el código de aula y entra.
  ///
  /// **Por qué un diálogo y no un campo fijo.** El código se usa una vez al
  /// empezar el curso; un campo permanente en la pantalla ocuparía sitio todos
  /// los días para algo que se usa una tarde.
  Future<void> _unirseConCodigo() async {
    final puerta = widget.aulaGateway;
    if (puerta == null) return;

    final control = TextEditingController();
    final codigo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unirme a un aula'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Escribe el código que el docente dicta en clase. Son 8 '
                'caracteres.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: control,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: 'Código de aula',
                  hintText: 'ABCD2345',
                  counterText: '',
                  isDense: true,
                ),
                onSubmitted: (valor) => Navigator.of(ctx).pop(valor),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(control.text),
            child: const Text('Entrar'),
          ),
        ],
      ),
    );

    final limpio = codigo?.trim().toUpperCase() ?? '';
    if (limpio.isEmpty || !mounted) return;

    // El formato se valida aquí para no gastar una petición en algo que no
    // puede existir; el servidor decide si el código es real.
    if (limpio.length < 4 || !RegExp(r'^[A-Z0-9]+$').hasMatch(limpio)) {
      mostrarAviso(
        context,
        'Ese no parece un código de aula: son 4 a 8 letras o números.',
        error: true,
      );
      return;
    }

    try {
      await puerta.unirsePorCodigo(limpio);
      if (!mounted) return;
      mostrarAviso(
        context,
        'Ya estás dentro del aula. La verás en la lista.',
        exito: true,
      );
      await _cargar();
    } catch (fallo) {
      if (!mounted) return;
      mostrarAviso(
        context,
        fallo is Exception && '$fallo'.isNotEmpty
            ? _mensajeDe(fallo)
            : 'No pudimos unirte al aula. Revisa el código.',
        error: true,
      );
    }
  }

  String _mensajeDe(Object fallo) {
    // `AppException` trae el mensaje ya escrito para el usuario; cualquier otra
    // cosa se resume, porque su `toString()` no se puede enseñar.
    final texto = '$fallo';
    return texto.replaceFirst(RegExp(r'^[^:]+:\s*'), '');
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    final resultado = await Result.guard(() => widget.gateway.misAulas());
    if (!mounted) return;

    setState(() {
      _cargando = false;
      resultado.when(
        success: (mis) => _misAulas = mis,
        failure: (fallo) => _error = fallo.message,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final abierta = _abierta;
    final puerta = widget.aulaGateway;

    // El aula abierta sustituye al listado. Sólo puede haber una abierta si hay
    // puerta de contenido: sin ella, las tarjetas no son pulsables.
    if (abierta != null && puerta != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vuelta al listado. Hace falta de verdad: volver a pulsar la sección
          // en el menú no reinicia este estado —el widget se conserva—, así que
          // sin este botón el usuario quedaría encerrado en el aula.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _abierta = null),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text('Volver a ${widget.titulo}'),
            ),
          ),
          Expanded(
            child: AulaVirtualDashboardScreen(
              seccionId: abierta.seccionId,
              // La misma etiqueta que la tarjeta: el título del aula y la fila
              // del listado no pueden discrepar.
              seccionNombre: abierta.etiqueta,
              gateway: puerta,
              // El rol sale del payload, no de una bandera del llamante.
              esDocente: _misAulas?.esDocente ?? false,
            ),
          ),
        ],
      );
    }

    return ContenidoSeccion(
      migas: ['Inicio', 'Académico', widget.titulo],
      child: EstadoPanel(
        cargando: _cargando,
        error: _error,
        onReintentar: _cargar,
        child: _listado(),
      ),
    );
  }

  Widget _listado() {
    final mis = _misAulas;

    if (mis == null || mis.vacio) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelVacio(
            titulo: 'Todavía no tienes aulas activas',
            mensaje: (mis?.esDocente ?? false)
                ? 'Cuando la coordinación del centro te asigne secciones, '
                    'aparecerán aquí con su tablón y su trabajo de clase.'
                : 'Cuando la coordinación active tu sección verás aquí el tablón '
                    'de anuncios y el trabajo de clase, y podrás subir tus '
                    'entregas sin salir del aula.',
            icono: Icons.class_outlined,
            nota: mis?.periodo != null ? 'Período: ${mis!.periodo}' : null,
          ),
          // **La salida cuando la lista está vacía.** Un alumno sin aulas es
          // justo quien tiene el código en la mano; esconder la puerta en otra
          // pantalla le obliga a pedirle a alguien que lo meta a mano.
          if (!(mis?.esDocente ?? false) && widget.aulaGateway != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: FilledButton.icon(
                  onPressed: _cargando ? null : _unirseConCodigo,
                  icon: const Icon(Icons.key_rounded, size: 18),
                  label: const Text('Unirme a un aula con un código'),
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloSeccion(
          widget.titulo,
          subtitulo:
              '${plural(mis.aulas.length, 'sección', 'secciones')} en este período.',
          acciones: [
            if (!mis.esDocente && widget.onNavegarA != null)
              TextButton.icon(
                onPressed: () => widget.onNavegarA?.call('Mis entregas'),
                icon: const Icon(Icons.assignment_turned_in_outlined, size: 16),
                label: const Text('Ver tareas pendientes'),
              ),
            if (!mis.esDocente && widget.aulaGateway != null)
              TextButton.icon(
                onPressed: _cargando ? null : _unirseConCodigo,
                icon: const Icon(Icons.key_rounded, size: 16),
                label: const Text('Unirme con código'),
              ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _cargando ? null : _cargar,
              icon: const Icon(Icons.refresh_rounded, size: 18),
            ),
          ],
        ),
        if (widget.aulaGateway == null) ...[
          // Sin puerta de contenido el listado es correcto pero el aula no se
          // puede abrir. Se dice antes de que el usuario pulse, no después.
          const AvisoEnLinea(
            texto: 'Estas son tus secciones reales. El contenido del aula —el '
                'tablón y el trabajo de clase— se activará cuando el centro '
                'publique el módulo.',
            icono: Icons.info_outline,
            tono: TonoAviso.info,
          ),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: ListView(
            children: [
              for (final aula in mis.aulas) _tarjeta(aula),
              if (mis.esDocente) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                DocenteResumenPanel(onNavegarA: widget.onNavegarA),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _tarjeta(AulaResumen aula) {
    final theme = Theme.of(context);
    final abrible = widget.aulaGateway != null;
    final area = AreaFormativa.resolver(aula.etiqueta);
    final esDocente = _misAulas?.esDocente ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        // Sin puerta de contenido la tarjeta no se puede pulsar: un toque que
        // abre una pantalla incapaz de cargar nada promete algo que no cumple.
        onTap: abrible ? () => setState(() => _abierta = aula) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera tipo Google Classroom con fotografía vocacional y degradado
            SizedBox(
              height: 110,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    area.rutaImagenAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      decoration: BoxDecoration(gradient: area.degradadoBanner),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.40),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    area.icono,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    area.etiqueta,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          aula.etiqueta,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Indicadores de actividad rápida en el aula
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 16,
                    color: area.colorPrimario,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tablón',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Icon(
                    Icons.assignment_outlined,
                    size: 16,
                    color: area.colorPrimario,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Trabajo de clase',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Icon(
                    Icons.photo_library_outlined,
                    size: 16,
                    color: area.colorPrimario,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Evidencias R2',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
            // Pie de acción y estado
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    esDocente
                        ? 'Gestión de curso y calificaciones'
                        : 'Entrega de tareas y notas',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  if (abrible)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Entrar al aula',
                          style: TextStyle(
                            color: area.colorPrimario,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: area.colorPrimario,
                        ),
                      ],
                    )
                  else
                    Text(
                      'Por activar',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
