import 'package:agromarket_360_app/core/api_client.dart';
import 'package:agromarket_360_app/core/photo_picker.dart';
import 'package:agromarket_360_app/features/auth/auth_controller.dart';

const longTitle = 'Toro Brahman reproductor de excelente genética certificado con pedigrí y vacunas al día';

class MemoryTokens extends TokenStorage {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String t) async => token = t;
  @override
  Future<void> clear() async => token = null;
}

/// Servidor falso con estado: imita las reglas principales de la API real.
class FakeApi extends ApiClient {
  FakeApi({bool loggedIn = false, MemoryTokens? tokens})
      : tokens_ = tokens ?? MemoryTokens(),
        super(tokens ?? MemoryTokens()) {
    if (loggedIn) tokens_.token = 'tok';
  }

  final MemoryTokens tokens_;
  final calls = <String>[];
  Map<String, dynamic>? lastCheckout;
  Map<String, dynamic>? lastRegister;
  Map<String, dynamic>? lastAuctionPayload;
  Map<String, dynamic>? lastLivestockForm;
  Map<String, dynamic>? lastProductForm;
  Map<String, dynamic>? lastServiceForm;
  Map<String, dynamic>? lastSchedule;

  @override
  TokenStorage get tokens => tokens_;

  bool get _auth => tokens_.token != null;

  // Estado
  int? favoriteId;
  final favorites = <Map<String, dynamic>>[];
  final offers = <Map<String, dynamic>>[];
  final orders = <Map<String, dynamic>>[];
  final notifications = <Map<String, dynamic>>[
    {'id': 1, 'type': 'info', 'title': 'Oferta aceptada', 'message': 'El vendedor aceptó tu oferta', 'is_read': false, 'created_at': '2026-10-02T10:00:00Z'},
    {'id': 2, 'type': 'info', 'title': 'Pedido enviado', 'message': 'Tu pedido va en camino', 'is_read': false, 'created_at': '2026-10-02T11:00:00Z'},
  ];
  double auctionPrice = 500;
  final bids = <Map<String, dynamic>>[];
  bool bankConfigured = true;

  // Negocio (vendedores)
  final sellerOrders = <Map<String, dynamic>>[];
  final myLivestock = <Map<String, dynamic>>[];
  final myAuctions = <Map<String, dynamic>>[];
  final rancherOffers = <Map<String, dynamic>>[];
  final myProducts = <Map<String, dynamic>>[];
  final myServices = <Map<String, dynamic>>[];
  final proRequests = <Map<String, dynamic>>[];
  final businessProfile = <String, dynamic>{'complete': false};
  int nextId = 100;

  // Servicios y mensajes
  Map<String, dynamic> service(int id) => {'id': id, 'title': id == 1 ? 'Vacunación y desparasitación completa de hatos bovinos con certificado sanitario' : 'Servicio $id', 'price': 25.0 * id, 'price_type': 'por_visita', 'category': 'Veterinaria General', 'image': null};
  final serviceRequests = <Map<String, dynamic>>[];
  final chat = <Map<String, dynamic>>[];

  // Insumos y carrito
  Map<String, dynamic> product(int id) => {
        'id': id, 'name': id == 1 ? 'Sal mineral para ganado bovino de engorde, bolsa de 25 kilos' : 'Balanceado $id', 'price': 10.5 * id, 'unit': 'bolsa', 'stock': id == 3 ? 0 : 5,
        'location': 'Quito', 'category': 'Alimentos y suplementos', 'image': null,
      };
  final cartItems = <Map<String, dynamic>>[];
  int cartSeq = 0;
  Map<String, dynamic> cartPayload() {
    final lines = [for (final i in cartItems) {...i, 'total': (i['unit_price'] as double) * (i['quantity'] as int)}];
    final total = lines.fold<double>(0, (a, l) => a + (l['total'] as double));
    return {'items': lines, 'item_count': lines.length, 'subtotal': total, 'total': total};
  }
  String livestockStatus = 'active';

  bool identityVerified = true;
  String verificationStatus = 'verified';
  int verificationAttempts = 0;
  String? rejectionReason;
  List<String> missingProfile = [];
  final profile = <String, dynamic>{'name': 'Comprador Test', 'email': 'comprador@test.com', 'phone': '0991234567', 'whatsapp': null, 'address': null, 'city': 'Quito', 'state': 'Pichincha', 'purchase_purpose': 'cria'};
  String password = 'secreta123';
  final formCalls = <Map<String, dynamic>>[];

  List<String> roles = ['buyer'];

  Map<String, dynamic> get user => {'id': 7, ...profile, 'user_type': 'buyer', 'roles': roles, 'identity_verified': identityVerified, 'missing_profile': missingProfile};

  Map<String, dynamic> verificationPayload() => {
        'status': verificationStatus, 'document_type': null, 'document_number': null, 'attempts': verificationAttempts,
        'remaining_attempts': 3 - verificationAttempts, 'rejection_reason': rejectionReason,
        'can_submit': verificationStatus != 'verified' && verificationAttempts < 3, 'missing_profile': missingProfile, 'identity_verified': identityVerified,
      };

  Map<String, dynamic> animal(int id) => {
        'id': id, 'title': id == 1 ? longTitle : 'Vaca $id', 'type': 'cattle', 'breed': 'Brahman', 'price': 2000.0, 'negotiable': true,
        'location': 'Guayaquil, Guayas', 'province': 'Guayas', 'image': null, 'seller': {'id': 1, 'name': 'Hacienda La Esperanza'},
      };

  Never _unauth() => throw ApiException('Unauthenticated.', statusCode: 401);
  Never _fail(String m) => throw ApiException(m, statusCode: 422);

  Map<String, dynamic> offerPayload(Map<String, dynamic> o) => {
        ...o,
        'awaiting_buyer': o['status'] == 'negotiating' && o['offered_by'] == 'rancher',
        'livestock': {'id': 1, 'title': longTitle, 'price': 2000.0, 'status': livestockStatus, 'image': null},
      };

  Map<String, dynamic> orderPayload(Map<String, dynamic> o) => {...o, 'bank': bankConfigured ? {'name': 'Banco Pichincha', 'account_type': 'Ahorros', 'account_number': '2200123456', 'account_holder': 'AgroMarket 360 S.A.', 'tax_id': '1790012345001'} : {'name': null, 'account_number': null}};

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    calls.add('GET $path');
    final now = DateTime.now().toUtc();
    if (path == '/auth/me') return _auth ? {'user': user} : _unauth();
    if (path == '/profile') return _auth ? {'data': user} : _unauth();
    if (path == '/verification') return _auth ? {'data': verificationPayload()} : _unauth();
    if (path == '/livestock') {
      return {
        'data': [for (var i = 1; i <= 6; i++) animal(i)],
        'meta': {'current_page': 1, 'last_page': 1, 'total': 6},
      };
    }
    if (path.startsWith('/livestock/')) {
      final id = int.parse(path.split('/').last);
      return {'data': {...animal(id), 'description': longTitle * 2, 'sex': 'male', 'age_years': 2, 'weight': 400, 'is_vaccinated': true, 'health_notes': longTitle, 'images': <String>[], 'favorite_id': _auth ? favoriteId : null}};
    }
    if (path == '/seller/dashboard') {
      return {'data': {
        'orders': {'total': sellerOrders.length, 'pending': sellerOrders.where((o) => o['status'] == 'pending').length, 'in_progress': 1, 'delivered': 0, 'revenue': 1234567.5},
        'livestock': {'total': myLivestock.length, 'active': myLivestock.where((l) => l['status'] == 'active').length, 'sold': 0},
        'offers': {'total': rancherOffers.length, 'awaiting_you': rancherOffers.where((o) => o['awaiting_you'] == true).length},
        'products': {'total': myProducts.length, 'available': myProducts.length},
        'services': {'total': myServices.length},
        'requests': {'pending': proRequests.where((r) => r['status'] == 'pending').length, 'completed': 0},
      }};
    }
    if (path == '/seller/orders') {
      final st = query?['status'];
      final list = sellerOrders.where((o) => st == null || o['status'] == st).toList();
      return {'data': list, 'meta': {'current_page': 1, 'last_page': 1}};
    }
    if (path == '/rancher/livestock') {
      final st = query?['status'];
      return {'data': myLivestock.where((l) => st == null || l['status'] == st).toList(), 'meta': {'current_page': 1, 'last_page': 1, 'total': myLivestock.length}};
    }
    if (RegExp(r'^/rancher/livestock/\d+$').hasMatch(path)) return {'data': myLivestock.firstWhere((l) => '${l['id']}' == path.split('/').last)};
    if (path == '/rancher/auctions') return {'data': myAuctions, 'meta': {'current_page': 1, 'last_page': 1}};
    if (RegExp(r'^/rancher/auctions/\d+$').hasMatch(path)) return {'data': myAuctions.firstWhere((a) => '${a['id']}' == path.split('/').last)};
    if (path == '/rancher/offers') {
      final st = query?['status'];
      return {'data': rancherOffers.where((o) => st == null || o['status'] == st).toList(), 'meta': {'current_page': 1, 'last_page': 1}};
    }
    if (path == '/supplier/products') return {'data': myProducts, 'meta': {'current_page': 1, 'last_page': 1, 'total': myProducts.length}};
    if (RegExp(r'^/supplier/products/\d+$').hasMatch(path)) return {'data': myProducts.firstWhere((p) => '${p['id']}' == path.split('/').last)};
    if (path == '/professional/services') return {'data': myServices, 'meta': {'current_page': 1, 'last_page': 1, 'total': myServices.length}};
    if (RegExp(r'^/professional/services/\d+$').hasMatch(path)) return {'data': myServices.firstWhere((p) => '${p['id']}' == path.split('/').last)};
    if (path == '/professional/requests') {
      final st = query?['status'];
      return {'data': proRequests.where((r) => st == null || r['status'] == st).toList(), 'meta': {'current_page': 1, 'last_page': 1}};
    }
    if (const ['/rancher/profile', '/supplier/profile', '/professional/profile'].contains(path)) return {'data': businessProfile};
    if (path == '/product-categories') return {'data': [{'id': 1, 'name': 'Alimentos y suplementos'}, {'id': 2, 'name': 'Medicamentos'}]};
    if (path == '/service-categories') return {'data': [{'id': 1, 'name': 'Veterinaria General'}, {'id': 2, 'name': 'Nutrición'}]};
    if (path == '/services') {
      final cat = query?['category_id'];
      final all = [for (var i = 1; i <= 3; i++) service(i)].where((s) => cat == null || (cat == '1' && (s['id'] as int).isOdd)).toList();
      return {'data': all, 'meta': {'current_page': 1, 'last_page': 1, 'total': all.length}};
    }
    if (path.startsWith('/services/')) return {'data': {...service(int.parse(path.split('/').last)), 'description': 'Vacunación completa.', 'requirements': 'Corrales en buen estado', 'coverage_area': 'Costa y Sierra', 'home_visit': true, 'emergency_service': true, 'professional': {'id': 5, 'name': 'Dr. Roberto Sánchez', 'profession': 'Veterinario'}}};
    if (path == '/products') {
      final search = (query?['search'] as String?)?.toLowerCase();
      final all = [for (var i = 1; i <= 4; i++) product(i)].where((p) => search == null || (p['name'] as String).toLowerCase().contains(search)).toList();
      return {'data': all, 'meta': {'current_page': 1, 'last_page': 1, 'total': all.length}};
    }
    if (path.startsWith('/products/')) return {'data': {...product(int.parse(path.split('/').last)), 'description': 'Suplemento mineral completo para todo tipo de ganado.', 'seller': {'id': 9, 'name': 'Agro Insumos SA'}}};
    if (path == '/auctions') {
      return {'data': [for (var i = 1; i <= 3; i++) _auction(i, now, withDetail: false)], 'meta': {'current_page': 1, 'last_page': 1, 'server_time': now.toIso8601String()}};
    }
    if (path.startsWith('/auctions/')) return {'data': _auction(1, now, withDetail: true)};
    if (!_auth) _unauth();
    if (path == '/favorites') return {'data': favorites};
    if (path == '/service-requests') return {'data': serviceRequests, 'meta': {'current_page': 1, 'last_page': 1}};
    final msgs = RegExp(r'^/orders/(\d+)/messages$').firstMatch(path);
    if (msgs != null) return {'data': chat, 'meta': {'other_user': {'id': 2, 'name': 'Hacienda La Esperanza'}, 'order_number': 'AGM-0005'}};
    if (path == '/cart') return {'data': cartPayload()};
    if (path == '/offers') return {'data': [for (final o in offers) offerPayload(o)]};
    if (path.startsWith('/offers/')) return {'data': offerPayload(offers.firstWhere((o) => '${o['id']}' == path.split('/').last))};
    if (path == '/orders') return {'data': [for (final o in orders) orderPayload(o)]};
    if (path.startsWith('/orders/')) return {'data': orderPayload(orders.firstWhere((o) => '${o['id']}' == path.split('/').last))};
    if (path == '/notifications') return {'data': notifications, 'meta': {'unread': notifications.where((n) => n['is_read'] != true).length}};
    throw ApiException('No encontrado', statusCode: 404);
  }

  Map<String, dynamic> _auction(int id, DateTime now, {required bool withDetail}) {
    final minimum = bids.isEmpty ? 500.0 : auctionPrice + 25;
    return {
      'id': id, 'title': id == 1 ? longTitle : 'Lote $id', 'type': 'cattle', 'breed': 'Brahman', 'image': null, 'starting_price': 500.0,
      'current_price': auctionPrice, 'min_bid_increment': 25.0, 'bid_count': bids.length, 'status': 'active', 'is_running': true,
      'ends_at': now.add(const Duration(hours: 5)).toIso8601String(), 'starts_at': now.toIso8601String(), 'server_time': now.toIso8601String(),
      if (withDetail) ...{
        'description': longTitle, 'location': 'Guayaquil', 'minimum_next_bid': minimum,
        'my_highest_bid': bids.isEmpty ? null : auctionPrice,
        'bids': [for (final b in bids.reversed) {'amount': b['amount'], 'bidder': 'Tú', 'is_mine': true}],
      },
    };
  }

  @override
  Future<Map<String, dynamic>> post(String path, {Object? data}) async {
    calls.add('POST $path');
    final body = (data is Map ? data.cast<String, dynamic>() : <String, dynamic>{});

    if (path == '/auth/login') {
      if (body['password'] != 'secreta123') throw ApiException('Las credenciales no coinciden con nuestros registros.', statusCode: 422);
      tokens_.token = 'tok';
      return {'token': 'tok', 'user': user};
    }
    if (path == '/auth/register') {
      lastRegister = body;
      if (body['email'] == 'repetido@test.com') throw ApiException('The email has already been taken.', statusCode: 422);
      tokens_.token = 'tok';
      return {'token': 'tok', 'user': {...user, 'name': body['name']}};
    }
    if (path == '/auth/logout') {
      tokens_.token = null;
      return {'message': 'ok'};
    }
    if (!_auth) _unauth();

    if (path == '/favorites') {
      favoriteId = 99;
      favorites.add({'id': 99, 'type': 'livestock', 'item_id': body['item_id'], 'title': animal(body['item_id'] as int)['title'], 'price': 2000.0});
      return {'id': 99};
    }
    final sellerAct = RegExp(r'^/seller/orders/(\d+)/(confirm-payment|process|ship)$').firstMatch(path);
    if (sellerAct != null) {
      final o = sellerOrders.firstWhere((o) => '${o['id']}' == sellerAct.group(1));
      switch (sellerAct.group(2)) {
        case 'confirm-payment':
          if (o['status'] != 'pending') _fail('Este pedido ya no está pendiente de pago.');
          o..['status'] = 'confirmed'..['payment_status'] = 'paid';
        case 'process':
          if (o['status'] != 'confirmed') _fail('Primero debes confirmar el pago.');
          o['status'] = 'processing';
        case 'ship':
          if (o['status'] != 'confirmed' && o['status'] != 'processing') _fail('Solo se pueden enviar pedidos con el pago confirmado.');
          o..['status'] = 'shipped'..['tracking_number'] = body['tracking_number'];
      }
      return {'data': o};
    }
    if (path == '/rancher/auctions') {
      if ((body['title'] as String?)?.isEmpty ?? true) _fail('El título es obligatorio.');
      final a = {'id': ++nextId, 'title': body['title'], 'description': body['description'], 'status': body['status'] == 'pending' ? 'active' : 'draft', 'starting_price': double.parse('${body['starting_price']}'), 'current_price': double.parse('${body['starting_price']}'), 'min_bid_increment': 25.0, 'bid_count': 0, 'is_running': true, 'starts_at': body['start_time'], 'ends_at': body['end_time'], 'bids': <Map<String, dynamic>>[], 'location': body['location']};
      myAuctions.add(a);
      lastAuctionPayload = body;
      return {'data': a};
    }
    final aCancel = RegExp(r'^/rancher/auctions/(\d+)/cancel$').firstMatch(path);
    if (aCancel != null) {
      final a = myAuctions.firstWhere((a) => '${a['id']}' == aCancel.group(1));
      if ((a['bids'] as List).isNotEmpty) _fail('No puedes cancelar una subasta que ya tiene pujas.');
      a['status'] = 'cancelled';
      return {'data': a};
    }
    final offerAct = RegExp(r'^/rancher/offers/(\d+)/(accept|reject|negotiate)$').firstMatch(path);
    if (offerAct != null) {
      final o = rancherOffers.firstWhere((o) => '${o['id']}' == offerAct.group(1));
      if (o['awaiting_you'] != true) _fail('Esta oferta no está esperando tu respuesta.');
      switch (offerAct.group(2)) {
        case 'accept':
          o..['status'] = 'accepted'..['awaiting_you'] = false;
        case 'reject':
          if ((body['rancher_response'] as String?)?.isEmpty ?? true) _fail('Indica el motivo.');
          o..['status'] = 'rejected'..['awaiting_you'] = false..['rancher_response'] = body['rancher_response'];
        case 'negotiate':
          o..['status'] = 'negotiating'..['offered_by'] = 'rancher'..['offer_price'] = body['offer_price']..['awaiting_you'] = false;
      }
      return {'data': o};
    }
    final reqAct = RegExp(r'^/professional/requests/(\d+)/(accept|reject|schedule|complete)$').firstMatch(path);
    if (reqAct != null) {
      final r = proRequests.firstWhere((r) => '${r['id']}' == reqAct.group(1));
      switch (reqAct.group(2)) {
        case 'accept':
          if (r['status'] != 'pending') _fail('Solo se pueden aceptar solicitudes pendientes.');
          r['status'] = 'accepted';
        case 'reject':
          if ((body['response_message'] as String?)?.isEmpty ?? true) _fail('Indica el motivo.');
          r..['status'] = 'rejected'..['response_message'] = body['response_message'];
        case 'schedule':
          r..['status'] = 'scheduled'..['scheduled_date'] = '2030-01-14T10:00:00Z'..['price_quoted'] = body['price_quoted'];
          lastSchedule = body;
        case 'complete':
          if (r['status'] != 'accepted' && r['status'] != 'scheduled') _fail('Solo se pueden completar solicitudes aceptadas o programadas.');
          r['status'] = 'completed';
      }
      return {'data': r};
    }
    final svcReq = RegExp(r'^/services/(\d+)/requests$').firstMatch(path);
    if (svcReq != null) {
      if (((body['description'] as String?) ?? '').length < 10) _fail('The description field must be at least 10 characters.');
      serviceRequests.add({'id': serviceRequests.length + 1, 'status': 'pending', 'service_title': service(int.parse(svcReq.group(1)!))['title'], 'description': body['description'], 'request_date': body['request_date'], 'preferred_time': body['preferred_time'], 'location': body['location'], 'scheduled_date': null, 'price_quoted': null, 'response_message': null, 'professional': {'id': 5, 'name': 'Dr. Roberto Sánchez'}});
      return {'data': serviceRequests.last};
    }
    final cancelReq = RegExp(r'^/service-requests/(\d+)/cancel$').firstMatch(path);
    if (cancelReq != null) {
      serviceRequests.firstWhere((r) => '${r['id']}' == cancelReq.group(1))['status'] = 'cancelled';
      return {'data': serviceRequests.first};
    }
    final sendMsg = RegExp(r'^/orders/(\d+)/messages$').firstMatch(path);
    if (sendMsg != null) {
      if (((body['message'] as String?) ?? '').trim().isEmpty) _fail('The message field is required.');
      chat.add({'id': chat.length + 1, 'message': body['message'], 'is_mine': true, 'sender': 'Comprador Test'});
      return {'data': chat.last};
    }
    if (path == '/cart/items') {
      final id = body['product_id'] as int;
      final qty = body['quantity'] as int;
      final p = product(id);
      final existing = cartItems.where((i) => i['product_id'] == id).firstOrNull;
      final newQty = (existing?['quantity'] as int? ?? 0) + qty;
      if (newQty > (p['stock'] as int)) _fail('Solo hay ${p['stock']} disponibles de este producto.');
      if (existing != null) {
        existing['quantity'] = newQty;
      } else {
        cartItems.add({'id': ++cartSeq, 'product_id': id, 'name': p['name'], 'image': null, 'unit': 'bolsa', 'quantity': newQty, 'unit_price': (p['price'] as double), 'stock': p['stock']});
      }
      return {'data': cartPayload()};
    }
    if (path == '/checkout') {
      if (!identityVerified) throw ApiException('Debes verificar tu identidad para comprar.', statusCode: 403);
      if (cartItems.isEmpty) _fail('Tu carrito está vacío.');
      for (final k in ['shipping_address', 'shipping_city', 'shipping_state', 'phone']) {
        if ((body[k] as String?)?.isEmpty ?? true) _fail('Falta $k.');
      }
      final bySeller = <int, List<Map<String, dynamic>>>{};
      for (final i in cartItems) {
        bySeller.putIfAbsent((i['product_id'] as int) % 2, () => []).add(i);
      }
      final created = <Map<String, dynamic>>[];
      for (final group in bySeller.values) {
        final total = group.fold<double>(0, (a, l) => a + (l['unit_price'] as double) * (l['quantity'] as int));
        final id = 20 + orders.length;
        orders.add({'id': id, 'order_number': 'AGM-$id', 'status': 'pending', 'payment_status': 'pending', 'payment_method': body['payment_method'], 'total': total, 'transfer_reference': null, 'items': [for (final l in group) {'name': l['name'], 'quantity': l['quantity'], 'unit_price': l['unit_price'], 'total': (l['unit_price'] as double) * (l['quantity'] as int)}]});
        created.add({'id': id, 'order_number': 'AGM-$id', 'total': total, 'status': 'pending'});
      }
      lastCheckout = body;
      cartItems.clear();
      return {'data': created};
    }
    if (path == '/offers') {
      if ((body['offer_price'] as num) < 100) _fail('La oferta es demasiado baja.');
      offers.add({'id': 1, 'status': 'pending', 'offered_by': 'buyer', 'offer_price': body['offer_price'], 'message': null, 'rancher_response': null});
      return {'data': offerPayload(offers.last)};
    }
    final offerAction = RegExp(r'^/offers/(\d+)/(accept|reject|counter)$').firstMatch(path);
    if (offerAction != null) {
      final o = offers.firstWhere((o) => '${o['id']}' == offerAction.group(1));
      switch (offerAction.group(2)) {
        case 'accept':
          o['status'] = 'accepted';
        case 'reject':
          o['status'] = 'rejected';
        case 'counter':
          o..['status'] = 'pending'..['offered_by'] = 'buyer'..['offer_price'] = body['offer_price'];
      }
      return {'data': offerPayload(o)};
    }
    if (path == '/orders') {
      final price = body['offer_id'] != null ? offers.first['offer_price'] : 2000.0;
      orders.add({'id': 5, 'order_number': 'AGM-0005', 'status': 'pending', 'payment_status': 'pending', 'payment_method': 'transfer', 'total': price, 'transfer_reference': null, 'items': [{'name': longTitle, 'quantity': 1, 'unit_price': price, 'total': price}]});
      return {'data': orderPayload(orders.last)};
    }
    final orderAction = RegExp(r'^/orders/(\d+)/(transfer-proof|cancel|confirm-delivery)$').firstMatch(path);
    if (orderAction != null) {
      final o = orders.firstWhere((o) => '${o['id']}' == orderAction.group(1));
      switch (orderAction.group(2)) {
        case 'transfer-proof':
          if ((body['reference_number'] as String?)?.isEmpty ?? true) _fail('La referencia es obligatoria.');
          o['transfer_reference'] = body['reference_number'];
        case 'cancel':
          o['status'] = 'cancelled';
        case 'confirm-delivery':
          if (o['status'] != 'shipped') _fail('Solo se puede confirmar la recepción de pedidos enviados.');
          o['status'] = 'delivered';
      }
      return {'data': orderPayload(o)};
    }
    if (path == '/notifications/read-all') {
      for (final n in notifications) {
        n['is_read'] = true;
      }
      return {'message': 'ok'};
    }
    final read = RegExp(r'^/notifications/(\d+)/read$').firstMatch(path);
    if (read != null) {
      notifications.firstWhere((n) => '${n['id']}' == read.group(1))['is_read'] = true;
      return {'message': 'ok'};
    }
    final bid = RegExp(r'^/auctions/(\d+)/bids$').firstMatch(path);
    if (bid != null) {
      final amount = (body['amount'] as num).toDouble();
      final minimum = bids.isEmpty ? 500.0 : auctionPrice + 25;
      if (amount < minimum) _fail('La puja mínima es \$${minimum.toStringAsFixed(2)}');
      auctionPrice = amount;
      bids.add({'amount': amount});
      return {'data': _auction(1, DateTime.now().toUtc(), withDetail: true)};
    }
    throw ApiException('No encontrado', statusCode: 404);
  }

  @override
  Future<Map<String, dynamic>> put(String path, {Object? data}) async {
    calls.add('PUT $path');
    if (!_auth) _unauth();
    final body = (data is Map ? data.cast<String, dynamic>() : <String, dynamic>{});
    if (path == '/profile') {
      if (!(body['email'] as String).contains('@')) throw ApiException('El correo no es válido.', statusCode: 422);
      if (body['email'] == 'ocupado@test.com') throw ApiException('The email has already been taken.', statusCode: 422);
      profile.addAll({for (final k in ['name', 'email', 'phone', 'whatsapp', 'address', 'city', 'state']) k: body[k]});
      if (body['purchase_purpose'] != null) {
        profile['purchase_purpose'] = body['purchase_purpose'];
        missingProfile = missingProfile.where((m) => m != 'purchase_purpose').toList();
      }
      return {'data': user};
    }
    if (path.startsWith('/cart/items/')) {
      final item = cartItems.firstWhere((i) => '${i['id']}' == path.split('/').last);
      final q = body['quantity'] as int;
      if (q > (item['stock'] as int)) _fail('Solo hay ${item['stock']} disponibles de este producto.');
      item['quantity'] = q;
      return {'data': cartPayload()};
    }
    if (const ['/rancher/profile', '/supplier/profile', '/professional/profile'].contains(path)) {
      businessProfile.addAll(body);
      businessProfile['complete'] = body.values.where((v) => v != null && v != '' && !(v is List && v.isEmpty)).length >= 5;
      return {'data': businessProfile};
    }
    final auctionPut = RegExp(r'^/rancher/auctions/(\d+)$').firstMatch(path);
    if (auctionPut != null) {
      final a = myAuctions.firstWhere((a) => '${a['id']}' == auctionPut.group(1));
      a..['title'] = body['title']..['description'] = body['description'];
      lastAuctionPayload = body;
      return {'data': a};
    }
    if (path == '/profile/password') {
      if (body['current_password'] != password) throw ApiException('La contraseña actual no es correcta.', statusCode: 422);
      password = body['password'] as String;
      return {'message': 'ok'};
    }
    throw ApiException('No encontrado', statusCode: 404);
  }

  @override
  Future<Map<String, dynamic>> postForm(String path, {Map<String, String> fields = const {}, Map<String, String> files = const {}}) async {
    calls.add('POST(form) $path');
    if (!_auth) _unauth();
    formCalls.add({'path': path, 'fields': fields, 'files': files});
    if (path == '/rancher/livestock' || RegExp(r'^/rancher/livestock/\d+$').hasMatch(path)) {
      final creating = path == '/rancher/livestock';
      if (creating && !files.containsKey('main_image')) throw ApiException('The main image field is required.', statusCode: 422);
      if (fields['title']?.isEmpty ?? true) throw ApiException('The title field is required.', statusCode: 422);
      lastLivestockForm = {'fields': fields, 'files': files};
      if (creating) {
        final l = {'id': ++nextId, 'title': fields['title'], 'type': fields['type'], 'breed': fields['breed'], 'price': double.parse(fields['price']!), 'status': fields['status'], 'negotiable': fields['negotiable'] == '1', 'location': '${fields['city']}, ${fields['location']}', 'province': fields['location'], 'image': null, 'views': 0, 'offers_count': 0, 'description': fields['description'], 'sex': fields['sex'], 'age_years': null, 'age_months': null, 'weight': null, 'is_vaccinated': fields['is_vaccinated'] == '1', 'has_pedigree': false, 'health_notes': null, 'purpose': null, 'images': <Map<String, dynamic>>[]};
        myLivestock.add(l);
        return {'data': l};
      }
      final l = myLivestock.firstWhere((l) => '${l['id']}' == path.split('/').last);
      l..['title'] = fields['title']..['price'] = double.parse(fields['price']!)..['status'] = fields['status'];
      return {'data': l};
    }
    if (path == '/supplier/products' || RegExp(r'^/supplier/products/\d+$').hasMatch(path)) {
      if (fields['name']?.isEmpty ?? true) throw ApiException('The name field is required.', statusCode: 422);
      lastProductForm = {'fields': fields, 'files': files};
      if (path == '/supplier/products') {
        final p = {'id': ++nextId, 'name': fields['name'], 'price': double.parse(fields['price']!), 'unit': fields['unit'], 'stock': int.parse(fields['quantity']!), 'location': fields['location'], 'category': 'Alimentos y suplementos', 'category_id': int.parse(fields['category_id']!), 'image': null, 'status': fields['status'], 'description': fields['description']};
        myProducts.add(p);
        return {'data': p};
      }
      final p = myProducts.firstWhere((p) => '${p['id']}' == path.split('/').last);
      p..['name'] = fields['name']..['price'] = double.parse(fields['price']!)..['stock'] = int.parse(fields['quantity']!)..['status'] = fields['status'];
      return {'data': p};
    }
    if (path == '/professional/services' || RegExp(r'^/professional/services/\d+$').hasMatch(path)) {
      if (fields['title']?.isEmpty ?? true) throw ApiException('The title field is required.', statusCode: 422);
      lastServiceForm = fields;
      if (path == '/professional/services') {
        final sv = {'id': ++nextId, 'title': fields['title'], 'price': double.parse(fields['price']!), 'price_type': fields['price_type'], 'status': fields['status'], 'category': 'Veterinaria General', 'service_category_id': int.parse(fields['service_category_id']!), 'home_visit': fields['home_visit'] == '1', 'emergency_service': fields['emergency_service'] == '1', 'description': fields['description'], 'requirements': fields['requirements'], 'coverage_area': fields['coverage_area']};
        myServices.add(sv);
        return {'data': sv};
      }
      final sv = myServices.firstWhere((p) => '${p['id']}' == path.split('/').last);
      sv..['title'] = fields['title']..['price'] = double.parse(fields['price']!)..['status'] = fields['status'];
      return {'data': sv};
    }
    if (path == '/rancher/profile/document') {
      businessProfile..['has_backup_document'] = true..['complete'] = true;
      return {'data': businessProfile};
    }
    if (path == '/verification') {
      if (files.length < 3) throw ApiException('Faltan imágenes.', statusCode: 422);
      verificationAttempts++;
      verificationStatus = 'in_review';
      return {'data': verificationPayload()};
    }
    throw ApiException('No encontrado', statusCode: 404);
  }

  @override
  Future<Map<String, dynamic>> delete(String path) async {
    calls.add('DELETE $path');
    if (!_auth) _unauth();
    final delImg = RegExp(r'^/rancher/livestock/(\d+)/images/(\d+)$').firstMatch(path);
    if (delImg != null) {
      final l = myLivestock.firstWhere((l) => '${l['id']}' == delImg.group(1));
      (l['images'] as List).removeWhere((i) => '${(i as Map)['id']}' == delImg.group(2));
      return {'message': 'ok'};
    }
    for (final entry in {'/rancher/livestock/': myLivestock, '/rancher/auctions/': myAuctions, '/supplier/products/': myProducts, '/professional/services/': myServices}.entries) {
      if (path.startsWith(entry.key)) {
        entry.value.removeWhere((e) => '${e['id']}' == path.split('/').last);
        return {'message': 'ok'};
      }
    }
    if (path == '/cart') {
      cartItems.clear();
      return {'data': cartPayload()};
    }
    if (path.startsWith('/cart/items/')) {
      cartItems.removeWhere((i) => '${i['id']}' == path.split('/').last);
      return {'data': cartPayload()};
    }
    if (path.startsWith('/favorites/')) {
      favoriteId = null;
      favorites.clear();
      return {'message': 'ok'};
    }
    throw ApiException('No encontrado', statusCode: 404);
  }
}

/// Sesión ya iniciada, sin pasar por la red.
class LoggedInAuth extends AuthController {
  LoggedInAuth({this.roles = const ['buyer'], this.verified = true, this.missing = const []});
  final List<String> roles;
  final bool verified;
  final List<String> missing;

  @override
  Future<AppUser?> build() async => AppUser(id: 7, name: 'Comprador Test', email: 'comprador@test.com', identityVerified: verified, roles: roles, missingProfile: missing);
}

/// Selector de fotos que devuelve rutas ficticias.
class FakePhotoPicker implements PhotoPicker {
  int picks = 0;
  @override
  Future<String?> pick({required bool fromCamera}) async => '/tmp/foto_${picks++}.jpg';
}
