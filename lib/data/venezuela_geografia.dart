/// División político-territorial y catálogo geográfico institucional de Venezuela.
///
/// Proporciona la jerarquía: Estado -> Municipio -> Parroquia -> Comunidades sugeridas,
/// con especial granularidad en el estado Carabobo (sede del CFS Rafael Urdaneta / La Isabelica)
/// y cobertura de todas las entidades federales de Venezuela.
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
    final limpio = nombreParroquia.trim().toLowerCase();
    for (final p in parroquias) {
      if (p.nombre.toLowerCase() == limpio) return p;
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
    final limpio = nombreMunicipio.trim().toLowerCase();
    for (final m in municipios) {
      if (m.nombre.toLowerCase() == limpio) return m;
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
      ],
    ),
  };

  /// Obtiene la lista de municipios para un estado dado.
  static List<String> municipiosDe(String? estado) {
    if (estado == null || estado.trim().isEmpty) return const [];
    final geo = _datos[estado.trim()];
    if (geo != null) {
      return geo.municipios.map((m) => m.nombre).toList(growable: false);
    }
    return [
      'Municipio Capital',
      'Municipio Centro',
      'Municipio Foráneo',
    ];
  }

  /// Obtiene la lista de parroquias para un estado y municipio dados.
  static List<String> parroquiasDe(String? estado, String? municipio) {
    if (estado == null || municipio == null) return const [];
    final geo = _datos[estado.trim()];
    if (geo == null) {
      return ['Parroquia Principal', 'Parroquia Central'];
    }
    final mun = geo.buscarMunicipio(municipio);
    if (mun == null) {
      return ['Parroquia Central'];
    }
    return mun.parroquias.map((p) => p.nombre).toList(growable: false);
  }

  /// Comunidades sugeridas para un estado, municipio y parroquia.
  static List<String> comunidadesSugeridasDe({
    required String? estado,
    required String? municipio,
    required String? parroquia,
  }) {
    if (estado == null || municipio == null || parroquia == null) return const [];
    final geo = _datos[estado.trim()];
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
    final geo = _datos[estado.trim()];
    if (geo == null) return const [];
    final mun = geo.buscarMunicipio(municipio);
    if (mun == null) return const [];
    final parr = mun.buscarParroquia(parroquia);
    return parr?.direccionesSugeridas ?? const [];
  }
}
