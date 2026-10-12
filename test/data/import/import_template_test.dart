import 'package:excel/excel.dart' show Data, Excel, TextCellValue;
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/import/import_template.dart';
import 'package:stockcontrol/domain/excel_import/excel_import_types.dart';

/// 셀의 글자. TextCellValue.value는 문자열이 아니라 TextSpan이라 .text로
/// 꺼내야 한다.
String? text(Data? cell) {
  final value = cell?.value;
  if (value is TextCellValue) return value.value.text;
  return value?.toString();
}

void main() {
  test('시트는 안내, 거래처, 품목, 입고 순서다', () {
    final back = Excel.decodeBytes(buildImportTemplateXlsx());

    expect(back.tables.keys.toList(), ['안내', '거래처', '품목', '입고']);
  });

  test('파일 이름 상수', () {
    expect(importTemplateFileName, '재고관리_업로드_양식.xlsx');
  });

  for (final (sheetName, headers) in [
    (kSuppliersSheet, kSupplierHeaders),
    (kIngredientsSheet, kIngredientHeaders),
    (kInboundSheet, kInboundHeaders),
  ]) {
    test('$sheetName 시트는 첫 줄이 머리글이고 둘째 줄부터는 비어 있다', () {
      final rows = Excel.decodeBytes(buildImportTemplateXlsx())[sheetName].rows;

      expect(rows.first.map(text).toList(), headers);
      // 예시는 안내 시트에만 둔다. 데이터 시트에 예시를 두면 그대로 올라간다.
      for (final row in rows.skip(1)) {
        expect(
          row.every((cell) => cell == null || cell.value == null),
          isTrue,
          reason: '$sheetName 시트에 머리글 말고 값이 있다: ${row.map(text)}',
        );
      }
    });
  }

  group('안내 시트 문구', () {
    final guideLines = [
      for (final row in Excel.decodeBytes(buildImportTemplateXlsx())['안내'].rows)
        for (final cell in row) text(cell) ?? '',
    ];

    bool hasLine(List<String> parts) =>
        guideLines.any((line) => parts.every(line.contains));

    test('환산계수의 정의와 예시', () {
      expect(hasLine(['환산계수', '구매 단위 1개', '기본 단위로 몇 개']), isTrue);
      expect(hasLine(['환산계수', '20000']), isTrue);
    });

    test('입고 날짜는 비워 두면 올리는 날(오늘)이 된다고 안내한다', () {
      expect(hasLine(['3.', '날짜', '비워 두면', '올리는 날']), isTrue);
    });

    test('품목 시트 칸 설명: 구매 단위는 이름, 환산계수는 숫자', () {
      expect(hasLine(['10.', '구매 단위', '단위 이름', '숫자만 적지 마세요', '환산계수']), isTrue);
    });

    test('품목 시트 예시 줄이 안내 시트에 있다 (데이터 시트가 아니라)', () {
      expect(hasLine(['품목 시트 예시']), isTrue);
      expect(guideLines, containsAll(kIngredientHeaders));
      // 쌀 20kg 포대와 낱개 품목(구매 단위 EA, 환산계수 1) 두 가지.
      expect(guideLines, containsAll(['쌀 20KG', 'g', '포', '20000']));
      expect(guideLines, containsAll(['목장갑', 'ea', 'EA', '1']));
    });

    test('기본 단위는 g, kg, ml, L, ea 중 하나', () {
      expect(hasLine(['5.', '기본 단위는 g, kg, ml, L, ea 중 하나입니다']), isTrue);
    });

    test('유통기한 관리는 예 또는 아니오, 단가를 비우면 0', () {
      expect(hasLine(['예 또는 아니오', '비우면 아니오']), isTrue);
      expect(hasLine(['단가를 비우면 0']), isTrue);
    });

    test('수식과 연락처 주의', () {
      expect(
        hasLine(['8.', '수식(=...)이 든 칸은 읽을 수 없습니다', '값으로 붙여넣어 주세요']),
        isTrue,
      );
      expect(
        hasLine(['9.', '연락처는 010-1234-5678처럼', "'-'를 넣어", '앞의 0이 사라질 수 있습니다']),
        isTrue,
      );
    });
  });
}
