# syncId 추가 (8-2-1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 거래처/품목/로트/재고이동 네 테이블에 서버 동기화용 `syncId`(UUID) 컬럼을 추가하고, 각 DAO의 insert 메서드가 자동으로 채우게 해서 — 화면이나 리포지토리는 전혀 건드리지 않고 — 8-2-2(실제 동기화)의 전제 조건을 만든다.

**Architecture:** 로컬 자동증가 정수 ID는 그대로 두고, 네 테이블에 nullable `syncId` 컬럼만 추가한다. `syncId` 생성은 화면/리포지토리가 아니라 각 DAO의 insert 메서드 안에서 처리해서, 호출하는 쪽은 아무것도 몰라도 된다.

**Tech Stack:** Flutter, Drift, `uuid` 패키지(신규)

**Spec:** `docs/superpowers/specs/2026-10-01-sync-id-migration-design.md`

## Global Constraints

- 로컬 자동증가 정수 ID 체계는 전혀 바꾸지 않는다 — `syncId`는 추가 컬럼일 뿐, 기존 PK가 아니다
- 화면(`SupplierListScreen`/`IngredientListScreen`)과 `LotRepository`는 이 계획에서 단 한 줄도 수정하지 않는다
- `syncId`는 각 테이블에서 **nullable**이다 — 기존 호출부(테스트 포함)가 전혀 안 깨져야 한다
- 복잡한 `onUpgrade` 마이그레이션을 작성하지 않는다 — 로컬 DB 파일 삭제 후 재시작을 전제로 한다(지금 로컬 데이터는 전부 테스트용)

## Review Focus

- 호출하는 쪽이 `Companion`에 `syncId`를 직접 넣어서 보내도, DAO가 그 값을 무시하고 항상 새로 생성한 값으로 덮어써야 한다 — 안 그러면 테스트/미래 코드가 실수로 중복되거나 빈 `syncId`를 넣을 여지가 생긴다
- 같은 테이블에 연달아 두 번 insert하면 서로 다른 `syncId`가 나와야 한다 — 생성기가 호출마다 진짜 새 값을 만드는지
- `entry.copyWith(syncId: ...)`가 `Companion`에 이미 설정된 다른 필드(이름, 단가 등)를 건드리지 않고 그대로 유지해야 한다 — `copyWith`를 잘못 쓰면 다른 필드가 날아갈 수 있음
- 기존 테스트(거래처/품목/로트/재고이동 DAO 및 그 위의 `LotRepository`/화면 테스트, 수십 개)가 이 계획 이후에도 전부 수정 없이 통과해야 한다
- `schemaVersion` 4로 깨끗하게 새로 설치(onCreate)됐을 때 네 테이블 다 문제없이 만들어져야 한다 — `onUpgrade`에 3→4 전용 로직이 없다는 걸 코드로도 확인해둔다(의도적으로 비워둠을 주석으로 명시)

---

### Task 1: `generateSyncId()` 헬퍼

**Files:**
- Create: `lib/domain/sync_id.dart`
- Test: `test/domain/sync_id_test.dart`

**Interfaces:**
- Produces: `String generateSyncId()` — 호출할 때마다 새 UUID v4 문자열을 반환

- [ ] **Step 1: `uuid` 패키지 추가**

Run:
```bash
flutter pub add uuid
```

- [ ] **Step 2: 실패하는 테스트 작성**

`test/domain/sync_id_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/domain/sync_id.dart';

void main() {
  group('generateSyncId', () {
    test('produces a non-empty string', () {
      expect(generateSyncId(), isNotEmpty);
    });

    test('produces different values on each call', () {
      expect(generateSyncId(), isNot(generateSyncId()));
    });
  });
}
```

- [ ] **Step 3: 테스트 실행하여 실패 확인**

Run: `flutter test test/domain/sync_id_test.dart`
Expected: FAIL — `lib/domain/sync_id.dart` 파일이 없어 컴파일 에러

- [ ] **Step 4: 구현**

`lib/domain/sync_id.dart`:
```dart
import 'package:uuid/uuid.dart';

String generateSyncId() => const Uuid().v4();
```

- [ ] **Step 5: 테스트 실행하여 통과 확인**

Run: `flutter test test/domain/sync_id_test.dart`
Expected: PASS (2 tests passed)

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/domain/sync_id.dart test/domain/sync_id_test.dart
git commit -m "feat: add generateSyncId helper for future server sync"
```

---

### Task 2: 네 테이블에 `syncId` 컬럼 추가

**Files:**
- Modify: `lib/data/local/tables/suppliers_table.dart`
- Modify: `lib/data/local/tables/ingredients_table.dart`
- Modify: `lib/data/local/tables/lots_table.dart`
- Modify: `lib/data/local/tables/stock_movements_table.dart`
- Modify: `lib/data/local/database.dart`

**Interfaces:**
- Produces: `Suppliers.syncId`, `Ingredients.syncId`, `Lots.syncId`, `StockMovements.syncId` — 전부 `TextColumn`, nullable. `AppDatabase.schemaVersion == 4`

- [ ] **Step 1: Suppliers에 syncId 추가**

`lib/data/local/tables/suppliers_table.dart` 전체를 아래로 교체:
```dart
import 'package:drift/drift.dart';

class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get contact => text().nullable()();
  TextColumn get memo => text().nullable()();
  TextColumn get syncId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

- [ ] **Step 2: Ingredients에 syncId 추가**

`lib/data/local/tables/ingredients_table.dart` 전체를 아래로 교체:
```dart
import 'package:drift/drift.dart';

class Ingredients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get category => text().nullable()();
  TextColumn get baseUnit => text()();
  TextColumn get purchaseUnit => text()();
  RealColumn get conversionFactor => real()();
  BoolColumn get isExpiryTracked => boolean()();
  RealColumn get safetyStockQty => real().nullable()();
  TextColumn get syncId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

- [ ] **Step 3: Lots에 syncId 추가**

`lib/data/local/tables/lots_table.dart` 전체를 아래로 교체:
```dart
import 'package:drift/drift.dart';

import 'ingredients_table.dart';
import 'stores_table.dart';
import 'suppliers_table.dart';

class Lots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ingredientId => integer().references(Ingredients, #id)();
  IntColumn get supplierId =>
      integer().nullable().references(Suppliers, #id)();
  TextColumn get storeId => text().nullable().references(Stores, #id)();
  TextColumn get syncId => text().nullable()();
  DateTimeColumn get receivedDate => dateTime()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  RealColumn get unitCost => real()();
  RealColumn get remainingQty => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

- [ ] **Step 4: StockMovements에 syncId 추가**

`lib/data/local/tables/stock_movements_table.dart` 전체를 아래로 교체:
```dart
import 'package:drift/drift.dart';

import 'lots_table.dart';

class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get lotId => integer().references(Lots, #id)();
  TextColumn get syncId => text().nullable()();
  TextColumn get type => text()();
  RealColumn get quantity => real()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get memo => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

- [ ] **Step 5: schemaVersion 4로 올리기**

`lib/data/local/database.dart`에서 `schemaVersion` getter를 아래로 교체:
```dart
  @override
  int get schemaVersion => 4;
```

`migration` getter(`onUpgrade` 안의 `if (from < 2) { ... }`)는 그대로 둔다 — 3→4 전용 마이그레이션은 의도적으로 추가하지 않는다(로컬 DB 파일을 지우고 새로 시작하는 걸 전제로 한다. Global Constraints 참고).

- [ ] **Step 6: 코드젠 실행**

Run: `dart run build_runner build`
Expected: `BUILD SUCCESSFUL`, 네 테이블의 `.g.dart` 파일들이 갱신됨

- [ ] **Step 7: 기존 테스트 전체 실행 확인**

Run: `flutter test`
Expected: 전부 그대로 PASS — `syncId`가 nullable이라 기존 `...Companion.insert(...)` 호출부가 전혀 안 깨진다(Global Constraints 참고)

- [ ] **Step 8: Commit**

```bash
git add lib/data/local
git commit -m "feat: add syncId column to suppliers/ingredients/lots/stock_movements"
```

**로컬 DB 파일 삭제 안내**: 이 커밋 이후 `flutter run`하기 전에 기존 `stockcontrol.sqlite` 파일을 지운다.

---

### Task 3: 각 DAO가 insert 시 `syncId` 자동 생성

**Files:**
- Modify: `lib/data/local/daos/supplier_dao.dart`
- Modify: `lib/data/local/daos/ingredient_dao.dart`
- Modify: `lib/data/local/daos/lot_dao.dart`
- Modify: `lib/data/local/daos/stock_movement_dao.dart`
- Test: `test/data/local/supplier_dao_test.dart`
- Test: `test/data/local/ingredient_dao_test.dart`
- Test: `test/data/local/lot_dao_test.dart`
- Test: `test/data/local/stock_movement_dao_test.dart`

**Interfaces:**
- Consumes: `generateSyncId()` (Task 1), `syncId` 컬럼 (Task 2)
- Produces: `SupplierDao.insertSupplier`/`IngredientDao.insertIngredient`/`LotDao.insertLot`/`StockMovementDao.insertMovement` — 시그니처는 그대로, 반환되는 행의 `syncId`가 항상 채워져 있음을 보장

- [ ] **Step 1: 실패하는 테스트 추가 (SupplierDao)**

`test/data/local/supplier_dao_test.dart` 맨 끝(`}` 앞)에 추가:
```dart

  test('insertSupplier always generates a fresh syncId, overriding any '
      'caller-provided value, and keeps other fields intact', () async {
    final id = await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(
        name: '거래처A',
        contact: const Value('010-0000-0000'),
        syncId: const Value('caller-provided-should-be-ignored'),
      ),
    );

    final suppliers = await db.supplierDao.watchAll().first;
    final saved = suppliers.firstWhere((s) => s.id == id);

    expect(saved.syncId, isNotNull);
    expect(saved.syncId, isNot('caller-provided-should-be-ignored'));
    expect(saved.name, '거래처A');
    expect(saved.contact, '010-0000-0000');
  });

  test('insertSupplier produces a different syncId for each call', () async {
    await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(name: '거래처B'),
    );
    await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(name: '거래처C'),
    );

    final suppliers = await db.supplierDao.watchAll().first;
    final syncIds = suppliers.map((s) => s.syncId).toSet();

    expect(syncIds, hasLength(suppliers.length));
  });
```

`test/data/local/supplier_dao_test.dart` 맨 위 import에 `package:drift/drift.dart`(`Value` 사용)를 추가한다:
```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/data/local/supplier_dao_test.dart`
Expected: FAIL — 지금은 `insertSupplier`가 `syncId`를 자동으로 안 채우므로 `saved.syncId`가 `null`이거나(아예 안 채움) 호출자가 보낸 값 그대로(`'caller-provided-should-be-ignored'`) 나와서 `expect`가 깨짐

- [ ] **Step 3: SupplierDao 수정**

`lib/data/local/daos/supplier_dao.dart` 전체를 아래로 교체:
```dart
import 'package:drift/drift.dart';

import '../../../domain/sync_id.dart';
import '../database.dart';
import '../tables/suppliers_table.dart';

part 'supplier_dao.g.dart';

@DriftAccessor(tables: [Suppliers])
class SupplierDao extends DatabaseAccessor<AppDatabase>
    with _$SupplierDaoMixin {
  SupplierDao(super.db);

  Stream<List<Supplier>> watchAll() => select(suppliers).watch();

  Future<int> insertSupplier(SuppliersCompanion entry) => into(suppliers)
      .insert(entry.copyWith(syncId: Value(generateSyncId())));
}
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/data/local/supplier_dao_test.dart`
Expected: PASS (3 tests passed — 기존 1개 + 신규 2개)

- [ ] **Step 5: IngredientDao도 동일하게 수정**

`test/data/local/ingredient_dao_test.dart` 맨 끝(`}` 앞)에 추가:
```dart

  test('insertIngredient always generates a syncId', () async {
    final id = await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
      ),
    );

    final ingredients = await db.ingredientDao.watchAll().first;
    final saved = ingredients.firstWhere((i) => i.id == id);

    expect(saved.syncId, isNotNull);
  });
```

`lib/data/local/daos/ingredient_dao.dart` 전체를 아래로 교체:
```dart
import 'package:drift/drift.dart';

import '../../../domain/sync_id.dart';
import '../database.dart';
import '../tables/ingredients_table.dart';

part 'ingredient_dao.g.dart';

@DriftAccessor(tables: [Ingredients])
class IngredientDao extends DatabaseAccessor<AppDatabase>
    with _$IngredientDaoMixin {
  IngredientDao(super.db);

  Stream<List<Ingredient>> watchAll() => select(ingredients).watch();

  Future<int> insertIngredient(IngredientsCompanion entry) => into(ingredients)
      .insert(entry.copyWith(syncId: Value(generateSyncId())));
}
```

Run: `flutter test test/data/local/ingredient_dao_test.dart`
Expected: PASS

- [ ] **Step 6: LotDao도 동일하게 수정**

`test/data/local/lot_dao_test.dart` 맨 끝(`}` 앞)에 추가:
```dart

  test('insertLot always generates a syncId', () async {
    final lotId = await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 3),
        unitCost: 15.0,
        remainingQty: 20000,
      ),
    );

    final lot = await db.lotDao.getById(lotId);
    expect(lot.syncId, isNotNull);
  });
```

`lib/data/local/daos/lot_dao.dart`에서 `insertLot` 메서드를 아래로 교체:
```dart
  Future<int> insertLot(LotsCompanion entry) =>
      into(lots).insert(entry.copyWith(syncId: Value(generateSyncId())));
```

파일 맨 위 import 목록에 추가:
```dart
import '../../../domain/sync_id.dart';
```

Run: `flutter test test/data/local/lot_dao_test.dart`
Expected: PASS

- [ ] **Step 7: StockMovementDao도 동일하게 수정**

`test/data/local/stock_movement_dao_test.dart` 맨 끝(`}` 앞)에 추가:
```dart

  test('insertMovement always generates a syncId', () async {
    final movementId = await db.stockMovementDao.insertMovement(
      StockMovementsCompanion.insert(
        lotId: lotId,
        type: 'inbound',
        quantity: 100,
        occurredAt: DateTime(2026, 9, 3),
      ),
    );

    final movements = await db.stockMovementDao.movementsForLot(lotId);
    final saved = movements.firstWhere((m) => m.id == movementId);

    expect(saved.syncId, isNotNull);
  });
```

`test/data/local/stock_movement_dao_test.dart`의 기존 `setUp`에 이미 `lotId`(로컬 로트 ID)가 만들어져 있으니 그대로 재사용한다.

`lib/data/local/daos/stock_movement_dao.dart` 전체를 아래로 교체:
```dart
import 'package:drift/drift.dart';

import '../../../domain/sync_id.dart';
import '../database.dart';
import '../tables/stock_movements_table.dart';

part 'stock_movement_dao.g.dart';

@DriftAccessor(tables: [StockMovements])
class StockMovementDao extends DatabaseAccessor<AppDatabase>
    with _$StockMovementDaoMixin {
  StockMovementDao(super.db);

  Future<int> insertMovement(StockMovementsCompanion entry) =>
      into(stockMovements)
          .insert(entry.copyWith(syncId: Value(generateSyncId())));

  Future<List<StockMovement>> movementsForLot(int lotId) =>
      (select(stockMovements)..where((m) => m.lotId.equals(lotId))).get();
}
```

Run: `flutter test test/data/local/stock_movement_dao_test.dart`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add lib/data/local/daos test/data/local
git commit -m "feat: auto-generate syncId on insert for suppliers/ingredients/lots/stock_movements"
```

---

### Task 4: 전체 회귀 확인

- [ ] **Step 1: 정적 분석 확인**

Run: `flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 2: 전체 테스트 실행**

Run: `flutter test`
Expected: 2차(매장 화면 연동) 끝낸 시점의 81개에 이번 계획에서 늘어난 7개(Task 1: `generateSyncId` 2개, Task 3: Supplier +2, Ingredient +1, Lot +1, StockMovement +1)를 더해 총 88개 통과

- [ ] **Step 3: 수동 확인**

로컬 `stockcontrol.sqlite` 파일을 지우고 `flutter run -d windows`(또는 `chrome`) 실행 → 로그인 → 거래처/품목 등록, 입고 등록, 마감 실사까지 평소처럼 전부 정상 동작하는지 확인(화면 동작 자체는 이번 계획에서 하나도 안 바뀌었으니 달라지는 건 없어야 한다)

---

## Self-Review 결과

**스펙 커버리지**: `uuid` 패키지 + `generateSyncId()` — Task 1 / 네 테이블 `syncId` 컬럼 + schemaVersion 4 — Task 2 / DAO가 insert 시 자동 생성 — Task 3 / 화면·`LotRepository` 무변경 — 전체 태스크에서 건드리지 않음(계획에 해당 파일이 등장하지 않음으로 확인됨) / 범위 밖 항목(실제 push/pull, Supabase 테이블) — 이번 계획에 포함하지 않음, 스펙과 일치.

**타입 일관성 확인**: `generateSyncId()`(Task 1)가 Task 3의 네 DAO에서 전부 동일한 시그니처로 쓰인다. 각 `...Companion`의 `syncId` 필드명이 Task 2에서 정의한 컬럼명과 Task 3의 `copyWith(syncId: ...)` 호출부에서 전부 일치한다.

**Review Focus 반영 확인**: 호출자가 `syncId`를 직접 넣어도 덮어써지는지 — Task 3 Step 1의 첫 번째 테스트. 연속 insert 시 서로 다른 값 — Task 3 Step 1의 두 번째 테스트. `copyWith`가 다른 필드를 보존하는지 — 같은 테스트에서 `name`/`contact` 값도 같이 검증. 기존 테스트 전체 무변경 통과 — Task 2 Step 7(스키마 변경 직후)과 Task 4 Step 2(전체 완료 후) 두 번 확인. `schemaVersion` 4 onCreate 정상 동작 — Task 2 Step 6(코드젠)과 Task 4 Step 3(실제 앱 실행)에서 확인.
