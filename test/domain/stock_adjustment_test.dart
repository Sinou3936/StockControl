import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/domain/stock_adjustment.dart';

void main() {
  group('applyQuantityChange', () {
    test('increases remainingQty when change is positive', () {
      expect(applyQuantityChange(1000, 500), 1500);
    });

    test('decreases remainingQty when change is negative', () {
      expect(applyQuantityChange(1000, -400), 600);
    });

    test('allows decreasing exactly to zero', () {
      expect(applyQuantityChange(1000, -1000), 0);
    });

    test('throws InsufficientStockException when change would go negative',
        () {
      expect(
        () => applyQuantityChange(1000, -1001),
        throwsA(
          isA<InsufficientStockException>()
              .having((e) => e.remainingQty, 'remainingQty', 1000)
              .having((e) => e.requestedQty, 'requestedQty', 1001),
        ),
      );
    });
  });
}
