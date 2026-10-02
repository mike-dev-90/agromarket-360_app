import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/form_widgets.dart';
import '../../core/photo_picker.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';

enum _Kind { text, multiline, number, integer, list, choice }

class _Spec {
  const _Spec(this.key, this.label, this.kind, {this.options, this.helper});
  final String key;
  final String label;
  final _Kind kind;
  final Map<String, String>? options;
  final String? helper;
}

const _rancherSpecs = [
  _Spec('farm_name', 'Nombre de la finca', _Kind.text),
  _Spec('farm_location', 'Ubicación de la finca', _Kind.text),
  _Spec('vereda', 'Sector / vereda', _Kind.text),
  _Spec('farm_size', 'Tamaño (hectáreas)', _Kind.number),
  _Spec('cattle_capacity', 'Capacidad de ganado (cabezas)', _Kind.integer),
  _Spec('years_experience', 'Años de experiencia', _Kind.integer),
  _Spec('specialization', 'Especialización', _Kind.text),
  _Spec('association_name', 'Asociación ganadera', _Kind.text),
  _Spec('association_member_number', 'Número de socio', _Kind.text),
  _Spec('agrocalidad_code', 'Código AGROCALIDAD', _Kind.text),
  _Spec('certifications', 'Certificaciones', _Kind.multiline),
  _Spec('bio', 'Sobre tu finca', _Kind.multiline),
];

const _supplierSpecs = [
  _Spec('company_name', 'Nombre de la empresa', _Kind.text),
  _Spec('company_type', 'Tipo de empresa', _Kind.text),
  _Spec('nit', 'RUC', _Kind.text),
  _Spec('tipo_productos', 'Tipos de productos', _Kind.list, helper: 'Separados por comas: alimentos, vacunas, equipos'),
  _Spec('marcas_distribuidas', 'Marcas que distribuyes', _Kind.text),
  _Spec('descripcion_negocio', 'Descripción del negocio', _Kind.multiline),
];

const _professions = {
  'veterinario': 'Veterinario',
  'reproduccion_genetica': 'Reproducción y genética',
  'nutricion': 'Nutrición',
  'tramites_movilizacion': 'Trámites de movilización',
  'infraestructura_finca': 'Infraestructura de finca',
  'entrenador': 'Entrenador',
  'herrador': 'Herrador',
  'esquilador': 'Esquilador',
};

const _professionalSpecs = [
  _Spec('profession', 'Profesión', _Kind.choice, options: _professions),
  _Spec('license_number', 'Número de registro profesional', _Kind.text),
  _Spec('specialty', 'Especialidades', _Kind.list, helper: 'Separadas por comas: Bovinos, Equinos'),
  _Spec('years_experience', 'Años de experiencia', _Kind.integer),
  _Spec('education', 'Formación', _Kind.text),
  _Spec('certifications', 'Certificaciones', _Kind.multiline),
  _Spec('bio', 'Sobre ti', _Kind.multiline),
];

class RancherProfilePage extends StatelessWidget {
  const RancherProfilePage({super.key});

  @override
  Widget build(BuildContext context) => const _BusinessProfileForm(title: 'Perfil de ganadero', path: '/rancher/profile', specs: _rancherSpecs, documentPath: '/rancher/profile/document');
}

class SupplierProfilePage extends StatelessWidget {
  const SupplierProfilePage({super.key});

  @override
  Widget build(BuildContext context) => const _BusinessProfileForm(title: 'Perfil de empresa', path: '/supplier/profile', specs: _supplierSpecs);
}

class ProfessionalProfilePage extends StatelessWidget {
  const ProfessionalProfilePage({super.key});

  @override
  Widget build(BuildContext context) => const _BusinessProfileForm(title: 'Perfil profesional', path: '/professional/profile', specs: _professionalSpecs);
}

class _BusinessProfileForm extends ConsumerStatefulWidget {
  const _BusinessProfileForm({required this.title, required this.path, required this.specs, this.documentPath});
  final String title;
  final String path;
  final List<_Spec> specs;
  final String? documentPath;

  @override
  ConsumerState<_BusinessProfileForm> createState() => _BusinessProfileFormState();
}

class _BusinessProfileFormState extends ConsumerState<_BusinessProfileForm> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _choices = <String, String?>{};
  bool _loading = true, _busy = false, _complete = false, _hasDocument = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final s in widget.specs) {
      if (s.kind == _Kind.choice) {
        _choices[s.key] = null;
      } else {
        _controllers[s.key] = TextEditingController();
      }
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Map<String, dynamic> d) {
    for (final s in widget.specs) {
      final v = d[s.key];
      if (s.kind == _Kind.choice) {
        _choices[s.key] = s.options!.containsKey(v) ? v as String : null;
      } else if (s.kind == _Kind.list) {
        _controllers[s.key]!.text = [for (final x in (v as List? ?? const [])) '$x'].join(', ');
      } else {
        _controllers[s.key]!.text = v == null ? '' : '$v';
      }
    }
    _complete = d['complete'] == true;
    _hasDocument = d['has_backup_document'] == true;
  }

  Future<void> _load() async {
    try {
      _fill((await ref.read(apiClientProvider).get(widget.path))['data'] as Map<String, dynamic>);
    } catch (e) {
      _error = errorText(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  Map<String, dynamic> _payload() {
    final out = <String, dynamic>{};
    for (final s in widget.specs) {
      if (s.kind == _Kind.choice) {
        out[s.key] = _choices[s.key];
        continue;
      }
      final text = _controllers[s.key]!.text.trim();
      switch (s.kind) {
        case _Kind.list:
          out[s.key] = [for (final x in text.split(',')) if (x.trim().isNotEmpty) x.trim()];
        case _Kind.number:
          out[s.key] = text.isEmpty ? null : num.tryParse(text.replaceAll(',', '.'));
        case _Kind.integer:
          out[s.key] = text.isEmpty ? null : int.tryParse(text);
        default:
          out[s.key] = text.isEmpty ? null : text;
      }
    }
    return out;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final d = (await ref.read(apiClientProvider).put(widget.path, data: _payload()))['data'] as Map<String, dynamic>;
      _fill(d);
      await ref.read(authProvider.notifier).refreshUser();
      if (mounted) showMessage(context, _complete ? 'Perfil guardado y completo.' : 'Perfil guardado. Aún faltan datos obligatorios.');
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadDocument() async {
    final path = await ref.read(photoPickerProvider).pick(fromCamera: false);
    if (path == null) return;
    setState(() => _busy = true);
    try {
      final d = (await ref.read(apiClientProvider).postForm(widget.documentPath!, files: {'backup_document': path}))['data'] as Map<String, dynamic>;
      _fill(d);
      await ref.read(authProvider.notifier).refreshUser();
      if (mounted) showMessage(context, 'Documento de respaldo guardado.');
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Card(
                  color: _complete ? Colors.green.shade50 : Colors.amber.shade50,
                  child: ListTile(
                    leading: Icon(_complete ? Icons.check_circle : Icons.info_outline, color: _complete ? Colors.green : Colors.orange),
                    title: Text(_complete ? 'Perfil completo' : 'Perfil incompleto'),
                    subtitle: _complete ? null : const Text('Completa los datos para poder publicar y vender.'),
                  ),
                ),
                const SizedBox(height: 12),
                for (final s in widget.specs)
                  switch (s.kind) {
                    _Kind.choice => appDropdown<String>(s.label, _choices[s.key], s.options!, (v) => setState(() => _choices[s.key] = v)),
                    _Kind.number => appNumberField(_controllers[s.key]!, s.label, helper: s.helper),
                    _Kind.integer => appNumberField(_controllers[s.key]!, s.label, decimal: false, helper: s.helper),
                    _Kind.multiline => appTextField(_controllers[s.key]!, s.label, maxLines: 3, helper: s.helper),
                    _ => appTextField(_controllers[s.key]!, s.label, helper: s.helper),
                  },
                if (widget.documentPath != null) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    icon: Icon(_hasDocument ? Icons.check_circle : Icons.upload_file, color: _hasDocument ? Colors.green : null),
                    label: Text(_hasDocument ? 'Documento de respaldo cargado (cambiar)' : 'Subir documento de respaldo'),
                    onPressed: _busy ? null : _uploadDocument,
                  ),
                  const SizedBox(height: 14),
                ],
                errorLine(context, _error),
                submitButton('Guardar perfil', _busy, _save),
              ]),
            ),
    );
  }
}
