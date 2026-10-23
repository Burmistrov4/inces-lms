import 'dart:async';

import 'package:flutter/material.dart';
// Localización en español de los widgets de Material (selector de fecha,
// diálogos, tooltips). Es un paquete del SDK de Flutter (`sdk: flutter`), no
// una dependencia de pub: lo resuelve `flutter pub get` desde el SDK.
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/gateways/preferencias_tema.dart';
import 'core/navegacion.dart';
import 'core/network/api_client.dart';
import 'providers/role_provider.dart';
import 'providers/tema_provider.dart';
import 'repositories/aspirante_repository.dart';
import 'screens/admin_dashboard.dart';
import 'screens/aspirante_dashboard.dart';
import 'screens/aspirante_form_screen.dart';
import 'screens/docente_dashboard.dart';
import 'screens/landing_page.dart';
import 'screens/login_screen.dart';
import 'screens/restablecer_con_codigo_screen.dart';
import 'screens/activar_cuenta_screen.dart';
import 'services/auth_service.dart';
import 'theme/inces_theme.dart';

SupabaseClient get supabase => Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Un fallo de configuración de compilación (p. ej. el bundle se compiló sin
  // `--dart-define-from-file=.env.json`) no debe quedar como una excepción sin
  // capturar en la consola: se muestra una pantalla clara con la causa. Es la
  // diferencia entre «la app se rompió» y «la app te dice qué falta».
  try {
    AppConfig.validate();
    unawaited(ApiClient.calentarBackend());

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  } catch (e) {
    runApp(_PantallaFalloArranque(mensaje: _mensajeFalloArranque(e)));
    return;
  }

  runApp(const IncesLmsApp());
}

/// Convierte cualquier error de arranque en un texto legible para el usuario.
String _mensajeFalloArranque(Object error) {
  final texto = error.toString();
  if (texto.contains('SUPABASE_URL')) {
    return 'Falta la configuración del servidor (SUPABASE_URL). Recompila la '
        'aplicación con:\n\n'
        'flutter build web --release --dart-define-from-file=.env.json\n\n'
        '(o define SUPABASE_URL y SUPABASE_ANON_KEY al compilar).';
  }
  if (texto.contains('SUPABASE_ANON_KEY')) {
    return 'Falta la clave pública de Supabase (SUPABASE_ANON_KEY). Recompila '
        'con --dart-define-from-file=.env.json.';
  }
  return 'La aplicación no pudo iniciar:\n\n$texto';
}

/// Pantallas alcanzables por nombre de ruta, indexadas por **camino**.
///
/// La activación de docentes no está aquí a propósito: necesita el token del
/// enlace, y los constructores de esta tabla sólo reciben el `BuildContext`.
/// Se resuelve aparte en [_generarRuta].
final Map<String, WidgetBuilder> _pantallas = {
  '/login': (_) => const LoginScreen(),
  '/auth/login': (_) => const LoginScreen(), // Alias defensivo para enlaces externos
  '/inscripcion': (_) => const AspiranteFormScreen(),
  '/restablecer': (_) => const RestablecerConCodigoScreen(),
  // Canje del código temporal institucional o enlace por correo.
  '/restablecer-codigo': (_) => const RestablecerConCodigoScreen(),
};

/// Resuelve una ruta a partir de su nombre.
///
/// Existe porque la tabla `routes` compara cadenas **exactas**: un enlace
/// profundo llega con la consulta pegada (`/auth/activate?token=…`) y no
/// encuentra destino. Cuando eso pasaba, el `Navigator` descartaba la pila
/// inicial entera y mostraba `/`, así que el docente abría el enlace del correo
/// y aterrizaba en el login: el token nunca llegaba a la pantalla.
///
/// Devuelve `null` para las rutas desconocidas **a propósito**. Al expandir un
/// enlace de varios segmentos, `Navigator` pide `/`, `/auth` y
/// `/auth/activate`; los intermedios que no existen deben quedarse en `null`
/// para que se filtren en vez de ensuciar el historial.
Route<dynamic>? _generarRuta(RouteSettings ajustes) {
  final destino = analizarRuta(ajustes.name);

  if (destino.ruta == rutaActivacion) {
    return MaterialPageRoute<dynamic>(
      settings: ajustes,
      builder: (_) => ActivarCuentaScreen(token: destino.token),
    );
  }

  final pantalla = _pantallas[destino.ruta];
  if (pantalla == null) return null;

  return MaterialPageRoute<dynamic>(settings: ajustes, builder: pantalla);
}

class IncesLmsApp extends StatelessWidget {
  const IncesLmsApp({
    super.key,
    this.rutaInicial,
    this.landingRepository,
    this.preferenciasTema,
  });

  /// Ruta con la que arranca la aplicación.
  ///
  /// En web la fija la URL del navegador, así que la app real no pasa nada. Se
  /// expone para poder abrir la aplicación en un enlace profundo concreto desde
  /// las pruebas, que no tienen navegador.
  final String? rutaInicial;

  /// Repositorio que usará la portada pública para leer la oferta formativa.
  ///
  /// Se expone sólo para las pruebas: sin él, montar la app en un test dispara
  /// una consulta real a Supabase desde la portada. En producción va `null` y la
  /// portada resuelve su propio repositorio.
  final AspiranteRepository? landingRepository;

  /// Almacén donde se recuerda el tema que eligió el usuario.
  ///
  /// Se expone sólo para las pruebas, por el mismo motivo que
  /// [landingRepository]: sin él, montar la aplicación en un test crea el
  /// proveedor de tema contra el almacenamiento real, que en la VM de
  /// `flutter test` no tiene plugin detrás. En producción va `null` y se usa el
  /// del dispositivo.
  final PreferenciasTema? preferenciasTema;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RoleProvider()),
        ChangeNotifierProvider(
          // `..cargar()`: la lectura de la preferencia es asíncrona y nadie
          // puede esperarla desde `create`. Mientras llega, el proveedor ya vale
          // `ThemeMode.system`, así que la aplicación arranca con el tema de
          // siempre y sólo cambia si había algo guardado.
          //
          // `preferenciasTema` se pasa tal cual, sin `??`: resolver el valor por
          // defecto es del proveedor, que es el único que tiene que saber cuál es
          // el almacén de producción. Aquí `null` significa «el de siempre».
          create: (_) => TemaProvider(preferencias: preferenciasTema)..cargar(),
        ),
      ],
      // `builder` y no `child`: `themeMode` **depende** del valor del proveedor,
      // así que no puede ser un hijo constante que se construye una vez.
      // `MultiProvider` envuelve este `builder` en un `Builder` colocado **por
      // dentro** de los proveedores —lo hace él mismo, ver su constructor—, que
      // es justo el contexto que hace falta para poder mirarlos.
      builder: (context, _) {
        // Una sola lectura del proveedor de tema en este `build`, y no
        // `read`+`watch` a la vez: `provider` exige un modo único por elemento y
        // por build, y mezclarlos lanza.
        //
        // Aquí la lectura es **no nulable** porque este mismo widget acaba de
        // crear el proveedor: está garantizado. En los paneles, en cambio, se
        // lee como nulable, porque allí sí puede faltar (ver `andamiaje.dart`).
        final tema = context.watch<TemaProvider>();
        return MaterialApp(
          title: 'INCES LMS — Sistema de Gestión Académica',
          debugShowCheckedModeBanner: false,

          // **Física de scroll única para todo el sistema.** Sin esto, cada
          // plataforma estira su propio comportamiento: el móvil rebota como
          // goma, el escritorio dibuja un resplandor azul al pasar del límite,
          // y rueda el ratón a distinta velocidad según el widget. Ninguna de
          // las tres es un defecto grave, pero las tres juntas hacen que la app
          // se sienta como tres aplicaciones distintas.
          //
          // La elección: rebote suave con **amortiguación**, que es lo que usan
          // las apps de Google en el móvil, y overscroll invisible en
          // escritorio —donde el resplandor de Material se lee como un error
          // visual—. Un solo sitio, efecto en los 143 archivos.
          scrollBehavior: const _ScrollSuaveInces(),

          // Localización en español, registrada una sola vez aquí. Sin estos
          // delegados, `MaterialApp` sólo cargaba la localización por defecto
          // (inglés): el selector de fecha del formulario de inscripción
          // mostraba el calendario con meses y botones en inglés
          // (`CANCEL`/`SAVE`), y `helpText` salía sin traducir. La dirección es
          // `MaterialApp` → delegados → `supportedLocales`: los widgets de
          // Material ya resuelven sus textos por `Localizations.of` contra el
          // ambiente, así que **no** hace falta pasar `locale` en cada
          // `showDatePicker`. Pedirlo sin tenerlos registrados lanzaría en
          // tiempo de ejecución («locale was not specified»/delegado ausente),
          // que es justo lo que explicaba el comentario que antes vivía en
          // `campo_planilla.dart`.
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('es')],
          locale: const Locale('es'),

          // El tema se delega en `IncesTheme`. Tenerlo centralizado es lo que
          // impide que cada pantalla vuelva a inventarse sus propios colores, que
          // es exactamente lo que pasó antes: el login era `#0F172A` y los paneles
          // también, pero con azules distintos, y la aplicación no se leía como un
          // solo producto.
          theme: IncesTheme.claro(),
          darkTheme: IncesTheme.oscuro(),

          // `system` por defecto, que es lo que hacía la aplicación antes de que
          // el usuario pudiera elegir. El valor real llega del proveedor.
          themeMode: tema.modo,

          // `home` define la ruta raíz. Por eso NO se incluye '/' en `routes`:
          // Flutter lanza una aserción si ambos existen y la app no arranca.
          home: AuthGate(landingRepository: landingRepository),
          initialRoute: rutaInicial,

          // Las rutas simples se resuelven por tabla exacta. El deep link del
          // docente invitado (`/auth/activate?token=…`) pasa por `_generarRuta`,
          // que sí sabe leer la consulta. Al abrirse por URL, esa pantalla queda
          // encima del `AuthGate`: el docente todavía no tiene sesión, y el botón
          // de volver tiene un destino sensato.
          routes: _pantallas,
          onGenerateRoute: _generarRuta,
        );
      },
    );
  }
}

/// Decide qué mostrar según la sesión y el rol del usuario.
///
/// Escucha `onAuthStateChange`, así que al registrarse o iniciar sesión la
/// pantalla cambia sola: no hace falta navegar manualmente.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.landingRepository});

  /// Repositorio de la portada pública, sólo para pruebas (ver [IncesLmsApp]).
  final AspiranteRepository? landingRepository;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<bool>? _authSubscription;
  StreamSubscription<AuthState>? _recuperacionSubscription;
  final AuthService _authService = AuthService();
  bool _isInitializing = true;

  /// `true` mientras el usuario llega desde el enlace del correo de
  /// recuperación. Tiene **prioridad sobre el rol**: hay una sesión válida, pero
  /// es temporal y su único propósito es cambiar la contraseña. Si no se
  /// intercepta, el enrutado por rol lo llevaría al dashboard sin dejarlo
  /// completar el trámite.
  bool _enRecuperacion = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = _authService.cambiosDeSesion.listen(_onSesionCambia);
    _recuperacionSubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((estado) {
      if (estado.event == AuthChangeEvent.passwordRecovery) {
        if (mounted) setState(() => _enRecuperacion = true);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarRol());
  }

  Future<void> _cargarRol() async {
    if (!mounted) return;

    final roleProvider = context.read<RoleProvider>();
    roleProvider.setLoading(true);

    final role = await _authService.obtenerRolActual();

    if (!mounted) return;
    roleProvider.setRole(role);
    roleProvider.setLoading(false);
    setState(() => _isInitializing = false);
  }

  Future<void> _onSesionCambia(bool autenticado) async {
    if (!autenticado) {
      if (!mounted) return;
      context.read<RoleProvider>().reset();
      setState(() => _isInitializing = false);
      return;
    }

    await _cargarRol();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _recuperacionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roleProvider = context.watch<RoleProvider>();

    if (_isInitializing || roleProvider.isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: IncesTheme.degradadoAzul,
                  borderRadius: BorderRadius.circular(IncesTheme.radioTarjeta),
                ),
                child: const Text(
                  'I',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Inicializando sesión…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    // Sin sesión se muestra la **portada pública**, no el login. El login sigue
    // accesible desde su botón «Portal Académico» (ruta `/login`) y desde la
    // inscripción. La protección no cambia: con sesión se sigue enrutando por
    // rol justo debajo, y las rutas internas nunca dejaron de exigir sesión.
    if (!_authService.tieneSesion) {
      return LandingPage(aspiranteRepository: widget.landingRepository);
    }

    // La recuperación gana al rol: hay sesión, pero es temporal y sólo sirve
    // para definir la contraseña nueva.
    if (_enRecuperacion) {
      return const RestablecerConCodigoScreen();
    }

    switch (roleProvider.role) {
      case UserRole.admin:
        return const AdminDashboardScreen();
      case UserRole.docente:
        return const DocenteDashboardScreen();
      case UserRole.estudiante:
      case UserRole.desconocido:
        return const AspiranteDashboardScreen();
    }
  }
}

/// Física de scroll única para toda la aplicación.
///
/// **Qué hace y por qué existe.** `MaterialScrollBehavior` es el comportamiento
/// por omisión de Material, y ya es correcto:usa la física de cada plataforma.
/// El problema es que «la de cada plataforma» son tres sensaciones distintas, y
/// el sistema se usa en las tres. Esta subclase cambia dos cosas y nada más:
///
///  1. **Escritorio: sin resplandor de overscroll.** El `StretchOverscroll` de
///     Material estira el contenido con un brillo azul al pasar del límite; en
///     una app de escritorio se lee como un fallo, no como una respuesta. Se
///     sustituye por `ClampingScrollPhysics`, que simplemente se detiene.
///  2. **Móvil: rebote con amortiguación.** `BouncingScrollPhysics` es el
///     rebote que usan las apps de Google en el móvil, y ya es el que Material
///     aplica en iOS; se declara explícito para que no dependa de la plataforma
///     en la que se compile.
///
/// **No se toca la velocidad ni el ratón.** El scroll con rueda en Flutter web
/// usa la del widget, y forzar aquí una velocidad distinta rompería el
/// «desplazamiento suave» del navegador, que es mejor que cualquier imitación.
class _ScrollSuaveInces extends MaterialScrollBehavior {
  const _ScrollSuaveInces();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // En web, `defaultTargetPlatform` reporta siempre la plataforma del
    // compilador, así que no distingue nada. Lo honesto es el ancho: por debajo
    // de 600 px es un teléfono (rebote), por encima es escritorio o tableta
    // grande con ratón (sin resplandor).
    final hayRaton = MediaQuery.of(context).size.shortestSide >= 600;

    return hayRaton
        ? const ClampingScrollPhysics()
        : const BouncingScrollPhysics();
  }
}

/// Pantalla de fallo de arranque: sustituye la excepción sin tratar en la
/// consola por un mensaje legible. Sólo se muestra si [main] no pudo
/// inicializar la sesión (configuración de compilación ausente, etc.).
class _PantallaFalloArranque extends StatelessWidget {
  const _PantallaFalloArranque({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: IncesTheme.claro(),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
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
                      gradient: IncesTheme.degradadoAzul,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'I',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No se pudo iniciar',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    mensaje,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
