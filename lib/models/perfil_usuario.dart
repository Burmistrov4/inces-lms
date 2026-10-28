/// El perfil de una persona en el sistema: la fila de `public.profiles`.
///
/// ## Qué es y qué no es
///
/// `profiles` es la tabla de identidad de **todo** el mundo —aprendices,
/// docentes y administradores—, no la ficha académica del aspirante (ésa es
/// `aspirantes`: fecha de nacimiento, tutor legal, nivel educativo…). Por eso
/// este modelo es deliberadamente pequeño: es lo que el dueño de la cuenta puede
/// corregir de sí mismo.
///
/// ## Por qué sólo el nombre y el apellido son editables
///
/// Es una decisión, no un recorte:
///
///  * `cedula` y `email` son la identidad con la que la persona **se autentica** y
///    con la que se la busca en la nómina. Si se pudieran cambiar desde aquí, un
///    aprendiz podría dejar de coincidir con su propia ficha y con la planilla
///    que se exporta a HACER, sin que nadie lo note.
///  * `rol` es un **privilegio**, y un privilegio que uno mismo puede cambiarse
///    no es un privilegio. Se concede desde el cPanel y sólo desde ahí.
///
/// Los tres se **muestran** en el panel, para dar contexto de quién eres y con
/// qué cuenta estás dentro; ninguno se toca.
class PerfilUsuario {
  const PerfilUsuario({
    required this.id,
    required this.email,
    required this.nombres,
    required this.apellidos,
    required this.rol,
    this.cedula = '',
  });

  final String id;
  final String email;
  final String nombres;
  final String apellidos;

  /// `estudiante`, `docente` o `admin`. Se muestra, no se edita.
  final String rol;

  /// Cédula de identidad (V-12345678 o dígitos), para login con documento.
  final String cedula;

  /// `nombres apellidos`, ya recortado.
  ///
  /// Misma composición que `AspiranteModel.nombreCompleto`, a propósito: dos
  /// formas distintas de armar el nombre en la misma aplicación acaban
  /// discrepando en un espacio de más, y eso se ve en la cabecera.
  String get nombreCompleto => '$nombres $apellidos'.trim();

  /// El rol en su forma legible para la interfaz.
  String get rolLegible => switch (rol) {
        'admin' => 'Administrador',
        'docente' => 'Docente',
        'estudiante' => 'Aprendiz',
        _ => rol,
      };

  factory PerfilUsuario.fromJson(Map<String, dynamic> json) => PerfilUsuario(
        id: json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        nombres: json['nombres'] as String? ?? '',
        apellidos: json['apellidos'] as String? ?? '',
        rol: json['rol'] as String? ?? '',
        cedula: json['cedula'] as String? ?? '',
      );

  /// Copia con el nombre y opcionalmente la cédula corregidos, conservando lo que no es editable.
  PerfilUsuario conNombre({
    required String nombres,
    required String apellidos,
    String? cedula,
  }) =>
      PerfilUsuario(
        id: id,
        email: email,
        nombres: nombres,
        apellidos: apellidos,
        rol: rol,
        cedula: cedula ?? this.cedula,
      );

  @override
  String toString() => 'PerfilUsuario($id, $nombreCompleto, $rol, $cedula)';
}
