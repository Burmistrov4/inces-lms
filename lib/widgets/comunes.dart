import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/inces_theme.dart';

/// Piezas de interfaz compartidas entre pantallas.
///
/// Viven aquí y no dentro de una pantalla concreta porque las usan varias. La
/// alternativa —copiar el widget— es la causa de que el login y los paneles
/// tuvieran azules distintos: dos copias del «mismo» componente se desvían en
/// cuanto alguien ajusta una.

// -----------------------------------------------------------------------------
//  Encabezado institucional
// -----------------------------------------------------------------------------

/// Banner superior con la identidad del centro, el rol y el período activo.
///
/// Es el ancla visual de toda la aplicación: el usuario tiene que poder mirar
/// cualquier pantalla y saber dónde está y con qué rol, sin leer el menú.
class EncabezadoInstitucional extends StatelessWidget {
  const EncabezadoInstitucional({
    super.key,
    required this.rolEtiqueta,
    this.nombreUsuario,
    this.correoUsuario,
    this.periodoActivo,
    this.acciones = const [],
    this.onAbrirMenu,
  });

  final String rolEtiqueta;
  final String? nombreUsuario;
  final String? correoUsuario;

  /// Período académico activo (`SA26-2`). Si es `null`, no se muestra la
  /// insignia: es preferible a mostrar un guion que no significa nada.
  final String? periodoActivo;

  final List<Widget> acciones;

  /// Si se pasa, aparece el botón de menú. Sólo en pantallas angostas, donde la
  /// barra lateral pasa a ser un cajón.
  final VoidCallback? onAbrirMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;

    // El saludo usa sólo el primer nombre si hay nombre completo: «Bienvenido,
    // Lorenzo Roca» es más largo y el encabezado tiene que caber en una línea.
    final saludo = nombreUsuario == null || nombreUsuario!.trim().isEmpty
        ? 'Bienvenido'
        : 'Bienvenido, ${nombreUsuario!.trim().split(' ').first}';

    return Container(
      decoration: BoxDecoration(
        color: esOscuro
            ? IncesTheme.superficieOscura
            : IncesTheme.superficieClara,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Franja de marca: 3 px de degradado azul→rojo. Es la firma visual más
          // barata y reconocible; basta para que la aplicación se lea como
          // institucional sin ocupar espacio útil.
          Container(height: 3, decoration:
              const BoxDecoration(gradient: IncesTheme.degradadoMarca)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: LayoutBuilder(
              builder: (context, restricciones) {
                final identidad = <Widget>[
                  if (onAbrirMenu != null) ...[
                    IconButton(
                      tooltip: 'Menú',
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: onAbrirMenu,
                    ),
                    const SizedBox(width: 4),
                  ],
                  const _EscudoInces(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          saludo,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        // `Wrap` y no `Row`: en móvil el rol y el período no
                        // caben junto al nombre y deben poder saltar de línea en
                        // vez de desbordar.
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _InsigniaRol(etiqueta: rolEtiqueta),
                            if (periodoActivo != null)
                              _InsigniaPeriodo(periodo: periodoActivo!),
                            if (correoUsuario != null)
                              Text(
                                correoUsuario!,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ];

                // Las acciones iban al final de la `Row` como hijos NO
                // flexibles: a 375 px el `Expanded` del saludo se quedaba sin
                // ancho y la fila desbordaba. Es **la misma trampa** que tenía
                // `TituloSeccion` — y el hueco hoy va vacío, así que el fallo
                // sólo espera al primero que meta un botón. Por debajo de
                // 640 px las acciones bajan a una segunda línea.
                const anchoMinimoParaFila = 640.0;
                final cabenEnLaFila = acciones.isEmpty ||
                    restricciones.maxWidth >= anchoMinimoParaFila;

                if (cabenEnLaFila) {
                  return Row(children: [...identidad, ...acciones]);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: identidad),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: acciones),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Escudo con las iniciales del centro, sobre degradado institucional.
///
/// No es el logotipo real del INCES —no se dispone de la versión vectorial— y
/// por eso **no se dibuja una imitación**: una aproximación chapucera del
/// logotipo oficial es peor que no ponerlo. Es una marca tipográfica neutra,
/// fácil de sustituir por el archivo real cuando se tenga.
class _EscudoInces extends StatelessWidget {
  const _EscudoInces();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: IncesTheme.degradadoAzul,
        borderRadius: BorderRadius.circular(IncesTheme.radioControl),
      ),
      child: Text(
        'I',
        style: GoogleFonts.inter(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _InsigniaRol extends StatelessWidget {
  const _InsigniaRol({required this.etiqueta});

  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        etiqueta,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _InsigniaPeriodo extends StatelessWidget {
  const _InsigniaPeriodo({required this.periodo});

  final String periodo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: 'Período académico activo',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              periodo,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
//  Migas de pan
// -----------------------------------------------------------------------------

/// Ruta de navegación. Evita que el usuario pierda el contexto.
///
/// El último elemento nunca es pulsable: es la página actual, y ofrecer un
/// enlace a donde ya se está no aporta nada.
class MigasDePan extends StatelessWidget {
  const MigasDePan({super.key, required this.partes});

  /// De la raíz a la página actual. El último es el actual.
  final List<String> partes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (partes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < partes.length; i++) ...[
            if (i > 0)
              Icon(
                Icons.chevron_right_rounded,
                size: 15,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            Text(
              partes[i],
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: i == partes.length - 1
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: i == partes.length - 1
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
//  Tarjeta de módulo
// -----------------------------------------------------------------------------

/// Tarjeta de módulo con cabecera de marca, estado y micro-interruptor.
///
/// Sustituye la fila plana del panel anterior. La fila obligaba a leer de
/// izquierda a derecha para saber qué estaba encendido; la tarjeta permite
/// reconocerlo por color y por badge antes de leer nada.
class TarjetaModulo extends StatelessWidget {
  const TarjetaModulo({
    super.key,
    required this.titulo,
    required this.estado,
    required this.icono,
    this.descripcion,
    this.rolesEtiquetas = const [],
    this.habilitado = false,
    this.guardando = false,
    this.candadoRazon,
    this.onAlternar,
    this.onEditarRoles,
  });

  final String titulo;
  final String? descripcion;
  final EstadoModulo estado;
  final IconData icono;

  /// Roles con acceso. Vacío = visible para todos.
  final List<String> rolesEtiquetas;

  final bool habilitado;
  final bool guardando;

  /// Si no es `null`, el interruptor se bloquea y el tooltip explica por qué.
  final String? candadoRazon;

  final ValueChanged<bool>? onAlternar;
  final VoidCallback? onEditarRoles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloqueado = candadoRazon != null;

    // El color del icono **no** sale de `IncesTheme`. El mismo verde tiene que ser
    // oscuro sobre la tarjeta blanca y claro sobre la oscura, y un `const` sólo
    // puede acertar en un tema: es el fallo que tenían las diez etiquetas. El
    // tono lo pone el estado —que no sabe de brillos— y el color, la paleta.
    final par = PaletaInces.de(context).etiquetaDe(estado.tono);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera con el degradado de marca. Es la señal de «esto es un
          // módulo del sistema», y sólo se usa aquí.
          Container(
            height: 6,
            decoration: BoxDecoration(
              gradient: bloqueado
                  // El módulo crítico cambia el degradado por el rojo sólido.
                  // El color transmite la restricción antes de que el usuario
                  // llegue a intentar pulsar.
                  ? const LinearGradient(
                      colors: [IncesTheme.rojoInces, IncesTheme.rojoInces],
                    )
                  : IncesTheme.degradadoMarca,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: par.fondo,
                        borderRadius:
                            BorderRadius.circular(IncesTheme.radioControl),
                      ),
                      child: Icon(icono, size: 20, color: par.texto),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          _BadgeEstado(estado: estado),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // El interruptor se sustituye por un indicador mientras
                    // guarda. Es la única parte que se bloquea durante la
                    // petición: los campos y el botón de la tarjeta siguen
                    // vivos, porque el usuario no debería quedarse sin poder
                    // hacer nada por el guardado de otro módulo.
                    if (guardando)
                      const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (bloqueado)
                      Tooltip(
                        message: candadoRazon!,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.lock_outline,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      Switch(
                        value: habilitado,
                        onChanged: onAlternar,
                      ),
                  ],
                ),
                if (descripcion != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    descripcion!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _FilaRoles(etiquetas: rolesEtiquetas)),
                    if (onEditarRoles != null)
                      TextButton.icon(
                        onPressed: guardando ? null : onEditarRoles,
                        icon: const Icon(Icons.group_outlined, size: 15),
                        label: const Text('Roles'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La etiqueta de estado de un módulo: un icono y una palabra sobre un tinte.
///
/// Es la **implementación canónica** del chip de estado del proyecto, y por eso
/// se lleva el comentario largo: las otras cuatro copias que había repartidas por
/// las pantallas repetían exactamente este patrón —tinte al 12 %, letra e icono
/// del mismo color— y las cinco estaban mal por la misma razón. El color salía de
/// `IncesTheme`, que es el acento **de relleno**: de diez combinaciones
/// acento-sobre-superficie, dos pasaban AA.
///
/// Ahora el par sale de `PaletaInces.etiquetaDe`, que sí distingue el brillo, y el
/// chip **no elige colores**: recibe el tono y pide el par. Medido en
/// `test/paleta_inces_test.dart` contra las dos superficies donde puede caer.
class _BadgeEstado extends StatelessWidget {
  const _BadgeEstado({required this.estado});

  final EstadoModulo estado;

  @override
  Widget build(BuildContext context) {
    final par = PaletaInces.de(context).etiquetaDe(estado.tono);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: par.fondo,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(estado.icono, size: 11, color: par.texto),
          const SizedBox(width: 4),
          Text(
            estado.etiqueta,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: par.texto,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaRoles extends StatelessWidget {
  const _FilaRoles({required this.etiquetas});

  final List<String> etiquetas;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (etiquetas.isEmpty) {
      return Row(
        children: [
          Icon(
            Icons.public_outlined,
            size: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            'Todos los roles',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final etiqueta in etiquetas)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              etiqueta,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
//  Tarjeta de métrica
// -----------------------------------------------------------------------------

/// Métrica rápida para la cabecera del Command Center.
class TarjetaMetrica extends StatelessWidget {
  const TarjetaMetrica({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.icono,
    this.tono = TonoEstado.info,
    this.onTap,
  });

  final String etiqueta;
  final String valor;
  final IconData icono;
  final VoidCallback? onTap;

  /// El **tono** del icono, no su color.
  ///
  /// Era un `Color?` y por ahí entraban los acentos de relleno de `IncesTheme`:
  /// `#16A34A` daba 2.65:1 sobre su propio tinte en modo claro, por debajo del 3:1
  /// que WCAG pide a un gráfico con significado. Con un tono el color no se puede
  /// elegir mal.
  ///
  /// Por defecto [TonoEstado.info] y no `colorScheme.primary` por la misma razón
  /// medida: el primario de modo oscuro (`#0059B3`) da **1.99:1** sobre su propio
  /// tinte, así que el valor por defecto era justo el que peor se veía. Medido el
  /// 2026-09-30.
  final TonoEstado tono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final par = PaletaInces.de(context).etiquetaDe(tono);

    final cuerpo = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: par.fondo,
              borderRadius: BorderRadius.circular(IncesTheme.radioControl),
            ),
            child: Icon(icono, size: 19, color: par.texto),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  valor,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  etiqueta,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
        ],
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
              child: cuerpo,
            )
          : cuerpo,
    );
  }
}

// -----------------------------------------------------------------------------
//  Aviso
// -----------------------------------------------------------------------------

/// Aviso en línea, para explicar reglas que el usuario no puede deducir.
///
/// Se mantiene distinto del `SnackBar` a propósito: el SnackBar desaparece y
/// sirve para confirmar una acción; esto explica una regla vigente y tiene que
/// seguir visible mientras el usuario decide.
class AvisoEnLinea extends StatelessWidget {
  const AvisoEnLinea({
    super.key,
    required this.texto,
    this.icono = Icons.info_outline,
    this.tono = TonoAviso.info,
    this.onCerrar,
    this.compacto = false,
  });

  final String texto;
  final IconData icono;
  final TonoAviso tono;
  final VoidCallback? onCerrar;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // El icono cae sobre un tinte de su propio color, así que necesita un acento
    // de **primer plano**: los de `IncesTheme` son de relleno. Medido el
    // 2026-09-30, como letra sobre su propio tinte: el ámbar daba 1.81:1 en modo
    // claro y el azul primario, 2.42:1 en oscuro. Ninguno de los dos se lee.
    final paleta = PaletaInces.de(context);
    final color = switch (tono) {
      TonoAviso.info => paleta.info,
      TonoAviso.exito => paleta.exito,
      TonoAviso.advertencia => paleta.advertencia,
      TonoAviso.peligro => paleta.error,
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: compacto ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(IncesTheme.radioControl),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icono, size: compacto ? 15 : 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: (compacto ? theme.textTheme.labelSmall : theme.textTheme.bodySmall)?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (onCerrar != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onCerrar,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum TonoAviso { info, exito, advertencia, peligro }

// -----------------------------------------------------------------------------
//  Estados de carga y error
// -----------------------------------------------------------------------------

/// Error de carga de un diálogo, con el botón de reintentar.
///
/// **Por qué existe habiendo un [EstadoPanel].** No son el mismo sitio: aquél
/// envuelve el cuerpo entero de un panel y su rótulo es fijo («No pudimos cargar
/// esta sección»), porque un panel es siempre la misma pantalla. Un diálogo
/// sabe **qué** estaba cargando y lo dice con su nombre —«No se pudo cargar la
/// cola», «No se pudo cargar la lista»—, que es información que el usuario no
/// tiene de otra forma.
///
/// **Por qué es público y no privado de cada diálogo.** Nació copiado: el
/// diálogo de la cola y el de los inscritos llevaban cada uno su propia copia
/// privada de estas mismas cuarenta líneas, y la segunda nació al escribir la
/// primera. Una copia privada por pantalla es deuda silenciosa —el día que se
/// arregle el contraste de una, la otra se queda atrás—, y este widget no tiene
/// nada específico de ninguna de las dos.
///
/// El título dice **qué** falló y no repite la palabra «error»: el mensaje
/// traducido de `AppException` ya empieza por «Ocurrió un error…», y duplicarlo
/// deja al usuario sin información nueva.
class ErrorConReintento extends StatelessWidget {
  const ErrorConReintento({
    super.key,
    required this.titulo,
    required this.mensaje,
    required this.onReintentar,
  });

  /// Qué se estaba cargando, en pasado y sin la palabra «error».
  final String titulo;

  /// El mensaje ya traducido de `AppException`, listo para mostrar.
  final String mensaje;

  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(titulo, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Envoltorio que resuelve los estados de carga y error de un panel.
///
/// Se conserva la lógica de la versión anterior —era correcta y evitaba que uno
/// de los tres paneles se quedara sin manejar el error— pero con la identidad
/// nueva.
class EstadoPanel extends StatelessWidget {
  const EstadoPanel({
    super.key,
    required this.cargando,
    required this.error,
    required this.onReintentar,
    required this.child,
    this.esqueleto,
  });

  final bool cargando;
  final String? error;
  final VoidCallback onReintentar;
  final Widget child;

  /// Lo que se muestra mientras carga. Por defecto, un esqueleto genérico.
  final Widget? esqueleto;

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      // **Esqueleto y no spinner.** Medido el 2026-10-23: un
      // `CircularProgressIndicator` centrado no dice que esta cargando ni
      // cuanta falta. El esqueleto muestra la forma del contenido que viene y
      // la espera se percibe mas corta (rendimiento percibido, limite de
      // Nielsen de 1 s).
      return esqueleto ?? const EsqueletoLista();
    }

    final mensaje = error;
    if (mensaje != null) {
      final theme = Theme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off_outlined,
                  size: 26,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No pudimos cargar esta sección',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return child;
  }
}

/// Título de sección dentro de un panel.
class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key, this.subtitulo, this.acciones});

  final String texto;
  final String? subtitulo;
  final List<Widget>? acciones;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final titulo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          texto.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        if (subtitulo != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitulo!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    final botones = acciones;
    if (botones == null || botones.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: titulo,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, restricciones) {
          // Título y acciones en la misma fila **sólo si caben**. Antes se
          // metían siempre, y a 375 px las acciones se comían el ancho: la
          // `Row` desbordaba y —peor, porque no se ve— el `Expanded` del
          // título se quedaba con ancho cero, así que el subtítulo envolvía
          // una letra por línea y la cabecera acababa **más alta que la
          // pantalla**. El desborde horizontal tapaba al vertical.
          const anchoMinimoParaFila = 640.0;

          if (restricciones.maxWidth >= anchoMinimoParaFila) {
            // Las acciones van en un `Wrap` ACOTADO (`Flexible`), no sueltas en
            // la `Row`: con 5 acciones (Guardias: Horarios, Aulas, Matriz/Lista,
            // Asignar guardia) la fila desbordaba 15 px a 840 —medido el
            // 2026-10-22—. `Flexible` les da un ancho máximo y el `Wrap` las
            // pasa a otra línea cuando no caben, sin desbordar.
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: titulo),
                const SizedBox(width: 16),
                Flexible(
                  flex: 2,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: botones,
                  ),
                ),
              ],
            );
          }

          // En estrecho se apilan, y los botones envuelven entre sí.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titulo,
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 8, children: botones),
            ],
          );
        },
      ),
    );
  }
}

/// Estado vacío explicativo.
///
/// Un panel vacío sin texto deja al usuario sin saber si le falta un permiso,
/// si no hay datos, o si la aplicación falla. Las tres cosas se ven igual, así
/// que el vacío **siempre** dice cuál de las tres es.
class PanelVacio extends StatelessWidget {
  const PanelVacio({
    super.key,
    required this.titulo,
    required this.mensaje,
    required this.icono,
    this.nota,
  });

  final String titulo;
  final String mensaje;
  final IconData icono;

  /// Aclaración adicional sobre por qué está vacío (qué módulo falta, etc.).
  final String? nota;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 30, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 20),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Text(
                mensaje,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (nota != null) ...[
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AvisoEnLinea(texto: nota!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
//  Utilidades
// -----------------------------------------------------------------------------

/// Etiqueta pequeña de fila: tipo, cupo, estado, rango de fechas.
///
/// Vive aquí y no en cada panel porque los tres catálogos del cPanel —espacios,
/// lapsos y guardias— pintan la misma fila de datos secundarios bajo el título,
/// y tres copias del «mismo» widget se desvían en cuanto alguien ajusta una.
///
/// [destacada] la tiñe con el color primario. Se usa para el dato que hay que
/// ver primero —el lapso vigente—, no para decorar: si todas destacan, ninguna
/// destaca.
class Etiqueta extends StatelessWidget {
  const Etiqueta({
    super.key,
    required this.texto,
    this.destacada = false,
    this.color,
  });

  final String texto;
  final bool destacada;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final acento = color ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: (destacada || color != null)
            ? acento.withValues(alpha: 0.12)
            : null,
        border: Border.all(
          color: (destacada || color != null)
              ? acento.withValues(alpha: 0.5)
              : theme.colorScheme.outline,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        texto,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight:
              (destacada || color != null) ? FontWeight.w600 : FontWeight.w500,
          color: (destacada || color != null)
              ? acento
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Formatea una fecha en algo legible sin depender de `intl`.
String formatearFechaHora(DateTime? fecha) {
  if (fecha == null) return '—';

  final local = fecha.toLocal();
  final dia = local.day.toString().padLeft(2, '0');
  final mes = local.month.toString().padLeft(2, '0');
  final hora = local.hour.toString().padLeft(2, '0');
  final minuto = local.minute.toString().padLeft(2, '0');

  return '$dia/$mes/${local.year} $hora:$minuto';
}

/// Muestra un mensaje temporal en la parte inferior.
///
/// Sustituye el `SnackBar` sin estilo por uno con icono y color según el tono:
/// el texto solo obliga a leer la frase entera para saber si algo salió bien.
void mostrarAviso(
  BuildContext context,
  String mensaje, {
  bool error = false,
  bool exito = false,
}) {
  if (!context.mounted) return;

  final theme = Theme.of(context);
  final color = error
      ? IncesTheme.error
      : exito
          ? IncesTheme.exito
          : null;

  // El icono depende del tono; el color del texto, de si hay tono o no. Un
  // SnackBar sin tono usa el color de acento del tema, que ya contrasta sobre
  // el fondo inverso.
  final colorContenido =
      color != null ? Colors.white : theme.colorScheme.onInverseSurface;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: error ? 6 : 3),
        content: Row(
          children: [
            Icon(
              error
                  ? Icons.error_outline
                  : exito
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
              size: 19,
              color: colorContenido,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensaje,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: colorContenido,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}


/// **Esqueleto de carga: la forma del contenido que viene.**
///
/// Medido el 2026-10-23: los paneles mostraban un `CircularProgressIndicator`
/// centrado mientras cargaban, que no dice *que* esta cargando. Este esqueleto
/// pinta tarjetas con la misma forma que la lista real, con un pulso suave, para
/// que la espera se perciba mas corta y no haya un salto cuando llegan los datos.
/// Pluraliza de verdad: «1 sección» / «3 secciones».
///
/// Medido el 2026-10-23: siete sitios de la interfaz escribían el atajo
/// «sección(es)», que en una aplicación se lee como descuido. Con uno o con
/// mil, el texto sale bien.
String plural(int n, String singular, [String? formaPlural]) {
  final palabra = n == 1 ? singular : (formaPlural ?? '${singular}es');
  return '$n $palabra';
}

class EsqueletoLista extends StatefulWidget {
  const EsqueletoLista({
    super.key,
    this.tarjetas = 4,
    this.conBarraFiltros = false,
  });

  /// Cuantas tarjetas de mentira se pintan.
  final int tarjetas;

  /// Si se pinta tambien la barra de busqueda/filtros de arriba.
  ///
  /// **Es `false` por defecto a proposito.** Medido el 2026-10-23: con la
  /// barra y las pastillas puestas por defecto, un panel que no tiene ninguna
  /// de las dos cosas —Inscripciones y Cupos, por ejemplo— mostraba un
  /// esqueleto que **contradecia** la forma real de lo que iba a aparecer. Un
  /// esqueleto que promete una barra que no existe es peor que no tener
  /// esqueleto: el usuario espera algo que no llega. Los paneles que sí tienen
  /// barra la piden explicita.
  final bool conBarraFiltros;

  @override
  State<EsqueletoLista> createState() => _EsqueletoListaState();
}

class _EsqueletoListaState extends State<EsqueletoLista>
    with SingleTickerProviderStateMixin {
  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  Widget _bloque(BuildContext context, double alto, double fraccion) {
    final theme = Theme.of(context);
    return FadeTransition(
      opacity: _control.drive(Tween<double>(begin: 0.45, end: 1)),
      child: FractionallySizedBox(
        widthFactor: fraccion,
        alignment: Alignment.centerLeft,
        child: Container(
          height: alto,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget tarjeta() {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            FadeTransition(
              opacity: _control.drive(Tween<double>(begin: 0.45, end: 1)),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bloque(context, 13, 0.55),
                  const SizedBox(height: 8),
                  _bloque(context, 10, 0.35),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.conBarraFiltros) ...[
          Container(
            height: 48,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < 4; i++)
                Container(
                  width: 74,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        for (var i = 0; i < widget.tarjetas; i++) tarjeta(),
      ],
    );
  }
}
