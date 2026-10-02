num? _n(Object? v) => v is num ? v : (v is String ? num.tryParse(v) : null);

class Product {
  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.unit,
    this.location,
    this.category,
    this.image,
    this.description,
    this.sellerName,
  });

  final int id;
  final String name;
  final double price;
  final int stock;
  final String? unit;
  final String? location;
  final String? category;
  final String? image;
  final String? description;
  final String? sellerName;

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as int,
        name: (j['name'] as String?) ?? 'Producto',
        price: _n(j['price'])?.toDouble() ?? 0,
        stock: _n(j['stock'])?.toInt() ?? 0,
        unit: j['unit'] as String?,
        location: j['location'] as String?,
        category: j['category'] as String?,
        image: j['image'] as String?,
        description: j['description'] as String?,
        sellerName: (j['seller'] as Map?)?['name'] as String?,
      );
}

class CartLine {
  CartLine({required this.id, required this.productId, required this.name, required this.quantity, required this.unitPrice, required this.total, required this.stock, this.unit, this.image});

  final int id;
  final int productId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double total;
  final int stock;
  final String? unit;
  final String? image;

  factory CartLine.fromJson(Map<String, dynamic> j) => CartLine(
        id: j['id'] as int,
        productId: j['product_id'] as int,
        name: (j['name'] as String?) ?? 'Producto',
        quantity: _n(j['quantity'])?.toInt() ?? 1,
        unitPrice: _n(j['unit_price'])?.toDouble() ?? 0,
        total: _n(j['total'])?.toDouble() ?? 0,
        stock: _n(j['stock'])?.toInt() ?? 0,
        unit: j['unit'] as String?,
        image: j['image'] as String?,
      );
}

class Cart {
  Cart({required this.items, required this.total});
  final List<CartLine> items;
  final double total;

  int get count => items.length;

  factory Cart.fromJson(Map<String, dynamic> j) => Cart(
        items: [for (final i in (j['items'] as List? ?? const [])) CartLine.fromJson(i as Map<String, dynamic>)],
        total: _n(j['total'])?.toDouble() ?? 0,
      );
}
