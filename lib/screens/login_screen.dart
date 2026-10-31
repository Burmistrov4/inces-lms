import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:inces_lms_app/core/errors/app_exception.dart';
import 'package:inces_lms_app/core/network/api_client.dart';
import 'package:inces_lms_app/core/result.dart';
import 'package:inces_lms_app/screens/aspirante_form_screen.dart';
import 'package:inces_lms_app/screens/landing_page.dart';
import 'package:inces_lms_app/screens/restablecer_con_codigo_screen.dart';
import 'package:inces_lms_app/services/auth_service.dart';
import 'package:inces_lms_app/theme/inces_theme.dart';
import 'package:inces_lms_app/widgets/responsivo.dart';

/// Pantalla de inicio de sesión.
///
/// ## Qué cambió en el rediseño
///
/// Antes era una tarjeta oscura sobre fondo oscuro. Funcionaba, pero la
/// aplicación entera se veía apagada y el contraste entre una pantalla de acceso
/// institucional y una herramienta cualquiera era nulo. Ahora hay un **panel de
/// marca** a la izquierda —degradado institucional, nombre del centro y sede— y
/// la tarjeta del formulario a la derecha.
///
/// En pantallas angostas el panel de marca desaparece en lugar de encogerse: un
/// degradado de 60 px de ancho no comunica nada y roba sitio al formulario.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  final AuthService _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;

  /// Ancho a partir del cual se muestra el panel de marca lateral.
  static const double _anchoConPanelMarca = 900;

  @override
  void initState() {
    super.initState();
    ApiClient.calentarBackend();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Guarda de reentrada. Sin esto, pulsar Enter dos veces (o Enter mientras
    // un intento está en vuelo) lanza dos peticiones en paralelo: la segunda
    // compite con la primera y el último `setState` gana, así que el estado de
    // carga puede quedar desincronizado con la realidad.
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final resultado = await _authService.iniciarSesion(
      identificador: _identifierController.text,
      password: _passwordController.text,
    );

    // Cierra el ciclo de autocompletado para que el navegador guarde o
    // actualice las credenciales. Sin esto, Chrome decide por su cuenta y a
    // veces deja el formulario en un estado intermedio: el campo muestra un
    // valor que el controlador no tiene, y borrarlo con el teclado no surte
    // efecto.
    if (resultado.isSuccess) {
      TextInput.finishAutofillContext();
    }

    // `_isLoading` se libera ANTES de comprobar `mounted`.
    //
    // El orden importa: si el widget se desmonta mientras la petición viaja
    // (el usuario navega, cierra la pestaña, el AuthGate cambia de pantalla),
    // un `return` temprano dejaría `_isLoading` en `true` para siempre. Al
    // volver a esta pantalla, los campos seguirían deshabilitados y la interfaz
    // parecería congelada sin causa visible.
    if (mounted) setState(() => _isLoading = false);

    if (!mounted) return;

    resultado.when(
      // El AuthGate escucha los cambios de sesión y enruta al panel del rol.
      success: (_) {
        TextInput.finishAutofillContext();
        _cerrarSiFueEmpujada();
      },
      failure: (AppException error) => _showError(error.message),
    );
  }

  /// Cierra esta pantalla si se abrió **empujada** sobre el `AuthGate`.
  ///
  /// El `AuthGate` es la raíz y ya está reconstruyendo hacia el panel del rol
  /// cuando la sesión cambia. Pero si el login se abrió empujado —desde el botón
  /// «Portal Académico» de la portada—, esa ruta empujada quedaría **por encima**
  /// del panel reconstruido y el usuario seguiría viendo el formulario de acceso
  /// con la sesión ya iniciada. Hay que cerrarla.
  ///
  /// Si el login es hijo directo del `AuthGate` no hay nada que cerrar: es la
  /// primera ruta y `canPop()` es falso, así que esto no hace nada.
  void _cerrarSiFueEmpujada() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((ruta) => ruta.isFirst);
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: IncesTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(IncesTheme.radioControl),
          ),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.inter(fontSize: 13.5, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
  }

  void _volverAlInicio() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const LandingPage()),
      );
    }
  }

  /// Gestiona la recuperación de contraseña por correo electrónico vía SMTP
  /// o de forma alternativa mediante código temporal entregado en coordinación.
  Future<void> _handleRecuperacion() async {
    final controllerIdentificador = TextEditingController(
      text: _identifierController.text.trim(),
    );
    String? errorModal;
    bool enviandoCorreo = false;
    bool correoEnviado = false;
    MetodoRecuperacionUsado? metodoUsado;
    String? mensajeExito;

    await showDialog<void>(
      context: context,
      barrierDismissible: !enviandoCorreo,
      builder: (contextoDialogo) {
        return StatefulBuilder(
          builder: (contexto, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: IncesTheme.azulPrimario.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(IncesTheme.radioControl),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: IncesTheme.azulPrimario,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Recuperar contraseña',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: anchoDialogoSeguro(context, 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (correoEnviado) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: IncesTheme.exito.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(IncesTheme.radioControl),
                            border: Border.all(
                              color: IncesTheme.exito.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: IncesTheme.exito,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  (mensajeExito != null &&
                                          !mensajeExito!.contains('SMTP') &&
                                          !mensajeExito!.contains('entrega activa'))
                                      ? mensajeExito!
                                      : (metodoUsado == MetodoRecuperacionUsado.supabase
                                          ? 'Hemos enviado un enlace de recuperación seguro a tu correo electrónico.'
                                          : 'Si la cuenta está registrada, hemos enviado el código de restablecimiento a tu correo electrónico.'),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: IncesTheme.exito,
                                    fontWeight: FontWeight.w500,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          metodoUsado == MetodoRecuperacionUsado.supabase
                              ? 'Abre tu correo (revisa la bandeja de entrada o spam) y pulsa directamente en el botón o enlace recibido para crear tu nueva contraseña. No necesitas escribir ningún código manual.'
                              : 'Revisa tu bandeja de entrada o la carpeta de spam para ver tu código temporal. Luego pulsa abajo para ingresarlo y crear tu nueva contraseña.',
                          style: GoogleFonts.inter(fontSize: 13, height: 1.4),
                        ),
                      ] else ...[
                        Text(
                          'Ingresa tu correo electrónico registrado o número de cédula para enviarte un código o enlace de recuperación:',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            color: Theme.of(contexto).colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: controllerIdentificador,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: 'Cédula o Correo',
                            hintText: 'ej. V-12345678 o usuario@gmail.com',
                            prefixIcon:
                                const Icon(Icons.person_outline, size: 20),
                            errorText: errorModal,
                            errorMaxLines: 4,
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: enviandoCorreo
                              ? null
                              : () async {
                                  final id =
                                      controllerIdentificador.text.trim();
                                  if (id.isEmpty) {
                                    setModalState(() {
                                      errorModal =
                                          'Ingresa tu correo o cédula';
                                    });
                                    return;
                                  }
                                  setModalState(() {
                                    enviandoCorreo = true;
                                    errorModal = null;
                                  });

                                  final resultado = await _authService
                                      .solicitarRecuperacionConFallback(id);

                                  if (!mounted) return;
                                  switch (resultado) {
                                    case Success(value: final resp):
                                      setModalState(() {
                                        enviandoCorreo = false;
                                        correoEnviado = true;
                                        metodoUsado = resp.metodo;
                                        mensajeExito = resp.mensaje;
                                      });
                                    case Failure(error: final fallo):
                                      setModalState(() {
                                        enviandoCorreo = false;
                                        errorModal = fallo.message;
                                      });
                                  }
                                },
                          icon: enviandoCorreo
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.mail_outline, size: 18),
                          label: Text(
                            enviandoCorreo
                                ? 'Enviando recuperación...'
                                : 'Enviar recuperación por correo',
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.apartment_outlined,
                              size: 16,
                              color: Theme.of(contexto)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Método presencial en coordinación:\nSi no tienes acceso a tu correo, puedes solicitar un código temporal en la coordinación del centro presentando tu cédula de identidad.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Theme.of(contexto)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                if (correoEnviado &&
                    metodoUsado == MetodoRecuperacionUsado.supabase) ...[
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(contextoDialogo).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RestablecerConCodigoScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.pin_outlined, size: 16),
                    label: const Text('Tengo un código manual'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(contextoDialogo).pop(),
                    child: const Text('Entendido, revisar mi correo'),
                  ),
                ] else ...[
                  TextButton(
                    onPressed: enviandoCorreo
                        ? null
                        : () => Navigator.of(contextoDialogo).pop(),
                    child: const Text('Cerrar'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: enviandoCorreo
                        ? null
                        : () {
                            Navigator.of(contextoDialogo).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const RestablecerConCodigoScreen(),
                              ),
                            );
                          },
                    icon: const Icon(Icons.pin_outlined, size: 18),
                    label: Text(correoEnviado
                        ? 'Ingresar código temporal'
                        : 'Ingresar código'),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esAngosto = MediaQuery.sizeOf(context).width < _anchoConPanelMarca;

    return Scaffold(
      body: Row(
        children: [
          if (!esAngosto)
            Expanded(flex: 5, child: _PanelMarca(onVolver: _volverAlInicio)),
          Expanded(
            flex: 6,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _formulario(theme),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formulario(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _volverAlInicio,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Volver al inicio'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              foregroundColor: theme.colorScheme.primary,
              textStyle: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // En móvil el panel de marca no se ve, así que la identidad tiene que
        // aparecer aquí. Se muestra sólo cuando el panel está oculto para no
        // repetir el nombre del centro dos veces en la misma pantalla.
        if (MediaQuery.sizeOf(context).width < _anchoConPanelMarca) ...[
          InkWell(
            onTap: _volverAlInicio,
            borderRadius: BorderRadius.circular(IncesTheme.radioControl),
            child: Row(
              children: [
                // **El icono de la app, no un cuadrado con una «I».** Este bloque
                // vive sobre `surface` (claro en tema claro), así que el logo
                // blanco sería invisible: se usa el icono, que trae su propio
                // fondo azul y se lee en los dos temas. Es el mismo archivo que
                // Android usa al añadir la página como acceso directo, así que
                // la marca del login y la del móvil coinciden.
                ClipRRect(
                  borderRadius: BorderRadius.circular(IncesTheme.radioControl),
                  child: Image.asset(
                    'assets/images/icono_app.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    semanticLabel: 'INCES LMS',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('INCES LMS', style: theme.textTheme.titleMedium),
                      Text(
                        'La Isabelica',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],
        Text('Iniciar sesión', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Accede con tu cédula o tu correo institucional.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),

        AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _identifierController,
                  // NOTA: los campos NO se deshabilitan durante la carga.
                  //
                  // Aquí había `enabled: !_isLoading`, y era un error: al pulsar
                  // Enter en este campo se disparaba el inicio de sesión, que ponía
                  // `_isLoading = true` y **deshabilitaba el campo de contraseña
                  // mientras el usuario aún escribía**. Un campo que deja de
                  // aceptar texto sin explicación es indistinguible de una
                  // aplicación colgada. Se bloquea el BOTÓN, no el campo.
                  style: theme.textTheme.bodyMedium,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                // Mueve el foco al campo de contraseña.
                //
                // `TextInputAction.next` NO lo hace: sólo cambia la tecla que
                // dibuja el teclado. Sin este callback, pulsar Enter lanzaba el
                // inicio de sesión con la contraseña vacía.
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                decoration: const InputDecoration(
                  labelText: 'Cédula o Correo',
                  prefixIcon: Icon(Icons.badge_outlined, size: 20),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Ingresa tu cédula o correo';
                  }
                  if (text.contains('@') &&
                      !RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(text)) {
                    return 'Ingresa un correo válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                style: theme.textTheme.bodyMedium,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                obscureText: _obscurePassword,
                onChanged: (_) => setState(() {}),
                onFieldSubmitted: (_) => _handleLogin(),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // **Vaciar, siempre.** Con el autocompletado del navegador
                      // el campo puede quedar con un valor que el controlador
                      // no ve —el navegador escribe en el input oculto y Flutter
                      // no se entera—, y entonces borrar con el teclado no
                      // vacía nada. Un botón que limpia el controlador resuelve
                      // el caso sin depender de esa sincronía.
                      if (_passwordController.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Vaciar contraseña',
                          icon: const Icon(Icons.backspace_outlined, size: 18),
                          onPressed: () {
                            _passwordController.clear();
                            setState(() {});
                          },
                        ),
                      IconButton(
                        tooltip: _obscurePassword
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ],
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa tu contraseña';
                  }
                  return null;
                },
              ),

              // Enlace de recuperación alineado a la derecha, pegado al campo al
              // que pertenece: en una pantalla de acceso, un enlace huérfano en
              // el centro se pierde.
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _handleRecuperacion,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Ingresar al sistema'),
                ),
              ),
            ],
          ),
        ),
      ),

        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Divider(color: theme.colorScheme.outline)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '¿Eres nuevo?',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Expanded(child: Divider(color: theme.colorScheme.outline)),
          ],
        ),
        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: _isLoading
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AspiranteFormScreen(),
                    ),
                  ),
          icon: const Icon(Icons.assignment_outlined, size: 18),
          label: const Text('Inscribirme como aspirante'),
        ),

        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Acceso restringido al personal autorizado',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Panel de marca: identidad institucional a la izquierda del formulario.
class _PanelMarca extends StatelessWidget {
  const _PanelMarca({this.onVolver});

  final VoidCallback? onVolver;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: IncesTheme.degradadoAzul),
      child: Stack(
        children: [
          // Círculos decorativos con muy baja opacidad. Su función es dar
          // profundidad al degradado plano, que si no se ve como un rectángulo
          // de color sin más. Al 6 % no compiten con el texto.
          Positioned(top: -60, right: -60, child: _circulo(220, 0.06)),
          Positioned(bottom: -80, left: -40, child: _circulo(260, 0.05)),
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: onVolver,
                  borderRadius: BorderRadius.circular(14),
                  child: Tooltip(
                    message: 'Volver a la portada',
                    // **El logo oficial del INCES, no un cuadrado con una «I».**
                    // Medido el 2026-10-25 con la captura de Lorenzo: el login
                    // mostraba un cuadro azul con la letra «I», que no dice nada
                    // de la institución, mientras la landing ya lucía el logo
                    // real. Los dos tienen que hablar el mismo idioma.
                    //
                    // Sin caja alrededor: el logo ya es blanco y el panel de
                    // este lado es azul, así que un fondo translúcido encima lo
                    // apaga. La altura manda y el ancho se ajusta solo, porque
                    // el archivo es horizontal (203x77).
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Image.asset(
                        'assets/images/logo_inces_blanco.png',
                        height: 44,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        semanticLabel: 'INCES',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Sistema de Gestión\nAcadémica',
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    height: 1.24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 44,
                  height: 3,
                  decoration: BoxDecoration(
                    color: IncesTheme.rojoInces,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'CFS Nacional de Soldadura\n«Rafael Urdaneta»',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'INCES La Isabelica',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 40),
                // Nota de alcance: deja claro frente a un evaluador o un
                // docente qué cubre el sistema hoy, sin prometer lo que aún no
                // existe.
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(IncesTheme.radioTarjeta),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Plataforma académica a la medida del INCES: '
                          'inscripciones, control de aulas y administración '
                          'centralizada.',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            height: 1.5,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circulo(double tamano, double opacidad) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacidad),
      ),
    );
  }
}
