import 'package:agromarket_360_app/app.dart';
import 'package:agromarket_360_app/core/api_client.dart';
import 'package:agromarket_360_app/core/theme.dart';
import 'package:agromarket_360_app/features/account/account_page.dart';
import 'package:agromarket_360_app/features/auctions/auction_detail_page.dart';
import 'package:agromarket_360_app/features/auctions/auctions_page.dart';
import 'package:agromarket_360_app/features/auth/auth_controller.dart';
import 'package:agromarket_360_app/features/auth/login_page.dart';
import 'package:agromarket_360_app/features/auth/register_page.dart';
import 'package:agromarket_360_app/features/business/business_home_page.dart';
import 'package:agromarket_360_app/features/business/business_profile_pages.dart';
import 'package:agromarket_360_app/features/business/livestock_form_page.dart';
import 'package:agromarket_360_app/features/business/professional_pages.dart';
import 'package:agromarket_360_app/features/business/rancher_auctions_page.dart';
import 'package:agromarket_360_app/features/business/rancher_livestock_page.dart';
import 'package:agromarket_360_app/features/business/rancher_offers_page.dart';
import 'package:agromarket_360_app/features/business/seller_orders_page.dart';
import 'package:agromarket_360_app/features/business/supplier_products_page.dart';
import 'package:agromarket_360_app/features/catalog/livestock_detail_page.dart';
import 'package:agromarket_360_app/features/favorites/favorites_page.dart';
import 'package:agromarket_360_app/features/messages/order_messages_page.dart';
import 'package:agromarket_360_app/features/notifications/notifications_page.dart';
import 'package:agromarket_360_app/features/services/service_detail_page.dart';
import 'package:agromarket_360_app/features/services/service_requests_page.dart';
import 'package:agromarket_360_app/features/services/services_page.dart';
import 'package:agromarket_360_app/features/offers/offer_detail_page.dart';
import 'package:agromarket_360_app/features/offers/offers_page.dart';
import 'package:agromarket_360_app/features/orders/order_detail_page.dart';
import 'package:agromarket_360_app/features/supplies/cart_page.dart';
import 'package:agromarket_360_app/features/supplies/checkout_page.dart';
import 'package:agromarket_360_app/features/supplies/product_detail_page.dart';
import 'package:agromarket_360_app/features/supplies/supplies_page.dart';
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
  api.serviceRequests.addAll([
    {'id': 1, 'status': 'scheduled', 'service_title': longTitle, 'description': longTitle, 'request_date': '2030-01-15', 'preferred_time': 'Mañana', 'location': longTitle, 'scheduled_date': '2030-01-14T10:00:00Z', 'price_quoted': 1234567.5, 'response_message': longTitle, 'professional': {'id': 5, 'name': 'Dr. Roberto Sánchez de la Torre y Villacís'}},
  ]);
  api.chat.addAll([
    {'id': 1, 'message': longTitle * 2, 'is_mine': true, 'sender': 'Yo'},
    {'id': 2, 'message': longTitle * 2, 'is_mine': false, 'sender': 'Vendedor'},
  ]);
  _seedBusiness(api);
  api.cartItems.addAll([
    for (var i = 1; i <= 3; i++) {'id': i, 'product_id': i, 'name': i == 1 ? 'Sal mineral para ganado bovino de engorde, bolsa de 25 kilos' : 'Balanceado $i', 'image': null, 'unit': 'bolsa', 'quantity': 12, 'unit_price': 1234567.5, 'stock': 50},
  ]);
  api.favorites.add({'id': 99, 'type': 'livestock', 'item_id': 1, 'title': longTitle, 'price': 2000.0});
  api.offers.add({'id': 1, 'status': 'negotiating', 'offered_by': 'rancher', 'offer_price': 1800.0, 'message': longTitle, 'rancher_response': longTitle});
  api.orders.add({
    'id': 5, 'order_number': 'AGM-2026-000005-ABCDEFGH', 'status': 'pending', 'payment_status': 'pending', 'payment_method': 'transfer', 'total': 12345678.9, 'transfer_reference': null,
    'items': [for (var i = 0; i < 3; i++) {'name': longTitle, 'quantity': 1, 'unit_price': 2000.0, 'total': 2000.0}],
  });
  return api;
}

void _seedBusiness(FakeApi api) {
  api.sellerOrders.add({
    'id': 31, 'order_number': 'AGM-2026-000031-ABCDEFGH', 'status': 'pending', 'payment_status': 'pending', 'payment_method': 'transfer', 'total': 12345678.9,
    'buyer': {'id': 1, 'name': 'Comprador con un nombre larguísimo de prueba', 'phone': '0991234567'}, 'shipping_address': longTitle, 'notes': longTitle,
    'transfer': {'reference': 'REF-123456789', 'bank': 'Banco del Pichincha', 'date': '2026-10-02', 'receipt': null}, 'tracking_number': null,
    'items': [for (var i = 0; i < 3; i++) {'name': longTitle, 'quantity': 2, 'unit_price': 10.0, 'total': 20.0}],
  });
  api.myLivestock.add({'id': 41, 'title': longTitle, 'type': 'cattle', 'breed': longTitle, 'price': 1234567.5, 'status': 'active', 'negotiable': true, 'location': longTitle, 'province': 'Guayas', 'image': null, 'views': 123456, 'offers_count': 99999,
    'description': longTitle, 'sex': 'male', 'age_years': 2, 'age_months': 3, 'weight': 400.0, 'is_vaccinated': true, 'has_pedigree': false, 'health_notes': longTitle, 'purpose': 'meat', 'images': [{'id': 1, 'url': 'http://x/a.jpg'}]});
  api.myAuctions.add({'id': 51, 'title': longTitle, 'description': longTitle, 'status': 'active', 'starting_price': 500.0, 'current_price': 1234567.5, 'min_bid_increment': 25.0, 'bid_count': 2, 'is_running': true,
    'starts_at': '2026-10-01T10:00:00Z', 'ends_at': '2026-10-05T10:00:00Z', 'location': longTitle, 'auction_terms': longTitle, 'reserve_price': 600.0, 'buy_now_price': null,
    'bids': [for (var i = 0; i < 4; i++) {'amount': 1000.0 + i, 'bidder': 'Comprador con un nombre muy largo número $i'}]});
  api.rancherOffers.add({'id': 61, 'status': 'pending', 'offered_by': 'buyer', 'offer_price': 1234567.5, 'message': longTitle, 'rancher_response': longTitle, 'awaiting_you': true, 'buyer': {'id': 1, 'name': 'Comprador con un nombre larguísimo'}, 'livestock': {'id': 41, 'title': longTitle, 'price': 2000.0}});
  api.myProducts.add({'id': 71, 'name': longTitle, 'price': 1234567.5, 'unit': 'bolsa', 'stock': 99999, 'location': longTitle, 'category': 'Alimentos y suplementos', 'category_id': 1, 'image': null, 'status': 'available', 'description': longTitle});
  api.myServices.add({'id': 81, 'title': longTitle, 'price': 1234567.5, 'price_type': 'por_visita', 'status': 'active', 'category': 'Veterinaria General', 'service_category_id': 1, 'home_visit': true, 'emergency_service': true, 'description': longTitle, 'requirements': longTitle, 'coverage_area': longTitle});
  api.proRequests.add({'id': 91, 'status': 'pending', 'service_title': longTitle, 'description': longTitle, 'request_date': '2030-01-15', 'preferred_time': 'Mañana', 'location': longTitle, 'scheduled_date': null, 'price_quoted': null, 'response_message': null, 'client': {'id': 1, 'name': 'Cliente con un nombre larguísimo de prueba'}});
  api.businessProfile.addAll({'farm_name': longTitle, 'company_name': longTitle, 'profession': 'veterinario', 'specialty': ['Bovinos', 'Equinos'], 'tipo_productos': ['alimentos', 'vacunas'], 'bio': longTitle, 'complete': false});
}

Future<void> _show(WidgetTester tester, Widget page, Size size, double scale, {bool loggedIn = true, List<String> roles = const ['buyer']}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(loggedIn ? (_seeded()..roles = roles) : FakeApi()),
      if (loggedIn) authProvider.overrideWith(() => LoggedInAuth(roles: roles, verified: false, missing: roles.contains('buyer') && roles.length == 1 ? const [] : const ['rancher_profile'])),
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
    'Servicios': () => const ServicesPage(),
    'Detalle de servicio': () => const ServiceDetailPage(id: 1),
    'Solicitudes de servicio': () => const ServiceRequestsPage(),
    'Mensajes del pedido': () => const OrderMessagesPage(orderId: 5),
    'Insumos': () => const SuppliesPage(),
    'Detalle de insumo': () => const ProductDetailPage(id: 1),
    'Carrito': () => const CartPage(),
    'Checkout': () => const CheckoutPage(),
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

  // Paneles de vendedor: cada rol con sus pantallas, en móviles pequeños y texto grande.
  final seller = <String, (List<String>, Widget Function())>{
    'Mi negocio (ganadero)': (['buyer', 'rancher'], () => const BusinessHomePage()),
    'Mi negocio (proveedor)': (['buyer', 'supplier'], () => const BusinessHomePage()),
    'Mi negocio (profesional)': (['buyer', 'professional'], () => const BusinessHomePage()),
    'Pedidos de venta': (['buyer', 'supplier'], () => const SellerOrdersPage()),
    'Mi ganado': (['buyer', 'rancher'], () => const RancherLivestockPage()),
    'Publicar animal': (['buyer', 'rancher'], () => const LivestockFormPage()),
    'Editar animal': (['buyer', 'rancher'], () => const LivestockFormPage(id: 41)),
    'Mis subastas': (['buyer', 'rancher'], () => const RancherAuctionsPage()),
    'Detalle de subasta propia': (['buyer', 'rancher'], () => const RancherAuctionDetailPage(id: 51)),
    'Nueva subasta': (['buyer', 'rancher'], () => const AuctionFormPage()),
    'Editar subasta': (['buyer', 'rancher'], () => const AuctionFormPage(id: 51)),
    'Ofertas recibidas': (['buyer', 'rancher'], () => const RancherOffersPage()),
    'Mis productos': (['buyer', 'supplier'], () => const SupplierProductsPage()),
    'Nuevo producto': (['buyer', 'supplier'], () => const ProductFormPage()),
    'Editar producto': (['buyer', 'supplier'], () => const ProductFormPage(id: 71)),
    'Mis servicios': (['buyer', 'professional'], () => const ProfessionalServicesPage()),
    'Nuevo servicio': (['buyer', 'professional'], () => const ServiceFormPage()),
    'Editar servicio': (['buyer', 'professional'], () => const ServiceFormPage(id: 81)),
    'Solicitudes de clientes': (['buyer', 'professional'], () => const ProfessionalRequestsPage()),
    'Perfil de ganadero': (['buyer', 'rancher'], () => const RancherProfilePage()),
    'Perfil de empresa': (['buyer', 'supplier'], () => const SupplierProfilePage()),
    'Perfil profesional': (['buyer', 'professional'], () => const ProfessionalProfilePage()),
  };
  for (final scale in [1.0, 1.5]) {
    for (final size in [const Size(320, 568), const Size(360, 640)]) {
      for (final e in seller.entries) {
        testWidgets('${e.key} sin desbordes en ${size.width.toInt()}x${size.height.toInt()} con texto x$scale', (tester) async {
          await _show(tester, e.value.$2(), size, scale, roles: e.value.$1);
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
    for (final label in ['Explorar', 'Subastas', 'Ofertas', 'Pedidos', 'Cuenta']) {
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)), findsOneWidget);
    }
  });
}
