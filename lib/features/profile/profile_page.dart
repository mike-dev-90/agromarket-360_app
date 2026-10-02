import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import '../auth/register_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Editar perfil')),
        body: const LoginRequired(message: 'Inicia sesión para editar tu perfil.', child: _ProfileForm()),
      );
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm();

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _email, _phone, _whatsapp, _address, _city;
  String? _state;
  String? _purpose;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = ref.read(authProvider).valueOrNull!;
    _name = TextEditingController(text: u.name);
    _email = TextEditingController(text: u.email);
    _phone = TextEditingController(text: u.phone ?? '');
    _whatsapp = TextEditingController(text: u.whatsapp ?? '');
    _address = TextEditingController(text: u.address ?? '');
    _city = TextEditingController(text: u.city ?? '');
    _state = provinces.contains(u.state) ? u.state : null;
    _purpose = purchasePurposes.containsKey(u.purchasePurpose) ? u.purchasePurpose : null;
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _whatsapp, _address, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = await ref.read(apiClientProvider).put('/profile', data: {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'whatsapp': _whatsapp.text.trim(),
        'address': _address.text.trim(),
        'city': _city.text.trim(),
        'state': _state,
        'purchase_purpose': _purpose,
      });
      ref.read(authProvider.notifier).setUser(body['data'] as Map<String, dynamic>);
      if (mounted) showMessage(context, 'Perfil actualizado correctamente.');
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre completo'), validator: _required),
        const SizedBox(height: 16),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Correo electrónico'),
          validator: (v) => (v == null || !v.contains('@')) ? 'Ingresa un correo válido' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono')),
        const SizedBox(height: 16),
        TextFormField(controller: _whatsapp, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp')),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _state,
          decoration: const InputDecoration(labelText: 'Provincia'),
          items: [for (final p in provinces) DropdownMenuItem(value: p, child: Text(p))],
          onChanged: (v) => setState(() => _state = v),
        ),
        const SizedBox(height: 16),
        TextFormField(controller: _city, decoration: const InputDecoration(labelText: 'Ciudad')),
        const SizedBox(height: 16),
        TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Dirección')),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _purpose,
          decoration: const InputDecoration(labelText: '¿Para qué compras?', helperText: 'Requisito para verificar tu identidad'),
          items: [for (final e in purchasePurposes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => _purpose = v),
        ),
        if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar cambios'),
        ),
      ]),
    );
  }
}
