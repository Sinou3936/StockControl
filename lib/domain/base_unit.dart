/// 재고를 세는 기본 단위. [label]이 화면 표기이자 DB에 저장되는 글자다.
/// (DB 열은 글자라서 단위를 더해도 옛 데이터와 서버 열은 바뀌지 않는다.)
enum BaseUnit {
  g('g'),
  kg('kg'),
  ml('ml'),
  l('L'),
  ea('ea');

  const BaseUnit(this.label);

  final String label;
}

extension BaseUnitDb on BaseUnit {
  String toDbString() => label;
}

BaseUnit baseUnitFromDbString(String value) =>
    BaseUnit.values.firstWhere((unit) => unit.label == value);

/// 안내 문구용 단위 목록: `g, kg, ml, L, ea`.
final String kBaseUnitList = BaseUnit.values.map((u) => u.label).join(', ');

/// 사람이 적은 글자를 단위로 읽는다 (대소문자·앞뒤 공백 무시). 모르면 null.
/// 엑셀에서 `KG`, `l`처럼 적어도 정해진 표기(`kg`, `L`)로 저장된다.
BaseUnit? parseBaseUnit(String text) {
  final lowered = text.trim().toLowerCase();
  for (final unit in BaseUnit.values) {
    if (unit.label.toLowerCase() == lowered) return unit;
  }
  return null;
}
