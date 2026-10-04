import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/format/quantity_format.dart';

void main() {
  test('whole numbers drop the decimal point and get thousands separators',
      () {
    expect(formatQty(5000.0), '5,000');
    expect(formatQty(1234567.0), '1,234,567');
    expect(formatQty(0.0), '0');
    expect(formatQty(950.0), '950');
  });

  test('fractions keep up to two decimals without trailing zeros', () {
    expect(formatQty(12.5), '12.5');
    expect(formatQty(12.349), '12.35');
    expect(formatQty(1500.25), '1,500.25');
  });

  test('negative values keep their sign and tiny values do not show -0', () {
    expect(formatQty(-1500.0), '-1,500');
    expect(formatQty(-0.001), '0');
  });
}
