import '../../models/seccion.dart';

/// Contrato de las rutas de administración de secciones (Módulo 4).
///
/// Separado de `InscripcionGateway` porque las unidades son distintas: aquí
/// se gestiona el grupo (lo que el estudiante elige), no la inscripción. Las
/// implementaciones lanzan `AppException`; los repositorios las envuelven en
/// `Result`.
abstract interface class SeccionesGateway {
  /// Catálogo paginado de secciones. Filtros opcionales: sólo activas.
  Future<PaginaSecciones> listarSecciones({
    bool soloActivas = false,
    int limite = 50,
    int desplazamiento = 0,
  });

  /// Crea una sección. Devuelve la sección recién creada (con `id`).
  Future<Seccion> crearSeccion(Seccion borrador);

  /// Archiva, renombra o recapacita una sección. No se puede cambiar
  /// programa, materia ni período (identidad).
  Future<Seccion> actualizarSeccion(String id, CambiosSeccion cambios);

  /// Devuelve el grupo de una materia en un período, creándolo si no existe.
  ///
  /// **Es lo que quita «sección» de la cara visible.** La pantalla pide curso +
  /// materia —lo que el administrador sabe nombrar— y esta llamada resuelve la
  /// fila que liga los tres. `creada` dice si esta vez la creó o ya estaba.
  ///
  /// Es `POST` y no `GET` porque puede escribir: un `GET` que crea filas se
  /// duplica con cualquier reintento del navegador o de un proxy.
  Future<({Seccion seccion, bool creada})> resolverGrupo({
    required String programaId,
    required String materiaId,
    required String periodo,
  });
}