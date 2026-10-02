import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import 'cart_provider.dart';
import 'product.dart';

final productDetailProvider = FutureProvider.autoDispose.family<Product, int>((ref, id) async {
  final body = await ref.read(apiClientProvider).get('/products/$id');
  return Product.fromJson(body['data'] as Map<String, dynamic>);
});

class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({super.key, required this.id});
  final int id;

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  int _qty = 1;
  bool _busy = false;

  Future<void> _add(Product p) async {
    if (ref.read(authProvider).valueOrNull == null) {
      context.push('/login');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).post('/cart/items', data: {'product_id': p.id, 'quantity': _qty});
      ref.invalidate(cartProvider);
      if (mounted) {
        showMessage(context, 'Agregado al carrito.');
      }
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(productDetailProvider(widget.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del insumo'), actions: [
        IconButton(tooltip: 'Carrito', icon: const Icon(Icons.shopping_cart_outlined), onPressed: () => context.push('/cart')),
      ]),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(productDetailProvider(widget.id))),
        data: (p) => ListView(children: [
          SizedBox(
            height: 220,
            child: p.image == null
                ? Container(color: Colors.green.shade50, child: const Icon(Icons.inventory_2, size: 64, color: Colors.green))
                : Image.network(p.image!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.green.shade50)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('${money(p.price)}${p.unit != null ? ' / ${p.unit}' : ''}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(p.stock > 0 ? '${p.stock} disponibles' : 'Sin stock'),
              if (p.category != null) Text('Categoría: ${p.category}'),
              if (p.location != null) Text('Ubicación: ${p.location}'),
              if (p.sellerName != null) Text('Vendedor: ${p.sellerName}'),
              if (p.description != null && p.description!.isNotEmpty) ...[const Divider(height: 32), Text(p.description!)],
              const SizedBox(height: 24),
              if (p.stock > 0) ...[
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton.outlined(tooltip: 'Menos', onPressed: _qty > 1 ? () => setState(() => _qty--) : null, icon: const Icon(Icons.remove)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('$_qty', style: Theme.of(context).textTheme.titleLarge)),
                  IconButton.outlined(tooltip: 'Más', onPressed: _qty < p.stock ? () => setState(() => _qty++) : null, icon: const Icon(Icons.add)),
                ]),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _add(p),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text('Agregar al carrito · ${money(p.price * _qty)}'),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
