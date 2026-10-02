import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/form_widgets.dart';
import '../../core/format.dart';
import '../../core/paged_list.dart';
import '../../core/photo_picker.dart';
import '../../core/widgets.dart';
import 'business_models.dart';

class SupplierProductsPage extends ConsumerStatefulWidget {
  const SupplierProductsPage({super.key});

  @override
  ConsumerState<SupplierProductsPage> createState() => _SupplierProductsPageState();
}

class _SupplierProductsPageState extends ConsumerState<SupplierProductsPage> {
  final _list = GlobalKey<PagedSearchListState<BizProduct>>();

  Future<void> _open(String route) async {
    await context.push(route);
    await _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis productos')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _open('/business/products/new'), icon: const Icon(Icons.add), label: const Text('Nuevo producto')),
      body: PagedSearchList<BizProduct>(
        key: _list,
        showSearch: false,
        emptyText: 'Aún no has publicado productos.',
        emptyIcon: Icons.inventory_2_outlined,
        filters: const {'available': 'Disponibles', 'sold': 'Agotados', 'pending': 'Pendientes'},
        fetch: (ref, page, search, filter) async {
          final body = await ref.read(apiClientProvider).get('/supplier/products', query: {'page': page, if (filter != null) 'status': filter});
          return (
            items: [for (final j in body['data'] as List) BizProduct.fromJson(j as Map<String, dynamic>)],
            lastPage: (body['meta'] as Map)['last_page'] as int,
          );
        },
        itemBuilder: (context, p) => Card(
          child: ListTile(
            onTap: () => _open('/business/products/${p.id}/edit'),
            leading: CircleAvatar(backgroundImage: p.image != null ? NetworkImage(p.image!) : null, child: p.image == null ? const Icon(Icons.inventory_2) : null),
            title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text('${p.statusLabel} · ${p.stock} en stock${p.category != null ? ' · ${p.category}' : ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: PriceTrailing(money(p.price)),
          ),
        ),
      ),
    );
  }
}

class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({super.key, this.id});
  final int? id;

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _quantity = TextEditingController();
  final _unit = TextEditingController(text: 'unidad');
  final _location = TextEditingController();
  String? _category;
  String _status = 'available';
  Map<String, String> _categories = {};
  String? _image;
  bool _hasImage = false;
  bool _loading = true, _busy = false;
  String? _error;

  bool get _editing => widget.id != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _price, _quantity, _unit, _location]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final cats = await api.get('/product-categories');
      _categories = {for (final c in cats['data'] as List) '${(c as Map)['id']}': c['name'] as String};
      if (_editing) {
        final p = BizProduct.fromJson((await api.get('/supplier/products/${widget.id}'))['data'] as Map<String, dynamic>);
        _name.text = p.name;
        _description.text = p.description ?? '';
        _price.text = '${p.price}';
        _quantity.text = '${p.stock}';
        _unit.text = p.unit ?? 'unidad';
        _location.text = p.location ?? '';
        _category = p.categoryId?.toString();
        _status = p.status;
        _hasImage = p.image != null;
      }
    } catch (e) {
      _error = errorText(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final fields = {
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'price': _price.text.trim().replaceAll(',', '.'),
        'quantity': _quantity.text.trim(),
        'unit': _unit.text.trim(),
        'category_id': _category!,
        if (_location.text.trim().isNotEmpty) 'location': _location.text.trim(),
        'status': _status,
      };
      await ref.read(apiClientProvider).postForm(_editing ? '/supplier/products/${widget.id}' : '/supplier/products', fields: fields, files: {if (_image != null) 'image': _image!});
      if (mounted) {
        showMessage(context, _editing ? 'Producto actualizado.' : 'Producto publicado.');
        context.pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, '¿Eliminar este producto?')) return;
    try {
      await ref.read(apiClientProvider).delete('/supplier/products/${widget.id}');
      if (mounted) {
        showMessage(context, 'Producto eliminado.');
        context.pop();
      }
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Editar producto' : 'Nuevo producto'), actions: [
        if (_editing) IconButton(tooltip: 'Eliminar', onPressed: _delete, icon: const Icon(Icons.delete_outline)),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                appTextField(_name, 'Nombre', required: true),
                appTextField(_description, 'Descripción', required: true, maxLines: 3),
                appDropdown<String>('Categoría', _category, _categories, (v) => setState(() => _category = v), required: true),
                Row(children: [
                  Expanded(child: appNumberField(_price, 'Precio (USD)', required: true)),
                  const SizedBox(width: 12),
                  Expanded(child: appNumberField(_quantity, 'Stock', required: true, decimal: false)),
                ]),
                appTextField(_unit, 'Unidad (kg, bolsa, unidad...)'),
                appTextField(_location, 'Ubicación'),
                appDropdown<String>('Estado', _status, const {'available': 'Disponible', 'sold': 'Agotado', 'pending': 'Pendiente'}, (v) => setState(() => _status = v ?? 'available'), required: true),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  icon: Icon(_image != null || _hasImage ? Icons.check_circle : Icons.add_a_photo, color: _image != null || _hasImage ? Colors.green : null),
                  label: Text(_image != null ? 'Foto nueva lista' : _hasImage ? 'Cambiar foto' : 'Agregar foto'),
                  onPressed: _busy ? null : () async {
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
                    final p = await ref.read(photoPickerProvider).pick(fromCamera: fromCamera);
                    if (p != null) setState(() => _image = p);
                  },
                ),
                const SizedBox(height: 14),
                errorLine(context, _error),
                submitButton(_editing ? 'Guardar cambios' : 'Publicar producto', _busy, _save),
              ]),
            ),
    );
  }
}
