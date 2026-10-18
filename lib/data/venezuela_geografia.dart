/// División político-territorial y catálogo geográfico institucional de Venezuela.
///
/// Proporciona la jerarquía: Estado -> Municipio -> Parroquia -> Comunidades sugeridas,
/// con especial granularidad en el estado Carabobo (sede del CFS Rafael Urdaneta / La Isabelica)
/// y cobertura integral de las 24 entidades federales de Venezuela con normalización
/// robusta para códigos en mayúsculas (ej. CARABOBO, DISTRITO_CAPITAL) y tildes.
library;

class ParroquiaGeo {
  const ParroquiaGeo({
    required this.nombre,
    this.comunidadesSugeridas = const [],
    this.direccionesSugeridas = const [],
  });

  final String nombre;
  final List<String> comunidadesSugeridas;
  final List<String> direccionesSugeridas;
}

class MunicipioGeo {
  const MunicipioGeo({
    required this.nombre,
    required this.parroquias,
  });

  final String nombre;
  final List<ParroquiaGeo> parroquias;

  ParroquiaGeo? buscarParroquia(String nombreParroquia) {
    final limpio = VenezuelaGeografia.normalizarClave(nombreParroquia);
    for (final p in parroquias) {
      if (VenezuelaGeografia.normalizarClave(p.nombre) == limpio) return p;
    }
    return parroquias.isNotEmpty ? parroquias.first : null;
  }
}

class EstadoGeo {
  const EstadoGeo({
    required this.nombre,
    required this.municipios,
  });

  final String nombre;
  final List<MunicipioGeo> municipios;

  MunicipioGeo? buscarMunicipio(String nombreMunicipio) {
    final limpio = VenezuelaGeografia.normalizarClave(nombreMunicipio);
    for (final m in municipios) {
      if (VenezuelaGeografia.normalizarClave(m.nombre) == limpio) return m;
    }
    return municipios.isNotEmpty ? municipios.first : null;
  }
}

class VenezuelaGeografia {
  VenezuelaGeografia._();

  static const List<String> todosLosEstados = [
    'Carabobo',
    'Distrito Capital',
    'Miranda',
    'Aragua',
    'Lara',
    'Zulia',
    'Anzoátegui',
    'Apure',
    'Barinas',
    'Bolívar',
    'Cojedes',
    'Delta Amacuro',
    'Falcón',
    'Guárico',
    'La Guaira',
    'Mérida',
    'Monagas',
    'Nueva Esparta',
    'Portuguesa',
    'Sucre',
    'Táchira',
    'Trujillo',
    'Yaracuy',
    'Amazonas',
  ];

  /// Normaliza una cadena para comparaciones geográficas insensibles a mayúsculas,
  /// tildes y separadores como guiones bajos o espacios (ej. CARABOBO -> carabobo,
  /// DISTRITO_CAPITAL -> distrito capital).
  static String normalizarClave(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[\s_\-]+'), ' ');
  }

  static EstadoGeo? buscarEstado(String? estado) {
    if (estado == null || estado.trim().isEmpty) return null;
    final norm = normalizarClave(estado);
    for (final entry in _datos.entries) {
      if (normalizarClave(entry.key) == norm) {
        return entry.value;
      }
    }
    return null;
  }

  static final Map<String, EstadoGeo> _datos = {
    'Carabobo': const EstadoGeo(
      nombre: 'Carabobo',
      municipios: [
        MunicipioGeo(
          nombre: 'Valencia',
          parroquias: [
            ParroquiaGeo(
              nombre: 'Rafael Urdaneta',
              comunidadesSugeridas: [
                'La Isabelica',
                'Flor Amarillo',
                'Parque Valencia',
                'Santa Inés',
                'Las Palmitas',
                'Bucaral',
                'Quintas del Sol',
                'Paseo Las Industrias',
                'Bello Monte',
                'Ciudad Plaza',
              ],
              direccionesSugeridas: [
                'Urb. La Isabelica, Sector 3, cercanías del CFS INCES',
                'Flor Amarillo, Av. Principal, Urb. Quintas del Sol',
                'Urb. Parque Valencia, Manzana 14',
                'Zona Industrial Sur, Av. Este-Oeste',
                'Las Palmitas, Sector 2',
              ],
            ),
            ParroquiaGeo(
              nombre: 'San José',
              comunidadesSugeridas: [
                'El Viñedo',
                'Prebo',
                'Los Nísperos',
                'La Trigaleña',
                'Las Chimeneas',
                'Agua Blanca',
                'Guaparo',
              ],
              direccionesSugeridas: [
                'Av. Bolívar Norte, Sector El Viñedo',
                'Urb. Prebo, Calle 137',
                'Urb. La Trigaleña, Av. Principal',
              ],
            ),
            ParroquiaGeo(
              nombre: 'Santa Rosa',
              comunidadesSugeridas: [
                'Santa Rosa Centro',
                'El Triunfo',
                '13 de Septiembre',
                'Los Taladros',
              ],
              direccionesSugeridas: [
                'Av. Las Ferias, Sector Santa Rosa',
                'Calle Lara c/c Av. Branger',
              ],
            ),
            ParroquiaGeo(
              nombre: 'San Blas',
              comunidadesSugeridas: ['San Blas Casco Histórico', 'La Adobera', 'Michelena'],
              direccionesSugeridas: ['Calle Colombia, San Blas Centro'],
            ),
            ParroquiaGeo(
              nombre: 'Miguel Peña',
              comunidadesSugeridas: [
                'El Socorro Sur',
                'Lomas de Funval',
                'Bella Vista',
                'Trapichito',
                'El Morro',
              ],
              direccionesSugeridas: [
                'Av. Aránzazu, Sector Lomas de Funval',
                'Bella Vista, Calle Principal',
              ],
            ),
            ParroquiaGeo(
              nombre: 'Candelaria',
              comunidadesSugeridas: ['La Candelaria Centro', 'San Pedro'],
            ),
            ParroquiaGeo(
              nombre: 'Catedral',
              comunidadesSugeridas: ['Casco Central Valencia', 'Plaza Bolívar'],
            ),
            ParroquiaGeo(
              nombre: 'El Socorro',
              comunidadesSugeridas: ['El Socorro Centro'],
            ),
            ParroquiaGeo(
              nombre: 'Negro Primero',
              comunidadesSugeridas: ['Los Naranjos', 'La Unión'],
            ),
          ],
        ),
        MunicipioGeo(
          nombre: 'Naguanagua',
          parroquias: [
            ParroquiaGeo(
              nombre: 'Naguanagua',
              comunidadesSugeridas: [
                'La Granja',
                'Las Quintas',
                'Tazajal',
                'Tarapío',
                'Mañongo',
                'Carialinda',
                'Vivienda Rural de Bárbula',
              ],
              direccionesSugeridas: [
                'Av. Universidad, Sector La Granja',
                'Urb. Las Quintas, Av. Salvador Feo La Cruz',
                'Urb. Tazajal, Calle Principal',
              ],
            ),
          ],
        ),
        MunicipioGeo(
          nombre: 'San Diego',
          parroquias: [
            ParroquiaGeo(
              nombre: 'San Diego',
              comunidadesSugeridas: [
                'El Morro',
                'La Esmeralda',
                'Valle Verde',
                'Los Jarales',
                'Monteserino',
                'Poblado de San Diego',
              ],
              direccionesSugeridas: [
                'Av. Don Julio Centeno, Sector El Morro',
                'Urb. La Esmeralda, Manzana F',
                'Urb. Valle Verde, Calle Las Flores',
              ],
            ),
          ],
        ),
        MunicipioGeo(
          nombre: 'Guacara',
          parroquias: [
            ParroquiaGeo(
              nombre: 'Guacara',
              comunidadesSugeridas: ['Casco de Guacara', 'San Agustín', 'El Samán'],
            ),
            ParroquiaGeo(
              nombre: 'Ciudad Alianza',
              comunidadesSugeridas: ['Ciudad Alianza 1ra Etapa', 'Ciudad Alianza 4ta Etapa'],
            ),
            ParroquiaGeo(
              nombre: 'Yagua',
              comunidadesSugeridas: ['Yagua Centro', 'El Cabrito'],
            ),
          ],
        ),
        MunicipioGeo(
          nombre: 'Los Guayos',
          parroquias: [
            ParroquiaGeo(
              nombre: 'Los Guayos',
              comunidadesSugeridas: ['Casco Los Guayos', 'Las Agüitas', 'Paraparal', 'El Roble'],
            ),
          ],
        ),
        MunicipioGeo(
          nombre: 'Puerto Cabello',
          parroquias: [
            ParroquiaGeo(
              nombre: 'Bartolomé Salóm',
              comunidadesSugeridas: ['Rancho Grande', 'Tejerías'],
            ),
            ParroquiaGeo(
              nombre: 'Democracia',
              comunidadesSugeridas: ['La Sorbona', 'San Esteban'],
            ),
            ParroquiaGeo(
              nombre: 'Fraternidad',
              comunidadesSugeridas: ['Centro Histórico Puerto Cabello'],
            ),
            ParroquiaGeo(
              nombre: 'Juan José Flores',
              comunidadesSugeridas: ['Cumboto Norte', 'Cumboto Sur'],
            ),
            ParroquiaGeo(
              nombre: 'Borburata',
              comunidadesSugeridas: ['Pueblo de Borburata'],
            ),
            ParroquiaGeo(
              nombre: 'Patanemo',
              comunidadesSugeridas: ['Bahía de Patanemo'],
            ),
          ],
        ),
        MunicipioGeo(
          nombre: 'Libertador',
          parroquias: [
            ParroquiaGeo(
              nombre: 'Tocuyito',
              comunidadesSugeridas: ['Casco de Tocuyito', 'El Molino', 'La Yaguara'],
            ),
            ParroquiaGeo(
              nombre: 'Independencia',
              comunidadesSugeridas: ['Campo Carabobo', 'Sabana Grande'],
            ),
          ],
        ),
        MunicipioGeo(
          nombre: 'Carlos Arvelo',
          parroquias: [
            ParroquiaGeo(nombre: 'Güigüe', comunidadesSugeridas: ['Casco de Güigüe']),
            ParroquiaGeo(nombre: 'Belén', comunidadesSugeridas: ['Pueblo de Belén']),
            ParroquiaGeo(nombre: 'Tacarigua', comunidadesSugeridas: ['Central Tacarigua']),
          ],
        ),
        MunicipioGeo(
          nombre: 'San Joaquín',
          parroquias: [
            ParroquiaGeo(nombre: 'San Joaquín', comunidadesSugeridas: ['Casco San Joaquín']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Diego Ibarra',
          parroquias: [
            ParroquiaGeo(nombre: 'Mariara', comunidadesSugeridas: ['Mariara Centro']),
            ParroquiaGeo(nombre: 'Aguas Calientes', comunidadesSugeridas: ['Sector Termal']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Bejuma',
          parroquias: [
            ParroquiaGeo(nombre: 'Bejuma', comunidadesSugeridas: ['Casco de Bejuma']),
            ParroquiaGeo(nombre: 'Canoabo', comunidadesSugeridas: ['Pueblo de Canoabo']),
            ParroquiaGeo(nombre: 'Simón Bolívar', comunidadesSugeridas: ['Chirgua']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Montalbán',
          parroquias: [
            ParroquiaGeo(nombre: 'Montalbán', comunidadesSugeridas: ['Casco Montalbán']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Miranda',
          parroquias: [
            ParroquiaGeo(nombre: 'Miranda', comunidadesSugeridas: ['Casco Miranda']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Juan José Mora',
          parroquias: [
            ParroquiaGeo(nombre: 'Morón', comunidadesSugeridas: ['Morón Centro', 'Palma Sola']),
            ParroquiaGeo(nombre: 'Urama', comunidadesSugeridas: ['Pueblo de Urama']),
          ],
        ),
      ],
    ),
    'Distrito Capital': const EstadoGeo(
      nombre: 'Distrito Capital',
      municipios: [
        MunicipioGeo(
          nombre: 'Libertador',
          parroquias: [
            ParroquiaGeo(nombre: 'Sucre (Catia)', comunidadesSugeridas: ['Catia', 'Propatria', 'Pérez Bonalde']),
            ParroquiaGeo(nombre: 'El Valle', comunidadesSugeridas: ['El Valle Centro', 'Longaray']),
            ParroquiaGeo(nombre: 'Antímano', comunidadesSugeridas: ['Antímano', 'Carapita']),
            ParroquiaGeo(nombre: 'Caricuao', comunidadesSugeridas: ['UD-1', 'UD-2', 'UD-3', 'UD-4', 'UD-5']),
            ParroquiaGeo(nombre: 'Coche', comunidadesSugeridas: ['Coche Centro', 'Delicias']),
            ParroquiaGeo(nombre: 'La Pastora', comunidadesSugeridas: ['La Pastora Centro', 'Lídice']),
            ParroquiaGeo(nombre: 'San Pedro', comunidadesSugeridas: ['Los Chaguaramos', 'Santa Mónica']),
            ParroquiaGeo(nombre: 'San Juan', comunidadesSugeridas: ['San Juan Centro', 'El Silencio']),
            ParroquiaGeo(nombre: 'Altagracia', comunidadesSugeridas: ['Altagracia Norte']),
            ParroquiaGeo(nombre: 'La Vega', comunidadesSugeridas: ['La Vega Centro']),
          ],
        ),
      ],
    ),
    'Miranda': const EstadoGeo(
      nombre: 'Miranda',
      municipios: [
        MunicipioGeo(
          nombre: 'Sucre',
          parroquias: [
            ParroquiaGeo(nombre: 'Petare', comunidadesSugeridas: ['La California', 'Macaracuay', 'Petare Casco']),
            ParroquiaGeo(nombre: 'Leoncio Martínez', comunidadesSugeridas: ['Los Dos Caminos', 'Boleíta']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Chacao',
          parroquias: [
            ParroquiaGeo(nombre: 'Chacao', comunidadesSugeridas: ['El Rosal', 'Altamira', 'Los Palos Grandes']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Baruta',
          parroquias: [
            ParroquiaGeo(nombre: 'Nuestra Señora del Rosario', comunidadesSugeridas: ['Las Mercedes', 'Prados del Este']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Guaicaipuro',
          parroquias: [
            ParroquiaGeo(nombre: 'Los Teques', comunidadesSugeridas: ['Los Teques Centro', 'El Paso']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Plaza',
          parroquias: [
            ParroquiaGeo(nombre: 'Guarenas', comunidadesSugeridas: ['Guarenas Centro', 'Nueva Casarapa']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Zamora',
          parroquias: [
            ParroquiaGeo(nombre: 'Guatire', comunidadesSugeridas: ['Guatire Centro', 'Castillejo']),
          ],
        ),
      ],
    ),
    'Aragua': const EstadoGeo(
      nombre: 'Aragua',
      municipios: [
        MunicipioGeo(
          nombre: 'Girardot',
          parroquias: [
            ParroquiaGeo(nombre: 'Los Tacarigua', comunidadesSugeridas: ['San Vicente', 'La Coromoto']),
            ParroquiaGeo(nombre: 'Madre María de San José', comunidadesSugeridas: ['Calicanto', 'La Soledad']),
            ParroquiaGeo(nombre: 'Joaquín Crespo', comunidadesSugeridas: ['Piñonal', 'Las Acacias']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Santiago Mariño',
          parroquias: [
            ParroquiaGeo(nombre: 'Turmero', comunidadesSugeridas: ['Turmero Centro', 'La Julia']),
          ],
        ),
        MunicipioGeo(
          nombre: 'José Félix Ribas',
          parroquias: [
            ParroquiaGeo(nombre: 'La Victoria', comunidadesSugeridas: ['La Victoria Centro', 'Las Mercedes']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Mario Briceño Iragorry',
          parroquias: [
            ParroquiaGeo(nombre: 'El Limón', comunidadesSugeridas: ['El Limón', 'Caña de Azúcar']),
          ],
        ),
      ],
    ),
    'Lara': const EstadoGeo(
      nombre: 'Lara',
      municipios: [
        MunicipioGeo(
          nombre: 'Iribarren',
          parroquias: [
            ParroquiaGeo(nombre: 'Catedral', comunidadesSugeridas: ['Barquisimeto Este', 'Los Cardones']),
            ParroquiaGeo(nombre: 'Concepción', comunidadesSugeridas: ['Centro Barquisimeto']),
            ParroquiaGeo(nombre: 'Santa Rosa', comunidadesSugeridas: ['Pueblo de Santa Rosa']),
            ParroquiaGeo(nombre: 'Unión', comunidadesSugeridas: ['Barrio Unión']),
            ParroquiaGeo(nombre: 'Juan de Villegas', comunidadesSugeridas: ['La Carucieña', 'El Garabatal']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Palavecino',
          parroquias: [
            ParroquiaGeo(nombre: 'Cabudare', comunidadesSugeridas: ['Cabudare Centro', 'Los Rastrojos']),
            ParroquiaGeo(nombre: 'José Gregorio Bastidas', comunidadesSugeridas: ['La Piedad', 'El Palmar']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Torres',
          parroquias: [
            ParroquiaGeo(nombre: 'Trinidad Samuel', comunidadesSugeridas: ['Carora Centro']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Morán',
          parroquias: [
            ParroquiaGeo(nombre: 'Bolívar', comunidadesSugeridas: ['El Tocuyo']),
          ],
        ),
      ],
    ),
    'Zulia': const EstadoGeo(
      nombre: 'Zulia',
      municipios: [
        MunicipioGeo(
          nombre: 'Maracaibo',
          parroquias: [
            ParroquiaGeo(nombre: 'Chiquinquirá', comunidadesSugeridas: ['Casco Central', 'El Tránsito']),
            ParroquiaGeo(nombre: 'Olegario Villalobos', comunidadesSugeridas: ['Bella Vista', '5 de Julio']),
            ParroquiaGeo(nombre: 'Santa Lucía', comunidadesSugeridas: ['El Empedrao']),
            ParroquiaGeo(nombre: 'Cristo de Aranza', comunidadesSugeridas: ['Los Haticos']),
            ParroquiaGeo(nombre: 'Francisco Eugenio Bustamante', comunidadesSugeridas: ['Cuatricentenario']),
          ],
        ),
        MunicipioGeo(
          nombre: 'San Francisco',
          parroquias: [
            ParroquiaGeo(nombre: 'San Francisco', comunidadesSugeridas: ['La Coromoto', 'San Francisco Centro']),
            ParroquiaGeo(nombre: 'Domitila Flores', comunidadesSugeridas: ['El Silencio']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Cabimas',
          parroquias: [
            ParroquiaGeo(nombre: 'Ambrosio', comunidadesSugeridas: ['Casco Central Cabimas']),
            ParroquiaGeo(nombre: 'Carmen Herrera', comunidadesSugeridas: ['Miraflores']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Lagunillas',
          parroquias: [
            ParroquiaGeo(nombre: 'Alonso de Ojeda', comunidadesSugeridas: ['Ciudad Ojeda Centro']),
          ],
        ),
      ],
    ),
    'Anzoátegui': const EstadoGeo(
      nombre: 'Anzoátegui',
      municipios: [
        MunicipioGeo(
          nombre: 'Simón Bolívar',
          parroquias: [
            ParroquiaGeo(nombre: 'Barcelona', comunidadesSugeridas: ['Barcelona Casco Central']),
            ParroquiaGeo(nombre: 'El Carmen', comunidadesSugeridas: ['Tronconal', 'Boyacá']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Juan Antonio Sotillo',
          parroquias: [
            ParroquiaGeo(nombre: 'Puerto La Cruz', comunidadesSugeridas: ['Paseo Colón', 'Casco Central']),
            ParroquiaGeo(nombre: 'Pozuelos', comunidadesSugeridas: ['Pozuelos']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Diego Bautista Urbaneja',
          parroquias: [
            ParroquiaGeo(nombre: 'Lechería', comunidadesSugeridas: ['Playa Mansa', 'Morro']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Anaco',
          parroquias: [
            ParroquiaGeo(nombre: 'Anaco', comunidadesSugeridas: ['Anaco Centro']),
          ],
        ),
      ],
    ),
    'Falcón': const EstadoGeo(
      nombre: 'Falcón',
      municipios: [
        MunicipioGeo(
          nombre: 'Miranda',
          parroquias: [
            ParroquiaGeo(nombre: 'Santa Ana', comunidadesSugeridas: ['Coro Casco Colonial']),
            ParroquiaGeo(nombre: 'San Antonio', comunidadesSugeridas: ['Coro Este']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Carirubana',
          parroquias: [
            ParroquiaGeo(nombre: 'Carirubana', comunidadesSugeridas: ['Punto Fijo Centro']),
            ParroquiaGeo(nombre: 'Punta Cardón', comunidadesSugeridas: ['Comunidad Cardón']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Silva',
          parroquias: [
            ParroquiaGeo(nombre: 'Tucacas', comunidadesSugeridas: ['Tucacas Centro']),
          ],
        ),
      ],
    ),
    'Táchira': const EstadoGeo(
      nombre: 'Táchira',
      municipios: [
        MunicipioGeo(
          nombre: 'San Cristóbal',
          parroquias: [
            ParroquiaGeo(nombre: 'La Concordia', comunidadesSugeridas: ['La Concordia Centro']),
            ParroquiaGeo(nombre: 'San Juan Bautista', comunidadesSugeridas: ['Barrio Obrero', 'Pirineos']),
            ParroquiaGeo(nombre: 'Pedro María Morantes', comunidadesSugeridas: ['Pueblo Nuevo']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Cárdenas',
          parroquias: [
            ParroquiaGeo(nombre: 'Táriba', comunidadesSugeridas: ['Táriba Centro']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Bolívar',
          parroquias: [
            ParroquiaGeo(nombre: 'San Antonio del Táchira', comunidadesSugeridas: ['San Antonio Centro']),
          ],
        ),
      ],
    ),
    'Mérida': const EstadoGeo(
      nombre: 'Mérida',
      municipios: [
        MunicipioGeo(
          nombre: 'Libertador',
          parroquias: [
            ParroquiaGeo(nombre: 'El Sagrario', comunidadesSugeridas: ['Mérida Casco Central']),
            ParroquiaGeo(nombre: 'Milla', comunidadesSugeridas: ['La Hechicera', 'Santa Ana']),
            ParroquiaGeo(nombre: 'Osuna Rodríguez', comunidadesSugeridas: ['Los Curos']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Campo Elías',
          parroquias: [
            ParroquiaGeo(nombre: 'Matriz', comunidadesSugeridas: ['Ejido Centro']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Alberto Adriani',
          parroquias: [
            ParroquiaGeo(nombre: 'Presidente Betancourt', comunidadesSugeridas: ['El Vigía']),
          ],
        ),
      ],
    ),
    'Bolívar': const EstadoGeo(
      nombre: 'Bolívar',
      municipios: [
        MunicipioGeo(
          nombre: 'Caroní',
          parroquias: [
            ParroquiaGeo(nombre: 'Cachamay', comunidadesSugeridas: ['Puerto Ordaz', 'Villa Central']),
            ParroquiaGeo(nombre: 'Unare', comunidadesSugeridas: ['Unare 1', 'Unare 2', 'El Guamo']),
            ParroquiaGeo(nombre: 'Dalla Costa', comunidadesSugeridas: ['San Félix']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Angostura del Orinoco',
          parroquias: [
            ParroquiaGeo(nombre: 'Catedral', comunidadesSugeridas: ['Ciudad Bolívar Casco Histórico']),
            ParroquiaGeo(nombre: 'Agua Salada', comunidadesSugeridas: ['Los Próceres']),
          ],
        ),
      ],
    ),
    'Monagas': const EstadoGeo(
      nombre: 'Monagas',
      municipios: [
        MunicipioGeo(
          nombre: 'Maturín',
          parroquias: [
            ParroquiaGeo(nombre: 'San Simón', comunidadesSugeridas: ['Maturín Centro', 'Las Avenidas']),
            ParroquiaGeo(nombre: 'Alto de Los Godos', comunidadesSugeridas: ['Los Godos']),
            ParroquiaGeo(nombre: 'Boquerón', comunidadesSugeridas: ['Tipuro', 'Palma Real']),
          ],
        ),
      ],
    ),
    'Sucre': const EstadoGeo(
      nombre: 'Sucre',
      municipios: [
        MunicipioGeo(
          nombre: 'Sucre',
          parroquias: [
            ParroquiaGeo(nombre: 'Santa Inés', comunidadesSugeridas: ['Cumaná Casco Histórico']),
            ParroquiaGeo(nombre: 'Altagracia', comunidadesSugeridas: ['Cumaná']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Bermúdez',
          parroquias: [
            ParroquiaGeo(nombre: 'Santa Catalina', comunidadesSugeridas: ['Carúpano Centro']),
          ],
        ),
      ],
    ),
    'Portuguesa': const EstadoGeo(
      nombre: 'Portuguesa',
      municipios: [
        MunicipioGeo(
          nombre: 'Páez',
          parroquias: [
            ParroquiaGeo(nombre: 'Acarigua', comunidadesSugeridas: ['Acarigua Centro', 'Baraure']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Araure',
          parroquias: [
            ParroquiaGeo(nombre: 'Araure', comunidadesSugeridas: ['Araure Centro', 'Tricentenaria']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Guanare',
          parroquias: [
            ParroquiaGeo(nombre: 'Guanare', comunidadesSugeridas: ['Guanare Centro']),
          ],
        ),
      ],
    ),
    'Barinas': const EstadoGeo(
      nombre: 'Barinas',
      municipios: [
        MunicipioGeo(
          nombre: 'Barinas',
          parroquias: [
            ParroquiaGeo(nombre: 'Barinas', comunidadesSugeridas: ['Barinas Centro']),
            ParroquiaGeo(nombre: 'Alto Barinas', comunidadesSugeridas: ['Alto Barinas Norte', 'Alto Barinas Sur']),
          ],
        ),
      ],
    ),
    'Guárico': const EstadoGeo(
      nombre: 'Guárico',
      municipios: [
        MunicipioGeo(
          nombre: 'Juan Germán Roscio',
          parroquias: [
            ParroquiaGeo(nombre: 'San Juan de los Morros', comunidadesSugeridas: ['San Juan Centro']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Francisco de Miranda',
          parroquias: [
            ParroquiaGeo(nombre: 'Calabozo', comunidadesSugeridas: ['Calabozo Centro']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Leonardo Infante',
          parroquias: [
            ParroquiaGeo(nombre: 'Valle de la Pascua', comunidadesSugeridas: ['Valle de la Pascua']),
          ],
        ),
      ],
    ),
    'Trujillo': const EstadoGeo(
      nombre: 'Trujillo',
      municipios: [
        MunicipioGeo(
          nombre: 'Valera',
          parroquias: [
            ParroquiaGeo(nombre: 'Mercedes Díaz', comunidadesSugeridas: ['Valera Centro', 'Las Acacias']),
            ParroquiaGeo(nombre: 'Juan Ignacio Montilla', comunidadesSugeridas: ['La Floresta']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Trujillo',
          parroquias: [
            ParroquiaGeo(nombre: 'Chiquinquirá', comunidadesSugeridas: ['Trujillo Capital']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Boconó',
          parroquias: [
            ParroquiaGeo(nombre: 'Boconó', comunidadesSugeridas: ['Boconó Centro']),
          ],
        ),
      ],
    ),
    'Yaracuy': const EstadoGeo(
      nombre: 'Yaracuy',
      municipios: [
        MunicipioGeo(
          nombre: 'San Felipe',
          parroquias: [
            ParroquiaGeo(nombre: 'San Felipe', comunidadesSugeridas: ['San Felipe Centro']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Independencia',
          parroquias: [
            ParroquiaGeo(nombre: 'Independencia', comunidadesSugeridas: ['Independencia']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Peña',
          parroquias: [
            ParroquiaGeo(nombre: 'Yaritagua', comunidadesSugeridas: ['Yaritagua Centro']),
          ],
        ),
      ],
    ),
    'Cojedes': const EstadoGeo(
      nombre: 'Cojedes',
      municipios: [
        MunicipioGeo(
          nombre: 'Ezequiel Zamora',
          parroquias: [
            ParroquiaGeo(nombre: 'San Carlos de Austria', comunidadesSugeridas: ['San Carlos Centro']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Tinaquillo',
          parroquias: [
            ParroquiaGeo(nombre: 'Tinaquillo', comunidadesSugeridas: ['Tinaquillo']),
          ],
        ),
      ],
    ),
    'Nueva Esparta': const EstadoGeo(
      nombre: 'Nueva Esparta',
      municipios: [
        MunicipioGeo(
          nombre: 'Mariño',
          parroquias: [
            ParroquiaGeo(nombre: 'Porlamar', comunidadesSugeridas: ['Porlamar Centro', 'Bella Vista']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Maneiro',
          parroquias: [
            ParroquiaGeo(nombre: 'Pampatar', comunidadesSugeridas: ['Pampatar', 'Playa El Ángel']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Arismendi',
          parroquias: [
            ParroquiaGeo(nombre: 'La Asunción', comunidadesSugeridas: ['La Asunción Capital']),
          ],
        ),
      ],
    ),
    'Apure': const EstadoGeo(
      nombre: 'Apure',
      municipios: [
        MunicipioGeo(
          nombre: 'San Fernando',
          parroquias: [
            ParroquiaGeo(nombre: 'San Fernando', comunidadesSugeridas: ['San Fernando Centro']),
            ParroquiaGeo(nombre: 'El Recreo', comunidadesSugeridas: ['El Recreo']),
          ],
        ),
        MunicipioGeo(
          nombre: 'Biruaca',
          parroquias: [
            ParroquiaGeo(nombre: 'Biruaca', comunidadesSugeridas: ['Biruaca Centro']),
          ],
        ),
      ],
    ),
    'La Guaira': const EstadoGeo(
      nombre: 'La Guaira',
      municipios: [
        MunicipioGeo(
          nombre: 'Vargas',
          parroquias: [
            ParroquiaGeo(nombre: 'Maiquetía', comunidadesSugeridas: ['Maiquetía Centro', 'Aeropuerto']),
            ParroquiaGeo(nombre: 'Catia La Mar', comunidadesSugeridas: ['Catia La Mar', 'Playa Grande']),
            ParroquiaGeo(nombre: 'La Guaira', comunidadesSugeridas: ['La Guaira Casco Colonial']),
            ParroquiaGeo(nombre: 'Caraballeda', comunidadesSugeridas: ['Caraballeda', 'Tanaguarena']),
            ParroquiaGeo(nombre: 'Macuto', comunidadesSugeridas: ['Macuto']),
          ],
        ),
      ],
    ),
    'Delta Amacuro': const EstadoGeo(
      nombre: 'Delta Amacuro',
      municipios: [
        MunicipioGeo(
          nombre: 'Tucupita',
          parroquias: [
            ParroquiaGeo(nombre: 'San Rafael', comunidadesSugeridas: ['Tucupita Centro']),
          ],
        ),
      ],
    ),
    'Amazonas': const EstadoGeo(
      nombre: 'Amazonas',
      municipios: [
        MunicipioGeo(
          nombre: 'Atures',
          parroquias: [
            ParroquiaGeo(nombre: 'Fernando Girón Tovar', comunidadesSugeridas: ['Puerto Ayacucho']),
          ],
        ),
      ],
    ),
  };

  /// Obtiene la lista de municipios para un estado dado.
  static List<String> municipiosDe(String? estado) {
    if (estado == null || estado.trim().isEmpty) return const [];
    final geo = buscarEstado(estado);
    if (geo != null && geo.municipios.isNotEmpty) {
      return geo.municipios.map((m) => m.nombre).toList(growable: false);
    }
    return const [];
  }

  /// Obtiene la lista de parroquias para un estado y municipio dados.
  static List<String> parroquiasDe(String? estado, String? municipio) {
    if (estado == null || municipio == null || municipio.trim().isEmpty) return const [];
    final geo = buscarEstado(estado);
    if (geo == null) return const [];
    final mun = geo.buscarMunicipio(municipio);
    if (mun == null) return const [];
    return mun.parroquias.map((p) => p.nombre).toList(growable: false);
  }

  /// Comunidades sugeridas para un estado, municipio y parroquia.
  static List<String> comunidadesSugeridasDe({
    required String? estado,
    required String? municipio,
    required String? parroquia,
  }) {
    if (estado == null || municipio == null || parroquia == null) return const [];
    final geo = buscarEstado(estado);
    if (geo == null) return const [];
    final mun = geo.buscarMunicipio(municipio);
    if (mun == null) return const [];
    final parr = mun.buscarParroquia(parroquia);
    return parr?.comunidadesSugeridas ?? const [];
  }

  /// Direcciones sugeridas para autocompletar.
  static List<String> direccionesSugeridasDe({
    required String? estado,
    required String? municipio,
    required String? parroquia,
  }) {
    if (estado == null || municipio == null || parroquia == null) return const [];
    final geo = buscarEstado(estado);
    if (geo == null) return const [];
    final mun = geo.buscarMunicipio(municipio);
    if (mun == null) return const [];
    final parr = mun.buscarParroquia(parroquia);
    return parr?.direccionesSugeridas ?? const [];
  }
}
