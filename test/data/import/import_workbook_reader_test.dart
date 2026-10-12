import 'dart:typed_data';

import 'package:excel/excel.dart'
    show
        BoolCellValue,
        CellIndex,
        CellValue,
        DateCellValue,
        DateTimeCellValue,
        DoubleCellValue,
        Excel,
        FormulaCellValue,
        IntCellValue,
        Sheet,
        TextCellValue,
        TimeCellValue;
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/import/import_template.dart';
import 'package:stockcontrol/data/import/import_workbook_reader.dart';
import 'package:stockcontrol/domain/excel_import/excel_import_types.dart';
import 'package:stockcontrol/domain/excel_import/import_validator.dart';

final _now = DateTime(2026, 10, 12, 15);

ImportValidation _validate(RawWorkbook book) => validateImport(
  book,
  existingSupplierNames: const {},
  existingIngredients: const {},
  now: _now,
);

/// 시트 이름 → (줄, 칸) → 값. 값이 있는 칸만 쓴다.
Uint8List _build(Map<String, Map<(int, int), CellValue>> sheets) {
  final excel = Excel.createExcel();
  final defaultName = excel.getDefaultSheet();
  var first = true;
  for (final entry in sheets.entries) {
    if (first && defaultName != null) {
      excel.rename(defaultName, entry.key);
      first = false;
    }
    final Sheet sheet = excel[entry.key];
    for (final cell in entry.value.entries) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(
          columnIndex: cell.key.$2,
          rowIndex: cell.key.$1,
        ),
        cell.value,
      );
    }
  }
  return Uint8List.fromList(excel.encode()!);
}

Map<(int, int), CellValue> _headers(List<String> headers, [int row = 0]) => {
  for (var c = 0; c < headers.length; c++) (row, c): TextCellValue(headers[c]),
};

void main() {
  test('양식 그대로 읽으면 세 시트 모두 머리글 한 줄뿐이고 검증을 통과한다', () {
    final book = readImportWorkbook(buildImportTemplateXlsx());

    expect(book.suppliers, [kSupplierHeaders]);
    expect(book.ingredients, [kIngredientHeaders]);
    expect(book.inbound, [kInboundHeaders]);
    expect(_validate(book).isValid, isTrue);
  });

  test('셀 종류마다 알맞은 값으로 읽는다', () {
    final bytes = _build({
      kSuppliersSheet: _headers(kSupplierHeaders),
      kIngredientsSheet: _headers(kIngredientHeaders),
      kInboundSheet: {
        // 머리글 대신 값 종류를 시험하는 시트라서 머리글은 쓰지 않는다.
        (0, 0): TextCellValue('쌀'),
        (0, 1): const IntCellValue(2),
        (0, 2): const DoubleCellValue(1.5),
        (0, 3): const DateCellValue(year: 2026, month: 9, day: 29),
        (0, 4): const DateTimeCellValue(
          year: 2026,
          month: 9,
          day: 29,
          hour: 13,
          minute: 30,
        ),
        (0, 5): const BoolCellValue(true),
        // (0, 6)은 일부러 비워 둔다.
        (0, 7): TextCellValue('끝'),
      },
    });

    final row = readImportWorkbook(bytes).inbound.first;

    expect(row[0], '쌀');
    expect(row[1], isA<num>());
    expect(row[1], 2);
    expect(row[2], 1.5);
    expect(row[3], DateTime(2026, 9, 29));
    expect(row[4], DateTime(2026, 9, 29, 13, 30));
    expect(row[5], true);
    expect(row[6], isNull);
    expect(row[7], '끝');
  });

  test('날짜 셀은 검증을 거쳐도 같은 날 09:00이 된다 (날짜+시간 셀도 날짜만 쓴다)', () {
    final bytes = _build({
      kSuppliersSheet: {
        ..._headers(kSupplierHeaders),
        (1, 0): TextCellValue('다라'),
      },
      kIngredientsSheet: {
        ..._headers(kIngredientHeaders),
        (1, 0): TextCellValue('쌀'),
        (1, 1): TextCellValue('g'),
        (1, 2): TextCellValue('포'),
        (1, 3): const IntCellValue(20000),
        (1, 5): TextCellValue('예'),
      },
      kInboundSheet: {
        ..._headers(kInboundHeaders),
        (1, 0): const DateCellValue(year: 2026, month: 9, day: 29),
        (1, 1): TextCellValue('다라'),
        (1, 2): TextCellValue('쌀'),
        (1, 3): const IntCellValue(2),
        (1, 4): const IntCellValue(45000),
        (1, 5): const DateCellValue(year: 2026, month: 12, day: 31),
        (2, 0): const DateTimeCellValue(
          year: 2026,
          month: 9,
          day: 30,
          hour: 13,
          minute: 30,
        ),
        (2, 1): TextCellValue('다라'),
        (2, 2): TextCellValue('쌀'),
        (2, 3): const DoubleCellValue(1.5),
      },
    });

    final result = _validate(readImportWorkbook(bytes));

    expect(result.errors, isEmpty);
    final lines = result.plan!.inboundLines;
    expect(lines[0].receivedAt, DateTime(2026, 9, 29, 9));
    expect(lines[0].expiryDate, DateTime(2026, 12, 31));
    expect(lines[0].baseQty, 40000);
    expect(lines[1].receivedAt, DateTime(2026, 9, 30, 9));
    expect(lines[1].purchaseQty, 1.5);
  });

  test('날짜가 달의 마지막 날이나 연말이어도 하루 밀리지 않는다', () {
    final bytes = _build({
      kSuppliersSheet: _headers(kSupplierHeaders),
      kIngredientsSheet: _headers(kIngredientHeaders),
      kInboundSheet: {
        (0, 0): const DateCellValue(year: 2025, month: 12, day: 31),
        (0, 1): const DateCellValue(year: 2024, month: 2, day: 29),
        (0, 2): const DateCellValue(year: 2026, month: 1, day: 1),
        (0, 3): const DateTimeCellValue(
          year: 2025,
          month: 12,
          day: 31,
          hour: 23,
          minute: 59,
        ),
      },
    });

    final row = readImportWorkbook(bytes).inbound.first;

    expect(row[0], DateTime(2025, 12, 31));
    expect(row[1], DateTime(2024, 2, 29));
    expect(row[2], DateTime(2026, 1, 1));
    expect(row[3], DateTime(2025, 12, 31, 23, 59));
  });

  test('수식 셀은 빈칸이 되지 않고 =수식 글자로 읽는다', () {
    final bytes = _build({
      kSuppliersSheet: _headers(kSupplierHeaders),
      kIngredientsSheet: _headers(kIngredientHeaders),
      kInboundSheet: {(0, 0): const FormulaCellValue('1+1')},
    });

    final cell = readImportWorkbook(bytes).inbound.first.first;

    expect(cell, '=1+1');
  });

  test('시간만 있는 셀도 빈칸이 되지 않는다', () {
    final bytes = _build({
      kSuppliersSheet: _headers(kSupplierHeaders),
      kIngredientsSheet: _headers(kIngredientHeaders),
      kInboundSheet: {(0, 0): const TimeCellValue(hour: 9, minute: 30)},
    });

    final cell = readImportWorkbook(bytes).inbound.first.first;

    expect(cell, isNotNull);
  });

  test('시트가 빠진 파일은 빠진 시트 이름을 알려 준다', () {
    final bytes = _build({kSuppliersSheet: _headers(kSupplierHeaders)});

    expect(
      () => readImportWorkbook(bytes),
      throwsA(
        isA<ImportFileException>().having(
          (e) => e.message,
          'message',
          allOf(contains("'품목'"), contains("'입고'"), isNot(contains("'거래처'"))),
        ),
      ),
    );
  });

  test('엑셀이 아닌 바이트는 읽을 수 없다는 안내를 한다', () {
    expect(
      () => readImportWorkbook(Uint8List.fromList([1, 2, 3])),
      throwsA(
        isA<ImportFileException>().having(
          (e) => e.message,
          'message',
          startsWith('엑셀 파일(.xlsx)을 읽을 수 없습니다'),
        ),
      ),
    );
  });

  test('가운데 빈 줄이 있어도 줄 번호가 엑셀 번호와 맞다', () {
    // 엑셀 3번째 줄은 비우고, 4번째 줄에 오류(수량 없음)를 둔다.
    final bytes = _build({
      kSuppliersSheet: {
        ..._headers(kSupplierHeaders),
        (1, 0): TextCellValue('다라'),
      },
      kIngredientsSheet: {
        ..._headers(kIngredientHeaders),
        (1, 0): TextCellValue('쌀'),
        (1, 1): TextCellValue('g'),
        (1, 2): TextCellValue('포'),
        (1, 3): const IntCellValue(20000),
      },
      kInboundSheet: {
        ..._headers(kInboundHeaders),
        (1, 0): const DateCellValue(year: 2026, month: 9, day: 29),
        (1, 1): TextCellValue('다라'),
        (1, 2): TextCellValue('쌀'),
        (1, 3): const IntCellValue(2),
        // 엑셀 3번째 줄 (rowIndex 2)은 비워 둔다.
        (3, 0): const DateCellValue(year: 2026, month: 9, day: 30),
        (3, 1): TextCellValue('다라'),
        (3, 2): TextCellValue('쌀'),
      },
    });

    final result = _validate(readImportWorkbook(bytes));

    expect(result.errors.map((e) => e.text), [
      '입고 시트 4번째 줄: 수량은 0보다 큰 숫자여야 합니다',
    ]);
  });
}
