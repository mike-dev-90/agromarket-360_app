class OrderItem {
  OrderItem({required this.name, required this.quantity, required this.total});
  final String name;
  final int quantity;
  final double total;
}

class BankInfo {
  BankInfo({this.bank, this.accountType, this.accountNumber, this.holder, this.document});
  final String? bank;
  final String? accountType;
  final String? accountNumber;
  final String? holder;
  final String? document;

  bool get isConfigured => accountNumber != null && accountNumber!.isNotEmpty;

  factory BankInfo.fromJson(Map<String, dynamic> j) => BankInfo(
        bank: j['name'] as String?,
        accountType: j['account_type'] as String?,
        accountNumber: j['account_number'] as String?,
        holder: j['account_holder'] as String?,
        document: j['tax_id'] as String?,
      );
}

class Order {
  Order({
    required this.id,
    required this.number,
    required this.status,
    required this.paymentStatus,
    required this.total,
    required this.items,
    this.transferReference,
    this.bank,
  });

  final int id;
  final String? number;
  final String status;
  final String paymentStatus;
  final double total;
  final List<OrderItem> items;
  final String? transferReference;
  final BankInfo? bank;

  String get statusLabel => const {
        'pending': 'Pendiente',
        'confirmed': 'Pago confirmado',
        'processing': 'En preparación',
        'shipped': 'Enviado',
        'delivered': 'Entregado',
        'cancelled': 'Cancelado',
      }[status] ?? status;

  bool get canSendProof => status == 'pending' && paymentStatus != 'paid';
  bool get canCancel => status == 'pending' && paymentStatus != 'paid';
  bool get canConfirmDelivery => status == 'shipped';

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'] as int,
        number: j['order_number'] as String?,
        status: j['status'] as String,
        paymentStatus: (j['payment_status'] as String?) ?? 'pending',
        total: (j['total'] as num).toDouble(),
        transferReference: j['transfer_reference'] as String?,
        bank: j['bank'] is Map ? BankInfo.fromJson((j['bank'] as Map).cast<String, dynamic>()) : null,
        items: [
          for (final i in (j['items'] as List? ?? const []))
            OrderItem(name: ((i as Map)['name'] as String?) ?? 'Producto', quantity: (i['quantity'] as num?)?.toInt() ?? 1, total: (i['total'] as num).toDouble()),
        ],
      );
}
