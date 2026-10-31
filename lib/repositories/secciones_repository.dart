import '../core/errors/app_exception.dart';
import '../core/gateways/secciones_gateway.dart';
import '../core/result.dart';
import '../models/seccion.dart';
import '../services/secciones_service.dart';

/// Repositorio de secciones del administrador (Módulo 4).
///
/// Mismo reparto que `AdminInscripcionesRepository`: el gateway lanza, este
/// repositorio captura y entrega `Result`. La UI consume con `when`.
class SeccionesRepository {
  SeccionesRepository({SeccionesGateway? gateway})
      : _gateway = gateway ?? BackendSeccionesGateway();

  final SeccionesGateway _gateway;

  Future<Result<PaginaSecciones>> listarSecciones({
    bool soloActivas = false,
    int limite = 50,
    int desplazamiento = 0,
  }) =>
      Result.guard(() => _gateway.listarSecciones(
            soloActivas: soloActivas,
            limite: limite,
            desplazamiento: desplazamiento,
          ));

  /// El tope que acepta el backend en `limite` (`esquemaListadoSecciones`, `.max(100)`).
  static const int limiteMaximoPorPagina = 100;

  /// **Todas** las secciones, paginando con el máximo permitido.
  ///
  /// Existe por un defecto medido el 2026-10-29: el cuadrante y el horario PNA
  /// pedían `limite: 150`, el backend rechaza todo lo que pase de 100 con un
  /// `400`, y la rejilla se quedaba en esqueletos **sin decir por qué**. Pedir
  /// «muchas de una vez» no es una opción: el límite es contrato, y una cifra
  /// mágica por encima se rompe en silencio el día que alguien la ajusta.
  ///
  /// `topePaginas` no es una regla de negocio: es un cortafuegos para que una
  /// respuesta que diga «hay más» y no avance no deje la pantalla girando.
  Future<Result<List<Seccion>>> listarTodasLasSecciones({
    bool soloActivas = false,
    int topePaginas = 20,
  }) {
    return Result.guard(() async {
      final acumulado = <Seccion>[];
      var desplazamiento = 0;
      for (var pagina = 0; pagina < topePaginas; pagina++) {
        final trozo = await _gateway.listarSecciones(
          soloActivas: soloActivas,
          limite: limiteMaximoPorPagina,
          desplazamiento: desplazamiento,
        );
        acumulado.addAll(trozo.secciones);
        desplazamiento += trozo.secciones.length;
        // Cortes: una página incompleta es el final; y si el servidor declaró un
        // total, se para al alcanzarlo aunque la página viniera llena.
        if (trozo.secciones.length < limiteMaximoPorPagina) break;
        if (trozo.total > 0 && acumulado.length >= trozo.total) break;
      }
      return acumulado;
    });
  }

  Future<Result<Seccion>> crearSeccion(Seccion borrador) =>
      Result.guard(() => _gateway.crearSeccion(borrador));

  /// Matricula a un aprendiz en un aula.
  ///
  /// Sólo valida lo que no puede saber el servidor —que le lleguen dos ids—. La
  /// regla de cupo, período y rol vive en la RPC: replicarla aquí daría dos
  /// verdades que acaban discrepando.
  Future<Result<String>> matricular({
    required String seccionId,
    required String estudianteId,
  }) {
    return Result.guard(() async {
      final seccion = seccionId.trim();
      final estudiante = estudianteId.trim();

      if (seccion.isEmpty || estudiante.isEmpty) {
        throw const AppException.validacion(
          'Falta el aula o el aprendiz.',
        );
      }

      return _gateway.matricular(seccion, estudiante);
    });
  }

  /// Da de baja a un aprendiz del aula.
  ///
  /// El mínimo del motivo se valida aquí para que el usuario lo sepa antes de
  /// gastar una petición; el servidor lo vuelve a comprobar y además guarda
  /// quién lo hizo. La baja **no borra nada**: el expediente y la planilla del
  /// alumno siguen visibles.
  Future<Result<String>> darDeBaja({
    required String seccionId,
    required String estudianteId,
    required String motivo,
  }) {
    return Result.guard(() async {
      final motivoLimpio = motivo.trim();
      if (motivoLimpio.length < 3) {
        throw const AppException.validacion(
          'Indica el motivo de la baja: es lo que explicará después por qué ese '
          'alumno no terminó el curso.',
        );
      }

      return _gateway.darDeBaja(
        seccionId.trim(),
        estudianteId.trim(),
        motivo: motivoLimpio,
      );
    });
  }

  Future<Result<Seccion>> actualizarSeccion(
          String id, CambiosSeccion cambios) =>
      Result.guard(() => _gateway.actualizarSeccion(id, cambios));

  /// El grupo de una materia en un período, creándolo si falta.
  ///
  /// Es la llamada que permite pedirle al administrador «curso + materia» en vez
  /// de «sección». Devuelve también si lo creó, para poder decirlo.
  Future<Result<({Seccion seccion, bool creada})>> resolverGrupo({
    required String programaId,
    required String materiaId,
    required String periodo,
  }) =>
      Result.guard(() => _gateway.resolverGrupo(
            programaId: programaId,
            materiaId: materiaId,
            periodo: periodo,
          ));
}