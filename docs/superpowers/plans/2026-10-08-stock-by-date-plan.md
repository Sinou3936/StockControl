# 날짜별 재고 조회 구현 계획

> **에이전트 작업자에게:** 서브에이전트 방식(작업마다 새 구현자 → 독립 검토)으로 진행한다. 단계는 체크박스(`- [ ]`)로 추적한다. 스펙: `docs/superpowers/specs/2026-10-08-stock-by-date-design.md` — 먼저 읽는다.

**목표:** 재고 조회 화면에 날짜 선택을 더해, 고른 날짜 끝 기준 재고와 그날 들어온 재고 목록을 보여준다.

**구조:** 과거 날짜의 재고는 새로 저장하지 않고 `StockMovement`를 로트별로 더해 구한다 (`StockMovementDao`의 새 쿼리 2개). 오늘은 지금처럼 `Lot.remainingQty`를 쓴다. 날짜 선택값은 `StateProvider`에 두고 화면이 읽는다. 지난 날짜는 조회 전용(탭·화살표·임박 표시 없음).

**기술:** Flutter, Riverpod, Drift. 새 테이블·동기화·마이그레이션 없음 (생성 코드 `*.g.dart`도 다시 만들 필요 없음 — DAO에 메서드만 더한다).

---

## 모든 작업에 적용되는 제약

- **`flutter test`는 한 번에 하나만.** 항상 `--timeout`을 주고 출력은 파일로: `flutter test <경로> --timeout 60s --reporter expanded *> $env:TEMP\t.log; Get-Content $env:TEMP\t.log -Tail 25`. 멈추면 `Get-Process dart,flutter_tester | Stop-Process -Force`.
- `testWidgets` 안에서 `await dao.watchAll().first` 금지 (영원히 멈춘다). 값은 `await db.select(db.table).get()`. **DAO 쿼리 테스트는 일반 `test`라서 `.first`를 써도 된다.**
- 위젯 테스트는 끝에 `await tester.pumpWidget(const SizedBox.shrink()); await tester.pump(const Duration(milliseconds: 1));`.
- `package:drift/drift.dart`를 테스트에서 가져오고 `isNull`/`isNotNull`을 쓰면 `hide isNotNull, isNull`.
- 시각 의존: 도메인·DAO 테스트는 **고정 날짜**(`DateTime(2026, 10, 5, …)`)를 쓴다. 위젯 테스트에서 "며칠 전"이 필요하면 `now` 기준 상대 날짜를 쓰되 날짜 선택은 provider override로 한다 (달력 위젯을 눌러 날짜를 고르지 않는다 — 월 경계에서 깨진다).
- Drift는 `DateTime`을 초 단위로 저장한다. 경계 테스트는 초 단위 값만 쓴다.
- 커밋: 작업마다 한 개 이상. `git add`는 경로를 직접 적는다. 메시지는 영어, `-m`을 두 번 (두 번째가 `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`). `dart format`은 건드린 파일에만, 기존 줄이 바뀌면 되돌리고 자기 코드만 포맷한다. **푸시하지 않는다.**
- 각 작업의 끝: 해당 테스트 통과 + `flutter analyze lib test` 깨끗. 전체 테스트는 작업 5에서 한다 (시작 시 276개).
- 보고서 파일 쓰기가 거절되면 최종 메시지에 담는다: RED/GREEN 실제 출력, 변이 결과, 커밋 해시.

## 파일 구조

| 파일 | 일 |
|---|---|
| `lib/domain/stock_by_date.dart` (새) | 하루 경계, 날짜 선택 규칙, 날짜 라벨, `InboundEntry` |
| `lib/domain/stock_overview.dart` (수정) | `groupLotsByIngredient`에 `flagNearExpiry` 추가 |
| `lib/data/local/daos/stock_movement_dao.dart` (수정) | `watchStockAsOf`, `watchInboundOn` |
| `lib/core/providers/stock_date_providers.dart` (새) | `selectedStockDateProvider` |
| `lib/features/stock_overview/stock_overview_screen.dart` (수정) | 날짜 버튼, 조회 전용 안내, 지난 날짜 렌더링 |
| `lib/features/stock_overview/inbound_day_card.dart` (새) | "이 날 입고 N건" 카드 |
| `test/domain/stock_by_date_test.dart` (새) | 도메인 규칙 |
| `test/domain/stock_overview_test.dart` (수정) | `flagNearExpiry` |
| `test/data/local/stock_movement_by_date_test.dart` (새) | 두 쿼리 |
| `test/features/stock_overview/stock_overview_screen_test.dart` (수정) | 화면 |

---

## 작업 1: 도메인 규칙

**파일:** 새 `lib/domain/stock_by_date.dart`, 수정 `lib/domain/stock_overview.dart`, 새 `test/domain/stock_by_date_test.dart`, 수정 `test/domain/stock_overview_test.dart`.

- [ ] **1-1. 실패하는 테스트를 쓴다** — `test/domain/stock_by_date_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/domain/stock_by_date.dart';

void main() {
  group('하루 경계', () {
    test('dayStart는 시각을 지우고 dayEnd는 다음 날 0시다', () {
      final d = DateTime(2026, 10, 5, 14, 30, 15);
      expect(dayStart(d), DateTime(2026, 10, 5));
      expect(dayEnd(d), DateTime(2026, 10, 6));
    });

    test('dayEnd는 달·해 경계를 넘는다', () {
      expect(dayEnd(DateTime(2026, 10, 31)), DateTime(2026, 11, 1));
      expect(dayEnd(DateTime(2026, 12, 31)), DateTime(2027, 1, 1));
    });

    test('isSameDay는 시각을 무시한다', () {
      expect(
        isSameDay(DateTime(2026, 10, 5, 0, 0), DateTime(2026, 10, 5, 23, 59)),
        isTrue,
      );
      expect(
        isSameDay(DateTime(2026, 10, 5, 23, 59), DateTime(2026, 10, 6, 0, 0)),
        isFalse,
      );
    });
  });

  group('stockDateSelection', () {
    final now = DateTime(2026, 10, 8, 15, 0);

    test('오늘을 고르면 null (= 오늘)', () {
      expect(stockDateSelection(DateTime(2026, 10, 8), now: now), isNull);
      expect(stockDateSelection(DateTime(2026, 10, 8, 9), now: now), isNull);
    });

    test('다른 날을 고르면 시각을 지운 그 날짜', () {
      expect(
        stockDateSelection(DateTime(2026, 10, 5, 13), now: now),
        DateTime(2026, 10, 5),
      );
    });
  });

  group('stockDateLabel', () {
    final now = DateTime(2026, 10, 8);

    test('null이거나 오늘이면 "오늘"', () {
      expect(stockDateLabel(null, now: now), '오늘');
      expect(stockDateLabel(DateTime(2026, 10, 8), now: now), '오늘');
    });

    test('올해의 다른 날은 월·일만', () {
      expect(stockDateLabel(DateTime(2026, 10, 5), now: now), '10월 5일');
    });

    test('다른 해는 연도를 붙인다', () {
      expect(
        stockDateLabel(DateTime(2025, 12, 31), now: now),
        '2025년 12월 31일',
      );
    });
  });
}
```

`test/domain/stock_overview_test.dart`의 `_groupLotsByIngredientTests()` 안에 아래 테스트를 더한다 (그 파일의 `_makeIngredient`/`_makeLot`/`now`를 쓴다 — 먼저 파일을 읽고 같은 방식으로 맞춘다):

```dart
    test('flagNearExpiry가 false이면 임박 표시도 정렬 우선도 없다', () {
      final onion = _makeIngredient(1, '양파');
      final carrot = _makeIngredient(2, '당근');
      final rows = [
        LotWithIngredient(
          lot: _makeLot(1, 1, expiryDate: now.add(const Duration(days: 1))),
          ingredient: onion,
        ),
        LotWithIngredient(lot: _makeLot(2, 2), ingredient: carrot),
      ];

      final flagged = groupLotsByIngredient(rows, now: now);
      final unflagged =
          groupLotsByIngredient(rows, now: now, flagNearExpiry: false);

      // 켜면 임박한 양파가 먼저, 끄면 가나다순(당근, 양파)에 표시도 없다.
      expect(flagged.map((g) => g.ingredient.name), ['양파', '당근']);
      expect(unflagged.map((g) => g.ingredient.name), ['당근', '양파']);
      expect(unflagged.every((g) => !g.hasNearExpiryLot), isTrue);
    });
```

- [ ] **1-2. 실패를 확인한다** — `flutter test test/domain/stock_by_date_test.dart test/domain/stock_overview_test.dart …`. 기대: 컴파일 오류 (파일·파라미터 없음).

- [ ] **1-3. 구현한다** — `lib/domain/stock_by_date.dart`:

```dart
import 'package:stockcontrol/data/local/database.dart';

/// 그날 00:00 (로컬).
DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

/// 다음 날 00:00 (로컬). "그날 끝"을 표현하는 배타적 상한이다.
DateTime dayEnd(DateTime d) => DateTime(d.year, d.month, d.day + 1);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 달력에서 고른 날짜를 provider에 넣을 값으로. 오늘이면 null("오늘").
DateTime? stockDateSelection(DateTime picked, {required DateTime now}) =>
    isSameDay(picked, now) ? null : dayStart(picked);

/// 날짜 버튼에 쓰는 글자.
String stockDateLabel(DateTime? selected, {required DateTime now}) {
  if (selected == null || isSameDay(selected, now)) return '오늘';
  final monthDay = '${selected.month}월 ${selected.day}일';
  return selected.year == now.year ? monthDay : '${selected.year}년 $monthDay';
}

/// 입고 목록의 한 줄: 입고 기록과 그 로트·품목, 거래처·매장 이름.
class InboundEntry {
  const InboundEntry({
    required this.movement,
    required this.lot,
    required this.ingredient,
    this.supplierName,
    this.storeName,
  });

  final StockMovement movement;
  final Lot lot;
  final Ingredient ingredient;
  final String? supplierName;
  final String? storeName;
}
```

`lib/domain/stock_overview.dart`의 `groupLotsByIngredient`:
- 시그니처에 `bool flagNearExpiry = true`를 더한다 (`{required DateTime now, bool flagNearExpiry = true}`).
- `hasNearExpiryLot: flagNearExpiry && lots.any(...)`.
- 위 파라미터 설명 주석 한 줄: 지난 날짜 조회는 지금 기준의 임박 표시와 정렬을 쓰지 않는다.

- [ ] **1-4. 통과를 확인한다.** 같은 명령. 기대: 모두 통과. `flutter analyze lib test` 깨끗.

- [ ] **1-5. 변이 확인 후 되돌린다.** (a) `dayEnd`를 `d.day`로 바꾸면 경계 테스트 실패. (b) `flagNearExpiry &&`를 지우면 새 `groupLotsByIngredient` 테스트 실패. 각각 `git checkout -- <경로>` 후 `git status --porcelain`에 의도하지 않은 변경이 없는지 본다.

- [ ] **1-6. 커밋.**
```
git add lib/domain/stock_by_date.dart lib/domain/stock_overview.dart test/domain/stock_by_date_test.dart test/domain/stock_overview_test.dart
git commit -m "feat: add day-boundary rules for the stock-by-date view" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## 작업 2: DAO 쿼리 두 개

**파일:** 수정 `lib/data/local/daos/stock_movement_dao.dart`, 새 `test/data/local/stock_movement_by_date_test.dart`.

- [ ] **2-1. 실패하는 테스트를 쓴다** — `test/data/local/stock_movement_by_date_test.dart`. `LotRepository`로 데이터를 만든다 (`receiveLot`은 입고 기록의 `occurredAt`을 `receivedDate`로 쓰고, `recordQuantityChange`는 `occurredAt`을 받는다).

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/data/repositories/lot_repository.dart';
import 'package:stockcontrol/domain/movement_type.dart';
import 'package:stockcontrol/domain/stock_by_date.dart';
import 'package:stockcontrol/domain/stock_overview.dart';

void main() {
  late AppDatabase db;
  late LotRepository repo;
  late int onionId;
  late int carrotId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = LotRepository(db);
    Future<int> ingredient(String name) => db.ingredientDao.insertIngredient(
          IngredientsCompanion.insert(
            name: name,
            baseUnit: 'g',
            purchaseUnit: '박스',
            conversionFactor: 1000,
            isExpiryTracked: false,
          ),
        );
    onionId = await ingredient('양파');
    carrotId = await ingredient('당근');
  });

  tearDown(() => db.close());

  Future<List<LotWithIngredient>> stockAsOf(DateTime day, {String? storeId}) =>
      db.stockMovementDao
          .watchStockAsOf(dayEnd(day), storeId: storeId)
          .first;

  Future<List<InboundEntry>> inboundOn(DateTime day, {String? storeId}) =>
      db.stockMovementDao
          .watchInboundOn(dayStart(day), dayEnd(day), storeId: storeId)
          .first;

  group('watchStockAsOf', () {
    test('그날 이후의 폐기는 빼지 않는다', () async {
      final lotId = await repo.receiveLot(
        ingredientId: onionId,
        receivedDate: DateTime(2026, 10, 5, 9),
        unitCost: 1,
        baseQty: 1000,
      );
      await repo.recordQuantityChange(
        lotId: lotId,
        type: MovementType.disposal,
        quantity: -300,
        occurredAt: DateTime(2026, 10, 7, 10),
      );

      expect((await stockAsOf(DateTime(2026, 10, 5))).single.lot.remainingQty, 1000);
      expect((await stockAsOf(DateTime(2026, 10, 6))).single.lot.remainingQty, 1000);
      expect((await stockAsOf(DateTime(2026, 10, 7))).single.lot.remainingQty, 700);
    });

    test('Lot.remainingQty 사본이 아니라 기록 합계를 읽는다', () async {
      final lotId = await repo.receiveLot(
        ingredientId: onionId,
        receivedDate: DateTime(2026, 10, 5, 9),
        unitCost: 1,
        baseQty: 1000,
      );
      await db.lotDao.updateRemainingQty(lotId, 42);

      expect((await stockAsOf(DateTime(2026, 10, 5))).single.lot.remainingQty, 1000);
    });

    test('그날 이후에 들어온 로트는 나오지 않는다', () async {
      await repo.receiveLot(
        ingredientId: onionId,
        receivedDate: DateTime(2026, 10, 6, 9),
        unitCost: 1,
        baseQty: 1000,
      );

      expect(await stockAsOf(DateTime(2026, 10, 5)), isEmpty);
    });

    test('그날 안에 다 쓴 로트(합계 0)는 나오지 않는다', () async {
      final lotId = await repo.receiveLot(
        ingredientId: onionId,
        receivedDate: DateTime(2026, 10, 5, 9),
        unitCost: 1,
        baseQty: 1000,
      );
      await repo.recordQuantityChange(
        lotId: lotId,
        type: MovementType.disposal,
        quantity: -1000,
        occurredAt: DateTime(2026, 10, 5, 18),
      );

      expect(await stockAsOf(DateTime(2026, 10, 5)), isEmpty);
      expect((await stockAsOf(DateTime(2026, 10, 4))), isEmpty);
    });

    test('경계: 23:59:59는 그날, 다음 날 00:00:00은 다음 날', () async {
      await repo.receiveLot(
        ingredientId: onionId,
        receivedDate: DateTime(2026, 10, 5, 23, 59, 59),
        unitCost: 1,
        baseQty: 100,
      );
      await repo.receiveLot(
        ingredientId: carrotId,
        receivedDate: DateTime(2026, 10, 6),
        unitCost: 1,
        baseQty: 200,
      );

      final fifth = await stockAsOf(DateTime(2026, 10, 5));
      final sixth = await stockAsOf(DateTime(2026, 10, 6));

      expect(fifth.map((r) => r.ingredient.name), ['양파']);
      expect(sixth.map((r) => r.ingredient.name).toSet(), {'양파', '당근'});
    });

    test('매장을 고르면 그 매장 로트만, 고르지 않으면 모두', () async {
      await db.storeDao.upsertStore(StoresCompanion.insert(id: 'a', name: '울산점'));
      await db.storeDao.upsertStore(StoresCompanion.insert(id: 'b', name: '부산점'));
      await repo.receiveLot(
        ingredientId: onionId,
        storeId: 'a',
        receivedDate: DateTime(2026, 10, 5, 9),
        unitCost: 1,
        baseQty: 100,
      );
      await repo.receiveLot(
        ingredientId: carrotId,
        storeId: 'b',
        receivedDate: DateTime(2026, 10, 5, 9),
        unitCost: 1,
        baseQty: 200,
      );

      final onlyA = await stockAsOf(DateTime(2026, 10, 5), storeId: 'a');
      final all = await stockAsOf(DateTime(2026, 10, 5));

      expect(onlyA.map((r) => r.ingredient.name), ['양파']);
      expect(all, hasLength(2));
    });
  });

  group('watchInboundOn', () {
    test('inbound 기록만 나오고 다른 종류의 변동은 빠진다', () async {
      final lotId = await repo.receiveLot(
        ingredientId: onionId,
        receivedDate: DateTime(2026, 10, 5, 9),
        unitCost: 1,
        baseQty: 1000,
      );
      for (final type in [
        MovementType.usage,
        MovementType.disposal,
        MovementType.adjustment,
        MovementType.countCorrection,
      ]) {
        await repo.recordQuantityChange(
          lotId: lotId,
          type: type,
          quantity: -10,
          occurredAt: DateTime(2026, 10, 5, 12),
        );
      }

      final entries = await inboundOn(DateTime(2026, 10, 5));

      expect(entries, hasLength(1));
      expect(entries.single.movement.type, 'inbound');
    });

    test('나중에 폐기돼도 입고 때의 수량이 나온다', () async {
      final lotId = await repo.receiveLot(
        ingredientId: onionId,
        receivedDate: DateTime(2026, 10, 5, 9),
        unitCost: 1,
        baseQty: 1000,
      );
      await repo.recordQuantityChange(
        lotId: lotId,
        type: MovementType.disposal,
        quantity: -400,
        occurredAt: DateTime(2026, 10, 5, 15),
      );

      final entries = await inboundOn(DateTime(2026, 10, 5));

      expect(entries.single.movement.quantity, 1000);
    });

    test('경계: 그날 00:00:00 포함, 다음 날 00:00:00 제외', () async {
      await repo.receiveLot(
        ingredientId: onionId,
        receivedDate: DateTime(2026, 10, 5),
        unitCost: 1,
        baseQty: 1,
      );
      await repo.receiveLot(
        ingredientId: carrotId,
        receivedDate: DateTime(2026, 10, 6),
        unitCost: 1,
        baseQty: 2,
      );

      final entries = await inboundOn(DateTime(2026, 10, 5));

      expect(entries.map((e) => e.ingredient.name), ['양파']);
    });

    test('매장과 거래처 이름을 함께 주고, 없으면 null', () async {
      await db.storeDao.upsertStore(StoresCompanion.insert(id: 'a', name: '울산점'));
      await db.storeDao.upsertStore(StoresCompanion.insert(id: 'b', name: '부산점'));
      final supplierId = await db.supplierDao.insertSupplier(
        SuppliersCompanion.insert(name: '가나다상사'),
      );
      await repo.receiveLot(
        ingredientId: onionId,
        storeId: 'a',
        supplierId: supplierId,
        receivedDate: DateTime(2026, 10, 5, 9),
        unitCost: 1,
        baseQty: 100,
      );
      await repo.receiveLot(
        ingredientId: carrotId,
        storeId: 'b',
        receivedDate: DateTime(2026, 10, 5, 10),
        unitCost: 1,
        baseQty: 200,
      );

      final all = await inboundOn(DateTime(2026, 10, 5));
      final onlyA = await inboundOn(DateTime(2026, 10, 5), storeId: 'a');

      expect(all.map((e) => e.storeName), ['울산점', '부산점']);
      expect(all.map((e) => e.supplierName), ['가나다상사', null]);
      expect(onlyA.map((e) => e.ingredient.name), ['양파']);
    });

    test('입고한 시각 순서로 나온다', () async {
      await repo.receiveLot(
        ingredientId: carrotId,
        receivedDate: DateTime(2026, 10, 5, 15),
        unitCost: 1,
        baseQty: 2,
      );
      await repo.receiveLot(
        ingredientId: onionId,
        receivedDate: DateTime(2026, 10, 5, 9),
        unitCost: 1,
        baseQty: 1,
      );

      final entries = await inboundOn(DateTime(2026, 10, 5));

      expect(entries.map((e) => e.ingredient.name), ['양파', '당근']);
    });
  });
}
```
(이 파일의 줄 길이는 `dart format`이 맞춘다 — 자기 코드에만.)

- [ ] **2-2. 실패를 확인한다.** 기대: 컴파일 오류 (`watchStockAsOf`/`watchInboundOn` 없음).

- [ ] **2-3. 구현한다** — `lib/data/local/daos/stock_movement_dao.dart` 상단에 `import '../../../domain/movement_type.dart'; import '../../../domain/stock_by_date.dart'; import '../../../domain/stock_overview.dart';`를 더하고 클래스에 메서드를 더한다:

```dart
  /// [dayEndExclusive] 직전까지의 기록 합계로 구한, 그 시점의 로트별 재고.
  /// `Lot.remainingQty`는 지금 값의 사본이라 과거를 알 수 없으므로 읽지 않고,
  /// 돌려주는 로트의 `remainingQty`를 그 합계로 바꿔 채운다. 합계가 0 이하인
  /// 로트는 뺀다.
  Stream<List<LotWithIngredient>> watchStockAsOf(
    DateTime dayEndExclusive, {
    String? storeId,
  }) {
    final total = stockMovements.quantity.sum();
    final query = select(lots).join([
      innerJoin(ingredients, ingredients.id.equalsExp(lots.ingredientId)),
      innerJoin(
        stockMovements,
        stockMovements.lotId.equalsExp(lots.id) &
            stockMovements.occurredAt.isSmallerThanValue(dayEndExclusive),
      ),
    ])
      ..addColumns([total])
      ..groupBy([lots.id], having: total.isBiggerThanValue(0));

    if (storeId != null) {
      query.where(lots.storeId.equals(storeId));
    }
    query.orderBy([OrderingTerm.asc(lots.expiryDate)]);

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => LotWithIngredient(
                  lot: row
                      .readTable(lots)
                      .copyWith(remainingQty: row.read(total) ?? 0),
                  ingredient: row.readTable(ingredients),
                ),
              )
              .toList(),
        );
  }

  /// [dayStart] 이상 [dayEndExclusive] 미만에 기록된 입고(`inbound`). 수량은
  /// 입고 때의 값이다 — 그 뒤에 폐기·조정으로 줄어든 값이 아니다.
  Stream<List<InboundEntry>> watchInboundOn(
    DateTime dayStart,
    DateTime dayEndExclusive, {
    String? storeId,
  }) {
    final query = select(stockMovements).join([
      innerJoin(lots, lots.id.equalsExp(stockMovements.lotId)),
      innerJoin(ingredients, ingredients.id.equalsExp(lots.ingredientId)),
      leftOuterJoin(suppliers, suppliers.id.equalsExp(lots.supplierId)),
      leftOuterJoin(stores, stores.id.equalsExp(lots.storeId)),
    ])
      ..where(
        stockMovements.type.equals(MovementType.inbound.toDbString()) &
            stockMovements.occurredAt.isBiggerOrEqualValue(dayStart) &
            stockMovements.occurredAt.isSmallerThanValue(dayEndExclusive),
      );

    if (storeId != null) {
      query.where(lots.storeId.equals(storeId));
    }
    query.orderBy([
      OrderingTerm.asc(stockMovements.occurredAt),
      OrderingTerm.asc(stockMovements.id),
    ]);

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => InboundEntry(
                  movement: row.readTable(stockMovements),
                  lot: row.readTable(lots),
                  ingredient: row.readTable(ingredients),
                  supplierName: row.readTableOrNull(suppliers)?.name,
                  storeName: row.readTableOrNull(stores)?.name,
                ),
              )
              .toList(),
        );
  }
```
막히는 지점이 있으면 (예: `groupBy`의 `having` 인자, `readTableOrNull`) drift 소스(`pub-cache`의 `drift` 패키지)로 시그니처를 확인하고 보고한다. 추측으로 바꾸지 않는다.

- [ ] **2-4. 통과를 확인한다.** `flutter test test/data/local/stock_movement_by_date_test.dart …` 그리고 `test/data/local/` 전체 (`stock_movement_dao_test.dart` 포함). `flutter analyze lib test` 깨끗.

- [ ] **2-5. 변이 확인 후 되돌린다.** 각각 지정한 테스트가 실패해야 한다:
  - `isSmallerThanValue(dayEndExclusive)` → `isSmallerOrEqualValue` : "경계" 두 테스트.
  - `having: total.isBiggerThanValue(0)` 제거 : "합계 0" 테스트.
  - `copyWith(remainingQty: …)` 제거 : "사본이 아니라 기록 합계" 테스트.
  - `type.equals('inbound')` 조건 제거 : "inbound 기록만" 테스트.
  - 두 쿼리의 `storeId` 조건 제거 : 매장 테스트 둘.
  결과(실패 메시지 한 줄씩)를 보고한다. 되돌릴 때 `git checkout -- lib/data/local/daos/stock_movement_dao.dart` (커밋 뒤에 한다).

- [ ] **2-6. 커밋.**
```
git add lib/data/local/daos/stock_movement_dao.dart test/data/local/stock_movement_by_date_test.dart
git commit -m "feat: add stock-as-of-day and inbound-on-day queries" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## 작업 3: 날짜 선택과 조회 전용 화면

**파일:** 새 `lib/core/providers/stock_date_providers.dart`, 수정 `lib/features/stock_overview/stock_overview_screen.dart`, 수정 `test/features/stock_overview/stock_overview_screen_test.dart`.

- [ ] **3-1. provider** — `lib/core/providers/stock_date_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 재고 조회에서 고른 날짜(시각 없는 로컬 날짜). `null`은 "오늘"이다 —
/// 화면을 자정 넘어 켜 둬도 오늘이 따라가도록 오늘 날짜를 저장하지 않는다.
final selectedStockDateProvider = StateProvider<DateTime?>((ref) => null);
```

- [ ] **3-2. 실패하는 테스트를 쓴다** — `stock_overview_screen_test.dart`의 기존 `pumpScreen(tester, db)`에 선택 인자 `{DateTime? date}`를 더하고 (`overrides`에 `selectedStockDateProvider.overrideWith((ref) => date)` 추가; 기존 호출은 그대로 두 인자) 파일 안에 테스트를 더한다. 헬퍼:

```dart
  Future<void> seedPastDisposal(AppDatabase db) async {
    final now = DateTime.now();
    final twoDaysAgo = DateTime(now.year, now.month, now.day - 2, 9);
    final id = await addIngredient(db, '양파');
    final lotId = await LotRepository(db).receiveLot(
      ingredientId: id,
      receivedDate: twoDaysAgo,
      expiryDate: now.add(const Duration(days: 1)),
      unitCost: 1,
      baseQty: 1000,
    );
    await LotRepository(db).recordQuantityChange(
      lotId: lotId,
      type: MovementType.disposal,
      quantity: -400,
    );
  }
```
(import: `lot_repository.dart`, `movement_type.dart`, `stock_by_date.dart`, `stock_date_providers.dart`, `ingredient`는 파일 안의 `addIngredient`.)

테스트 (이름은 한국어로 짧게):
1. **오늘 화면은 지금 수량이고 날짜 버튼은 "오늘"이며 안내가 없다** — `seedPastDisposal` 후 `pumpScreen(tester, db)`: `find.text('600g')` 있음(품목 카드 머리), `find.text('오늘')` 하나, `find.byKey(Key('pastDateBanner'))` 없음, `find.byKey(Key('summaryNearExpiryCount'))` 있음.
2. **지난 날짜는 그날 끝 기준 수량을 보인다** — 같은 데이터, `date: DateTime(now.year, now.month, now.day - 2)`: `find.text('1,000g')` 있음, `find.text('600g')` 없음, 버튼 글자는 `stockDateLabel(날짜, now: now)`.
3. **지난 날짜는 조회 전용이다** — 같은 설정(로트에 유통기한 임박 있음): 안내 `"… 기준 (조회 전용)"` 포함 텍스트 있음, `find.text('임박')` 없음, `Key('summaryNearExpiryCount')` 없음, `Key('summaryItemCount')` 있음, `find.byIcon(Icons.chevron_right)` 없음, 로트 줄(`find.text('1,000')` — 줄의 수량 글자) 탭 후 `pumpAndSettle` → `find.byType(StockAdjustmentFormScreen)` 없음.
4. **"오늘로 돌아가기"를 누르면 오늘 화면이 된다** — `date` override 후 `Key('backToTodayButton')` 탭 → 안내 사라지고 날짜 버튼이 "오늘". (override한 `StateProvider`는 상태를 바꿀 수 있다.)
5. **날짜 버튼을 누르면 달력이 뜬다** — `Key('stockDateButton')` 탭 → `find.byType(DatePickerDialog)` 있음.
6. **지난 날짜에 표시할 재고가 없으면 날짜가 들어간 빈 상태** — 빈 DB, `date` 지정: `'이 날에는 표시할 재고가 없습니다'` 있음, 안내(`pastDateBanner`)도 있음. 기존 "표시할 재고가 없습니다" 테스트(오늘)는 그대로 통과해야 한다.

- [ ] **3-3. 실패를 확인한다.** 새 테스트만 실패하고 기존 테스트는 통과해야 한다 (컴파일 오류가 나면 3-1/3-2의 import와 `date` 인자를 먼저 맞춘 뒤 다시 확인).

- [ ] **3-4. 구현한다** — `stock_overview_screen.dart`.

  (a) **build 구조.** 화면 `StockOverviewScreen`(ConsumerWidget)의 `build`는 아래 틀이 되고, 기존 본문 로직은 새 private 위젯 `_StockBody`로 옮긴다.

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotDao = ref.watch(lotDaoProvider);
    final movementDao = ref.watch(stockMovementDaoProvider);
    final storeDao = ref.watch(storeDaoProvider);
    final storeId = ref.watch(activeStoreIdProvider);
    final selected = ref.watch(selectedStockDateProvider);
    final now = DateTime.now();
    final isToday = selected == null || isSameDay(selected, now);
    // selected가 널이 아닐 때만 else 가지로 오므로 널 승격이 된다.
    final day = selected == null || isSameDay(selected, now)
        ? dayStart(now)
        : selected;

    // 오늘은 지금처럼 로트의 남은 수량, 지난 날짜는 그날 끝까지의 기록 합계.
    final Stream<List<LotWithIngredient>> stockStream = isToday
        ? lotDao.watchAvailableLotsWithIngredient(storeId: storeId)
        : movementDao.watchStockAsOf(dayEnd(day), storeId: storeId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('재고 조회'),
        actions: [
          TextButton.icon(
            key: const Key('stockDateButton'),
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(stockDateLabel(selected, now: now)),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: day,
                firstDate: DateTime(2020),
                lastDate: dayStart(now),
              );
              if (picked == null) return;
              ref.read(selectedStockDateProvider.notifier).state =
                  stockDateSelection(picked, now: DateTime.now());
            },
          ),
          const StoreSwitcher(),
        ],
      ),
      body: Column(
        children: [
          if (!isToday)
            _PastDateBanner(
              label: stockDateLabel(day, now: now),
              onBack: () =>
                  ref.read(selectedStockDateProvider.notifier).state = null,
            ),
          Expanded(
            child: StreamBuilder<List<Store>>(
              stream: storeDao.watchAll(),
              builder: (context, storeSnapshot) {
                final storeNames = {
                  for (final s in storeSnapshot.data ?? <Store>[]) s.id: s.name,
                };
                return StreamBuilder<List<LotWithIngredient>>(
                  stream: stockStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    return _StockBody(
                      rows: snapshot.data!,
                      storeNames: storeNames,
                      now: now,
                      isToday: isToday,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
```

  (b) **`_PastDateBanner`**: `CenteredContent(maxWidth: _kContentMaxWidth)` 안에 `Padding(16,12,16,0)`, 배경 `AppColors.chipBackground`, 둥근 모서리 10인 `Container`(Row: `Expanded(Text('$label 기준 (조회 전용)'))`, `TextButton(key: Key('backToTodayButton'), child: Text('오늘로 돌아가기'))`), 바깥에 `Key('pastDateBanner')`. 글자 13, `AppColors.textBody`.

  (c) **`_StockBody`**: 기존 `build`의 본문(그룹 만들기·요약 줄·카드 줄)을 그대로 옮기고 아래만 바꾼다.
  - `groupLotsByIngredient(rows, now: now, flagNearExpiry: isToday)`.
  - 비었을 때 `EmptyState(title: isToday ? '표시할 재고가 없습니다' : '이 날에는 표시할 재고가 없습니다', message: isToday ? '입고를 등록하면 여기에 나타납니다' : null)`. 아이콘은 지금과 같게.
  - 임박 건수는 `isToday`일 때만 계산해 `_SummaryStrip(nearExpiryCount: isToday ? n : null)`.
  - `_IngredientCard(…, readOnly: !isToday)`.

  (d) **`_SummaryStrip`**: `nearExpiryCount`를 `int?`로. 지역 변수 `final near = nearExpiryCount;`로 받아 `near != null`이면 지금처럼 둘째 타일(키·alert 그대로)을 그리고 아니면 품목 타일만. (public 필드는 널 승격이 안 되니 지역 변수를 쓴다.)

  (e) **`_IngredientCard`/`_LotRow`**: `readOnly` 인자(기본 false)를 더한다. `_IngredientCard`: `alert = !readOnly && group.hasNearExpiryLot`, 줄에 `readOnly` 전달. `_LotRow`: `near = !readOnly && isNearExpiry(...)`; `InkWell(onTap: readOnly ? null : () => …push…)`; `Icon(chevron_right)`는 `if (!readOnly)`로 감싼다. 나머지 그리기는 그대로.

  새 import: `stock_date_providers.dart`, `stock_by_date.dart`. 이 작업에서 `_kContentMaxWidth` 등 기존 상수는 그대로 쓴다.

- [ ] **3-5. 통과를 확인한다.** `flutter test test/features/stock_overview/stock_overview_screen_test.dart …` — 기존 테스트(모서리 픽셀 포함)와 새 테스트 모두. `flutter analyze lib test`.

- [ ] **3-6. 변이 확인 후 되돌린다.** (a) `readOnly ? null : …` 를 항상 push로 → 3번 테스트 실패. (b) `flagNearExpiry: isToday`를 `true`로 → 3번 테스트(임박 없음) 실패. (c) `isToday` 판정을 항상 `true`로 → 2번 실패. 각 결과를 보고한다.

- [ ] **3-7. 커밋.**
```
git add lib/core/providers/stock_date_providers.dart lib/features/stock_overview/stock_overview_screen.dart test/features/stock_overview/stock_overview_screen_test.dart
git commit -m "feat: pick a past date on the stock overview (read-only)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## 작업 4: "이 날 입고" 카드

**파일:** 새 `lib/features/stock_overview/inbound_day_card.dart`, 수정 `stock_overview_screen.dart`, 수정 `stock_overview_screen_test.dart`.

- [ ] **4-1. 실패하는 테스트를 쓴다** — 화면 테스트에 추가 (데이터는 `LotRepository.receiveLot`/`recordQuantityChange`로 만든다. 매장 이름이 필요하면 `db.storeDao.upsertStore`, 거래처는 `db.supplierDao.insertSupplier`):
1. **오늘 입고 두 건이 카드에 나온다** — 양파 1,000g(울산점, 거래처 가나다상사)·당근 500g(거래처 없음)을 오늘 입고: `Key('inboundDayCard')` 안에 `오늘 입고 2건`, `양파`, `1,000g`, `울산점`, `가나다상사`, `당근`, `500g`. 각 줄 `Key('inboundEntry_<movement id>')` 두 개.
2. **입고가 없으면 안내 문구** — 오늘 로트를 `insertLot`으로만(기록 없이) 넣어 재고는 있고 입고 기록은 없게: `오늘 입고 0건`, `이 날 입고된 재고가 없습니다`, 품목 카드도 보임.
3. **오늘 입고한 뒤 오늘 폐기해도 입고 때 수량이 나온다** — 입고 1,000 → 오늘 폐기 -400: 입고 카드에 `1,000g`, 품목 카드 머리에 `600g`.
4. **지난 날짜는 그날 입고만 보인다** — 이틀 전에 양파, 어제 당근, 오늘 파 입고. `date`=이틀 전: 카드에 `이 날 입고 1건`과 양파만(당근·파 없음). 오늘 화면(`date` 없음)은 `오늘 입고 1건`과 파만.
5. **사용·폐기·조정은 입고 목록에 들어가지 않는다** — 오늘 입고 1건 + 같은 로트에 usage/disposal/adjustment/countCorrection 기록: `오늘 입고 1건`.
6. **그날 재고가 다 없어졌어도 입고 카드는 보인다** — 오늘 입고 1,000 → 오늘 폐기 -1000: `EmptyState` 문구('표시할 재고가 없습니다')가 **카드 아래 알림으로** 보이고 입고 카드(`오늘 입고 1건`)도 보인다. 화면 전체가 빈 상태 하나로 바뀌지 않는다. (입고도 재고도 없으면 지금처럼 빈 상태 하나 — 기존 테스트.)
7. **매장 범위** — 사장 세션이 아닐 때의 `activeStoreIdProvider` override 방법은 기존 테스트(`store_switcher`/`stock_overview` 관련)를 읽어 같은 방식으로: 울산점을 고르면 부산점 입고는 카드에 없다.

- [ ] **4-2. 실패를 확인한다.**

- [ ] **4-3. 구현한다.**

  `lib/features/stock_overview/inbound_day_card.dart`:
  - `InboundDayCard({super.key, required this.title, required this.entries})` (StatelessWidget). 바깥은 재고 카드와 같은 `Material(key: Key('inboundDayCard'), color: AppColors.surface, clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(side: BorderSide(color: AppColors.border), borderRadius: 12))` (테두리를 `Container` 장식에 맡기지 않는다).
  - 머리글 `Text('$title ${entries.length}건', 15/w700/textStrong)` (패딩 12,10,12,8). 입고가 없으면 아래에 `Text('이 날 입고된 재고가 없습니다', 13, textMuted)` (패딩 12,0,12,12). 있으면 줄마다 `Divider(height: 1, thickness: 1, color: AppColors.border)` 다음 `_InboundRow`.
  - `_InboundRow(key: Key('inboundEntry_${entry.movement.id}'))`: 패딩 `fromLTRB(12, 8, 12, 8)`, Row — 왼쪽 `Expanded(Column(start))`: 품목명(14/w600/textStrong, 한 줄 말줄임), 그 아래 간격 4의 `Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: center)`에 `if (storeName != null) InfoChip(storeName)`과 `if (supplierName != null) Text(supplierName, 12, textMuted)` (둘 다 없으면 Wrap 자체를 그리지 않는다); 오른쪽 `Text('${formatQty(entry.movement.quantity)}${entry.ingredient.baseUnit}', 14/w600, tabularFigures)`. 사이에 `SizedBox(width: 8)`.

  `stock_overview_screen.dart`:
  - `StockOverviewScreen.build`에서 `final inboundStream = movementDao.watchInboundOn(day, dayEnd(day), storeId: storeId);`를 만들고 재고 `StreamBuilder` 안쪽에 `StreamBuilder<List<InboundEntry>>(stream: inboundStream, …)`를 한 겹 더 둔다. 둘 중 하나라도 `hasData`가 아니면 `SizedBox.shrink()`. `_StockBody`에 `inbound`를 넘긴다.
  - `_StockBody`: 비어 있음 판정은 `groups.isEmpty && inbound.isEmpty`일 때만 전체 빈 상태. 목록 `itemCount = rowCount + 2` — 0번 요약 줄, 1번 `InboundDayCard(title: isToday ? '오늘 입고' : '이 날 입고', entries: inbound)` (아래 간격 `_kGap`), 그 뒤 카드 줄(인덱스는 `index - 2`로 바꾼다). `groups.isEmpty`(입고만 있고 재고는 없음)이면 입고 카드 뒤에 같은 문구의 안내 한 줄(`isToday ? '표시할 재고가 없습니다' : '이 날에는 표시할 재고가 없습니다'`, 13, textMuted, 가운데)을 둔다. `columns` 계산에 `rowCount`가 0일 수 있음에 주의.
  - `_SummaryStrip`의 "재고 품목 N종"은 `groups.length`로 그대로.

- [ ] **4-4. 통과를 확인한다.** 이 파일 전체 + `flutter analyze lib test`. 기존 테스트가 깨지면 **원인을 보고**하고, 테스트가 낡은 기대를 하고 있는 경우에만 고친다 (예: 목록 줄 수나 위치를 세는 기대).

- [ ] **4-5. 변이 확인 후 되돌린다.** (a) `watchInboundOn`을 써야 할 곳에서 항상 오늘 날짜를 주기 → 4번 실패. (b) 카드 머리글의 `entries.length`를 `groups.length`로 → 1번 실패. (c) `groups.isEmpty && inbound.isEmpty`를 `groups.isEmpty`로 → 6번 실패. (d) 입고 카드를 `isToday`일 때만 그리기 → 4번(지난 날짜) 실패.

- [ ] **4-6. 커밋.**
```
git add lib/features/stock_overview/inbound_day_card.dart lib/features/stock_overview/stock_overview_screen.dart test/features/stock_overview/stock_overview_screen_test.dart
git commit -m "feat: show the day's inbound lots on the stock overview" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## 작업 5: 전체 확인 (통제자가 한다)

- [ ] 전체 테스트와 분석: `flutter test --timeout 120s --reporter expanded *> $env:TEMP\full.log; Get-Content $env:TEMP\full.log -Tail 5` 그리고 `flutter analyze lib test`. 기대: 시작 276개 + 새 테스트 모두 통과, 분석 깨끗. 새 테스트 수를 직접 센다.
- [ ] 전체 브랜치 독립 검토 (opus): 스펙의 모든 항목이 구현됐는지, 지난 날짜에서 오늘 전용 동작(탭·화살표·임박)이 새지 않는지, 날짜 경계(로컬 자정), 스트림이 날짜·매장이 바뀔 때 다시 만들어지는지, 기존 화면(오늘)이 달라지지 않았는지.
- [ ] 사용자가 손으로 확인한다 (Android + Windows): 오늘 입고를 하나 등록 → 입고 카드에 보이는지; 이전에 입고해 둔 데이터가 있으면 어제 날짜를 골라 그날 수량과 입고가 나오는지; 지난 날짜에서 로트를 눌러도 폐기·조정 화면이 안 뜨는지; "오늘로 돌아가기"; 사장 계정에서 매장을 바꿔도 날짜가 유지되는지.
- [ ] 메모리/문서 갱신: `project_stockcontrol.md`에 날짜별 재고 완료를 적고, CLAUDE.md는 새 함정이 생겼을 때만 더한다.
