import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'features/account/account_page.dart';
import 'features/auctions/auction_detail_page.dart';
import 'features/auctions/auctions_page.dart';
import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/business/business_home_page.dart';
import 'features/business/business_profile_pages.dart';
import 'features/business/livestock_form_page.dart';
import 'features/business/professional_pages.dart';
import 'features/business/rancher_auctions_page.dart';
import 'features/business/rancher_livestock_page.dart';
import 'features/business/rancher_offers_page.dart';
import 'features/business/seller_orders_page.dart';
import 'features/business/supplier_products_page.dart';
import 'features/explore/explore_page.dart';
import 'features/supplies/cart_page.dart';
import 'features/supplies/cart_provider.dart';
import 'features/supplies/checkout_page.dart';
import 'features/supplies/product_detail_page.dart';
import 'features/catalog/livestock_detail_page.dart';
import 'features/favorites/favorites_page.dart';
import 'features/messages/order_messages_page.dart';
import 'features/notifications/notifications_page.dart';
import 'features/services/service_detail_page.dart';
import 'features/services/service_requests_page.dart';
import 'features/offers/offer_detail_page.dart';
import 'features/profile/password_page.dart';
import 'features/profile/profile_page.dart';
import 'features/profile/verification_page.dart';
import 'features/offers/offers_page.dart';
import 'features/orders/order_detail_page.dart';
import 'features/orders/orders_page.dart';

GoRouter buildRouter() => GoRouter(routes: [
  GoRoute(path: '/', builder: (_, __) => const HomePage()),
  GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
  GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
  GoRoute(path: '/livestock/:id', builder: (_, s) => LivestockDetailPage(id: int.parse(s.pathParameters['id']!))),
  GoRoute(path: '/offers/:id', builder: (_, s) => OfferDetailPage(id: int.parse(s.pathParameters['id']!))),
  GoRoute(path: '/orders/:id', builder: (_, s) => OrderDetailPage(id: int.parse(s.pathParameters['id']!))),
  GoRoute(path: '/products/:id', builder: (_, s) => ProductDetailPage(id: int.parse(s.pathParameters['id']!))),
  GoRoute(path: '/services/:id', builder: (_, s) => ServiceDetailPage(id: int.parse(s.pathParameters['id']!))),
  GoRoute(path: '/service-requests', builder: (_, __) => const ServiceRequestsPage()),
  GoRoute(path: '/orders/:id/messages', builder: (_, s) => OrderMessagesPage(orderId: int.parse(s.pathParameters['id']!))),
  GoRoute(path: '/cart', builder: (_, __) => const CartPage()),
  GoRoute(path: '/checkout', builder: (_, __) => const CheckoutPage()),
  GoRoute(path: '/business', builder: (_, __) => const BusinessHomePage()),
  GoRoute(path: '/business/orders', builder: (_, __) => const SellerOrdersPage()),
  GoRoute(path: '/business/rancher-profile', builder: (_, __) => const RancherProfilePage()),
  GoRoute(path: '/business/supplier-profile', builder: (_, __) => const SupplierProfilePage()),
  GoRoute(path: '/business/professional-profile', builder: (_, __) => const ProfessionalProfilePage()),
  GoRoute(path: '/business/livestock', builder: (_, __) => const RancherLivestockPage()),
  GoRoute(path: '/business/livestock/new', builder: (_, __) => const LivestockFormPage()),
  GoRoute(path: '/business/livestock/:id/edit', builder: (_, s) => LivestockFormPage(id: int.parse(s.pathParameters['id']!))),
  GoRoute(path: '/business/auctions', builder: (_, __) => const RancherAuctionsPage()),
  GoRoute(path: '/business/auctions/new', builder: (_, __) => const AuctionFormPage()),
  GoRoute(path: '/business/auctions/:id', builder: (_, s) => RancherAuctionDetailPage(id: int.parse(s.pathParameters['id']!))),
  GoRoute(path: '/business/auctions/:id/edit', builder: (_, s) => AuctionFormPage(id: int.parse(s.pathParameters['id']!))),
  GoRoute(path: '/business/offers', builder: (_, __) => const RancherOffersPage()),
  GoRoute(path: '/business/products', builder: (_, __) => const SupplierProductsPage()),
  GoRoute(path: '/business/products/new', builder: (_, __) => const ProductFormPage()),
  GoRoute(path: '/business/products/:id/edit', builder: (_, s) => ProductFormPage(id: int.parse(s.pathParameters['id']!))),
  GoRoute(path: '/business/services', builder: (_, __) => const ProfessionalServicesPage()),
  GoRoute(path: '/business/services/new', builder: (_, __) => const ServiceFormPage()),
  GoRoute(path: '/business/services/:id/edit', builder: (_, s) => ServiceFormPage(id: int.parse(s.pathParameters['id']!))),
  GoRoute(path: '/business/requests', builder: (_, __) => const ProfessionalRequestsPage()),
  GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
  GoRoute(path: '/profile/password', builder: (_, __) => const PasswordPage()),
  GoRoute(path: '/verification', builder: (_, __) => const VerificationPage()),
  GoRoute(path: '/favorites', builder: (_, __) => const FavoritesPage()),
  GoRoute(path: '/notifications', builder: (_, __) => const NotificationsPage()),
  GoRoute(path: '/auctions/:id', builder: (_, s) => AuctionDetailPage(id: int.parse(s.pathParameters['id']!))),
]);

class AgroMarketApp extends StatefulWidget {
  const AgroMarketApp({super.key});

  @override
  State<AgroMarketApp> createState() => _AgroMarketAppState();
}

class _AgroMarketAppState extends State<AgroMarketApp> {
  final _router = buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AgroMarket 360',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: _router,
    );
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _index = 0;

  static const _titles = ['Explorar', 'Subastas', 'Mis ofertas', 'Mis pedidos', 'Mi cuenta'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index]), actions: const [CartButton()]),
      body: IndexedStack(index: _index, children: const [ExplorePage(), AuctionsPage(), OffersPage(), OrdersPage(), AccountPage()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.pets_outlined), selectedIcon: Icon(Icons.pets), label: 'Explorar'),
          NavigationDestination(icon: Icon(Icons.gavel_outlined), selectedIcon: Icon(Icons.gavel), label: 'Subastas'),
          NavigationDestination(icon: Icon(Icons.handshake_outlined), selectedIcon: Icon(Icons.handshake), label: 'Ofertas'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Pedidos'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Cuenta'),
        ],
      ),
    );
  }
}


/// Icono de carrito con el número de productos.
class CartButton extends ConsumerWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartProvider).valueOrNull?.count ?? 0;
    return IconButton(
      tooltip: 'Carrito',
      onPressed: () => context.push('/cart'),
      icon: Badge(isLabelVisible: count > 0, label: Text('$count'), child: const Icon(Icons.shopping_cart_outlined)),
    );
  }
}
