@Tags(['contract'])
library;

import 'dart:io';
import 'dart:math';

import 'package:agromarket_360_app/core/api_client.dart';
import 'package:agromarket_360_app/features/auctions/auction.dart';
import 'package:agromarket_360_app/features/auth/auth_controller.dart';
import 'package:agromarket_360_app/features/catalog/livestock.dart';
import 'package:agromarket_360_app/features/notifications/notification_item.dart';
import 'package:agromarket_360_app/features/offers/offer.dart';
import 'package:agromarket_360_app/features/orders/order.dart';
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
      'phone': '0991234567', 'city': 'Quito', 'state': 'Pichincha',
    });
    await tokens.write(body['token'] as String);
    final user = AppUser.fromJson(body['user'] as Map<String, dynamic>);
    expect(user.identityVerified, isFalse);

    // Correo repetido: el mensaje llega legible.
    await expectLater(
      api.post('/auth/register', data: {'name': 'X', 'email': email, 'password': 'secreta123', 'password_confirmation': 'secreta123', 'phone': '1', 'city': 'Q', 'state': 'P'}),
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
}
