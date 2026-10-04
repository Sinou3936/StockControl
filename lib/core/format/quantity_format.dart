/// 재고 수량을 사람이 읽기 쉽게: 5000.0 -> "5,000", 12.5 -> "12.5".
String formatQty(double value) {
  final fixed = value.toStringAsFixed(2);
  final negative = fixed.startsWith('-');
  final unsigned = negative ? fixed.substring(1) : fixed;
  final parts = unsigned.split('.');

  final grouped = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final fraction = parts[1].replaceFirst(RegExp(r'0+$'), '');

  final text = fraction.isEmpty ? grouped : '$grouped.$fraction';
  return negative && text != '0' ? '-$text' : text;
}
