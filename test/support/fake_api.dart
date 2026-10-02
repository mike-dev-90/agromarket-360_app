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

  Map<String, dynamic> get user => {'id': 7, ...profile, 'user_type': 'buyer', 'roles': ['buyer'], 'identity_verified': identityVerified, 'missing_profile': missingProfile};

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
  @override
  Future<AppUser?> build() async => AppUser(id: 7, name: 'Comprador Test', email: 'comprador@test.com', identityVerified: true);
}

/// Selector de fotos que devuelve rutas ficticias.
class FakePhotoPicker implements PhotoPicker {
  int picks = 0;
  @override
  Future<String?> pick({required bool fromCamera}) async => '/tmp/foto_${picks++}.jpg';
}
