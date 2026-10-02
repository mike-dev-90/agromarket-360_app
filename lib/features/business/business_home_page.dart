import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import 'business_models.dart';

final sellerDashboardProvider = FutureProvider.autoDispose<SellerDashboard>((ref) async {
  ref.watch(authProvider.select((u) => u.valueOrNull?.id));
  final body = await ref.read(apiClientProvider).get('/seller/dashboard');
  return SellerDashboard.fromJson(body['data'] as Map<String, dynamic>);
});

/// ¿Tiene el usuario algún rol de vendedor?
bool isSeller(AppUser? u) => u != null && (u.hasRole('rancher') || u.hasRole('supplier') || u.hasRole('professional'));

class BusinessHomePage extends StatelessWidget {
  const BusinessHomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mi negocio')),
        body: const LoginRequired(message: 'Inicia sesión para gestionar tu negocio.', child: _Body()),
      );
}

class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    if (!isSeller(user)) {
      return const EmptyState(icon: Icons.storefront_outlined, text: 'Tu cuenta es de comprador. Para vender, regístrate como ganadero, proveedor o profesional desde la web.');
    }
    final dash = ref.watch(sellerDashboardProvider);

    Widget stat(String label, num value) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              child: Column(children: [
                FittedBox(child: Text('$value', style: Theme.of(context).textTheme.headlineSmall)),
                Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
        );

    Widget tile(IconData icon, String title, String route, {String? subtitle}) => Card(
          child: ListTile(leading: Icon(icon), title: Text(title), subtitle: subtitle != null ? Text(subtitle) : null, trailing: const Icon(Icons.chevron_right), onTap: () => context.push(route)),
        );

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(sellerDashboardProvider.future),
      child: ListView(padding: const EdgeInsets.all(12), children: [
        if (user != null && user.missingProfile.any((m) => m.endsWith('_profile')))
          Card(
            color: Colors.amber.shade50,
            child: ListTile(
              leading: const Icon(Icons.warning_amber, color: Colors.orange),
              title: const Text('Completa el perfil de tu negocio'),
              subtitle: const Text('Es obligatorio para poder publicar y vender.'),
              onTap: () => context.push(user.hasRole('rancher') ? '/business/rancher-profile' : user.hasRole('supplier') ? '/business/supplier-profile' : '/business/professional-profile'),
            ),
          )
        else if (user != null && !user.identityVerified)
          Card(
            color: Colors.amber.shade50,
            child: ListTile(
              leading: const Icon(Icons.badge_outlined, color: Colors.orange),
              title: const Text('Verifica tu identidad'),
              subtitle: const Text('Es obligatorio para publicar y gestionar ofertas.'),
              onTap: () => context.push('/verification'),
            ),
          ),
        dash.when(
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(sellerDashboardProvider)),
          data: (d) => Column(children: [
            Row(children: [stat('Pedidos', d.order('total')), stat('Por cobrar', d.order('pending')), stat('En curso', d.order('in_progress'))]),
            if (user!.hasRole('rancher')) Row(children: [stat('Animales', d.stat('livestock', 'total')), stat('Publicados', d.stat('livestock', 'active')), stat('Ofertas por responder', d.stat('offers', 'awaiting_you'))]),
            if (user.hasRole('supplier')) Row(children: [stat('Productos', d.stat('products', 'total')), stat('Disponibles', d.stat('products', 'available'))]),
            if (user.hasRole('professional')) Row(children: [stat('Servicios', d.stat('services', 'total')), stat('Solicitudes nuevas', d.stat('requests', 'pending')), stat('Completadas', d.stat('requests', 'completed'))]),
            Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.only(right: 8), child: Text('Ingresos entregados: ${money(d.order('revenue'))}', style: Theme.of(context).textTheme.bodySmall))),
          ]),
        ),
        const SizedBox(height: 8),
        tile(Icons.receipt_long_outlined, 'Pedidos de venta', '/business/orders', subtitle: 'Confirma pagos y envía'),
        if (user!.hasRole('rancher')) ...[
          tile(Icons.pets, 'Mi ganado', '/business/livestock', subtitle: 'Publica y edita tus animales'),
          tile(Icons.gavel, 'Mis subastas', '/business/auctions'),
          tile(Icons.handshake_outlined, 'Ofertas recibidas', '/business/offers'),
          tile(Icons.agriculture_outlined, 'Perfil de ganadero', '/business/rancher-profile'),
        ],
        if (user.hasRole('supplier')) ...[
          tile(Icons.inventory_2_outlined, 'Mis productos', '/business/products', subtitle: 'Insumos que vendes'),
          tile(Icons.business_outlined, 'Perfil de empresa', '/business/supplier-profile'),
        ],
        if (user.hasRole('professional')) ...[
          tile(Icons.medical_services_outlined, 'Mis servicios', '/business/services'),
          tile(Icons.inbox_outlined, 'Solicitudes de clientes', '/business/requests'),
          tile(Icons.school_outlined, 'Perfil profesional', '/business/professional-profile'),
        ],
      ]),
    );
  }
}
