import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import 'order.dart';
import 'orders_page.dart';

final orderDetailProvider = FutureProvider.autoDispose.family<Order, int>((ref, id) async {
  final body = await ref.read(apiClientProvider).get('/orders/$id');
  return Order.fromJson(body['data'] as Map<String, dynamic>);
});

class OrderDetailPage extends ConsumerStatefulWidget {
  const OrderDetailPage({super.key, required this.id});
  final int id;

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(orderDetailProvider(widget.id));
      ref.invalidate(ordersProvider);
      if (mounted) showMessage(context, done);
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendProof() async {
    final data = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ProofSheet(),
    );
    if (data == null) return;
    await _run(() => ref.read(apiClientProvider).post('/orders/${widget.id}/transfer-proof', data: data).then((_) {}), 'Comprobante enviado. El vendedor confirmará tu pago.');
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(orderDetailProvider(widget.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del pedido')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(orderDetailProvider(widget.id))),
        data: (o) => ListView(padding: const EdgeInsets.all(16), children: [
          Text(o.number ?? 'Pedido #${o.id}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Chip(label: Text(o.statusLabel)),
          const Divider(height: 24),
          for (final i in o.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text('${i.quantity} × ${i.name}')),
                const SizedBox(width: 8),
                Flexible(child: Text(money(i.total), textAlign: TextAlign.end)),
              ]),
            ),
          const Divider(height: 24),
          Row(children: [
            const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Expanded(child: Text(money(o.total), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold))),
          ]),
          if (o.canSendProof) ...[
            const SizedBox(height: 20),
            _BankCard(bank: o.bank),
            const SizedBox(height: 12),
            if (o.transferReference != null) Text('Comprobante enviado (ref. ${o.transferReference}). Esperando confirmación del vendedor.'),
            const SizedBox(height: 8),
            FilledButton(onPressed: _busy ? null : _sendProof, child: Text(o.transferReference == null ? 'Ya hice la transferencia' : 'Enviar otro comprobante')),
          ],
          if (o.canConfirmDelivery) ...[
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : () async {
                if (await confirm(context, '¿Confirmas que recibiste tu pedido?')) {
                  await _run(() => ref.read(apiClientProvider).post('/orders/${widget.id}/confirm-delivery').then((_) {}), 'Entrega confirmada. ¡Gracias por tu compra!');
                }
              },
              child: const Text('Confirmar que lo recibí'),
            ),
          ],
          if (o.canCancel) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () async {
                if (await confirm(context, '¿Cancelar este pedido?')) {
                  await _run(() => ref.read(apiClientProvider).post('/orders/${widget.id}/cancel').then((_) {}), 'Pedido cancelado.');
                }
              },
              child: const Text('Cancelar pedido'),
            ),
          ],
        ]),
      ),
    );
  }
}

class _BankCard extends StatelessWidget {
  const _BankCard({required this.bank});
  final BankInfo? bank;

  @override
  Widget build(BuildContext context) {
    final b = bank;
    if (b == null || !b.isConfigured) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(16), child: Text('Los datos bancarios aún no están configurados. Contacta con soporte para recibirlos.')),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Datos para la transferencia', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (b.bank != null) Text('Banco: ${b.bank}'),
          if (b.accountType != null) Text('Tipo de cuenta: ${b.accountType}'),
          Text('Cuenta: ${b.accountNumber}'),
          if (b.holder != null) Text('Titular: ${b.holder}'),
          if (b.document != null) Text('RUC/CI: ${b.document}'),
        ]),
      ),
    );
  }
}

class _ProofSheet extends StatefulWidget {
  const _ProofSheet();

  @override
  State<_ProofSheet> createState() => _ProofSheetState();
}

class _ProofSheetState extends State<_ProofSheet> {
  final _form = GlobalKey<FormState>();
  final _reference = TextEditingController();
  final _bank = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _reference.dispose();
    _bank.dispose();
    super.dispose();
  }

  String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Comprobante de transferencia', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(controller: _reference, decoration: const InputDecoration(labelText: 'Número de referencia'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _bank, decoration: const InputDecoration(labelText: 'Banco desde el que transferiste'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.calendar_today),
              label: Text('Fecha: ${_iso(_date)}'),
              onPressed: () async {
                final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now());
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(context, {'reference_number': _reference.text.trim(), 'bank_name': _bank.text.trim(), 'transfer_date': _iso(_date)});
                }
              },
              child: const Text('Enviar comprobante'),
            ),
          ]),
        ),
      ),
    );
  }
}
