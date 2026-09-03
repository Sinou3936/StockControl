import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/domain/movement_type.dart';

void main() {
  test('round-trips every value through its db string representation', () {
    for (final type in MovementType.values) {
      expect(movementTypeFromDbString(type.toDbString()), type);
    }
  });
}
