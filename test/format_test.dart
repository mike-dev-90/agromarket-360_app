import 'package:agromarket_360_app/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('money formatea en USD', () {
    expect(money(1500), r'$1,500.00');
  });

  test('countdown muestra tiempo restante y finalizada', () {
    expect(countdown(const Duration(hours: 1, minutes: 2, seconds: 3)), '01:02:03');
    expect(countdown(const Duration(days: 2, hours: 3, minutes: 4)), '2d 3h 4m');
    expect(countdown(Duration.zero), 'Finalizada');
    expect(countdown(const Duration(seconds: -5)), 'Finalizada');
  });
}
