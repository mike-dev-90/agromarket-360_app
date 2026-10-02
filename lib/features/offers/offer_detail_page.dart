import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../orders/orders_page.dart';
import 'offer.dart';
import 'offers_page.dart';

final offerDetailProvider = FutureProvider.autoDispose.family<Offer, int>((ref, id) async {
  final body = await ref.read(apiClientProvider).get('/offers/$id');
  return Offer.fromJson(body['data'] as Map<String, dynamic>);
});

class OfferDetailPage extends ConsumerStatefulWidget {
  const OfferDetailPage({super.key, required this.id});
  final int id;

  @override
  ConsumerState<OfferDetailPage> createState() => _OfferDetailPageState();
}

class _OfferDetailPageState extends ConsumerState<OfferDetailPage> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(offerDetailProvider(widget.id));
      ref.invalidate(offersProvider);
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _post(String action, [Map<String, dynamic>? data]) =>
      _run(() => ref.read(apiClientProvider).post('/offers/${widget.id}/$action', data: data).then((_) {}));

  Future<void> _counter(Offer o) async {
    final amount = await askAmount(context, title: 'Tu contraoferta', initial: o.offerPrice, action: 'Enviar');
    if (amount != null) await _post('counter', {'offer_price': amount});
  }

  Future<void> _buy(Offer o) async {
    setState(() => _busy = true);
    try {
      final body = await ref.read(apiClientProvider).post('/orders', data: {'livestock_id': o.livestockId, 'offer_id': o.id});
      ref.invalidate(ordersProvider);
      final id = (body['data'] as Map)['id'];
      if (mounted) context.pushReplacement('/orders/$id');
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(offerDetailProvider(widget.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de la oferta')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(offerDetailProvider(widget.id))),
        data: (o) => ListView(padding: const EdgeInsets.all(16), children: [
          Text(o.livestockTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _row('Estado', o.statusLabel),
          _row('Precio publicado', money(o.livestockPrice)),
          _row(o.offeredBy == 'rancher' ? 'Propuesta del vendedor' : 'Tu propuesta', money(o.offerPrice)),
          if (o.message != null && o.message!.isNotEmpty) ...[const SizedBox(height: 12), Text('Tu mensaje: ${o.message}')],
          if (o.rancherResponse != null && o.rancherResponse!.isNotEmpty) ...[const SizedBox(height: 12), Text('Respuesta del vendedor: ${o.rancherResponse}')],
          const SizedBox(height: 24),
          if (o.awaitingBuyer) ...[
            FilledButton(onPressed: _busy ? null : () => _post('accept'), child: Text('Aceptar ${money(o.offerPrice)}')),
            const SizedBox(height: 8),
            OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)), onPressed: _busy ? null : () => _counter(o), child: const Text('Hacer contraoferta')),
          ],
          if (o.isOpen) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () async {
                if (await confirm(context, '¿Rechazar y cerrar esta negociación?')) await _post('reject');
              },
              child: const Text('Rechazar / cerrar negociación'),
            ),
          ],
          if (o.status == 'accepted') FilledButton(onPressed: _busy ? null : () => _buy(o), child: const Text('Continuar con la compra')),
          if (o.isOpen && !o.awaitingBuyer) const Text('Esperando la respuesta del vendedor.', textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(flex: 3, child: Text(value, textAlign: TextAlign.end)),
        ]),
      );
}
