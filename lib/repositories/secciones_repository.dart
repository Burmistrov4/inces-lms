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