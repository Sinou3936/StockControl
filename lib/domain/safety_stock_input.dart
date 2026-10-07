/// 안전재고 입력칸을 읽은 결과.
/// - [isValid]가 false면 사용자가 뭔가 잘못 입력한 것이라 저장하면 안 된다.
/// - [value]가 null이고 [isValid]가 true면 "추적하지 않음"이다.
typedef SafetyStockInput = ({bool isValid, double? value});

/// 안전재고 입력칸의 글자를 읽는다.
///
/// - 비어 있으면(공백 포함) 추적 해제: (isValid: true, value: null)
/// - 천 단위 콤마(`5,000`)는 받는다.
/// - 0이면 추적 해제: (isValid: true, value: null) — 스펙: "빈 값이나 0은 null로 저장".
/// - 양수이면서 유한한 수면 그 값.
/// - 그 밖(글자가 섞임, 음수, NaN, 무한대)은 (isValid: false, value: null).
///   이걸 null로 저장하면 알림이 말없이 꺼지므로, 호출하는 쪽이 오류를 보여줘야 한다.
SafetyStockInput parseSafetyStockInput(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return (isValid: true, value: null);

  // 콤마만 지우므로 ',' 한 글자처럼 콤마만 있는 입력은 빈 문자열이 되어
  // tryParse가 null을 돌려주고, 아래에서 invalid로 걸러진다.
  final parsed = double.tryParse(trimmed.replaceAll(',', ''));

  // tryParse는 'Infinity', 'NaN', '1e400'도 받아들이므로 유한한지 따로 본다.
  if (parsed == null || !parsed.isFinite || parsed < 0) {
    return (isValid: false, value: null);
  }
  if (parsed == 0) return (isValid: true, value: null);
  return (isValid: true, value: parsed);
}

/// 수정 다이얼로그에 미리 채울 글자. 정수면 소수점 없이(`5000`),
/// 소수면 값 그대로(`12.345`) — formatQty처럼 반올림하지 않는다.
String safetyStockInputText(double value) {
  if (!value.isFinite) return '';
  return value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toString();
}
