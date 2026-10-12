import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/domain/excel_import/cell_parsing.dart';

void main() {
  group('cellText', () {
    test('null은 빈 글자', () => expect(cellText(null), ''));
    test('앞뒤 공백을 지운다', () => expect(cellText('  양파 '), '양파'));
    test('정수는 소수점 없이', () => expect(cellText(5), '5'));
    test('소수는 그대로', () => expect(cellText(5.5), '5.5'));
    test(
      '날짜는 yyyy-MM-dd',
      () => expect(cellText(DateTime(2026, 9, 29)), '2026-09-29'),
    );
    test('cellIsBlank: 공백만 있으면 비었다, 숫자 0은 아니다', () {
      expect(cellIsBlank(' '), isTrue);
      expect(cellIsBlank(0), isFalse);
    });
  });

  group('cellNumber', () {
    test('읽히는 값', () {
      expect(cellNumber(5), 5.0);
      expect(cellNumber(1.5), 1.5);
      expect(cellNumber(' 5 '), 5.0);
      expect(cellNumber('1,000'), 1000.0);
      expect(cellNumber('1,234.5'), 1234.5);
      expect(cellNumber('-3'), -3.0);
      expect(cellNumber('-1,000'), -1000.0);
    });

    test('부호가 겹치거나 +가 붙은 글자는 null (--5가 5가 되지 않는다)', () {
      expect(cellNumber('--5'), isNull);
      expect(cellNumber('-+5'), isNull);
      expect(cellNumber('+5'), isNull);
    });

    test('천 단위 묶음이 틀린 쉼표는 null', () {
      expect(cellNumber('1,50'), isNull);
      expect(cellNumber('1234,567'), isNull);
      expect(cellNumber('1,0000'), isNull);
    });

    test("'-0'은 부호 없는 0.0 (단가가 -0.0으로 저장되지 않는다)", () {
      expect(cellNumber('-0'), 0.0);
      expect(cellNumber('-0')!.isNegative, isFalse);
      expect(cellNumber(-0.0)!.isNegative, isFalse);
    });

    test('읽을 수 없는 값은 null (조용히 0이 되지 않는다)', () {
      expect(cellNumber('1,5'), isNull);
      expect(cellNumber('5,'), isNull);
      expect(cellNumber('5g'), isNull);
      expect(cellNumber('abc'), isNull);
      expect(cellNumber(''), isNull);
      expect(cellNumber(null), isNull);
      expect(cellNumber(double.nan), isNull);
      expect(cellNumber(double.infinity), isNull);
      expect(cellNumber('Infinity'), isNull);
    });
  });

  group('cellDate', () {
    test('엑셀 날짜 셀은 시각을 버린다', () {
      expect(cellDate(DateTime(2026, 9, 29, 13, 30)), DateTime(2026, 9, 29));
    });

    test('문자 날짜 형식들', () {
      expect(cellDate('2026-09-29'), DateTime(2026, 9, 29));
      expect(cellDate('2026/09/29'), DateTime(2026, 9, 29));
      expect(cellDate('2026.9.9'), DateTime(2026, 9, 9));
      expect(cellDate('26/09/29'), DateTime(2026, 9, 29));
      expect(cellDate('2026-09-29 00:00:00'), DateTime(2026, 9, 29));
    });

    test('읽을 수 없는 값은 null', () {
      expect(cellDate('2026-02-30'), isNull);
      expect(cellDate('2026-13-01'), isNull);
      expect(cellDate('9/29'), isNull);
      expect(cellDate('abc'), isNull);
      expect(cellDate('45000'), isNull);
      expect(cellDate(45000), isNull);
      expect(cellDate(null), isNull);
      expect(cellDate(''), isNull);
    });
  });
}
