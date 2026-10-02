import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import 'livestock.dart';

final livestockDetailProvider = FutureProvider.family<Livestock, int>((ref, id) async {
  final body = await ref.read(apiClientProvider).get('/livestock/$id');
  return Livestock.fromJson(body['data'] as Map<String, dynamic>);
});

class LivestockDetailPage extends ConsumerWidget {
  const LivestockDetailPage({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(livestockDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del animal')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
        data: (l) => ListView(children: [
          SizedBox(
            height: 240,
            child: l.images.isEmpty
                ? Container(color: Colors.green.shade50, child: const Icon(Icons.pets, size: 64, color: Colors.green))
                : PageView(children: [for (final url in l.images) Image.network(url, fit: BoxFit.cover)]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(money(l.price), style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
              if (l.negotiable) const Text('Precio negociable'),
              const Divider(height: 32),
              _row('Tipo', livestockTypes[l.type] ?? l.type),
              if (l.breed != null) _row('Raza', l.breed!),
              if (l.sex != null) _row('Sexo', l.sex == 'male' ? 'Macho' : 'Hembra'),
              if (l.ageYears != null) _row('Edad', '${l.ageYears} años'),
              if (l.weight != null) _row('Peso', '${l.weight} kg'),
              _row('Vacunado', l.isVaccinated ? 'Sí' : 'No'),
              if (l.location != null) _row('Ubicación', l.location!),
              if (l.sellerName != null) _row('Vendedor', l.sellerName!),
              if (l.description != null) ...[const Divider(height: 32), Text(l.description!)],
              if (l.healthNotes != null && l.healthNotes!.isNotEmpty) ...[const SizedBox(height: 12), Text('Salud: ${l.healthNotes}')],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey))), Expanded(child: Text(value))]),
      );
}
