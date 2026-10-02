import 'package:agromarket_360_app/app.dart';
import 'package:agromarket_360_app/core/theme.dart';
import 'package:agromarket_360_app/features/account/account_page.dart';
import 'package:agromarket_360_app/features/auctions/auction_detail_page.dart';
import 'package:agromarket_360_app/features/auctions/auctions_page.dart';
import 'package:agromarket_360_app/features/auth/login_page.dart';
import 'package:agromarket_360_app/features/auth/register_page.dart';
import 'package:agromarket_360_app/features/catalog/livestock_detail_page.dart';
import 'package:agromarket_360_app/core/api_client.dart';
import 'package:agromarket_360_app/features/catalog/catalog_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _long = 'Toro Brahman reproductor de excelente genética certificado con pedigrí y vacunas al día';

class FakeApi extends ApiClient {
  FakeApi() : super(TokenStorage());

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    final now = DateTime.now().toUtc();
    if (path == '/livestock') {
      return {
        'data': [
          for (var i = 1; i <= 6; i++)
            {
              'id': i, 'title': _long, 'type': 'cattle', 'breed': 'Brahman cruzado con Nelore de pastoreo', 'price': 12345.5,
              'negotiable': true, 'location': 'Santo Domingo de los Tsáchilas, Ecuador', 'province': 'Guayas', 'image': null,
              'seller': {'id': 1, 'name': 'Hacienda La Esperanza de los Andes'},
            }
        ],
        'meta': {'current_page': 1, 'last_page': 1, 'total': 6},
      };
    }
    if (path.startsWith('/livestock/')) {
      return {'data': {
        'id': 1, 'title': _long, 'type': 'cattle', 'breed': 'Brahman', 'price': 2500.0, 'negotiable': true, 'location': 'Guayaquil, Guayas',
        'image': null, 'seller': {'id': 1, 'name': 'Hacienda'}, 'description': _long * 3, 'sex': 'male', 'age_years': 2, 'weight': 400,
        'is_vaccinated': true, 'health_notes': _long, 'images': <String>[],
      }};
    }
    if (path == '/auctions') {
      return {'data': [
        for (var i = 1; i <= 4; i++)
          {'id': i, 'title': _long, 'type': 'cattle', 'breed': 'Brahman', 'image': null, 'starting_price': 500, 'current_price': 1234567.5,
           'min_bid_increment': 25, 'bid_count': 12, 'status': 'active', 'is_running': true,
           'ends_at': now.add(const Duration(days: 2)).toIso8601String(), 'starts_at': now.toIso8601String(), 'server_time': now.toIso8601String()}
      ], 'meta': {'current_page': 1, 'last_page': 1, 'server_time': now.toIso8601String()}};
    }
    if (path.startsWith('/auctions/')) {
      return {'data': {
        'id': 1, 'title': _long, 'type': 'cattle', 'breed': 'Brahman', 'image': null, 'starting_price': 500, 'current_price': 1234567.5,
        'min_bid_increment': 25, 'bid_count': 12, 'status': 'active', 'is_running': true, 'description': _long, 'location': 'Guayaquil',
        'minimum_next_bid': 1234592.5, 'my_highest_bid': 1200000, 'ends_at': now.add(const Duration(hours: 5)).toIso8601String(),
        'starts_at': now.toIso8601String(), 'server_time': now.toIso8601String(),
        'bids': [for (var i = 0; i < 8; i++) {'amount': 1000 + i, 'bidder': 'Comprador con un nombre muy largo número $i', 'is_mine': i == 0, 'created_at': now.toIso8601String()}],
      }};
    }
    throw ApiException('Sin sesión', statusCode: 401);
  }
}

Future<void> _show(WidgetTester tester, Widget page, Size size, double scale) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(FakeApi())],
    child: MaterialApp(theme: buildTheme(), home: Scaffold(body: page)),
  ));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  // Desplaza al final para comprobar también lo que queda fuera de la primera pantalla.
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isNotEmpty) {
    await tester.drag(scrollables.first, const Offset(0, -2000));
    await tester.pump(const Duration(milliseconds: 300));
  }
  expect(tester.takeException(), isNull);
}

void main() {
  final pages = <String, Widget Function()>{
    'Catálogo': () => const CatalogPage(),
    'Subastas': () => const AuctionsPage(),
    'Detalle de animal': () => const LivestockDetailPage(id: 1),
    'Detalle de subasta': () => const AuctionDetailPage(id: 1),
    'Cuenta': () => const AccountPage(),
    'Inicio de sesión': () => const LoginPage(),
    'Registro': () => const RegisterPage(),
  };

  for (final scale in [1.0, 1.5]) {
    for (final size in [const Size(320, 568), const Size(360, 640)]) {
      for (final e in pages.entries) {
        testWidgets('${e.key} sin desbordes en ${size.width.toInt()}x${size.height.toInt()} con texto x$scale', (tester) async {
          await _show(tester, e.value(), size, scale);
        });
      }
    }
  }

  testWidgets('el menú inferior se ve completo en 320 px', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(FakeApi())], child: const AgroMarketApp()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
