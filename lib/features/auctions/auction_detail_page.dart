import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import 'auction.dart';

/// Detalle de subasta. No usa conexión permanente: consulta la API cada [AppConfig.auctionPollSeconds]
/// segundos mientras la pantalla está visible, y la cuenta atrás se calcula en el teléfono.
class AuctionDetailPage extends ConsumerStatefulWidget {
  const AuctionDetailPage({super.key, required this.id});
  final int id;

  @override
  ConsumerState<AuctionDetailPage> createState() => _AuctionDetailPageState();
}

class _AuctionDetailPageState extends ConsumerState<AuctionDetailPage> with WidgetsBindingObserver {
  Auction? _auction;
  String? _error;
  Timer? _poll;
  Timer? _tick;
  bool _bidding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _startTimers();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimers();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
      _startTimers();
    } else {
      _stopTimers(); // en segundo plano no se consulta
    }
  }

  void _startTimers() {
    _stopTimers();
    _poll = Timer.periodic(const Duration(seconds: AppConfig.auctionPollSeconds), (_) => _load());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopTimers() {
    _poll?.cancel();
    _tick?.cancel();
  }

  Future<void> _load() async {
    try {
      final body = await ref.read(apiClientProvider).get('/auctions/${widget.id}');
      if (!mounted) return;
      setState(() {
        _auction = Auction.fromJson(body['data'] as Map<String, dynamic>);
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && _auction == null) setState(() => _error = e.message);
    }
  }

  Future<void> _bid() async {
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) {
      context.push('/login');
      return;
    }
    final a = _auction!;
    final controller = TextEditingController(text: (a.minimumNextBid ?? a.currentPrice).toStringAsFixed(2));
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tu puja'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(prefixText: r'$ ', helperText: 'Mínimo ${money(a.minimumNextBid ?? a.currentPrice)}'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text.replaceAll(',', '.'))),
            child: const Text('Pujar'),
          ),
        ],
      ),
    );
    if (amount == null) return;

    setState(() => _bidding = true);
    try {
      await ref.read(apiClientProvider).post('/auctions/${widget.id}/bids', data: {'amount': amount});
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Puja realizada!')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _bidding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _auction;
    return Scaffold(
      appBar: AppBar(title: const Text('Subasta')),
      body: a == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (a.image != null) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(a.image!, height: 200, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
                const SizedBox(height: 12),
                Text(a.title, style: Theme.of(context).textTheme.headlineSmall),
                if (a.breed != null) Text(a.breed!),
                const SizedBox(height: 16),
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      const Text('Precio actual'),
                      Text(money(a.currentPrice), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Cierra en: ${countdown(a.remaining)}'),
                      Text('${a.bidCount} pujas'),
                      if (a.myHighestBid != null) Text('Tu mejor puja: ${money(a.myHighestBid!)}'),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: (_bidding || !a.isRunning || a.remaining <= Duration.zero) ? null : _bid,
                  child: Text(a.isRunning && a.remaining > Duration.zero ? 'Pujar (mín. ${money(a.minimumNextBid ?? a.currentPrice)})' : 'Subasta no disponible'),
                ),
                if (a.description != null) ...[const SizedBox(height: 16), Text(a.description!)],
                if (a.location != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Ubicación: ${a.location}')),
                const Divider(height: 32),
                Text('Últimas pujas', style: Theme.of(context).textTheme.titleMedium),
                if (a.bids.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Aún no hay pujas.')),
                for (final b in a.bids)
                  ListTile(
                    dense: true,
                    leading: Icon(b.isMine ? Icons.person : Icons.gavel),
                    title: Text(b.isMine ? 'Tú' : b.bidder),
                    trailing: PriceTrailing(money(b.amount), color: Theme.of(context).colorScheme.onSurface),
                  ),
              ]),
            ),
    );
  }
}
