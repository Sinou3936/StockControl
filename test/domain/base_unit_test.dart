import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/domain/base_unit.dart';

void main() {
  test('round-trips every value through its db string representation', () {
    for (final unit in BaseUnit.values) {
      expect(baseUnitFromDbString(unit.toDbString()), unit);
    }
  });
}
