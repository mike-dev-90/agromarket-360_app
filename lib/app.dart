import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'features/account/account_page.dart';
import 'features/auctions/auction_detail_page.dart';
import 'features/auctions/auctions_page.dart';
import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/catalog/catalog_page.dart';
import 'features/catalog/livestock_detail_page.dart';
import 'features/favorites/favorites_page.dart';
import 'features/notifications/notifications_page.dart';
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

  static const _titles = ['Catálogo', 'Subastas', 'Mis ofertas', 'Mis pedidos', 'Mi cuenta'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(index: _index, children: const [CatalogPage(), AuctionsPage(), OffersPage(), OrdersPage(), AccountPage()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.pets_outlined), selectedIcon: Icon(Icons.pets), label: 'Catálogo'),
          NavigationDestination(icon: Icon(Icons.gavel_outlined), selectedIcon: Icon(Icons.gavel), label: 'Subastas'),
          NavigationDestination(icon: Icon(Icons.handshake_outlined), selectedIcon: Icon(Icons.handshake), label: 'Ofertas'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Pedidos'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Cuenta'),
        ],
      ),
    );
  }
}
