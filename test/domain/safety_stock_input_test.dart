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
      // 콤마는 올바른 천 단위 묶음일 때만 받는다.
      '1,5',
      '1,50',
      '1,2,3',
      '5,,000',
      '5,',
      ',',
      ',5',
      '1234,567',
      '-5,000',
      // 0이 아닌 글자가 0으로 읽히면 알림이 꺼지므로 거절한다.
      '1e-400',
    ]) {
      test('"$text" is rejected instead of being read as null', () {
        expect(parseSafetyStockInput(text), (isValid: false, value: null));
      });
    }

    test('only well-formed thousands groups keep their commas', () {
      expect(parseSafetyStockInput('5,000'), (isValid: true, value: 5000.0));
      expect(parseSafetyStockInput('1,234,567'), (
        isValid: true,
        value: 1234567.0,
      ));
      expect(parseSafetyStockInput('1,234.5'), (isValid: true, value: 1234.5));
    });

    test('zeros written in any way still turn tracking off', () {
      expect(parseSafetyStockInput('0.000'), (isValid: true, value: null));
      expect(parseSafetyStockInput('00'), (isValid: true, value: null));
    });
  });

  group('safetyStockInputText', () {
    test('whole numbers have no decimal point', () {
      expect(safetyStockInputText(5000), '5000');
    });

    test('fractions are not rounded', () {
      expect(safetyStockInputText(12.345), '12.345');
      expect(safetyStockInputText(0.5), '0.5');
    });

    for (final value in [1e21, 9.3e18, 123456789012.0, 12.345, 5000.0, 0.5]) {
      test('$value survives being filled in and read back', () {
        expect(parseSafetyStockInput(safetyStockInputText(value)).value, value);
      });
    }
  });
}
