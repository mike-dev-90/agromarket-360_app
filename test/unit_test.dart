import 'dart:convert';
import 'dart:typed_data';

import 'package:agromarket_360_app/core/api_client.dart';
import 'package:agromarket_360_app/features/auctions/auction.dart';
import 'package:agromarket_360_app/features/auth/auth_controller.dart';
import 'package:agromarket_360_app/features/catalog/livestock.dart';
import 'package:agromarket_360_app/features/offers/offer.dart';
import 'package:agromarket_360_app/features/orders/order.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final ResponseBody Function(RequestOptions) handler;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });

ApiClient _api(_Adapter adapter, MemoryTokens tokens) => ApiClient(tokens, dio: Dio(BaseOptions(baseUrl: 'http://x/api/v1'))..httpClientAdapter = adapter);

void main() {
  group('ApiClient', () {
    test('envía el token como Bearer y solo si existe', () async {
      final tokens = MemoryTokens();
      final adapter = _Adapter((_) => _json(200, {'ok': true}));
      final api = _api(adapter, tokens);

      await api.get('/livestock');
      expect(adapter.last!.headers.containsKey('Authorization'), isFalse);

      await tokens.write('abc');
      await api.get('/livestock');
      expect(adapter.last!.headers['Authorization'], 'Bearer abc');
    });

    test('error 422: usa el primer mensaje de validación y conserva todos', () async {
      final api = _api(_Adapter((_) => _json(422, {'message': 'The given data was invalid.', 'errors': {'email': ['Correo repetido'], 'phone': ['Teléfono inválido']}})), MemoryTokens());
      await expectLater(
        api.post('/auth/register', data: {}),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Correo repetido')
            .having((e) => e.statusCode, 'status', 422)
            .having((e) => e.errors['phone'], 'phone', ['Teléfono inválido'])),
      );
    });

    test('error con solo "message" (403/404/422 de reglas de negocio)', () async {
      final api = _api(_Adapter((_) => _json(403, {'message': 'Debes verificar tu identidad en la web para ofertar.'})), MemoryTokens());
      await expectLater(api.post('/offers', data: {}), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('verificar'))));
    });

    test('límite de intentos (429) se explica con claridad', () async {
      final api = _api(_Adapter((_) => _json(429, {'message': 'Too Many Attempts.'})), MemoryTokens());
      await expectLater(api.post('/auth/login', data: {}), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('Espera un minuto'))));
    });

    test('respuesta no JSON del servidor y caída de red dan mensajes amigables', () async {
      final html = _api(_Adapter((_) => ResponseBody.fromString('<html>Error</html>', 500)), MemoryTokens());
      await expectLater(html.get('/x'), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'No se pudo completar la solicitud.')));

      final offline = _api(_Adapter((o) => throw DioException(requestOptions: o, type: DioExceptionType.connectionError)), MemoryTokens());
      await expectLater(offline.get('/x'), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('No hay conexión'))));
    });
  });

  group('AuthController', () {
    ProviderContainer containerWith(FakeApi api) {
      final c = ProviderContainer(overrides: [apiClientProvider.overrideWithValue(api)]);
      addTearDown(c.dispose);
      return c;
    }

    test('sin token arranca como invitado y no consulta al servidor', () async {
      final api = FakeApi();
      final c = containerWith(api);
      expect(await c.read(authProvider.future), isNull);
      expect(api.calls, isEmpty);
    });

    test('con token válido restaura la sesión', () async {
      final c = containerWith(FakeApi(loggedIn: true));
      expect((await c.read(authProvider.future))?.email, 'comprador@test.com');
    });

    test('token vencido (401): borra el token y queda como invitado', () async {
      final api = FakeApi(loggedIn: true);
      api.tokens_.token = 'vencido';
      final expired = _ExpiredApi(api.tokens_);
      final c = ProviderContainer(overrides: [apiClientProvider.overrideWithValue(expired)]);
      addTearDown(c.dispose);
      expect(await c.read(authProvider.future), isNull);
      expect(expired.tokens_.token, isNull);
    });

    test('login y logout actualizan el estado y el almacenamiento', () async {
      final api = FakeApi();
      final c = containerWith(api);
      await c.read(authProvider.future);
      await c.read(authProvider.notifier).login('comprador@test.com', 'secreta123');
      expect(c.read(authProvider).value?.name, 'Comprador Test');
      expect(api.tokens_.token, 'tok');

      await c.read(authProvider.notifier).logout();
      expect(c.read(authProvider).value, isNull);
      expect(api.tokens_.token, isNull);
    });

    test('login fallido lanza ApiException y no guarda sesión', () async {
      final api = FakeApi();
      final c = containerWith(api);
      await c.read(authProvider.future);
      await expectLater(c.read(authProvider.notifier).login('a@b.com', 'mala'), throwsA(isA<ApiException>()));
      expect(api.tokens_.token, isNull);
    });
  });

  group('Modelos', () {
    test('Livestock acepta números como texto ("400.00") y como número', () {
      final a = Livestock.fromJson({'id': 1, 'title': 'T', 'type': 'cattle', 'price': '2500.00', 'negotiable': true, 'weight': '400.00', 'age_years': '2'});
      expect(a.price, 2500.0);
      expect(a.weight, 400.0);
      expect(a.ageYears, 2);
      final b = Livestock.fromJson({'id': 1, 'title': 'T', 'type': 'cattle', 'price': 10, 'negotiable': false, 'weight': null, 'favorite_id': 7});
      expect(b.weight, isNull);
      expect(b.favoriteId, 7);
    });

    test('Offer: estados y turno', () {
      final o = Offer.fromJson({'id': 1, 'status': 'negotiating', 'offered_by': 'rancher', 'offer_price': 1800, 'awaiting_buyer': true, 'livestock': {'id': 3, 'title': 'Toro', 'price': 2000}});
      expect(o.isOpen, isTrue);
      expect(o.awaitingBuyer, isTrue);
      expect(o.statusLabel, 'En negociación');
      expect(o.livestockId, 3);
      expect(Offer.fromJson({'id': 2, 'status': 'accepted', 'offered_by': 'buyer', 'offer_price': 1, 'livestock': null}).isOpen, isFalse);
    });

    test('Order: acciones permitidas según estado y datos bancarios', () {
      Order build(String status, [String pay = 'pending']) =>
          Order.fromJson({'id': 1, 'status': status, 'payment_status': pay, 'total': 10, 'items': [], 'bank': {'name': null, 'account_number': null}});
      expect(build('pending').canSendProof, isTrue);
      expect(build('pending').canCancel, isTrue);
      expect(build('pending', 'paid').canCancel, isFalse);
      expect(build('shipped').canConfirmDelivery, isTrue);
      expect(build('shipped').canCancel, isFalse);
      expect(build('delivered').canSendProof, isFalse);
      expect(build('pending').bank!.isConfigured, isFalse);
      expect(BankInfo.fromJson({'name': 'B', 'account_number': '123'}).isConfigured, isTrue);
    });

    test('Auction: la cuenta atrás usa la hora del servidor aunque el reloj del teléfono esté desfasado', () {
      final serverNow = DateTime.now().toUtc().add(const Duration(hours: 3)); // teléfono 3 h atrasado
      final a = Auction.fromJson({
        'id': 1, 'title': 'L', 'current_price': 10, 'starting_price': 5, 'bid_count': 0, 'is_running': true,
        'ends_at': serverNow.add(const Duration(hours: 2)).toIso8601String(), 'server_time': serverNow.toIso8601String(),
      });
      expect(a.remaining.inMinutes, inInclusiveRange(118, 120));
    });
  });
}

class _ExpiredApi extends FakeApi {
  _ExpiredApi(MemoryTokens t) : super(tokens: t);

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    throw ApiException('Unauthenticated.', statusCode: 401);
  }
}
