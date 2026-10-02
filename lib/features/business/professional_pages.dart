import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/form_widgets.dart';
import '../../core/format.dart';
import '../../core/paged_list.dart';
import '../../core/widgets.dart';
import '../services/service_models.dart';
import '../services/service_requests_page.dart';
import 'business_models.dart';

// ---------- Mis servicios ----------

class ProfessionalServicesPage extends ConsumerStatefulWidget {
  const ProfessionalServicesPage({super.key});

  @override
  ConsumerState<ProfessionalServicesPage> createState() => _ProfessionalServicesPageState();
}

class _ProfessionalServicesPageState extends ConsumerState<ProfessionalServicesPage> {
  final _list = GlobalKey<PagedSearchListState<BizService>>();

  Future<void> _open(String route) async {
    await context.push(route);
    await _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis servicios')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _open('/business/services/new'), icon: const Icon(Icons.add), label: const Text('Nuevo servicio')),
      body: PagedSearchList<BizService>(
        key: _list,
        showSearch: false,
        emptyText: 'Aún no has publicado servicios.',
        emptyIcon: Icons.medical_services_outlined,
        filters: const {'active': 'Activos', 'inactive': 'Inactivos', 'pending': 'Pendientes'},
        fetch: (ref, page, search, filter) async {
          final body = await ref.read(apiClientProvider).get('/professional/services', query: {'page': page, if (filter != null) 'status': filter});
          return (
            items: [for (final j in body['data'] as List) BizService.fromJson(j as Map<String, dynamic>)],
            lastPage: (body['meta'] as Map)['last_page'] as int,
          );
        },
        itemBuilder: (context, s) => Card(
          child: ListTile(
            onTap: () => _open('/business/services/${s.id}/edit'),
            leading: const CircleAvatar(child: Icon(Icons.medical_services)),
            title: Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text('${s.statusLabel}${s.category != null ? ' · ${s.category}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: PriceTrailing(money(s.price)),
          ),
        ),
      ),
    );
  }
}

class ServiceFormPage extends ConsumerStatefulWidget {
  const ServiceFormPage({super.key, this.id});
  final int? id;

  @override
  ConsumerState<ServiceFormPage> createState() => _ServiceFormPageState();
}

class _ServiceFormPageState extends ConsumerState<ServiceFormPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _coverage = TextEditingController();
  final _requirements = TextEditingController();
  String? _category;
  String _priceType = 'por_visita';
  String _status = 'active';
  bool _home = false, _emergency = false;
  Map<String, String> _categories = {};
  bool _loading = true, _busy = false;
  String? _error;

  bool get _editing => widget.id != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _price, _coverage, _requirements]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final cats = await api.get('/service-categories');
      _categories = {for (final c in cats['data'] as List) '${(c as Map)['id']}': c['name'] as String};
      if (_editing) {
        final s = BizService.fromJson((await api.get('/professional/services/${widget.id}'))['data'] as Map<String, dynamic>);
        _title.text = s.title;
        _description.text = s.description ?? '';
        _price.text = '${s.price}';
        _coverage.text = s.coverageArea ?? '';
        _requirements.text = s.requirements ?? '';
        _category = s.categoryId?.toString();
        _priceType = s.priceType;
        _status = s.status;
        _home = s.homeVisit;
        _emergency = s.emergency;
      }
    } catch (e) {
      _error = errorText(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final fields = {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'service_category_id': _category!,
        'price': _price.text.trim().replaceAll(',', '.'),
        'price_type': _priceType,
        if (_coverage.text.trim().isNotEmpty) 'coverage_area': _coverage.text.trim(),
        if (_requirements.text.trim().isNotEmpty) 'requirements': _requirements.text.trim(),
        'home_visit': _home ? '1' : '0',
        'emergency_service': _emergency ? '1' : '0',
        'status': _status,
      };
      await ref.read(apiClientProvider).postForm(_editing ? '/professional/services/${widget.id}' : '/professional/services', fields: fields);
      if (mounted) {
        showMessage(context, _editing ? 'Servicio actualizado.' : 'Servicio publicado.');
        context.pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, '¿Eliminar este servicio?')) return;
    try {
      await ref.read(apiClientProvider).delete('/professional/services/${widget.id}');
      if (mounted) {
        showMessage(context, 'Servicio eliminado.');
        context.pop();
      }
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Editar servicio' : 'Nuevo servicio'), actions: [
        if (_editing) IconButton(tooltip: 'Eliminar', onPressed: _delete, icon: const Icon(Icons.delete_outline)),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                appTextField(_title, 'Título', required: true),
                appTextField(_description, 'Descripción', required: true, maxLines: 4),
                appDropdown<String>('Categoría', _category, _categories, (v) => setState(() => _category = v), required: true),
                appNumberField(_price, 'Precio (USD)', required: true),
                appDropdown<String>('Tipo de precio', _priceType, servicePriceTypes, (v) => setState(() => _priceType = v ?? 'por_visita'), required: true),
                appTextField(_coverage, 'Zona de cobertura'),
                appTextField(_requirements, 'Requisitos para el cliente', maxLines: 2),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Visita a domicilio'), value: _home, onChanged: (v) => setState(() => _home = v)),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Atiendo emergencias'), value: _emergency, onChanged: (v) => setState(() => _emergency = v)),
                appDropdown<String>('Estado', _status, const {'active': 'Activo', 'inactive': 'Inactivo', 'pending': 'Pendiente'}, (v) => setState(() => _status = v ?? 'active'), required: true),
                errorLine(context, _error),
                submitButton(_editing ? 'Guardar cambios' : 'Publicar servicio', _busy, _save),
              ]),
            ),
    );
  }
}

// ---------- Solicitudes recibidas ----------

class ProfessionalRequestsPage extends ConsumerStatefulWidget {
  const ProfessionalRequestsPage({super.key});

  @override
  ConsumerState<ProfessionalRequestsPage> createState() => _ProfessionalRequestsPageState();
}

class _ProfessionalRequestsPageState extends ConsumerState<ProfessionalRequestsPage> {
  final _list = GlobalKey<PagedSearchListState<ServiceRequestItem>>();

  Future<void> _act(ServiceRequestItem r, String action, String done, [Map<String, dynamic>? data]) async {
    try {
      await ref.read(apiClientProvider).post('/professional/requests/${r.id}/$action', data: data);
      if (mounted) showMessage(context, done);
      await _list.currentState?.reload();
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    }
  }

  Future<String?> _askText(String title, String label, {bool required = false}) =>
      askText(context, title: title, label: label, required: required);

  Future<void> _schedule(ServiceRequestItem r) async {
    final when = await pickDateTime(context, initial: DateTime.now().add(const Duration(days: 1)), first: DateTime.now());
    if (when == null || !mounted) return;
    final price = await askAmount(context, title: 'Cotización (opcional)', helper: 'Déjalo vacío si no aplica', action: 'Programar');
    if (!mounted) return;
    await _act(r, 'schedule', 'Cita programada.', {'scheduled_date': apiDateTime(when), if (price != null) 'price_quoted': price});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes de clientes')),
      body: PagedSearchList<ServiceRequestItem>(
        key: _list,
        showSearch: false,
        emptyText: 'Aún no tienes solicitudes.',
        emptyIcon: Icons.inbox_outlined,
        filters: const {'pending': 'Nuevas', 'accepted': 'Aceptadas', 'scheduled': 'Programadas', 'completed': 'Completadas', 'rejected': 'Rechazadas'},
        fetch: (ref, page, search, filter) async {
          final body = await ref.read(apiClientProvider).get('/professional/requests', query: {'page': page, if (filter != null) 'status': filter});
          return (
            items: [for (final j in body['data'] as List) ServiceRequestItem.fromJson(j as Map<String, dynamic>)],
            lastPage: (body['meta'] as Map)['last_page'] as int,
          );
        },
        itemBuilder: (context, r) => ServiceRequestCard(
          item: r,
          actions: [
            Wrap(spacing: 8, runSpacing: 4, children: [
              if (r.status == 'pending') FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: () => _act(r, 'accept', 'Solicitud aceptada.'), child: const Text('Aceptar')),
              if (const ['pending', 'accepted', 'scheduled'].contains(r.status)) OutlinedButton(onPressed: () => _schedule(r), child: Text(r.status == 'scheduled' ? 'Reprogramar' : 'Programar')),
              if (const ['accepted', 'scheduled'].contains(r.status))
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () async {
                    final notes = await _askText('Completar servicio', 'Notas (opcional)');
                    if (notes != null) await _act(r, 'complete', 'Servicio completado.', {if (notes.isNotEmpty) 'notes': notes});
                  },
                  child: const Text('Completar'),
                ),
              if (const ['pending', 'accepted'].contains(r.status))
                TextButton(
                  onPressed: () async {
                    final reason = await _askText('Rechazar solicitud', 'Motivo', required: true);
                    if (reason != null) await _act(r, 'reject', 'Solicitud rechazada.', {'response_message': reason});
                  },
                  child: const Text('Rechazar'),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}
