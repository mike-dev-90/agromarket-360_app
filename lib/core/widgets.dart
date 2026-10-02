import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import 'api_client.dart';

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Texto de error amigable para cualquier excepción.
String errorText(Object e) => e is ApiException ? e.message : 'Ocurrió un error inesperado.';

/// Muestra [child] solo con sesión iniciada; si no, invita a iniciar sesión.
class LoginRequired extends ConsumerWidget {
  const LoginRequired({super.key, required this.child, this.message = 'Inicia sesión para ver esta sección.'});
  final Widget child;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return auth.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(errorText(e))),
      data: (user) => user != null
          ? child
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.lock_outline, size: 56, color: Colors.green),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: () => context.push('/login'), child: const Text('Iniciar sesión')),
                ]),
              ),
            ),
    );
  }
}

/// Estado vacío o de error reutilizable para listas.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => ListView(children: [
        const SizedBox(height: 96),
        Icon(icon, size: 56, color: Colors.grey),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(text, textAlign: TextAlign.center)),
        if (action != null) Padding(padding: const EdgeInsets.all(16), child: Center(child: action)),
      ]);
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(errorText(error), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ]),
        ),
      );
}

/// Pide un precio en dólares; devuelve null si se cancela.
Future<double?> askAmount(BuildContext context, {required String title, double? initial, String? helper, String action = 'Enviar'}) {
  final controller = TextEditingController(text: initial?.toStringAsFixed(2) ?? '');
  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(prefixText: r'$ ', helperText: helper),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
          onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text.replaceAll(',', '.'))),
          child: Text(action),
        ),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext context, String question) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(question),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
        FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(80, 44)), onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí')),
      ],
    ),
  );
  return ok ?? false;
}

/// Importe para el extremo de un ListTile: nunca ocupa todo el ancho (se reduce si es muy grande).
class PriceTrailing extends StatelessWidget {
  const PriceTrailing(this.value, {super.key, this.color});
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 110),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color ?? Theme.of(context).colorScheme.primary)),
        ),
      );
}

/// Etiqueta de estado que se reduce (con puntos suspensivos) en vez de desbordarse.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(16)),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondaryContainer)),
      );
}


/// Pide un texto corto; devuelve null si se cancela. Si [required], no deja enviar vacío.
Future<String?> askText(BuildContext context, {required String title, required String label, bool required = false, String action = 'Enviar'}) {
  return showDialog<String>(context: context, builder: (_) => _AskTextDialog(title: title, label: label, required: required, action: action));
}

class _AskTextDialog extends StatefulWidget {
  const _AskTextDialog({required this.title, required this.label, required this.required, required this.action});
  final String title, label, action;
  final bool required;

  @override
  State<_AskTextDialog> createState() => _AskTextDialogState();
}

class _AskTextDialogState extends State<_AskTextDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(controller: _controller, maxLines: 3, minLines: 1, decoration: InputDecoration(labelText: widget.label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () {
              final text = _controller.text.trim();
              if (widget.required && text.isEmpty) return;
              Navigator.pop(context, text);
            },
            child: Text(widget.action),
          ),
        ],
      );
}
