import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/domain/unit_conversion.dart';

void main() {
  test('multiplies purchase quantity by the conversion factor', () {
    // 2박스, 1박스 = 20kg(=20000g) 이라고 가정
    final result = purchaseQtyToBaseQty(2, 20000);
    expect(result, 40000);
  });

  test('returns zero when purchase quantity is zero', () {
    expect(purchaseQtyToBaseQty(0, 20000), 0);
  });
}
