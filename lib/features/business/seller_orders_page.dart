import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/paged_list.dart';
import '../../core/widgets.dart';
import 'business_models.dart';

class SellerOrdersPage extends ConsumerStatefulWidget {
  const SellerOrdersPage({super.key});

  @override
  ConsumerState<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends ConsumerState<SellerOrdersPage> {
  final _list = GlobalKey<PagedSearchListState<SellerOrder>>();

  Future<void> _act(SellerOrder o, String action, {Map<String, dynamic>? data, required String done}) async {
    try {
      await ref.read(apiClientProvider).post('/seller/orders/${o.id}/$action', data: data);
      if (mounted) showMessage(context, done);
      await _list.currentState?.reload();
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    }
  }

  Future<void> _ship(SellerOrder o) async {
    final tracking = await askText(context, title: 'Marcar como enviado', label: 'Número de guía (opcional)');
    if (tracking != null) {
      await _act(o, 'ship', data: {if (tracking.isNotEmpty) 'tracking_number': tracking}, done: 'Pedido marcado como enviado.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos de venta')),
      body: PagedSearchList<SellerOrder>(
        key: _list,
        showSearch: false,
        emptyText: 'Aún no tienes pedidos.',
        emptyIcon: Icons.receipt_long_outlined,
        filters: const {'pending': 'Por cobrar', 'confirmed': 'Por preparar', 'processing': 'En preparación', 'shipped': 'Enviados', 'delivered': 'Entregados'},
        fetch: (ref, page, search, filter) async {
          final body = await ref.read(apiClientProvider).get('/seller/orders', query: {'page': page, if (filter != null) 'status': filter});
          return (
            items: [for (final j in body['data'] as List) SellerOrder.fromJson(j as Map<String, dynamic>)],
            lastPage: (body['meta'] as Map)['last_page'] as int,
          );
        },
        itemBuilder: (context, o) => _OrderCard(
          order: o,
          onConfirm: () async {
            if (await confirm(context, '¿Confirmas que recibiste el pago?')) {
              await _act(o, 'confirm-payment', done: 'Pago confirmado. Prepara el pedido y márcalo como enviado.');
            }
          },
          onProcess: () => _act(o, 'process', done: 'Pedido en preparación.'),
          onShip: () => _ship(o),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onConfirm, required this.onProcess, required this.onShip});
  final SellerOrder order;
  final VoidCallback onConfirm;
  final VoidCallback onProcess;
  final VoidCallback onShip;

  @override
  Widget build(BuildContext context) {
    final o = order;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(o.number ?? 'Pedido #${o.id}', style: Theme.of(context).textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Flexible(child: StatusBadge(o.statusLabel)),
          ]),
          if (o.buyerName != null) Text('Comprador: ${o.buyerName}${o.buyerPhone != null ? ' · ${o.buyerPhone}' : ''}'),
          const SizedBox(height: 6),
          for (final i in o.items) Text(i, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text('Total: ${money(o.total)} · ${o.paymentMethod == 'cash' ? 'Efectivo' : 'Transferencia'}', style: const TextStyle(fontWeight: FontWeight.bold)),
          if (o.address != null) Text('Entrega: ${o.address}', style: Theme.of(context).textTheme.bodySmall),
          if (o.notes != null && o.notes!.isNotEmpty) Text('Notas: ${o.notes}', style: Theme.of(context).textTheme.bodySmall),
          if (o.transferReference != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text('Comprobante: ref. ${o.transferReference}${o.transferBank != null ? ' · ${o.transferBank}' : ''}${o.transferDate != null ? ' · ${o.transferDate}' : ''}'),
            )
          else if (o.canConfirmPayment && o.paymentMethod != 'cash')
            const Padding(padding: EdgeInsets.only(top: 6), child: Text('El comprador aún no envió el comprobante de pago.', style: TextStyle(fontStyle: FontStyle.italic))),
          if (o.trackingNumber != null) Text('Guía: ${o.trackingNumber}'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            if (o.canConfirmPayment) FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: onConfirm, child: const Text('Confirmar pago')),
            if (o.canProcess) OutlinedButton(onPressed: onProcess, child: const Text('En preparación')),
            if (o.canShip) FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: onShip, child: const Text('Marcar enviado')),
            OutlinedButton.icon(onPressed: () => context.push('/orders/${o.id}/messages'), icon: const Icon(Icons.chat_bubble_outline, size: 18), label: const Text('Mensajes')),
          ]),
        ]),
      ),
    );
  }
}
