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

final _router = GoRouter(routes: [
  GoRoute(path: '/', builder: (_, __) => const HomePage()),
  GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
  GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
  GoRoute(path: '/livestock/:id', builder: (_, s) => LivestockDetailPage(id: int.parse(s.pathParameters['id']!))),
  GoRoute(path: '/auctions/:id', builder: (_, s) => AuctionDetailPage(id: int.parse(s.pathParameters['id']!))),
]);

class AgroMarketApp extends StatelessWidget {
  const AgroMarketApp({super.key});

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

  static const _titles = ['Catálogo', 'Subastas', 'Mi cuenta'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(index: _index, children: const [CatalogPage(), AuctionsPage(), AccountPage()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.pets_outlined), selectedIcon: Icon(Icons.pets), label: 'Catálogo'),
          NavigationDestination(icon: Icon(Icons.gavel_outlined), selectedIcon: Icon(Icons.gavel), label: 'Subastas'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Cuenta'),
        ],
      ),
    );
  }
}
