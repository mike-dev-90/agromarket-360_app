import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/form_widgets.dart';
import '../../core/photo_picker.dart';
import '../../core/widgets.dart';
import '../auth/register_page.dart';
import '../catalog/livestock.dart';
import 'business_models.dart';

const _purposes = {'cria': 'Cría', 'levante': 'Levante', 'engorde': 'Engorde', 'reproductor': 'Reproductor', 'lechero': 'Lechero', 'lote': 'Lote'};

/// Publicar o editar un animal (multipart: foto principal obligatoria al crear).
class LivestockFormPage extends ConsumerStatefulWidget {
  const LivestockFormPage({super.key, this.id});
  final int? id;

  @override
  ConsumerState<LivestockFormPage> createState() => _LivestockFormPageState();
}

class _LivestockFormPageState extends ConsumerState<LivestockFormPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _breed = TextEditingController();
  final _ageYears = TextEditingController();
  final _ageMonths = TextEditingController();
  final _weight = TextEditingController();
  final _price = TextEditingController();
  final _city = TextEditingController();
  final _health = TextEditingController();
  String? _type, _sex, _category, _province;
  String _status = 'active';
  bool _negotiable = true, _vaccinated = false, _pedigree = false;
  String? _mainImage; // ruta local nueva
  String? _existingMain;
  final _extra = <String>[]; // rutas locales nuevas
  List<({int id, String url})> _existingImages = [];
  bool _loading = false, _busy = false;
  String? _error;

  bool get _editing => widget.id != null;

  @override
  void initState() {
    super.initState();
    if (_editing) _load();
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _breed, _ageYears, _ageMonths, _weight, _price, _city, _health]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = (await ref.read(apiClientProvider).get('/rancher/livestock/${widget.id}'))['data'] as Map<String, dynamic>;
      setState(() {
        _title.text = d['title'] as String? ?? '';
        _description.text = d['description'] as String? ?? '';
        _breed.text = d['breed'] as String? ?? '';
        _ageYears.text = '${d['age_years'] ?? ''}';
        _ageMonths.text = '${d['age_months'] ?? ''}';
        _weight.text = d['weight'] == null ? '' : '${d['weight']}';
        _price.text = '${d['price']}';
        _health.text = d['health_notes'] as String? ?? '';
        _type = d['type'] as String?;
        _sex = d['sex'] as String?;
        _status = (d['status'] as String?) ?? 'active';
        _province = provinces.contains(d['province']) ? d['province'] as String : null;
        final loc = (d['location'] as String?) ?? '';
        _city.text = loc.contains(',') ? loc.split(',').first.trim() : '';
        _category = _purposes.keys.firstWhere((k) => const {'cria': 'breeding', 'engorde': 'meat', 'lechero': 'dairy'}[k] == d['purpose'], orElse: () => '');
        if (_category!.isEmpty) _category = null;
        _negotiable = d['negotiable'] == true;
        _vaccinated = d['is_vaccinated'] == true;
        _pedigree = d['has_pedigree'] == true;
        _existingMain = d['image'] as String?;
        _existingImages = [for (final i in (d['images'] as List? ?? const [])) (id: (i as Map)['id'] as int, url: i['url'] as String)];
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _pick() async {
    final fromCamera = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Tomar foto'), onTap: () => Navigator.pop(ctx, true)),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Elegir de la galería'), onTap: () => Navigator.pop(ctx, false)),
        ]),
      ),
    );
    if (fromCamera == null) return null;
    return ref.read(photoPickerProvider).pick(fromCamera: fromCamera);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (!_editing && _mainImage == null) {
      setState(() => _error = 'Agrega la foto principal del animal.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final fields = <String, String>{
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'type': _type!,
        'sex': _sex!,
        if (_breed.text.trim().isNotEmpty) 'breed': _breed.text.trim(),
        if (_category != null) 'category': _category!,
        if (_ageYears.text.trim().isNotEmpty) 'age_years': _ageYears.text.trim(),
        if (_ageMonths.text.trim().isNotEmpty) 'age_months': _ageMonths.text.trim(),
        if (_weight.text.trim().isNotEmpty) 'weight': _weight.text.trim().replaceAll(',', '.'),
        'price': _price.text.trim().replaceAll(',', '.'),
        'negotiable': _negotiable ? '1' : '0',
        'location': _province!,
        if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
        'is_vaccinated': _vaccinated ? '1' : '0',
        'has_pedigree': _pedigree ? '1' : '0',
        if (_health.text.trim().isNotEmpty) 'health_notes': _health.text.trim(),
        'status': _status,
      };
      final files = <String, String>{
        if (_mainImage != null) 'main_image': _mainImage!,
        for (var i = 0; i < _extra.length; i++) 'additional_images[$i]': _extra[i],
      };
      final path = _editing ? '/rancher/livestock/${widget.id}' : '/rancher/livestock';
      await ref.read(apiClientProvider).postForm(path, fields: fields, files: files);
      if (mounted) {
        showMessage(context, _editing ? 'Animal actualizado.' : 'Animal publicado.');
        context.pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, '¿Eliminar este animal? Esta acción no se puede deshacer.')) return;
    try {
      await ref.read(apiClientProvider).delete('/rancher/livestock/${widget.id}');
      if (mounted) {
        showMessage(context, 'Animal eliminado.');
        context.pop();
      }
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    }
  }

  Future<void> _deleteImage(int imageId) async {
    try {
      await ref.read(apiClientProvider).delete('/rancher/livestock/${widget.id}/images/$imageId');
      setState(() => _existingImages = _existingImages.where((i) => i.id != imageId).toList());
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _editing ? livestockStatuses : {'active': 'Publicado', 'draft': 'Borrador'};
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Editar animal' : 'Publicar animal'), actions: [
        if (_editing) IconButton(tooltip: 'Eliminar', onPressed: _delete, icon: const Icon(Icons.delete_outline)),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                appTextField(_title, 'Título', required: true),
                appTextField(_description, 'Descripción', required: true, maxLines: 4),
                appDropdown<String>('Tipo de animal', _type, livestockTypes, (v) => setState(() => _type = v), required: true),
                appTextField(_breed, 'Raza'),
                appDropdown<String>('Sexo', _sex, const {'male': 'Macho', 'female': 'Hembra'}, (v) => setState(() => _sex = v), required: true),
                appDropdown<String>('Categoría', _category, _purposes, (v) => setState(() => _category = v)),
                Row(children: [
                  Expanded(child: appNumberField(_ageYears, 'Edad (años)', decimal: false)),
                  const SizedBox(width: 12),
                  Expanded(child: appNumberField(_ageMonths, 'Meses', decimal: false)),
                ]),
                appNumberField(_weight, 'Peso (kg)'),
                appNumberField(_price, 'Precio (USD)', required: true),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Precio negociable'), value: _negotiable, onChanged: (v) => setState(() => _negotiable = v)),
                appDropdown<String>('Provincia', _province, {for (final p in provinces) p: p}, (v) => setState(() => _province = v), required: true),
                appTextField(_city, 'Ciudad'),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Vacunado'), value: _vaccinated, onChanged: (v) => setState(() => _vaccinated = v)),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Con pedigrí'), value: _pedigree, onChanged: (v) => setState(() => _pedigree = v)),
                appTextField(_health, 'Notas de salud', maxLines: 2),
                appDropdown<String>('Estado', _status, statuses, (v) => setState(() => _status = v ?? 'active'), required: true),
                const SizedBox(height: 4),
                Text('Fotos', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  icon: Icon(_mainImage != null || _existingMain != null ? Icons.check_circle : Icons.add_a_photo, color: _mainImage != null || _existingMain != null ? Colors.green : null),
                  label: Text(_mainImage != null ? 'Foto principal: nueva lista' : _existingMain != null ? 'Foto principal: cambiar' : 'Foto principal (obligatoria)'),
                  onPressed: _busy ? null : () async {
                    final p = await _pick();
                    if (p != null) setState(() => _mainImage = p);
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text('Fotos adicionales (${_extra.length + _existingImages.length}/5)'),
                  onPressed: _busy || _extra.length + _existingImages.length >= 5 ? null : () async {
                    final p = await _pick();
                    if (p != null) setState(() => _extra.add(p));
                  },
                ),
                for (final img in _existingImages) ListTile(dense: true, leading: const Icon(Icons.image_outlined), title: Text('Foto guardada ${img.id}'), trailing: IconButton(tooltip: 'Quitar foto', icon: const Icon(Icons.close), onPressed: () => _deleteImage(img.id))),
                for (var i = 0; i < _extra.length; i++) ListTile(dense: true, leading: const Icon(Icons.image), title: Text('Foto nueva ${i + 1}'), trailing: IconButton(tooltip: 'Quitar foto nueva', icon: const Icon(Icons.close), onPressed: () => setState(() => _extra.removeAt(i)))),
                const SizedBox(height: 12),
                errorLine(context, _error),
                submitButton(_editing ? 'Guardar cambios' : 'Publicar', _busy, _save),
              ]),
            ),
    );
  }
}
