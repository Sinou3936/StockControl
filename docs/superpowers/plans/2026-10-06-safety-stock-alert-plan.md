# 안전재고 부족 알림 (9-1) 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 품목마다 안전재고 기준을 정하고, 매장별로 그 기준에 못 미치는 품목을 "부족 재고" 탭에 모아 보여준다.

**Architecture:** 부족 판정은 DB를 모르는 순수 함수(`calculateShortages`)가 맡는다. 매장 목록·품목 목록·매장별 재고 합계 세 스트림을 Riverpod provider가 모아 그 함수에 넘기고, 화면과 탭 배지는 결과만 읽는다. 나중에 푸시 알림을 붙일 때 같은 판정을 서버에서 재사용하기 위한 구조다.

**Tech Stack:** Flutter, Riverpod, Drift(로컬 SQLite), Supabase(동기화)

**Spec:** `docs/superpowers/specs/2026-10-06-safety-stock-alert-design.md`

## Global Constraints

- 안전재고(`Ingredient.safetyStockQty`)가 `null`이거나 0 이하면 그 품목은 추적하지 않는다. 사용자가 빈 값이나 0을 넣으면 `null`로 저장한다.
- 안전재고는 품목당 값 하나다. 판정만 매장별로 한다. 매장별 기준값 테이블은 만들지 않는다.
- 안전재고가 설정된 품목은 모든 매장에서 추적한다 (전 매장이 같은 품목을 쓴다고 전제).
- `storeId`가 `null`인 로트는 매장별 합계에서 제외한다.
- 직원은 자기 매장 것만 본다. 세션에 매장이 없으면 빈 목록이다 — 전 매장으로 넘어가면 안 된다.
- 품목의 이름·단위·환산계수는 이번 범위에서 수정하지 않는다. 수정 대상은 안전재고 값뿐이다.
- `calculateShortages`는 Drift·Riverpod·Flutter를 import하지 않는다. 입력은 평범한 리스트, 출력은 평범한 리스트다.
- 테스트에서 `package:drift/drift.dart`를 import하면서 `isNull`/`isNotNull` matcher를 쓸 때는 `hide isNotNull, isNull`을 붙인다 (이름 충돌).
- `testWidgets` 안에서 `await dao.watchAll().first`처럼 실제 스트림을 직접 기다리면 멈춘다. `tester.pump()`로 흘려보낸다.
- 커밋 메시지 끝에 `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`를 붙인다.

## Review Focus

- **매장이 지정되지 않은 직원 세션** — `activeStoreIdProvider`의 `null`은 "사장의 전체 합산"과 "매장 없는 직원" 둘 다를 뜻한다. 후자에게 전 매장 재고가 보이면 안 된다. (Task 5)
- **탭이 하나 늘어 기존 인덱스가 밀리는 것** — 폰의 "더보기"가 3에서 4로, Windows의 사장 전용 항목이 5·6에서 6·7로 바뀐다. 고치지 않으면 엉뚱한 화면이 열린다. (Task 7)
- **안전재고를 다시 비웠을 때** — 추적을 끄려고 값을 지웠는데 목록에 계속 남으면 끌 방법이 없어진다. (Task 3, Task 1)
- **pull이 이름·환산계수까지 덮어쓰는 것** — 안전재고만 갱신해야 한다. 다른 필드까지 건드리면 로컬 데이터가 서버 값으로 조용히 바뀐다. (Task 4)
- **현재 수량이 기준과 정확히 같을 때** — 부족이 아니다. 경계에서 잘못 뜨면 알림이 상시로 울린다. (Task 1)

---

### Task 1: 부족 판정 순수 함수

**Files:**
- Create: `lib/domain/stock_shortage.dart`
- Test: `test/domain/stock_shortage_test.dart`

**Interfaces:**
- Consumes: Drift가 생성한 `Ingredient`, `Store` 행 클래스 (`package:stockcontrol/data/local/database.dart`)
- Produces:
  - `class StoreStockLevel { int ingredientId; String storeId; double totalQty; }`
  - `class StockShortage { Ingredient ingredient; Store store; double currentQty; double get safetyStockQty; double get shortfall; double get fillRatio; }`
  - `List<StockShortage> calculateShortages({required List<Ingredient> ingredients, required List<Store> stores, required List<StoreStockLevel> levels})`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/domain/stock_shortage_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/domain/stock_shortage.dart';

Ingredient makeIngredient(int id, String name, double? safetyStockQty) =>
    Ingredient(
      id: id,
      name: name,
      baseUnit: 'g',
      purchaseUnit: '박스',
      conversionFactor: 1000,
      isExpiryTracked: false,
      safetyStockQty: safetyStockQty,
      createdAt: DateTime(2026, 10, 1),
    );

void main() {
  const ulsan = Store(id: 'store-1', name: '울산점');
  const busan = Store(id: 'store-2', name: '부산점');

  test('안전재고가 없는 품목은 결과에 나오지 않는다', () {
    final result = calculateShortages(
      ingredients: [makeIngredient(1, '양파', null)],
      stores: [ulsan],
      levels: [],
    );

    expect(result, isEmpty);
  });

  test('안전재고가 0 이하인 품목도 추적하지 않는다', () {
    final result = calculateShortages(
      ingredients: [makeIngredient(1, '양파', 0)],
      stores: [ulsan],
      levels: [],
    );

    expect(result, isEmpty);
  });

  test('로트가 하나도 없는 매장은 현재 수량 0으로 부족에 포함된다', () {
    final result = calculateShortages(
      ingredients: [makeIngredient(1, '양파', 5000)],
      stores: [ulsan],
      levels: [],
    );

    expect(result, hasLength(1));
    expect(result.single.currentQty, 0);
    expect(result.single.shortfall, 5000);
    expect(result.single.fillRatio, 0);
    expect(result.single.store.id, 'store-1');
  });

  test('현재 수량이 기준과 정확히 같으면 부족이 아니다', () {
    final result = calculateShortages(
      ingredients: [makeIngredient(1, '양파', 5000)],
      stores: [ulsan],
      levels: [
        const StoreStockLevel(
          ingredientId: 1,
          storeId: 'store-1',
          totalQty: 5000,
        ),
      ],
    );

    expect(result, isEmpty);
  });

  test('현재 수량이 기준보다 많으면 부족이 아니다', () {
    final result = calculateShortages(
      ingredients: [makeIngredient(1, '양파', 5000)],
      stores: [ulsan],
      levels: [
        const StoreStockLevel(
          ingredientId: 1,
          storeId: 'store-1',
          totalQty: 5001,
        ),
      ],
    );

    expect(result, isEmpty);
  });

  test('한 매장이 부족해도 다른 매장이 충분하면 그 매장만 나온다', () {
    final result = calculateShortages(
      ingredients: [makeIngredient(1, '양파', 5000)],
      stores: [ulsan, busan],
      levels: [
        const StoreStockLevel(
          ingredientId: 1,
          storeId: 'store-2',
          totalQty: 9000,
        ),
      ],
    );

    expect(result, hasLength(1));
    expect(result.single.store.id, 'store-1');
  });

  test('채워진 비율이 낮은 순, 같으면 매장 이름, 그다음 품목 이름 순', () {
    final result = calculateShortages(
      ingredients: [
        makeIngredient(1, '양파', 100),
        makeIngredient(2, '당근', 100),
      ],
      stores: [ulsan, busan],
      levels: [
        // 울산 양파 50%, 부산 양파 0%, 울산 당근 50%, 부산 당근 50%
        const StoreStockLevel(
          ingredientId: 1,
          storeId: 'store-1',
          totalQty: 50,
        ),
        const StoreStockLevel(
          ingredientId: 2,
          storeId: 'store-1',
          totalQty: 50,
        ),
        const StoreStockLevel(
          ingredientId: 2,
          storeId: 'store-2',
          totalQty: 50,
        ),
      ],
    );

    final labels = result
        .map((s) => '${s.store.name}-${s.ingredient.name}')
        .toList();
    expect(labels, ['부산점-양파', '부산점-당근', '울산점-당근', '울산점-양파']);
  });

  test('stores에 한 매장만 넘기면 그 매장 결과만 나온다', () {
    final result = calculateShortages(
      ingredients: [makeIngredient(1, '양파', 5000)],
      stores: [busan],
      levels: [],
    );

    expect(result, hasLength(1));
    expect(result.single.store.id, 'store-2');
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/domain/stock_shortage_test.dart`
Expected: FAIL — `lib/domain/stock_shortage.dart` 파일이 없어 컴파일 에러

- [ ] **Step 3: 구현 작성**

`lib/domain/stock_shortage.dart`:

```dart
import 'package:stockcontrol/data/local/database.dart';

/// 매장 한 곳에서 품목 하나의 현재 재고 합계.
class StoreStockLevel {
  const StoreStockLevel({
    required this.ingredientId,
    required this.storeId,
    required this.totalQty,
  });

  final int ingredientId;
  final String storeId;
  final double totalQty;
}

/// 한 매장에서 한 품목이 안전재고 기준에 못 미치는 상태.
class StockShortage {
  const StockShortage({
    required this.ingredient,
    required this.store,
    required this.currentQty,
  });

  final Ingredient ingredient;
  final Store store;
  final double currentQty;

  /// 추적 대상만 StockShortage가 되므로 항상 non-null이다.
  double get safetyStockQty => ingredient.safetyStockQty!;

  double get shortfall => safetyStockQty - currentQty;

  /// 기준 대비 채워진 비율. 0이면 완전히 빈 상태.
  double get fillRatio => currentQty / safetyStockQty;
}

/// 안전재고가 설정된 품목에 대해 [stores] 각각의 재고를 비교해 부족분을 모은다.
/// 매장 범위를 좁히려면 호출하는 쪽에서 [stores]를 걸러 넘긴다.
List<StockShortage> calculateShortages({
  required List<Ingredient> ingredients,
  required List<Store> stores,
  required List<StoreStockLevel> levels,
}) {
  final quantities = <String, double>{
    for (final level in levels)
      '${level.ingredientId}@${level.storeId}': level.totalQty,
  };

  final shortages = <StockShortage>[];
  for (final ingredient in ingredients) {
    final threshold = ingredient.safetyStockQty;
    if (threshold == null || threshold <= 0) continue;

    for (final store in stores) {
      final current = quantities['${ingredient.id}@${store.id}'] ?? 0;
      if (current >= threshold) continue;
      shortages.add(
        StockShortage(
          ingredient: ingredient,
          store: store,
          currentQty: current,
        ),
      );
    }
  }

  shortages.sort((a, b) {
    final byRatio = a.fillRatio.compareTo(b.fillRatio);
    if (byRatio != 0) return byRatio;
    final byStore = a.store.name.compareTo(b.store.name);
    if (byStore != 0) return byStore;
    return a.ingredient.name.compareTo(b.ingredient.name);
  });

  return shortages;
}
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/domain/stock_shortage_test.dart`
Expected: PASS (8 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/domain/stock_shortage.dart test/domain/stock_shortage_test.dart
git commit -m "feat: add per-store safety stock shortage calculation

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: 매장+품목별 재고 합계 조회

**Files:**
- Modify: `lib/data/local/daos/lot_dao.dart`
- Test: `test/data/local/lot_dao_test.dart`

**Interfaces:**
- Consumes: `StoreStockLevel` (Task 1)
- Produces: `Stream<List<StoreStockLevel>> LotDao.watchStockLevelsByStore()`

- [ ] **Step 1: 실패하는 테스트 추가**

`test/data/local/lot_dao_test.dart` 맨 끝(`}` 앞)에 추가:

```dart

  test('watchStockLevelsByStore sums lots per ingredient and store', () async {
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-1', name: '울산점'),
    );
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-2', name: '부산점'),
    );

    for (final (store, qty) in [('store-1', 300.0), ('store-1', 200.0),
        ('store-2', 50.0)]) {
      await db.lotDao.insertLot(
        LotsCompanion.insert(
          ingredientId: ingredientId,
          storeId: Value(store),
          receivedDate: DateTime(2026, 10, 1),
          unitCost: 10,
          remainingQty: qty,
        ),
      );
    }

    final levels = await db.lotDao.watchStockLevelsByStore().first;

    final ulsan = levels.firstWhere((l) => l.storeId == 'store-1');
    final busan = levels.firstWhere((l) => l.storeId == 'store-2');
    expect(ulsan.totalQty, 500);
    expect(ulsan.ingredientId, ingredientId);
    expect(busan.totalQty, 50);
  });

  test('watchStockLevelsByStore ignores lots that have no store', () async {
    await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 10, 1),
        unitCost: 10,
        remainingQty: 999,
      ),
    );

    final levels = await db.lotDao.watchStockLevelsByStore().first;

    expect(levels, isEmpty);
  });
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/data/local/lot_dao_test.dart`
Expected: FAIL — `watchStockLevelsByStore` 메서드가 없어 컴파일 에러

- [ ] **Step 3: DAO에 메서드 추가**

`lib/data/local/daos/lot_dao.dart`의 import 목록에 추가:

```dart
import '../../../domain/stock_shortage.dart';
```

같은 파일 `watchAvailableLotsWithIngredient` 메서드 **뒤**, 클래스 닫는 중괄호 앞에 추가:

```dart
  /// 매장별·품목별 남은 수량 합계. 매장이 지정되지 않은 로트는 제외한다.
  Stream<List<StoreStockLevel>> watchStockLevelsByStore() {
    final total = lots.remainingQty.sum();
    final query = selectOnly(lots)
      ..addColumns([lots.ingredientId, lots.storeId, total])
      ..where(lots.storeId.isNotNull())
      ..groupBy([lots.ingredientId, lots.storeId]);

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => StoreStockLevel(
                  ingredientId: row.read(lots.ingredientId)!,
                  storeId: row.read(lots.storeId)!,
                  totalQty: row.read(total) ?? 0,
                ),
              )
              .toList(),
        );
  }
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/data/local/lot_dao_test.dart`
Expected: PASS (기존 5개 + 신규 2개 = 7개)

- [ ] **Step 5: Commit**

```bash
git add lib/data/local/daos/lot_dao.dart test/data/local/lot_dao_test.dart
git commit -m "feat: add per-store stock level query to LotDao

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: 안전재고 수정과 전송 큐 기록

**Files:**
- Modify: `lib/data/local/daos/ingredient_dao.dart`
- Test: `test/data/local/ingredient_dao_test.dart`

**Interfaces:**
- Consumes: `SyncQueueDao.enqueue(String tableName, int recordId)` (8-2)
- Produces: `Future<void> IngredientDao.updateSafetyStock(int id, double? value)`

- [ ] **Step 1: 실패하는 테스트 추가**

`test/data/local/ingredient_dao_test.dart` 맨 끝(`}` 앞)에 추가:

```dart

  test('updateSafetyStock writes the value and queues the row for sync',
      () async {
    final id = await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
      ),
    );
    await db.delete(db.syncQueue).go();

    await db.ingredientDao.updateSafetyStock(id, 5000);

    final saved = (await db.ingredientDao.watchAll().first)
        .firstWhere((i) => i.id == id);
    expect(saved.safetyStockQty, 5000);

    final queued = await db.syncQueueDao.oldest();
    expect(queued!.targetTable, 'ingredients');
    expect(queued.recordId, id);
  });

  test('updateSafetyStock with null clears tracking', () async {
    final id = await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
        safetyStockQty: const Value(5000),
      ),
    );

    await db.ingredientDao.updateSafetyStock(id, null);

    final saved = (await db.ingredientDao.watchAll().first)
        .firstWhere((i) => i.id == id);
    expect(saved.safetyStockQty, isNull);
  });
```

`test/data/local/ingredient_dao_test.dart` 맨 위 import에 drift가 없으면 추가한다. 위 테스트가 `Value`와 matcher `isNull`을 함께 쓰므로 반드시 다음 형태여야 한다:

```dart
import 'package:drift/drift.dart' hide isNotNull, isNull;
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/data/local/ingredient_dao_test.dart`
Expected: FAIL — `updateSafetyStock` 메서드가 없어 컴파일 에러

- [ ] **Step 3: DAO에 메서드 추가**

`lib/data/local/daos/ingredient_dao.dart`의 `insertIngredient` 뒤, 클래스 닫는 중괄호 앞에 추가:

```dart
  /// 안전재고 값만 고친다. 값이 바뀌는 유일한 필드라, 고칠 때도 새로 만들 때와
  /// 똑같이 전송 큐에 남겨 다른 기기로 전달한다.
  Future<void> updateSafetyStock(int id, double? value) {
    return attachedDatabase.transaction(() async {
      await (update(ingredients)..where((i) => i.id.equals(id))).write(
        IngredientsCompanion(safetyStockQty: Value(value)),
      );
      await attachedDatabase.syncQueueDao.enqueue('ingredients', id);
    });
  }
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/data/local/ingredient_dao_test.dart`
Expected: PASS (기존 3개 + 신규 2개)

- [ ] **Step 5: Commit**

```bash
git add lib/data/local/daos/ingredient_dao.dart test/data/local/ingredient_dao_test.dart
git commit -m "feat: add safety stock update that also queues the row for sync

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: 받은 품목의 안전재고 갱신

**Files:**
- Modify: `lib/data/repositories/sync_repository.dart`
- Test: `test/data/repositories/sync_repository_test.dart`

**Interfaces:**
- Consumes: 기존 `SyncRepository.pullUpdates({required bool isOwner, String? storeId})`
- Produces: 동작 변경만 — `'ingredients'` 행을 pull할 때 로컬에 이미 있으면 건너뛰지 않고 `safetyStockQty`를 갱신한다. 다른 필드는 건드리지 않는다.

- [ ] **Step 1: 실패하는 테스트 추가**

`test/data/repositories/sync_repository_test.dart` 맨 끝(`}` 앞)에 추가:

```dart

  test('pullUpdates updates safetyStockQty on an ingredient that already '
      'exists locally, leaving its other fields alone', () async {
    final localId = await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
      ),
    );
    final local = (await db.ingredientDao.watchAll().first)
        .firstWhere((i) => i.id == localId);

    final gateway = FakeSyncGateway();
    gateway.tableRows['ingredients'] = [
      {
        'id': local.syncId,
        'name': '서버에서온이름',
        'category': null,
        'base_unit': 'kg',
        'purchase_unit': '자루',
        'conversion_factor': 999,
        'is_expiry_tracked': true,
        'safety_stock_qty': 5000,
        'synced_at': DateTime(2026, 10, 6).toIso8601String(),
      },
    ];
    final repository = SyncRepository(gateway, db);

    await repository.pullUpdates(isOwner: true);

    final updated = (await db.ingredientDao.watchAll().first)
        .firstWhere((i) => i.id == localId);
    expect(updated.safetyStockQty, 5000);
    expect(updated.name, '양파');
    expect(updated.baseUnit, 'g');
    expect(updated.purchaseUnit, '박스');
    expect(updated.conversionFactor, 20000);
    expect(updated.isExpiryTracked, isFalse);
  });

  test('pullUpdates can clear safetyStockQty back to null', () async {
    final localId = await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
        safetyStockQty: const Value(5000),
      ),
    );
    final local = (await db.ingredientDao.watchAll().first)
        .firstWhere((i) => i.id == localId);

    final gateway = FakeSyncGateway();
    gateway.tableRows['ingredients'] = [
      {
        'id': local.syncId,
        'name': '양파',
        'category': null,
        'base_unit': 'g',
        'purchase_unit': '박스',
        'conversion_factor': 20000,
        'is_expiry_tracked': false,
        'safety_stock_qty': null,
        'synced_at': DateTime(2026, 10, 6).toIso8601String(),
      },
    ];
    final repository = SyncRepository(gateway, db);

    await repository.pullUpdates(isOwner: true);

    final updated = (await db.ingredientDao.watchAll().first)
        .firstWhere((i) => i.id == localId);
    expect(updated.safetyStockQty, isNull);
  });
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/data/repositories/sync_repository_test.dart`
Expected: FAIL — 첫 테스트가 `Expected: 5000 Actual: <null>` (지금은 이미 있는 품목을 건너뛴다)

- [ ] **Step 3: pull 분기 수정**

`lib/data/repositories/sync_repository.dart`에서 `_applyPulledRow`의 `case 'ingredients':` 블록 첫 줄을 찾는다. 현재는 이렇게 생겼다:

```dart
      case 'ingredients':
        if (await _findIngredientLocalId(syncId) != null) return true;
        await _db.into(_db.ingredients).insert(
```

이 두 줄을 아래로 교체한다 (`await _db.into(...)` 이후의 `IngredientsCompanion.insert(...)` 본문은 그대로 둔다):

```dart
      case 'ingredients':
        final existingIngredientId = await _findIngredientLocalId(syncId);
        if (existingIngredientId != null) {
          // 품목에서 값이 바뀔 수 있는 필드는 안전재고 하나뿐이다. 이름·단위·
          // 환산계수를 덮어쓰면 과거 로트와 어긋나므로 건드리지 않는다.
          await (_db.update(_db.ingredients)
                ..where((t) => t.id.equals(existingIngredientId)))
              .write(
            IngredientsCompanion(
              safetyStockQty: Value(
                (row['safety_stock_qty'] as num?)?.toDouble(),
              ),
            ),
          );
          return true;
        }
        await _db.into(_db.ingredients).insert(
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/data/repositories/sync_repository_test.dart`
Expected: PASS (기존 14개 + 신규 2개 = 16개)

- [ ] **Step 5: 전체 테스트로 회귀 확인**

Run: `flutter test`
Expected: 전부 PASS — 특히 "pullUpdates skips a row whose syncId already exists locally"(거래처 대상)가 여전히 통과해야 한다. 거래처 분기는 건드리지 않았다.

- [ ] **Step 6: Commit**

```bash
git add lib/data/repositories/sync_repository.dart test/data/repositories/sync_repository_test.dart
git commit -m "feat: apply pulled safety stock changes to existing ingredients

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: 부족 목록 provider

**Files:**
- Create: `lib/core/providers/shortage_providers.dart`
- Test: `test/core/providers/shortage_providers_test.dart`

**Interfaces:**
- Consumes: `calculateShortages`(Task 1), `LotDao.watchStockLevelsByStore`(Task 2), 기존 `authSessionProvider`, `selectedStoreProvider`, `storeDaoProvider`, `ingredientDaoProvider`, `lotDaoProvider`
- Produces:
  - `storesStreamProvider`, `ingredientsStreamProvider`, `stockLevelsStreamProvider` (StreamProvider)
  - `final shortagesProvider = Provider<List<StockShortage>>(...)`
  - `final shortageCountProvider = Provider<int>(...)`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/core/providers/shortage_providers_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/auth_providers.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/core/providers/shortage_providers.dart';
import 'package:stockcontrol/core/providers/store_providers.dart';
import 'package:stockcontrol/data/local/database.dart';

void main() {
  late AppDatabase db;
  late int ingredientId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-1', name: '울산점'),
    );
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-2', name: '부산점'),
    );
    ingredientId = await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
        safetyStockQty: const Value(5000),
      ),
    );
  });

  tearDown(() => db.close());

  ProviderContainer makeContainer(AuthSession? session) {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    if (session != null) {
      container.read(authSessionProvider.notifier).setSession(session);
    }
    return container;
  }

  AuthSession owner() => AuthSession(
        id: 'owner-1',
        email: 'owner@internal.local',
        pin: '123456',
        displayName: '사장님',
        role: 'owner',
      );

  AuthSession staff({String? storeId}) => AuthSession(
        id: 'staff-1',
        email: 'staff@internal.local',
        pin: '111111',
        displayName: '직원1',
        role: 'staff',
        storeId: storeId,
        storeName: storeId == null ? null : '울산점',
      );

  /// 세 스트림이 첫 값을 내보낼 때까지 흘려보낸다.
  Future<void> settle(ProviderContainer container) async {
    container.listen(storesStreamProvider, (_, _) {});
    container.listen(ingredientsStreamProvider, (_, _) {});
    container.listen(stockLevelsStreamProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  test('사장이 전체를 보면 모든 매장의 부족이 나온다', () async {
    final container = makeContainer(owner());
    await settle(container);

    final shortages = container.read(shortagesProvider);

    expect(shortages, hasLength(2));
    expect(
      shortages.map((s) => s.store.id).toSet(),
      {'store-1', 'store-2'},
    );
    expect(container.read(shortageCountProvider), 2);
  });

  test('사장이 매장을 고르면 그 매장만 나온다', () async {
    final container = makeContainer(owner());
    await settle(container);

    container.read(selectedStoreProvider.notifier).state =
        const Store(id: 'store-1', name: '울산점');

    final shortages = container.read(shortagesProvider);

    expect(shortages, hasLength(1));
    expect(shortages.single.store.id, 'store-1');
  });

  test('직원은 자기 매장 것만 본다', () async {
    final container = makeContainer(staff(storeId: 'store-2'));
    await settle(container);

    final shortages = container.read(shortagesProvider);

    expect(shortages, hasLength(1));
    expect(shortages.single.store.id, 'store-2');
  });

  test('매장이 지정되지 않은 직원에게는 아무것도 보이지 않는다', () async {
    final container = makeContainer(staff());
    await settle(container);

    expect(container.read(shortagesProvider), isEmpty);
  });

  test('로그인하지 않으면 빈 목록이다', () async {
    final container = makeContainer(null);
    await settle(container);

    expect(container.read(shortagesProvider), isEmpty);
  });

  test('재고가 기준 이상이면 그 매장은 빠진다', () async {
    await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        storeId: const Value('store-1'),
        receivedDate: DateTime(2026, 10, 1),
        unitCost: 10,
        remainingQty: 9000,
      ),
    );

    final container = makeContainer(owner());
    await settle(container);

    final shortages = container.read(shortagesProvider);

    expect(shortages, hasLength(1));
    expect(shortages.single.store.id, 'store-2');
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/core/providers/shortage_providers_test.dart`
Expected: FAIL — `lib/core/providers/shortage_providers.dart` 파일이 없어 컴파일 에러

- [ ] **Step 3: provider 작성**

`lib/core/providers/shortage_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../domain/stock_shortage.dart';
import 'auth_providers.dart';
import 'dao_providers.dart';
import 'store_providers.dart';

final storesStreamProvider = StreamProvider<List<Store>>(
  (ref) => ref.watch(storeDaoProvider).watchAll(),
);

final ingredientsStreamProvider = StreamProvider<List<Ingredient>>(
  (ref) => ref.watch(ingredientDaoProvider).watchAll(),
);

final stockLevelsStreamProvider = StreamProvider<List<StoreStockLevel>>(
  (ref) => ref.watch(lotDaoProvider).watchStockLevelsByStore(),
);

/// 지금 보고 있는 범위의 부족 목록.
///
/// 판정 대상 매장은 세션 역할에서 직접 끌어낸다. `activeStoreIdProvider`를
/// 쓰지 않는 이유는 그 provider의 null이 "사장의 전체 합산"과 "매장이 없는
/// 직원" 두 가지를 뜻해서, 후자에게 전 매장이 보일 수 있기 때문이다.
final shortagesProvider = Provider<List<StockShortage>>((ref) {
  final session = ref.watch(authSessionProvider);
  if (session == null) return const [];

  final allStores = ref.watch(storesStreamProvider).valueOrNull ?? const [];
  final ingredients =
      ref.watch(ingredientsStreamProvider).valueOrNull ?? const [];
  final levels = ref.watch(stockLevelsStreamProvider).valueOrNull ?? const [];

  final List<Store> stores;
  if (session.isOwner) {
    final selected = ref.watch(selectedStoreProvider);
    stores = selected == null
        ? allStores
        : allStores.where((s) => s.id == selected.id).toList();
  } else {
    final storeId = session.storeId;
    if (storeId == null) return const [];
    stores = allStores.where((s) => s.id == storeId).toList();
  }

  return calculateShortages(
    ingredients: ingredients,
    stores: stores,
    levels: levels,
  );
});

/// 탭 배지용 부족 건수.
final shortageCountProvider = Provider<int>(
  (ref) => ref.watch(shortagesProvider).length,
);
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/core/providers/shortage_providers_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/core/providers/shortage_providers.dart test/core/providers/shortage_providers_test.dart
git commit -m "feat: add shortage providers scoped by session role

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: 부족 재고 화면

**Files:**
- Create: `lib/features/shortage/shortage_screen.dart`
- Test: `test/features/shortage/shortage_screen_test.dart`

**Interfaces:**
- Consumes: `shortagesProvider`(Task 5), `ingredientsStreamProvider`(Task 5), 기존 `StoreSwitcher`, `CenteredContent`, `EmptyState`, `AppColors`, `AppTheme.tabularFigures`, `formatQty`
- Produces: `class ShortageScreen extends ConsumerWidget` — 인자 없는 생성자(`const ShortageScreen({super.key})`)라 Task 7의 `static const _primaryScreens`에 바로 들어간다. 카드 위젯 키는 `Key('shortageCard_<ingredientId>_<storeId>')`.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/features/shortage/shortage_screen_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/auth_providers.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/features/shortage/shortage_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-1', name: '울산점'),
    );
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-2', name: '부산점'),
    );
  });

  tearDown(() => db.close());

  Future<int> addTrackedIngredient(String name, double safety) =>
      db.ingredientDao.insertIngredient(
        IngredientsCompanion.insert(
          name: name,
          baseUnit: 'g',
          purchaseUnit: '박스',
          conversionFactor: 20000,
          isExpiryTracked: false,
          safetyStockQty: Value(safety),
        ),
      );

  Future<void> pumpScreen(WidgetTester tester, AuthSession session) async {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    container.read(authSessionProvider.notifier).setSession(session);

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
  }

  Future<void> disposeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  AuthSession owner() => AuthSession(
        id: 'owner-1',
        email: 'owner@internal.local',
        pin: '123456',
        displayName: '사장님',
        role: 'owner',
      );

  AuthSession staff({String? storeId}) => AuthSession(
        id: 'staff-1',
        email: 'staff@internal.local',
        pin: '111111',
        displayName: '직원1',
        role: 'staff',
        storeId: storeId,
        storeName: storeId == null ? null : '울산점',
      );

  testWidgets('기준에 못 미치는 품목이 매장별 카드로 보인다', (tester) async {
    final id = await addTrackedIngredient('양파', 5000);

    await pumpScreen(tester, owner());

    expect(find.byKey(Key('shortageCard_${id}_store-1')), findsOneWidget);
    expect(find.byKey(Key('shortageCard_${id}_store-2')), findsOneWidget);
    expect(find.textContaining('양파'), findsWidgets);

    await disposeScreen(tester);
  });

  testWidgets('직원 세션에서는 자기 매장 건만 보인다', (tester) async {
    final id = await addTrackedIngredient('양파', 5000);

    await pumpScreen(tester, staff(storeId: 'store-1'));

    expect(find.byKey(Key('shortageCard_${id}_store-1')), findsOneWidget);
    expect(find.byKey(Key('shortageCard_${id}_store-2')), findsNothing);

    await disposeScreen(tester);
  });

  testWidgets('매장이 지정되지 않은 직원에게는 아무 카드도 보이지 않는다',
      (tester) async {
    final id = await addTrackedIngredient('양파', 5000);

    await pumpScreen(tester, staff());

    expect(find.byKey(Key('shortageCard_${id}_store-1')), findsNothing);
    expect(find.byKey(Key('shortageCard_${id}_store-2')), findsNothing);

    await disposeScreen(tester);
  });

  testWidgets('안전재고가 설정된 품목이 없으면 설정 안내가 보인다',
      (tester) async {
    await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
      ),
    );

    await pumpScreen(tester, owner());

    expect(find.text('안전재고가 설정된 품목이 없습니다'), findsOneWidget);

    await disposeScreen(tester);
  });

  testWidgets('추적 중인데 전부 기준 이상이면 충분하다는 안내가 보인다',
      (tester) async {
    final id = await addTrackedIngredient('양파', 100);
    for (final store in ['store-1', 'store-2']) {
      await db.lotDao.insertLot(
        LotsCompanion.insert(
          ingredientId: id,
          storeId: Value(store),
          receivedDate: DateTime(2026, 10, 1),
          unitCost: 10,
          remainingQty: 500,
        ),
      );
    }

    await pumpScreen(tester, owner());

    expect(find.text('모든 품목이 기준 이상입니다'), findsOneWidget);

    await disposeScreen(tester);
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/features/shortage/shortage_screen_test.dart`
Expected: FAIL — `lib/features/shortage/shortage_screen.dart` 파일이 없어 컴파일 에러

- [ ] **Step 3: 화면 작성**

`lib/features/shortage/shortage_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/quantity_format.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/shortage_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../domain/stock_shortage.dart';
import '../stock/store_switcher.dart';

const _kContentMaxWidth = 1100.0;
const _kPagePadding = 16.0;
const _kGap = 12.0;
const _kMinCardWidth = 240.0;
const _kMaxColumns = 4;

class ShortageScreen extends ConsumerWidget {
  const ShortageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortages = ref.watch(shortagesProvider);
    final ingredients =
        ref.watch(ingredientsStreamProvider).valueOrNull ?? const [];
    final hasTrackedIngredient = ingredients.any(
      (i) => (i.safetyStockQty ?? 0) > 0,
    );
    final isOwner = ref.watch(authSessionProvider)?.isOwner ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('부족 재고'),
        actions: const [StoreSwitcher()],
      ),
      body: shortages.isEmpty
          ? _buildEmpty(hasTrackedIngredient)
          : _buildGrid(shortages, showStoreName: isOwner),
    );
  }

  Widget _buildEmpty(bool hasTrackedIngredient) {
    if (!hasTrackedIngredient) {
      return const EmptyState(
        icon: Icons.tune,
        title: '안전재고가 설정된 품목이 없습니다',
        message: '품목 관리에서 안전재고를 정하면 부족한 품목이 여기에 표시됩니다',
      );
    }
    return const EmptyState(
      icon: Icons.check_circle_outline,
      title: '모든 품목이 기준 이상입니다',
      message: '안전재고 밑으로 떨어지면 여기에 표시됩니다',
    );
  }

  Widget _buildGrid(
    List<StockShortage> shortages, {
    required bool showStoreName,
  }) {
    return CenteredContent(
      maxWidth: _kContentMaxWidth,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = _columnsFor(constraints.maxWidth);
          final rowCount = (shortages.length / columns).ceil();

          return ListView.builder(
            padding: const EdgeInsets.all(_kPagePadding),
            itemCount: rowCount,
            itemBuilder: (context, rowIndex) {
              final start = rowIndex * columns;
              return Padding(
                padding: const EdgeInsets.only(bottom: _kGap),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < columns; i++) ...[
                      if (i > 0) const SizedBox(width: _kGap),
                      Expanded(
                        child: start + i < shortages.length
                            ? _ShortageCard(
                                shortage: shortages[start + i],
                                showStoreName: showStoreName,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  int _columnsFor(double maxWidth) {
    final available = maxWidth - _kPagePadding * 2;
    final fit = ((available + _kGap) / (_kMinCardWidth + _kGap)).floor();
    return fit.clamp(1, _kMaxColumns);
  }
}

class _ShortageCard extends StatelessWidget {
  const _ShortageCard({required this.shortage, required this.showStoreName});

  final StockShortage shortage;
  final bool showStoreName;

  @override
  Widget build(BuildContext context) {
    final empty = shortage.currentQty <= 0;
    final unit = shortage.ingredient.baseUnit;

    return Container(
      key: Key(
        'shortageCard_${shortage.ingredient.id}_${shortage.store.id}',
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: empty ? AppColors.dangerBackground : AppColors.surface,
        border: Border.all(
          color: empty ? AppColors.dangerBorder : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  shortage.ingredient.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textStrong,
                  ),
                ),
              ),
              if (showStoreName) ...[
                const SizedBox(width: 8),
                InfoChip(shortage.store.name),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${formatQty(shortage.currentQty)}$unit'
            ' / 기준 ${formatQty(shortage.safetyStockQty)}$unit',
            style: TextStyle(
              fontSize: 13,
              color: empty ? AppColors.danger : AppColors.textBody,
              fontFeatures: AppTheme.tabularFigures,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: shortage.fillRatio.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.chipBackground,
              valueColor: AlwaysStoppedAnimation(
                empty ? AppColors.danger : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${formatQty(shortage.shortfall)}$unit 부족',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
              fontFeatures: AppTheme.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/features/shortage/shortage_screen_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/shortage test/features/shortage
git commit -m "feat: add the shortage screen

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: 부족 재고 탭과 배지

**Files:**
- Modify: `lib/core/shell/app_shell.dart`
- Test: `test/core/shell/app_shell_test.dart`

**Interfaces:**
- Consumes: `ShortageScreen`(Task 6), `shortageCountProvider`(Task 5)
- Produces: 동작 변경만 — `_primaryScreens`가 4개가 되고, 폰 "더보기"는 인덱스 4, Windows 사장 전용 항목은 6·7이 된다.

- [ ] **Step 1: 실패하는 테스트 추가**

`test/core/shell/app_shell_test.dart` 맨 끝(`}` 앞)에 추가:

```dart

  testWidgets('부족 탭이 데스크톱 사이드바와 폰 하단 탭 모두에 있다',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('부족 재고'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('부족 재고'),
      ),
    );
    await tester.pump();
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 3);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('탭이 늘어난 뒤에도 폰 하단의 더보기가 열린다', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('더보기'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MoreScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('탭이 늘어난 뒤에도 사장 전용 항목이 올바른 화면을 연다',
      (tester) async {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    container.read(authSessionProvider.notifier).setSession(
          AuthSession(
            id: 'user-1',
            email: 'owner@internal.local',
            pin: '123456',
            displayName: '사장님',
            role: 'owner',
          ),
        );

    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('직원 추가'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('직원 추가'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
```

이 파일에는 `MoreScreen` import가 이미 있다. 없으면 추가한다:

```dart
import 'package:stockcontrol/core/shell/more_screen.dart';
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/core/shell/app_shell_test.dart`
Expected: FAIL — "부족 재고" 항목이 없다

- [ ] **Step 3: 화면 목록에 추가**

`lib/core/shell/app_shell.dart` import에 추가:

```dart
import '../../features/shortage/shortage_screen.dart';
import '../providers/shortage_providers.dart';
```

`_primaryScreens`를 교체:

```dart
  static const _primaryScreens = [
    StockOverviewScreen(),
    InboundFormScreen(),
    CountScreen(),
    ShortageScreen(),
  ];
```

- [ ] **Step 4: 사이드바에 항목 추가하고 사장 전용 인덱스 밀기**

`_buildDesktop()`의 `onDestinationSelected` 분기를 교체 (5→6, 6→7):

```dart
            onDestinationSelected: (index) {
              if (isOwner && index == 6) {
                pushAddStaffScreen(context);
                return;
              }
              if (isOwner && index == 7) {
                pushStoreManagementScreen(context);
                return;
              }
              setState(() => _selectedIndex = index);
            },
```

같은 메서드의 `destinations` 목록에서 '마감 실사' 항목 **바로 뒤**, '거래처 관리' 항목 앞에 추가:

```dart
              NavigationRailDestination(
                icon: _ShortageIcon(count: ref.watch(shortageCountProvider)),
                label: const Text('부족 재고'),
              ),
```

- [ ] **Step 5: 폰 하단 탭에 추가하고 더보기 인덱스 밀기**

`_buildMobile()`의 `onTap` 분기에서 `if (index == 3)`을 `if (index == 4)`로 바꾼다.

같은 메서드의 `items` 목록에서 '실사' 항목 뒤, '더보기' 앞에 추가 (`items`가 `const` 리스트이므로 `const` 키워드를 제거해야 한다):

```dart
          BottomNavigationBarItem(
            icon: _ShortageIcon(count: ref.watch(shortageCountProvider)),
            label: '부족',
          ),
```

`items: const [` 를 `items: [` 로 바꾸고, 나머지 항목 각각에 `const`를 붙인다:

```dart
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: '재고',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.input), label: '입고'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.fact_check_outlined),
            label: '실사',
          ),
          BottomNavigationBarItem(
            icon: _ShortageIcon(count: ref.watch(shortageCountProvider)),
            label: '부족',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: '더보기',
          ),
        ],
```

- [ ] **Step 6: 배지 위젯 추가**

`lib/core/shell/app_shell.dart` 파일 맨 끝(`_AppShellState` 클래스 바깥)에 추가:

```dart
/// 부족 건수를 아이콘 위에 빨간 숫자로 올린다. 0이면 숫자를 숨긴다.
class _ShortageIcon extends StatelessWidget {
  const _ShortageIcon({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: AppColors.danger,
      child: const Icon(Icons.report_problem_outlined),
    );
  }
}
```

- [ ] **Step 7: 테스트 실행하여 통과 확인**

Run: `flutter test test/core/shell/app_shell_test.dart`
Expected: PASS (기존 테스트 + 신규 3개). 기존 "shows a navigation rail with 5 destinations..." 테스트는 목적지 개수를 세지 않고 '거래처 관리'/'품목 관리' 텍스트와 인덱스 0·1만 확인하므로 그대로 통과한다. 실패하면 그 테스트가 기대하는 인덱스를 새 배치에 맞게 고친다.

- [ ] **Step 8: 전체 테스트로 회귀 확인**

Run: `flutter test`
Expected: 전부 PASS

- [ ] **Step 9: Commit**

```bash
git add lib/core/shell/app_shell.dart test/core/shell/app_shell_test.dart
git commit -m "feat: add the shortage tab with a count badge

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: 품목 화면에서 안전재고 보기·설정·수정

**Files:**
- Modify: `lib/core/widgets/app_widgets.dart`
- Modify: `lib/features/ingredient_management/ingredient_list_screen.dart`
- Test: `test/features/ingredient_management/ingredient_list_screen_test.dart`

**Interfaces:**
- Consumes: `IngredientDao.updateSafetyStock`(Task 3), `formatQty`
- Produces: `AppListCard`에 선택 인자 `VoidCallback? onTap` 추가

- [ ] **Step 1: 실패하는 테스트 작성**

`test/features/ingredient_management/ingredient_list_screen_test.dart` (새 파일):

```dart
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/features/ingredient_management/ingredient_list_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addIngredient({double? safety}) =>
      db.ingredientDao.insertIngredient(
        IngredientsCompanion.insert(
          name: '양파',
          baseUnit: 'g',
          purchaseUnit: '박스',
          conversionFactor: 20000,
          isExpiryTracked: false,
          safetyStockQty: Value(safety),
        ),
      );

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: IngredientListScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> disposeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('설정된 안전재고가 목록에 보인다', (tester) async {
    await addIngredient(safety: 5000);

    await pumpScreen(tester);

    expect(find.text('안전재고 5,000g'), findsOneWidget);

    await disposeScreen(tester);
  });

  testWidgets('품목을 누르면 안전재고를 고칠 수 있다', (tester) async {
    final id = await addIngredient();

    await pumpScreen(tester);
    await tester.tap(find.text('양파'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('safetyStockField')),
      '5000',
    );
    await tester.tap(find.widgetWithText(TextButton, '저장'));
    await tester.pumpAndSettle();

    final saved = (await db.ingredientDao.watchAll().first)
        .firstWhere((i) => i.id == id);
    expect(saved.safetyStockQty, 5000);

    await disposeScreen(tester);
  });

  testWidgets('안전재고를 비우면 추적이 해제된다', (tester) async {
    final id = await addIngredient(safety: 5000);

    await pumpScreen(tester);
    await tester.tap(find.text('양파'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('safetyStockField')), '');
    await tester.tap(find.widgetWithText(TextButton, '저장'));
    await tester.pumpAndSettle();

    final saved = (await db.ingredientDao.watchAll().first)
        .firstWhere((i) => i.id == id);
    expect(saved.safetyStockQty, isNull);

    await disposeScreen(tester);
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/features/ingredient_management/ingredient_list_screen_test.dart`
Expected: FAIL — 안전재고 표시도, 누를 수 있는 카드도 없다

- [ ] **Step 3: `AppListCard`에 onTap 추가**

`lib/core/widgets/app_widgets.dart`의 `AppListCard` 전체를 아래로 교체:

```dart
/// 목록 한 줄(거래처, 품목, 매장 등): 제목 + 보조 설명 + 오른쪽 위젯.
class AppListCard extends StatelessWidget {
  const AppListCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: AppColors.surface,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textStrong,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 품목 목록에 안전재고 표시와 수정 붙이기**

`lib/features/ingredient_management/ingredient_list_screen.dart`의 `itemBuilder` 안 `AppListCard(...)` 호출을 교체:

```dart
                final ingredient = ingredients[index];
                final safety = ingredient.safetyStockQty;
                return AppListCard(
                  title: ingredient.name,
                  subtitle: '${ingredient.purchaseUnit} = '
                      '${formatQty(ingredient.conversionFactor)}'
                      '${ingredient.baseUnit}',
                  trailing: safety == null
                      ? (ingredient.isExpiryTracked
                          ? const InfoChip('유통기한 관리')
                          : null)
                      : InfoChip(
                          '안전재고 ${formatQty(safety)}${ingredient.baseUnit}',
                        ),
                  onTap: () => _showSafetyStockDialog(context, dao, ingredient),
                );
```

같은 파일 클래스 안, `_showAddDialog` 앞에 추가:

```dart
  /// 안전재고 값만 고친다. 이름·단위·환산계수는 과거 로트와 어긋날 수 있어
  /// 이번 범위에서 수정 대상이 아니다.
  Future<void> _showSafetyStockDialog(
    BuildContext context,
    IngredientDao dao,
    Ingredient ingredient,
  ) async {
    final controller = TextEditingController(
      text: ingredient.safetyStockQty == null
          ? ''
          : formatQty(ingredient.safetyStockQty!).replaceAll(',', ''),
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${ingredient.name} 안전재고'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('safetyStockField'),
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '안전재고',
                  suffixText: ingredient.baseUnit,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '비워 두면 이 품목은 부족 알림에서 제외됩니다.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final parsed = double.tryParse(controller.text.trim());
              await dao.updateSafetyStock(
                ingredient.id,
                parsed == null || parsed <= 0 ? null : parsed,
              );
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
```

파일 맨 위 import에 추가:

```dart
import '../../core/theme/app_theme.dart';
```

- [ ] **Step 5: 신규 등록 다이얼로그에도 안전재고 입력칸 추가**

같은 파일 `_showAddDialog` 안, '구매단위 1개 = base unit 몇 개' `TextField` **뒤**에 컨트롤러와 입력칸을 추가한다. 먼저 `_showAddDialog` 상단의 컨트롤러 선언 옆에 추가:

```dart
    final safetyStockController = TextEditingController();
```

그리고 환산계수 `TextField` 뒤에 추가:

```dart
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('newSafetyStockField'),
                    controller: safetyStockController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '안전재고 (선택)',
                    ),
                  ),
```

같은 다이얼로그의 '저장' 버튼에서 `IngredientsCompanion.insert(...)` 호출에 한 줄 추가:

```dart
                    safetyStockQty: Value(
                      () {
                        final v =
                            double.tryParse(safetyStockController.text.trim());
                        return v == null || v <= 0 ? null : v;
                      }(),
                    ),
```

- [ ] **Step 6: 테스트 실행하여 통과 확인**

Run: `flutter test test/features/ingredient_management/ingredient_list_screen_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 7: 전체 테스트로 회귀 확인**

Run: `flutter test`
Expected: 전부 PASS — `AppListCard`를 쓰는 거래처·매장 관리 화면이 깨지지 않았는지 확인한다.

- [ ] **Step 8: Commit**

```bash
git add lib/core/widgets/app_widgets.dart lib/features/ingredient_management test/features/ingredient_management
git commit -m "feat: show and edit safety stock on the ingredient screen

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: 부족 카드에서 입고 등록으로 이동

**Files:**
- Modify: `lib/features/inbound/inbound_form_screen.dart`
- Modify: `lib/features/shortage/shortage_screen.dart`
- Test: `test/features/shortage/shortage_screen_test.dart`

**Interfaces:**
- Consumes: `StockShortage`(Task 1), `selectedStoreProvider`
- Produces: `InboundFormScreen({super.key, Ingredient? initialIngredient})` — 기존 호출부(`const InboundFormScreen()`)는 그대로 동작한다.

- [ ] **Step 1: 실패하는 테스트 추가**

`test/features/shortage/shortage_screen_test.dart` 맨 끝(`}` 앞)에 추가하고, 파일 상단에 import 두 줄을 넣는다:

```dart
import 'package:stockcontrol/core/providers/store_providers.dart';
import 'package:stockcontrol/features/inbound/inbound_form_screen.dart';
```

```dart

  testWidgets('부족 카드를 누르면 그 품목으로 입고 등록이 열리고, 전체를 보던 '
      '사장은 그 매장이 선택된다', (tester) async {
    final id = await addTrackedIngredient('양파', 5000);

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    container.read(authSessionProvider.notifier).setSession(owner());

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

    expect(container.read(selectedStoreProvider), isNull);

    await tester.tap(find.byKey(Key('shortageCard_${id}_store-1')));
    await tester.pumpAndSettle();

    expect(find.byType(InboundFormScreen), findsOneWidget);
    expect(container.read(selectedStoreProvider)?.id, 'store-1');

    final form = tester.widget<InboundFormScreen>(
      find.byType(InboundFormScreen),
    );
    expect(form.initialIngredient?.id, id);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/features/shortage/shortage_screen_test.dart`
Expected: FAIL — `InboundFormScreen`에 `initialIngredient`가 없고, 카드를 눌러도 아무 일도 일어나지 않는다

- [ ] **Step 3: 입고 등록이 품목을 미리 받도록 수정**

`lib/features/inbound/inbound_form_screen.dart`의 위젯 선언을 교체:

```dart
class InboundFormScreen extends ConsumerStatefulWidget {
  const InboundFormScreen({super.key, this.initialIngredient});

  /// 부족 재고 화면에서 넘어올 때 미리 선택해 둘 품목.
  final Ingredient? initialIngredient;

  @override
  ConsumerState<InboundFormScreen> createState() => _InboundFormScreenState();
}
```

같은 파일 `_InboundFormScreenState`의 필드 선언 뒤, `dispose` 앞에 추가:

```dart
  @override
  void initState() {
    super.initState();
    _selectedIngredient = widget.initialIngredient;
  }
```

- [ ] **Step 4: 부족 카드에 탭 동작 연결**

`lib/features/shortage/shortage_screen.dart`에 import 추가:

```dart
import '../../core/providers/store_providers.dart';
import '../inbound/inbound_form_screen.dart';
```

`_ShortageCard`를 `ConsumerWidget`으로 바꾸고 카드를 `InkWell`로 감싼다. 클래스 선언과 `build` 시그니처를 교체:

```dart
class _ShortageCard extends ConsumerWidget {
  const _ShortageCard({required this.shortage, required this.showStoreName});

  final StockShortage shortage;
  final bool showStoreName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
```

그리고 `build`가 돌려주던 바깥 `Container(...)`를 아래 형태로 감싼다 — `key`를 바깥 `InkWell` 쪽으로 옮기고, `Container`에서는 `key`를 뺀다:

```dart
    return InkWell(
      key: Key('shortageCard_${shortage.ingredient.id}_${shortage.store.id}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openInbound(context, ref),
      child: Container(
        padding: const EdgeInsets.all(14),
        // ... 기존 decoration과 child 그대로
      ),
    );
```

`_ShortageCard` 클래스 안에 추가:

```dart
  /// 부족한 품목을 바로 채울 수 있도록 입고 등록으로 보낸다. 사장이 전체 합산을
  /// 보던 중이었다면 그 카드의 매장으로 선택을 옮긴다 — 입고 등록은 매장이
  /// 정해져야 동작하고, 이 카드를 눌렀다는 것은 그 매장 일을 하겠다는 뜻이다.
  void _openInbound(BuildContext context, WidgetRef ref) {
    final session = ref.read(authSessionProvider);
    if (session?.isOwner ?? false) {
      ref.read(selectedStoreProvider.notifier).state = shortage.store;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InboundFormScreen(
          initialIngredient: shortage.ingredient,
        ),
      ),
    );
  }
```

- [ ] **Step 5: 테스트 실행하여 통과 확인**

Run: `flutter test test/features/shortage/shortage_screen_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 6: 전체 테스트와 정적 분석**

Run: `flutter analyze lib test`
Expected: `No issues found!`

Run: `flutter test`
Expected: 전부 PASS

- [ ] **Step 7: Commit**

```bash
git add lib/features/inbound/inbound_form_screen.dart lib/features/shortage test/features/shortage
git commit -m "feat: open inbound registration from a shortage card

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 10: Supabase 트리거와 수동 확인

**Files:** 코드 변경 없음. 사용자가 Supabase에서 SQL을 1회 실행하고 두 기기로 확인한다.

**Interfaces:**
- Consumes: Task 3(고칠 때 큐에 쌓기), Task 4(받아서 갱신하기)
- Produces: 서버 `ingredients` 테이블이 UPDATE될 때도 `synced_at`을 새로 찍는다 — 이것이 없으면 다른 기기가 바뀐 값을 영영 가져가지 않는다.

- [ ] **Step 1: Supabase SQL Editor에서 실행 (사용자)**

```sql
create or replace function public.touch_synced_at()
returns trigger language plpgsql as $$
begin
  new.synced_at = now();
  return new;
end;
$$;

create trigger ingredients_touch_synced_at
  before update on public.ingredients
  for each row execute function public.touch_synced_at();
```

실행 후 "Success" 표시를 확인한다. 이 트리거는 `ingredients`에만 건다. 나머지 세 테이블은 기록용이라 수정될 일이 없다.

- [ ] **Step 2: 앱 두 개 실행**

앱이 켜져 있으면 끄고 다시 실행한다 (실행 중에는 Windows 빌드가 실행 파일을 덮어쓰지 못한다 — `LNK1168`).

```bash
flutter run -d windows
flutter run -d emulator-5554
```

- [ ] **Step 3: 안전재고 설정과 부족 목록 확인 (Windows)**

품목 관리에서 품목 하나를 눌러 안전재고를 현재 재고보다 큰 값으로 넣는다. 부족 재고 탭에 그 품목이 뜨고, 탭에 빨간 숫자가 보이는지 확인한다. 재고가 0인 품목(현재 로컬 DB에 4개 있다)이 맨 위에 오는지 함께 본다.

- [ ] **Step 4: 다른 기기로 값이 전달되는지 확인**

에뮬레이터에서 더보기 → "지금 동기화"를 누른다. 같은 기준이 반영되어 그 매장 기준으로 부족이 뜨는지 확인한다.

- [ ] **Step 5: 값을 고쳤을 때도 전달되는지 확인 (트리거 확인)**

Windows에서 같은 품목의 안전재고 값을 다른 숫자로 바꾼다. 에뮬레이터에서 동기화한 뒤 바뀐 값이 반영되는지 확인한다. **여기서 반영되지 않으면 Step 1의 트리거가 걸리지 않은 것이다.**

- [ ] **Step 6: 추적 해제 확인**

안전재고를 비워 저장하면 그 품목이 부족 목록에서 사라지고, 다른 기기에서도 동기화 후 사라지는지 확인한다.

- [ ] **Step 7: 입고 등록 연결 확인**

부족 카드를 눌러 입고 등록이 그 품목으로 열리는지, 사장 계정에서 전체 합산을 보던 중이었다면 매장이 그 카드의 매장으로 바뀌는지 확인한다.

- [ ] **Step 8: 직원 계정 확인**

에뮬레이터에서 직원 계정으로 로그인해 자기 매장 부족만 보이는지 확인한다.

---

## Self-Review 결과

**스펙 커버리지**: 안전재고 입력(신규) — Task 8 Step 5 / 안전재고 수정(기존) — Task 3 + Task 8 / 매장별 부족 판정 순수 함수 — Task 1 / 매장+품목별 재고 합계 — Task 2 / provider 구성과 역할별 범위 — Task 5 / 부족 재고 화면과 빈 상태 두 종류 — Task 6 / 탭 추가와 배지, 인덱스 밀림 — Task 7 / 카드에서 입고 등록으로 — Task 9 / 동기화 3군데(보낼 계기, 받아서 반영, 서버 트리거) — Task 3, Task 4, Task 10 / 수동 확인 — Task 10.

**타입 일관성**: `StoreStockLevel{ingredientId, storeId, totalQty}`가 Task 1 정의, Task 2 생성, Task 5 소비에서 같은 필드명을 쓴다. `calculateShortages({ingredients, stores, levels})`의 이름 있는 인자가 Task 1과 Task 5에서 일치한다. `shortagesProvider`/`shortageCountProvider`가 Task 5 정의, Task 6·7 소비에서 일치한다. `InboundFormScreen({initialIngredient})`가 Task 9에서 정의되고 같은 Task의 테스트가 그 이름으로 읽는다. 카드 키 `shortageCard_<ingredientId>_<storeId>`가 Task 6 정의, Task 6·9 테스트에서 일치한다.

**Review Focus 반영**: 매장 없는 직원 — Task 5의 네 번째 테스트와 Task 6의 세 번째 테스트. 탭 인덱스 밀림 — Task 7의 두 번째·세 번째 테스트(더보기, 사장 전용 항목). 안전재고를 다시 비움 — Task 3의 두 번째 테스트와 Task 8의 세 번째 테스트, Task 10 Step 6. pull이 다른 필드를 덮어쓰지 않음 — Task 4의 첫 번째 테스트가 이름·단위·환산계수를 모두 확인한다. 기준과 정확히 같을 때 — Task 1의 네 번째 테스트.

**알려진 한계 (의도적으로 범위 밖)**: 어떤 매장이 실제로 취급하지 않는 품목도 재고 0이라 부족으로 뜬다 — 전 매장이 같은 품목을 쓴다는 전제 때문이다. 시끄러워지면 "그 매장에서 입고한 적 있는 품목만" 거르는 조건을 덧붙인다(새 데이터 불필요). 푸시 알림은 범위 밖이며, 그때 재사용할 수 있도록 판정을 순수 함수로 떼어 두는 것까지만 이번에 한다.
