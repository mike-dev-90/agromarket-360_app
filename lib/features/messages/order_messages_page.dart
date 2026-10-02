import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/widgets.dart';

class ChatMessage {
  ChatMessage({required this.id, required this.text, required this.isMine, this.sender});
  final int id;
  final String text;
  final bool isMine;
  final String? sender;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(id: j['id'] as int, text: (j['message'] as String?) ?? '', isMine: j['is_mine'] == true, sender: j['sender'] as String?);
}

class ChatThread {
  ChatThread({required this.messages, this.otherName, this.orderNumber});
  final List<ChatMessage> messages;
  final String? otherName;
  final String? orderNumber;
}

final orderMessagesProvider = FutureProvider.autoDispose.family<ChatThread, int>((ref, orderId) async {
  final body = await ref.read(apiClientProvider).get('/orders/$orderId/messages');
  final meta = (body['meta'] as Map?) ?? const {};
  return ChatThread(
    messages: [for (final j in body['data'] as List) ChatMessage.fromJson(j as Map<String, dynamic>)],
    otherName: (meta['other_user'] as Map?)?['name'] as String?,
    orderNumber: meta['order_number'] as String?,
  );
});

class OrderMessagesPage extends ConsumerStatefulWidget {
  const OrderMessagesPage({super.key, required this.orderId});
  final int orderId;

  @override
  ConsumerState<OrderMessagesPage> createState() => _OrderMessagesPageState();
}

class _OrderMessagesPageState extends ConsumerState<OrderMessagesPage> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(apiClientProvider).post('/orders/${widget.orderId}/messages', data: {'message': text});
      _controller.clear();
      ref.invalidate(orderMessagesProvider(widget.orderId));
      await ref.read(orderMessagesProvider(widget.orderId).future);
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thread = ref.watch(orderMessagesProvider(widget.orderId));
    return Scaffold(
      appBar: AppBar(title: Text(thread.valueOrNull?.otherName != null ? 'Chat con ${thread.value!.otherName}' : 'Mensajes del pedido', maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Column(children: [
        Expanded(
          child: thread.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(orderMessagesProvider(widget.orderId))),
            data: (t) => RefreshIndicator(
              onRefresh: () async => ref.refresh(orderMessagesProvider(widget.orderId).future),
              child: t.messages.isEmpty
                  ? const EmptyState(icon: Icons.chat_bubble_outline, text: 'Aún no hay mensajes. Escribe el primero para coordinar entrega o pago.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: t.messages.length,
                      itemBuilder: (_, i) {
                        final m = t.messages[i];
                        return Align(
                          alignment: m.isMine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(color: m.isMine ? Colors.green.shade100 : Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                            child: Text(m.text),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Expanded(child: TextField(controller: _controller, minLines: 1, maxLines: 4, textInputAction: TextInputAction.send, decoration: const InputDecoration(hintText: 'Escribe un mensaje'), onSubmitted: (_) => _send())),
              const SizedBox(width: 8),
              IconButton.filled(tooltip: 'Enviar', onPressed: _sending ? null : _send, icon: const Icon(Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }
}
