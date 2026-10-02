import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../auth/auth_controller.dart';
import 'product.dart';

/// Carrito del usuario. Para invitados es un carrito vacío (sin consultar al servidor).
final cartProvider = FutureProvider.autoDispose<Cart>((ref) async {
  final user = ref.watch(authProvider.select((u) => u.valueOrNull?.id));
  if (user == null) return Cart(items: const [], total: 0);
  final body = await ref.read(apiClientProvider).get('/cart');
  return Cart.fromJson(body['data'] as Map<String, dynamic>);
});
