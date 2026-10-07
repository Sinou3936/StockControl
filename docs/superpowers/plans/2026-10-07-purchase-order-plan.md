# 발주서 파일 만들기 (9-2) 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 부족 재고에서 이어서 거래처별 발주서를 PDF와 엑셀 파일로 만들어 저장한다.

**Architecture:** 수량 제안과 발주서 조립은 DB·파일을 모르는 순수 함수가 맡는다. PDF와 엑셀은 각각 `PurchaseOrder`를 받아 바이트를 돌려주는 함수이고, 저장은 `PurchaseOrderExporter` 뒤에 숨겨서 화면과 테스트가 파일 시스템을 몰라도 되게 한다. 발주서는 저장하지 않으므로 새 테이블도, 동기화 변경도 없다.

**Tech Stack:** Flutter, Riverpod, Drift, `pdf 3.12.0`, `excel 4.0.6`, `file_picker 13.1.0`

**Spec:** `docs/superpowers/specs/2026-10-07-purchase-order-design.md`

## 이 계획서에서 이미 확인한 것

패키지는 계획 단계에서 **실제로 내려받아 소스를 읽고, 같은 코드를 임시 프로젝트에서 돌려 봤다.** 아래는 추측이 아니라 확인한 사실이다. 구현자는 이 사실에 맞춰 쓴다.

- 세 패키지를 이 프로젝트에 추가하면 충돌 없이 설치되고 **기존 패키지는 하나도 바뀌지 않는다.** (`flutter pub add --dry-run`)
- **엑셀**: `Excel.createExcel()`의 기본 시트 이름은 `Sheet1`이고 `excel.rename(기존, 새이름)`으로 바꿀 수 있다. `excel.appendRow`가 아니라 **`sheet.appendRow(List<CellValue?>)`**, `sheet.setColumnWidth(열, 너비)`, `sheet.cell(CellIndex.indexByColumnRow(columnIndex:, rowIndex:)).cellStyle = CellStyle(bold: true)`가 동작한다. `excel.encode()`는 `List<int>?`를 돌려준다. 만든 바이트를 `Excel.decodeBytes`로 다시 읽으면 한글과 숫자가 그대로 나온다.
- **함정**: `TextCellValue.value`는 문자열이 아니라 `TextSpan`이다. 읽을 때 `.toString()`을 쓰면 `TextSpan(...)`이라는 디버그 문자열이 나온다. **`(cell.value as TextCellValue).value.text`** 를 쓴다.
- **PDF**: `pw.Font.ttf(ByteData)`, `pw.ThemeData.withFont(base:, bold:)`, `pw.MultiPage`, `pw.TableHelper.fromTextArray(headers:, data:, cellAlignments:, cellHeight:, columnWidths:)`가 3.12.0에서 그대로 컴파일된다. 3줄은 1쪽, 120줄은 5쪽으로 나뉜다. 한글 글꼴을 넘기면 "글리프를 찾을 수 없다"는 경고가 나오지 않는다. 글꼴은 쓴 글자만 담겨서 PDF가 13KB 안팎이다.
- **저장 창**: `FilePicker.saveFile(fileName:, bytes:, mimeType:, dialogTitle:)`가 `Future<Uri?>`를 돌려주고 **취소하면 null**이다. Windows는 저장 창으로 위치를 받은 뒤 **직접 바이트를 써서** `file:` 주소를 돌려준다. Android는 시스템 저장 창을 거쳐 쓰고 **`content:` 주소**를 돌려준다. 이름에 `.`이 없을 때만 확장자를 덧붙이므로 항상 확장자를 붙여 넘기면 중복되지 않는다.
- **글꼴**: 나눔고딕(SIL OFL 1.1) Regular 2,054,744바이트, Bold 2,073,868바이트, 라이선스 `OFL.txt` 4,534바이트. 내려받는 주소는 Task 3에 있다.
- **확인하지 못한 것**: PDF 한글이 실제 화면에서 예쁘게 보이는지(도구가 없어 눈으로 못 봤다), Android 실기기의 저장 위치. Task 7의 수동 확인으로 둔다.

## 스펙과 달라진 점

1. **저장 결과 문구**: 스펙은 "저장했습니다 + 경로"였다. Android는 `content:` 주소를 돌려줘서 사람이 읽을 경로가 아니므로 **Android는 파일 이름만** 보여준다. Windows는 실제 경로를 보여준다.
2. **`PurchaseOrderExporter.save`의 반환값**: 스펙은 "저장한 경로, 취소하면 null"이었다. 위 이유로 **화면에 보여줄 문구(경로 또는 파일 이름), 취소하면 null**로 한다.
3. **`PurchaseOrderFormat`의 위치**: 스펙은 exporter 쪽에 두었으나, 파일 이름 함수가 쓰므로 **도메인 파일**에 둔다.
4. **날짜 형식 함수**(`formatPurchaseOrderDate`)를 도메인에 추가한다. PDF와 엑셀이 같은 형식을 쓰게 하려는 것이다.

## Global Constraints

- 발주서는 **PDF와 엑셀 둘 다** 만든다. 저장만 한다 — 공유, 인쇄, 발주 이력은 없다.
- **새 테이블, 동기화 변경, Supabase SQL은 만들지 않는다.** 발주서는 저장하지 않고 그때그때 계산해서 파일로만 만든다.
- 발주서는 **매장 하나 + 거래처 하나** 단위다. 거래처는 발주서를 만들 때 고른다. 거래처와 품목을 잇는 데이터는 만들지 않는다.
- 발주는 사장이 한다. **"발주서 만들기"는 사장 계정에만** 보인다.
- 사장이 **전체 합산**을 보는 중에는 발주서를 만들 수 없다. 버튼을 비활성화하고 "매장을 고르면 발주서를 만들 수 있습니다"를 보여준다.
- 수량 제안은 `부족분 ÷ 환산계수`를 **올림한 구매 단위 수**다. 항상 직접 고칠 수 있다.
- 수량이 0 이하인 품목은 발주서에서 빠진다. 환산계수가 0 이하(또는 NaN, 무한대)인 품목은 제안 수량을 **1**로 둔다.
- 발주서 화면을 열 때 부족 목록을 **한 번 복사해서 넘긴다.** 화면이 부족 목록 provider를 계속 지켜보면 안 된다.
- PDF 한글을 위해 한글 글꼴을 앱에 포함한다. 글꼴은 SIL OFL 라이선스이고 `assets/fonts/OFL.txt`를 함께 둔다.
- 파일 이름의 `\ / : * ? " < > |`는 `_`로 바꾼다.
- 커밋 메시지는 `-m`을 두 번 써서 끝에 `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` 단락을 붙인다. 메시지 안에 큰따옴표를 넣지 않는다 (PowerShell 인용이 깨진다).
- **`dart format`은 수정한 파일 경로만 지정해서 돌린다.** `dart format lib`처럼 디렉터리째 돌리면 건드리지 않은 파일이 바뀐다.
- **`git add .`/`git add -A` 금지.** 경로를 직접 적는다.
- 셸은 PowerShell이다. `&&`는 파서 에러라 `;`로 잇는다. `python`은 멈추니 필요하면 `py -3`.
- 테스트에서 `package:drift/drift.dart`를 import하면서 `isNull`/`isNotNull` matcher를 쓰면 `hide isNotNull, isNull`을 붙인다.
- **`testWidgets` 안에서 `await dao.watchAll().first`처럼 실제 스트림을 직접 기다리면 영원히 멈춘다.** 값을 읽을 때는 `await db.select(db.테이블).get()`을 쓴다.

### 테스트 실행 방법 (모든 Task에 공통)

`flutter test`는 **항상 `--timeout`을 주고, 출력을 파일로 받아서 읽는다.** 출력을 `Select-String` 같은 필터에 바로 물리면 끝날 때까지 아무것도 안 보여서 멈춘 것과 구별이 안 된다. **Windows에서 `flutter test`를 두 개 동시에 돌리면 `sqlite3.dll` 복사가 충돌해서 도구가 죽는다** — 하나가 끝난 뒤에 다음을 돌린다.

```powershell
flutter test <경로> --timeout 60s --reporter expanded *> $env:TEMP\flutter-test.log; Get-Content $env:TEMP\flutter-test.log -Tail 25
```

멈춘 것 같으면(수 분 동안 `+0`에 머묾) `Get-Process dart,flutter_tester | Stop-Process -Force`로 정리하고 원인을 본다.

### 변이로 확인한 파일을 되돌리는 방법

이미 커밋된 파일이면 `git checkout -- <경로>`. 커밋 전이면 `git checkout`이 작업을 날리므로 **편집 도구로 정확히 되돌린다.** PowerShell `Set-Content`로 다시 쓰지 않는다 (한글 주석이 깨진다).

## Review Focus

- **거래처·매장 이름에 파일 이름으로 못 쓰는 문자**(`/`, `:` 등)가 들어 있어도 저장이 실패하지 않는다. 문자가 `_`로 바뀐다. (Task 1)
- **환산계수가 0 이하이거나 NaN인 품목**은 예외 없이 제안 수량 1이 된다. 품목 등록 화면이 환산계수의 양수 여부를 검사하지 않아서 생길 수 있는 값이다. (Task 1)
- **저장 창을 취소**하면 아무 메시지도, 에러도 없다. 사용자가 일부러 닫은 것이다. (Task 4, Task 5)
- **수량칸에 숫자가 아닌 글자, 빈칸, 0**을 넣으면 그 줄만 조용히 빠지고 예외는 없다. 숫자가 아닌 글자는 아예 입력되지 않는다. (Task 5)
- **저장하는 동안 버튼을 또 눌러도** 한 번만 저장된다. 파일 만들기와 저장 창이 느릴 때 두 번 누르기 쉽다. (Task 5)

---

### Task 1: 수량 제안과 발주서 조립 (순수 함수)

**Files:**
- Create: `lib/domain/purchase_order.dart`
- Test: `test/domain/purchase_order_test.dart`

**Interfaces:**
- Consumes: 9-1의 `StockShortage` (`lib/domain/stock_shortage.dart`) — `ingredient`, `store`, `currentQty`, `shortfall`
- Produces:
  - `enum PurchaseOrderFormat { pdf, xlsx }` — `String get fileExtension`, `String get mimeType`
  - `class PurchaseOrderLine { Ingredient ingredient; int qty; }`
  - `class PurchaseOrder { Store store; Supplier supplier; DateTime date; List<PurchaseOrderLine> lines; }`
  - `int suggestOrderQty(StockShortage shortage)`
  - `PurchaseOrder buildPurchaseOrder({required Store store, required Supplier supplier, required DateTime date, required List<PurchaseOrderLine> lines})`
  - `String formatPurchaseOrderDate(DateTime date)` — `yyyy-MM-dd`
  - `String purchaseOrderFileName(PurchaseOrder order, PurchaseOrderFormat format)`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/domain/purchase_order_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/domain/purchase_order.dart';
import 'package:stockcontrol/domain/stock_shortage.dart';

const ulsan = Store(id: 'store-1', name: '울산점');

Ingredient makeIngredient({
  int id = 1,
  String name = '양파',
  double safety = 5000,
  double conversionFactor = 20000,
}) => Ingredient(
  id: id,
  name: name,
  baseUnit: 'g',
  purchaseUnit: '박스',
  conversionFactor: conversionFactor,
  isExpiryTracked: false,
  safetyStockQty: safety,
  createdAt: DateTime(2026, 10, 1),
);

StockShortage makeShortage({
  required double safety,
  required double current,
  double conversionFactor = 20000,
}) => StockShortage(
  ingredient: makeIngredient(
    safety: safety,
    conversionFactor: conversionFactor,
  ),
  store: ulsan,
  currentQty: current,
);

Supplier makeSupplier(String name) =>
    Supplier(id: 1, name: name, createdAt: DateTime(2026, 10, 1));

void main() {
  group('suggestOrderQty', () {
    test('부족분이 구매 단위 한 개에 못 미치면 1이다', () {
      // 5,000g 기준, 1,200g 남음 → 3,800g 부족, 1박스 = 20,000g
      final shortage = makeShortage(safety: 5000, current: 1200);

      expect(suggestOrderQty(shortage), 1);
    });

    test('부족분이 구매 단위의 정확한 배수면 그 배수다', () {
      final shortage = makeShortage(safety: 40000, current: 0);

      expect(suggestOrderQty(shortage), 2);
    });

    test('부족분이 배수를 조금 넘으면 올림한다', () {
      final shortage = makeShortage(safety: 40001, current: 0);

      expect(suggestOrderQty(shortage), 3);
    });

    test('환산계수가 0 이하이거나 숫자가 아니면 예외 없이 1이다', () {
      for (final factor in [0.0, -5.0, double.nan, double.infinity]) {
        final shortage = makeShortage(
          safety: 5000,
          current: 0,
          conversionFactor: factor,
        );

        expect(suggestOrderQty(shortage), 1, reason: '환산계수 $factor');
      }
    });
  });

  group('buildPurchaseOrder', () {
    test('수량이 0 이하인 줄은 빠지고 남은 줄의 순서는 유지된다', () {
      final order = buildPurchaseOrder(
        store: ulsan,
        supplier: makeSupplier('가나다상사'),
        date: DateTime(2026, 10, 7),
        lines: [
          PurchaseOrderLine(ingredient: makeIngredient(id: 1, name: '양파'), qty: 2),
          PurchaseOrderLine(ingredient: makeIngredient(id: 2, name: '당근'), qty: 0),
          PurchaseOrderLine(ingredient: makeIngredient(id: 3, name: '대파'), qty: -1),
          PurchaseOrderLine(ingredient: makeIngredient(id: 4, name: '마늘'), qty: 5),
        ],
      );

      expect(order.lines.map((l) => l.ingredient.name), ['양파', '마늘']);
    });

    test('모든 줄이 빠지면 줄이 없는 발주서가 된다', () {
      final order = buildPurchaseOrder(
        store: ulsan,
        supplier: makeSupplier('가나다상사'),
        date: DateTime(2026, 10, 7),
        lines: [
          PurchaseOrderLine(ingredient: makeIngredient(), qty: 0),
        ],
      );

      expect(order.lines, isEmpty);
    });
  });

  group('파일 이름과 날짜', () {
    test('형식마다 확장자와 MIME 형식이 정해져 있다', () {
      expect(PurchaseOrderFormat.pdf.fileExtension, 'pdf');
      expect(PurchaseOrderFormat.pdf.mimeType, 'application/pdf');
      expect(PurchaseOrderFormat.xlsx.fileExtension, 'xlsx');
      expect(
        PurchaseOrderFormat.xlsx.mimeType,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    });

    test('날짜는 월과 일이 한 자리여도 두 자리로 채운다', () {
      expect(formatPurchaseOrderDate(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('파일 이름에 쓸 수 없는 문자는 _로 바뀐다', () {
      final order = PurchaseOrder(
        store: ulsan,
        supplier: makeSupplier('가나/다:상사'),
        date: DateTime(2026, 10, 7),
        lines: const [],
      );

      expect(
        purchaseOrderFileName(order, PurchaseOrderFormat.pdf),
        '발주서_울산점_가나_다_상사_20261007.pdf',
      );
    });

    test('엑셀 파일 이름은 .xlsx로 끝나고 날짜가 두 자리로 채워진다', () {
      final order = PurchaseOrder(
        store: ulsan,
        supplier: makeSupplier('가나다상사'),
        date: DateTime(2026, 1, 5),
        lines: const [],
      );

      expect(
        purchaseOrderFileName(order, PurchaseOrderFormat.xlsx),
        '발주서_울산점_가나다상사_20260105.xlsx',
      );
    });
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/domain/purchase_order_test.dart --timeout 60s --reporter expanded *> $env:TEMP\flutter-test.log; Get-Content $env:TEMP\flutter-test.log -Tail 25`
Expected: FAIL — `lib/domain/purchase_order.dart` 파일이 없어 컴파일 에러

- [ ] **Step 3: 구현 작성**

`lib/domain/purchase_order.dart`:

```dart
import 'package:stockcontrol/data/local/database.dart';

import 'stock_shortage.dart';

/// 발주서 파일 형식.
enum PurchaseOrderFormat {
  pdf('pdf', 'application/pdf'),
  xlsx(
    'xlsx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );

  const PurchaseOrderFormat(this.fileExtension, this.mimeType);

  /// 점(.)을 뺀 확장자.
  final String fileExtension;
  final String mimeType;
}

/// 발주서의 한 줄. 수량은 구매 단위(박스 등) 기준 정수다.
class PurchaseOrderLine {
  const PurchaseOrderLine({required this.ingredient, required this.qty});

  final Ingredient ingredient;
  final int qty;
}

/// 매장 하나, 거래처 하나에 대한 발주서.
class PurchaseOrder {
  const PurchaseOrder({
    required this.store,
    required this.supplier,
    required this.date,
    required this.lines,
  });

  final Store store;
  final Supplier supplier;
  final DateTime date;
  final List<PurchaseOrderLine> lines;
}

/// 부족분을 구매 단위로 올린 수. 안전재고까지만 채우는 양이라 어디까지나
/// 사용자가 고칠 수 있는 제안값이다.
///
/// 환산계수가 0 이하이거나 숫자가 아니면 1을 돌려준다. 0으로 나눈 값을
/// 올림하면 예외가 나는데, 품목 등록 화면이 환산계수의 양수 여부를 검사하지
/// 않아서 이런 값이 들어올 수 있다.
int suggestOrderQty(StockShortage shortage) {
  final factor = shortage.ingredient.conversionFactor;
  if (!factor.isFinite || factor <= 0) return 1;
  return (shortage.shortfall / factor).ceil();
}

/// 수량이 0 이하인 줄을 빼고 발주서를 만든다. 남은 줄은 입력 순서를 지킨다.
PurchaseOrder buildPurchaseOrder({
  required Store store,
  required Supplier supplier,
  required DateTime date,
  required List<PurchaseOrderLine> lines,
}) {
  return PurchaseOrder(
    store: store,
    supplier: supplier,
    date: date,
    lines: [
      for (final line in lines)
        if (line.qty > 0) line,
    ],
  );
}

String _two(int n) => n.toString().padLeft(2, '0');

/// `2026-10-07` 형식. PDF와 엑셀이 같은 형식을 쓴다.
String formatPurchaseOrderDate(DateTime date) =>
    '${date.year}-${_two(date.month)}-${_two(date.day)}';

/// `발주서_{매장}_{거래처}_{yyyyMMdd}.{확장자}`. 파일 이름에 쓸 수 없는
/// 문자는 `_`로 바꾼다 — 거래처 이름에 `/` 같은 문자가 있어도 저장이
/// 실패하지 않게 하려는 것이다.
String purchaseOrderFileName(PurchaseOrder order, PurchaseOrderFormat format) {
  String clean(String text) =>
      text.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  final d = order.date;
  final stamp = '${d.year}${_two(d.month)}${_two(d.day)}';
  return '발주서_${clean(order.store.name)}_${clean(order.supplier.name)}'
      '_$stamp.${format.fileExtension}';
}
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: Step 2와 같은 명령
Expected: PASS (10 tests)

- [ ] **Step 5: 정적 분석과 포맷**

Run: `dart format lib/domain/purchase_order.dart test/domain/purchase_order_test.dart; flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```powershell
git add lib/domain/purchase_order.dart test/domain/purchase_order_test.dart
git commit -m "feat: add purchase order quantity suggestion and assembly" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: 엑셀 발주서 만들기

**Files:**
- Modify: `pubspec.yaml` (`excel` 추가), `pubspec.lock`
- Create: `lib/data/export/purchase_order_xlsx.dart`
- Test: `test/data/export/purchase_order_xlsx_test.dart`

**Interfaces:**
- Consumes: `PurchaseOrder`, `formatPurchaseOrderDate` (Task 1)
- Produces: `Uint8List buildPurchaseOrderXlsx(PurchaseOrder order)`

- [ ] **Step 1: 패키지 추가**

`pubspec.yaml`의 `dependencies:`에서 `uuid: ^4.6.0` 다음 줄에 추가한다:

```yaml
  excel: ^4.0.6
```

Run: `flutter pub get`
Expected: 오류 없이 끝나고, `flutter pub deps | Select-String "excel"`에 `excel 4.0.6`이 보인다.

- [ ] **Step 2: 실패하는 테스트 작성**

`test/data/export/purchase_order_xlsx_test.dart`:

```dart
import 'package:excel/excel.dart' show Data, Excel, IntCellValue, TextCellValue;
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/export/purchase_order_xlsx.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/domain/purchase_order.dart';

Ingredient makeIngredient(int id, String name, String purchaseUnit) =>
    Ingredient(
      id: id,
      name: name,
      baseUnit: 'g',
      purchaseUnit: purchaseUnit,
      conversionFactor: 20000,
      isExpiryTracked: false,
      safetyStockQty: 5000,
      createdAt: DateTime(2026, 10, 1),
    );

PurchaseOrder makeOrder({String? contact = '010-1234-5678'}) => PurchaseOrder(
  store: const Store(id: 'store-1', name: '울산점'),
  supplier: Supplier(
    id: 1,
    name: '가나다상사',
    contact: contact,
    createdAt: DateTime(2026, 10, 1),
  ),
  date: DateTime(2026, 10, 7),
  lines: [
    PurchaseOrderLine(ingredient: makeIngredient(1, '양파', '박스'), qty: 2),
    PurchaseOrderLine(ingredient: makeIngredient(2, '대파', '단'), qty: 10),
  ],
);

/// 셀의 글자. TextCellValue.value는 문자열이 아니라 TextSpan이라 .text로
/// 꺼내야 한다. toString()을 쓰면 TextSpan(...) 디버그 문자열이 나온다.
String? text(Data? cell) {
  final value = cell?.value;
  if (value is TextCellValue) return value.value.text;
  return value?.toString();
}

void main() {
  test('시트 이름은 발주서 하나뿐이다', () {
    final back = Excel.decodeBytes(buildPurchaseOrderXlsx(makeOrder()));

    expect(back.tables.keys.toList(), ['발주서']);
  });

  test('위쪽에 제목과 발주 정보가 들어간다', () {
    final rows = Excel.decodeBytes(buildPurchaseOrderXlsx(makeOrder()))['발주서']
        .rows;

    expect(text(rows[0][0]), '발주서');
    expect(rows[1].take(2).map(text), ['발주일', '2026-10-07']);
    expect(rows[2].take(2).map(text), ['매장', '울산점']);
    expect(rows[3].take(2).map(text), ['거래처', '가나다상사']);
    expect(rows[4].take(2).map(text), ['연락처', '010-1234-5678']);
  });

  test('품목 표에 머리글과 각 줄이 들어간다', () {
    final rows = Excel.decodeBytes(buildPurchaseOrderXlsx(makeOrder()))['발주서']
        .rows;

    expect(rows[5].take(4).map(text), ['품목', '수량', '단위', '비고']);
    expect(rows[6].take(3).map(text), ['양파', '2', '박스']);
    expect(rows[7].take(3).map(text), ['대파', '10', '단']);
  });

  test('수량은 글자가 아니라 숫자 셀이다', () {
    final rows = Excel.decodeBytes(buildPurchaseOrderXlsx(makeOrder()))['발주서']
        .rows;

    final qty = rows[6][1]!.value;
    expect(qty, isA<IntCellValue>());
    expect((qty as IntCellValue).value, 2);
  });

  test('연락처가 없어도 만들어지고 그 칸은 비어 있다', () {
    final rows = Excel.decodeBytes(
      buildPurchaseOrderXlsx(makeOrder(contact: null)),
    )['발주서'].rows;

    expect(text(rows[4][0]), '연락처');
    expect(text(rows[4][1]) ?? '', '');
  });
}
```

- [ ] **Step 3: 테스트 실행하여 실패 확인**

Run: `flutter test test/data/export/purchase_order_xlsx_test.dart --timeout 60s --reporter expanded *> $env:TEMP\flutter-test.log; Get-Content $env:TEMP\flutter-test.log -Tail 25`
Expected: FAIL — `purchase_order_xlsx.dart` 파일이 없어 컴파일 에러

- [ ] **Step 4: 구현 작성**

`lib/data/export/purchase_order_xlsx.dart`:

```dart
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
  sheet.appendRow([
    TextCellValue('거래처'),
    TextCellValue(order.supplier.name),
  ]);
  sheet.appendRow([
    TextCellValue('연락처'),
    TextCellValue(order.supplier.contact ?? ''),
  ]);

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
  sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle =
      CellStyle(bold: true);
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
```

- [ ] **Step 5: 테스트 실행하여 통과 확인**

Run: Step 3과 같은 명령
Expected: PASS (5 tests)

- [ ] **Step 6: 정적 분석과 포맷**

Run: `dart format lib/data/export/purchase_order_xlsx.dart test/data/export/purchase_order_xlsx_test.dart; flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

`git status --porcelain`으로 `pubspec.yaml`, `pubspec.lock` 외에 바뀐 생성 파일(`windows/flutter/generated_*` 등)이 있는지 보고, 있으면 함께 추가한다.

```powershell
git add pubspec.yaml pubspec.lock lib/data/export/purchase_order_xlsx.dart test/data/export/purchase_order_xlsx_test.dart
git commit -m "feat: build purchase orders as Excel files" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: PDF 발주서 만들기와 한글 글꼴

**Files:**
- Modify: `pubspec.yaml` (`pdf` 추가, `assets` 등록), `pubspec.lock`
- Create: `assets/fonts/NanumGothic-Regular.ttf`, `assets/fonts/NanumGothic-Bold.ttf`, `assets/fonts/OFL.txt`
- Create: `lib/data/export/purchase_order_pdf.dart`
- Test: `test/data/export/purchase_order_pdf_test.dart`

**Interfaces:**
- Consumes: `PurchaseOrder`, `formatPurchaseOrderDate` (Task 1)
- Produces: `Future<Uint8List> buildPurchaseOrderPdf(PurchaseOrder order, {required ByteData regularFont, required ByteData boldFont})`

- [ ] **Step 1: 글꼴 내려받기**

Run:

```powershell
New-Item -ItemType Directory -Force assets/fonts | Out-Null
$base = "https://raw.githubusercontent.com/google/fonts/main/ofl/nanumgothic"
foreach ($f in "NanumGothic-Regular.ttf","NanumGothic-Bold.ttf","OFL.txt") {
  Invoke-WebRequest -Uri "$base/$f" -OutFile "assets/fonts/$f" -UseBasicParsing -TimeoutSec 60
  "{0}  {1:N0} bytes" -f $f, (Get-Item "assets/fonts/$f").Length
}
```

Expected: 크기가 `2,054,744` / `2,073,868` / `4,534` 바이트다. 다르면 내려받기가 잘못된 것(HTML 오류 페이지 등)이니 파일을 지우고 다시 받는다.

- [ ] **Step 2: 패키지와 글꼴 등록**

`pubspec.yaml`의 `dependencies:`에서 Task 2에서 추가한 `excel` 다음 줄에 추가한다:

```yaml
  pdf: ^3.12.0
```

같은 파일의 `flutter:` 아래, `uses-material-design: true` 줄을 아래로 바꾼다 (뒤따르는 주석 처리된 `assets:` 예시는 그대로 둔다):

```yaml
  uses-material-design: true

  assets:
    - assets/fonts/NanumGothic-Regular.ttf
    - assets/fonts/NanumGothic-Bold.ttf
    - assets/fonts/OFL.txt
```

Run: `flutter pub get`
Expected: 오류 없이 끝나고, `flutter pub deps | Select-String "pdf"`에 `pdf 3.12.0`이 보인다.

- [ ] **Step 3: 실패하는 테스트 작성**

`test/data/export/purchase_order_pdf_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/export/purchase_order_pdf.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/domain/purchase_order.dart';

Ingredient makeIngredient(int id, String name) => Ingredient(
  id: id,
  name: name,
  baseUnit: 'g',
  purchaseUnit: '박스',
  conversionFactor: 20000,
  isExpiryTracked: false,
  safetyStockQty: 5000,
  createdAt: DateTime(2026, 10, 1),
);

PurchaseOrder makeOrder(int lineCount) => PurchaseOrder(
  store: const Store(id: 'store-1', name: '울산점'),
  supplier: Supplier(
    id: 1,
    name: '가나다상사',
    contact: '010-1234-5678',
    createdAt: DateTime(2026, 10, 1),
  ),
  date: DateTime(2026, 10, 7),
  lines: [
    for (var i = 0; i < lineCount; i++)
      PurchaseOrderLine(ingredient: makeIngredient(i, '양파$i'), qty: i + 1),
  ],
);

ByteData readFont(String name) =>
    ByteData.sublistView(File('assets/fonts/$name').readAsBytesSync());

/// PDF 안의 쪽 수. 쪽 객체는 압축되지 않아서 글자로 읽어 셀 수 있다.
int pageCount(Uint8List bytes) => RegExp(
  r'/Type\s*/Page(?!s)',
).allMatches(String.fromCharCodes(bytes)).length;

Future<Uint8List> build(int lineCount) => buildPurchaseOrderPdf(
  makeOrder(lineCount),
  regularFont: readFont('NanumGothic-Regular.ttf'),
  boldFont: readFont('NanumGothic-Bold.ttf'),
);

void main() {
  test('한글 글꼴로 만든 PDF는 %PDF로 시작하고 비어 있지 않다', () async {
    final bytes = await build(3);

    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });

  test('줄이 적으면 한 쪽, 많으면 여러 쪽으로 나뉜다', () async {
    expect(pageCount(await build(3)), 1);
    expect(pageCount(await build(120)), greaterThan(1));
  });

  test('pubspec에 등록한 글꼴을 앱 번들에서 읽을 수 있다', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final regular = await rootBundle.load(
      'assets/fonts/NanumGothic-Regular.ttf',
    );
    final bold = await rootBundle.load('assets/fonts/NanumGothic-Bold.ttf');

    expect(regular.lengthInBytes, greaterThan(1000000));
    expect(bold.lengthInBytes, greaterThan(1000000));
  });
}
```

- [ ] **Step 4: 테스트 실행하여 실패 확인**

Run: `flutter test test/data/export/purchase_order_pdf_test.dart --timeout 60s --reporter expanded *> $env:TEMP\flutter-test.log; Get-Content $env:TEMP\flutter-test.log -Tail 25`
Expected: FAIL — `purchase_order_pdf.dart` 파일이 없어 컴파일 에러

- [ ] **Step 5: 구현 작성**

`lib/data/export/purchase_order_pdf.dart`:

```dart
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/purchase_order.dart';

/// 발주서를 PDF 파일 바이트로 만든다.
///
/// 한글이 깨지지 않으려면 한글 글꼴이 필요하다. 글꼴 파일은 호출하는 쪽이
/// 읽어서 넘긴다 — 테스트가 실제 글꼴로 만들어 볼 수 있게 하려는 것이다.
/// 글꼴은 PDF 안에 쓴 글자만 담겨서 파일이 수십 KB에 그친다.
Future<Uint8List> buildPurchaseOrderPdf(
  PurchaseOrder order, {
  required ByteData regularFont,
  required ByteData boldFont,
}) {
  final regular = pw.Font.ttf(regularFont);
  final bold = pw.Font.ttf(boldFont);
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );

  // 줄이 많으면 여러 쪽으로 나뉘도록 MultiPage를 쓴다.
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => [
        pw.Text('발주서', style: pw.TextStyle(font: bold, fontSize: 24)),
        pw.SizedBox(height: 16),
        pw.Text('발주일: ${formatPurchaseOrderDate(order.date)}'),
        pw.Text('매장: ${order.store.name}'),
        pw.Text('거래처: ${order.supplier.name}'),
        pw.Text('연락처: ${order.supplier.contact ?? ''}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: ['품목', '수량', '단위', '비고'],
          data: [
            for (final line in order.lines)
              [
                line.ingredient.name,
                '${line.qty}',
                line.ingredient.purchaseUnit,
                '',
              ],
          ],
          cellAlignments: {1: pw.Alignment.centerRight},
          cellHeight: 28,
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(4),
          },
        ),
      ],
    ),
  );

  return doc.save();
}
```

- [ ] **Step 6: 테스트 실행하여 통과 확인**

Run: Step 4와 같은 명령
Expected: PASS (3 tests)

세 번째 테스트가 실패하면 `pubspec.yaml`의 `assets:` 들여쓰기나 파일 이름 오타를 먼저 본다.

- [ ] **Step 7: 정적 분석과 포맷**

Run: `dart format lib/data/export/purchase_order_pdf.dart test/data/export/purchase_order_pdf_test.dart; flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

`git status --porcelain`으로 생성 파일 변경이 있는지 본다.

```powershell
git add pubspec.yaml pubspec.lock assets/fonts lib/data/export/purchase_order_pdf.dart test/data/export/purchase_order_pdf_test.dart
git commit -m "feat: build purchase orders as PDF files with a Korean font" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: 저장 (exporter)

**Files:**
- Modify: `pubspec.yaml` (`file_picker` 추가), `pubspec.lock`
- Create: `lib/data/export/purchase_order_exporter.dart`
- Test: `test/data/export/purchase_order_exporter_test.dart`

**Interfaces:**
- Consumes: Task 1의 `PurchaseOrder`, `PurchaseOrderFormat`, `purchaseOrderFileName`, Task 2의 `buildPurchaseOrderXlsx`, Task 3의 `buildPurchaseOrderPdf`
- Produces:
  - `abstract class PurchaseOrderExporter { Future<String?> save(PurchaseOrder order, PurchaseOrderFormat format); }` — 저장했으면 화면에 보여줄 문구, 사용자가 저장 창을 취소했으면 null
  - `class FilePurchaseOrderExporter implements PurchaseOrderExporter` — 생성자 `FilePurchaseOrderExporter({SaveFileFn? saveFile, LoadFontFn? loadFont})`
  - `String? savedDisplayText(Uri? saved, String fileName)`
  - `final purchaseOrderExporterProvider = Provider<PurchaseOrderExporter>(...)`

- [ ] **Step 1: 패키지 추가**

`pubspec.yaml`의 `dependencies:`에서 `pdf` 다음 줄에 추가한다:

```yaml
  file_picker: ^13.1.0
```

Run: `flutter pub get`
Expected: 오류 없이 끝나고, `flutter pub deps | Select-String "file_picker"`에 `file_picker 13.1.0`이 보인다.

- [ ] **Step 2: 실패하는 테스트 작성**

`test/data/export/purchase_order_exporter_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/export/purchase_order_exporter.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/domain/purchase_order.dart';

PurchaseOrder makeOrder() => PurchaseOrder(
  store: const Store(id: 'store-1', name: '울산점'),
  supplier: Supplier(id: 1, name: '가나다상사', createdAt: DateTime(2026, 10, 1)),
  date: DateTime(2026, 10, 7),
  lines: [
    PurchaseOrderLine(
      ingredient: Ingredient(
        id: 1,
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
        safetyStockQty: 5000,
        createdAt: DateTime(2026, 10, 1),
      ),
      qty: 2,
    ),
  ],
);

void main() {
  late List<({String fileName, Uint8List bytes, String mimeType})> calls;
  late int fontLoads;

  /// 저장 창은 가짜로, 글꼴은 파일에서 직접 읽는다.
  FilePurchaseOrderExporter makeExporter({Uri? result}) {
    calls = [];
    fontLoads = 0;
    return FilePurchaseOrderExporter(
      saveFile: ({required fileName, required bytes, required mimeType}) async {
        calls.add((fileName: fileName, bytes: bytes, mimeType: mimeType));
        return result;
      },
      loadFont: (path) async {
        fontLoads++;
        return ByteData.sublistView(File(path).readAsBytesSync());
      },
    );
  }

  test('PDF를 만들어 저장 창에 넘기고 Windows 경로를 돌려준다', () async {
    final saved = Uri.file('C:/docs/발주서.pdf');
    final exporter = makeExporter(result: saved);
    final order = makeOrder();

    final shown = await exporter.save(order, PurchaseOrderFormat.pdf);

    expect(shown, saved.toFilePath());
    expect(calls, hasLength(1));
    expect(calls.single.mimeType, 'application/pdf');
    expect(
      calls.single.fileName,
      purchaseOrderFileName(order, PurchaseOrderFormat.pdf),
    );
    expect(String.fromCharCodes(calls.single.bytes.take(4)), '%PDF');
    expect(fontLoads, 2);
  });

  test('엑셀은 글꼴을 읽지 않고 xlsx 파일을 넘긴다', () async {
    final exporter = makeExporter(result: Uri.file('C:/docs/발주서.xlsx'));

    await exporter.save(makeOrder(), PurchaseOrderFormat.xlsx);

    expect(
      calls.single.mimeType,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    // xlsx는 zip이라 PK로 시작한다.
    expect(String.fromCharCodes(calls.single.bytes.take(2)), 'PK');
    expect(fontLoads, 0);
  });

  test('저장 창을 취소하면 null이다', () async {
    final exporter = makeExporter(result: null);

    final shown = await exporter.save(makeOrder(), PurchaseOrderFormat.xlsx);

    expect(shown, isNull);
  });

  test('Android처럼 content 주소가 돌아오면 파일 이름만 보여준다', () async {
    final exporter = makeExporter(
      result: Uri.parse('content://com.android.providers/document/1'),
    );
    final order = makeOrder();

    final shown = await exporter.save(order, PurchaseOrderFormat.pdf);

    expect(shown, purchaseOrderFileName(order, PurchaseOrderFormat.pdf));
  });

  test('savedDisplayText는 취소면 null, file 주소면 경로, 그 밖은 이름이다', () {
    expect(savedDisplayText(null, 'a.pdf'), isNull);
    expect(
      savedDisplayText(Uri.file('C:/x/a.pdf'), 'a.pdf'),
      Uri.file('C:/x/a.pdf').toFilePath(),
    );
    expect(savedDisplayText(Uri.parse('content://x/1'), 'a.pdf'), 'a.pdf');
  });
}
```

- [ ] **Step 3: 테스트 실행하여 실패 확인**

Run: `flutter test test/data/export/purchase_order_exporter_test.dart --timeout 60s --reporter expanded *> $env:TEMP\flutter-test.log; Get-Content $env:TEMP\flutter-test.log -Tail 25`
Expected: FAIL — `purchase_order_exporter.dart` 파일이 없어 컴파일 에러

- [ ] **Step 4: 구현 작성**

`lib/data/export/purchase_order_exporter.dart`:

```dart
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/purchase_order.dart';
import 'purchase_order_pdf.dart';
import 'purchase_order_xlsx.dart';

const regularFontAsset = 'assets/fonts/NanumGothic-Regular.ttf';
const boldFontAsset = 'assets/fonts/NanumGothic-Bold.ttf';

/// 발주서를 파일로 저장한다. 화면과 테스트는 이 인터페이스만 안다.
abstract class PurchaseOrderExporter {
  /// 저장했으면 화면에 보여줄 문구(Windows는 경로, Android는 파일 이름),
  /// 사용자가 저장 창을 취소했으면 null.
  Future<String?> save(PurchaseOrder order, PurchaseOrderFormat format);
}

/// 저장 창을 띄워 파일을 쓴다. 저장한 곳의 주소를 돌려주고, 취소하면 null.
typedef SaveFileFn =
    Future<Uri?> Function({
      required String fileName,
      required Uint8List bytes,
      required String mimeType,
    });

typedef LoadFontFn = Future<ByteData> Function(String assetPath);

/// 저장 결과를 화면에 보여줄 문구로 바꾼다. 취소했으면 null.
///
/// Windows는 `file:` 주소라 실제 경로를 보여준다. Android는 `content:`
/// 주소라 사람이 읽을 수 없으므로 파일 이름만 보여준다.
String? savedDisplayText(Uri? saved, String fileName) {
  if (saved == null) return null;
  if (saved.scheme == 'file') return saved.toFilePath();
  return fileName;
}

class FilePurchaseOrderExporter implements PurchaseOrderExporter {
  FilePurchaseOrderExporter({SaveFileFn? saveFile, LoadFontFn? loadFont})
    : _saveFile = saveFile ?? _pickAndSave,
      _loadFont = loadFont ?? rootBundle.load;

  final SaveFileFn _saveFile;
  final LoadFontFn _loadFont;

  /// 시스템의 "다른 이름으로 저장" 창에서 위치를 고르게 한다. 폰에서 앱 전용
  /// 폴더에 조용히 저장하면 사용자가 파일을 찾을 수 없다.
  static Future<Uri?> _pickAndSave({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) {
    return FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      dialogTitle: '발주서 저장',
    );
  }

  @override
  Future<String?> save(PurchaseOrder order, PurchaseOrderFormat format) async {
    final Uint8List bytes;
    switch (format) {
      case PurchaseOrderFormat.xlsx:
        bytes = buildPurchaseOrderXlsx(order);
      case PurchaseOrderFormat.pdf:
        bytes = await buildPurchaseOrderPdf(
          order,
          regularFont: await _loadFont(regularFontAsset),
          boldFont: await _loadFont(boldFontAsset),
        );
    }

    final fileName = purchaseOrderFileName(order, format);
    final saved = await _saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: format.mimeType,
    );
    return savedDisplayText(saved, fileName);
  }
}

final purchaseOrderExporterProvider = Provider<PurchaseOrderExporter>(
  (ref) => FilePurchaseOrderExporter(),
);
```

- [ ] **Step 5: 테스트 실행하여 통과 확인**

Run: Step 3과 같은 명령
Expected: PASS (5 tests)

- [ ] **Step 6: 정적 분석과 포맷**

Run: `dart format lib/data/export/purchase_order_exporter.dart test/data/export/purchase_order_exporter_test.dart; flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

`git status --porcelain`으로 `pubspec.lock` 외에 바뀐 생성 파일(`windows/flutter/generated_plugin_registrant.cc`, `generated_plugins.cmake`, `linux/flutter/generated_plugin_registrant.cc`)이 있는지 보고, 있으면 함께 추가한다.

```powershell
git add pubspec.yaml pubspec.lock lib/data/export/purchase_order_exporter.dart test/data/export/purchase_order_exporter_test.dart
git commit -m "feat: save purchase orders through a system save dialog" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: 발주서 화면

**Files:**
- Create: `lib/features/purchase_order/purchase_order_screen.dart`
- Test: `test/features/purchase_order/purchase_order_screen_test.dart`

**Interfaces:**
- Consumes: Task 1의 `PurchaseOrder*`, `suggestOrderQty`, `buildPurchaseOrder`, `formatPurchaseOrderDate`, Task 4의 `purchaseOrderExporterProvider`, `PurchaseOrderExporter`, 9-1의 `StockShortage`, 기존 `supplierDaoProvider`, `AppCard`, `SectionLabel`, `CenteredContent`, `EmptyState`, `formatQty`
- Produces: `class PurchaseOrderScreen extends ConsumerStatefulWidget` — 생성자 `PurchaseOrderScreen({super.key, required Store store, required List<StockShortage> shortages})`. 위젯 키: `supplierDropdown`, `check_<ingredientId>`, `qty_<ingredientId>`, `savePdfButton`, `saveXlsxButton`.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/features/purchase_order/purchase_order_screen_test.dart`:

```dart
import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/data/export/purchase_order_exporter.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/domain/purchase_order.dart';
import 'package:stockcontrol/domain/stock_shortage.dart';
import 'package:stockcontrol/features/purchase_order/purchase_order_screen.dart';

const ulsan = Store(id: 'store-1', name: '울산점');

Ingredient makeIngredient(int id, String name) => Ingredient(
  id: id,
  name: name,
  baseUnit: 'g',
  purchaseUnit: '박스',
  conversionFactor: 20000,
  isExpiryTracked: false,
  safetyStockQty: 5000,
  createdAt: DateTime(2026, 10, 1),
);

StockShortage makeShortage(int id, String name, {double current = 1200}) =>
    StockShortage(
      ingredient: makeIngredient(id, name),
      store: ulsan,
      currentQty: current,
    );

/// 저장 요청을 기록만 하는 가짜.
class FakeExporter implements PurchaseOrderExporter {
  final saved = <({PurchaseOrder order, PurchaseOrderFormat format})>[];
  Future<String?> Function()? onSave;
  String? result = '저장위치/발주서.pdf';

  @override
  Future<String?> save(PurchaseOrder order, PurchaseOrderFormat format) async {
    saved.add((order: order, format: format));
    final handler = onSave;
    if (handler != null) return handler();
    return result;
  }
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(
        name: '가나다상사',
        contact: const Value('010-1234-5678'),
      ),
    );
  });

  tearDown(() => db.close());

  Future<FakeExporter> pumpScreen(
    WidgetTester tester, {
    List<StockShortage>? shortages,
  }) async {
    final exporter = FakeExporter();
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          purchaseOrderExporterProvider.overrideWithValue(exporter),
        ],
        child: MaterialApp(
          home: PurchaseOrderScreen(
            store: ulsan,
            shortages:
                shortages ??
                [
                  makeShortage(1, '양파'),
                  makeShortage(2, '당근', current: 0),
                ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return exporter;
  }

  Future<void> disposeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> pickSupplier(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(const Key('supplierDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  VoidCallback? onPressed(WidgetTester tester, String key) =>
      tester.widget<FilledButton>(find.byKey(Key(key))).onPressed;

  String qtyText(WidgetTester tester, int id) => tester
      .widget<TextField>(find.byKey(Key('qty_$id')))
      .controller!
      .text;

  testWidgets('열면 수량이 부족분을 구매 단위로 올린 값으로 채워져 있다', (tester) async {
    await pumpScreen(tester);

    // 양파: 3,800g 부족 → 1박스, 당근: 5,000g 부족 → 1박스
    expect(qtyText(tester, 1), '1');
    expect(qtyText(tester, 2), '1');

    await disposeScreen(tester);
  });

  testWidgets('거래처를 고르기 전에는 저장 버튼이 눌리지 않는다', (tester) async {
    await pumpScreen(tester);

    expect(onPressed(tester, 'savePdfButton'), isNull);
    expect(onPressed(tester, 'saveXlsxButton'), isNull);

    await pickSupplier(tester, '가나다상사');

    expect(onPressed(tester, 'savePdfButton'), isNotNull);
    expect(onPressed(tester, 'saveXlsxButton'), isNotNull);

    await disposeScreen(tester);
  });

  testWidgets('고친 수량과 고른 거래처가 발주서에 담겨 저장된다', (tester) async {
    final exporter = await pumpScreen(tester);
    await pickSupplier(tester, '가나다상사');

    await tester.enterText(find.byKey(const Key('qty_1')), '3');
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveXlsxButton')));
    await tester.pump();

    final call = exporter.saved.single;
    expect(call.format, PurchaseOrderFormat.xlsx);
    expect(call.order.store.id, 'store-1');
    expect(call.order.supplier.name, '가나다상사');
    expect(
      call.order.lines.map((l) => (l.ingredient.name, l.qty)).toList(),
      [('양파', 3), ('당근', 1)],
    );

    await disposeScreen(tester);
  });

  testWidgets('PDF 저장 버튼은 PDF 형식으로 저장을 요청한다', (tester) async {
    final exporter = await pumpScreen(tester);
    await pickSupplier(tester, '가나다상사');

    await tester.tap(find.byKey(const Key('savePdfButton')));
    await tester.pump();

    expect(exporter.saved.single.format, PurchaseOrderFormat.pdf);

    await disposeScreen(tester);
  });

  testWidgets('체크를 해제한 품목은 발주서에서 빠진다', (tester) async {
    final exporter = await pumpScreen(tester);
    await pickSupplier(tester, '가나다상사');

    await tester.tap(find.byKey(const Key('check_2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('savePdfButton')));
    await tester.pump();

    expect(exporter.saved.single.order.lines.map((l) => l.ingredient.name), [
      '양파',
    ]);

    await disposeScreen(tester);
  });

  testWidgets('수량을 0으로 하면 그 줄이 빠지고, 모두 0이면 저장할 수 없다', (tester) async {
    final exporter = await pumpScreen(tester);
    await pickSupplier(tester, '가나다상사');

    await tester.enterText(find.byKey(const Key('qty_1')), '0');
    await tester.pump();
    await tester.tap(find.byKey(const Key('savePdfButton')));
    await tester.pump();
    expect(exporter.saved.single.order.lines.map((l) => l.ingredient.name), [
      '당근',
    ]);

    await tester.enterText(find.byKey(const Key('qty_2')), '0');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(onPressed(tester, 'savePdfButton'), isNull);
    expect(onPressed(tester, 'saveXlsxButton'), isNull);

    await disposeScreen(tester);
  });

  testWidgets('수량칸에는 숫자가 아닌 글자가 들어가지 않고 그 줄은 빠진다', (tester) async {
    final exporter = await pumpScreen(tester);
    await pickSupplier(tester, '가나다상사');

    await tester.enterText(find.byKey(const Key('qty_1')), 'abc');
    await tester.pump();

    expect(qtyText(tester, 1), '');
    await tester.tap(find.byKey(const Key('savePdfButton')));
    await tester.pump();
    expect(exporter.saved.single.order.lines.map((l) => l.ingredient.name), [
      '당근',
    ]);

    await disposeScreen(tester);
  });

  testWidgets('거래처가 하나도 없으면 먼저 등록하라고 안내한다', (tester) async {
    await db.delete(db.suppliers).go();

    await pumpScreen(tester);

    expect(find.text('거래처 관리에서 거래처를 먼저 등록하세요'), findsOneWidget);
    expect(find.byKey(const Key('supplierDropdown')), findsNothing);
    expect(onPressed(tester, 'savePdfButton'), isNull);

    await disposeScreen(tester);
  });

  testWidgets('부족한 품목이 없으면 안내만 보이고 저장 버튼은 없다', (tester) async {
    await pumpScreen(tester, shortages: const []);

    expect(find.text('부족한 품목이 없습니다'), findsOneWidget);
    expect(find.byKey(const Key('savePdfButton')), findsNothing);

    await disposeScreen(tester);
  });

  testWidgets('열어 둔 동안 재고가 바뀌어도 입력한 수량이 덮이지 않는다', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.byKey(const Key('qty_1')), '7');
    await tester.pump();

    // 같은 매장의 재고를 충분히 채운다. 부족 목록을 계속 지켜보는 화면이었다면
    // 이 변경으로 줄이 사라지거나 수량이 제안값으로 되돌아간다.
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-1', name: '울산점'),
    );
    final ingredientId = await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
        safetyStockQty: const Value(5000),
      ),
    );
    await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        storeId: const Value('store-1'),
        receivedDate: DateTime(2026, 10, 1),
        unitCost: 10,
        remainingQty: 99999,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('qty_1')), findsOneWidget);
    expect(qtyText(tester, 1), '7');

    await disposeScreen(tester);
  });

  testWidgets('저장하면 저장했다는 메시지가 보인다', (tester) async {
    final exporter = await pumpScreen(tester);
    exporter.result = 'C:\\문서\\발주서.pdf';
    await pickSupplier(tester, '가나다상사');

    await tester.tap(find.byKey(const Key('savePdfButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('저장했습니다: C:\\문서\\발주서.pdf'), findsOneWidget);

    await disposeScreen(tester);
  });

  testWidgets('저장 창을 취소하면 아무 메시지도 뜨지 않는다', (tester) async {
    final exporter = await pumpScreen(tester);
    exporter.result = null;
    await pickSupplier(tester, '가나다상사');

    await tester.tap(find.byKey(const Key('savePdfButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);

    await disposeScreen(tester);
  });

  testWidgets('저장이 실패하면 이유를 보여주고 다시 시도할 수 있다', (tester) async {
    final exporter = await pumpScreen(tester);
    exporter.onSave = () async => throw StateError('디스크가 가득 찼습니다');
    await pickSupplier(tester, '가나다상사');

    await tester.tap(find.byKey(const Key('savePdfButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('저장하지 못했습니다'), findsOneWidget);
    expect(onPressed(tester, 'savePdfButton'), isNotNull);

    await disposeScreen(tester);
  });

  testWidgets('저장하는 동안 다시 눌러도 한 번만 저장한다', (tester) async {
    final exporter = await pumpScreen(tester);
    final done = Completer<String?>();
    exporter.onSave = () => done.future;
    await pickSupplier(tester, '가나다상사');

    await tester.tap(find.byKey(const Key('savePdfButton')));
    await tester.pump();

    // 끝나기 전에는 두 버튼 모두 눌리지 않는다.
    expect(onPressed(tester, 'savePdfButton'), isNull);
    expect(onPressed(tester, 'saveXlsxButton'), isNull);
    expect(exporter.saved, hasLength(1));

    done.complete('발주서.pdf');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(onPressed(tester, 'savePdfButton'), isNotNull);
    expect(exporter.saved, hasLength(1));

    await disposeScreen(tester);
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/features/purchase_order/purchase_order_screen_test.dart --timeout 60s --reporter expanded *> $env:TEMP\flutter-test.log; Get-Content $env:TEMP\flutter-test.log -Tail 25`
Expected: FAIL — `purchase_order_screen.dart` 파일이 없어 컴파일 에러

- [ ] **Step 3: 화면 작성**

`lib/features/purchase_order/purchase_order_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/quantity_format.dart';
import '../../core/providers/dao_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/export/purchase_order_exporter.dart';
import '../../data/local/database.dart';
import '../../domain/purchase_order.dart';
import '../../domain/stock_shortage.dart';

final _suppliersProvider = StreamProvider<List<Supplier>>(
  (ref) => ref.watch(supplierDaoProvider).watchAll(),
);

class PurchaseOrderScreen extends ConsumerStatefulWidget {
  const PurchaseOrderScreen({
    super.key,
    required this.store,
    required this.shortages,
  });

  /// 발주할 매장. 발주서는 매장 하나 단위다.
  final Store store;

  /// 이 매장의 부족 품목. 화면을 열 때 복사해서 넘긴 값이라, 화면을 보는
  /// 중에 동기화로 재고가 바뀌어도 입력 중인 수량은 바뀌지 않는다. 모두
  /// [store]의 것이어야 한다.
  final List<StockShortage> shortages;

  @override
  ConsumerState<PurchaseOrderScreen> createState() =>
      _PurchaseOrderScreenState();
}

class _PurchaseOrderScreenState extends ConsumerState<PurchaseOrderScreen> {
  final _qtyControllers = <int, TextEditingController>{};
  final _unchecked = <int>{};
  late final DateTime _date;
  int? _supplierId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    for (final shortage in widget.shortages) {
      _qtyControllers[shortage.ingredient.id] = TextEditingController(
        text: '${suggestOrderQty(shortage)}',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _qtyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// 입력칸의 수량. 비었거나 숫자가 아니면 0이라 발주서에서 빠진다.
  int _qtyOf(StockShortage shortage) =>
      int.tryParse(_qtyControllers[shortage.ingredient.id]!.text.trim()) ?? 0;

  /// 지금 입력한 상태로 만들 수 있는 발주서. 거래처를 안 골랐거나 담을 줄이
  /// 하나도 없으면 null이라 저장 버튼이 눌리지 않는다.
  PurchaseOrder? _currentOrder(Supplier? supplier) {
    if (supplier == null) return null;
    final order = buildPurchaseOrder(
      store: widget.store,
      supplier: supplier,
      date: _date,
      lines: [
        for (final shortage in widget.shortages)
          if (!_unchecked.contains(shortage.ingredient.id))
            PurchaseOrderLine(
              ingredient: shortage.ingredient,
              qty: _qtyOf(shortage),
            ),
      ],
    );
    return order.lines.isEmpty ? null : order;
  }

  Future<void> _save(PurchaseOrder order, PurchaseOrderFormat format) async {
    setState(() => _saving = true);
    try {
      final shown = await ref
          .read(purchaseOrderExporterProvider)
          .save(order, format);
      if (!mounted) return;
      // 저장 창을 취소하면 null이다. 사용자가 일부러 닫은 것이라 아무 말도
      // 하지 않는다.
      if (shown != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장했습니다: $shown')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장하지 못했습니다: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliers =
        ref.watch(_suppliersProvider).valueOrNull ?? const <Supplier>[];
    Supplier? supplier;
    for (final s in suppliers) {
      if (s.id == _supplierId) supplier = s;
    }
    final order = _currentOrder(supplier);
    final hasShortages = widget.shortages.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('발주서 만들기')),
      body: hasShortages
          ? CenteredContent(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildInfoCard(suppliers),
                  const SizedBox(height: 12),
                  _buildLinesCard(),
                ],
              ),
            )
          : const EmptyState(
              icon: Icons.check_circle_outline,
              title: '부족한 품목이 없습니다',
              message: '이 매장은 안전재고 기준을 모두 채우고 있어 발주할 품목이 없습니다',
            ),
      bottomNavigationBar: hasShortages ? _buildSaveBar(order) : null,
    );
  }

  Widget _buildInfoCard(List<Supplier> suppliers) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('발주 정보'),
          _InfoRow(label: '매장', value: widget.store.name),
          _InfoRow(label: '발주일', value: formatPurchaseOrderDate(_date)),
          const SizedBox(height: 8),
          if (suppliers.isEmpty)
            const Text(
              '거래처 관리에서 거래처를 먼저 등록하세요',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            )
          else
            // 선택한 객체가 아니라 id를 값으로 쓴다. 객체를 붙잡으면 그 행이
            // 바뀔 때 목록의 항목과 같지 않게 되어 드롭다운이 깨진다.
            DropdownButtonFormField<int>(
              key: const Key('supplierDropdown'),
              initialValue: _supplierId,
              decoration: const InputDecoration(labelText: '거래처'),
              items: [
                for (final s in suppliers)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (value) => setState(() => _supplierId = value),
            ),
        ],
      ),
    );
  }

  Widget _buildLinesCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('발주 품목'),
          for (final shortage in widget.shortages) _buildLine(shortage),
        ],
      ),
    );
  }

  Widget _buildLine(StockShortage shortage) {
    final id = shortage.ingredient.id;
    final checked = !_unchecked.contains(id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            key: Key('check_$id'),
            value: checked,
            onChanged: (value) => setState(() {
              if (value ?? false) {
                _unchecked.remove(id);
              } else {
                _unchecked.add(id);
              }
            }),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shortage.ingredient.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textStrong,
                  ),
                ),
                Text(
                  '부족 ${formatQty(shortage.shortfall)}'
                  '${shortage.ingredient.baseUnit}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: TextField(
              key: Key('qty_$id'),
              controller: _qtyControllers[id],
              enabled: checked,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.end,
              decoration: const InputDecoration(isDense: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 72),
            child: Text(
              shortage.ingredient.purchaseUnit,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar(PurchaseOrder? order) {
    // 저장하는 동안에는 두 버튼 모두 막는다. 파일 만들기와 저장 창이 느릴 때
    // 두 번 누르면 같은 발주서가 두 번 저장된다.
    final current = order;
    VoidCallback? handlerFor(PurchaseOrderFormat format) =>
        (current == null || _saving) ? null : () => _save(current, format);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: FilledButton(
                key: const Key('savePdfButton'),
                onPressed: handlerFor(PurchaseOrderFormat.pdf),
                child: const Text('PDF 저장'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('saveXlsxButton'),
                onPressed: handlerFor(PurchaseOrderFormat.xlsx),
                child: const Text('엑셀 저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textStrong,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: Step 2와 같은 명령
Expected: PASS (14 tests)

실패하면 에러 원문을 먼저 읽는다. 특히 `pickSupplier`가 실패하면 드롭다운 항목 글자를 `find.text(...).last`가 못 찾는 것이니 `pumpAndSettle` 뒤 화면을 확인한다.

- [ ] **Step 5: 변이로 테스트가 실제로 무는지 확인**

아직 커밋 전이므로 **편집 도구로 정확히 되돌린다** (`git checkout`을 쓰면 작업이 날아간다). 각 변이마다 Step 2의 테스트를 돌려서 **실패하는지** 본 뒤 원래대로 되돌린다.

1. `_save`의 `setState(() => _saving = true);`를 `setState(() {});`로 → "저장하는 동안 다시 눌러도 한 번만 저장한다"가 실패해야 한다.
2. `inputFormatters: [FilteringTextInputFormatter.digitsOnly],` 줄을 지워서 → "수량칸에는 숫자가 아닌 글자가…"가 실패해야 한다.
3. `if (shown != null) {`를 `{`로(조건 제거) → "저장 창을 취소하면 아무 메시지도 뜨지 않는다"가 실패해야 한다.

세 변이를 모두 되돌린 뒤 Step 2를 다시 돌려 14개가 통과하는지 확인한다.

- [ ] **Step 6: 정적 분석과 포맷**

Run: `dart format lib/features/purchase_order/purchase_order_screen.dart test/features/purchase_order/purchase_order_screen_test.dart; flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```powershell
git add lib/features/purchase_order test/features/purchase_order
git commit -m "feat: add the purchase order screen" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: 부족 재고 화면에서 발주서로 진입

**Files:**
- Modify: `lib/features/shortage/shortage_screen.dart`
- Test: `test/features/shortage/shortage_screen_test.dart`

**Interfaces:**
- Consumes: Task 5의 `PurchaseOrderScreen({store, shortages})`, 9-1의 `shortagesProvider`, `shortageStoresProvider`, 기존 `selectedStoreProvider`, `authSessionProvider`
- Produces: 동작 변경 — 사장 계정의 부족 재고 화면 위쪽에 "발주서 만들기" 버튼(키 `purchaseOrderButton`)이 생긴다.

- [ ] **Step 1: 실패하는 테스트 추가**

`test/features/shortage/shortage_screen_test.dart` 맨 위 import 목록에 추가한다:

```dart
import 'package:stockcontrol/features/purchase_order/purchase_order_screen.dart';
```

같은 파일 맨 끝(`}` 앞)에 추가한다. 이 파일에는 이미 `addTrackedIngredient`, `pumpScreen`, `disposeScreen`, `owner()`, `staff()`와 `store-1`(울산점), `store-2`(부산점)가 있다:

```dart

  testWidgets('전체 합산을 보는 사장은 발주서를 만들 수 없고 이유가 보인다', (tester) async {
    await addTrackedIngredient('양파', 5000);

    await pumpScreen(tester, owner());

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('purchaseOrderButton')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('매장을 고르면 발주서를 만들 수 있습니다'), findsOneWidget);

    await disposeScreen(tester);
  });

  testWidgets('직원 계정에는 발주서 만들기 버튼이 없다', (tester) async {
    await addTrackedIngredient('양파', 5000);

    await pumpScreen(tester, staff(storeId: 'store-1'));

    expect(find.byKey(const Key('purchaseOrderButton')), findsNothing);

    await disposeScreen(tester);
  });

  testWidgets('매장을 고른 사장이 누르면 그 매장의 부족 품목으로 발주서 화면이 열린다',
      (tester) async {
    final id = await addTrackedIngredient('양파', 5000);

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    container.read(authSessionProvider.notifier).setSession(owner());
    container.read(selectedStoreProvider.notifier).state = const Store(
      id: 'store-1',
      name: '울산점',
    );

    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ShortageScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const Key('purchaseOrderButton')));
    await tester.pumpAndSettle();

    final screen = tester.widget<PurchaseOrderScreen>(
      find.byType(PurchaseOrderScreen),
    );
    expect(screen.store.id, 'store-1');
    expect(screen.shortages, hasLength(1));
    expect(screen.shortages.single.store.id, 'store-1');
    expect(screen.shortages.single.ingredient.id, id);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/features/shortage/shortage_screen_test.dart --timeout 60s --reporter expanded *> $env:TEMP\flutter-test.log; Get-Content $env:TEMP\flutter-test.log -Tail 25`
Expected: FAIL — `purchaseOrderButton`을 찾을 수 없다

- [ ] **Step 3: 진입 버튼 추가**

`lib/features/shortage/shortage_screen.dart` 맨 위 import에 두 줄을 추가한다 (알파벳 순서 위치에):

```dart
import '../../data/local/database.dart';
```

```dart
import '../purchase_order/purchase_order_screen.dart';
```

`build`의 `body:` 부분을 아래로 교체한다. 지금은 이렇게 생겼다:

```dart
      body: shortages.isEmpty
          ? _buildEmpty(
              hasTrackedIngredient: hasTrackedIngredient,
              hasStoreInScope: hasStoreInScope,
              isOwner: isOwner,
              hasAssignedStore: session?.storeId != null,
            )
          : _buildGrid(shortages, showStoreName: isOwner),
```

교체할 내용:

```dart
      body: Column(
        children: [
          // 발주는 사장이 한다. 판정할 매장이 없으면 빈 상태 안내가 이미 매장
          // 등록을 알려주므로 버튼은 보이지 않는다.
          if (isOwner && hasStoreInScope)
            _PurchaseOrderBar(shortages: shortages),
          Expanded(
            child: shortages.isEmpty
                ? _buildEmpty(
                    hasTrackedIngredient: hasTrackedIngredient,
                    hasStoreInScope: hasStoreInScope,
                    isOwner: isOwner,
                    hasAssignedStore: session?.storeId != null,
                  )
                : _buildGrid(shortages, showStoreName: isOwner),
          ),
        ],
      ),
```

같은 파일 맨 끝에 클래스를 추가한다:

```dart

/// "발주서 만들기" 버튼. 발주서는 매장 하나 단위라서 사장이 전체 합산을
/// 보는 중에는 누를 수 없다.
class _PurchaseOrderBar extends ConsumerWidget {
  const _PurchaseOrderBar({required this.shortages});

  final List<StockShortage> shortages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(selectedStoreProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (store == null)
              const Flexible(
                child: Text(
                  '매장을 고르면 발주서를 만들 수 있습니다',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ),
            const SizedBox(width: 12),
            FilledButton.icon(
              key: const Key('purchaseOrderButton'),
              onPressed: store == null ? null : () => _open(context, store),
              icon: const Icon(Icons.description_outlined),
              label: const Text('발주서 만들기'),
            ),
          ],
        ),
      ),
    );
  }

  /// 누른 순간의 부족 목록을 복사해서 넘긴다. 발주서 화면이 부족 목록을 계속
  /// 지켜보면, 입력 중에 동기화로 재고가 바뀔 때 수량이 덮인다.
  void _open(BuildContext context, Store store) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PurchaseOrderScreen(
          store: store,
          shortages: [
            for (final shortage in shortages)
              if (shortage.store.id == store.id) shortage,
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: Step 2와 같은 명령
Expected: PASS (기존 테스트 + 신규 3개). 기존 카드 키 테스트가 그대로 통과해야 한다 — 본문을 `Column`으로 감쌌지만 카드 키는 바뀌지 않았다.

- [ ] **Step 5: 전체 테스트와 정적 분석**

Run: `dart format lib/features/shortage/shortage_screen.dart test/features/shortage/shortage_screen_test.dart; flutter analyze lib test`
Expected: `No issues found!`

Run: `flutter test --timeout 90s --reporter compact *> $env:TEMP\flutter-test.log; Get-Content $env:TEMP\flutter-test.log -Tail 3`
Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```powershell
git add lib/features/shortage/shortage_screen.dart test/features/shortage/shortage_screen_test.dart
git commit -m "feat: open the purchase order screen from the shortage screen" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 7: 변이로 사장 전용 조건이 실제로 막는지 확인**

커밋된 뒤이므로 `git checkout`으로 되돌릴 수 있다.

`shortage_screen.dart`의 `if (isOwner && hasStoreInScope)`를 `if (hasStoreInScope)`로 바꾸고 Step 2의 테스트를 돌린다. "직원 계정에는 발주서 만들기 버튼이 없다"가 **실패해야 한다.**

Run: `git checkout -- lib/features/shortage/shortage_screen.dart; git status --porcelain`
Expected: 출력이 비어 있다 (작업 트리 깨끗).

---

### Task 7: 수동 확인 (사용자)

**Files:** 코드 변경 없음. 사용자가 앱을 직접 열어 확인한다.

**왜 필요한가:** 자동 테스트가 못 잡는 것이 세 가지 있다 — PDF에서 **한글이 실제로 깨지지 않는지**, **저장 창이 실제로 뜨고 파일이 생기는지**, **Android에서 저장한 파일을 찾을 수 있는지**. 패키지 세 개를 추가했으므로 **Windows와 Android 빌드가 처음으로 새 플러그인을 포함한다.** 빌드가 실패하면 그 에러를 그대로 알려준다.

- [ ] **Step 1: 앱 두 개 실행**

실행 중이면 끈다 (켜진 채로 빌드하면 Windows에서 `LNK1168`이 난다).

```powershell
flutter run -d windows
flutter run -d emulator-5554
```

- [ ] **Step 2: Windows — 사장 계정으로 발주서 만들기**

안전재고를 설정해 둔 품목이 부족한 매장을 고른다. 부족 재고 화면 위쪽의 **발주서 만들기**를 누른다.

- 제안 수량이 맞는가? 실제 품목 하나를 손으로 계산해서 대조한다. (예: 3,800g 부족, 1박스 = 20,000g이면 1박스)
- 거래처를 고르고 수량을 고쳐 본다. 체크를 해제하면 그 품목이 빠지는가?

- [ ] **Step 3: Windows — PDF 저장**

**PDF 저장**을 누르고 저장 창에서 위치를 고른다. 저장한 PDF를 연다.

- **한글이 깨지지 않았는가?** (제목, 매장, 거래처, 품목 이름) — 이것이 자동 테스트가 못 잡는 부분이다.
- 파일 이름이 `발주서_{매장}_{거래처}_{날짜}.pdf`인가?
- 저장 후 화면 아래에 `저장했습니다: {경로}`가 뜨는가?
- 저장 창에서 **취소**하면 아무 메시지가 뜨지 않는가?

- [ ] **Step 4: Windows — 엑셀 저장**

**엑셀 저장**으로 저장한 파일을 엑셀로 연다.

- 시트 이름이 `발주서`이고, 한글이 깨지지 않고, 수량이 숫자로 들어가고, 열 너비가 읽을 만한가?
- 비고 칸이 비어 있어서 직접 적을 수 있는가?

- [ ] **Step 5: 전체 합산 상태와 직원 계정**

- 사장 계정에서 상단 매장 선택을 **전체 합산**으로 바꾼다. 발주서 만들기 버튼이 막히고 "매장을 고르면 발주서를 만들 수 있습니다"가 보이는가?
- 에뮬레이터에서 **직원 계정**으로 로그인한다. 부족 재고 화면에 발주서 만들기 버튼이 **없는가?**

- [ ] **Step 6: Android — 저장한 파일을 찾을 수 있는가**

에뮬레이터에서 사장 계정으로 PDF를 저장한다. 시스템 저장 창에서 폴더를 고르고(예: Downloads), 저장 후 **파일 관리자 앱에서 그 파일이 보이는가?** 화면 아래 메시지에는 경로가 아니라 파일 이름이 뜬다.

- [ ] **Step 7: 결과 알려주기**

각 단계가 되는지 안 되는지만 알려준다. 실패한 단계는 증상(화면에 무엇이 어떻게 보였는지, 에러 문구)을 함께 준다.

---

## Self-Review 결과

**스펙 커버리지**: 부족 재고 화면 진입(사장 전용, 전체 합산 막힘, 열 때 복사) — Task 6 / 거래처 선택·품목 체크·수량 수정 — Task 5 / 수량 제안(올림, 환산계수 방어) — Task 1 / 0 이하 줄 제외 — Task 1, Task 5 / PDF — Task 3 / 엑셀 — Task 2 / 한글 글꼴과 라이선스 — Task 3 / 저장 창과 저장 결과 문구 — Task 4, Task 5 / 파일 이름 — Task 1 / 새 테이블·동기화·SQL 없음 — 어느 Task에도 없음(Global Constraints) / 수동 확인 — Task 7.

**스펙 결정 번호별**: 8(전체 합산 막힘) Task 6, 9(열 때 복사) Task 5·6, 10(0 이하 제외) Task 1·5, 11(환산계수 방어) Task 1, 12(보정 안 함) — 별도 코드 없음. 거래처 드롭다운 방어(스펙 "아키텍처" 화면 절) — id 값으로 쓰는 것으로 해결, Task 5.

**타입 일관성**: `PurchaseOrder{store, supplier, date, lines}`와 `PurchaseOrderLine{ingredient, qty}`가 Task 1에서 정의되고 Task 2·3·4·5의 테스트와 구현에서 같은 필드명으로 쓰인다. `PurchaseOrderFormat.fileExtension`/`mimeType`이 Task 1·4에서 일치한다. `buildPurchaseOrderPdf(order, {regularFont, boldFont})`가 Task 3 정의, Task 4 호출에서 일치한다. `purchaseOrderExporterProvider`가 Task 4 정의, Task 5 테스트 override에서 일치한다. `PurchaseOrderScreen({store, shortages})`가 Task 5 정의, Task 6 호출과 테스트에서 일치한다. 위젯 키 `purchaseOrderButton`이 Task 6 정의와 테스트에서 일치한다.

**Review Focus 반영**: 파일 이름 금지 문자 — Task 1의 네 번째 파일 이름 테스트 / 환산계수 0·NaN — Task 1의 네 번째 수량 제안 테스트 / 저장 창 취소 — Task 4의 세 번째 테스트와 Task 5의 취소 테스트 / 수량칸 비정상 입력 — Task 5의 "숫자가 아닌 글자" 테스트와 "0" 테스트 / 저장 중 중복 누름 — Task 5의 마지막 테스트와 Step 5 변이 1번.

**알려진 한계 (의도적으로 범위 밖)**: PDF 한글 모양과 Android 저장 위치는 자동 테스트로 확인할 수 없어 Task 7로 뺐다. 여러 매장을 합친 발주, 발주 이력, 공유·인쇄, 거래처-품목 연결은 스펙대로 범위 밖이다. 수량 제안이 안전재고까지만 채우는 양이라 도착하자마자 다시 기준선에 걸릴 수 있다 — 어디까지나 고칠 수 있는 제안값이다.
