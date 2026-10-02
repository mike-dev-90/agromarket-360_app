import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/paged_list.dart';
import '../catalog/livestock.dart';
import 'business_models.dart';

class RancherLivestockPage extends ConsumerStatefulWidget {
  const RancherLivestockPage({super.key});

  @override
  ConsumerState<RancherLivestockPage> createState() => _RancherLivestockPageState();
}

class _RancherLivestockPageState extends ConsumerState<RancherLivestockPage> {
  final _list = GlobalKey<PagedSearchListState<BizLivestock>>();

  Future<void> _open(String route) async {
    await context.push(route);
    await _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi ganado')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _open('/business/livestock/new'), icon: const Icon(Icons.add), label: const Text('Publicar animal')),
      body: PagedSearchList<BizLivestock>(
        key: _list,
        showSearch: false,
        emptyText: 'Aún no has publicado animales.',
        emptyIcon: Icons.pets,
        filters: livestockStatuses,
        fetch: (ref, page, search, filter) async {
          final body = await ref.read(apiClientProvider).get('/rancher/livestock', query: {'page': page, if (filter != null) 'status': filter});
          return (
            items: [for (final j in body['data'] as List) BizLivestock.fromJson(j as Map<String, dynamic>)],
            lastPage: (body['meta'] as Map)['last_page'] as int,
          );
        },
        itemBuilder: (context, l) => Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _open('/business/livestock/${l.id}/edit'),
            child: Row(children: [
              SizedBox(
                width: 90,
                height: 90,
                child: l.image == null
                    ? Container(color: Colors.green.shade50, child: const Icon(Icons.pets, color: Colors.green))
                    : Image.network(l.image!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.green.shade50)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
                    Text('${livestockTypes[l.type] ?? l.type} · ${l.statusLabel}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                    Text(money(l.price), style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                    Text('${l.offersCount} ofertas · ${l.views} visitas', style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
