class Offer {
  Offer({
    required this.id,
    required this.status,
    required this.offeredBy,
    required this.offerPrice,
    required this.awaitingBuyer,
    required this.livestockId,
    required this.livestockTitle,
    required this.livestockPrice,
    this.message,
    this.rancherResponse,
    this.image,
  });

  final int id;
  final String status;
  final String offeredBy;
  final double offerPrice;
  final bool awaitingBuyer;
  final int livestockId;
  final String livestockTitle;
  final double livestockPrice;
  final String? message;
  final String? rancherResponse;
  final String? image;

  bool get isOpen => status == 'pending' || status == 'negotiating';

  String get statusLabel => const {
        'pending': 'Pendiente',
        'negotiating': 'En negociación',
        'accepted': 'Aceptada',
        'rejected': 'Rechazada',
        'cancelled': 'Cancelada',
      }[status] ?? status;

  factory Offer.fromJson(Map<String, dynamic> j) {
    final l = (j['livestock'] as Map?) ?? const {};
    return Offer(
      id: j['id'] as int,
      status: j['status'] as String,
      offeredBy: (j['offered_by'] as String?) ?? 'buyer',
      offerPrice: (j['offer_price'] as num).toDouble(),
      awaitingBuyer: j['awaiting_buyer'] == true,
      livestockId: (l['id'] as num?)?.toInt() ?? 0,
      livestockTitle: (l['title'] as String?) ?? 'Animal',
      livestockPrice: (l['price'] as num?)?.toDouble() ?? 0,
      message: j['message'] as String?,
      rancherResponse: j['rancher_response'] as String?,
      image: l['image'] as String?,
    );
  }
}
