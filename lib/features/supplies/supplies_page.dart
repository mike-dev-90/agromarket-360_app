import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/paged_list.dart';
import 'product.dart';

class SuppliesPage extends StatelessWidget {
  const SuppliesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PagedSearchList<Product>(
      searchHint: 'Buscar insumos',
      emptyText: 'No hay insumos con esos filtros.',
      emptyIcon: Icons.inventory_2_outlined,
      fetch: (ref, page, search, filter) async {
        final body = await ref.read(apiClientProvider).get('/products', query: {
          'page': page,
          if (search.isNotEmpty) 'search': search,
        });
        return (
          items: [for (final j in body['data'] as List) Product.fromJson(j as Map<String, dynamic>)],
          lastPage: (body['meta'] as Map)['last_page'] as int,
        );
      },
      itemBuilder: (context, p) => ProductCard(product: p),
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/products/${product.id}'),
        child: Row(children: [
          SizedBox(
            width: 100,
            height: 100,
            child: product.image == null
                ? Container(color: Colors.green.shade50, child: const Icon(Icons.inventory_2, size: 36, color: Colors.green))
                : Image.network(product.image!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.green.shade50, child: const Icon(Icons.inventory_2, color: Colors.green))),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                if (product.category != null) Text(product.category!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text('${money(product.price)}${product.unit != null ? ' / ${product.unit}' : ''}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                Text(product.stock > 0 ? '${product.stock} disponibles' : 'Sin stock', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
