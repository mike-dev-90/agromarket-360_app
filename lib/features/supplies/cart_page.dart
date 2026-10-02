import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import 'cart_provider.dart';
import 'product.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mi carrito')),
        body: const LoginRequired(message: 'Inicia sesión para ver tu carrito.', child: _CartBody()),
      );
}

class _CartBody extends ConsumerStatefulWidget {
  const _CartBody();

  @override
  ConsumerState<_CartBody> createState() => _CartBodyState();
}

class _CartBodyState extends ConsumerState<_CartBody> {
  bool _busy = false;

  Future<void> _call(Future<void> Function(ApiClient api) action) async {
    setState(() => _busy = true);
    try {
      await action(ref.read(apiClientProvider));
      ref.invalidate(cartProvider);
      await ref.read(cartProvider.future);
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ref.watch(cartProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(cartProvider)),
          data: (cart) {
            if (cart.items.isEmpty) {
              return EmptyState(
                icon: Icons.shopping_cart_outlined,
                text: 'Tu carrito está vacío.',
                action: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(160, 48)), onPressed: () => context.go('/'), child: const Text('Explorar insumos')),
              );
            }
            return Column(children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.all(12), children: [
                  for (final line in cart.items) _line(line),
                  TextButton.icon(onPressed: _busy ? null : () => _call((api) => api.delete('/cart').then((_) {})), icon: const Icon(Icons.delete_outline), label: const Text('Vaciar carrito')),
                ]),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(money(cart.total), textAlign: TextAlign.end, style: Theme.of(context).textTheme.titleLarge)),
                    ]),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _busy ? null : () => context.push('/checkout'), child: const Text('Continuar con la compra')),
                  ]),
                ),
              ),
            ]);
          },
        );
  }

  Widget _line(CartLine l) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('${money(l.unitPrice)}${l.unit != null ? ' / ${l.unit}' : ''}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(children: [
            IconButton.outlined(
              tooltip: 'Menos',
              onPressed: _busy || l.quantity <= 1 ? null : () => _call((api) => api.put('/cart/items/${l.id}', data: {'quantity': l.quantity - 1}).then((_) {})),
              icon: const Icon(Icons.remove),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('${l.quantity}')),
            IconButton.outlined(
              tooltip: 'Más',
              onPressed: _busy ? null : () => _call((api) => api.put('/cart/items/${l.id}', data: {'quantity': l.quantity + 1}).then((_) {})),
              icon: const Icon(Icons.add),
            ),
            const Spacer(),
            Flexible(child: Text(money(l.total), style: const TextStyle(fontWeight: FontWeight.bold))),
            IconButton(tooltip: 'Quitar', onPressed: _busy ? null : () => _call((api) => api.delete('/cart/items/${l.id}').then((_) {})), icon: const Icon(Icons.close)),
          ]),
        ]),
      ),
    );
  }
}
