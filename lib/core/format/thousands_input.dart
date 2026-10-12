import 'dart:math' as math;

import 'package:flutter/services.dart';

/// 숫자 글자(`1234.5`)의 정수 부분에 세 자리마다 쉼표를 넣는다. 소수 부분은
/// 그대로 둔다 (`12345.678` -> `12,345.678`).
String groupThousands(String raw) {
  final dot = raw.indexOf('.');
  final integer = dot < 0 ? raw : raw.substring(0, dot);
  final rest = dot < 0 ? '' : raw.substring(dot);
  final grouped = integer.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '$grouped$rest';
}

/// 쉼표가 들어 있을 수 있는 입력칸의 글자를 숫자로 읽는다. 읽을 수 없으면 null.
/// [ThousandsSeparatorFormatter]가 붙은 칸은 쉼표가 항상 올바른 자리에 있으므로
/// 지우기만 하면 된다.
double? parseThousands(String text) =>
    double.tryParse(text.trim().replaceAll(',', ''));

/// 숫자 입력칸에서 천 단위 쉼표를 자동으로 넣어 보여 준다 (`45000` -> `45,000`).
///
/// 칸에 보이는 글자에는 쉼표가 있으므로, 저장할 때는 `double.parse`가 아니라
/// [parseThousands]로 읽어야 한다.
class ThousandsSeparatorFormatter extends TextInputFormatter {
  const ThousandsSeparatorFormatter({this.allowDecimal = true, this.maxDigits});

  /// 소수점을 받을지. false면 점은 버린다.
  final bool allowDecimal;

  /// 정수 부분의 최대 자리수 (쉼표는 세지 않는다). 넘는 자리는 잘라 낸다.
  final int? maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final cursor = newValue.selection.extentOffset.clamp(0, text.length);

    // 숫자와 점(한 번)만 남긴다. 커서 앞에 남은 글자 수를 센다: 쉼표를 다시
    // 넣으면 글자 위치가 달라지므로, "남긴 글자 몇 개 뒤"로 커서를 옮긴다.
    final kept = StringBuffer();
    var keptBeforeCursor = 0;
    var seenDot = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      final isDigit = ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39;
      final isDot = allowDecimal && ch == '.' && !seenDot;
      if (!isDigit && !isDot) continue;
      if (isDot) seenDot = true;
      kept.write(ch);
      if (i < cursor) keptBeforeCursor++;
    }

    var raw = kept.toString();
    final limit = maxDigits;
    if (limit != null) {
      final dot = raw.indexOf('.');
      final integer = dot < 0 ? raw : raw.substring(0, dot);
      if (integer.length > limit) {
        raw = integer.substring(0, limit) + (dot < 0 ? '' : raw.substring(dot));
        keptBeforeCursor = math.min(keptBeforeCursor, raw.length);
      }
    }

    final formatted = groupThousands(raw);
    var position = 0;
    var counted = 0;
    while (position < formatted.length && counted < keptBeforeCursor) {
      if (formatted[position] != ',') counted++;
      position++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: position),
    );
  }
}
