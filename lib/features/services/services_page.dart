import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/paged_list.dart';
import 'service_models.dart';

final serviceCategoriesProvider = FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final body = await ref.read(apiClientProvider).get('/service-categories');
  return {for (final c in body['data'] as List) '${(c as Map)['id']}': c['name'] as String};
});

class ServicesPage extends ConsumerWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(serviceCategoriesProvider).valueOrNull;
    return PagedSearchList<ServiceItem>(
      key: ValueKey(categories?.length ?? -1), // al llegar las categorías se dibujan los filtros
      searchHint: 'Buscar servicios',
      emptyText: 'No hay servicios con esos filtros.',
      emptyIcon: Icons.medical_services_outlined,
      filters: categories,
      fetch: (ref, page, search, filter) async {
        final body = await ref.read(apiClientProvider).get('/services', query: {
          'page': page,
          if (search.isNotEmpty) 'search': search,
          if (filter != null) 'category_id': filter,
        });
        return (
          items: [for (final j in body['data'] as List) ServiceItem.fromJson(j as Map<String, dynamic>)],
          lastPage: (body['meta'] as Map)['last_page'] as int,
        );
      },
      itemBuilder: (context, s) => Card(
        child: ListTile(
          onTap: () => context.push('/services/${s.id}'),
          leading: const CircleAvatar(child: Icon(Icons.medical_services)),
          title: Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text([if (s.category != null) s.category!, s.priceLabel].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
