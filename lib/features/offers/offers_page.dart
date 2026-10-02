import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import 'offer.dart';

final offersProvider = FutureProvider.autoDispose<List<Offer>>((ref) async {
  ref.watch(authProvider.select((u) => u.valueOrNull?.id)); // se reinicia al cambiar de usuario
  final body = await ref.read(apiClientProvider).get('/offers');
  return [for (final j in body['data'] as List) Offer.fromJson(j as Map<String, dynamic>)];
});

class OffersPage extends StatelessWidget {
  const OffersPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const LoginRequired(message: 'Inicia sesión para ver y gestionar tus ofertas.', child: _OffersBody());
}

class _OffersBody extends ConsumerWidget {
  const _OffersBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(offersProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(offersProvider)),
            data: (offers) => RefreshIndicator(
              onRefresh: () async => ref.refresh(offersProvider.future),
              child: offers.isEmpty
                  ? const EmptyState(icon: Icons.handshake_outlined, text: 'Aún no has hecho ofertas. Entra a un animal y pulsa "Hacer oferta".')
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: offers.length,
                      itemBuilder: (_, i) => OfferTile(offer: offers[i]),
                    ),
            ),
          );
  }
}

class OfferTile extends StatelessWidget {
  const OfferTile({super.key, required this.offer});
  final Offer offer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: () => context.push('/offers/${offer.id}'),
        title: Text(offer.livestockTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(offer.awaitingBuyer ? 'El vendedor respondió: te toca' : offer.statusLabel),
        trailing: Text(money(offer.offerPrice), style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
      ),
    );
  }
}
