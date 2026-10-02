class NotificationItem {
  NotificationItem({required this.id, required this.title, required this.message, required this.isRead, this.createdAt});

  final int id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdAt;

  NotificationItem copyWith({bool? isRead}) =>
      NotificationItem(id: id, title: title, message: message, isRead: isRead ?? this.isRead, createdAt: createdAt);

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
        id: j['id'] as int,
        title: (j['title'] as String?) ?? '',
        message: (j['message'] as String?) ?? '',
        isRead: j['is_read'] == true,
        createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at'] as String)?.toLocal() : null,
      );
}
