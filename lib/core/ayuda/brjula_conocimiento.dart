/// Lo que sabe **Brújula**, el asistente del INCES LMS.
///
/// **Por qué una base escrita y no un modelo.** Un asistente que improvisa
/// inventa módulos y enlaces que no existen; en una demostración eso es peor que
/// no tener asistente. Aquí cada respuesta está escrita a mano, apunta a una
/// sección que existe de verdad y dice qué perfil puede hacerla. Si no hay
/// coincidencia, Brújula lo admite y ofrece el camino: no adivina.
///
/// Cada entrada tiene **pocas palabras y un botón**. El objetivo es que nadie
/// tenga que leer un párrafo para llegar a una pantalla.
library;

/// Quién puede usar una entrada.
enum Publico { todos, admin, docente, aprendiz }

/// Una respuesta de Brújula.
class EntradaAyuda {
  const EntradaAyuda({
    required this.titulo,
    required this.respuesta,
    required this.claves,
    this.destino,
    this.publico = Publico.todos,
  });

  /// Cómo se llama la tarea, en las palabras del usuario.
  final String titulo;

  /// Una o dos frases. Ni una más.
  final String respuesta;

  /// Palabras que la activan (sin tildes, en minúsculas).
  final List<String> claves;

  /// Título exacto de la sección a la que lleva. `null` = no hay pantalla.
  final String? destino;

  final Publico publico;

  bool sirvePara(String rol) => switch (publico) {
        Publico.todos => true,
        Publico.admin => rol == 'admin' || rol == 'administrador',
        Publico.docente => rol == 'docente',
        Publico.aprendiz => rol == 'aspirante' || rol == 'estudiante',
      };
}

/// Normaliza para comparar: sin tildes, sin mayúsculas, sin signos.
String normalizar(String texto) {
  const conTilde = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const sinTilde = 'aaaaaeeeeiiiiooooouuuunc';
  final plano = StringBuffer();
  for (final c in texto.toLowerCase().split('')) {
    final i = conTilde.indexOf(c);
    plano.write(i >= 0 ? sinTilde[i] : c);
  }
  return plano
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Todas las entradas, en el orden en que se ofrecen cuando no hay búsqueda.
const List<EntradaAyuda> brjulaConocimiento = [
  // --- Empezar -------------------------------------------------------------
  EntradaAyuda(
    titulo: 'No veo datos o la pantalla salió vacía',
    respuesta:
        'Casi siempre es la caché del navegador. Recarga con Ctrl + Shift + R. '
        'Si sigue igual, mira el pie: debe decir la versión más reciente.',
    claves: ['vacio', 'no carga', 'no aparece', 'no veo', 'error', 'cache'],
  ),
  EntradaAyuda(
    titulo: 'Cómo cambiar mi contraseña',
    respuesta:
        'Está en «Mi Perfil», al final. Si la olvidaste, usa «¿Olvidaste tu '
        'contraseña?» en la pantalla de entrada: llega un código al correo.',
    claves: ['contrasena', 'clave', 'password', 'olvide', 'cambiar'],
  ),

  // --- Administración ------------------------------------------------------
  EntradaAyuda(
    titulo: 'Abrir un período nuevo',
    respuesta:
        'En «Período» → «Nuevo período». Al cerrar el vigente tienes que '
        'declarar el que lo sucede; sin sucesor el cierre no se completa.',
    claves: ['periodo', 'lapso', 'abrir', 'nuevo', 'cerrar', 'vigente'],
    destino: 'Período',
    publico: Publico.admin,
  ),
  EntradaAyuda(
    titulo: 'Crear un curso, especialidad o PNA',
    respuesta:
        'En «Cursos y PNA» → «Nuevo curso». Le pones nombre, código y duración; '
        'después le agregas las materias del pensum.',
    claves: ['curso', 'programa', 'especialidad', 'pna', 'crear', 'materia',
      'pensum'],
    destino: 'Cursos y PNA',
    publico: Publico.admin,
  ),
  EntradaAyuda(
    titulo: 'Asignar una clase en el horario',
    respuesta:
        'En «Cuadrante de Horarios» toca el «+» de la celda. Eliges aula '
        'virtual y docente; el espacio físico es opcional. Hay bloques de '
        'mañana, tarde y noche (13 a 17).',
    claves: ['horario', 'cuadrante', 'asignar', 'clase', 'bloque', 'nocturno',
      'tarde', 'manana'],
    destino: 'Cuadrante de Horarios',
    publico: Publico.admin,
  ),
  EntradaAyuda(
    titulo: 'Horario del PNA',
    respuesta:
        'En «Horario PNA», con «Asignar materia PNA». Materia y docente son '
        'obligatorios; el espacio es opcional.',
    claves: ['pna', 'horario pna', 'introductorio'],
    destino: 'Horario PNA',
    publico: Publico.admin,
  ),
  EntradaAyuda(
    titulo: 'Meter un aprendiz en un aula',
    respuesta:
        'En «Aulas Virtuales» abre el aula y pulsa el icono de personas: '
        'buscas al aprendiz y lo matriculas. Si no aparece, activa «Mostrando '
        'también cuentas de prueba» o créalo en «Usuarios y Roles».',
    claves: ['matricular', 'inscribir aprendiz', 'meter', 'alumno', 'aula'],
    destino: 'Aulas Virtuales',
    publico: Publico.admin,
  ),
  EntradaAyuda(
    titulo: 'Dar de baja a un aprendiz',
    respuesta:
        'En el mismo listado del aula, el icono de persona con menos. La baja '
        'pide un motivo y **no borra**: el expediente y la planilla se '
        'conservan.',
    claves: ['baja', 'retirar', 'sacar', 'eliminar aprendiz'],
    destino: 'Aulas Virtuales',
    publico: Publico.admin,
  ),
  EntradaAyuda(
    titulo: 'Invitar a un docente',
    respuesta:
        'En «Usuarios y Roles» → «Invitar». Le llega un correo con un enlace '
        'para crear su contraseña.',
    claves: ['invitar', 'docente', 'usuario', 'crear cuenta', 'rol'],
    destino: 'Usuarios y Roles',
    publico: Publico.admin,
  ),
  EntradaAyuda(
    titulo: 'Ver quién se inscribió',
    respuesta:
        'En «Campos de Inscripción» está la cola de solicitudes y la lista de '
        'inscritos. Cada fila se abre con su detalle.',
    claves: ['inscritos', 'inscripcion', 'solicitud', 'cola', 'ver'],
    destino: 'Campos de Inscripción',
    publico: Publico.admin,
  ),
  EntradaAyuda(
    titulo: 'Archivos y materiales',
    respuesta:
        '«Archivos del Centro» guarda lo institucional. Los materiales de una '
        'materia se suben desde el aula, en «Guías y materiales».',
    claves: ['archivo', 'subir', 'drive', 'material', 'guia', 'documento'],
    destino: 'Archivos del Centro',
    publico: Publico.admin,
  ),

  // --- Docente -------------------------------------------------------------
  EntradaAyuda(
    titulo: 'Poner una tarea a mis estudiantes',
    respuesta:
        'Abre el aula en «Aulas Virtuales» → «Trabajo de clase» → «Nueva '
        'tarea». Nace en borrador: hay que **publicarla** para que aparezca a '
        'los aprendices.',
    claves: ['tarea', 'actividad', 'poner', 'crear', 'publicar'],
    destino: 'Aulas Virtuales',
    publico: Publico.docente,
  ),
  EntradaAyuda(
    titulo: 'Calificar una entrega',
    respuesta:
        'En «Calificaciones» eliges el aula y la tarea, y pones la nota de 01 a '
        '20. Al guardar, el aprendiz la ve al instante.',
    claves: ['calificar', 'nota', 'corregir', 'entregas', 'evaluar'],
    destino: 'Calificaciones',
    publico: Publico.docente,
  ),
  EntradaAyuda(
    titulo: 'Pasar lista',
    respuesta:
        'En «Pasar lista» eliges el aula y marcas presentes. Funciona por '
        'REST incluso si el aviso en vivo no llega.',
    claves: ['asistencia', 'lista', 'presente', 'marcar'],
    destino: 'Pasar lista',
    publico: Publico.docente,
  ),
  EntradaAyuda(
    titulo: 'Ver mi horario',
    respuesta: 'En «Mi horario» salen tus bloques del período vigente.',
    claves: ['horario', 'mi horario', 'bloques', 'donde doy'],
    destino: 'Mi horario',
    publico: Publico.docente,
  ),

  // --- Aprendiz ------------------------------------------------------------
  EntradaAyuda(
    titulo: 'Entrar a un aula con un código',
    respuesta:
        'En «Mis aulas» → «Unirme con un código». El docente dicta 8 '
        'caracteres; no distingue mayúsculas.',
    claves: ['codigo', 'unirme', 'entrar', 'aula', 'clase'],
    destino: 'Mis aulas',
    publico: Publico.aprendiz,
  ),
  EntradaAyuda(
    titulo: 'Ver mis tareas y entregar',
    respuesta:
        'En «Mis tareas» están las publicadas con su fecha. Abres la tuya, '
        'adjuntas el archivo y entregas.',
    claves: ['tarea', 'entregar', 'trabajo', 'subir', 'adjuntar'],
    destino: 'Mis tareas',
    publico: Publico.aprendiz,
  ),
  EntradaAyuda(
    titulo: 'Ver mis notas',
    respuesta:
        'En «Mi inscripción» está tu planilla con las notas por materia. Si '
        'falta alguna, el docente aún no la cargó.',
    claves: ['nota', 'calificacion', 'planilla', 'resultado'],
    destino: 'Mi inscripción',
    publico: Publico.aprendiz,
  ),
  EntradaAyuda(
    titulo: 'Inscribirme en un curso',
    respuesta:
        'En «Inscribirme en un curso» llenas el formulario. Queda en revisión '
        'hasta que administración lo apruebe.',
    claves: ['inscribirme', 'inscripcion', 'solicitar', 'cupo'],
    destino: 'Inscribirme en un curso',
    publico: Publico.aprendiz,
  ),
  EntradaAyuda(
    titulo: 'Marcar mi asistencia',
    respuesta:
        'En «Marcar asistencia» escaneas o pegas el código que da el docente. '
        'El código caduca rápido: pídele uno nuevo si falla.',
    claves: ['asistencia', 'qr', 'marcar', 'codigo'],
    destino: 'Marcar asistencia',
    publico: Publico.aprendiz,
  ),

  // --- Sin pantalla concreta ----------------------------------------------
  EntradaAyuda(
    titulo: '¿Qué es el PNA?',
    respuesta:
        'El Programa Nacional de Aprendizaje (CUR-INT-01) para jóvenes de 14 a '
        '17 años. Tiene su propio horario y su propia rejilla.',
    claves: ['pna', 'que es', 'programa nacional', 'aprendizaje'],
    publico: Publico.admin,
  ),
  EntradaAyuda(
    titulo: '¿Esto se puede ver desde el teléfono?',
    respuesta:
        'Sí. Todas las pantallas se adaptan; en pantallas estrechas las tablas '
        'se convierten en listas por día.',
    claves: ['telefono', 'movil', 'celular', 'pantalla', 'responsive'],
  ),
];
