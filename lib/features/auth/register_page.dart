import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import 'auth_controller.dart';

const provinces = [
  'Azuay', 'Bolívar', 'Cañar', 'Carchi', 'Chimborazo', 'Cotopaxi', 'El Oro', 'Esmeraldas', 'Galápagos', 'Guayas',
  'Imbabura', 'Loja', 'Los Ríos', 'Manabí', 'Morona Santiago', 'Napo', 'Orellana', 'Pastaza', 'Pichincha',
  'Santa Elena', 'Santo Domingo de los Tsáchilas', 'Sucumbíos', 'Tungurahua', 'Zamora Chinchipe',
];

const accountTypes = {'comprador': 'Comprador', 'ganadero': 'Ganadero', 'profesional': 'Profesional (veterinario, nutrición...)', 'proveedor': 'Proveedor de insumos'};

const professions = {
  'veterinario': 'Veterinario',
  'reproduccion_genetica': 'Reproducción y genética',
  'nutricion': 'Nutrición',
  'tramites_movilizacion': 'Trámites de movilización',
  'infraestructura_finca': 'Infraestructura de finca',
  'entrenador': 'Entrenador',
  'herrador': 'Herrador',
  'esquilador': 'Esquilador',
};

const purchasePurposes = {'consumo': 'Consumo', 'reventa': 'Reventa', 'cria': 'Cría'};

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _state;
  String? _purpose;
  String _type = 'comprador';
  String? _profession;
  final _farm = TextEditingController();
  final _cattleType = TextEditingController();
  final _hectares = TextEditingController();
  final _license = TextEditingController();
  final _company = TextEditingController();
  final _nit = TextEditingController();
  final _products = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _city, _password, _confirm, _farm, _cattleType, _hectares, _license, _company, _nit, _products]) {
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
      await ref.read(authProvider.notifier).register({
        'user_type': _type,
        ..._roleFields(),
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'city': _city.text.trim(),
        'state': _state!,
        'purchase_purpose': _purpose!,
        'password': _password.text,
        'password_confirmation': _confirm.text,
      });
      if (mounted) context.go('/');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic> _roleFields() {
    switch (_type) {
      case 'ganadero':
        return {'nombre_finca': _farm.text.trim(), 'tipo_ganado': _cattleType.text.trim(), if (_hectares.text.trim().isNotEmpty) 'hectareas': _hectares.text.trim()};
      case 'profesional':
        return {'profesion': _profession, 'registro_profesional': _license.text.trim()};
      case 'proveedor':
        return {'nombre_empresa': _company.text.trim(), 'nit': _nit.text.trim(), 'tipo_productos': [for (final x in _products.text.split(',')) if (x.trim().isNotEmpty) x.trim()]};
      default:
        return {};
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo de cuenta'),
              items: [for (final e in accountTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => _type = v ?? 'comprador'),
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre completo'), validator: _required),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo electrónico'),
              validator: (v) => (v == null || !v.contains('@')) ? 'Ingresa un correo válido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono'), validator: _required),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _state,
              decoration: const InputDecoration(labelText: 'Provincia'),
              items: [for (final p in provinces) DropdownMenuItem(value: p, child: Text(p))],
              onChanged: (v) => setState(() => _state = v),
              validator: (v) => v == null ? 'Selecciona tu provincia' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _city, decoration: const InputDecoration(labelText: 'Ciudad'), validator: _required),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _purpose,
              decoration: const InputDecoration(labelText: '¿Para qué compras?'),
              items: [for (final e in purchasePurposes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setState(() => _purpose = v),
              validator: (v) => v == null ? 'Selecciona una opción' : null,
            ),
            const SizedBox(height: 16),
            if (_type == 'ganadero') ...[
              TextFormField(controller: _farm, decoration: const InputDecoration(labelText: 'Nombre de la finca'), validator: _required),
              const SizedBox(height: 16),
              TextFormField(controller: _cattleType, decoration: const InputDecoration(labelText: 'Tipo de ganado (bovino, porcino...)'), validator: _required),
              const SizedBox(height: 16),
              TextFormField(controller: _hectares, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Hectáreas (opcional)')),
              const SizedBox(height: 16),
            ],
            if (_type == 'profesional') ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _profession,
                decoration: const InputDecoration(labelText: 'Profesión'),
                items: [for (final e in professions.entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setState(() => _profession = v),
                validator: (v) => v == null ? 'Selecciona tu profesión' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _license, decoration: const InputDecoration(labelText: 'Registro profesional'), validator: _required),
              const SizedBox(height: 16),
            ],
            if (_type == 'proveedor') ...[
              TextFormField(controller: _company, decoration: const InputDecoration(labelText: 'Nombre de la empresa'), validator: _required),
              const SizedBox(height: 16),
              TextFormField(controller: _nit, decoration: const InputDecoration(labelText: 'RUC'), validator: _required),
              const SizedBox(height: 16),
              TextFormField(controller: _products, decoration: const InputDecoration(labelText: 'Tipos de productos', helperText: 'Separados por comas: alimentos, vacunas'), validator: _required),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña (mínimo 8 caracteres)'),
              validator: (v) => (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Repite la contraseña'),
              validator: (v) => v != _password.text ? 'Las contraseñas no coinciden' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Crear cuenta'),
            ),
          ]),
        ),
      ),
    );
  }
}
