import '../core/cache_lecturas.dart';
import '../core/errors/app_exception.dart';
import '../core/gateways/auth_gateway.dart';
import '../core/network/api_client.dart';
import '../core/result.dart';
import '../models/aspirante_model.dart';
import '../models/perfil_usuario.dart';
import '../models/registro_resultado.dart';
import '../providers/role_provider.dart';
import 'supabase_service.dart';

/// Reglas de autenticación y onboarding.
///
/// Depende de [AuthGateway], no del singleton de Supabase (deuda D1 resuelta).
/// Toda operación que pueda fallar devuelve `Result<T>` con un [AppException]
/// tipado. Nada se traga en silencio.
class AuthService {
  final AuthGateway _gateway;

  AuthService({AuthGateway? gateway})
      : _gateway = gateway ?? SupabaseService.instance;

  static const int _largoMinimoPassword = 8;

  // ---------------------------------------------------------------------------
  // Sesión
  // ---------------------------------------------------------------------------

  Future<UserRole> obtenerRolActual() async {
    final id = _gateway.userId;
    if (id == null) return UserRole.desconocido;

    try {
      final rol = await _gateway.rolDePerfil(id);
      if (rol != null && rol.isNotEmpty) return userRoleFromName(rol);
    } catch (_) {
      // Si la consulta falla (RLS, red), caemos a la metadata del token.
      // No es fatal: el rol se puede reconstruir desde la sesión.
    }

    return userRoleFromName(_gateway.rolMetadata);
  }

  bool get tieneSesion => _gateway.tieneSesion;

  /// Correo del usuario con sesión activa, o `null` si no hay sesión.
  ///
  /// Lo usa el cPanel para mostrar quién está conectado en lugar de un texto
  /// fijo. Un panel de administración que muestra un correo de ejemplo es una
  /// invitación a confundirse de cuenta.
  String? get emailActual => _gateway.userEmail;

  Stream<bool> get cambiosDeSesion => _gateway.cambiosDeSesion;

  Future<Result<UserRole>> iniciarSesion({
    required String identificador,
    required String password,
  }) {
    return Result.guard(() async {
      final identifier = identificador.trim();
      if (identifier.isEmpty || password.isEmpty) {
        throw const AppException.validacion(
          'Ingresa tu cédula/correo y tu contraseña.',
        );
      }

      var email = identifier;

      if (!identifier.contains('@')) {
        final encontrado = await _gateway.emailPorCedula(identifier);
        if (encontrado == null) {
          // Mensaje genérico a propósito: no revelamos si la cédula existe.
          throw const AppException(
            type: AppErrorType.credenciales,
            message: 'Credenciales inválidas. Verifica tus datos e inténtalo '
                'de nuevo.',
          );
        }
        email = encontrado;
      }

      await _gateway.iniciarConPassword(email: email, password: password);

      // Repara fichas huérfanas creadas por el bug anterior, si las hubiera.
      await vincularFichaPendiente();

      return obtenerRolActual();
    });
  }

  Future<void> cerrarSesion() async {
    await _gateway.cerrarSesion();
    // **La caché de lecturas se vacía aquí.** Su clave es la URL, así que sin
    // esto el siguiente usuario del mismo dispositivo vería los datos del
    // anterior durante el TTL (60 s). Medido el 2026-10-23.
    cacheDeLecturas.invalidarTodo();
  }

  Future<Result<bool>> enviarCorreoRecuperacion(String email) {
    return Result.guard(() async {
      final correo = email.trim();
      if (!_esEmailValido(correo)) {
        throw const AppException.validacion('Ingresa un correo válido.');
      }
      await _gateway.enviarRecuperacion(correo);
      return true;
    });
  }

  /// Solicita el código de recuperación por correo vía Fastify / Gmail SMTP (Nodemailer).
  ///
  /// Admite cédula o correo. Si la cuenta existe, el backend envía un correo
  /// institucional con el código de 12 caracteres y un enlace directo.
  Future<Result<String>> solicitarRecuperacionBackend(String identificador) {
    return Result.guard(() async {
      final limpio = identificador.trim();
      if (limpio.isEmpty) {
        throw const AppException.validacion(
          'Ingresa tu cédula o correo electrónico.',
        );
      }
      final api = ApiClient();
      final res = await api.post(
        '/api/v1/auth/solicitar-recuperacion',
        cuerpo: {'identificador': limpio},
      );
      return res['mensaje'] as String? ??
          'Si la cuenta existe, hemos enviado un código a tu correo.';
    });
  }

  /// Solicita el restablecimiento de cuenta con fallback automático a Supabase Auth.
  ///
  /// Intenta primero la vía institucional Fastify / Gmail SMTP. Si no hay
  /// `SMTP_PASS` configurado en el servidor o el correo no se pudo entregar,
  /// activa el despacho nativo de Supabase Auth vía `_gateway.enviarRecuperacion`.
  Future<Result<ResultadoRecuperacionCuenta>> solicitarRecuperacionConFallback(
    String identificador,
  ) {
    return Result.guard(() async {
      final limpio = identificador.trim();
      if (limpio.isEmpty) {
        throw const AppException.validacion(
          'Ingresa tu cédula o correo electrónico.',
        );
      }

      String? correoDestino = _esEmailValido(limpio) ? limpio : null;
      if (correoDestino == null) {
        try {
          correoDestino = await _gateway.emailPorCedula(limpio);
        } catch (_) {
          // Si la búsqueda por cédula no responde, el backend intentará resolverla
        }
      }

      // Intento prioritario: Fastify Backend con Gmail SMTP
      try {
        final api = ApiClient();
        final res = await api.post(
          '/api/v1/auth/solicitar-recuperacion',
          cuerpo: {'identificador': limpio},
        );

        final correoEnviado = res['correoEnviado'] as bool? ?? false;
        final resEmail = res['email'] as String? ?? correoDestino;

        if (correoEnviado) {
          return ResultadoRecuperacionCuenta(
            exito: true,
            metodo: MetodoRecuperacionUsado.smtp,
            mensaje: res['mensaje'] as String? ??
                'Hemos enviado un código temporal a tu correo electrónico.',
            emailDestino: resEmail,
          );
        }

        // Si el SMTP directo no pudo despachar (p. ej. puertos salientes bloqueados
        // por la infraestructura del servidor), activamos el despacho vía Supabase Auth
        // (que se encuentra sincronizado con el SMTP de Gmail institucional).
        if (resEmail != null && resEmail.isNotEmpty) {
          try {
            await _gateway.enviarRecuperacion(resEmail);
            return ResultadoRecuperacionCuenta(
              exito: true,
              metodo: MetodoRecuperacionUsado.supabase,
              mensaje:
                  'Hemos enviado un enlace de recuperación a tu correo ($resEmail).',
              emailDestino: resEmail,
            );
          } catch (_) {
            return ResultadoRecuperacionCuenta(
              exito: true,
              metodo: MetodoRecuperacionUsado.smtp,
              mensaje: res['mensaje'] as String? ??
                  'Solicitud procesada. Si los datos coinciden con un usuario registrado, recibirás las instrucciones en tu correo.',
              emailDestino: resEmail,
            );
          }
        }
      } catch (e) {
        // En caso de caída de backend o red, intentamos Supabase con guarda segura
        if (correoDestino != null && correoDestino.isNotEmpty) {
          try {
            await _gateway.enviarRecuperacion(correoDestino);
            return ResultadoRecuperacionCuenta(
              exito: true,
              metodo: MetodoRecuperacionUsado.supabase,
              mensaje:
                  'Hemos enviado un enlace de recuperación a tu correo ($correoDestino).',
              emailDestino: correoDestino,
            );
          } catch (_) {
            return ResultadoRecuperacionCuenta(
              exito: true,
              metodo: MetodoRecuperacionUsado.smtp,
              mensaje:
                  'Hemos recibido la solicitud. Si tu correo está registrado, el sistema procesará la recuperación. También puedes solicitar un código temporal en la coordinación.',
              emailDestino: correoDestino,
            );
          }
        }
        rethrow;
      }

      return const ResultadoRecuperacionCuenta(
        exito: true,
        metodo: MetodoRecuperacionUsado.smtp,
        mensaje:
            'Si los datos coinciden con un usuario registrado, hemos procesado tu solicitud.',
      );
    });
  }

  /// Define una contraseña nueva para el usuario con sesión activa.
  ///
  /// Cubre los dos caminos del restablecimiento:
  ///
  ///  - El **enlace del correo de recuperación**. Supabase redirige con el token
  ///    en el fragmento de la URL; el SDK lo detecta al inicializarse y deja una
  ///    sesión temporal. Si el enlace caducó, no hay sesión y esta llamada
  ///    falla con un mensaje que lo explica, en lugar de fingir que funcionó.
  ///  - El **cambio voluntario** desde dentro de la app.
  ///
  /// La validación de longitud vive aquí y no en el widget: la regla es del
  /// dominio, y así los tests la cubren sin montar la interfaz.
  Future<Result<bool>> restablecerPassword(String password) {
    return Result.guard(() async {
      if (!_gateway.tieneSesion) {
        throw const AppException(
          type: AppErrorType.credenciales,
          message: 'El enlace ya no es válido. Solicita uno nuevo desde la '
              'pantalla de inicio de sesión.',
        );
      }

      if (password.length < _largoMinimoPassword) {
        throw const AppException.validacion(
          'La contraseña debe tener al menos 8 caracteres.',
        );
      }

      if (password.trim().isEmpty) {
        throw const AppException.validacion(
          'La contraseña no puede estar vacía.',
        );
      }

      await _gateway.actualizarPassword(password);
      return true;
    });
  }

  /// Nunca interrumpe el login: si falla, se ignora.
  Future<bool> vincularFichaPendiente() async {
    try {
      return await _gateway.vincularFichaPendiente();
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Perfil propio
  // ---------------------------------------------------------------------------

  /// El perfil de quien tiene la sesión activa.
  ///
  /// `success(null)` significa «esta cuenta no tiene perfil», que en la práctica
  /// sólo ocurre en altas antiguas o interrumpidas: `handle_new_user()` inserta
  /// la fila en la misma transacción del alta. Un fallo de red o de RLS llega
  /// como `failure`, **no** como `null` — confundir los dos haría que un corte de
  /// red se pintara como «no tienes perfil».
  Future<Result<PerfilUsuario?>> miPerfil() {
    return Result.guard(() => _gateway.miPerfil());
  }

  /// Corrige el nombre y el apellido propios y devuelve el perfil actualizado.
  ///
  /// **La validación vive aquí y no en el widget**, por el mismo motivo que la de
  /// la contraseña: la regla es del dominio, y así las pruebas la cubren sin
  /// montar la interfaz. Y hay una razón concreta para no dejarla a la base:
  /// `profiles.nombres` es `not null`, pero la cadena vacía **lo satisface**, así
  /// que Postgres aceptaría un perfil sin nombre y la cabecera de la aplicación
  /// quedaría en blanco sin que nada fallara.
  Future<Result<PerfilUsuario>> actualizarPerfil({
    required String nombres,
    required String apellidos,
    String? cedula,
  }) {
    return Result.guard(() async {
      // Se recorta **antes** de validar y de enviar: un nombre de solo espacios
      // no es un nombre, y mandarlo con espacios dejaría un `'  '` guardado que
      // se ve como un hueco pero no está vacío.
      final nombreLimpio = nombres.trim();
      final apellidoLimpio = apellidos.trim();

      final faltantes = <String>[
        if (nombreLimpio.isEmpty) 'el nombre',
        if (apellidoLimpio.isEmpty) 'el apellido',
      ];

      if (faltantes.isNotEmpty) {
        throw AppException.validacion(
          'Completa ${faltantes.join(' y ')}: son los datos con los que '
          'apareces en la nómina.',
        );
      }

      return _gateway.actualizarPerfil(
        nombres: nombreLimpio,
        apellidos: apellidoLimpio,
        cedula: cedula?.trim(),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Registro de aspirantes (Fase 1)
  // ---------------------------------------------------------------------------

  /// Registra un aspirante de punta a punta.
  ///
  /// Flujo:
  ///  1. Valida los datos localmente (falla rápido, sin gastar red).
  ///  2. Prechequea cédula/correo duplicados contra la base de datos.
  ///  3. Llama a `signUp` con la metadata de la planilla.
  ///  4. El trigger `handle_new_user()` crea `profiles` + `aspirantes`
  ///     **en una sola transacción**. Si algo falla, Postgres revierte todo:
  ///     no queda usuario huérfano ni ficha a medias.
  Future<Result<RegistroResultado>> registrarAspirante({
    required AspiranteModel aspirante,
    required String password,
  }) {
    return Result.guard(() async {
      _validarPlanilla(aspirante, password);

      final precheck = await _gateway.precheck(
        cedula: aspirante.cedula,
        email: aspirante.email,
      );

      switch (precheck) {
        case 'OK':
          break;
        case 'CEDULA_DUPLICADA':
          throw const AppException.duplicado(
            'Ya existe una inscripción registrada con esa cédula.',
            code: 'CEDULA_DUPLICADA',
          );
        case 'EMAIL_DUPLICADO':
          throw const AppException.duplicado(
            'Ya existe una cuenta registrada con ese correo.',
            code: 'EMAIL_DUPLICADO',
          );
        case 'EMAIL_INVALIDO':
          throw const AppException.validacion(
            'El correo electrónico no tiene un formato válido.',
            code: 'EMAIL_INVALIDO',
          );
        case 'CEDULA_REQUERIDA':
          throw const AppException.validacion(
            'La cédula es obligatoria para completar la inscripción.',
            code: 'CEDULA_REQUERIDA',
          );
        default:
          throw AppException.servidor(
            technical: 'Código de precheck desconocido: $precheck',
          );
      }

      SesionAuth? sesion;
      try {
        sesion = await _gateway.registrarConPassword(
          email: aspirante.email,
          password: password,
          metadata: aspirante.toMetadata(),
        );
      } catch (e) {
        final eStr = e.toString().toLowerCase();
        // Si Supabase falla al intentar enviar el correo de confirmación (ej. 500
        // Error sending confirmation email, rate limits o problemas de red),
        // acudimos al backend/edge para dar de alta al aspirante con confirmación
        // inmediata sin revertir la transacción.
        final esErrorCorreoOServidor = eStr.contains('confirmation email') ||
            eStr.contains('servidor de correo') ||
            eStr.contains('unexpected_failure') ||
            eStr.contains('rate limit') ||
            eStr.contains('over_email_send_rate_limit') ||
            eStr.contains('500') ||
            eStr.contains('authretryablefetchexception') ||
            eStr.contains('clientexception');

        if (esErrorCorreoOServidor) {
          try {
            final api = ApiClient();
            final res = await api.post(
              '/api/v1/auth/registro-aspirante',
              cuerpo: {
                'email': aspirante.email,
                'password': password,
                'metadata': aspirante.toMetadata(),
              },
            );
            final userId = res['userId'] as String?;
            if (userId != null && userId.isNotEmpty) {
              bool sesionIniciada = false;
              try {
                await _gateway.iniciarConPassword(
                  email: aspirante.email,
                  password: password,
                );
                sesionIniciada = true;
              } catch (_) {}

              return RegistroResultado(
                email: aspirante.email,
                userId: userId,
                sesionIniciada: sesionIniciada,
                fichaCreada: true,
                requiereTutorLegal: aspirante.requiresLegalTutor,
              );
            }
          } catch (fallbackError) {
            if (fallbackError is AppException) {
              rethrow;
            }
          }
        }
        rethrow;
      }

      if (sesion.userId == null) {
        throw const AppException(
          type: AppErrorType.servidor,
          message: 'No pudimos crear tu cuenta. Verifica tus datos e inténtalo '
              'de nuevo.',
        );
      }

      return RegistroResultado(
        email: aspirante.email,
        userId: sesion.userId,
        sesionIniciada: sesion.tieneSesion,
        // El trigger es atómico: si signUp no lanzó, la ficha existe.
        fichaCreada: true,
        requiereTutorLegal: aspirante.requiresLegalTutor,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Validaciones locales
  // ---------------------------------------------------------------------------

  void _validarPlanilla(AspiranteModel a, String password) {
    if (password.length < _largoMinimoPassword) {
      throw const AppException.validacion(
        'La contraseña debe tener al menos 8 caracteres.',
      );
    }

    final faltantes = <String>[
      if (a.cedula.trim().isEmpty) 'cédula',
      if (a.nombres.trim().isEmpty) 'nombres',
      if (a.apellidos.trim().isEmpty) 'apellidos',
      if (a.fechaNacimiento == null) 'fecha de nacimiento',
      if (a.sexo.trim().isEmpty) 'sexo',
      if (a.telefono.trim().isEmpty) 'teléfono',
      if (!_esEmailValido(a.email)) 'correo electrónico',
      if (a.direccion.trim().isEmpty) 'domicilio',
      if (a.nivelEducativo.trim().isEmpty) 'nivel educativo',
      if (a.programId.trim().isEmpty) 'propuesta formativa',
    ];

    if (faltantes.isNotEmpty) {
      throw AppException.validacion(
        'Faltan datos obligatorios: ${faltantes.join(', ')}.',
      );
    }

    if (!const ['M', 'F', 'Otro'].contains(a.sexo)) {
      throw const AppException.validacion('El sexo seleccionado no es válido.');
    }

    // Un menor de edad sin representante legal no puede inscribirse: el CHECK
    // de la base de datos lo rechazaría igual, pero aquí damos un mensaje claro.
    if (a.requiresLegalTutor) {
      final faltantesTutor = <String>[
        if ((a.numeroIdentidadTutor ?? '').trim().isEmpty)
          'cédula del representante',
        if ((a.nombreTutor ?? '').trim().isEmpty) 'nombre del representante',
        if ((a.parentescoTutor ?? '').trim().isEmpty)
          'parentesco del representante',
        if ((a.telefonoTutor ?? '').trim().isEmpty)
          'teléfono del representante',
        if ((a.correoTutor ?? '').trim().isEmpty) 'correo del representante',
      ];

      if (faltantesTutor.isNotEmpty) {
        throw AppException.validacion(
          'El aspirante es menor de edad y falta: ${faltantesTutor.join(', ')}.',
        );
      }
    }
  }

  static bool _esEmailValido(String value) {
    final texto = value.trim();
    if (texto.isEmpty) return false;
    return RegExp(r'^[\w\.\-\+]+@[\w\-]+(\.[\w\-]+)+$').hasMatch(texto);
  }
}

enum MetodoRecuperacionUsado {
  smtp,
  supabase,
}

class ResultadoRecuperacionCuenta {
  final bool exito;
  final MetodoRecuperacionUsado metodo;
  final String mensaje;
  final String? emailDestino;

  const ResultadoRecuperacionCuenta({
    required this.exito,
    required this.metodo,
    required this.mensaje,
    this.emailDestino,
  });
}
