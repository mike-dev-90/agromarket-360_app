import 'package:intl/intl.dart';

final _money = NumberFormat.currency(locale: 'en_US', symbol: r'$');

/// Precios en USD (Ecuador).
String money(num value) => _money.format(value);

String countdown(Duration d) {
  if (d.isNegative || d == Duration.zero) return 'Finalizada';
  final days = d.inDays;
  final h = d.inHours % 24;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (days > 0) return '${days}d ${h}h ${m}m';
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
