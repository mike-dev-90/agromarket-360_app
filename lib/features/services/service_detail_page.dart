import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import 'service_models.dart';
import 'service_requests_page.dart';

final serviceDetailProvider = FutureProvider.autoDispose.family<ServiceItem, int>((ref, id) async {
  final body = await ref.read(apiClientProvider).get('/services/$id');
  return ServiceItem.fromJson(body['data'] as Map<String, dynamic>);
});

class ServiceDetailPage extends ConsumerWidget {
  const ServiceDetailPage({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(serviceDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del servicio')),
      bottomNavigationBar: detail.valueOrNull == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: () async {
                    if (ref.read(authProvider).valueOrNull == null) {
                      context.push('/login');
                      return;
                    }
                    final sent = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => _RequestSheet(service: detail.value!));
                    if (sent == true && context.mounted) {
                      ref.invalidate(myServiceRequestsProvider);
                      showMessage(context, 'Solicitud enviada. El profesional te responderá pronto.');
                    }
                  },
                  child: const Text('Solicitar este servicio'),
                ),
              ),
            ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(serviceDetailProvider(id))),
        data: (s) => ListView(padding: const EdgeInsets.all(16), children: [
          Text(s.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(s.priceLabel, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
          if (s.category != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Categoría: ${s.category}')),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            if (s.homeVisit) const Chip(label: Text('Visita a domicilio')),
            if (s.emergencyService) const Chip(label: Text('Atiende emergencias')),
          ]),
          if (s.description != null) ...[const Divider(height: 32), Text(s.description!)],
          if (s.requirements != null && s.requirements!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text('Requisitos: ${s.requirements}')),
          if (s.coverageArea != null && s.coverageArea!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text('Cobertura: ${s.coverageArea}')),
          if (s.professionalName != null) ...[
            const Divider(height: 32),
            Text('Profesional', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text([s.professionalName!, if (s.profession != null) s.profession!].join(' · ')),
          ],
        ]),
      ),
    );
  }
}

class _RequestSheet extends ConsumerStatefulWidget {
  const _RequestSheet({required this.service});
  final ServiceItem service;

  @override
  ConsumerState<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends ConsumerState<_RequestSheet> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _time = TextEditingController();
  late final TextEditingController _location;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = ref.read(authProvider).valueOrNull;
    _location = TextEditingController(text: [u?.city, u?.state].whereType<String>().join(', '));
  }

  @override
  void dispose() {
    _description.dispose();
    _time.dispose();
    _location.dispose();
    super.dispose();
  }

  String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).post('/services/${widget.service.id}/requests', data: {
        'description': _description.text.trim(),
        'request_date': _iso(_date),
        'preferred_time': _time.text.trim().isEmpty ? null : _time.text.trim(),
        'location': _location.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Solicitar: ${widget.service.title}', style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Describe lo que necesitas'),
              validator: (v) => (v == null || v.trim().length < 10) ? 'Escribe al menos 10 caracteres' : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.calendar_today),
              label: Text('Fecha deseada: ${_iso(_date)}'),
              onPressed: () async {
                final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _time, decoration: const InputDecoration(labelText: 'Horario preferido (opcional)')),
            const SizedBox(height: 12),
            TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Ubicación (finca, ciudad)'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _send, child: const Text('Enviar solicitud')),
          ]),
        ),
      ),
    );
  }
}
