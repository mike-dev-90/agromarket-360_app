class Livestock {
  Livestock({
    required this.id,
    required this.title,
    required this.type,
    required this.price,
    required this.negotiable,
    this.breed,
    this.location,
    this.image,
    this.sellerName,
    this.description,
    this.sex,
    this.weight,
    this.ageYears,
    this.healthNotes,
    this.isVaccinated = false,
    this.images = const [],
  });

  final int id;
  final String title;
  final String type;
  final double price;
  final bool negotiable;
  final String? breed;
  final String? location;
  final String? image;
  final String? sellerName;
  final String? description;
  final String? sex;
  final num? weight;
  final int? ageYears;
  final String? healthNotes;
  final bool isVaccinated;
  final List<String> images;

  factory Livestock.fromJson(Map<String, dynamic> j) => Livestock(
        id: j['id'] as int,
        title: j['title'] as String,
        type: j['type'] as String,
        price: (j['price'] as num).toDouble(),
        negotiable: j['negotiable'] == true,
        breed: j['breed'] as String?,
        location: j['location'] as String?,
        image: j['image'] as String?,
        sellerName: (j['seller'] as Map?)?['name'] as String?,
        description: j['description'] as String?,
        sex: j['sex'] as String?,
        weight: j['weight'] as num?,
        ageYears: j['age_years'] as int?,
        healthNotes: j['health_notes'] as String?,
        isVaccinated: j['is_vaccinated'] == true,
        images: [for (final i in (j['images'] as List? ?? const [])) '$i'],
      );
}

const livestockTypes = {
  'cattle': 'Bovino',
  'pig': 'Porcino',
  'sheep': 'Ovino',
  'goat': 'Caprino',
  'horse': 'Equino',
};
