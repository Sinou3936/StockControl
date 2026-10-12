import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/domain/base_unit.dart';

void main() {
  test('round-trips every value through its db string representation', () {
    for (final unit in BaseUnit.values) {
      expect(baseUnitFromDbString(unit.toDbString()), unit);
    }
  });

  test('기본 단위는 g, kg, ml, L, ea 다섯 가지이고 DB에는 화면 표기 그대로 저장된다', () {
    expect(BaseUnit.values.map((u) => u.toDbString()), [
      'g',
      'kg',
      'ml',
      'L',
      'ea',
    ]);
  });

  group('parseBaseUnit', () {
    test('대소문자·앞뒤 공백을 가리지 않고 정해진 표기로 읽는다', () {
      expect(parseBaseUnit('g'), BaseUnit.g);
      expect(parseBaseUnit('G'), BaseUnit.g);
      expect(parseBaseUnit(' KG '), BaseUnit.kg);
      expect(parseBaseUnit('Ml'), BaseUnit.ml);
      expect(parseBaseUnit('l'), BaseUnit.l);
      expect(parseBaseUnit('L'), BaseUnit.l);
      expect(parseBaseUnit('EA'), BaseUnit.ea);
    });

    test('모르는 단위와 빈 글자는 null', () {
      expect(parseBaseUnit('oz'), isNull);
      expect(parseBaseUnit(''), isNull);
      expect(parseBaseUnit('킬로'), isNull);
    });
  });
}
