import 'package:flutter/material.dart';

import '../catalog/catalog_page.dart';
import '../supplies/supplies_page.dart';

/// Pestaña "Explorar": como el menú de la web (Ganado, Insumos, Servicios).
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  int _section = 0;

  static const _labels = ['Ganado', 'Insumos'];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [for (var i = 0; i < _labels.length; i++) ButtonSegment(value: i, label: Text(_labels[i]))],
          selected: {_section},
          onSelectionChanged: (s) => setState(() => _section = s.first),
        ),
      ),
      Expanded(
        child: IndexedStack(index: _section, children: const [CatalogPage(), SuppliesPage()]),
      ),
    ]);
  }
}
