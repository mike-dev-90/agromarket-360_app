import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/form_widgets.dart';
import '../../core/format.dart';
import '../../core/paged_list.dart';
import '../../core/widgets.dart';
import '../catalog/livestock.dart';
import 'business_models.dart';

class RancherAuctionsPage extends ConsumerStatefulWidget {
  const RancherAuctionsPage({super.key});

  @override
  ConsumerState<RancherAuctionsPage> createState() => _RancherAuctionsPageState();
}

class _RancherAuctionsPageState extends ConsumerState<RancherAuctionsPage> {
  final _list = GlobalKey<PagedSearchListState<BizAuction>>();

  Future<void> _open(String route) async {
    await context.push(route);
    await _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis subastas')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _open('/business/auctions/new'), icon: const Icon(Icons.add), label: const Text('Nueva subasta')),
      body: PagedSearchList<BizAuction>(
        key: _list,
        showSearch: false,
        emptyText: 'Aún no has creado subastas.',
        emptyIcon: Icons.gavel,
        fetch: (ref, page, search, filter) async {
          final body = await ref.read(apiClientProvider).get('/rancher/auctions', query: {'page': page});
          return (
            items: [for (final j in body['data'] as List) BizAuction.fromJson(j as Map<String, dynamic>)],
            lastPage: (body['meta'] as Map)['last_page'] as int,
          );
        },
        itemBuilder: (context, a) => Card(
          child: ListTile(
            onTap: () => _open('/business/auctions/${a.id}'),
            title: Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text('${a.statusLabel} · ${a.bidCount} pujas${a.endsAt != null ? ' · cierra ${shortDateTime(a.endsAt!)}' : ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: PriceTrailing(money(a.currentPrice)),
          ),
        ),
      ),
    );
  }
}

class RancherAuctionDetailPage extends ConsumerStatefulWidget {
  const RancherAuctionDetailPage({super.key, required this.id});
  final int id;

  @override
  ConsumerState<RancherAuctionDetailPage> createState() => _RancherAuctionDetailPageState();
}

class _RancherAuctionDetailPageState extends ConsumerState<RancherAuctionDetailPage> {
  BizAuction? _auction;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = (await ref.read(apiClientProvider).get('/rancher/auctions/${widget.id}'))['data'] as Map<String, dynamic>;
      if (mounted) setState(() => _auction = BizAuction.fromJson(d));
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    }
  }

  Future<void> _call(Future<void> Function() action, String done, {bool leave = false}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showMessage(context, done);
      if (leave) {
        context.pop();
      } else {
        await _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _auction;
    return Scaffold(
      appBar: AppBar(title: const Text('Subasta')),
      body: a == null
          ? (_error != null ? ErrorRetry(error: _error!, onRetry: () {
              setState(() => _error = null);
              _load();
            }) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Text(a.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Chip(label: Text(a.statusLabel)),
                if (a.description != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(a.description!)),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      _row('Precio inicial', money(a.startingPrice)),
                      _row('Precio actual', money(a.currentPrice)),
                      _row('Pujas', '${a.bidCount}'),
                      if (a.startsAt != null) _row('Inicia', shortDateTime(a.startsAt!)),
                      if (a.endsAt != null) _row('Cierra', shortDateTime(a.endsAt!)),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Pujas', style: Theme.of(context).textTheme.titleMedium),
                if (a.bids.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Aún no hay pujas.')),
                for (final b in a.bids) ListTile(dense: true, leading: const Icon(Icons.gavel), title: Text(b.bidder), trailing: PriceTrailing(money(b.amount), color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 12),
                if (a.status != 'cancelled') ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: _busy ? null : () async {
                      await context.push('/business/auctions/${a.id}/edit');
                      await _load();
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar subasta'),
                  ),
                  if (a.bids.isEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton(onPressed: _busy ? null : () async {
                      if (await confirm(context, '¿Cancelar esta subasta?')) await _call(() => ref.read(apiClientProvider).post('/rancher/auctions/${widget.id}/cancel').then((_) {}), 'Subasta cancelada.');
                    }, child: const Text('Cancelar subasta')),
                    TextButton(onPressed: _busy ? null : () async {
                      if (await confirm(context, '¿Eliminar esta subasta?')) await _call(() => ref.read(apiClientProvider).delete('/rancher/auctions/${widget.id}').then((_) {}), 'Subasta eliminada.', leave: true);
                    }, child: const Text('Eliminar subasta')),
                  ] else
                    const Padding(padding: EdgeInsets.only(top: 8), child: Text('Con pujas ya no se puede cancelar ni eliminar.', textAlign: TextAlign.center)),
                ],
              ]),
            ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: Colors.grey))), const SizedBox(width: 8), Flexible(child: Text(value, textAlign: TextAlign.end))]),
      );
}

/// Crear o editar una subasta.
class AuctionFormPage extends ConsumerStatefulWidget {
  const AuctionFormPage({super.key, this.id});
  final int? id;

  @override
  ConsumerState<AuctionFormPage> createState() => _AuctionFormPageState();
}

class _AuctionFormPageState extends ConsumerState<AuctionFormPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _breed = TextEditingController();
  final _start = TextEditingController();
  final _increment = TextEditingController(text: '25');
  final _reserve = TextEditingController();
  final _buyNow = TextEditingController();
  final _terms = TextEditingController();
  final _location = TextEditingController();
  String? _type, _sex;
  String _status = 'pending';
  DateTime? _startsAt, _endsAt;
  bool _loading = false, _busy = false;
  String? _error;

  bool get _editing => widget.id != null;

  @override
  void initState() {
    super.initState();
    if (_editing) _load();
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _breed, _start, _increment, _reserve, _buyNow, _terms, _location]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = (await ref.read(apiClientProvider).get('/rancher/auctions/${widget.id}'))['data'] as Map<String, dynamic>;
      setState(() {
        _title.text = d['title'] as String? ?? '';
        _description.text = d['description'] as String? ?? '';
        _start.text = '${d['starting_price']}';
        _increment.text = '${d['min_bid_increment']}';
        _reserve.text = d['reserve_price'] == null ? '' : '${d['reserve_price']}';
        _buyNow.text = d['buy_now_price'] == null ? '' : '${d['buy_now_price']}';
        _terms.text = d['auction_terms'] as String? ?? '';
        _location.text = d['location'] as String? ?? '';
        _status = d['status'] == 'draft' ? 'draft' : 'pending';
        _startsAt = d['starts_at'] != null ? DateTime.parse(d['starts_at'] as String).toLocal() : null;
        _endsAt = d['ends_at'] != null ? DateTime.parse(d['ends_at'] as String).toLocal() : null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_startsAt == null || _endsAt == null) {
      setState(() => _error = 'Elige la fecha de inicio y la de cierre.');
      return;
    }
    if (!_endsAt!.isAfter(_startsAt!)) {
      setState(() => _error = 'La fecha de cierre debe ser posterior a la de inicio.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    String? n(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim().replaceAll(',', '.');
    try {
      final data = <String, dynamic>{
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'starting_price': n(_start),
        'min_bid_increment': n(_increment),
        'reserve_price': n(_reserve),
        'buy_now_price': n(_buyNow),
        'start_time': apiDateTime(_startsAt!),
        'end_time': apiDateTime(_endsAt!),
        'auction_terms': _terms.text.trim().isEmpty ? null : _terms.text.trim(),
        'location': _location.text.trim().isEmpty ? null : _location.text.trim(),
        'status': _status,
        if (!_editing) ...{'type': _type, 'sex': _sex, if (_breed.text.trim().isNotEmpty) 'breed': _breed.text.trim()},
      };
      final api = ref.read(apiClientProvider);
      if (_editing) {
        await api.put('/rancher/auctions/${widget.id}', data: data);
      } else {
        await api.post('/rancher/auctions', data: data);
      }
      if (mounted) {
        showMessage(context, _editing ? 'Subasta actualizada.' : 'Subasta creada.');
        context.pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate(bool start) async {
    final picked = await pickDateTime(context, initial: (start ? _startsAt : _endsAt) ?? DateTime.now().add(Duration(days: start ? 0 : 2)));
    if (picked != null) setState(() => start ? _startsAt = picked : _endsAt = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Editar subasta' : 'Nueva subasta')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                appTextField(_title, 'Título', required: true),
                appTextField(_description, 'Descripción', required: true, maxLines: 3),
                if (!_editing) ...[
                  appDropdown<String>('Tipo de animal', _type, livestockTypes, (v) => setState(() => _type = v), required: true),
                  appDropdown<String>('Sexo', _sex, const {'male': 'Macho', 'female': 'Hembra'}, (v) => setState(() => _sex = v), required: true),
                  appTextField(_breed, 'Raza'),
                ],
                appNumberField(_start, 'Precio inicial (USD)', required: true),
                appNumberField(_increment, 'Incremento mínimo de puja (USD)'),
                appNumberField(_reserve, 'Precio de reserva (opcional)', helper: 'Si no se alcanza, no hay venta'),
                appNumberField(_buyNow, 'Precio de compra inmediata (opcional)'),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  icon: const Icon(Icons.play_circle_outline),
                  label: Text(_startsAt == null ? 'Inicio de la subasta' : 'Inicia: ${shortDateTime(_startsAt!)}'),
                  onPressed: () => _pickDate(true),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(_endsAt == null ? 'Cierre de la subasta' : 'Cierra: ${shortDateTime(_endsAt!)}'),
                  onPressed: () => _pickDate(false),
                ),
                const SizedBox(height: 14),
                appTextField(_location, 'Ubicación'),
                appTextField(_terms, 'Condiciones de la subasta', maxLines: 3),
                appDropdown<String>('Estado', _status, const {'pending': 'Publicar (programada)', 'draft': 'Guardar como borrador'}, (v) => setState(() => _status = v ?? 'pending'), required: true),
                errorLine(context, _error),
                submitButton(_editing ? 'Guardar cambios' : 'Crear subasta', _busy, _save),
              ]),
            ),
    );
  }
}
