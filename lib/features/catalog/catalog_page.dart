import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import 'livestock.dart';

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key});

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _items = <Livestock>[];
  String? _type;
  int _page = 1;
  int _lastPage = 1;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _items.clear();
      _page = 1;
      _lastPage = 1;
      _error = null;
    });
    await _fetch();
  }

  Future<void> _loadMore() async {
    if (_loading || _page >= _lastPage) return;
    _page++;
    await _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final body = await ref.read(apiClientProvider).get('/livestock', query: {
        'page': _page,
        if (_type != null) 'type': _type,
        if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
      });
      final data = [for (final j in body['data'] as List) Livestock.fromJson(j as Map<String, dynamic>)];
      if (!mounted) return;
      setState(() {
        _items.addAll(data);
        _lastPage = (body['meta'] as Map)['last_page'] as int;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Buscar por título o raza',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () {
              _search.clear();
              _reload();
            }),
          ),
          onSubmitted: (_) => _reload(),
        ),
      ),
      SizedBox(
        height: 48,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(label: const Text('Todos'), selected: _type == null, onSelected: (_) {
              _type = null;
              _reload();
            }),
          ),
          for (final e in livestockTypes.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: Text(e.value), selected: _type == e.key, onSelected: (_) {
                _type = e.key;
                _reload();
              }),
            ),
        ]),
      ),
      Expanded(child: _body()),
    ]);
  }

  Widget _body() {
    if (_items.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty && _error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!), const SizedBox(height: 8), OutlinedButton(onPressed: _reload, child: const Text('Reintentar')),
      ]));
    }
    if (_items.isEmpty) return const Center(child: Text('No hay animales con esos filtros.'));

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(12),
        itemCount: _items.length + (_page < _lastPage ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _items.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
          return LivestockCard(item: _items[i]);
        },
      ),
    );
  }
}

class LivestockCard extends StatelessWidget {
  const LivestockCard({super.key, required this.item});
  final Livestock item;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/livestock/${item.id}'),
        child: Row(children: [
          SizedBox(width: 110, height: 110, child: _Photo(url: item.image)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text([livestockTypes[item.type] ?? item.type, if (item.breed != null) item.breed!].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall),
                if (item.location != null) Text(item.location!, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Text(money(item.price), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(color: Colors.green.shade50, child: const Icon(Icons.pets, size: 40, color: Colors.green));
    if (url == null) return placeholder;
    return Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder);
  }
}
