import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';

class FavoriteItem {
  FavoriteItem({required this.id, required this.type, required this.itemId, required this.title, this.price});
  final int id;
  final String? type;
  final int itemId;
  final String title;
  final double? price;

  factory FavoriteItem.fromJson(Map<String, dynamic> j) => FavoriteItem(
        id: j['id'] as int,
        type: j['type'] as String?,
        itemId: j['item_id'] as int,
        title: (j['title'] as String?) ?? 'Sin título',
        price: (j['price'] as num?)?.toDouble(),
      );
}

final favoritesProvider = FutureProvider.autoDispose<List<FavoriteItem>>((ref) async {
  ref.watch(authProvider.select((u) => u.valueOrNull?.id)); // se reinicia al cambiar de usuario
  final body = await ref.read(apiClientProvider).get('/favorites');
  return [for (final j in body['data'] as List) FavoriteItem.fromJson(j as Map<String, dynamic>)];
});

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mis favoritos')),
        body: const LoginRequired(message: 'Inicia sesión para ver tus favoritos.', child: _FavoritesBody()),
      );
}

class _FavoritesBody extends ConsumerWidget {
  const _FavoritesBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(favoritesProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(favoritesProvider)),
              data: (items) => RefreshIndicator(
                onRefresh: () async => ref.refresh(favoritesProvider.future),
                child: items.isEmpty
                    ? const EmptyState(icon: Icons.favorite_border, text: 'Aún no tienes favoritos. Toca el corazón en un animal para guardarlo.')
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final f = items[i];
                          return Card(
                            child: ListTile(
                              onTap: f.type == 'livestock' ? () => context.push('/livestock/${f.itemId}') : null,
                              title: Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: f.price != null ? Text(money(f.price!)) : null,
                              trailing: IconButton(
                                tooltip: 'Quitar de favoritos',
                                icon: const Icon(Icons.favorite, color: Colors.red),
                                onPressed: () async {
                                  try {
                                    await ref.read(apiClientProvider).delete('/favorites/${f.id}');
                                    ref.invalidate(favoritesProvider);
                                  } catch (e) {
                                    if (context.mounted) showMessage(context, errorText(e));
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            );
  }
}
