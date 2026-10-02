import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/photo_picker.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';

class VerificationState {
  VerificationState({
    required this.status,
    required this.attempts,
    required this.remainingAttempts,
    required this.canSubmit,
    required this.identityVerified,
    this.rejectionReason,
    this.missingProfile = const [],
  });

  final String status;
  final int attempts;
  final int remainingAttempts;
  final bool canSubmit;
  final bool identityVerified;
  final String? rejectionReason;
  final List<String> missingProfile;

  String get statusLabel => const {
        'none': 'Sin enviar',
        'pending': 'Pendiente',
        'in_review': 'En revisión',
        'verified': 'Verificada',
        'rejected': 'Rechazada',
      }[status] ?? status;

  factory VerificationState.fromJson(Map<String, dynamic> j) => VerificationState(
        status: (j['status'] as String?) ?? 'none',
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
        remainingAttempts: (j['remaining_attempts'] as num?)?.toInt() ?? 0,
        canSubmit: j['can_submit'] == true,
        identityVerified: j['identity_verified'] == true,
        rejectionReason: j['rejection_reason'] as String?,
        missingProfile: [for (final m in (j['missing_profile'] as List? ?? const [])) '$m'],
      );
}

final verificationProvider = FutureProvider.autoDispose<VerificationState>((ref) async {
  ref.watch(authProvider.select((u) => u.valueOrNull?.id));
  final body = await ref.read(apiClientProvider).get('/verification');
  return VerificationState.fromJson(body['data'] as Map<String, dynamic>);
});

class VerificationPage extends StatelessWidget {
  const VerificationPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Verificación de identidad')),
        body: const LoginRequired(message: 'Inicia sesión para verificar tu identidad.', child: _VerificationBody()),
      );
}

class _VerificationBody extends ConsumerStatefulWidget {
  const _VerificationBody();

  @override
  ConsumerState<_VerificationBody> createState() => _VerificationBodyState();
}

class _VerificationBodyState extends ConsumerState<_VerificationBody> {
  final _form = GlobalKey<FormState>();
  final _number = TextEditingController();
  String _type = 'cedula';
  final _photos = <String, String>{}; // campo -> ruta
  bool _busy = false;
  String? _error;

  static const _slots = {
    'document_front': 'Documento (frente)',
    'document_back': 'Documento (reverso)',
    'selfie': 'Selfie sosteniendo el documento',
  };

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _pick(String field) async {
    final fromCamera = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Tomar foto'), onTap: () => Navigator.pop(ctx, true)),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Elegir de la galería'), onTap: () => Navigator.pop(ctx, false)),
        ]),
      ),
    );
    if (fromCamera == null) return;
    final path = await ref.read(photoPickerProvider).pick(fromCamera: fromCamera);
    if (path != null) setState(() => _photos[field] = path);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final missing = _slots.keys.where((k) => !_photos.containsKey(k)).toList();
    if (missing.isNotEmpty) {
      setState(() => _error = 'Agrega las tres fotos: frente, reverso y selfie.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).postForm('/verification', fields: {'document_type': _type, 'document_number': _number.text.trim()}, files: Map.of(_photos));
      _photos.clear();
      _number.clear();
      ref.invalidate(verificationProvider);
      await ref.read(authProvider.notifier).refreshUser();
      if (mounted) showMessage(context, 'Documentos enviados. Revisaremos tu verificación.');
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ref.watch(verificationProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(verificationProvider)),
          data: (v) => ListView(padding: const EdgeInsets.all(20), children: [
            Card(
              child: ListTile(
                leading: Icon(v.identityVerified ? Icons.verified : Icons.badge_outlined, color: v.identityVerified ? Colors.green : Colors.orange),
                title: Text('Estado: ${v.statusLabel}'),
                subtitle: Text(v.identityVerified ? 'Ya puedes ofertar, pujar y comprar.' : 'Necesitas verificar tu identidad para ofertar, pujar y comprar.'),
              ),
            ),
            if (v.status == 'rejected' && v.rejectionReason != null)
              Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Text('Motivo del rechazo: ${v.rejectionReason}'))),
            if (v.status == 'verified' && !v.identityVerified) _missingCard(context, v),
            if (v.missingProfile.isNotEmpty && v.status != 'verified') _missingCard(context, v),
            if (v.status == 'in_review') const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Tus documentos están en revisión. Te avisaremos cuando terminen.')),
            if (v.canSubmit) ...[
              const SizedBox(height: 8),
              Text('Intentos restantes: ${v.remainingAttempts}', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Form(
                key: _form,
                child: Column(children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Tipo de documento'),
                    items: const [DropdownMenuItem(value: 'cedula', child: Text('Cédula')), DropdownMenuItem(value: 'pasaporte', child: Text('Pasaporte'))],
                    onChanged: (x) => setState(() => _type = x ?? 'cedula'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(controller: _number, decoration: const InputDecoration(labelText: 'Número de documento'), validator: (x) => (x == null || x.trim().isEmpty) ? 'Obligatorio' : null),
                  const SizedBox(height: 16),
                  for (final e in _slots.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        icon: Icon(_photos.containsKey(e.key) ? Icons.check_circle : Icons.add_a_photo, color: _photos.containsKey(e.key) ? Colors.green : null),
                        label: Text(_photos.containsKey(e.key) ? '${e.value}: lista' : e.value),
                        onPressed: _busy ? null : () => _pick(e.key),
                      ),
                    ),
                ]),
              ),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enviar documentos'),
              ),
            ],
            if (!v.canSubmit && !v.identityVerified && v.status != 'in_review' && v.status != 'verified')
              const Padding(padding: EdgeInsets.only(top: 12), child: Text('Alcanzaste el máximo de intentos. Contacta con soporte para continuar.')),
          ]),
        );
  }

  Widget _missingCard(BuildContext context, VerificationState v) {
    final labels = {
      'purchase_purpose': 'Indica para qué compras en tu perfil.',
      'rancher_profile': 'Completa tu perfil de ganadero en la web.',
      'professional_profile': 'Completa tu perfil profesional en la web.',
      'supplier_profile': 'Completa los datos de tu empresa en la web.',
    };
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Antes de verificarte falta:', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final m in v.missingProfile) Text('• ${labels[m] ?? m}'),
          if (v.missingProfile.contains('purchase_purpose')) TextButton(onPressed: () => context.push('/profile'), child: const Text('Completar mi perfil')),
        ]),
      ),
    );
  }
}
