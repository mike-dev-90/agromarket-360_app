import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import '../auth/register_page.dart';
import '../orders/orders_page.dart';
import 'cart_provider.dart';

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Finalizar compra')),
        body: const LoginRequired(message: 'Inicia sesión para comprar.', child: _CheckoutForm()),
      );
}

class _CheckoutForm extends ConsumerStatefulWidget {
  const _CheckoutForm();

  @override
  ConsumerState<_CheckoutForm> createState() => _CheckoutFormState();
}

class _CheckoutFormState extends ConsumerState<_CheckoutForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _address, _city, _zip, _phone, _notes;
  String? _state;
  String _payment = 'transfer';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = ref.read(authProvider).valueOrNull;
    _address = TextEditingController(text: u?.address ?? '');
    _city = TextEditingController(text: u?.city ?? '');
    _zip = TextEditingController();
    _phone = TextEditingController(text: u?.phone ?? '');
    _notes = TextEditingController();
    _state = provinces.contains(u?.state) ? u?.state : null;
  }

  @override
  void dispose() {
    for (final c in [_address, _city, _zip, _phone, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = await ref.read(apiClientProvider).post('/checkout', data: {
        'shipping_address': _address.text.trim(),
        'shipping_city': _city.text.trim(),
        'shipping_state': _state,
        'shipping_zipcode': _zip.text.trim().isEmpty ? null : _zip.text.trim(),
        'phone': _phone.text.trim(),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'payment_method': _payment,
      });
      ref.invalidate(cartProvider);
      ref.invalidate(ordersProvider);
      final orders = body['data'] as List;
      if (!mounted) return;
      if (orders.length == 1) {
        context.pushReplacement('/orders/${(orders.first as Map)['id']}');
      } else {
        showMessage(context, 'Se crearon ${orders.length} pedidos (uno por vendedor).');
        context.go('/');
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null;

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider).valueOrNull;
    return Form(
      key: _form,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        if (cart != null)
          Card(
            child: ListTile(
              title: Text('${cart.count} ${cart.count == 1 ? 'producto' : 'productos'}'),
              trailing: PriceTrailing(money(cart.total)),
            ),
          ),
        const SizedBox(height: 8),
        Text('Dirección de entrega', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Dirección'), validator: _required),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _state,
          decoration: const InputDecoration(labelText: 'Provincia'),
          items: [for (final p in provinces) DropdownMenuItem(value: p, child: Text(p))],
          onChanged: (v) => setState(() => _state = v),
          validator: (v) => v == null ? 'Selecciona la provincia' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _city, decoration: const InputDecoration(labelText: 'Ciudad'), validator: _required),
        const SizedBox(height: 12),
        TextFormField(controller: _zip, decoration: const InputDecoration(labelText: 'Código postal (opcional)')),
        const SizedBox(height: 12),
        TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono de contacto'), validator: _required),
        const SizedBox(height: 12),
        TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notas para el vendedor (opcional)')),
        const SizedBox(height: 20),
        Text('Método de pago', style: Theme.of(context).textTheme.titleMedium),
        RadioGroup<String>(
          groupValue: _payment,
          onChanged: (v) => setState(() => _payment = v ?? 'transfer'),
          child: const Column(children: [
            RadioListTile<String>(value: 'transfer', title: Text('Transferencia bancaria'), subtitle: Text('Recibirás los datos y subirás el comprobante')),
            RadioListTile<String>(value: 'cash', title: Text('Efectivo contra entrega')),
          ]),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Confirmar pedido'),
        ),
      ]),
    );
  }
}
