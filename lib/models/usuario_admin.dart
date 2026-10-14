class UsuarioAdmin {
  final String id;
  final String email;
  final String? cedula;
  final String nombres;
  final String apellidos;
  final String rol;
  final bool activo;

  const UsuarioAdmin({
    required this.id,
    required this.email,
    required this.cedula,
    required this.nombres,
    required this.apellidos,
    required this.rol,
    required this.activo,
  });
  String get nombreCompleto {
    final n = '$nombres $apellidos'.trim();
    return n.isEmpty ? email : n;
  }

  /// ¿Es una cuenta de demostración de la siembra?
  ///
  /// Mismo criterio que `InscripcionDetallada.esCuentaDemo`: el dominio
  /// `semilla.invalid` está reservado para dominios inválidos (RFC 2606), y es
  /// la marca que la siembra dejó en sus cuentas. Medido el 2026-10-13: 56 de
  /// los 64 perfiles de producción la usan. Etiquetar distingue demo de real
  /// **sin borrar ni ocultar**: algunas fichas de demostración dependen de
  /// ellas.
  bool get esCuentaDemo =>
      email.trim().toLowerCase().endsWith('@semilla.invalid');

  factory UsuarioAdmin.fromJson(Map<String, dynamic> j) => UsuarioAdmin(
    id: j['id'] as String,
    email: j['email'] as String,
    cedula: j['cedula'] as String?,
    nombres: (j['nombres'] as String?) ?? '',
    apellidos: (j['apellidos'] as String?) ?? '',
    rol: j['rol'] as String,
    activo: j['activo'] as bool? ?? false,
  );
}

class PaginaUsuarios {
  final List<UsuarioAdmin> usuarios;
  final int total;
  final int limite;
  final int desplazamiento;
  const PaginaUsuarios({
    required this.usuarios,
    required this.total,
    required this.limite,
    required this.desplazamiento,
  });
  factory PaginaUsuarios.fromJson(Map<String, dynamic> j) {
    final raw = j['usuarios'] as List<dynamic>? ?? const [];
    return PaginaUsuarios(
      usuarios: raw
          .whereType<Map<String, dynamic>>()
          .map(UsuarioAdmin.fromJson)
          .toList(),
      total: (j['total'] as num?)?.toInt() ?? 0,
      limite: (j['limite'] as num?)?.toInt() ?? 25,
      desplazamiento: (j['desplazamiento'] as num?)?.toInt() ?? 0,
    );
  }
}
