import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import 'service_models.dart';

final myServiceRequestsProvider = FutureProvider.autoDispose<List<ServiceRequestItem>>((ref) async {
  ref.watch(authProvider.select((u) => u.valueOrNull?.id));
  final body = await ref.read(apiClientProvider).get('/service-requests');
  return [for (final j in body['data'] as List) ServiceRequestItem.fromJson(j as Map<String, dynamic>)];
});

class ServiceRequestsPage extends StatelessWidget {
  const ServiceRequestsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mis solicitudes de servicio')),
        body: const LoginRequired(message: 'Inicia sesión para ver tus solicitudes.', child: _Body()),
      );
}

class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(myServiceRequestsProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(myServiceRequestsProvider)),
          data: (items) => RefreshIndicator(
            onRefresh: () async => ref.refresh(myServiceRequestsProvider.future),
            child: items.isEmpty
                ? EmptyState(
                    icon: Icons.medical_services_outlined,
                    text: 'Aún no has solicitado servicios.',
                    action: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(180, 48)), onPressed: () => context.go('/'), child: const Text('Ver servicios')),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (_, i) => ServiceRequestCard(item: items[i], onCancel: items[i].clientCanCancel ? () => _cancel(context, ref, items[i]) : null),
                  ),
          ),
        );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, ServiceRequestItem r) async {
    if (!await confirm(context, '¿Cancelar esta solicitud?')) return;
    try {
      await ref.read(apiClientProvider).post('/service-requests/${r.id}/cancel');
      ref.invalidate(myServiceRequestsProvider);
    } catch (e) {
      if (context.mounted) showMessage(context, errorText(e));
    }
  }
}

class ServiceRequestCard extends StatelessWidget {
  const ServiceRequestCard({super.key, required this.item, this.onCancel, this.actions = const []});
  final ServiceRequestItem item;
  final VoidCallback? onCancel;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(item.serviceTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall)),
            const SizedBox(width: 8),
            Chip(label: Text(item.statusLabel), visualDensity: VisualDensity.compact),
          ]),
          if (item.otherParty != null) Text(item.otherParty!, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(item.description),
          const SizedBox(height: 6),
          Text([
            if (item.requestDate != null) 'Fecha deseada: ${item.requestDate}',
            if (item.scheduledDate != null) 'Programada: ${item.scheduledDate!.day}/${item.scheduledDate!.month}/${item.scheduledDate!.year} ${item.scheduledDate!.hour.toString().padLeft(2, '0')}:${item.scheduledDate!.minute.toString().padLeft(2, '0')}',
            if (item.priceQuoted != null) 'Cotización: \$${item.priceQuoted!.toStringAsFixed(2)}',
          ].join(' · '), style: Theme.of(context).textTheme.bodySmall),
          if (item.responseMessage != null && item.responseMessage!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Respuesta: ${item.responseMessage}')),
          if (item.notes != null && item.notes!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Notas: ${item.notes}')),
          if (onCancel != null) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: onCancel, child: const Text('Cancelar solicitud'))),
          ...actions,
        ]),
      ),
    );
  }
}
