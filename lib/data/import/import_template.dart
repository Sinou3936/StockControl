import 'dart:typed_data';

import 'package:excel/excel.dart'
    show CellIndex, CellStyle, Excel, Sheet, TextCellValue;

import '../../domain/excel_import/excel_import_types.dart';

const importTemplateFileName = '재고관리_업로드_양식.xlsx';

void _writeHeader(Sheet sheet, List<String> headers) {
  sheet.appendRow([for (final h in headers) TextCellValue(h)]);
  for (var column = 0; column < headers.length; column++) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0))
        .cellStyle = CellStyle(
      bold: true,
    );
    sheet.setColumnWidth(column, 18);
  }
}

/// 빈 양식 `.xlsx`. 안내 시트에만 설명과 예시를 두고, 데이터 시트는 머리글만
/// 둔다 (예시 줄이 데이터로 읽히지 않게).
Uint8List buildImportTemplateXlsx() {
  final excel = Excel.createExcel();
  final defaultName = excel.getDefaultSheet();
  if (defaultName != null) excel.rename(defaultName, kGuideSheet);

  final guide = excel[kGuideSheet];
  const lines = [
    '엑셀 업로드 양식',
    '',
    '1. 거래처, 품목, 입고 시트의 2행부터 채웁니다. 1행(머리글)은 지우거나 바꾸지 마세요.',
    '2. 입고 시트의 거래처와 품목명은 거래처·품목 시트에 있거나 앱에 이미 등록되어 있어야 합니다.',
    '3. 날짜는 2026-09-29처럼 적습니다 (엑셀 날짜 칸도 됩니다). 오늘 이후 날짜는 올릴 수 없습니다.',
    '4. 환산계수는 구매 단위 1개가 기본 단위로 몇 개인지입니다. 예: 쌀 20kg 1포 → 기본 단위 g, 구매 단위 포, 환산계수 20000.',
    '5. 기본 단위는 g, ml, ea 중 하나입니다. 유통기한 관리는 예 또는 아니오이고, 비우면 아니오입니다.',
    '6. 단가를 비우면 0으로 등록됩니다. 유통기한은 유통기한 관리 품목에만 적용됩니다.',
    '7. 오류가 하나라도 있으면 아무것도 저장되지 않습니다. 미리보기에서 줄 번호와 이유를 알려 줍니다.',
    '8. 수식(=...)이 든 칸은 읽을 수 없습니다. 값으로 붙여넣어 주세요.',
    "9. 연락처는 010-1234-5678처럼 '-'를 넣어 문자로 적어 주세요 (숫자로만 적으면 앞의 0이 사라질 수 있습니다).",
    '',
    '입고 시트 예시',
  ];
  for (final line in lines) {
    guide.appendRow([TextCellValue(line)]);
  }
  guide.appendRow([for (final h in kInboundHeaders) TextCellValue(h)]);
  guide.appendRow([
    TextCellValue('2026-09-29'),
    TextCellValue('가나다상사'),
    TextCellValue('쌀 20KG'),
    TextCellValue('2'),
    TextCellValue('45000'),
    TextCellValue(''),
  ]);
  guide
      .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      .cellStyle = CellStyle(
    bold: true,
  );
  guide.setColumnWidth(0, 60);

  _writeHeader(excel[kSuppliersSheet], kSupplierHeaders);
  _writeHeader(excel[kIngredientsSheet], kIngredientHeaders);
  _writeHeader(excel[kInboundSheet], kInboundHeaders);
  return Uint8List.fromList(excel.encode()!);
}
