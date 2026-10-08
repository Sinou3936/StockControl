import 'package:stockcontrol/data/local/database.dart';

/// 그날 00:00 (로컬).
DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

/// 다음 날 00:00 (로컬). "그날 끝"을 표현하는 배타적 상한이다.
DateTime dayEnd(DateTime d) => DateTime(d.year, d.month, d.day + 1);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 달력에서 고른 날짜를 provider에 넣을 값으로. 오늘이면 null("오늘").
DateTime? stockDateSelection(DateTime picked, {required DateTime now}) =>
    isSameDay(picked, now) ? null : dayStart(picked);

/// 날짜 버튼에 쓰는 글자.
String stockDateLabel(DateTime? selected, {required DateTime now}) {
  if (selected == null || isSameDay(selected, now)) return '오늘';
  final monthDay = '${selected.month}월 ${selected.day}일';
  return selected.year == now.year ? monthDay : '${selected.year}년 $monthDay';
}

/// 입고 목록의 한 줄: 입고 기록과 그 로트·품목, 거래처·매장 이름.
class InboundEntry {
  const InboundEntry({
    required this.movement,
    required this.lot,
    required this.ingredient,
    this.supplierName,
    this.storeName,
  });

  final StockMovement movement;
  final Lot lot;
  final Ingredient ingredient;
  final String? supplierName;
  final String? storeName;
}
