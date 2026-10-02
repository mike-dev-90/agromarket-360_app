import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'features/account/account_page.dart';
import 'features/auctions/auction_detail_page.dart';
import 'features/auctions/auctions_page.dart';
import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
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
