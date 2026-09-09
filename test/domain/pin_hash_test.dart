import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/domain/pin_hash.dart';

void main() {
  group('hashPin', () {
    test('produces the same hash for the same pin and salt', () {
      expect(hashPin('1234', 'salt-a'), hashPin('1234', 'salt-a'));
    });

    test('produces different hashes for different pins', () {
      expect(hashPin('1234', 'salt-a'), isNot(hashPin('5678', 'salt-a')));
    });

    test('produces different hashes for different salts', () {
      expect(hashPin('1234', 'salt-a'), isNot(hashPin('1234', 'salt-b')));
    });
  });

  group('generatePinSalt', () {
    test('produces a non-empty string', () {
      expect(generatePinSalt(), isNotEmpty);
    });

    test('produces different values on each call', () {
      expect(generatePinSalt(), isNot(generatePinSalt()));
    });
  });
}
