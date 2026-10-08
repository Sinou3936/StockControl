import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/domain/stock_by_date.dart';

void main() {
  group('하루 경계', () {
    test('dayStart는 시각을 지우고 dayEnd는 다음 날 0시다', () {
      final d = DateTime(2026, 10, 5, 14, 30, 15);
      expect(dayStart(d), DateTime(2026, 10, 5));
      expect(dayEnd(d), DateTime(2026, 10, 6));
    });

    test('dayEnd는 달·해 경계를 넘는다', () {
      expect(dayEnd(DateTime(2026, 10, 31)), DateTime(2026, 11, 1));
      expect(dayEnd(DateTime(2026, 12, 31)), DateTime(2027, 1, 1));
    });

    test('isSameDay는 시각을 무시한다', () {
      expect(
        isSameDay(DateTime(2026, 10, 5, 0, 0), DateTime(2026, 10, 5, 23, 59)),
        isTrue,
      );
      expect(
        isSameDay(DateTime(2026, 10, 5, 23, 59), DateTime(2026, 10, 6, 0, 0)),
        isFalse,
      );
    });
  });

  group('stockDateSelection', () {
    final now = DateTime(2026, 10, 8, 15, 0);

    test('오늘을 고르면 null (= 오늘)', () {
      expect(stockDateSelection(DateTime(2026, 10, 8), now: now), isNull);
      expect(stockDateSelection(DateTime(2026, 10, 8, 9), now: now), isNull);
    });

    test('다른 날을 고르면 시각을 지운 그 날짜', () {
      expect(
        stockDateSelection(DateTime(2026, 10, 5, 13), now: now),
        DateTime(2026, 10, 5),
      );
    });
  });

  group('stockDateLabel', () {
    final now = DateTime(2026, 10, 8);

    test('null이거나 오늘이면 "오늘"', () {
      expect(stockDateLabel(null, now: now), '오늘');
      expect(stockDateLabel(DateTime(2026, 10, 8), now: now), '오늘');
    });

    test('올해의 다른 날은 월·일만', () {
      expect(stockDateLabel(DateTime(2026, 10, 5), now: now), '10월 5일');
    });

    test('다른 해는 연도를 붙인다', () {
      expect(stockDateLabel(DateTime(2025, 12, 31), now: now), '2025년 12월 31일');
    });
  });
}
