import 'dart:typed_data';

import 'package:excel/excel.dart'
    show
        CellValue,
        DateCellValue,
        DoubleCellValue,
        Excel,
        IntCellValue,
        TextCellValue;
import 'package:stockcontrol/domain/excel_import/excel_import_types.dart';

CellValue? _cell(Object? value) => switch (value) {
  null => null,
  String() => TextCellValue(value),
  int() => IntCellValue(value),
  double() => DoubleCellValue(value),
  DateTime() => DateCellValue(
    year: value.year,
    month: value.month,
    day: value.day,
  ),
  _ => throw ArgumentError('지원하지 않는 셀 값: $value'),
};

/// 업로드 양식과 같은 시트 구성의 `.xlsx` 바이트. 데이터 시트마다 머리글 한 줄
/// 뒤에 [suppliers]/[ingredients]/[inbound]의 줄을 쓴다. 셀 값은 String, int,
/// double, DateTime(엑셀 날짜 셀), null(빈 칸) 중 하나다.
Uint8List xlsx({
  List<List<Object?>> suppliers = const [],
  List<List<Object?>> ingredients = const [],
  List<List<Object?>> inbound = const [],
}) {
  final excel = Excel.createExcel();
  final defaultName = excel.getDefaultSheet();
  if (defaultName != null) excel.rename(defaultName, kGuideSheet);

  void write(String name, List<String> headers, List<List<Object?>> rows) {
    final sheet = excel[name];
    sheet.appendRow([for (final h in headers) TextCellValue(h)]);
    for (final row in rows) {
      sheet.appendRow([for (final v in row) _cell(v)]);
    }
  }

  write(kSuppliersSheet, kSupplierHeaders, suppliers);
  write(kIngredientsSheet, kIngredientHeaders, ingredients);
  write(kInboundSheet, kInboundHeaders, inbound);
  return Uint8List.fromList(excel.encode()!);
}
