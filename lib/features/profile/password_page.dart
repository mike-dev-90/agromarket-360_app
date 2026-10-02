import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/widgets.dart';

class PasswordPage extends StatelessWidget {
  const PasswordPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Cambiar contraseña')),
        body: const LoginRequired(message: 'Inicia sesión para cambiar tu contraseña.', child: _PasswordForm()),
      );
}

class _PasswordForm extends ConsumerStatefulWidget {
  const _PasswordForm();

  @override
  ConsumerState<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends ConsumerState<_PasswordForm> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).put('/profile/password', data: {
        'current_password': _current.text,
        'password': _new.text,
        'password_confirmation': _confirm.text,
      });
      _current.clear();
      _new.clear();
      _confirm.clear();
      if (mounted) showMessage(context, 'Contraseña actualizada correctamente.');
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        TextFormField(controller: _current, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña actual'), validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
        const SizedBox(height: 16),
        TextFormField(controller: _new, obscureText: true, decoration: const InputDecoration(labelText: 'Nueva contraseña (mínimo 8 caracteres)'), validator: (v) => (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null),
        const SizedBox(height: 16),
        TextFormField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Repite la nueva contraseña'), validator: (v) => v != _new.text ? 'Las contraseñas no coinciden' : null),
        if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Actualizar contraseña'),
        ),
      ]),
    );
  }
}
