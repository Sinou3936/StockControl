import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/format/thousands_input.dart';

/// 글자를 [from]에서 [to]로 바꾸는 입력을 흉내 낸다. 커서는 [cursor] 뒤.
TextEditingValue type(
  TextInputFormatter formatter,
  String from,
  String to, {
  int? cursor,
}) => formatter.formatEditUpdate(
  TextEditingValue(text: from),
  TextEditingValue(
    text: to,
    selection: TextSelection.collapsed(offset: cursor ?? to.length),
  ),
);

void main() {
  const formatter = ThousandsSeparatorFormatter();

  group('groupThousands', () {
    test('정수 부분에 세 자리마다 쉼표', () {
      expect(groupThousands('0'), '0');
      expect(groupThousands('999'), '999');
      expect(groupThousands('1000'), '1,000');
      expect(groupThousands('1234567'), '1,234,567');
    });

    test('소수 부분은 그대로, 끝의 점도 남긴다', () {
      expect(groupThousands('12345.678'), '12,345.678');
      expect(groupThousands('1234.'), '1,234.');
      expect(groupThousands('.5'), '.5');
    });
  });

  group('parseThousands', () {
    test('쉼표를 지우고 읽는다', () {
      expect(parseThousands('45,000'), 45000.0);
      expect(parseThousands('1,234,567.5'), 1234567.5);
      expect(parseThousands(' 2 '), 2.0);
    });

    test('읽을 수 없으면 null', () {
      expect(parseThousands(''), isNull);
      expect(parseThousands('abc'), isNull);
      expect(parseThousands('1.2.3'), isNull);
    });
  });

  group('ThousandsSeparatorFormatter', () {
    test('숫자를 칠 때마다 쉼표가 들어가고 커서는 끝에 있다', () {
      var v = type(formatter, '', '1');
      expect(v.text, '1');
      v = type(formatter, v.text, '${v.text}2');
      v = type(formatter, v.text, '${v.text}3');
      v = type(formatter, v.text, '${v.text}4');
      expect(v.text, '1,234');
      expect(v.selection.baseOffset, 5);
    });

    test('쉼표가 들어 있는 글자 뒤에 숫자를 이어 쳐도 한 번만 묶인다', () {
      final v = type(formatter, '1,234', '1,2345');
      expect(v.text, '12,345');
      expect(v.selection.baseOffset, 6);
    });

    test('지우면 쉼표가 줄어든다', () {
      final v = type(formatter, '1,234', '1,23');
      expect(v.text, '123');
      expect(v.selection.baseOffset, 3);
    });

    test('가운데에 숫자를 끼우면 커서가 그 숫자 뒤에 남는다', () {
      // 1,234 에서 '1' 뒤(커서 1)에 9를 쳐서 '19,234'가 아니라 '1,9234'가 된 입력.
      final v = type(formatter, '1,234', '19,234', cursor: 2);
      expect(v.text, '19,234');
      expect(v.selection.baseOffset, 2);
    });

    test('소수점은 한 번만, 소수 부분에는 쉼표가 없다', () {
      expect(type(formatter, '', '1234.5').text, '1,234.5');
      expect(type(formatter, '1,234', '1,234.').text, '1,234.');
      expect(type(formatter, '1.5', '1.5.5').text, '1.55');
      expect(type(formatter, '', '0.12345').text, '0.12345');
    });

    test('숫자와 점이 아닌 글자는 버린다', () {
      expect(type(formatter, '', 'abc').text, '');
      expect(type(formatter, '', '1a2b3').text, '123');
      expect(type(formatter, '1', '1-').text, '1');
    });

    test('붙여넣은 값의 쉼표도 다시 묶는다', () {
      expect(type(formatter, '', '1,234,567').text, '1,234,567');
      expect(type(formatter, '', '1234567').text, '1,234,567');
    });

    test('allowDecimal이 false면 점도 버린다', () {
      const integerOnly = ThousandsSeparatorFormatter(allowDecimal: false);
      expect(type(integerOnly, '', '12.5').text, '125');
    });

    test('maxDigits를 넘는 정수 자리는 잘라 낸다 (쉼표는 자리수에 세지 않는다)', () {
      const limited = ThousandsSeparatorFormatter(
        allowDecimal: false,
        maxDigits: 5,
      );
      expect(type(limited, '', '12345').text, '12,345');
      // 이미 5자리인 값 뒤에 한 자리를 더 치면 막힌다.
      expect(type(limited, '12,345', '12,3456').text, '12,345');
      expect(type(limited, '', '1234567').text, '12,345');
    });

    test('빈 글자는 빈 글자', () {
      expect(type(formatter, '1', '').text, '');
    });
  });
}
