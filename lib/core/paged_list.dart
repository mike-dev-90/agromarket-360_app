import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'widgets.dart';

typedef PageResult<T> = ({List<T> items, int lastPage});
typedef PageFetcher<T> = Future<PageResult<T>> Function(WidgetRef ref, int page, String search, String? filter);

/// Lista con búsqueda, filtros (chips), paginación al hacer scroll y "tirar para refrescar".
class PagedSearchList<T> extends ConsumerStatefulWidget {
  const PagedSearchList({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    this.filters,
    this.searchHint = 'Buscar',
    this.emptyText = 'No hay resultados.',
    this.emptyIcon = Icons.search_off,
    this.allLabel = 'Todos',
    this.showSearch = true,
  });

  final PageFetcher<T> fetch;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Map<String, String>? filters; // clave -> etiqueta
  final String searchHint;
  final String emptyText;
  final IconData emptyIcon;
  final String allLabel;
  final bool showSearch;

  @override
  ConsumerState<PagedSearchList<T>> createState() => PagedSearchListState<T>();
}

class PagedSearchListState<T> extends ConsumerState<PagedSearchList<T>> {
  /// Vuelve a cargar desde la primera página (p. ej. tras crear o editar un elemento).
  Future<void> reload() => _reload();

  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _items = <T>[];
  String? _filter;
  int _page = 1;
  int _lastPage = 1;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
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
      final r = await widget.fetch(ref, _page, _search.text.trim(), _filter);
      if (!mounted) return;
      setState(() {
        _items.addAll(r.items);
        _lastPage = r.lastPage;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (widget.showSearch) _searchField(),
      if (widget.filters != null) _filterChips(),
      Expanded(child: _body()),
    ]);
  }

  Widget _searchField() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: widget.searchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _search.clear();
                _reload();
              },
            ),
          ),
          onSubmitted: (_) => _reload(),
        ),
      );

  Widget _filterChips() => Padding(
        padding: EdgeInsets.only(top: widget.showSearch ? 0 : 8),
        child: SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(widget.allLabel),
                selected: _filter == null,
                onSelected: (_) {
                  _filter = null;
                  _reload();
                },
              ),
            ),
            for (final e in widget.filters!.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(e.value),
                  selected: _filter == e.key,
                  onSelected: (_) {
                    _filter = e.key;
                    _reload();
                  },
                ),
              ),
          ]),
        ),
      );

  Widget _body() {
    if (_items.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty && _error != null) return ErrorRetry(error: _error!, onRetry: _reload);
    if (_items.isEmpty) return RefreshIndicator(onRefresh: _reload, child: EmptyState(icon: widget.emptyIcon, text: widget.emptyText));

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(12),
        itemCount: _items.length + (_page < _lastPage ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _items.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
          return widget.itemBuilder(context, _items[i]);
        },
      ),
    );
  }
}
