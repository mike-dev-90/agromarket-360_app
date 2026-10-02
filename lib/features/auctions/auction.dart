class Bid {
  Bid({required this.amount, required this.bidder, required this.isMine});
  final double amount;
  final String bidder;
  final bool isMine;
}

class Auction {
  Auction({
    required this.id,
    required this.title,
    required this.currentPrice,
    required this.startingPrice,
    required this.bidCount,
    required this.isRunning,
    required this.endsAt,
    required this.serverTime,
    this.image,
    this.breed,
    this.description,
    this.location,
    this.minimumNextBid,
    this.myHighestBid,
    this.bids = const [],
  });

  final int id;
  final String title;
  final double currentPrice;
  final double startingPrice;
  final int bidCount;
  final bool isRunning;
  final DateTime endsAt;
  final DateTime serverTime;
  final String? image;
  final String? breed;
  final String? description;
  final String? location;
  final double? minimumNextBid;
  final double? myHighestBid;
  final List<Bid> bids;

  /// Diferencia entre el reloj del servidor y el del teléfono, para una cuenta atrás correcta.
  Duration get clockOffset => serverTime.difference(DateTime.now().toUtc());

  Duration get remaining => endsAt.difference(DateTime.now().toUtc().add(clockOffset));

  factory Auction.fromJson(Map<String, dynamic> j) => Auction(
        id: j['id'] as int,
        title: j['title'] as String,
        currentPrice: (j['current_price'] as num).toDouble(),
        startingPrice: (j['starting_price'] as num).toDouble(),
        bidCount: (j['bid_count'] as num?)?.toInt() ?? 0,
        isRunning: j['is_running'] == true,
        endsAt: DateTime.parse(j['ends_at'] as String).toUtc(),
        serverTime: DateTime.parse(j['server_time'] as String).toUtc(),
        image: j['image'] as String?,
        breed: j['breed'] as String?,
        description: j['description'] as String?,
        location: j['location'] as String?,
        minimumNextBid: (j['minimum_next_bid'] as num?)?.toDouble(),
        myHighestBid: (j['my_highest_bid'] as num?)?.toDouble(),
        bids: [
          for (final b in (j['bids'] as List? ?? const []))
            Bid(amount: ((b as Map)['amount'] as num).toDouble(), bidder: b['bidder'] as String, isMine: b['is_mine'] == true),
        ],
      );
}
