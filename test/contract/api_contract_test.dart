@Tags(['contract'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:agromarket_360_app/core/api_client.dart';
import 'package:agromarket_360_app/features/auctions/auction.dart';
import 'package:agromarket_360_app/features/auth/auth_controller.dart';
import 'package:agromarket_360_app/features/catalog/livestock.dart';
import 'package:agromarket_360_app/features/notifications/notification_item.dart';
import 'package:agromarket_360_app/features/offers/offer.dart';
import 'package:agromarket_360_app/features/orders/order.dart';
import 'package:agromarket_360_app/features/messages/order_messages_page.dart';
import 'package:agromarket_360_app/features/services/service_models.dart';
import 'package:agromarket_360_app/features/supplies/product.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api.dart';

/// Ejecuta el cliente y los modelos REALES de la app contra un servidor Laravel de verdad.
///
///   flutter test test/contract --dart-define=CONTRACT_API=http://127.0.0.1:8000/api/v1
///
/// Requiere el proyecto web con datos de demostración (comprador@agromarket.com / password, verificado).
const _base = String.fromEnvironment('CONTRACT_API');

ApiClient _client(MemoryTokens tokens) => ApiClient(
      tokens,
      dio: Dio(BaseOptions(baseUrl: _base, headers: {'Accept': 'application/json'}, validateStatus: (s) => s != null && s < 500 && s < 400)),
    );

void main() {
  setUpAll(() => HttpOverrides.global = null); // flutter_test bloquea la red por defecto

  final skip = _base.isEmpty ? 'Define CONTRACT_API para ejecutar estas pruebas contra un servidor real.' : null;

  test('registro de un comprador nuevo: sin verificar no puede ofertar ni pujar ni comprar', () async {
    final tokens = MemoryTokens();
    final api = _client(tokens);
    final email = 'app${Random().nextInt(1 << 30)}@test.com';

    final body = await api.post('/auth/register', data: {
      'name': 'Comprador App', 'email': email, 'password': 'secreta123', 'password_confirmation': 'secreta123',
      'phone': '0991234567', 'city': 'Quito', 'state': 'Pichincha', 'purchase_purpose': 'cria',
    });
    await tokens.write(body['token'] as String);
    final user = AppUser.fromJson(body['user'] as Map<String, dynamic>);
    expect(user.identityVerified, isFalse);

    // Correo repetido: el mensaje llega legible.
    await expectLater(
      api.post('/auth/register', data: {'name': 'X', 'email': email, 'password': 'secreta123', 'password_confirmation': 'secreta123', 'phone': '1', 'city': 'Q', 'state': 'P', 'purchase_purpose': 'cria'}),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)),
    );

    await expectLater(
      api.post('/offers', data: {'livestock_id': 2, 'offer_price': 1500}),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403).having((e) => e.message, 'message', contains('verificar'))),
    );
    await expectLater(api.post('/orders', data: {'livestock_id': 2}), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)));
    await expectLater(api.post('/auctions/1/bids', data: {'amount': 900}), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)));

    await api.post('/auth/logout');
    await expectLater(api.get('/auth/me'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));
  }, skip: skip);

  test('login incorrecto devuelve un mensaje de validación legible', () async {
    final api = _client(MemoryTokens());
    await expectLater(
      api.post('/auth/login', data: {'email': 'comprador@agromarket.com', 'password': 'mala'}),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('credenciales'))),
    );
  }, skip: skip);

  test('catálogo público: lista, filtros y detalle se leen con los modelos de la app', () async {
    final api = _client(MemoryTokens());

    final list = await api.get('/livestock', query: {'per_page': 5});
    final animals = [for (final j in list['data'] as List) Livestock.fromJson(j as Map<String, dynamic>)];
    expect(animals, isNotEmpty);
    expect(animals.first.price, greaterThan(0));
    expect((list['meta'] as Map)['last_page'], isA<int>());

    final porcino = await api.get('/livestock', query: {'type': 'pig'});
    expect((porcino['data'] as List).every((a) => (a as Map)['type'] == 'pig'), isTrue);

    final detail = Livestock.fromJson((await api.get('/livestock/${animals.first.id}'))['data'] as Map<String, dynamic>);
    expect(detail.id, animals.first.id);
    expect(detail.favoriteId, isNull, reason: 'invitado');

    await expectLater(api.get('/livestock/999999'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)));

    final auctions = await api.get('/auctions');
    final parsed = [for (final j in auctions['data'] as List) Auction.fromJson(j as Map<String, dynamic>)];
    expect(parsed, isNotEmpty);
    expect(parsed.first.remaining, greaterThan(Duration.zero));
  }, skip: skip);

  test('comprador verificado: favoritos, ofertas, pedido con comprobante, notificaciones y pujas', () async {
    final tokens = MemoryTokens();
    final api = _client(tokens);

    final login = await api.post('/auth/login', data: {'email': 'comprador@agromarket.com', 'password': 'password'});
    await tokens.write(login['token'] as String);
    expect(AppUser.fromJson(login['user'] as Map<String, dynamic>).identityVerified, isTrue);

    // Favoritos
    final fav = await api.post('/favorites', data: {'type': 'livestock', 'item_id': 1});
    final detail = Livestock.fromJson((await api.get('/livestock/1'))['data'] as Map<String, dynamic>);
    expect(detail.favoriteId, fav['id']);
    expect(((await api.get('/favorites'))['data'] as List).any((f) => (f as Map)['item_id'] == 1), isTrue);
    await api.delete('/favorites/${fav['id']}');
    expect(Livestock.fromJson((await api.get('/livestock/1'))['data'] as Map<String, dynamic>).favoriteId, isNull);

    // Ofertas: crear, duplicada, rechazar
    final created = Offer.fromJson((await api.post('/offers', data: {'livestock_id': 2, 'offer_price': 1500}))['data'] as Map<String, dynamic>);
    expect(created.isOpen, isTrue);
    expect(created.awaitingBuyer, isFalse);
    expect(created.livestockId, 2);
    await expectLater(api.post('/offers', data: {'livestock_id': 2, 'offer_price': 1400}), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)));
    final offers = [for (final j in (await api.get('/offers'))['data'] as List) Offer.fromJson(j as Map<String, dynamic>)];
    expect(offers.any((o) => o.id == created.id), isTrue);
    final rejected = Offer.fromJson((await api.post('/offers/${created.id}/reject'))['data'] as Map<String, dynamic>);
    expect(rejected.status, 'rejected');

    // Pedido: comprar, comprobante, cancelar (el animal vuelve a estar publicado)
    final order = Order.fromJson((await api.post('/orders', data: {'livestock_id': 3}))['data'] as Map<String, dynamic>);
    expect(order.status, 'pending');
    expect(order.canSendProof, isTrue);
    expect(order.items.single.name, 'Novillo C');
    final withProof = Order.fromJson((await api.post('/orders/${order.id}/transfer-proof', data: {
      'reference_number': 'REF-APP', 'bank_name': 'Pichincha', 'transfer_date': DateTime.now().toIso8601String().substring(0, 10),
    }))['data'] as Map<String, dynamic>);
    expect(withProof.transferReference, 'REF-APP');
    final shown = Order.fromJson((await api.get('/orders/${order.id}'))['data'] as Map<String, dynamic>);
    expect(shown.bank, isNotNull);
    await expectLater(api.post('/orders', data: {'livestock_id': 3}), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)), reason: 'ya está reservado');
    await expectLater(api.post('/orders/${order.id}/confirm-delivery'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)));
    final cancelled = Order.fromJson((await api.post('/orders/${order.id}/cancel'))['data'] as Map<String, dynamic>);
    expect(cancelled.status, 'cancelled');
    expect(Livestock.fromJson((await api.get('/livestock/3'))['data'] as Map<String, dynamic>).title, 'Novillo C', reason: 'volvió al catálogo');

    // Notificaciones
    final notes = await api.get('/notifications');
    final items = [for (final j in notes['data'] as List) NotificationItem.fromJson(j as Map<String, dynamic>)];
    expect((notes['meta'] as Map)['unread'], isA<int>());
    expect(items.length, lessThanOrEqualTo(20));
    await api.post('/notifications/read-all');
    final after = [for (final j in (await api.get('/notifications'))['data'] as List) NotificationItem.fromJson(j as Map<String, dynamic>)];
    expect(after.every((n) => n.isRead), isTrue);

    // Subasta: puja baja rechazada, puja válida aceptada y reflejada
    final auction = Auction.fromJson(((await api.get('/auctions'))['data'] as List).first as Map<String, dynamic>);
    final before = Auction.fromJson((await api.get('/auctions/${auction.id}'))['data'] as Map<String, dynamic>);
    await expectLater(
      api.post('/auctions/${auction.id}/bids', data: {'amount': 1}),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('mínima'))),
    );
    final amount = before.minimumNextBid! + 5;
    final placed = Auction.fromJson((await api.post('/auctions/${auction.id}/bids', data: {'amount': amount}))['data'] as Map<String, dynamic>);
    expect(placed.currentPrice, amount);
    final polled = Auction.fromJson((await api.get('/auctions/${auction.id}'))['data'] as Map<String, dynamic>);
    expect(polled.myHighestBid, amount);
    expect(polled.bids.first.isMine, isTrue);
    expect(polled.minimumNextBid, greaterThan(amount));
  }, skip: skip);

  test('perfil, contraseña y verificación de identidad (subida de fotos real)', () async {
    final tokens = MemoryTokens();
    final api = _client(tokens);
    final email = 'perfil${Random().nextInt(1 << 30)}@test.com';

    final reg = await api.post('/auth/register', data: {
      'name': 'Perfil App', 'email': email, 'password': 'secreta123', 'password_confirmation': 'secreta123',
      'phone': '0991234567', 'city': 'Quito', 'state': 'Pichincha', 'purchase_purpose': 'consumo',
    });
    await tokens.write(reg['token'] as String);
    final me = AppUser.fromJson((await api.get('/profile'))['data'] as Map<String, dynamic>);
    expect(me.purchasePurpose, 'consumo');
    expect(me.city, 'Quito');
    expect(me.identityVerified, isFalse);

    final updated = AppUser.fromJson((await api.put('/profile', data: {'name': 'Perfil Editado', 'email': email, 'city': 'Cuenca', 'state': 'Azuay', 'purchase_purpose': 'reventa'}))['data'] as Map<String, dynamic>);
    expect(updated.name, 'Perfil Editado');
    expect(updated.state, 'Azuay');
    expect(updated.purchasePurpose, 'reventa');

    await expectLater(api.put('/profile', data: {'name': 'X', 'email': 'comprador@agromarket.com'}), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)));
    await expectLater(
      api.put('/profile/password', data: {'current_password': 'mala', 'password': 'otraClave123', 'password_confirmation': 'otraClave123'}),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('no es correcta'))),
    );
    await api.put('/profile/password', data: {'current_password': 'secreta123', 'password': 'otraClave123', 'password_confirmation': 'otraClave123'});
    final relogin = await _client(MemoryTokens()).post('/auth/login', data: {'email': email, 'password': 'otraClave123'});
    expect(relogin['token'], isA<String>());

    // Verificación: estado inicial, envío multipart y revisión
    final before = await api.get('/verification');
    expect((before['data'] as Map)['status'], 'none');
    expect((before['data'] as Map)['remaining_attempts'], 3);

    final dir = Directory.systemTemp.createTempSync('agro_ver');
    addTearDown(() => dir.deleteSync(recursive: true));
    final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
    final files = {for (final n in ['document_front', 'document_back', 'selfie']) n: (File('${dir.path}/$n.jpg')..writeAsBytesSync(png)).path};

    await expectLater(api.postForm('/verification', fields: {'document_type': 'cedula'}, files: files), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)));
    final sent = await api.postForm('/verification', fields: {'document_type': 'cedula', 'document_number': '0912345678'}, files: files);
    final state = sent['data'] as Map;
    expect(state['status'], 'in_review');
    expect(state['attempts'], 1);
    expect(state['can_submit'], isTrue);
  }, skip: skip);

  test('insumos: catálogo, carrito con límites de stock y checkout real', () async {
    final tokens = MemoryTokens();
    final api = _client(tokens);

    final list = await api.get('/products', query: {'per_page': 5});
    final products = [for (final j in list['data'] as List) Product.fromJson(j as Map<String, dynamic>)];
    expect(products, isNotEmpty);
    expect(products.first.price, greaterThan(0));
    final categories = await api.get('/product-categories');
    expect((categories['data'] as List), isNotEmpty);
    final detail = Product.fromJson((await api.get('/products/${products.first.id}'))['data'] as Map<String, dynamic>);
    expect(detail.id, products.first.id);
    await expectLater(api.get('/cart'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));

    final login = await api.post('/auth/login', data: {'email': 'comprador@agromarket.com', 'password': 'password'});
    await tokens.write(login['token'] as String);

    await api.delete('/cart');
    final p = products.firstWhere((x) => x.stock >= 2);
    await expectLater(api.post('/cart/items', data: {'product_id': p.id, 'quantity': p.stock + 1}), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('disponibles'))));
    var cart = Cart.fromJson((await api.post('/cart/items', data: {'product_id': p.id, 'quantity': 1}))['data'] as Map<String, dynamic>);
    expect(cart.count, 1);
    cart = Cart.fromJson((await api.put('/cart/items/${cart.items.single.id}', data: {'quantity': 2}))['data'] as Map<String, dynamic>);
    expect(cart.items.single.quantity, 2);
    expect(cart.total, closeTo(p.price * 2, 0.01));
    cart = Cart.fromJson((await api.delete('/cart/items/${cart.items.single.id}'))['data'] as Map<String, dynamic>);
    expect(cart.count, 0);

    await expectLater(api.post('/checkout', data: {'payment_method': 'transfer'}), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)));
    await api.post('/cart/items', data: {'product_id': p.id, 'quantity': 1});
    final created = await api.post('/checkout', data: {
      'shipping_address': 'Av. 9 de Octubre 100', 'shipping_city': 'Guayaquil', 'shipping_state': 'Guayas', 'phone': '0991234567', 'payment_method': 'transfer',
    });
    final orderId = ((created['data'] as List).first as Map)['id'];
    expect(Cart.fromJson((await api.get('/cart'))['data'] as Map<String, dynamic>).count, 0);

    final order = Order.fromJson((await api.get('/orders/$orderId'))['data'] as Map<String, dynamic>);
    expect(order.items.single.name, p.name);
    expect(order.canSendProof, isTrue);
    await api.post('/orders/$orderId/cancel');
  }, skip: skip);

  test('servicios profesionales: catálogo, solicitud y cancelación; mensajes de un pedido', () async {
    final tokens = MemoryTokens();
    final api = _client(tokens);

    final list = await api.get('/services');
    final services = [for (final j in list['data'] as List) ServiceItem.fromJson(j as Map<String, dynamic>)];
    expect(services, isNotEmpty);
    final categories = await api.get('/service-categories');
    expect(categories['data'], isNotEmpty);
    final detail = ServiceItem.fromJson((await api.get('/services/${services.first.id}'))['data'] as Map<String, dynamic>);
    expect(detail.title, services.first.title);

    final login = await api.post('/auth/login', data: {'email': 'comprador@agromarket.com', 'password': 'password'});
    await tokens.write(login['token'] as String);

    await expectLater(api.post('/services/${services.first.id}/requests', data: {'description': 'corto'}), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)));
    final tomorrow = DateTime.now().add(const Duration(days: 2)).toIso8601String().substring(0, 10);
    final created = ServiceRequestItem.fromJson((await api.post('/services/${services.first.id}/requests', data: {'description': 'Vacunar 30 reses de la finca', 'request_date': tomorrow, 'location': 'Guayaquil'}))['data'] as Map<String, dynamic>);
    expect(created.status, 'pending');
    final mine = [for (final j in (await api.get('/service-requests'))['data'] as List) ServiceRequestItem.fromJson(j as Map<String, dynamic>)];
    expect(mine.any((r) => r.id == created.id), isTrue);
    final cancelled = ServiceRequestItem.fromJson((await api.post('/service-requests/${created.id}/cancel'))['data'] as Map<String, dynamic>);
    expect(cancelled.status, 'cancelled');
    expect(cancelled.clientCanCancel, isFalse);

    // Mensajes de un pedido propio
    final animal = (((await api.get('/livestock'))['data'] as List).firstWhere((a) => (a as Map)['id'] == 3) as Map);
    final order = (await api.post('/orders', data: {'livestock_id': animal['id']}))['data'] as Map;
    await expectLater(api.post('/orders/${order['id']}/messages', data: {'message': ''}), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)));
    await api.post('/orders/${order['id']}/messages', data: {'message': '¿Cuándo recojo?'});
    final thread = await api.get('/orders/${order['id']}/messages');
    final messages = [for (final j in thread['data'] as List) ChatMessage.fromJson(j as Map<String, dynamic>)];
    expect(messages.single.isMine, isTrue);
    expect((thread['meta'] as Map)['other_user'], isNotNull);
    await api.post('/orders/${order['id']}/cancel');
  }, skip: skip);
}
