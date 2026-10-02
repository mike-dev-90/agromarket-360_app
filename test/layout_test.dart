import 'package:agromarket_360_app/app.dart';
import 'package:agromarket_360_app/core/api_client.dart';
import 'package:agromarket_360_app/core/theme.dart';
import 'package:agromarket_360_app/features/account/account_page.dart';
import 'package:agromarket_360_app/features/auctions/auction_detail_page.dart';
import 'package:agromarket_360_app/features/auctions/auctions_page.dart';
import 'package:agromarket_360_app/features/auth/auth_controller.dart';
import 'package:agromarket_360_app/features/auth/login_page.dart';
import 'package:agromarket_360_app/features/auth/register_page.dart';
import 'package:agromarket_360_app/features/catalog/livestock_detail_page.dart';
import 'package:agromarket_360_app/features/favorites/favorites_page.dart';
import 'package:agromarket_360_app/features/notifications/notifications_page.dart';
import 'package:agromarket_360_app/features/offers/offer_detail_page.dart';
import 'package:agromarket_360_app/features/offers/offers_page.dart';
import 'package:agromarket_360_app/features/orders/order_detail_page.dart';
import 'package:agromarket_360_app/features/profile/password_page.dart';
import 'package:agromarket_360_app/features/profile/profile_page.dart';
import 'package:agromarket_360_app/features/profile/verification_page.dart';
import 'package:agromarket_360_app/features/orders/orders_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api.dart';

/// Servidor con datos ya cargados (favorito, oferta negociando, pedido enviado) y textos larguísimos.
FakeApi _seeded() {
  final api = FakeApi(loggedIn: true);
  api.identityVerified = false;
  api.verificationStatus = 'rejected';
  api.rejectionReason = longTitle;
  api.missingProfile = ['purchase_purpose'];
  api.favoriteId = 99;
  api.favorites.add({'id': 99, 'type': 'livestock', 'item_id': 1, 'title': longTitle, 'price': 2000.0});
  api.offers.add({'id': 1, 'status': 'negotiating', 'offered_by': 'rancher', 'offer_price': 1800.0, 'message': longTitle, 'rancher_response': longTitle});
  api.orders.add({
    'id': 5, 'order_number': 'AGM-2026-000005-ABCDEFGH', 'status': 'pending', 'payment_status': 'pending', 'payment_method': 'transfer', 'total': 12345678.9, 'transfer_reference': null,
    'items': [for (var i = 0; i < 3; i++) {'name': longTitle, 'quantity': 1, 'unit_price': 2000.0, 'total': 2000.0}],
  });
  return api;
}

Future<void> _show(WidgetTester tester, Widget page, Size size, double scale, {bool loggedIn = true}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(loggedIn ? _seeded() : FakeApi()),
      if (loggedIn) authProvider.overrideWith(LoggedInAuth.new),
    ],
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
    'Inicio con menú': () => const HomePage(),
    'Subastas': () => const AuctionsPage(),
    'Detalle de animal': () => const LivestockDetailPage(id: 1),
    'Detalle de subasta': () => const AuctionDetailPage(id: 1),
    'Ofertas': () => const OffersPage(),
    'Detalle de oferta': () => const OfferDetailPage(id: 1),
    'Pedidos': () => const OrdersPage(),
    'Detalle de pedido': () => const OrderDetailPage(id: 5),
    'Favoritos': () => const FavoritesPage(),
    'Notificaciones': () => const NotificationsPage(),
    'Cuenta': () => const AccountPage(),
    'Inicio de sesión': () => const LoginPage(),
    'Registro': () => const RegisterPage(),
    'Editar perfil': () => const ProfilePage(),
    'Cambiar contraseña': () => const PasswordPage(),
    'Verificación': () => const VerificationPage(),
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

  // Invitado: las secciones privadas piden iniciar sesión sin desbordarse.
  for (final e in {'Ofertas': () => const OffersPage(), 'Pedidos': () => const OrdersPage(), 'Cuenta': () => const AccountPage()}.entries) {
    testWidgets('${e.key} como invitado en 320x568 con texto x1.5', (tester) async {
      await _show(tester, e.value(), const Size(320, 568), 1.5, loggedIn: false);
      expect(find.text('Iniciar sesión'), findsWidgets);
    });
  }

  testWidgets('el menú inferior con 5 accesos cabe en 320 px con texto grande', (tester) async {
    await _show(tester, const HomePage(), const Size(320, 568), 1.5);
    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in ['Catálogo', 'Subastas', 'Ofertas', 'Pedidos', 'Cuenta']) {
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)), findsOneWidget);
    }
  });
}
