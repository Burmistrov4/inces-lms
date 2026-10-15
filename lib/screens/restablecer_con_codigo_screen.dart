import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/errors/app_exception.dart';
import '../repositories/recuperacion_repository.dart';
import '../services/auth_service.dart';
import '../theme/inces_theme.dart';

/// Canje del código de recuperación o enlace por correo (ruta `/restablecer-codigo`).
///
/// Soporta dos vías armónicas:
/// 1. Vía enlace seguro por correo (Supabase Auth o SMTP): detecta la sesión
///    activa de recuperación y permite definir la nueva contraseña directamente.
/// 2. Vía código de 12 caracteres: canjea el código emitido institucionalmente
///    por el CFS o recibido por correo contra el backend.
class RestablecerConCodigoScreen extends StatefulWidget {
  const RestablecerConCodigoScreen({
    super.key,
    this.repositorio,
    this.authService,
    this.codigoInicial,
  });

  /// Inyectable para las pruebas.
  final RecuperacionRepository? repositorio;
  final AuthService? authService;

  /// Código opcional pre-rellenado (por ejemplo desde el modal o enlace de correo).
  final String? codigoInicial;

  @override
  State<RestablecerConCodigoScreen> createState() =>
      _RestablecerConCodigoScreenState();
}

class _RestablecerConCodigoScreenState extends State<RestablecerConCodigoScreen> {
  late final RecuperacionRepository _repo =
      widget.repositorio ?? RecuperacionRepository();
  late final AuthService _authService =
      widget.authService ?? AuthService();

  StreamSubscription<bool>? _subSesion;
  bool _sesionRecuperacionActiva = false;
  bool _mostrarCampoCodigoForzado = false;

  final _formKey = GlobalKey<FormState>();
  final _codigoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _repetirController = TextEditingController();
  final _codigoFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _repetirFocus = FocusNode();

  bool _isLoading = false;
  bool _obscure = true;
  String? _error;
  bool _listo = false;

  @override
  void initState() {
    super.initState();
    _sesionRecuperacionActiva = _authService.tieneSesion;
    _subSesion = _authService.cambiosDeSesion.listen((tiene) {
      if (mounted && tiene != _sesionRecuperacionActiva) {
        setState(() {
          _sesionRecuperacionActiva = tiene;
        });
      }
    });

    final inicial = widget.codigoInicial?.trim();
    if (inicial != null && inicial.isNotEmpty) {
      _codigoController.text = inicial;
      _mostrarCampoCodigoForzado = true;
    } else {
      final paramUrl = Uri.base.queryParameters['codigo']?.trim();
      if (paramUrl != null && paramUrl.isNotEmpty) {
        _codigoController.text = paramUrl;
        _mostrarCampoCodigoForzado = true;
      }
    }
  }

  @override
  void dispose() {
    _subSesion?.cancel();
    _codigoController.dispose();
    _passwordController.dispose();
    _repetirController.dispose();
    _codigoFocus.dispose();
    _passwordFocus.dispose();
    _repetirFocus.dispose();
    super.dispose();
  }

  Future<void> _canjear() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    if (_sesionRecuperacionActiva &&
        !_mostrarCampoCodigoForzado &&
        _codigoController.text.trim().isEmpty) {
      final res = await _authService.restablecerPassword(
        _passwordController.text,
      );
      if (mounted) setState(() => _isLoading = false);
      if (!mounted) return;

      res.when(
        success: (_) => setState(() => _listo = true),
        failure: (AppException fallo) => setState(() => _error = fallo.message),
      );
      return;
    }

    final resultado = await _repo.canjearCodigo(
      codigo: _codigoController.text,
      password: _passwordController.text,
    );

    // El estado de carga se libera ANTES de comprobar `mounted`: al revés, un
    // desmontaje durante la petición dejaría el botón bloqueado para siempre.
    if (mounted) setState(() => _isLoading = false);
    if (!mounted) return;

    resultado.when(
      success: (_) => setState(() => _listo = true),
      failure: (AppException fallo) => setState(() => _error = fallo.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parError = PaletaInces.de(context).etiquetaDe(TonoEstado.error);

    return Scaffold(
      appBar: AppBar(title: const Text('Restablecer contraseña')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: _listo ? _exito(theme) : _formulario(theme, parError),
          ),
        ),
      ),
    );
  }

  Widget _exito(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.check_circle_outline, size: 56, color: IncesTheme.exito),
        const SizedBox(height: 16),
        Text(
          'Contraseña actualizada',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        Text(
          'Ya puedes iniciar sesión con tu contraseña nueva. Por seguridad, se '
          'cerraron las sesiones que estuvieran abiertas.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/login');
            }
          },
          child: const Text('Ir a iniciar sesión'),
        ),
      ],
    );
  }

  Widget _formulario(ThemeData theme, ParDeEtiqueta parError) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Restablecer contraseña', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            _sesionRecuperacionActiva && !_mostrarCampoCodigoForzado
                ? 'Tu enlace de correo ha sido verificado. Ingresa y confirma tu contraseña nueva.'
                : 'Escribe el código temporal que recibiste o que te entregó el personal del centro y elige tu contraseña nueva.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (_sesionRecuperacionActiva && !_mostrarCampoCodigoForzado) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(IncesTheme.radioControl),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Enlace de recuperación verificado por correo. Puedes definir tu nueva contraseña directamente.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _mostrarCampoCodigoForzado = true;
                  });
                },
                icon: const Icon(Icons.pin_outlined, size: 16),
                label: const Text('¿Prefieres usar un código manual de 12 dígitos?'),
              ),
            ),
            const SizedBox(height: 8),
          ] else ...[
            TextFormField(
              controller: _codigoController,
              focusNode: _codigoFocus,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
              style: theme.textTheme.bodyMedium,
              decoration: const InputDecoration(
                labelText: 'Código de recuperación',
                prefixIcon: Icon(Icons.key_outlined, size: 20),
                hintText: 'ABCD-EFGH-JKMN',
              ),
              validator: (valor) {
                if (_sesionRecuperacionActiva && !_mostrarCampoCodigoForzado) {
                  return null;
                }
                final limpio = (valor ?? '').replaceAll(RegExp(r'[\s-]'), '');
                if (limpio.isEmpty) return 'Escribe el código que te entregaron.';
                if (limpio.length < 8) return 'El código está incompleto.';
                return null;
              },
            ),
            if (_sesionRecuperacionActiva) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _mostrarCampoCodigoForzado = false;
                      _codigoController.clear();
                    });
                  },
                  child: const Text('Volver a verificación por enlace de correo'),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _repetirFocus.requestFocus(),
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              labelText: 'Contraseña nueva',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (valor) {
              final texto = valor ?? '';
              if (texto.isEmpty) return 'Elige una contraseña.';
              if (texto.length < 8) {
                return 'Usa al menos 8 caracteres.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _repetirController,
            focusNode: _repetirFocus,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _canjear(),
            style: theme.textTheme.bodyMedium,
            decoration: const InputDecoration(
              labelText: 'Repite la contraseña',
              prefixIcon: Icon(Icons.lock_outline, size: 20),
            ),
            validator: (valor) {
              if ((valor ?? '').isEmpty) return 'Repite la contraseña.';
              if (valor != _passwordController.text) {
                return 'Las contraseñas no coinciden.';
              }
              return null;
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: parError.fondo,
                borderRadius: BorderRadius.circular(IncesTheme.radioControl),
                border: Border.all(color: parError.texto.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: parError.texto, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: GoogleFonts.inter(fontSize: 13, color: parError.texto),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 46,
            child: FilledButton(
              onPressed: _isLoading ? null : _canjear,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Cambiar contraseña'),
            ),
          ),
        ],
      ),
    );
  }
}
