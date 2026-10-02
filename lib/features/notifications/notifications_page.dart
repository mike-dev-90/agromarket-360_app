import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import 'notification_item.dart';

final notificationsProvider = FutureProvider.autoDispose<List<NotificationItem>>((ref) async {
  ref.watch(authProvider.select((u) => u.valueOrNull?.id)); // se reinicia al cambiar de usuario
  final body = await ref.read(apiClientProvider).get('/notifications');
  return [for (final j in body['data'] as List) NotificationItem.fromJson(j as Map<String, dynamic>)];
});

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notificaciones')),
        body: const LoginRequired(message: 'Inicia sesión para ver tus notificaciones.', child: _NotificationsBody()),
      );
}

class _NotificationsBody extends ConsumerWidget {
  const _NotificationsBody();

  Future<void> _call(BuildContext context, WidgetRef ref, String path) async {
    try {
      await ref.read(apiClientProvider).post(path);
      ref.invalidate(notificationsProvider);
    } catch (e) {
      if (context.mounted) showMessage(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(notificationsProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(notificationsProvider)),
          data: (items) => RefreshIndicator(
            onRefresh: () async => ref.refresh(notificationsProvider.future),
            child: items.isEmpty
                ? const EmptyState(icon: Icons.notifications_none, text: 'No tienes notificaciones.')
                : ListView(children: [
                    if (items.any((n) => !n.isRead))
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(onPressed: () => _call(context, ref, '/notifications/read-all'), child: const Text('Marcar todas como leídas')),
                      ),
                    for (final n in items) ...[
                      ListTile(
                        leading: Icon(n.isRead ? Icons.notifications_none : Icons.notifications_active, color: n.isRead ? Colors.grey : Colors.green),
                        title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                        subtitle: Text(n.message, maxLines: 3, overflow: TextOverflow.ellipsis),
                        onTap: n.isRead ? null : () => _call(context, ref, '/notifications/${n.id}/read'),
                      ),
                      const Divider(height: 1),
                    ],
                  ]),
          ),
        );
  }
}
