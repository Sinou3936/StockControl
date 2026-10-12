import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../domain/excel_import/excel_import_types.dart';

class ImportFileException implements Exception {
  const ImportFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

Object? _value(CellValue? v) => switch (v) {
  null => null,
  // 서식이 섞인 글자(예: 한 글자만 굵게)는 text가 null이고 조각이 children에
  // 들어 있다. text만 읽으면 빈칸이 되므로 조각을 이어 붙이는 toString()을 쓴다.
  TextCellValue() => v.value.toString(),
  IntCellValue() => v.value,
  DoubleCellValue() => v.value,
  DateCellValue() => DateTime(v.year, v.month, v.day),
  DateTimeCellValue() => DateTime(
    v.year,
    v.month,
    v.day,
    v.hour,
    v.minute,
    v.second,
  ),
  BoolCellValue() => v.value,
  // 수식은 계산 결과를 알 수 없다. 빈칸으로 두면 조용히 사라지므로 글자로
  // 남겨, 숫자·날짜 칸에서는 "읽을 수 없습니다" 오류가 나게 한다.
  FormulaCellValue() => '=${v.formula}',
  // 시간만 있는 칸도 같은 이유로 글자(09:30:00)로 남긴다.
  TimeCellValue() => v.toString(),
};

RawSheet _sheet(Excel excel, String name) => [
  for (final row in excel.tables[name]!.rows)
    [for (final cell in row) _value(cell?.value)],
];

/// `.xlsx` 바이트에서 세 데이터 시트를 읽는다. 시트가 없거나 엑셀 파일이
/// 아니면 [ImportFileException].
RawWorkbook readImportWorkbook(Uint8List bytes) {
  final Excel excel;
  try {
    excel = Excel.decodeBytes(bytes);
  } catch (error, stack) {
    // 사용자에게는 쉬운 안내만 보이고, 진짜 원인은 로그에 남긴다.
    debugPrint('엑셀 읽기 실패: $error\n$stack');
    throw const ImportFileException(
      '엑셀 파일(.xlsx)을 읽을 수 없습니다. 앱에서 받은 양식을 .xlsx로 저장해 올려 주세요.',
    );
  }

  const required = [kSuppliersSheet, kIngredientsSheet, kInboundSheet];
  final missing = [
    for (final name in required)
      if (!excel.tables.containsKey(name)) "'$name'",
  ];
  if (missing.isNotEmpty) {
    final found = excel.tables.keys.join(', ');
    throw ImportFileException(
      '${missing.join(', ')} 시트가 없습니다 (파일의 시트: $found). '
      '앱에서 받은 양식을 그대로 써 주세요.',
    );
  }

  return RawWorkbook(
    suppliers: _sheet(excel, kSuppliersSheet),
    ingredients: _sheet(excel, kIngredientsSheet),
    inbound: _sheet(excel, kInboundSheet),
  );
}
