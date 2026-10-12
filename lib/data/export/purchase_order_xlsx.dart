import 'dart:typed_data';

import 'package:excel/excel.dart'
    show CellIndex, CellStyle, Excel, IntCellValue, TextCellValue;

import '../../domain/purchase_order.dart';

const _sheetName = '발주서';

/// 발주서를 엑셀(.xlsx) 파일 바이트로 만든다.
Uint8List buildPurchaseOrderXlsx(PurchaseOrder order) {
  final excel = Excel.createExcel();

  // 새 파일은 Sheet1 하나를 갖고 있다. 이름을 바꿔서 쓴다.
  final defaultName = excel.getDefaultSheet();
  if (defaultName != null) {
    excel.rename(defaultName, _sheetName);
  }
  final sheet = excel[_sheetName];

  sheet.appendRow([TextCellValue('발주서')]);
  sheet.appendRow([
    TextCellValue('발주일'),
    TextCellValue(formatPurchaseOrderDate(order.date)),
  ]);
  sheet.appendRow([TextCellValue('매장'), TextCellValue(order.store.name)]);
  sheet.appendRow([TextCellValue('거래처'), TextCellValue(order.supplier.name)]);
  sheet.appendRow([
    TextCellValue('연락처'),
    TextCellValue(order.supplier.contact ?? ''),
  ]);

  // 발주일·매장·거래처·연락처의 값 칸은 B~D열(표의 수량·단위·비고 폭)로 합친다.
  // 값이 긴 거래처 이름이나 전화번호도 잘리지 않고 같은 폭으로 보인다.
  for (var row = 1; row <= 4; row++) {
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
    );
  }

  const headerRow = 5;
  sheet.appendRow([
    TextCellValue('품목'),
    TextCellValue('수량'),
    TextCellValue('단위'),
    TextCellValue('비고'),
  ]);
  for (final line in order.lines) {
    sheet.appendRow([
      TextCellValue(line.ingredient.name),
      IntCellValue(line.qty),
      TextCellValue(line.ingredient.purchaseUnit),
    ]);
  }

  // 제목과 표 머리글을 굵게.
  sheet
      .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      .cellStyle = CellStyle(
    bold: true,
  );
  for (var column = 0; column < 4; column++) {
    sheet
        .cell(
          CellIndex.indexByColumnRow(columnIndex: column, rowIndex: headerRow),
        )
        .cellStyle = CellStyle(
      bold: true,
    );
  }

  sheet.setColumnWidth(0, 28);
  sheet.setColumnWidth(1, 10);
  sheet.setColumnWidth(2, 10);
  sheet.setColumnWidth(3, 30);

  return Uint8List.fromList(excel.encode()!);
}
