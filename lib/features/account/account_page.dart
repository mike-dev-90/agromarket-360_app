import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return auth.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (user) {
        if (user == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.account_circle, size: 72, color: Colors.green),
                const SizedBox(height: 12),
                const Text('Inicia sesión para ofertar, pujar y comprar.'),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => context.push('/login'), child: const Text('Iniciar sesión')),
                TextButton(onPressed: () => context.push('/register'), child: const Text('Crear una cuenta')),
              ]),
            ),
          );
        }
        return ListView(padding: const EdgeInsets.all(24), children: [
          const Icon(Icons.account_circle, size: 72, color: Colors.green),
          const SizedBox(height: 12),
          Center(child: Text(user.name, style: Theme.of(context).textTheme.titleLarge)),
          Center(child: Text(user.email)),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(user.identityVerified ? Icons.verified : Icons.warning_amber, color: user.identityVerified ? Colors.green : Colors.orange),
              title: Text(user.identityVerified ? 'Identidad verificada' : 'Identidad sin verificar'),
              subtitle: user.identityVerified ? null : const Text('Verifica tu identidad para poder ofertar, pujar y comprar.'),
              onTap: user.identityVerified ? null : () => context.push('/verification'),
            ),
          ),
          const SizedBox(height: 8),
          Card(child: ListTile(leading: const Icon(Icons.person_outline), title: const Text('Editar perfil'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/profile'))),
          Card(child: ListTile(leading: const Icon(Icons.badge_outlined), title: const Text('Verificación de identidad'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/verification'))),
          Card(child: ListTile(leading: const Icon(Icons.lock_outline), title: const Text('Cambiar contraseña'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/profile/password'))),
          Card(child: ListTile(leading: const Icon(Icons.favorite_border), title: const Text('Mis favoritos'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/favorites'))),
          Card(child: ListTile(leading: const Icon(Icons.notifications_none), title: const Text('Notificaciones'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/notifications'))),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: () => ref.read(authProvider.notifier).logout(), icon: const Icon(Icons.logout), label: const Text('Cerrar sesión')),
        ]);
      },
    );
  }
}
