import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/errors/app_exception.dart';
import '../repositories/recuperacion_repository.dart';
import '../services/auth_service.dart';
import '../theme/inces_theme.dart';

/// Canje del código de recuperación o enlace por correo (ruta `/restablecer-codigo`).
///
/// Soporta dos vías armónicas:
/// 1. Vía enlace seguro por correo (Supabase Auth o SMTP): detecta automáticamente
///    los parámetros de enlace (`code`, `token_hash`, `type=recovery`, `access_token`
///    o sesión activa) y omite por completo la solicitud de código manual,
///    permitiendo definir la nueva contraseña directamente sin confusión.
/// 2. Vía código de 12 caracteres: canjea el código emitido institucionalmente
///    por el CFS en mano o recibido por correo contra el backend.
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

class _RestablecerConCodigoScreenState
    extends State<RestablecerConCodigoScreen> {
  late final RecuperacionRepository _repo =
      widget.repositorio ?? RecuperacionRepository();
  late final AuthService _authService =
      widget.authService ?? AuthService();

  StreamSubscription<bool>? _subSesion;
  StreamSubscription<AuthState>? _subAuth;

  bool _sesionRecuperacionActiva = false;
  bool _esFlujoEnlace = false;
  bool _validandoEnlace = false;
  String? _errorEnlace;
  bool _mostrarCampoCodigoForzado = false;
  bool _codigoPrecargadoPorUrl = false;

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

  bool get _supabaseEstaInicializado {
    try {
      Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, String> _extraerParametrosUrl() {
    final params = <String, String>{};
    try {
      params.addAll(Uri.base.queryParameters);

      final fragmento = Uri.base.fragment;
      if (fragmento.isNotEmpty) {
        if (fragmento.contains('?')) {
          final partes = fragmento.split('?');
          if (partes.length > 1) {
            params.addAll(Uri.splitQueryString(partes[1]));
          }
        } else if (fragmento.contains('&') || fragmento.contains('=')) {
          final sinRuta =
              fragmento.contains('#') ? fragmento.split('#').last : fragmento;
          final limpia = sinRuta.startsWith('/') ? sinRuta.substring(1) : sinRuta;
          params.addAll(Uri.splitQueryString(limpia));
        }
      }
    } catch (_) {
      // Entorno de test o sin acceso a Uri.base
    }
    return params;
  }

  bool _detectarFlujoEnlace(Map<String, String> params) {
    if (_authService.tieneSesion) return true;
    if (params.containsKey('code')) return true;
    if (params.containsKey('token_hash')) return true;
    if (params.containsKey('access_token')) return true;
    if (params['type'] == 'recovery') return true;
    if (params.containsKey('error') || params.containsKey('error_code')) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    final params = _extraerParametrosUrl();
    _sesionRecuperacionActiva = _authService.tieneSesion;
    _esFlujoEnlace = _detectarFlujoEnlace(params);

    _subSesion = _authService.cambiosDeSesion.listen((tiene) {
      if (mounted) {
        setState(() {
          _sesionRecuperacionActiva = tiene;
          if (tiene) {
            _validandoEnlace = false;
            _errorEnlace = null;
          }
        });
      }
    });

    if (_supabaseEstaInicializado) {
      try {
        _subAuth = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
          if (data.session != null ||
              data.event == AuthChangeEvent.passwordRecovery) {
            if (mounted) {
              setState(() {
                _sesionRecuperacionActiva = true;
                _validandoEnlace = false;
                _errorEnlace = null;
              });
            }
          }
        });
      } catch (_) {}
    }

    final inicial = widget.codigoInicial?.trim();
    if (inicial != null && inicial.isNotEmpty) {
      _codigoController.text = inicial;
      _mostrarCampoCodigoForzado = true;
    } else {
      final paramCodigo = params['codigo']?.trim();
      if (paramCodigo != null && paramCodigo.isNotEmpty) {
        _codigoController.text = paramCodigo;
        _mostrarCampoCodigoForzado = true;
        _codigoPrecargadoPorUrl = true;
      }
    }

    if (_esFlujoEnlace && !_sesionRecuperacionActiva) {
      if (params.containsKey('error') || params.containsKey('error_code')) {
        _errorEnlace = params['error_description'] ??
            'El enlace de recuperación ha caducado o no es válido.';
      } else {
        _validandoEnlace = true;
        _procesarEnlaceRecuperacion(params);
      }
    }
  }

  Future<void> _procesarEnlaceRecuperacion(Map<String, String> params) async {
    if (!_supabaseEstaInicializado) {
      if (mounted) setState(() => _validandoEnlace = false);
      return;
    }

    try {
      await Supabase.instance.client.auth.getSessionFromUrl(Uri.base);
    } catch (_) {
      final authCode = params['code'];
      if (authCode != null && authCode.isNotEmpty) {
        try {
          await Supabase.instance.client.auth.exchangeCodeForSession(authCode);
        } catch (_) {
          if (mounted) {
            setState(() {
              _validandoEnlace = false;
              _errorEnlace =
                  'El enlace de recuperación es inválido o ha caducado por seguridad.';
            });
            return;
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _validandoEnlace = false;
        _sesionRecuperacionActiva = _authService.tieneSesion;
        if (!_sesionRecuperacionActiva && _errorEnlace == null) {
          _errorEnlace =
              'No se pudo verificar la sesión de recuperación. Solicita un nuevo enlace desde el inicio de sesión.';
        }
      });
    }
  }

  @override
  void dispose() {
    _subSesion?.cancel();
    _subAuth?.cancel();
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

    final bool modoEnlace = (_sesionRecuperacionActiva ||
            (_esFlujoEnlace && _errorEnlace == null)) &&
        !_mostrarCampoCodigoForzado;

    if (modoEnlace ||
        (_sesionRecuperacionActiva && _codigoController.text.trim().isEmpty)) {
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

    Widget contenido;
    if (_listo) {
      contenido = _exito(theme);
    } else if (_validandoEnlace) {
      contenido = _cargandoVerificacion(theme);
    } else if (_errorEnlace != null &&
        !_sesionRecuperacionActiva &&
        !_mostrarCampoCodigoForzado) {
      contenido = _errorEnlaceVista(theme);
    } else {
      contenido = _formulario(theme, parError);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Restablecer contraseña')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: contenido,
          ),
        ),
      ),
    );
  }

  Widget _cargandoVerificacion(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Verificando enlace de seguridad...',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Estamos validando tu enlace de recuperación para que puedas definir tu nueva contraseña de forma segura.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _errorEnlaceVista(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.link_off_rounded,
          size: 56,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          'Enlace no válido o caducado',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        Text(
          _errorEnlace ??
              'Los enlaces de recuperación caducan por motivos de seguridad.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Por seguridad institucional, los enlaces enviados por correo tienen una duración limitada (máximo 30 minutos). Puedes solicitar uno nuevo desde el portal.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/login');
            }
          },
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Solicitar nuevo enlace'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _mostrarCampoCodigoForzado = true;
              _errorEnlace = null;
            });
          },
          icon: const Icon(Icons.pin_outlined, size: 18),
          label: const Text('Ingresar código manual de 12 dígitos'),
        ),
      ],
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
    final bool modoEnlace = (_sesionRecuperacionActiva ||
            (_esFlujoEnlace && _errorEnlace == null)) &&
        !_mostrarCampoCodigoForzado;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Restablecer contraseña', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            modoEnlace
                ? 'Tu enlace de correo ha sido verificado. Ingresa y confirma tu contraseña nueva.'
                : (_codigoPrecargadoPorUrl
                    ? 'Se ha detectado el código institucional desde tu enlace. Elige tu nueva contraseña.'
                    : 'Escribe el código temporal que recibiste o que te entregó el personal del centro y elige tu contraseña nueva.'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (modoEnlace) ...[
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
          ] else if (_codigoPrecargadoPorUrl) ...[
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
                    Icons.check_circle_outline,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Código institucional pre-cargado: ${_codigoController.text}',
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
            const SizedBox(height: 16),
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
                if (modoEnlace) {
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
            autofocus: modoEnlace || _codigoPrecargadoPorUrl,
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
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
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
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: parError.texto,
                      ),
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
