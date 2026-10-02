import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import 'order.dart';

final ordersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  ref.watch(authProvider.select((u) => u.valueOrNull?.id)); // se reinicia al cambiar de usuario
  final body = await ref.read(apiClientProvider).get('/orders');
  return [for (final j in body['data'] as List) Order.fromJson(j as Map<String, dynamic>)];
});

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) => const LoginRequired(message: 'Inicia sesión para ver tus pedidos.', child: _OrdersBody());
}

class _OrdersBody extends ConsumerWidget {
  const _OrdersBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(ordersProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(ordersProvider)),
            data: (orders) => RefreshIndicator(
              onRefresh: () async => ref.refresh(ordersProvider.future),
              child: orders.isEmpty
                  ? const EmptyState(icon: Icons.receipt_long_outlined, text: 'Aún no tienes pedidos.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: orders.length,
                      itemBuilder: (_, i) {
                        final o = orders[i];
                        return Card(
                          child: ListTile(
                            onTap: () => context.push('/orders/${o.id}'),
                            title: Text(o.items.isEmpty ? 'Pedido #${o.id}' : o.items.map((i) => i.name).join(', '), maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${o.number ?? '#${o.id}'} · ${o.statusLabel}', maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: PriceTrailing(money(o.total)),
                          ),
                        );
                      },
                    ),
            ),
          );
  }
}
