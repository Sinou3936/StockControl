/// 셀 값을 앞뒤 공백 없는 글자로. 비어 있으면 ''.
String cellText(Object? cell) {
  if (cell == null) return '';
  if (cell is String) return cell.trim();
  if (cell is DateTime) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${cell.year}-${two(cell.month)}-${two(cell.day)}';
  }
  if (cell is num) {
    return cell == cell.truncateToDouble() && cell.abs() < 1e15
        ? cell.toInt().toString()
        : cell.toString();
  }
  return cell.toString().trim();
}

bool cellIsBlank(Object? cell) => cellText(cell).isEmpty;

final _thousandsGrouped = RegExp(r'^\d{1,3}(,\d{3})+(\.\d+)?$');

/// 숫자 칸을 읽는다. 읽을 수 없으면 null (조용히 0이 되지 않는다).
/// 음수는 그대로 돌려주고 허용 여부는 부르는 쪽이 정한다.
/// 천 단위 쉼표는 올바른 묶음일 때만 받는다 (`1,5`는 15가 아니라 오류).
double? cellNumber(Object? cell) {
  if (cell is num) {
    return cell.isFinite ? _noNegativeZero(cell.toDouble()) : null;
  }
  final text = cellText(cell);
  if (text.isEmpty) return null;
  final negative = text.startsWith('-');
  final body = negative ? text.substring(1) : text;
  // 맨 앞 '-' 하나만 부호로 받는다. '--5', '-+5', '+5'는 읽을 수 없는 글자다.
  if (!_startsLikeNumber.hasMatch(body)) return null;
  if (body.contains(',') && !_thousandsGrouped.hasMatch(body)) return null;
  final parsed = double.tryParse(body.replaceAll(',', ''));
  if (parsed == null || !parsed.isFinite) return null;
  return _noNegativeZero(negative ? -parsed : parsed);
}

final _startsLikeNumber = RegExp(r'^[\d.]');

/// `-0`이 -0.0으로 저장되지 않게 한다.
double _noNegativeZero(double value) => value == 0 ? 0.0 : value;

final _dateText = RegExp(
  r'^(\d{4}|\d{2})[-/.](\d{1,2})[-/.](\d{1,2})(\s+\d{1,2}:\d{2}(:\d{2})?)?$',
);

/// 날짜 칸을 읽는다 (시각은 버리고 로컬 자정). 읽을 수 없으면 null.
/// 두 자리 연도는 20xx. 없는 날짜(2월 30일)는 null.
DateTime? cellDate(Object? cell) {
  if (cell is DateTime) return DateTime(cell.year, cell.month, cell.day);
  final match = _dateText.firstMatch(cellText(cell));
  if (match == null) return null;
  var year = int.parse(match.group(1)!);
  if (match.group(1)!.length == 2) year += 2000;
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}
