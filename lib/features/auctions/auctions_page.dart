import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import 'auction.dart';

final auctionListProvider = FutureProvider.autoDispose.family<List<Auction>, String>((ref, status) async {
  final body = await ref.read(apiClientProvider).get('/auctions', query: {'status': status});
  return [for (final j in body['data'] as List) Auction.fromJson(j as Map<String, dynamic>)];
});

/// Listado de subastas: se actualiza al abrir y con "tirar para refrescar" (sin temporizador).
class AuctionsPage extends ConsumerStatefulWidget {
  const AuctionsPage({super.key});

  @override
  ConsumerState<AuctionsPage> createState() => _AuctionsPageState();
}

class _AuctionsPageState extends ConsumerState<AuctionsPage> {
  String _status = 'running';

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(auctionListProvider(_status));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'running', label: Text('En curso')),
            ButtonSegment(value: 'upcoming', label: Text('Próximas')),
            ButtonSegment(value: 'ended', label: Text('Finalizadas')),
          ],
          selected: {_status},
          onSelectionChanged: (s) => setState(() => _status = s.first),
        ),
      ),
      Expanded(
        child: list.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$e'), OutlinedButton(onPressed: () => ref.invalidate(auctionListProvider(_status)), child: const Text('Reintentar')),
          ])),
          data: (items) => RefreshIndicator(
            onRefresh: () async => ref.refresh(auctionListProvider(_status).future),
            child: items.isEmpty
                ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No hay subastas en esta sección.'))])
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _AuctionCard(auction: items[i]),
                  ),
          ),
        ),
      ),
    ]);
  }
}

class _AuctionCard extends StatelessWidget {
  const _AuctionCard({required this.auction});
  final Auction auction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: () => context.push('/auctions/${auction.id}'),
        title: Text(auction.title),
        subtitle: Text('${auction.bidCount} pujas · ${countdown(auction.remaining)}'),
        trailing: Text(money(auction.currentPrice), style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
      ),
    );
  }
}
