import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import '../favorites/favorites_page.dart';
import '../offers/offers_page.dart';
import '../orders/orders_page.dart';
import 'livestock.dart';

final livestockDetailProvider = FutureProvider.autoDispose.family<Livestock, int>((ref, id) async {
  ref.watch(authProvider.select((u) => u.valueOrNull?.id)); // el estado de favorito depende del usuario
  final body = await ref.read(apiClientProvider).get('/livestock/$id');
  return Livestock.fromJson(body['data'] as Map<String, dynamic>);
});

class LivestockDetailPage extends ConsumerStatefulWidget {
  const LivestockDetailPage({super.key, required this.id});
  final int id;

  @override
  ConsumerState<LivestockDetailPage> createState() => _LivestockDetailPageState();
}

class _LivestockDetailPageState extends ConsumerState<LivestockDetailPage> {
  bool _busy = false;

  bool _requireLogin() {
    if (ref.read(authProvider).valueOrNull != null) return true;
    context.push('/login');
    return false;
  }

  Future<void> _guard(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleFavorite(Livestock l) async {
    if (!_requireLogin()) return;
    await _guard(() async {
      final api = ref.read(apiClientProvider);
      if (l.favoriteId != null) {
        await api.delete('/favorites/${l.favoriteId}');
      } else {
        await api.post('/favorites', data: {'type': 'livestock', 'item_id': l.id});
      }
      ref.invalidate(livestockDetailProvider(widget.id));
      ref.invalidate(favoritesProvider);
    });
  }

  Future<void> _offer(Livestock l) async {
    if (!_requireLogin()) return;
    final amount = await askAmount(context, title: 'Tu oferta', helper: 'Precio publicado: ${money(l.price)}', action: 'Ofertar');
    if (amount == null) return;
    await _guard(() async {
      await ref.read(apiClientProvider).post('/offers', data: {'livestock_id': l.id, 'offer_price': amount});
      ref.invalidate(offersProvider);
      if (mounted) {
        showMessage(context, 'Oferta enviada. Te avisaremos cuando el vendedor responda.');
      }
    });
  }

  Future<void> _buy(Livestock l) async {
    if (!_requireLogin()) return;
    if (!await confirm(context, '¿Comprar "${l.title}" por ${money(l.price)}?')) return;
    await _guard(() async {
      final body = await ref.read(apiClientProvider).post('/orders', data: {'livestock_id': l.id});
      ref.invalidate(ordersProvider);
      final id = (body['data'] as Map)['id'];
      if (mounted) context.push('/orders/$id');
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(livestockDetailProvider(widget.id));
    final livestock = detail.valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del animal'),
        actions: [
          if (livestock != null)
            IconButton(
              tooltip: livestock.favoriteId != null ? 'Quitar de favoritos' : 'Guardar en favoritos',
              icon: Icon(livestock.favoriteId != null ? Icons.favorite : Icons.favorite_border),
              onPressed: _busy ? null : () => _toggleFavorite(livestock),
            ),
        ],
      ),
      bottomNavigationBar: livestock == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  if (livestock.negotiable)
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        onPressed: _busy ? null : () => _offer(livestock),
                        child: const Text('Hacer oferta'),
                      ),
                    ),
                  if (livestock.negotiable) const SizedBox(width: 12),
                  Expanded(child: FilledButton(onPressed: _busy ? null : () => _buy(livestock), child: const Text('Comprar'))),
                ]),
              ),
            ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(livestockDetailProvider(widget.id))),
        data: (l) => ListView(children: [
          SizedBox(
            height: 240,
            child: l.images.isEmpty
                ? Container(color: Colors.green.shade50, child: const Icon(Icons.pets, size: 64, color: Colors.green))
                : PageView(children: [for (final url in l.images) Image.network(url, fit: BoxFit.cover)]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(money(l.price), style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
              if (l.negotiable) const Text('Precio negociable'),
              const Divider(height: 32),
              _row('Tipo', livestockTypes[l.type] ?? l.type),
              if (l.breed != null) _row('Raza', l.breed!),
              if (l.sex != null) _row('Sexo', l.sex == 'male' ? 'Macho' : 'Hembra'),
              if (l.ageYears != null) _row('Edad', '${l.ageYears} años'),
              if (l.weight != null) _row('Peso', '${l.weight} kg'),
              _row('Vacunado', l.isVaccinated ? 'Sí' : 'No'),
              if (l.location != null) _row('Ubicación', l.location!),
              if (l.sellerName != null) _row('Vendedor', l.sellerName!),
              if (l.description != null) ...[const Divider(height: 32), Text(l.description!)],
              if (l.healthNotes != null && l.healthNotes!.isNotEmpty) ...[const SizedBox(height: 12), Text('Salud: ${l.healthNotes}')],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
        ]),
      );
}
