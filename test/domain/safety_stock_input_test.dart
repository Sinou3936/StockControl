import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/domain/safety_stock_input.dart';

void main() {
  group('parseSafetyStockInput', () {
    test('plain, comma-grouped and padded numbers are read', () {
      expect(parseSafetyStockInput('5000'), (isValid: true, value: 5000.0));
      expect(parseSafetyStockInput('5,000'), (isValid: true, value: 5000.0));
      expect(parseSafetyStockInput(' 12.5 '), (isValid: true, value: 12.5));
      expect(parseSafetyStockInput('1,234,567'), (
        isValid: true,
        value: 1234567.0,
      ));
    });

    test('blank means tracking is turned off', () {
      expect(parseSafetyStockInput(''), (isValid: true, value: null));
      expect(parseSafetyStockInput('   '), (isValid: true, value: null));
    });

    test('zero means tracking is turned off', () {
      expect(parseSafetyStockInput('0'), (isValid: true, value: null));
      expect(parseSafetyStockInput('0.0'), (isValid: true, value: null));
    });

    for (final text in [
      '5000g',
      'abc',
      '-5',
      'Infinity',
      'NaN',
      '1e400',
      '5 000',
    ]) {
      test('"$text" is rejected instead of being read as null', () {
        expect(parseSafetyStockInput(text), (isValid: false, value: null));
      });
    }
  });

  group('safetyStockInputText', () {
    test('whole numbers have no decimal point', () {
      expect(safetyStockInputText(5000), '5000');
    });

    test('fractions are not rounded', () {
      expect(safetyStockInputText(12.345), '12.345');
      expect(safetyStockInputText(0.5), '0.5');
    });
  });
}
