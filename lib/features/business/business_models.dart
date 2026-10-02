num? _n(Object? v) => v is num ? v : (v is String ? num.tryParse(v) : null);

class SellerOrder {
  SellerOrder({
    required this.id,
    required this.status,
    required this.paymentStatus,
    required this.total,
    required this.items,
    this.number,
    this.paymentMethod,
    this.buyerName,
    this.buyerPhone,
    this.address,
    this.notes,
    this.transferReference,
    this.transferBank,
    this.transferDate,
    this.trackingNumber,
  });

  final int id;
  final String? number;
  final String status;
  final String paymentStatus;
  final String? paymentMethod;
  final double total;
  final String? buyerName;
  final String? buyerPhone;
  final String? address;
  final String? notes;
  final String? transferReference;
  final String? transferBank;
  final String? transferDate;
  final String? trackingNumber;
  final List<String> items;

  String get statusLabel => const {
        'pending': 'Pendiente de pago',
        'confirmed': 'Pago confirmado',
        'processing': 'En preparación',
        'shipped': 'Enviado',
        'delivered': 'Entregado',
        'cancelled': 'Cancelado',
      }[status] ?? status;

  bool get canConfirmPayment => status == 'pending';
  bool get canProcess => status == 'confirmed';
  bool get canShip => status == 'confirmed' || status == 'processing';

  factory SellerOrder.fromJson(Map<String, dynamic> j) {
    final transfer = j['transfer'] as Map?;
    final buyer = j['buyer'] as Map?;
    return SellerOrder(
      id: j['id'] as int,
      number: j['order_number'] as String?,
      status: (j['status'] as String?) ?? 'pending',
      paymentStatus: (j['payment_status'] as String?) ?? 'pending',
      paymentMethod: j['payment_method'] as String?,
      total: _n(j['total'])?.toDouble() ?? 0,
      buyerName: buyer?['name'] as String?,
      buyerPhone: buyer?['phone'] as String?,
      address: j['shipping_address'] as String?,
      notes: j['notes'] as String?,
      transferReference: transfer?['reference'] as String?,
      transferBank: transfer?['bank'] as String?,
      transferDate: transfer?['date'] as String?,
      trackingNumber: j['tracking_number'] as String?,
      items: [for (final i in (j['items'] as List? ?? const [])) '${(i as Map)['quantity']} × ${i['name']}'],
    );
  }
}

class SellerDashboard {
  SellerDashboard({required this.orders, required this.extra});
  final Map<String, num> orders;
  final Map<String, Map<String, num>> extra; // livestock, offers, products, services, requests

  num order(String k) => orders[k] ?? 0;
  num stat(String group, String k) => extra[group]?[k] ?? 0;

  factory SellerDashboard.fromJson(Map<String, dynamic> j) {
    Map<String, num> toMap(Object? m) => {for (final e in ((m as Map?) ?? const {}).entries) '${e.key}': _n(e.value) ?? 0};
    return SellerDashboard(
      orders: toMap(j['orders']),
      extra: {for (final g in ['livestock', 'offers', 'products', 'services', 'requests']) if (j[g] != null) g: toMap(j[g])},
    );
  }
}

class BizLivestock {
  BizLivestock({required this.id, required this.title, required this.type, required this.price, required this.status, required this.views, required this.offersCount, this.breed, this.image, this.location});

  final int id;
  final String title;
  final String type;
  final double price;
  final String status;
  final int views;
  final int offersCount;
  final String? breed;
  final String? image;
  final String? location;

  String get statusLabel => livestockStatuses[status] ?? status;

  factory BizLivestock.fromJson(Map<String, dynamic> j) => BizLivestock(
        id: j['id'] as int,
        title: (j['title'] as String?) ?? 'Animal',
        type: (j['type'] as String?) ?? 'cattle',
        price: _n(j['price'])?.toDouble() ?? 0,
        status: (j['status'] as String?) ?? 'draft',
        views: _n(j['views'])?.toInt() ?? 0,
        offersCount: _n(j['offers_count'])?.toInt() ?? 0,
        breed: j['breed'] as String?,
        image: j['image'] as String?,
        location: j['location'] as String?,
      );
}

const livestockStatuses = {'active': 'Publicado', 'draft': 'Borrador', 'reserved': 'Reservado', 'sold': 'Vendido', 'inactive': 'Inactivo'};

class BizAuction {
  BizAuction({required this.id, required this.title, required this.status, required this.startingPrice, required this.currentPrice, required this.bidCount, required this.isRunning, this.endsAt, this.startsAt, this.bids = const [], this.description});

  final int id;
  final String title;
  final String status;
  final double startingPrice;
  final double currentPrice;
  final int bidCount;
  final bool isRunning;
  final DateTime? endsAt;
  final DateTime? startsAt;
  final String? description;
  final List<({String bidder, double amount})> bids;

  String get statusLabel => const {'active': 'Activa', 'draft': 'Borrador', 'cancelled': 'Cancelada', 'sold': 'Vendida', 'ended': 'Finalizada', 'unsold': 'Sin vender'}[status] ?? status;

  factory BizAuction.fromJson(Map<String, dynamic> j) => BizAuction(
        id: j['id'] as int,
        title: (j['title'] as String?) ?? 'Subasta',
        status: (j['status'] as String?) ?? 'draft',
        startingPrice: _n(j['starting_price'])?.toDouble() ?? 0,
        currentPrice: _n(j['current_price'])?.toDouble() ?? 0,
        bidCount: _n(j['bid_count'])?.toInt() ?? 0,
        isRunning: j['is_running'] == true,
        endsAt: j['ends_at'] != null ? DateTime.tryParse(j['ends_at'] as String)?.toLocal() : null,
        startsAt: j['starts_at'] != null ? DateTime.tryParse(j['starts_at'] as String)?.toLocal() : null,
        description: j['description'] as String?,
        bids: [for (final b in (j['bids'] as List? ?? const [])) (bidder: ((b as Map)['bidder'] as String?) ?? 'Comprador', amount: _n(b['amount'])?.toDouble() ?? 0)],
      );
}

class RancherOffer {
  RancherOffer({required this.id, required this.status, required this.offeredBy, required this.offerPrice, required this.awaitingYou, required this.livestockTitle, required this.livestockPrice, this.buyerName, this.message, this.response});

  final int id;
  final String status;
  final String offeredBy;
  final double offerPrice;
  final bool awaitingYou;
  final String livestockTitle;
  final double livestockPrice;
  final String? buyerName;
  final String? message;
  final String? response;

  String get statusLabel => const {'pending': 'Pendiente', 'negotiating': 'En negociación', 'accepted': 'Aceptada', 'rejected': 'Rechazada', 'cancelled': 'Cancelada'}[status] ?? status;

  factory RancherOffer.fromJson(Map<String, dynamic> j) {
    final l = (j['livestock'] as Map?) ?? const {};
    return RancherOffer(
      id: j['id'] as int,
      status: (j['status'] as String?) ?? 'pending',
      offeredBy: (j['offered_by'] as String?) ?? 'buyer',
      offerPrice: _n(j['offer_price'])?.toDouble() ?? 0,
      awaitingYou: j['awaiting_you'] == true,
      livestockTitle: (l['title'] as String?) ?? 'Animal',
      livestockPrice: _n(l['price'])?.toDouble() ?? 0,
      buyerName: (j['buyer'] as Map?)?['name'] as String?,
      message: j['message'] as String?,
      response: j['rancher_response'] as String?,
    );
  }
}

class BizProduct {
  BizProduct({required this.id, required this.name, required this.price, required this.stock, required this.status, this.unit, this.category, this.categoryId, this.image, this.description, this.location});

  final int id;
  final String name;
  final double price;
  final int stock;
  final String status;
  final String? unit;
  final String? category;
  final int? categoryId;
  final String? image;
  final String? description;
  final String? location;

  String get statusLabel => const {'available': 'Disponible', 'sold': 'Agotado', 'pending': 'Pendiente'}[status] ?? status;

  factory BizProduct.fromJson(Map<String, dynamic> j) => BizProduct(
        id: j['id'] as int,
        name: (j['name'] as String?) ?? 'Producto',
        price: _n(j['price'])?.toDouble() ?? 0,
        stock: _n(j['stock'])?.toInt() ?? 0,
        status: (j['status'] as String?) ?? 'available',
        unit: j['unit'] as String?,
        category: j['category'] as String?,
        categoryId: _n(j['category_id'])?.toInt(),
        image: j['image'] as String?,
        description: j['description'] as String?,
        location: j['location'] as String?,
      );
}

class BizService {
  BizService({required this.id, required this.title, required this.price, required this.priceType, required this.status, this.category, this.categoryId, this.description, this.requirements, this.coverageArea, this.homeVisit = false, this.emergency = false});

  final int id;
  final String title;
  final double price;
  final String priceType;
  final String status;
  final String? category;
  final int? categoryId;
  final String? description;
  final String? requirements;
  final String? coverageArea;
  final bool homeVisit;
  final bool emergency;

  String get statusLabel => const {'active': 'Activo', 'inactive': 'Inactivo', 'pending': 'Pendiente'}[status] ?? status;

  factory BizService.fromJson(Map<String, dynamic> j) => BizService(
        id: j['id'] as int,
        title: (j['title'] as String?) ?? 'Servicio',
        price: _n(j['price'])?.toDouble() ?? 0,
        priceType: (j['price_type'] as String?) ?? 'por_visita',
        status: (j['status'] as String?) ?? 'active',
        category: j['category'] as String?,
        categoryId: _n(j['service_category_id'])?.toInt(),
        description: j['description'] as String?,
        requirements: j['requirements'] as String?,
        coverageArea: j['coverage_area'] as String?,
        homeVisit: j['home_visit'] == true,
        emergency: j['emergency_service'] == true,
      );
}

const servicePriceTypes = {'por_hora': 'Por hora', 'por_visita': 'Por visita', 'precio_fijo': 'Precio fijo', 'consultar': 'A consultar'};
