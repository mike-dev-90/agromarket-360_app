num? _n(Object? v) => v is num ? v : (v is String ? num.tryParse(v) : null);

class ServiceItem {
  ServiceItem({
    required this.id,
    required this.title,
    required this.price,
    this.priceType,
    this.category,
    this.image,
    this.description,
    this.requirements,
    this.coverageArea,
    this.homeVisit = false,
    this.emergencyService = false,
    this.professionalName,
    this.profession,
  });

  final int id;
  final String title;
  final double price;
  final String? priceType;
  final String? category;
  final String? image;
  final String? description;
  final String? requirements;
  final String? coverageArea;
  final bool homeVisit;
  final bool emergencyService;
  final String? professionalName;
  final String? profession;

  String get priceLabel {
    final suffix = const {'por_hora': ' / hora', 'por_visita': ' / visita', 'precio_fijo': '', 'consultar': ' (a consultar)'}[priceType] ?? '';
    return '\$${price.toStringAsFixed(2)}$suffix';
  }

  factory ServiceItem.fromJson(Map<String, dynamic> j) {
    final pro = j['professional'] as Map?;
    return ServiceItem(
      id: j['id'] as int,
      title: (j['title'] as String?) ?? 'Servicio',
      price: _n(j['price'])?.toDouble() ?? 0,
      priceType: j['price_type'] as String?,
      category: j['category'] as String?,
      image: j['image'] as String?,
      description: j['description'] as String?,
      requirements: j['requirements'] as String?,
      coverageArea: j['coverage_area'] as String?,
      homeVisit: j['home_visit'] == true,
      emergencyService: j['emergency_service'] == true,
      professionalName: pro?['name'] as String?,
      profession: pro?['profession'] as String?,
    );
  }
}

class ServiceRequestItem {
  ServiceRequestItem({
    required this.id,
    required this.status,
    required this.serviceTitle,
    required this.description,
    this.requestDate,
    this.location,
    this.scheduledDate,
    this.priceQuoted,
    this.responseMessage,
    this.notes,
    this.otherParty,
    this.preferredTime,
  });

  final int id;
  final String status;
  final String serviceTitle;
  final String description;
  final String? requestDate;
  final String? location;
  final DateTime? scheduledDate;
  final double? priceQuoted;
  final String? responseMessage;
  final String? notes;
  final String? otherParty; // profesional (para el cliente) o cliente (para el profesional)
  final String? preferredTime;

  String get statusLabel => const {
        'pending': 'Pendiente',
        'accepted': 'Aceptada',
        'scheduled': 'Programada',
        'completed': 'Completada',
        'rejected': 'Rechazada',
        'cancelled': 'Cancelada',
        'in_progress': 'En curso',
      }[status] ?? status;

  bool get clientCanCancel => const ['pending', 'accepted', 'scheduled'].contains(status);

  factory ServiceRequestItem.fromJson(Map<String, dynamic> j) => ServiceRequestItem(
        id: j['id'] as int,
        status: (j['status'] as String?) ?? 'pending',
        serviceTitle: (j['service_title'] as String?) ?? 'Servicio',
        description: (j['description'] as String?) ?? '',
        requestDate: j['request_date'] as String?,
        location: j['location'] as String?,
        scheduledDate: j['scheduled_date'] != null ? DateTime.tryParse(j['scheduled_date'] as String)?.toLocal() : null,
        priceQuoted: _n(j['price_quoted'])?.toDouble(),
        responseMessage: j['response_message'] as String?,
        notes: j['notes'] as String?,
        preferredTime: j['preferred_time'] as String?,
        otherParty: ((j['professional'] ?? j['client']) as Map?)?['name'] as String?,
      );
}
