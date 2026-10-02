import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/paged_list.dart';
import '../../core/widgets.dart';
import 'business_models.dart';

class RancherOffersPage extends ConsumerStatefulWidget {
  const RancherOffersPage({super.key});

  @override
  ConsumerState<RancherOffersPage> createState() => _RancherOffersPageState();
}

class _RancherOffersPageState extends ConsumerState<RancherOffersPage> {
  final _list = GlobalKey<PagedSearchListState<RancherOffer>>();

  Future<void> _act(RancherOffer o, String action, Map<String, dynamic> data, String done) async {
    try {
      await ref.read(apiClientProvider).post('/rancher/offers/${o.id}/$action', data: data);
      if (mounted) showMessage(context, done);
      await _list.currentState?.reload();
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    }
  }

  Future<String?> _askText(String title, {bool required = false}) =>
      askText(context, title: title, label: required ? 'Motivo' : 'Mensaje (opcional)', required: required);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ofertas recibidas')),
      body: PagedSearchList<RancherOffer>(
        key: _list,
        showSearch: false,
        emptyText: 'Aún no tienes ofertas.',
        emptyIcon: Icons.handshake_outlined,
        filters: const {'pending': 'Pendientes', 'negotiating': 'En negociación', 'accepted': 'Aceptadas', 'rejected': 'Rechazadas'},
        fetch: (ref, page, search, filter) async {
          final body = await ref.read(apiClientProvider).get('/rancher/offers', query: {'page': page, if (filter != null) 'status': filter});
          return (
            items: [for (final j in body['data'] as List) RancherOffer.fromJson(j as Map<String, dynamic>)],
            lastPage: (body['meta'] as Map)['last_page'] as int,
          );
        },
        itemBuilder: (context, o) => Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(o.livestockTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall)),
                const SizedBox(width: 8),
                Flexible(child: StatusBadge(o.awaitingYou ? 'Te toca responder' : o.statusLabel)),
              ]),
              if (o.buyerName != null) Text('Comprador: ${o.buyerName}'),
              const SizedBox(height: 4),
              Text('Oferta: ${money(o.offerPrice)} · Precio publicado: ${money(o.livestockPrice)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (o.message != null && o.message!.isNotEmpty) Text('Mensaje: ${o.message}'),
              if (o.response != null && o.response!.isNotEmpty) Text('Tu respuesta: ${o.response}'),
              if (o.awaitingYou)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(spacing: 8, runSpacing: 4, children: [
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                      onPressed: () async {
                        final msg = await _askText('Aceptar oferta de ${money(o.offerPrice)}');
                        if (msg != null) await _act(o, 'accept', {if (msg.isNotEmpty) 'rancher_response': msg}, 'Oferta aceptada.');
                      },
                      child: const Text('Aceptar'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final amount = await askAmount(context, title: 'Tu contraoferta', initial: o.livestockPrice, action: 'Enviar');
                        if (amount != null) await _act(o, 'negotiate', {'offer_price': amount}, 'Contraoferta enviada.');
                      },
                      child: const Text('Contraofertar'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final reason = await _askText('Rechazar oferta', required: true);
                        if (reason != null) await _act(o, 'reject', {'rancher_response': reason}, 'Oferta rechazada.');
                      },
                      child: const Text('Rechazar'),
                    ),
                  ]),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
