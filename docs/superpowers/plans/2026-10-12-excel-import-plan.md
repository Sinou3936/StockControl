# 엑셀 업로드 구현 계획

> **에이전트 작업자에게:** 서브에이전트 방식(작업마다 새 구현자 → 독립 검토)으로 진행한다. 단계는 체크박스(`- [ ]`)로 추적한다. **스펙을 먼저 읽는다.**

**목표:** 사장이 앱이 내려주는 `.xlsx` 양식에 거래처·품목·입고를 채워 올리면, 검증과 미리보기를 거쳐 한 번에 등록한다.

**구조:** 순수 도메인(셀 값 → 검증된 계획) → 데이터 계층(양식 만들기, 파일 읽기, 중복 조회, 한 트랜잭션 저장) → 화면(양식 받기, 파일 선택, 미리보기, 올리기)과 사장 전용 메뉴. 저장은 기존 `SupplierDao`/`IngredientDao`/`LotRepository.receiveLot`을 그대로 써서 동기화 큐에 자동으로 쌓인다.

**기술:** Flutter, Riverpod, Drift, `excel` 4.0.6 (읽기 `Excel.decodeBytes`, 쓰기 `Excel.createExcel`), `file_picker` 13.1.0 (`FilePicker.pickFile`, `FilePicker.saveFile`).

**스펙:** `docs/superpowers/specs/2026-10-12-excel-import-design.md`

## 모든 작업에 적용되는 제약

- 새 테이블 없음, `schemaVersion` 그대로, 서버(Supabase) 변경 없음. 생성 코드(`*.g.dart`) 다시 만들 필요 없음.
- 입고 줄 최대 **3,000개**, 화면에 보이는 오류 최대 **50개**, 날짜만 있는 입고는 그날 **09:00(로컬)**, **오늘 이후 날짜는 오류**, **유통기한 관리 빈칸 = 아니오**, 단가 빈칸 = 0, 업로드는 **사장만**.
- 탭 화면은 성공 후에 `Navigator.pop()` 하지 않는다 (CLAUDE.md). 업로드 화면은 푸시되는 화면이지만 성공 후 화면을 비우고 결과를 보여 준다.
- **`flutter test`는 한 번에 하나만.** 항상 `--timeout 60s --reporter expanded`, 출력은 파일로: `flutter test <경로> --timeout 60s --reporter expanded *> $env:TEMP\t.log; Get-Content $env:TEMP\t.log -Tail 25`. 멈추면 `Get-Process dart,flutter_tester | Stop-Process -Force`.
- `testWidgets` 안에서 `await dao.watchAll().first` 금지. 값은 `await db.select(db.table).get()`. 위젯 테스트는 끝에 `await tester.pumpWidget(const SizedBox.shrink()); await tester.pump(const Duration(milliseconds: 1));`. 순수 `test`와 DB `test`에서는 `.first` 가능.
- 테스트에서 `package:drift/drift.dart`를 가져오면서 `isNull`/`isNotNull`을 쓰면 `hide isNotNull, isNull`.
- excel 패키지의 `TextCellValue.value`는 `TextSpan`이다 → `.value.text`.
- 커밋: 작업마다 한 개 이상. `git add`는 경로를 직접 적는다. 메시지는 영어, `-m`을 두 번 (두 번째가 `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`). `dart format`은 건드린 파일에만, 기존 줄이 바뀌면 되돌린다. 한국어가 든 파일 편집은 Edit 도구 (PowerShell `Set-Content` 금지). **푸시하지 않는다.**
- 각 작업의 끝: 해당 테스트 통과 + `flutter analyze lib test` 깨끗. 전체 테스트는 작업 5에서 한다 (시작 시 354개).
- 구현자가 중간에 멈춘 적이 있다. **초록이 되면 바로 커밋**하고, 모자라면 무엇이 빠졌는지 보고에 적는다.
- 보고서 파일 쓰기가 거절되면 최종 메시지에 담는다: RED/GREEN 요약, 변이 결과, 커밋 해시.

## Review Focus

스펙이 암시하지만 작업 테스트가 놓치기 쉬운, 사람이 쓰다가 실제로 부딪힐 입력. 각 줄의 테스트는 그 코드를 가진 작업에 들어 있다.

1. **엑셀 날짜 셀 vs 문자 날짜** — 실제 `.xlsx`로 저장한 날짜 셀(시간 없음/있음)과 `2026-09-29`, `26/09/29` 문자가 같은 날로 읽혀야 한다 (작업 1, 2).
2. **엑셀에 흔히 남는 빈 줄·빈 칸** — 서식만 남은 빈 줄은 건너뛰되 줄 번호 안내가 엑셀 번호와 어긋나지 않아야 한다. 일부 칸만 빈 줄은 오류 (작업 1).
3. **숫자가 문자로 저장된 칸** — `" 5 "`, `"1,000"`은 읽히고 `"5g"`, `"1,5"`, `"abc"`는 조용히 0이 되지 않고 오류다 (작업 1).
4. **이름이 거의 같은 거래처·품목** — 앞뒤 공백은 같은 이름으로, 글자가 다르면 모르는 이름 오류 (새 거래처·품목이 조용히 생기지 않는다) (작업 1, 3).
5. **같은 파일을 두 번 올림, 저장 도중 실패** — 두 번째에 중복 의심이 뜨고, 저장 도중 예외가 나면 거래처·품목까지 전부 되돌려진다 (작업 3).

---

## 파일 구조

| 파일 | 일 |
|---|---|
| `lib/domain/excel_import/excel_import_types.dart` (새) | 시트 이름·머리글 상수, `RawWorkbook`, 오류·계획 모델 |
| `lib/domain/excel_import/cell_parsing.dart` (새) | 셀 값 → 글자/숫자/날짜 읽기 |
| `lib/domain/excel_import/import_validator.dart` (새) | `validateImport` (순수) |
| `lib/data/import/import_template.dart` (새) | 빈 양식 `.xlsx` 만들기 |
| `lib/data/import/import_workbook_reader.dart` (새) | `.xlsx` 바이트 → `RawWorkbook` |
| `lib/data/import/excel_import_service.dart` (새) | 미리보기 준비(검증 + 중복 조회), 한 트랜잭션 저장 |
| `lib/data/import/import_file_gateway.dart` (새) | 양식 저장·파일 선택 (주입 가능) + provider |
| `lib/features/excel_import/excel_import_screen.dart` (새) | 업로드 화면, 미리보기 |
| `lib/core/shell/excel_import_route.dart` (새) | `pushExcelImportScreen` |
| `lib/core/shell/app_shell.dart`, `more_screen.dart` (수정) | 사장 전용 메뉴 |
| `test/domain/excel_import/*`, `test/data/import/*`, `test/features/excel_import/*`, `test/core/shell/*` | 각 작업의 테스트 |

---

## 작업 1: 도메인 — 셀 읽기와 검증 (순수)

**파일:** 새 `lib/domain/excel_import/excel_import_types.dart`, `cell_parsing.dart`, `import_validator.dart`. 새 테스트 `test/domain/excel_import/cell_parsing_test.dart`, `import_validator_test.dart`.

**Interfaces — Produces** (이후 작업이 쓴다):
- `typedef RawSheet = List<List<Object?>>` (첫 줄 머리글, 셀은 `String`/`num`/`DateTime`/`bool`/`null`), `class RawWorkbook({required RawSheet suppliers, required RawSheet ingredients, required RawSheet inbound})`.
- 상수: `kGuideSheet='안내'`, `kSuppliersSheet='거래처'`, `kIngredientsSheet='품목'`, `kInboundSheet='입고'`, `kSupplierHeaders`, `kIngredientHeaders`, `kInboundHeaders`, `kMaxInboundRows=3000`, `kMaxShownErrors=50`.
- `ImportError(sheet, row, message)` + `.text`, `ExistingIngredient({baseUnit, purchaseUnit, conversionFactor, isExpiryTracked})`, `NewSupplier({name, contact})`, `NewIngredient({name, baseUnit, purchaseUnit, conversionFactor, safetyStockQty, isExpiryTracked})`, `InboundLine({rowNumber, receivedAt, supplierName, ingredientName, purchaseQty, purchaseUnit, baseUnit, conversionFactor, baseQty, unitCost, expiryDate})`, `ImportPlan({newSuppliers, newIngredients, inboundLines, noPriceCount, ignoredExpiryCount})` + `firstDate`/`lastDate`, `ImportValidation({plan, errors})` + `isValid`, `shownErrors`, `hiddenErrorCount`.
- `ImportValidation validateImport(RawWorkbook book, {required Set<String> existingSupplierNames, required Map<String, ExistingIngredient> existingIngredients, required DateTime now})`.
- `String cellText(Object?)`, `bool cellIsBlank(Object?)`, `double? cellNumber(Object?)`, `DateTime? cellDate(Object?)`.

**Consumes:** `dayStart(DateTime)` from `lib/domain/stock_by_date.dart`.

- [ ] **1-1. 타입 파일을 만든다** — `lib/domain/excel_import/excel_import_types.dart`:

```dart
import 'dart:math' as math;

/// 시트 하나. 첫 줄이 머리글이고 나머지가 데이터다.
/// 셀 값은 String, num, DateTime, bool, null 중 하나다.
typedef RawSheet = List<List<Object?>>;

const kGuideSheet = '안내';
const kSuppliersSheet = '거래처';
const kIngredientsSheet = '품목';
const kInboundSheet = '입고';

const kSupplierHeaders = ['이름', '연락처'];
const kIngredientHeaders = [
  '품목명',
  '기본 단위',
  '구매 단위',
  '환산계수',
  '안전재고',
  '유통기한 관리',
];
const kInboundHeaders = ['날짜', '거래처', '품목명', '수량', '단가', '유통기한'];

/// 한 번에 올릴 수 있는 입고 줄 수.
const kMaxInboundRows = 3000;

/// 화면에 보여 주는 오류 수 (넘으면 "외 N개").
const kMaxShownErrors = 50;

class RawWorkbook {
  const RawWorkbook({
    required this.suppliers,
    required this.ingredients,
    required this.inbound,
  });

  final RawSheet suppliers;
  final RawSheet ingredients;
  final RawSheet inbound;
}

/// 파일의 한 줄에서 찾은 문제. [row]는 엑셀에서 보이는 줄 번호(머리글이 1).
class ImportError {
  const ImportError(this.sheet, this.row, this.message);

  final String sheet;
  final int row;
  final String message;

  String get text => '$sheet 시트 $row번째 줄: $message';

  @override
  String toString() => text;
}

/// 앱에 이미 등록된 품목 중 검증에 필요한 값.
class ExistingIngredient {
  const ExistingIngredient({
    required this.baseUnit,
    required this.purchaseUnit,
    required this.conversionFactor,
    required this.isExpiryTracked,
  });

  final String baseUnit;
  final String purchaseUnit;
  final double conversionFactor;
  final bool isExpiryTracked;
}

class NewSupplier {
  const NewSupplier({required this.name, this.contact});

  final String name;
  final String? contact;
}

class NewIngredient {
  const NewIngredient({
    required this.name,
    required this.baseUnit,
    required this.purchaseUnit,
    required this.conversionFactor,
    required this.safetyStockQty,
    required this.isExpiryTracked,
  });

  final String name;
  final String baseUnit;
  final String purchaseUnit;
  final double conversionFactor;
  final double? safetyStockQty;
  final bool isExpiryTracked;
}

class InboundLine {
  const InboundLine({
    required this.rowNumber,
    required this.receivedAt,
    required this.supplierName,
    required this.ingredientName,
    required this.purchaseQty,
    required this.purchaseUnit,
    required this.baseUnit,
    required this.conversionFactor,
    required this.baseQty,
    required this.unitCost,
    required this.expiryDate,
  });

  final int rowNumber;

  /// 입고 날짜의 09:00 (로컬).
  final DateTime receivedAt;
  final String supplierName;
  final String ingredientName;

  /// 파일에 적은 수량 (구매 단위).
  final double purchaseQty;
  final String purchaseUnit;
  final String baseUnit;
  final double conversionFactor;

  /// 저장될 수량 = [purchaseQty] × [conversionFactor] (기본 단위).
  final double baseQty;
  final double unitCost;
  final DateTime? expiryDate;
}

/// 검증을 통과한, 저장할 내용.
class ImportPlan {
  const ImportPlan({
    required this.newSuppliers,
    required this.newIngredients,
    required this.inboundLines,
    required this.noPriceCount,
    required this.ignoredExpiryCount,
  });

  final List<NewSupplier> newSuppliers;
  final List<NewIngredient> newIngredients;
  final List<InboundLine> inboundLines;

  /// 단가 칸이 비어 0으로 저장되는 입고 줄 수.
  final int noPriceCount;

  /// 유통기한 관리가 아닌 품목인데 유통기한이 적혀 있어 무시한 줄 수.
  final int ignoredExpiryCount;

  /// 입고 날짜 범위 (자정). 입고가 없으면 null.
  DateTime? get firstDate => _dates(inboundLines).firstOrNull;
  DateTime? get lastDate => _dates(inboundLines).lastOrNull;

  static List<DateTime> _dates(List<InboundLine> lines) {
    final days = {
      for (final l in lines)
        DateTime(l.receivedAt.year, l.receivedAt.month, l.receivedAt.day),
    }.toList()..sort();
    return days;
  }
}

class ImportValidation {
  const ImportValidation({required this.plan, required this.errors});

  /// 오류가 없을 때만 있다.
  final ImportPlan? plan;
  final List<ImportError> errors;

  bool get isValid => errors.isEmpty;

  List<ImportError> get shownErrors => errors.take(kMaxShownErrors).toList();

  int get hiddenErrorCount => math.max(0, errors.length - kMaxShownErrors);
}
```

- [ ] **1-2. 셀 읽기 실패 테스트를 쓴다** — `test/domain/excel_import/cell_parsing_test.dart`. 케이스 (기대값 포함):
  1. `cellText`: `null`→`''`, `'  양파 '`→`'양파'`, `5`→`'5'`, `5.5`→`'5.5'`, `DateTime(2026,9,29)`→`'2026-09-29'`. `cellIsBlank(' ')`는 true, `cellIsBlank(0)`는 false.
  2. `cellNumber`: `5`→5.0, `1.5`→1.5, `' 5 '`→5.0, `'1,000'`→1000.0, `'1,234.5'`→1234.5, `'-3'`→-3.0. 읽을 수 없음(null): `'1,5'`, `'5,'`, `'5g'`, `'abc'`, `''`, `null`, `double.nan`, `double.infinity`, `'Infinity'`.
  3. `cellDate`: `DateTime(2026,9,29,13,30)`→`DateTime(2026,9,29)`, `'2026-09-29'`/`'2026/09/29'`/`'2026.9.9'`→해당 날짜, `'26/09/29'`→`DateTime(2026,9,29)`, `'2026-09-29 00:00:00'`→`DateTime(2026,9,29)`. null: `'2026-02-30'`, `'2026-13-01'`, `'9/29'`, `'abc'`, `'45000'`, `45000`(숫자), `null`, `''`.

- [ ] **1-3. 실패를 확인한다** (`flutter test test/domain/excel_import/cell_parsing_test.dart` — 함수가 없어 컴파일 오류).

- [ ] **1-4. 구현한다** — `lib/domain/excel_import/cell_parsing.dart`:

```dart
/// 셀 값을 앞뒤 공백 없는 글자로. 비어 있으면 ''.
String cellText(Object? cell) {
  if (cell == null) return '';
  if (cell is String) return cell.trim();
  if (cell is DateTime) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${cell.year}-${two(cell.month)}-${two(cell.day)}';
  }
  if (cell is num) {
    return cell == cell.truncateToDouble() && cell.abs() < 1e15
        ? cell.toInt().toString()
        : cell.toString();
  }
  return cell.toString().trim();
}

bool cellIsBlank(Object? cell) => cellText(cell).isEmpty;

final _thousandsGrouped = RegExp(r'^\d{1,3}(,\d{3})+(\.\d+)?$');

/// 숫자 칸을 읽는다. 읽을 수 없으면 null (조용히 0이 되지 않는다).
/// 음수는 그대로 돌려주고 허용 여부는 부르는 쪽이 정한다.
/// 천 단위 쉼표는 올바른 묶음일 때만 받는다 (`1,5`는 15가 아니라 오류).
double? cellNumber(Object? cell) {
  if (cell is num) return cell.isFinite ? cell.toDouble() : null;
  final text = cellText(cell);
  if (text.isEmpty) return null;
  final negative = text.startsWith('-');
  final body = negative ? text.substring(1) : text;
  if (body.contains(',') && !_thousandsGrouped.hasMatch(body)) return null;
  final parsed = double.tryParse(body.replaceAll(',', ''));
  if (parsed == null || !parsed.isFinite) return null;
  return negative ? -parsed : parsed;
}

final _dateText = RegExp(
  r'^(\d{4}|\d{2})[-/.](\d{1,2})[-/.](\d{1,2})(\s+\d{1,2}:\d{2}(:\d{2})?)?$',
);

/// 날짜 칸을 읽는다 (시각은 버리고 로컬 자정). 읽을 수 없으면 null.
/// 두 자리 연도는 20xx. 없는 날짜(2월 30일)는 null.
DateTime? cellDate(Object? cell) {
  if (cell is DateTime) return DateTime(cell.year, cell.month, cell.day);
  final match = _dateText.firstMatch(cellText(cell));
  if (match == null) return null;
  var year = int.parse(match.group(1)!);
  if (match.group(1)!.length == 2) year += 2000;
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}
```

- [ ] **1-5. 통과를 확인한다.**

- [ ] **1-6. 검증 실패 테스트를 쓴다** — `test/domain/excel_import/import_validator_test.dart`. 도우미를 먼저 둔다:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/domain/excel_import/excel_import_types.dart';
import 'package:stockcontrol/domain/excel_import/import_validator.dart';

final now = DateTime(2026, 10, 12, 10, 0);

RawWorkbook book({
  List<List<Object?>> suppliers = const [],
  List<List<Object?>> ingredients = const [],
  List<List<Object?>> inbound = const [],
}) => RawWorkbook(
  suppliers: [kSupplierHeaders, ...suppliers],
  ingredients: [kIngredientHeaders, ...ingredients],
  inbound: [kInboundHeaders, ...inbound],
);

ImportValidation validate(
  RawWorkbook b, {
  Set<String> suppliers = const {},
  Map<String, ExistingIngredient> ingredients = const {},
}) => validateImport(
  b,
  existingSupplierNames: suppliers,
  existingIngredients: ingredients,
  now: now,
);

List<String> texts(ImportValidation v) => v.errors.map((e) => e.text).toList();

/// 품목 시트 한 줄: 쌀, g, 포, 20000, 안전재고 없음, 예(기한 관리)
List<Object?> rice({Object? factor = 20000, Object? tracked = '아니오'}) =>
    ['쌀', 'g', '포', factor, null, tracked];

/// 입고 시트 한 줄.
List<Object?> inboundRow({
  Object? date = '2026-09-29',
  Object? supplier = '다라마상사',
  Object? item = '쌀',
  Object? qty = 2,
  Object? cost = 45000,
  Object? expiry,
}) => [date, supplier, item, qty, cost, expiry];
```

  케이스 (각각 기대값을 단언):
  - **머리글**: 품목 시트에서 `'환산계수'` 머리글을 뺀 줄을 주면 `'품목 시트 1번째 줄: \'환산계수\' 열이 없습니다'` 오류, `plan == null`. 세 시트의 머리글이 다 틀리면 오류 세 개가 한 번에 나온다. 머리글이 틀리면 데이터 줄 검사는 하지 않는다. 열 순서를 바꿔도 통과하고, 모르는 열은 무시한다.
  - **빈 양식**: `book()` → `isValid`, `plan.inboundLines` 비어 있음.
  - **거래처**: 이름이 비면 `'거래처 시트 2번째 줄: 이름이 비어 있습니다'`. 같은 이름이 두 번이면 두 번째 줄에 `'같은 이름이 시트 안에 두 번 있습니다 (2번째 줄과 같음)'` (공백 차이 `'가나다 '`/`'가나다'`도 같은 이름). 이미 등록된 이름이면 `newSuppliers`에 없다. 연락처가 빈칸이면 `contact == null`.
  - **품목**: 정상 줄은 `NewIngredient`로 나온다 (`baseUnit 'g'`, `factor 20000`, `isExpiryTracked false`). 기본 단위 `'G'`는 `'g'`로 읽는다, `'kg'`는 `'기본 단위는 g, ml, ea 중 하나여야 합니다'`. 구매 단위 빈칸, 환산계수 `0`/`-1`/`'abc'`/빈칸은 `'환산계수는 0보다 큰 숫자여야 합니다'`. 안전재고: 빈칸→`null`, `0`→`null`, `5000`→5000, `'abc'`/`-1`→`'안전재고를 숫자로 적어 주세요 (비우면 알림에서 제외)'`. 유통기한 관리: `'예'`→true, `'아니오'`·빈칸→false, `'네'`→`"유통기한 관리는 '예' 또는 '아니오'로 적어 주세요"`. 시트 안 같은 이름은 오류.
  - **기존 품목**: 이름이 같고 단위·환산계수가 같으면 `newIngredients`에 없다 (안전재고·유통기한 관리는 기존 값을 쓴다). 환산계수가 다르면 `'이미 등록된 품목과 기본 단위나 환산계수가 다릅니다 (등록된 값: g, 20000)'`. 기본 단위가 다르면 같은 오류.
  - **입고 정상**: 위 `rice()`가 파일에 있고 `inboundRow()` 한 줄 → `inboundLines.single`의 `receivedAt == DateTime(2026,9,29,9)`, `baseQty == 40000`, `purchaseQty == 2`, `unitCost == 45000`, `noPriceCount == 0`. 거래처 `'다라마상사'`는 거래처 시트에 있거나 `suppliers:`로 넘긴다.
  - **입고 날짜**: 엑셀 날짜 셀(`DateTime(2026,9,29,13,30)`), `'2026-09-29'`, `'26/09/29'`가 모두 `DateTime(2026,9,29,9)`. 빈칸 `'날짜가 비어 있습니다'`, `'abc'` `'날짜를 읽을 수 없습니다 (예: 2026-09-29)'`, 오늘(`2026-10-12`)은 통과, 내일(`2026-10-13`) `'오늘 이후 날짜입니다'`.
  - **입고 거래처·품목**: 빈칸은 오류. 모르는 이름은 `'거래처 "X"가 거래처 시트나 등록된 거래처에 없습니다'` / `'품목 "X"가 품목 시트나 등록된 품목에 없습니다'`. 앞뒤 공백(`' 쌀 '`)은 같은 이름으로 본다. 대소문자·글자가 다르면(`'쌀 '` vs `'쌀2'`) 모르는 이름 오류.
  - **수량**: `0`, `-1`, `'abc'`, 빈칸, `'1,5'`, `1e12` → `'수량은 0보다 큰 숫자여야 합니다'`. `' 5 '`, `'1,000'`, `2.5`는 통과.
  - **단가**: 빈칸 → `unitCost == 0`, `noPriceCount == 1`. `0`은 빈칸이 아니므로 `noPriceCount`에 안 센다. `-1`/`'abc'` → `'단가를 0 이상의 숫자로 적어 주세요 (비우면 0)'`.
  - **유통기한**: 유통기한 관리 품목(`tracked: '예'`)이면 `expiryDate`에 들어간다. 입고 날짜보다 이르면 `'유통기한이 입고 날짜보다 이릅니다'`. 읽을 수 없으면 `'유통기한을 읽을 수 없습니다 (예: 2026-12-31)'`. 유통기한 관리가 아닌 품목에 값이 있으면 오류가 아니고 `expiryDate == null`, `ignoredExpiryCount == 1`.
  - **빈 줄**: 파일 중간에 완전히 빈 줄(`[null, null, null, null, null, null]`)이 끼어도 건너뛰고, 그 뒤 줄의 오류 번호는 엑셀 번호와 같다 (빈 줄이 3번째 줄이면 그 다음 줄은 `4번째 줄`). 일부 칸만 빈 줄은 오류 (예: 수량만 빈 줄).
  - **여러 오류가 한 번에**: 입고 두 줄이 서로 다른 문제를 가지면 오류 두 개가 줄 번호 순으로 나온다 (첫 오류에서 멈추지 않는다).
  - **오류 상한**: 오류가 되는 입고 줄 60개 → `errors.length == 60`, `shownErrors.length == 50`, `hiddenErrorCount == 10`.
  - **줄 수 한도**: 입고 줄 3,001개 → `'입고 시트 1번째 줄: 입고 줄이 3,000개를 넘습니다 (3001개)'` 오류 하나, 줄 검사는 하지 않는다. 3,000개는 통과.
  - **무효 품목 줄을 가리키는 입고**: 품목 시트의 한 줄이 오류(환산계수 0)인데 입고가 그 품목을 쓰면, 입고에 "품목 없음" 오류가 따로 생기지 않는다 (오류는 품목 줄 하나뿐).
  - **날짜 범위**: 입고 날짜가 `9/29`, `9/30`, `9/29`이면 `plan.firstDate == DateTime(2026,9,29)`, `lastDate == DateTime(2026,9,30)`.

- [ ] **1-7. 실패를 확인한다.**

- [ ] **1-8. 구현한다** — `lib/domain/excel_import/import_validator.dart`:

```dart
import '../stock_by_date.dart';
import 'cell_parsing.dart';
import 'excel_import_types.dart';

const _baseUnits = {'g', 'ml', 'ea'};

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

  // ---- 거래처
  final sheetSuppliers = <String, int>{};
  final newSuppliers = <NewSupplier>[];
  for (final row in _dataRows(book.suppliers)) {
    final name = cellText(_at(row.cells, supplierCols['이름']!));
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
    final contact = cellText(_at(row.cells, supplierCols['연락처']!));
    newSuppliers.add(
      NewSupplier(name: name, contact: contact.isEmpty ? null : contact),
    );
  }

  // ---- 품목. 줄이 틀렸어도 이름은 등록해 둔다 (값은 null): 입고 줄에 "품목
  // 없음" 오류가 따로 생겨 같은 문제가 두 번 보이는 것을 막는다.
  final sheetIngredients = <String, _IngredientInfo?>{};
  final newIngredients = <NewIngredient>[];
  for (final row in _dataRows(book.ingredients)) {
    final name = cellText(_at(row.cells, ingredientCols['품목명']!));
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

    final baseUnit = cellText(
      _at(row.cells, ingredientCols['기본 단위']!),
    ).toLowerCase();
    if (!_baseUnits.contains(baseUnit)) fail('기본 단위는 g, ml, ea 중 하나여야 합니다');

    final purchaseUnit = cellText(_at(row.cells, ingredientCols['구매 단위']!));
    if (purchaseUnit.isEmpty) fail('구매 단위가 비어 있습니다');

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
    final supplierName = cellText(_at(row.cells, inboundCols['거래처']!));
    if (supplierName.isEmpty) {
      fail('거래처가 비어 있습니다');
    } else if (!sheetSuppliers.containsKey(supplierName) &&
        !existingSupplierNames.contains(supplierName)) {
      fail('거래처 "$supplierName"가 거래처 시트나 등록된 거래처에 없습니다');
    }

    // 품목
    final itemName = cellText(_at(row.cells, inboundCols['품목명']!));
    _IngredientInfo? info;
    if (itemName.isEmpty) {
      fail('품목명이 비어 있습니다');
    } else if (sheetIngredients.containsKey(itemName)) {
      info = sheetIngredients[itemName];
      // info가 null이면 품목 시트의 그 줄이 이미 오류다. 여기서 또 알리지 않는다.
      if (info == null) ok = false;
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
      final value = cellDate(expiryCell);
      if (value == null) {
        fail('유통기한을 읽을 수 없습니다 (예: 2026-12-31)');
      } else if (date != null && value.isBefore(date)) {
        fail('유통기한이 입고 날짜보다 이릅니다');
      } else if (info != null && !info.isExpiryTracked) {
        ignoredExpiry = true;
      } else {
        expiry = value;
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
```

  메모: `date.isAfter(today)`에서 오늘 이후면 `date = null`로 두어 아래 "유통기한이 입고 날짜보다 이릅니다" 판정이 이미 오류가 난 날짜로 한 번 더 오류를 내지 않게 한다.

- [ ] **1-9. 통과를 확인한다.** 이 작업의 테스트 파일 둘 + `flutter analyze lib test`. 기존 테스트는 영향 없다.

- [ ] **1-10. 변이 확인 후 되돌린다.** (a) 날짜를 09:00이 아니라 00:00으로 → 정상·날짜 테스트 실패. (b) `qty * info.conversionFactor`에서 곱하기 제거 → 정상 테스트 실패. (c) `date.isAfter(today)`를 `date.isAfter(now)`로 → 오늘 통과 케이스는 그대로고 실패 안 할 수 있다 — 실패하면 문서화, 생존하면 `now` 시각을 정오 이후로 바꿔 보고 보고. (d) 이미 있는 품목 불일치 검사 제거 → 기존 품목 테스트 실패. (e) 완전히 빈 줄을 건너뛰지 않기 → 빈 줄 테스트 실패. (f) `_dataRows`의 `number: i + 1`을 `i`로 → 줄 번호 테스트 실패. (g) `qty > 1e9` 검사 제거 → `1e12` 테스트 실패. (h) 오류를 `continue`로 첫 줄에서 멈추기 → "여러 오류가 한 번에" 실패. (i) 쉼표 검사(`!_thousandsGrouped.hasMatch`) 제거 → `'1,5'` 테스트 실패. (j) 유통기한 관리 빈칸을 `true`로 → 빈칸 케이스 실패.

- [ ] **1-11. 커밋.**
```
git add lib/domain/excel_import test/domain/excel_import
git commit -m "feat: add the Excel import cell parsing and validation rules" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## 작업 2: 양식 만들기와 `.xlsx` 읽기

**파일:** 새 `lib/data/import/import_template.dart`, `import_workbook_reader.dart`. 새 테스트 `test/data/import/import_template_test.dart`, `import_workbook_reader_test.dart`.

**Interfaces — Consumes:** 작업 1의 `RawWorkbook`, `kGuideSheet`, `kSuppliersSheet`, `kIngredientsSheet`, `kInboundSheet`, `kSupplierHeaders`, `kIngredientHeaders`, `kInboundHeaders`.
**Produces:** `Uint8List buildImportTemplateXlsx()`, `const importTemplateFileName = '재고관리_업로드_양식.xlsx'`, `RawWorkbook readImportWorkbook(Uint8List bytes)`, `class ImportFileException implements Exception { const ImportFileException(this.message); final String message; }`.

- [ ] **2-1. 실패하는 테스트를 쓴다.**
  - `import_template_test.dart`: (1) `Excel.decodeBytes(buildImportTemplateXlsx())`의 `tables.keys.toList()`가 `['안내', '거래처', '품목', '입고']` 순서다. (2) 거래처·품목·입고 시트의 **첫 줄**이 각각 `kSupplierHeaders` 등과 같고(`cell.value`를 `TextCellValue`의 `.value.text`로 읽는다) **둘째 줄은 비어 있다** (예시는 안내 시트에만). (3) 안내 시트에 `'환산계수'`가 들어 있는 줄이 있다.
  - `import_workbook_reader_test.dart` (테스트 안에서 `Excel.createExcel()`로 파일을 만들어 `encode()`한 바이트를 읽는다):
    1. 양식 그대로 `readImportWorkbook(buildImportTemplateXlsx())` → 세 시트 모두 첫 줄이 머리글이고 줄이 하나뿐. 그리고 `validateImport`(작업 1)에 넣으면 `isValid`.
    2. 값을 채운 파일: 텍스트 셀 `'쌀'`→`'쌀'`, 정수 셀 `2`→`2`(`num`), 소수 셀 `1.5`→`1.5`, **날짜 셀** `DateCellValue(year: 2026, month: 9, day: 29)`→`DateTime(2026,9,29)`, **날짜+시간 셀** `DateTimeCellValue(year: 2026, month: 9, day: 29, hour: 13, minute: 30)`→`DateTime(2026,9,29,13,30)`, 불리언 셀→`bool`, 빈 칸→`null`. 날짜 셀을 `validateImport`에 통과시키면 같은 날 09:00으로 나온다.
    3. 수식 셀(`FormulaCellValue('1+1')`)은 `'=1+1'` 글자로 읽는다 (조용히 빈칸이 되지 않는다).
    4. 시트가 빠진 파일(거래처만 있는 파일) → `ImportFileException`, 메시지에 `'품목'`과 `'입고'`가 들어 있다. 엑셀이 아닌 바이트(`Uint8List.fromList([1,2,3])`) → `ImportFileException('엑셀 파일(.xlsx)을 읽을 수 없습니다 …')`.
    5. 뒤쪽 빈 줄이 있어도 줄 번호가 유지된다: 3번째 줄만 비워 둔 파일을 읽어 `validateImport`에 넣었을 때 4번째 줄의 오류가 `4번째 줄`로 나온다.

- [ ] **2-2. 실패를 확인한다.**

- [ ] **2-3. 구현한다.**

`lib/data/import/import_template.dart` (발주서 엑셀 `purchase_order_xlsx.dart`와 같은 방식):

```dart
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
    '',
    '입고 시트 예시',
  ];
  for (final line in lines) {
    guide.appendRow([TextCellValue(line)]);
  }
  guide.appendRow([for (final h in kInboundHeaders) TextCellValue(h)]);
  guide.appendRow([
    TextCellValue('2026-09-29'),
    TextCellValue('다라마상사'),
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
```

`lib/data/import/import_workbook_reader.dart`:

```dart
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../domain/excel_import/excel_import_types.dart';

class ImportFileException implements Exception {
  const ImportFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

Object? _value(CellValue? v) => switch (v) {
  null => null,
  TextCellValue() => v.value.text ?? '',
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
  _ => null,
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
  } catch (_) {
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
    throw ImportFileException(
      '${missing.join(', ')} 시트가 없습니다. 앱에서 받은 양식을 그대로 써 주세요.',
    );
  }

  return RawWorkbook(
    suppliers: _sheet(excel, kSuppliersSheet),
    ingredients: _sheet(excel, kIngredientsSheet),
    inbound: _sheet(excel, kInboundSheet),
  );
}
```

  메모: 패키지 버전에 따라 `sheet.rows`의 칸이 `Data?`다 (`cell?.value`가 `CellValue?`). 컴파일 오류가 나면 `lib/src/sheet/data_model.dart`의 실제 시그니처에 맞추고 보고한다. `TextSpan.text`는 `String?`이다.

- [ ] **2-4. 통과를 확인한다.** 이 작업 테스트 파일 둘 + 작업 1 테스트 + analyze.

- [ ] **2-5. 변이 확인 후 되돌린다.** (a) 날짜 셀을 `DateTime(v.year, v.month, v.day + 1)`로 → 날짜 셀 테스트 실패. (b) 수식 셀을 `null`로 → 수식 테스트 실패. (c) 시트 이름을 `'입고'`에서 `'입고 '`로(양식) → 양식 시트 이름 테스트·왕복 테스트 실패. (d) 빠진 시트 검사 제거 → 시트 누락 테스트(`tables[name]!` null 오류로 실패). (e) 양식에 데이터 시트의 둘째 줄로 예시를 넣기 → "둘째 줄은 비어 있다" 테스트 실패.

- [ ] **2-6. 커밋.**
```
git add lib/data/import/import_template.dart lib/data/import/import_workbook_reader.dart test/data/import
git commit -m "feat: build the Excel import template and read uploaded workbooks" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## 작업 3: 미리보기 준비와 한 트랜잭션 저장

**파일:** 새 `lib/data/import/excel_import_service.dart`. 새 테스트 `test/data/import/excel_import_service_test.dart`.

**Interfaces — Consumes:** 작업 1(`validateImport`, `ImportPlan`, `ImportValidation`, `ExistingIngredient`, `InboundLine`), 작업 2(`readImportWorkbook`, `ImportFileException`), `AppDatabase`(`supplierDao.insertSupplier`, `ingredientDao.insertIngredient`), `LotRepository.receiveLot` (`lib/data/repositories/lot_repository.dart`), `dayEnd`/`isSameDay`(`lib/domain/stock_by_date.dart`).
**Produces:**
```dart
class DuplicateCandidate {
  const DuplicateCandidate({required this.rowNumber, required this.ingredientName, required this.supplierName, required this.receivedAt, required this.baseQty, required this.unitCost});
  final int rowNumber; final String ingredientName; final String supplierName;
  final DateTime receivedAt; final double baseQty; final double unitCost;
}
class ImportPreview { const ImportPreview({required this.validation, required this.duplicates}); final ImportValidation validation; final List<DuplicateCandidate> duplicates; }
class ImportCommitResult { const ImportCommitResult({required this.newSuppliers, required this.newIngredients, required this.inboundCount, required this.firstDate, required this.lastDate}); final int newSuppliers; final int newIngredients; final int inboundCount; final DateTime? firstDate; final DateTime? lastDate; }
class ExcelImportService {
  ExcelImportService(AppDatabase db);
  Future<ImportPreview> prepare({required Uint8List bytes, required String storeId, DateTime? now});  // ImportFileException을 던질 수 있다
  Future<ImportCommitResult> commit({required ImportPlan plan, required String storeId});
}
final excelImportServiceProvider = Provider<ExcelImportService>((ref) => ExcelImportService(ref.watch(appDatabaseProvider)));
```

- [ ] **3-1. 실패하는 테스트를 쓴다** — `test/data/import/excel_import_service_test.dart`. 도우미: 메모리 DB(`AppDatabase(NativeDatabase.memory())`, `addTearDown(db.close)`), 매장 한 개(`db.storeDao.upsertStore(StoresCompanion.insert(id: 'a', name: '울산점'))`), 파일 바이트를 만드는 함수 `Uint8List xlsx({suppliers, ingredients, inbound})` (테스트 안에서 `Excel.createExcel()`로 세 시트에 머리글 + 줄을 `TextCellValue`/`IntCellValue`/`DateCellValue`로 써서 `encode()`; 도우미는 한 번만 만들고 모든 케이스가 쓴다). 이 테스트는 일반 `test`라서 `.first`를 써도 된다. 케이스:
  1. **정상 저장**: 새 거래처 `다라마상사`, 새 품목 `쌀`(g, 포, 20000, 기한 관리 아니오), 입고 `2026-09-29`, 수량 2, 단가 45000. `prepare` → `validation.isValid`, `duplicates` 비어 있음. `commit` 후 DB: 거래처 1개, 품목 1개(`conversionFactor 20000`), 로트 1개(`storeId 'a'`, `unitCost 45000`, `receivedDate == DateTime(2026,9,29,9)`, `remainingQty 40000`), 입고 기록 1개(`type 'inbound'`, `quantity 40000`, `occurredAt == DateTime(2026,9,29,9)`). `ImportCommitResult`의 개수가 맞다.
  2. **재고 합계**: 위 업로드 뒤 `db.stockMovementDao`의 지난 날짜 재고(`watchStockAsOf(DateTime(2026,9,30), storeId: 'a').first`)가 40000 g 한 줄이다 (지난 날짜 조회와 이어짐).
  3. **이미 있는 거래처·품목은 새로 만들지 않는다**: 거래처 `다라마상사`와 품목 `쌀`(같은 단위·환산계수)을 DAO로 먼저 등록하고 같은 파일을 올리면 거래처·품목 수가 그대로 1개이고 로트만 생긴다. 파일의 거래처 시트·품목 시트를 **비워 두고** 입고 시트만 채워도(기존 이름 참조) 통과한다.
  4. **기존 품목과 환산계수가 다르면** `prepare`의 `validation.isValid`가 false이고 `commit`은 호출하지 않는다 (오류 메시지에 `환산계수` 포함).
  5. **중복 의심**: 같은 파일을 `commit`한 뒤 다시 `prepare`하면 `duplicates.single`의 `ingredientName == '쌀'`, `rowNumber == 2`. 다음 중 하나라도 다르면 중복이 아니다 (각각 한 케이스): 매장(`storeId 'b'`로 prepare), 날짜(`2026-09-28`), 수량(3), 단가(46000), 거래처(다른 거래처), 품목(다른 품목). 파일 안에서 같은 줄이 두 번 있어도 `duplicates`는 비어 있다 (둘 다 새로 올리는 것).
  6. **전부 아니면 전무**: 계획을 직접 만들어 `commit`에 넘긴다 — 새 거래처 1개, 새 품목 1개, 입고 줄 2개 중 둘째 줄의 `ingredientName`이 계획에도 DB에도 없는 이름. `commit`이 예외(`StateError`)를 던지고, 그 뒤 DB에 거래처·품목·로트·입고 기록이 **하나도 없다** (이미 만든 거래처·품목까지 되돌려짐).
  7. **동기화 큐**: 정상 저장 뒤 `db.select(db.syncQueue).get()`에 `suppliers`, `ingredients`, `lots`, `stock_movements` 대상이 각각 1개 이상 있다.
  8. **큰 파일**: 입고 줄 300개(품목 5개, 날짜 10일)를 `prepare` → `commit`: 로트 300개, 입고 기록 300개.
  9. **오류 파일은 DB를 건드리지 않는다**: 모르는 거래처가 있는 파일을 `prepare`만 해도 DB 행 수가 그대로다.
  10. **엑셀이 아닌 바이트**는 `prepare`가 `ImportFileException`을 던진다.
  11. **기한 관리 품목**: 품목 `우유`(기한 관리 예) 입고에 유통기한 `2026-10-05`를 적으면 로트의 `expiryDate == DateTime(2026,10,5)`. 기한 관리가 아닌 품목에 유통기한을 적으면 로트의 `expiryDate`가 null.

- [ ] **3-2. 실패를 확인한다.**

- [ ] **3-3. 구현한다** — `lib/data/import/excel_import_service.dart`:

```dart
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_provider.dart';
import '../../domain/excel_import/excel_import_types.dart';
import '../../domain/excel_import/import_validator.dart';
import '../../domain/stock_by_date.dart';
import '../local/database.dart';
import '../repositories/lot_repository.dart';
import 'import_workbook_reader.dart';

class DuplicateCandidate {
  const DuplicateCandidate({
    required this.rowNumber,
    required this.ingredientName,
    required this.supplierName,
    required this.receivedAt,
    required this.baseQty,
    required this.unitCost,
  });

  final int rowNumber;
  final String ingredientName;
  final String supplierName;
  final DateTime receivedAt;
  final double baseQty;
  final double unitCost;
}

class ImportPreview {
  const ImportPreview({required this.validation, required this.duplicates});

  final ImportValidation validation;

  /// 저장하려는 입고와 모든 값이 같은 입고가 이미 있는 줄.
  final List<DuplicateCandidate> duplicates;
}

class ImportCommitResult {
  const ImportCommitResult({
    required this.newSuppliers,
    required this.newIngredients,
    required this.inboundCount,
    required this.firstDate,
    required this.lastDate,
  });

  final int newSuppliers;
  final int newIngredients;
  final int inboundCount;
  final DateTime? firstDate;
  final DateTime? lastDate;
}

class ExcelImportService {
  ExcelImportService(this._db);

  final AppDatabase _db;

  /// 파일을 읽어 검증하고, 오류가 없으면 기존 입고와 겹치는 줄을 찾는다.
  /// 엑셀 파일이 아니거나 시트가 없으면 [ImportFileException]. DB는 바꾸지 않는다.
  Future<ImportPreview> prepare({
    required Uint8List bytes,
    required String storeId,
    DateTime? now,
  }) async {
    final book = readImportWorkbook(bytes);
    final suppliers = await _db.select(_db.suppliers).get();
    final ingredients = await _db.select(_db.ingredients).get();

    final existingIngredients = <String, ExistingIngredient>{};
    for (final i in ingredients) {
      existingIngredients.putIfAbsent(
        i.name,
        () => ExistingIngredient(
          baseUnit: i.baseUnit,
          purchaseUnit: i.purchaseUnit,
          conversionFactor: i.conversionFactor,
          isExpiryTracked: i.isExpiryTracked,
        ),
      );
    }

    final validation = validateImport(
      book,
      existingSupplierNames: {for (final s in suppliers) s.name},
      existingIngredients: existingIngredients,
      now: now ?? DateTime.now(),
    );
    final plan = validation.plan;
    if (plan == null) {
      return ImportPreview(validation: validation, duplicates: const []);
    }
    final duplicates = await _findDuplicates(
      plan,
      storeId,
      suppliers,
      ingredients,
    );
    return ImportPreview(validation: validation, duplicates: duplicates);
  }

  Future<List<DuplicateCandidate>> _findDuplicates(
    ImportPlan plan,
    String storeId,
    List<Supplier> suppliers,
    List<Ingredient> ingredients,
  ) async {
    final first = plan.firstDate;
    final last = plan.lastDate;
    if (first == null || last == null) return const [];

    final supplierIds = <String, int>{};
    for (final s in suppliers) {
      supplierIds.putIfAbsent(s.name, () => s.id);
    }
    final ingredientIds = <String, int>{};
    for (final i in ingredients) {
      ingredientIds.putIfAbsent(i.name, () => i.id);
    }

    final lots = await (_db.select(_db.lots)
          ..where(
            (l) =>
                l.storeId.equals(storeId) &
                l.receivedDate.isBetweenValues(first, dayEnd(last)),
          ))
        .get();
    if (lots.isEmpty) return const [];

    final movements = await (_db.select(_db.stockMovements)
          ..where(
            (m) => m.lotId.isIn([for (final l in lots) l.id]) &
                m.type.equals('inbound'),
          ))
        .get();
    final inboundQty = <int, double>{};
    for (final m in movements) {
      inboundQty.putIfAbsent(m.lotId, () => m.quantity);
    }

    final duplicates = <DuplicateCandidate>[];
    for (final line in plan.inboundLines) {
      final supplierId = supplierIds[line.supplierName];
      final ingredientId = ingredientIds[line.ingredientName];
      // 새 거래처나 새 품목이 걸린 줄은 기존 입고가 있을 수 없다.
      if (supplierId == null || ingredientId == null) continue;
      final found = lots.any(
        (l) =>
            l.supplierId == supplierId &&
            l.ingredientId == ingredientId &&
            isSameDay(l.receivedDate, line.receivedAt) &&
            (l.unitCost - line.unitCost).abs() < 1e-9 &&
            ((inboundQty[l.id] ?? double.nan) - line.baseQty).abs() < 1e-6,
      );
      if (found) {
        duplicates.add(
          DuplicateCandidate(
            rowNumber: line.rowNumber,
            ingredientName: line.ingredientName,
            supplierName: line.supplierName,
            receivedAt: line.receivedAt,
            baseQty: line.baseQty,
            unitCost: line.unitCost,
          ),
        );
      }
    }
    return duplicates;
  }

  /// 계획을 한 트랜잭션으로 저장한다. 하나라도 실패하면 아무것도 남지 않는다.
  Future<ImportCommitResult> commit({
    required ImportPlan plan,
    required String storeId,
  }) {
    return _db.transaction(() async {
      final supplierIds = <String, int>{};
      for (final s in await _db.select(_db.suppliers).get()) {
        supplierIds.putIfAbsent(s.name, () => s.id);
      }
      final ingredientIds = <String, int>{};
      for (final i in await _db.select(_db.ingredients).get()) {
        ingredientIds.putIfAbsent(i.name, () => i.id);
      }

      for (final s in plan.newSuppliers) {
        supplierIds[s.name] = await _db.supplierDao.insertSupplier(
          SuppliersCompanion.insert(name: s.name, contact: Value(s.contact)),
        );
      }
      for (final i in plan.newIngredients) {
        ingredientIds[i.name] = await _db.ingredientDao.insertIngredient(
          IngredientsCompanion.insert(
            name: i.name,
            baseUnit: i.baseUnit,
            purchaseUnit: i.purchaseUnit,
            conversionFactor: i.conversionFactor,
            isExpiryTracked: i.isExpiryTracked,
            safetyStockQty: Value(i.safetyStockQty),
          ),
        );
      }

      final lots = LotRepository(_db);
      for (final line in plan.inboundLines) {
        final supplierId = supplierIds[line.supplierName];
        final ingredientId = ingredientIds[line.ingredientName];
        if (supplierId == null || ingredientId == null) {
          throw StateError(
            '업로드 계획이 현재 데이터와 맞지 않습니다 (${line.rowNumber}번째 줄)',
          );
        }
        await lots.receiveLot(
          ingredientId: ingredientId,
          supplierId: supplierId,
          storeId: storeId,
          receivedDate: line.receivedAt,
          expiryDate: line.expiryDate,
          unitCost: line.unitCost,
          baseQty: line.baseQty,
        );
      }

      return ImportCommitResult(
        newSuppliers: plan.newSuppliers.length,
        newIngredients: plan.newIngredients.length,
        inboundCount: plan.inboundLines.length,
        firstDate: plan.firstDate,
        lastDate: plan.lastDate,
      );
    });
  }
}

final excelImportServiceProvider = Provider<ExcelImportService>(
  (ref) => ExcelImportService(ref.watch(appDatabaseProvider)),
);
```

  메모: `isSameDay`가 `lib/domain/stock_by_date.dart`에 있는지 확인한다 (날짜 선택 기능에서 만든 함수). 시그니처가 다르면 맞춘다. 중첩 트랜잭션(`receiveLot` 안의 `_db.transaction`)은 `submitCountCorrections`가 이미 같은 방식이라 바깥 트랜잭션에 합쳐진다. 케이스 6이 실제로 되돌려지는지로 확인한다.

- [ ] **3-4. 통과를 확인한다.** 이 작업 테스트 + 작업 1·2 테스트 + analyze.

- [ ] **3-5. 변이 확인 후 되돌린다.** (a) `commit`에서 `_db.transaction`을 빼고 본문만 실행 → 케이스 6(전부 아니면 전무) 실패. (b) `baseQty` 대신 `purchaseQty` 저장 → 케이스 1·2 실패. (c) 중복 비교에서 `storeId` 조건 제거 → 매장 다른 케이스 실패. (d) 중복 비교에서 단가 조건 제거 → 단가 다른 케이스 실패. (e) 중복 비교에서 날짜 조건 제거 → 날짜 다른 케이스 실패. (f) 기존 거래처를 `putIfAbsent` 대신 항상 새로 만들기 → 케이스 3 실패. (g) `receivedDate`를 `DateTime.now()`로 → 케이스 1·2 실패. (h) 파일 안 같은 줄끼리도 중복으로 세기 → 파일 내 중복 케이스 실패.

- [ ] **3-6. 커밋.**
```
git add lib/data/import/excel_import_service.dart test/data/import/excel_import_service_test.dart
git commit -m "feat: prepare Excel imports with duplicate detection and save them in one transaction" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## 작업 4: 화면과 사장 전용 메뉴

**파일:** 새 `lib/data/import/import_file_gateway.dart`, `lib/features/excel_import/excel_import_screen.dart`, `lib/core/shell/excel_import_route.dart`. 수정 `lib/core/shell/app_shell.dart`, `lib/core/shell/more_screen.dart`. 새 테스트 `test/features/excel_import/excel_import_screen_test.dart`, `test/core/shell/excel_import_menu_test.dart` (기존 `app_shell` 테스트 파일이 있으면 그 규칙·도우미를 따른다 — `Glob test/core/shell/*`로 먼저 확인).

**Interfaces — Consumes:** 작업 2의 `buildImportTemplateXlsx`, `importTemplateFileName`, `ImportFileException`; 작업 3의 `ExcelImportService`, `ImportPreview`, `ImportCommitResult`, `excelImportServiceProvider`; `activeStoreIdProvider`(`lib/core/providers/store_providers.dart`), `StoreSwitcher`(`lib/features/stock/store_switcher.dart`), `authSessionProvider`, `formatQty`(`lib/core/format/quantity_format.dart`), `EmptyState`/`CenteredContent`/`AppCard`/`InlineError`(`lib/core/widgets/app_widgets.dart`), `savedDisplayText`(`lib/data/export/purchase_order_exporter.dart`).
**Produces:**
```dart
abstract class ImportFileGateway {
  /// 양식을 저장한다. 저장했으면 화면에 보여 줄 문구, 취소했으면 null.
  Future<String?> saveTemplate(Uint8List bytes);
  /// 엑셀 파일을 고른다. 취소했으면 null.
  Future<Uint8List?> pickWorkbook();
}
final importFileGatewayProvider = Provider<ImportFileGateway>((ref) => FilePickerImportFileGateway());
class ExcelImportScreen extends ConsumerStatefulWidget { const ExcelImportScreen({super.key}); }
void pushExcelImportScreen(BuildContext context);
```
키: `templateButton`, `pickFileButton`, `previewSummary`, `errorList`, `duplicateList`, `duplicateConfirm`(체크박스), `commitButton`, `anotherFileButton`, `resultCard`.

- [ ] **4-1. 파일 게이트웨이를 만든다** — `lib/data/import/import_file_gateway.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../export/purchase_order_exporter.dart' show savedDisplayText;
import 'import_template.dart';

/// 양식 저장과 엑셀 파일 선택. 화면과 테스트는 이 인터페이스만 안다.
abstract class ImportFileGateway {
  Future<String?> saveTemplate(Uint8List bytes);
  Future<Uint8List?> pickWorkbook();
}

class FilePickerImportFileGateway implements ImportFileGateway {
  @override
  Future<String?> saveTemplate(Uint8List bytes) async {
    final saved = await FilePicker.saveFile(
      fileName: importTemplateFileName,
      bytes: bytes,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      dialogTitle: '업로드 양식 저장',
    );
    return savedDisplayText(saved, importTemplateFileName);
  }

  @override
  Future<Uint8List?> pickWorkbook() async {
    final file = await FilePicker.pickFile(
      dialogTitle: '엑셀 파일 선택',
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
    if (file == null) return null;
    final bytes = file.bytes;
    if (bytes != null) return bytes;
    final path = file.path;
    return path == null ? null : File(path).readAsBytes();
  }
}

final importFileGatewayProvider = Provider<ImportFileGateway>(
  (ref) => FilePickerImportFileGateway(),
);
```
  메모: `FilePicker.pickFile`에 `withData` 인자가 없다. Windows/Android에서는 `path`로 읽는다. 컴파일 오류가 나면 패키지 실제 시그니처(`lib/src/file_picker.dart` 67행)에 맞춘다.

- [ ] **4-2. 실패하는 화면 테스트를 쓴다** — `test/features/excel_import/excel_import_screen_test.dart`. `purchase_order_screen_test.dart`처럼 `ProviderScope`에 `appDatabaseProvider.overrideWithValue(db)`, `importFileGatewayProvider.overrideWithValue(FakeGateway())`, 사장 세션(`authSessionProvider.overrideWith((ref) => AuthSessionNotifier()..setSession(...))`)과 `selectedStoreProvider.overrideWith((ref) => const Store(id: 'a', name: '울산점'))`를 넣는다 (세션·매장 override 방법은 `stock_overview_screen_test.dart`의 `pumpAs`를 따른다). `FakeGateway`: `savedTemplates`(받은 바이트 기록), `saveResult = '저장위치/양식.xlsx'`, `nextFile`(고를 파일 바이트, 기본 null=취소). 파일 바이트는 작업 3 테스트의 `xlsx(...)` 도우미를 `test/support/import_test_files.dart`로 옮겨 공유한다. 케이스:
  1. **양식 받기**: `templateButton`을 누르면 게이트웨이가 바이트를 받고(`Excel.decodeBytes`로 시트 네 개 확인), 화면에 저장 위치 안내가 나온다. 저장 창을 취소하면(`saveResult = null`) 안내가 나오지 않는다.
  2. **매장 선택 전**: 매장을 고르지 않은 사장(`selectedStoreProvider` null) → `'매장을 선택해주세요'` 안내가 나오고 `pickFileButton`이 없다.
  3. **정상 파일**: `nextFile = xlsx(정상)`, `pickFileButton` → 미리보기. `previewSummary` 안에 `'새 거래처 1'`, `'새 품목 1'`, `'입고 1건'`, `'단가 없음 0건'`이 있고, 입고 줄 예시 `'쌀 20KG · 2포 × 20,000 = 40,000g'` 형태가 보인다. `commitButton`이 있고 `errorList`는 없다.
  4. **올리기**: `commitButton`을 누르면 DB에 로트가 생기고(`await db.select(db.lots).get()`), `resultCard`에 `'입고 1건'`이 나온다. 화면이 닫히지 않고 파일 선택 상태로 돌아간다 (`pickFileButton`이 다시 보인다).
  5. **오류 파일**: 모르는 거래처가 있는 파일 → `errorList`에 `'입고 시트 2번째 줄: 거래처 "…"가 거래처 시트나 등록된 거래처에 없습니다'`가 보이고 `commitButton`이 **없다**. `anotherFileButton`을 누르면 파일 선택 상태로 돌아간다. 오류가 55개이면 `'외 5개'`가 보인다.
  6. **중복 의심**: 같은 파일을 한 번 올린 뒤 다시 고르면 `duplicateList`가 보이고, `commitButton`은 `duplicateConfirm`을 체크하기 전에는 비활성(`onPressed == null`), 체크하면 활성이다.
  7. **엑셀이 아닌 파일**: `nextFile = Uint8List.fromList([1,2,3])` → `'엑셀 파일(.xlsx)을 읽을 수 없습니다'`가 보이고 미리보기는 없다.
  8. **파일 선택 취소**: `nextFile = null` → 아무 변화 없음.
  9. **단가 없음·유통기한 무시 알림**: 단가 빈칸 한 줄 → `'단가 없음 1건'`, 기한 관리 아닌 품목에 유통기한을 적은 줄 → `'유통기한 무시 1건'`.
  10. **폭 320** (`tester.view.physicalSize = Size(320, 800)`, 실제 테마 `AppTheme.light()`): 긴 품목명·긴 오류 메시지가 든 미리보기에서 예외 없음.
  - `excel_import_menu_test.dart`: (a) 데스크톱 폭(900)에서 사장은 내비게이션 레일에 `'엑셀 업로드'`가 보이고, 눌러서 `ExcelImportScreen`이 열린다. 직원 세션에는 `'엑셀 업로드'`가 없다. (b) 폰 폭(390)에서 더보기 화면에 사장은 `'엑셀 업로드'` 타일이 있고 직원은 없다.

- [ ] **4-3. 실패를 확인한다.**

- [ ] **4-4. 구현한다.**

`lib/core/shell/excel_import_route.dart`:
```dart
import 'package:flutter/material.dart';

import '../../features/excel_import/excel_import_screen.dart';

void pushExcelImportScreen(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const ExcelImportScreen()),
  );
}
```

`app_shell.dart`: 사장 전용 destination을 **맨 뒤에** 더한다 (인덱스 8). `onDestinationSelected`에 `if (isOwner && index == 8) { pushExcelImportScreen(context); return; }`를 `index == 7` 처리 아래에 두고, `destinations` 끝(매장 관리 다음)에 `if (isOwner) const NavigationRailDestination(icon: Icon(Icons.upload_file_outlined), label: Text('엑셀 업로드'))`. `more_screen.dart`: 사장 전용 `_MenuTile(icon: Icons.upload_file_outlined, title: '엑셀 업로드', onTap: () => pushExcelImportScreen(context))`를 `직원 추가` 다음에 `if (isOwner)`로. 두 파일 모두 `excel_import_route.dart`를 import한다.

`lib/features/excel_import/excel_import_screen.dart`: `ConsumerStatefulWidget`. 상태: `_phase`(`idle`/`preview`), `_preview`(`ImportPreview?`), `_bytes`, `_templateMessage`, `_resultMessage`, `_fileError`, `_confirmedDuplicates`, `_busy`. 구조:
  - `Scaffold(appBar: AppBar(title: const Text('엑셀 업로드'), actions: const [StoreSwitcher()]))`. 본문은 `ref.watch(activeStoreIdProvider)`가 null이면 `EmptyState(icon: Icons.upload_file_outlined, title: '매장을 선택해주세요', message: '오른쪽 위에서 업로드할 매장을 고르세요')` (입고 등록 화면과 같은 규칙).
  - `idle`: `AppCard` 하나에 설명(`'양식을 받아 거래처, 품목, 입고를 채운 뒤 올려 주세요. 파일 하나는 매장 하나입니다.'`), `OutlinedButton.icon(key: templateButton, '양식 받기')`, 저장 위치 안내(`_templateMessage`), `FilledButton.icon(key: pickFileButton, '파일 선택')`. 결과(`_resultMessage`)가 있으면 `resultCard`, `_fileError`가 있으면 `InlineError`.
  - `양식 받기`: `final bytes = buildImportTemplateXlsx(); final shown = await gateway.saveTemplate(bytes); if (!mounted) return; setState(() => _templateMessage = shown == null ? null : '저장했습니다: $shown');`
  - `파일 선택`: `_busy` 동안 중복 탭 방지. `bytes = await gateway.pickWorkbook()`; null이면 반환. `try { preview = await service.prepare(bytes: bytes, storeId: storeId); } on ImportFileException catch (e) { _fileError = e.message; return; }`. 성공하면 `_phase = preview`, `_preview = preview`, `_bytes`는 저장하지 않는다 (`validation.plan`을 쓴다), `_confirmedDuplicates = false`, `_resultMessage = null`, `_fileError = null`.
  - `preview`: 오류가 있으면 `errorList`(오류 `shownErrors`의 `.text`를 줄마다, `hiddenErrorCount > 0`이면 `'외 $hiddenErrorCount개'`)와 `anotherFileButton`만. 오류가 없으면 `previewSummary`(`'새 거래처 N'`, `'새 품목 N'`, `'입고 N건'`, `'단가 없음 N건'`, 유통기한 무시가 있으면 `'유통기한 무시 N건'`, 입고 날짜 범위 `'2026-09-29 ~ 2026-09-30'`), 입고 줄 앞쪽 10줄 `'${line.ingredientName} · ${formatQty(line.purchaseQty)}${line.purchaseUnit} × ${formatQty(line.conversionFactor)} = ${formatQty(line.baseQty)}${line.baseUnit}'` (더 있으면 `'외 N건'`), 중복이 있으면 `duplicateList`(줄 번호 + 품목 + 날짜 + 수량)와 `CheckboxListTile(key: duplicateConfirm, title: Text('알고 있습니다. 그래도 올리기'))`, `FilledButton(key: commitButton, onPressed: (중복 없음 또는 체크함) && !_busy ? _commit : null, child: Text('올리기'))`, `anotherFileButton`.
  - `_commit`: `final result = await service.commit(plan: _preview!.validation.plan!, storeId: storeId)`; 성공하면 `_phase = idle`, `_preview = null`, `_resultMessage = '거래처 ${result.newSuppliers}, 품목 ${result.newIngredients}, 입고 ${result.inboundCount}건을 등록했습니다'` + 날짜 범위 + `ScaffoldMessenger`로 SnackBar. **`Navigator.pop()` 하지 않는다.** 예외가 나면(`catch (e)`) `_fileError = '저장하지 못했습니다: $e'`로 보여 주고 아무것도 저장되지 않았다고 안내한다.
  - 콘텐츠는 `CenteredContent`로 감싸고 `ListView`(패딩 16)로 스크롤된다.

- [ ] **4-5. 통과를 확인한다.** 이 작업 테스트 + analyze + 기존 `app_shell`/`more_screen` 테스트(있다면)가 수정 없이 통과한다. 기존 테스트가 깨지면 **원인을 보고**하고, 낡은 기대(예: 내비게이션 항목 수를 세는 단정)만 고친다.

- [ ] **4-6. 변이 확인 후 되돌린다.** (a) 오류가 있어도 `commitButton`을 보이기 → 케이스 5 실패. (b) 중복 체크 없이 `commitButton` 활성 → 케이스 6 실패. (c) 직원에게도 메뉴 보이기(`if (isOwner)` 제거) → 메뉴 테스트 실패. (d) 성공 뒤 `Navigator.pop` 호출 → 케이스 4 실패. (e) `activeStoreIdProvider` 대신 항상 `'a'` 사용 → 케이스 2 또는 매장 전환 확인 실패. (f) 오류 목록의 상한(`shownErrors`) 대신 전체 표시 → 케이스 5 `'외 5개'` 실패.

- [ ] **4-7. 커밋.**
```
git add lib/data/import/import_file_gateway.dart lib/features/excel_import lib/core/shell/excel_import_route.dart lib/core/shell/app_shell.dart lib/core/shell/more_screen.dart test/features/excel_import test/core/shell test/support
git commit -m "feat: add the owner-only Excel upload screen" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## 작업 5: 전체 확인 (통제자가 한다)

- [ ] 전체 테스트와 분석: `flutter test --timeout 120s --reporter expanded *> $env:TEMP\full.log; Get-Content $env:TEMP\full.log -Tail 5` 그리고 `flutter analyze lib test`. 기대: 시작 354개 + 새 테스트 모두 통과, 분석 깨끗. 새 테스트 수를 직접 센다.
- [ ] 전체 브랜치 독립 검토 (opus): 스펙의 모든 항목이 구현됐는지(오류 메시지 문구, 상한들, 09:00, 오늘 이후 불가, 사장 전용), 저장이 실제로 한 트랜잭션인지, 중복 비교 정확도, 날짜 셀의 시간대, 큰 파일의 성능, 폭 320과 직원 접근, 실제 `.xlsx`(엑셀 프로그램에서 연 뒤 저장한 파일)를 읽는지 점검한다.
- [ ] 사용자가 손으로 확인한다 (Windows 먼저, 그다음 Android): (1) 양식 받기 → 저장 위치 확인 → 엑셀에서 열림. (2) 양식에 거래처 1, 품목 2, 입고 3줄을 채워 올림 → 미리보기 숫자 확인 → 올리기. (3) 재고 조회에서 입고 날짜로 바꿔 그날 재고와 입고 카드 확인. (4) 같은 파일을 다시 올려 중복 경고 확인. (5) 일부러 틀린 파일(거래처 오타, 날짜 형식 틀림) 오류 메시지의 줄 번호가 엑셀 줄과 맞는지. (6) 직원 계정에서 메뉴가 없는지. (7) 개발용 서버에서 올린 입고가 다른 기기로 동기화되는지.
- [ ] 메모리/문서 갱신: `project_stockcontrol.md`에 엑셀 업로드 완료를 적고, 새 함정이 생겼으면 CLAUDE.md에 더한다.
