import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/domain/sync_id.dart';

void main() {
  group('generateSyncId', () {
    test('produces a non-empty string', () {
      expect(generateSyncId(), isNotEmpty);
    });

    test('produces different values on each call', () {
      expect(generateSyncId(), isNot(generateSyncId()));
    });
  });
}
