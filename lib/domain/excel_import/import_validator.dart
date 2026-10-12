import '../base_unit.dart';
import '../stock_by_date.dart';
import 'cell_parsing.dart';
import 'excel_import_types.dart';

class _IngredientInfo {
  const _IngredientInfo({
    required this.baseUnit,
    required this.purchaseUnit,
    required this.conversionFactor,
    required this.isExpiryTracked,
  });

  factory _IngredientInfo.of(ExistingIngredient e) => _IngredientInfo(
    baseUnit: e.baseUnit,
    purchaseUnit: e.purchaseUnit,
    conversionFactor: e.conversionFactor,
    isExpiryTracked: e.isExpiryTracked,
  );

  final String baseUnit;
  final String purchaseUnit;
  final double conversionFactor;
  final bool isExpiryTracked;
}

/// 머리글 이름 → 열 위치. 빠진 머리글이 있으면 [errors]에 더하고 null.
Map<String, int>? _headerColumns(
  String sheetName,
  RawSheet sheet,
  List<String> required,
  List<ImportError> errors,
) {
  final header = sheet.isEmpty ? const <Object?>[] : sheet.first;
  final columns = <String, int>{};
  for (var i = 0; i < header.length; i++) {
    columns.putIfAbsent(cellText(header[i]), () => i);
  }
  var complete = true;
  for (final name in required) {
    if (!columns.containsKey(name)) {
      errors.add(ImportError(sheetName, 1, "'$name' 열이 없습니다"));
      complete = false;
    }
  }
  return complete ? columns : null;
}

/// 머리글 아래의 데이터 줄. 완전히 빈 줄은 건너뛰고, 줄 번호는 엑셀 번호(머리글이 1).
List<({int number, List<Object?> cells})> _dataRows(RawSheet sheet) {
  final rows = <({int number, List<Object?> cells})>[];
  for (var i = 1; i < sheet.length; i++) {
    final cells = sheet[i];
    if (cells.every(cellIsBlank)) continue;
    rows.add((number: i + 1, cells: cells));
  }
  return rows;
}

bool _isFormula(Object? cell) =>
    cell is String && cell.startsWith('=') && cell.trim().length > 1;

/// 수식이 든 줄을 줄마다 오류 하나로 모은다. 리더는 수식 칸을 '=계산결과'로
/// 넘기는데 그대로 쓰면 이름 앞에 '='가 붙은 채 조용히 등록되거나, 숫자 칸에서
/// 이유를 알 수 없는 오류가 난다.
void _checkFormulas(
  String sheetName,
  RawSheet sheet,
  List<ImportError> errors,
) {
  for (var i = 1; i < sheet.length; i++) {
    final column = sheet[i].indexWhere(_isFormula);
    if (column < 0) continue;
    errors.add(
      ImportError(
        sheetName,
        i + 1,
        '수식이 들어 있습니다 (${column + 1}번째 칸). 값만 복사해 붙여넣어 주세요',
      ),
    );
  }
}

/// 엑셀은 숫자로 친 전화번호(01012345678)의 앞 0을 파일에 저장하기 전에 이미
/// 지운다. 숫자 칸이고 9~10자리(휴대폰 10자리, 지역번호 9~10자리)이면 앞에 0이
/// 있었던 번호로 본다. 8자리는 1588-1234 같은 대표번호일 수 있어 추측하지 않는다.
final _onlyNumber = RegExp(r'^[\d.,\s]+$');

bool _isPhoneMissingZero(Object? cell) {
  if (cell is! num || !cell.isFinite || cell != cell.truncateToDouble()) {
    return false;
  }
  final digits = cell.toInt().toString();
  return digits.length >= 9 && digits.length <= 10;
}

Object? _at(List<Object?> row, int column) =>
    column < row.length ? row[column] : null;

String _num(double value) => value == value.truncateToDouble()
    ? value.toInt().toString()
    : value.toString();

/// 파일의 내용을 검사해 저장할 계획을 만든다. 오류는 한 번에 모두 모은다.
ImportValidation validateImport(
  RawWorkbook book, {
  required Set<String> existingSupplierNames,
  required Map<String, ExistingIngredient> existingIngredients,
  required DateTime now,
}) {
  final errors = <ImportError>[];
  final supplierCols = _headerColumns(
    kSuppliersSheet,
    book.suppliers,
    kSupplierHeaders,
    errors,
  );
  final ingredientCols = _headerColumns(
    kIngredientsSheet,
    book.ingredients,
    kIngredientHeaders,
    errors,
  );
  final inboundCols = _headerColumns(
    kInboundSheet,
    book.inbound,
    kInboundHeaders,
    errors,
  );
  if (supplierCols == null || ingredientCols == null || inboundCols == null) {
    return ImportValidation(plan: null, errors: errors);
  }

  // 수식이 있으면 값을 믿을 수 없다. 다른 검사는 하지 않고 수식부터 고치게 한다.
  _checkFormulas(kSuppliersSheet, book.suppliers, errors);
  _checkFormulas(kIngredientsSheet, book.ingredients, errors);
  _checkFormulas(kInboundSheet, book.inbound, errors);
  if (errors.isNotEmpty) return ImportValidation(plan: null, errors: errors);

  // ---- 거래처
  final sheetSuppliers = <String, int>{};
  final newSuppliers = <NewSupplier>[];
  var restoredPhoneCount = 0;
  for (final row in _dataRows(book.suppliers)) {
    final name = cellName(_at(row.cells, supplierCols['이름']!));
    if (name.isEmpty) {
      errors.add(ImportError(kSuppliersSheet, row.number, '이름이 비어 있습니다'));
      continue;
    }
    final first = sheetSuppliers[name];
    if (first != null) {
      errors.add(
        ImportError(
          kSuppliersSheet,
          row.number,
          '같은 이름이 시트 안에 두 번 있습니다 ($first번째 줄과 같음)',
        ),
      );
      continue;
    }
    sheetSuppliers[name] = row.number;
    if (existingSupplierNames.contains(name)) continue;
    final contactCell = _at(row.cells, supplierCols['연락처']!);
    var contact = cellText(contactCell);
    if (_isPhoneMissingZero(contactCell)) {
      contact = '0$contact';
      restoredPhoneCount++;
    }
    newSuppliers.add(
      NewSupplier(name: name, contact: contact.isEmpty ? null : contact),
    );
  }

  // ---- 품목. 줄이 틀렸어도 이름은 등록해 둔다 (값은 null): 입고 줄에 "품목
  // 없음" 오류가 따로 생겨 같은 문제가 두 번 보이는 것을 막는다.
  final sheetIngredients = <String, _IngredientInfo?>{};
  final newIngredients = <NewIngredient>[];
  for (final row in _dataRows(book.ingredients)) {
    final name = cellName(_at(row.cells, ingredientCols['품목명']!));
    if (name.isEmpty) {
      errors.add(ImportError(kIngredientsSheet, row.number, '품목명이 비어 있습니다'));
      continue;
    }
    if (sheetIngredients.containsKey(name)) {
      errors.add(
        ImportError(kIngredientsSheet, row.number, '같은 이름이 시트 안에 두 번 있습니다'),
      );
      continue;
    }

    var ok = true;
    void fail(String message) {
      errors.add(ImportError(kIngredientsSheet, row.number, message));
      ok = false;
    }

    // `KG`, `l`처럼 적어도 정해진 표기(`kg`, `L`)로 맞춘다.
    final parsedUnit = parseBaseUnit(
      cellText(_at(row.cells, ingredientCols['기본 단위']!)),
    );
    if (parsedUnit == null) fail('기본 단위는 $kBaseUnitList 중 하나여야 합니다');
    final baseUnit = parsedUnit?.label ?? '';

    final purchaseUnit = cellText(_at(row.cells, ingredientCols['구매 단위']!));
    if (purchaseUnit.isEmpty) {
      fail('구매 단위가 비어 있습니다');
    } else if (_onlyNumber.hasMatch(purchaseUnit)) {
      // 구매 단위는 EA·포·박스 같은 이름이다. 숫자만 있으면 환산계수나 수량을
      // 한 칸 옆에 적은 것이라, 그대로 등록되면 발주서 단위 칸에 숫자가 찍힌다.
      fail(
        '구매 단위에 숫자가 적혀 있습니다. EA, 포, 박스처럼 단위 이름을 적어 주세요 '
        '(몇 개인지는 환산계수 칸)',
      );
    }

    final factor = cellNumber(_at(row.cells, ingredientCols['환산계수']!));
    if (factor == null || factor <= 0) fail('환산계수는 0보다 큰 숫자여야 합니다');

    double? safety;
    final safetyCell = _at(row.cells, ingredientCols['안전재고']!);
    if (!cellIsBlank(safetyCell)) {
      final value = cellNumber(safetyCell);
      if (value == null || value < 0) {
        fail('안전재고를 숫자로 적어 주세요 (비우면 알림에서 제외)');
      } else if (value > 0) {
        safety = value;
      }
    }

    final trackedText = cellText(_at(row.cells, ingredientCols['유통기한 관리']!));
    var tracked = false;
    if (trackedText == '예') {
      tracked = true;
    } else if (trackedText.isNotEmpty && trackedText != '아니오') {
      fail("유통기한 관리는 '예' 또는 '아니오'로 적어 주세요");
    }

    if (!ok) {
      sheetIngredients[name] = null;
      continue;
    }

    final existing = existingIngredients[name];
    if (existing != null) {
      if (existing.baseUnit != baseUnit ||
          (existing.conversionFactor - factor!).abs() > 1e-9) {
        errors.add(
          ImportError(
            kIngredientsSheet,
            row.number,
            '이미 등록된 품목과 기본 단위나 환산계수가 다릅니다 '
            '(등록된 값: ${existing.baseUnit}, ${_num(existing.conversionFactor)})',
          ),
        );
        sheetIngredients[name] = null;
      } else {
        sheetIngredients[name] = _IngredientInfo.of(existing);
      }
      continue;
    }

    sheetIngredients[name] = _IngredientInfo(
      baseUnit: baseUnit,
      purchaseUnit: purchaseUnit,
      conversionFactor: factor!,
      isExpiryTracked: tracked,
    );
    newIngredients.add(
      NewIngredient(
        name: name,
        baseUnit: baseUnit,
        purchaseUnit: purchaseUnit,
        conversionFactor: factor,
        safetyStockQty: safety,
        isExpiryTracked: tracked,
      ),
    );
  }

  // ---- 입고
  final inboundRows = _dataRows(book.inbound);
  if (inboundRows.length > kMaxInboundRows) {
    errors.add(
      ImportError(
        kInboundSheet,
        1,
        '입고 줄이 ${_withComma(kMaxInboundRows)}개를 넘습니다 (${inboundRows.length}개)',
      ),
    );
    return ImportValidation(plan: null, errors: errors);
  }

  final today = dayStart(now);
  final lines = <InboundLine>[];
  var noPriceCount = 0;
  var ignoredExpiryCount = 0;

  for (final row in inboundRows) {
    var ok = true;
    void fail(String message) {
      errors.add(ImportError(kInboundSheet, row.number, message));
      ok = false;
    }

    // 날짜
    DateTime? date;
    final dateCell = _at(row.cells, inboundCols['날짜']!);
    if (cellIsBlank(dateCell)) {
      fail('날짜가 비어 있습니다');
    } else {
      date = cellDate(dateCell);
      if (date == null) {
        fail('날짜를 읽을 수 없습니다 (예: 2026-09-29)');
      } else if (date.isAfter(today)) {
        fail('오늘 이후 날짜입니다');
        date = null;
      }
    }

    // 거래처
    final supplierName = cellName(_at(row.cells, inboundCols['거래처']!));
    if (supplierName.isEmpty) {
      fail('거래처가 비어 있습니다');
    } else if (!sheetSuppliers.containsKey(supplierName) &&
        !existingSupplierNames.contains(supplierName)) {
      fail('거래처 "$supplierName"가 거래처 시트나 등록된 거래처에 없습니다');
    }

    // 품목
    final itemName = cellName(_at(row.cells, inboundCols['품목명']!));
    _IngredientInfo? info;
    if (itemName.isEmpty) {
      fail('품목명이 비어 있습니다');
    } else if (sheetIngredients.containsKey(itemName)) {
      info = sheetIngredients[itemName];
      // info가 null이면 품목 시트의 그 줄이 이미 오류다. 여기서 또 알리지 않는다
      // (아래에서 info가 null인 줄은 계획에 넣지 않고 건너뛴다).
    } else if (existingIngredients.containsKey(itemName)) {
      info = _IngredientInfo.of(existingIngredients[itemName]!);
    } else {
      fail('품목 "$itemName"이(가) 품목 시트나 등록된 품목에 없습니다');
    }

    // 수량
    final qty = cellNumber(_at(row.cells, inboundCols['수량']!));
    if (qty == null || qty <= 0 || qty > 1e9) fail('수량은 0보다 큰 숫자여야 합니다');

    // 단가
    var unitCost = 0.0;
    var noPrice = false;
    final costCell = _at(row.cells, inboundCols['단가']!);
    if (cellIsBlank(costCell)) {
      noPrice = true;
    } else {
      final value = cellNumber(costCell);
      if (value == null || value < 0) {
        fail('단가를 0 이상의 숫자로 적어 주세요 (비우면 0)');
      } else {
        unitCost = value;
      }
    }

    // 유통기한
    DateTime? expiry;
    var ignoredExpiry = false;
    final expiryCell = _at(row.cells, inboundCols['유통기한']!);
    if (!cellIsBlank(expiryCell)) {
      if (info != null && !info.isExpiryTracked) {
        // 유통기한 관리 품목이 아니면 칸을 읽지 않고 무시한다 (읽히는지, 입고
        // 날짜보다 이른지도 보지 않는다). 오류가 아니고 경고로만 센다.
        ignoredExpiry = true;
      } else {
        final value = cellDate(expiryCell);
        if (value == null) {
          fail('유통기한을 읽을 수 없습니다 (예: 2026-12-31)');
        } else if (date != null && value.isBefore(date)) {
          fail('유통기한이 입고 날짜보다 이릅니다');
        } else {
          expiry = value;
        }
      }
    }

    if (!ok || info == null || date == null || qty == null) continue;
    if (noPrice) noPriceCount++;
    if (ignoredExpiry) ignoredExpiryCount++;
    lines.add(
      InboundLine(
        rowNumber: row.number,
        receivedAt: DateTime(date.year, date.month, date.day, 9),
        supplierName: supplierName,
        ingredientName: itemName,
        purchaseQty: qty,
        purchaseUnit: info.purchaseUnit,
        baseUnit: info.baseUnit,
        conversionFactor: info.conversionFactor,
        baseQty: qty * info.conversionFactor,
        unitCost: unitCost,
        expiryDate: expiry,
      ),
    );
  }

  if (errors.isNotEmpty) return ImportValidation(plan: null, errors: errors);
  return ImportValidation(
    plan: ImportPlan(
      newSuppliers: newSuppliers,
      newIngredients: newIngredients,
      inboundLines: lines,
      noPriceCount: noPriceCount,
      ignoredExpiryCount: ignoredExpiryCount,
      restoredPhoneCount: restoredPhoneCount,
    ),
    errors: errors,
  );
}

String _withComma(int n) {
  final s = n.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
    buffer.write(s[i]);
  }
  return buffer.toString();
}
