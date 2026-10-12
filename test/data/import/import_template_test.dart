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

  test('안내 시트에 환산계수 설명이 있다', () {
    final rows = Excel.decodeBytes(buildImportTemplateXlsx())['안내'].rows;

    expect(
      rows.any((row) => row.any((cell) => (text(cell) ?? '').contains('환산계수'))),
      isTrue,
    );
  });
}
