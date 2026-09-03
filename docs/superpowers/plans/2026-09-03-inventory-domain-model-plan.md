# 도메인 모델 + 로컬 DB + 입고 등록 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flutter + Drift 기반으로 재고관리 앱의 도메인 모델, 로컬 SQLite 스키마, 입고 등록 화면을 구현하여 서버 없이 로컬만으로 입고를 등록/저장할 수 있는 상태를 만든다.

**Architecture:** Drift가 테이블 클래스로부터 데이터 클래스를 자동 생성하므로 (`Ingredients`→`Ingredient`, `Lots`→`Lot` 등), 별도의 손으로 작성한 도메인 데이터 클래스는 만들지 않는다. `lib/domain/`에는 순수 로직(enum, 단위 환산 함수)만 둔다. Supplier/Ingredient는 단순 CRUD이므로 리포지토리 레이어 없이 DAO를 Riverpod provider로 직접 노출한다. Lot 생성은 Lot + StockMovement를 하나의 트랜잭션으로 묶는 실제 로직이 있으므로 `LotRepository`를 둔다. 입고 폼의 상태는 화면 하나에서만 쓰이는 일시적 UI 상태이므로 전역 provider 대신 `ConsumerStatefulWidget`의 로컬 State로 관리한다.

**Tech Stack:** Flutter, Drift (SQLite ORM), drift_flutter, flutter_riverpod

---

## 코드젠 관련 참고사항

Drift는 `@DriftDatabase`/`@DriftAccessor` 어노테이션이 붙은 클래스로부터 `build_runner`가 `*.g.dart` 파일을 생성해야 컴파일이 된다. 즉 테이블/DAO 선언 자체는 코드젠이 끝나기 전까지 "실행 가능한 실패"를 만들 수 없는 순수 스캐폴딩이다. 따라서:

- **테이블 선언 (Task 5)**: 로직이 없는 순수 스키마 선언이므로 테스트를 먼저 쓰지 않는다.
- **DAO (Task 6)**: 코드젠 이후에만 컴파일되므로, 선언 → 코드젠 → 테스트 작성 → 테스트 실행(바로 PASS 기대) 순서로 진행한다. 진짜 "실패하는 테스트"를 만들 수 없는 스캐폴딩 특성 때문이다.
- **순수 로직 (도메인 enum, unit_conversion, LotRepository)**: 코드젠에 의존하지 않으므로 엄격한 TDD(RED→GREEN)를 그대로 적용한다.

---

### Task 1: 의존성 추가

**Files:**
- Modify: `pubspec.yaml`

> **실행 중 발견한 변경사항**: `sqlite3_flutter_libs`는 pub.dev에서 `+eol` 태그가 붙어 있으며, drift 2.32+ / sqlite3 3.x부터는 build hooks로 SQLite가 자동 번들되어 더 이상 직접 의존할 필요가 없다. 대신 drift 공식 문서가 권장하는 `drift_flutter` 패키지의 `driftDatabase()` 헬퍼를 사용한다 — `path`/`path_provider`를 직접 다룰 필요도 없어진다.

- [ ] **Step 1: 런타임 의존성 추가**

Run:
```bash
flutter pub add drift flutter_riverpod drift_flutter
```
Expected: `pubspec.yaml`의 `dependencies:`에 세 패키지가 추가되고 `flutter pub get`이 자동 실행되어 성공 메시지가 뜬다.

- [ ] **Step 2: 개발 의존성 추가**

Run:
```bash
flutter pub add --dev drift_dev build_runner
```
Expected: `pubspec.yaml`의 `dev_dependencies:`에 두 패키지가 추가된다.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add drift, riverpod, and codegen dependencies"
```

---

### Task 2: 도메인 enum — BaseUnit

**Files:**
- Create: `lib/domain/base_unit.dart`
- Test: `test/domain/base_unit_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/domain/base_unit_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/domain/base_unit.dart';

void main() {
  test('round-trips every value through its db string representation', () {
    for (final unit in BaseUnit.values) {
      expect(baseUnitFromDbString(unit.toDbString()), unit);
    }
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/domain/base_unit_test.dart`
Expected: FAIL — `lib/domain/base_unit.dart` 파일이 없어서 컴파일 에러 (`Target of URI doesn't exist`)

- [ ] **Step 3: 최소 구현 작성**

`lib/domain/base_unit.dart`:
```dart
enum BaseUnit { g, ml, ea }

extension BaseUnitDb on BaseUnit {
  String toDbString() => name;
}

BaseUnit baseUnitFromDbString(String value) =>
    BaseUnit.values.firstWhere((unit) => unit.name == value);
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/domain/base_unit_test.dart`
Expected: PASS (1 test passed)

- [ ] **Step 5: Commit**

```bash
git add lib/domain/base_unit.dart test/domain/base_unit_test.dart
git commit -m "feat: add BaseUnit domain enum"
```

---

### Task 3: 도메인 enum — MovementType

**Files:**
- Create: `lib/domain/movement_type.dart`
- Test: `test/domain/movement_type_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/domain/movement_type_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/domain/movement_type.dart';

void main() {
  test('round-trips every value through its db string representation', () {
    for (final type in MovementType.values) {
      expect(movementTypeFromDbString(type.toDbString()), type);
    }
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/domain/movement_type_test.dart`
Expected: FAIL — 파일 없음으로 컴파일 에러

- [ ] **Step 3: 최소 구현 작성**

`lib/domain/movement_type.dart`:
```dart
enum MovementType { inbound, usage, disposal, adjustment, countCorrection }

extension MovementTypeDb on MovementType {
  String toDbString() => name;
}

MovementType movementTypeFromDbString(String value) =>
    MovementType.values.firstWhere((type) => type.name == value);
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/domain/movement_type_test.dart`
Expected: PASS (1 test passed)

- [ ] **Step 5: Commit**

```bash
git add lib/domain/movement_type.dart test/domain/movement_type_test.dart
git commit -m "feat: add MovementType domain enum"
```

---

### Task 4: 도메인 로직 — 단위 환산

**Files:**
- Create: `lib/domain/unit_conversion.dart`
- Test: `test/domain/unit_conversion_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/domain/unit_conversion_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/domain/unit_conversion.dart';

void main() {
  test('multiplies purchase quantity by the conversion factor', () {
    // 2박스, 1박스 = 20kg(=20000g) 이라고 가정
    final result = purchaseQtyToBaseQty(2, 20000);
    expect(result, 40000);
  });

  test('returns zero when purchase quantity is zero', () {
    expect(purchaseQtyToBaseQty(0, 20000), 0);
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/domain/unit_conversion_test.dart`
Expected: FAIL — 파일 없음으로 컴파일 에러

- [ ] **Step 3: 최소 구현 작성**

`lib/domain/unit_conversion.dart`:
```dart
double purchaseQtyToBaseQty(double purchaseQty, double conversionFactor) =>
    purchaseQty * conversionFactor;
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/domain/unit_conversion_test.dart`
Expected: PASS (2 tests passed)

- [ ] **Step 5: Commit**

```bash
git add lib/domain/unit_conversion.dart test/domain/unit_conversion_test.dart
git commit -m "feat: add purchase-to-base unit conversion"
```

---

### Task 5: Drift 테이블 + 데이터베이스 클래스

**Files:**
- Create: `lib/data/local/tables/suppliers_table.dart`
- Create: `lib/data/local/tables/ingredients_table.dart`
- Create: `lib/data/local/tables/lots_table.dart`
- Create: `lib/data/local/tables/stock_movements_table.dart`
- Create: `lib/data/local/database.dart`

- [ ] **Step 1: Suppliers 테이블 작성**

`lib/data/local/tables/suppliers_table.dart`:
```dart
import 'package:drift/drift.dart';

class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get contact => text().nullable()();
  TextColumn get memo => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

- [ ] **Step 2: Ingredients 테이블 작성**

`lib/data/local/tables/ingredients_table.dart`:
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
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

- [ ] **Step 3: Lots 테이블 작성**

`lib/data/local/tables/lots_table.dart`:
```dart
import 'package:drift/drift.dart';

import 'ingredients_table.dart';
import 'suppliers_table.dart';

class Lots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ingredientId => integer().references(Ingredients, #id)();
  IntColumn get supplierId =>
      integer().nullable().references(Suppliers, #id)();
  DateTimeColumn get receivedDate => dateTime()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  RealColumn get unitCost => real()();
  RealColumn get remainingQty => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

- [ ] **Step 4: StockMovements 테이블 작성**

`lib/data/local/tables/stock_movements_table.dart`:
```dart
import 'package:drift/drift.dart';

import 'lots_table.dart';

class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get lotId => integer().references(Lots, #id)();
  TextColumn get type => text()();
  RealColumn get quantity => real()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get memo => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

- [ ] **Step 5: AppDatabase 클래스 작성 (DAO는 다음 태스크에서 채움)**

`drift_flutter`의 `driftDatabase()`가 플랫폼에 맞는 파일 경로/커넥션을 알아서 구성해주므로, `path_provider`를 직접 다루지 않는다. 테스트에서는 생성자의 선택적 `QueryExecutor` 인자로 인메모리 DB를 주입한다.

`lib/data/local/database.dart`:
```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/ingredients_table.dart';
import 'tables/lots_table.dart';
import 'tables/stock_movements_table.dart';
import 'tables/suppliers_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Suppliers, Ingredients, Lots, StockMovements],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'stockcontrol'));

  @override
  int get schemaVersion => 1;
}
```

- [ ] **Step 6: 코드젠 실행**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `BUILD SUCCESSFUL`, `lib/data/local/database.g.dart` 생성됨

- [ ] **Step 7: Commit**

```bash
git add lib/data/local
git commit -m "feat: add drift tables and AppDatabase"
```

---

### Task 6: DAO 4종 + 검증 테스트

**Files:**
- Create: `lib/data/local/daos/supplier_dao.dart`
- Create: `lib/data/local/daos/ingredient_dao.dart`
- Create: `lib/data/local/daos/lot_dao.dart`
- Create: `lib/data/local/daos/stock_movement_dao.dart`
- Modify: `lib/data/local/database.dart`
- Test: `test/data/local/supplier_dao_test.dart`
- Test: `test/data/local/ingredient_dao_test.dart`
- Test: `test/data/local/lot_dao_test.dart`
- Test: `test/data/local/stock_movement_dao_test.dart`

- [ ] **Step 1: SupplierDao 작성**

`lib/data/local/daos/supplier_dao.dart`:
```dart
import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/suppliers_table.dart';

part 'supplier_dao.g.dart';

@DriftAccessor(tables: [Suppliers])
class SupplierDao extends DatabaseAccessor<AppDatabase>
    with _$SupplierDaoMixin {
  SupplierDao(super.db);

  Stream<List<Supplier>> watchAll() => select(suppliers).watch();

  Future<int> insertSupplier(SuppliersCompanion entry) =>
      into(suppliers).insert(entry);
}
```

- [ ] **Step 2: IngredientDao 작성**

`lib/data/local/daos/ingredient_dao.dart`:
```dart
import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/ingredients_table.dart';

part 'ingredient_dao.g.dart';

@DriftAccessor(tables: [Ingredients])
class IngredientDao extends DatabaseAccessor<AppDatabase>
    with _$IngredientDaoMixin {
  IngredientDao(super.db);

  Stream<List<Ingredient>> watchAll() => select(ingredients).watch();

  Future<int> insertIngredient(IngredientsCompanion entry) =>
      into(ingredients).insert(entry);
}
```

- [ ] **Step 3: LotDao 작성**

`lib/data/local/daos/lot_dao.dart`:
```dart
import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/lots_table.dart';

part 'lot_dao.g.dart';

@DriftAccessor(tables: [Lots])
class LotDao extends DatabaseAccessor<AppDatabase> with _$LotDaoMixin {
  LotDao(super.db);

  Future<int> insertLot(LotsCompanion entry) => into(lots).insert(entry);

  Future<Lot> getById(int id) =>
      (select(lots)..where((l) => l.id.equals(id))).getSingle();

  Future<void> updateRemainingQty(int id, double remainingQty) =>
      (update(lots)..where((l) => l.id.equals(id))).write(
        LotsCompanion(remainingQty: Value(remainingQty)),
      );

  Stream<List<Lot>> watchLotsForIngredient(int ingredientId) =>
      (select(lots)..where((l) => l.ingredientId.equals(ingredientId)))
          .watch();
}
```

- [ ] **Step 4: StockMovementDao 작성**

`lib/data/local/daos/stock_movement_dao.dart`:
```dart
import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/stock_movements_table.dart';

part 'stock_movement_dao.g.dart';

@DriftAccessor(tables: [StockMovements])
class StockMovementDao extends DatabaseAccessor<AppDatabase>
    with _$StockMovementDaoMixin {
  StockMovementDao(super.db);

  Future<int> insertMovement(StockMovementsCompanion entry) =>
      into(stockMovements).insert(entry);

  Future<List<StockMovement>> movementsForLot(int lotId) =>
      (select(stockMovements)..where((m) => m.lotId.equals(lotId))).get();
}
```

- [ ] **Step 5: AppDatabase에 DAO 등록**

`lib/data/local/database.dart`의 `@DriftDatabase` 어노테이션과 import를 아래처럼 수정:
```dart
import 'daos/ingredient_dao.dart';
import 'daos/lot_dao.dart';
import 'daos/stock_movement_dao.dart';
import 'daos/supplier_dao.dart';
import 'tables/ingredients_table.dart';
import 'tables/lots_table.dart';
import 'tables/stock_movements_table.dart';
import 'tables/suppliers_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Suppliers, Ingredients, Lots, StockMovements],
  daos: [SupplierDao, IngredientDao, LotDao, StockMovementDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'stockcontrol'));

  @override
  int get schemaVersion => 1;
}
```

- [ ] **Step 6: 코드젠 실행**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `BUILD SUCCESSFUL`, DAO별 `*.g.dart` 파일 생성됨

- [ ] **Step 7: SupplierDao 테스트 작성**

`test/data/local/supplier_dao_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('inserts a supplier and reads it back via watchAll', () async {
    await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(name: '테스트거래처'),
    );

    final suppliers = await db.supplierDao.watchAll().first;

    expect(suppliers, hasLength(1));
    expect(suppliers.first.name, '테스트거래처');
  });
}
```

- [ ] **Step 8: IngredientDao 테스트 작성**

`test/data/local/ingredient_dao_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('inserts an ingredient and reads it back via watchAll', () async {
    await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
      ),
    );

    final ingredients = await db.ingredientDao.watchAll().first;

    expect(ingredients, hasLength(1));
    expect(ingredients.first.name, '양파');
    expect(ingredients.first.conversionFactor, 20000);
  });
}
```

- [ ] **Step 9: LotDao 테스트 작성**

`test/data/local/lot_dao_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';

void main() {
  late AppDatabase db;
  late int ingredientId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ingredientId = await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
      ),
    );
  });

  tearDown(() => db.close());

  test('inserts a lot and updates its remainingQty', () async {
    final lotId = await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 3),
        unitCost: 15.0,
        remainingQty: 20000,
      ),
    );

    await db.lotDao.updateRemainingQty(lotId, 15000);

    final lot = await db.lotDao.getById(lotId);
    expect(lot.remainingQty, 15000);
  });
}
```

- [ ] **Step 10: StockMovementDao 테스트 작성**

`test/data/local/stock_movement_dao_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';

void main() {
  late AppDatabase db;
  late int ingredientId;
  late int lotId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ingredientId = await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
      ),
    );
    lotId = await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 3),
        unitCost: 15.0,
        remainingQty: 20000,
      ),
    );
  });

  tearDown(() => db.close());

  test('inserts a movement linked to a lot', () async {
    await db.stockMovementDao.insertMovement(
      StockMovementsCompanion.insert(
        lotId: lotId,
        type: 'inbound',
        quantity: 20000,
        occurredAt: DateTime(2026, 9, 3),
      ),
    );

    final movements = await db.stockMovementDao.movementsForLot(lotId);

    expect(movements, hasLength(1));
    expect(movements.first.type, 'inbound');
  });
}
```

- [ ] **Step 11: 전체 DAO 테스트 실행**

Run: `flutter test test/data/local`
Expected: PASS (4 tests passed)

- [ ] **Step 12: Commit**

```bash
git add lib/data/local test/data/local
git commit -m "feat: add DAOs for suppliers, ingredients, lots, and stock movements"
```

---

### Task 7: LotRepository — 입고 트랜잭션

**Files:**
- Create: `lib/data/repositories/lot_repository.dart`
- Test: `test/data/repositories/lot_repository_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/data/repositories/lot_repository_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/data/repositories/lot_repository.dart';
import 'package:stockcontrol/domain/movement_type.dart';

void main() {
  late AppDatabase db;
  late LotRepository repository;
  late int ingredientId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = LotRepository(db);
    ingredientId = await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
      ),
    );
  });

  tearDown(() => db.close());

  test('creates a lot and a matching inbound movement atomically', () async {
    final lotId = await repository.receiveLot(
      ingredientId: ingredientId,
      supplierId: null,
      receivedDate: DateTime(2026, 9, 3),
      unitCost: 15.0,
      baseQty: 20000,
    );

    final lot = await db.lotDao.getById(lotId);
    final movements = await db.stockMovementDao.movementsForLot(lotId);

    expect(lot.remainingQty, 20000);
    expect(lot.supplierId, isNull);
    expect(movements, hasLength(1));
    expect(movements.first.type, 'inbound');
    expect(movements.first.quantity, 20000);
  });

  test('registers initial stock as an adjustment movement with no supplier',
      () async {
    final lotId = await repository.receiveLot(
      ingredientId: ingredientId,
      receivedDate: DateTime(2026, 9, 3),
      unitCost: 0,
      baseQty: 5000,
      type: MovementType.adjustment,
      memo: '초기재고',
    );

    final movements = await db.stockMovementDao.movementsForLot(lotId);

    expect(movements.first.type, 'adjustment');
    expect(movements.first.memo, '초기재고');
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/data/repositories/lot_repository_test.dart`
Expected: FAIL — `lib/data/repositories/lot_repository.dart` 파일이 없어 컴파일 에러

- [ ] **Step 3: 최소 구현 작성**

`lib/data/repositories/lot_repository.dart`:
```dart
import 'package:drift/drift.dart';

import '../../domain/movement_type.dart';
import '../local/database.dart';
import '../local/tables/lots_table.dart';
import '../local/tables/stock_movements_table.dart';

class LotRepository {
  LotRepository(this._db);

  final AppDatabase _db;

  Future<int> receiveLot({
    required int ingredientId,
    int? supplierId,
    required DateTime receivedDate,
    DateTime? expiryDate,
    required double unitCost,
    required double baseQty,
    MovementType type = MovementType.inbound,
    String? memo,
  }) {
    return _db.transaction(() async {
      final lotId = await _db.lotDao.insertLot(
        LotsCompanion.insert(
          ingredientId: ingredientId,
          supplierId: Value(supplierId),
          receivedDate: receivedDate,
          expiryDate: Value(expiryDate),
          unitCost: unitCost,
          remainingQty: baseQty,
        ),
      );

      await _db.stockMovementDao.insertMovement(
        StockMovementsCompanion.insert(
          lotId: lotId,
          type: type.toDbString(),
          quantity: baseQty,
          occurredAt: receivedDate,
          memo: Value(memo),
        ),
      );

      return lotId;
    });
  }
}
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/data/repositories/lot_repository_test.dart`
Expected: PASS (2 tests passed)

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories test/data/repositories
git commit -m "feat: add LotRepository with atomic inbound transaction"
```

---

### Task 8: Riverpod providers

**Files:**
- Create: `lib/core/providers/database_provider.dart`
- Create: `lib/core/providers/dao_providers.dart`
- Create: `lib/core/providers/repository_providers.dart`

- [ ] **Step 1: 데이터베이스 provider 작성**

`lib/core/providers/database_provider.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
```

- [ ] **Step 2: DAO provider 작성**

`lib/core/providers/dao_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_provider.dart';

final supplierDaoProvider =
    Provider((ref) => ref.watch(appDatabaseProvider).supplierDao);
final ingredientDaoProvider =
    Provider((ref) => ref.watch(appDatabaseProvider).ingredientDao);
final lotDaoProvider =
    Provider((ref) => ref.watch(appDatabaseProvider).lotDao);
final stockMovementDaoProvider =
    Provider((ref) => ref.watch(appDatabaseProvider).stockMovementDao);
```

- [ ] **Step 3: 리포지토리 provider 작성**

`lib/core/providers/repository_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/lot_repository.dart';
import 'database_provider.dart';

final lotRepositoryProvider = Provider<LotRepository>((ref) {
  return LotRepository(ref.watch(appDatabaseProvider));
});
```

- [ ] **Step 4: 정적 분석 확인**

Run: `flutter analyze lib/core`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/core
git commit -m "feat: add riverpod providers for database, DAOs, and repositories"
```

---

### Task 9: 거래처 관리 화면

**Files:**
- Create: `lib/features/supplier_management/supplier_list_screen.dart`

- [ ] **Step 1: 화면 작성**

`lib/features/supplier_management/supplier_list_screen.dart`:
```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/dao_providers.dart';
import '../../data/local/daos/supplier_dao.dart';
import '../../data/local/database.dart';

class SupplierListScreen extends ConsumerWidget {
  const SupplierListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.watch(supplierDaoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('거래처 관리')),
      body: StreamBuilder<List<Supplier>>(
        stream: dao.watchAll(),
        builder: (context, snapshot) {
          final suppliers = snapshot.data ?? [];
          return ListView.builder(
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final supplier = suppliers[index];
              return ListTile(
                title: Text(supplier.name),
                subtitle:
                    supplier.contact != null ? Text(supplier.contact!) : null,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, dao),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, SupplierDao dao) async {
    final nameController = TextEditingController();
    final contactController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('거래처 등록'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            TextField(
              controller: contactController,
              decoration: const InputDecoration(labelText: '연락처'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              await dao.insertSupplier(
                SuppliersCompanion.insert(
                  name: nameController.text.trim(),
                  contact: Value(
                    contactController.text.trim().isEmpty
                        ? null
                        : contactController.text.trim(),
                  ),
                ),
              );
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 정적 분석 확인**

Run: `flutter analyze lib/features/supplier_management`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/supplier_management
git commit -m "feat: add supplier management screen"
```

---

### Task 10: 품목 관리 화면

**Files:**
- Create: `lib/features/ingredient_management/ingredient_list_screen.dart`

- [ ] **Step 1: 화면 작성**

`lib/features/ingredient_management/ingredient_list_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/dao_providers.dart';
import '../../data/local/daos/ingredient_dao.dart';
import '../../data/local/database.dart';
import '../../domain/base_unit.dart';

class IngredientListScreen extends ConsumerWidget {
  const IngredientListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.watch(ingredientDaoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('품목 관리')),
      body: StreamBuilder<List<Ingredient>>(
        stream: dao.watchAll(),
        builder: (context, snapshot) {
          final ingredients = snapshot.data ?? [];
          return ListView.builder(
            itemCount: ingredients.length,
            itemBuilder: (context, index) {
              final ingredient = ingredients[index];
              return ListTile(
                title: Text(ingredient.name),
                subtitle: Text(
                  '${ingredient.purchaseUnit} = ${ingredient.conversionFactor}${ingredient.baseUnit}',
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, dao),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, IngredientDao dao) async {
    final nameController = TextEditingController();
    final purchaseUnitController = TextEditingController();
    final conversionFactorController = TextEditingController();
    BaseUnit selectedBaseUnit = BaseUnit.g;
    bool isExpiryTracked = true;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('품목 등록'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '품목명'),
              ),
              DropdownButton<BaseUnit>(
                value: selectedBaseUnit,
                items: BaseUnit.values
                    .map(
                      (unit) => DropdownMenuItem(
                        value: unit,
                        child: Text(unit.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => selectedBaseUnit = value!),
              ),
              TextField(
                controller: purchaseUnitController,
                decoration:
                    const InputDecoration(labelText: '구매 단위 (예: 박스)'),
              ),
              TextField(
                controller: conversionFactorController,
                decoration: const InputDecoration(
                  labelText: '구매단위 1개 = base unit 몇 개',
                ),
                keyboardType: TextInputType.number,
              ),
              CheckboxListTile(
                title: const Text('유통기한 관리'),
                value: isExpiryTracked,
                onChanged: (value) =>
                    setState(() => isExpiryTracked = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final factor =
                    double.tryParse(conversionFactorController.text);
                if (nameController.text.trim().isEmpty ||
                    purchaseUnitController.text.trim().isEmpty ||
                    factor == null) {
                  return;
                }
                await dao.insertIngredient(
                  IngredientsCompanion.insert(
                    name: nameController.text.trim(),
                    baseUnit: selectedBaseUnit.toDbString(),
                    purchaseUnit: purchaseUnitController.text.trim(),
                    conversionFactor: factor,
                    isExpiryTracked: isExpiryTracked,
                  ),
                );
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 정적 분석 확인**

Run: `flutter analyze lib/features/ingredient_management`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/ingredient_management
git commit -m "feat: add ingredient management screen"
```

---

### Task 11: 입고 등록 화면

**Files:**
- Create: `lib/features/inbound/inbound_form_screen.dart`
- Test: `test/features/inbound/inbound_form_screen_test.dart`

- [ ] **Step 1: 실패하는 위젯 테스트 작성**

`test/features/inbound/inbound_form_screen_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/features/inbound/inbound_form_screen.dart';

void main() {
  testWidgets('shows validation errors when required fields are empty',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: InboundFormScreen()),
      ),
    );

    await tester.tap(find.text('저장'));
    await tester.pump();

    expect(find.text('수량을 입력하세요'), findsOneWidget);
    expect(find.text('단가를 입력하세요'), findsOneWidget);

    // Drift의 watch() 스트림이 구독 취소 시 예약하는 정리용 타이머(0초 지연)가
    // 테스트 종료 시점까지 남아있지 않도록, 위젯을 교체해 dispose를 유도한 뒤
    // duration을 준 pump()로 가짜 시계를 흘려보내 그 타이머를 실행시킨다.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/features/inbound/inbound_form_screen_test.dart`
Expected: FAIL — `lib/features/inbound/inbound_form_screen.dart` 파일이 없어 컴파일 에러

- [ ] **Step 3: 화면 구현**

`lib/features/inbound/inbound_form_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/dao_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../data/local/database.dart';
import '../../domain/unit_conversion.dart';
import '../ingredient_management/ingredient_list_screen.dart';
import '../supplier_management/supplier_list_screen.dart';

class InboundFormScreen extends ConsumerStatefulWidget {
  const InboundFormScreen({super.key});

  @override
  ConsumerState<InboundFormScreen> createState() => _InboundFormScreenState();
}

class _InboundFormScreenState extends ConsumerState<InboundFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _purchaseQtyController = TextEditingController();
  final _unitCostController = TextEditingController();

  Supplier? _selectedSupplier;
  Ingredient? _selectedIngredient;
  DateTime? _expiryDate;

  @override
  void dispose() {
    _purchaseQtyController.dispose();
    _unitCostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supplierDao = ref.watch(supplierDaoProvider);
    final ingredientDao = ref.watch(ingredientDaoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('입고 등록')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StreamBuilder<List<Supplier>>(
              stream: supplierDao.watchAll(),
              builder: (context, snapshot) {
                final suppliers = snapshot.data ?? [];
                return DropdownButtonFormField<Supplier>(
                  key: const Key('supplierDropdown'),
                  initialValue: _selectedSupplier,
                  decoration: const InputDecoration(labelText: '거래처'),
                  items: suppliers
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedSupplier = value),
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SupplierListScreen()),
              ),
              child: const Text('+ 신규 거래처 등록'),
            ),
            StreamBuilder<List<Ingredient>>(
              stream: ingredientDao.watchAll(),
              builder: (context, snapshot) {
                final ingredients = snapshot.data ?? [];
                return DropdownButtonFormField<Ingredient>(
                  key: const Key('ingredientDropdown'),
                  initialValue: _selectedIngredient,
                  decoration: const InputDecoration(labelText: '품목'),
                  items: ingredients
                      .map(
                        (i) => DropdownMenuItem(value: i, child: Text(i.name)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedIngredient = value),
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const IngredientListScreen(),
                ),
              ),
              child: const Text('+ 신규 품목 등록'),
            ),
            TextFormField(
              key: const Key('purchaseQtyField'),
              controller: _purchaseQtyController,
              decoration: InputDecoration(
                labelText: _selectedIngredient == null
                    ? '수량'
                    : '수량 (${_selectedIngredient!.purchaseUnit})',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return '수량을 입력하세요';
                if (double.tryParse(value) == null) return '숫자를 입력하세요';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            if (_selectedIngredient != null &&
                double.tryParse(_purchaseQtyController.text) != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '= ${purchaseQtyToBaseQty(double.parse(_purchaseQtyController.text), _selectedIngredient!.conversionFactor)}'
                  ' ${_selectedIngredient!.baseUnit}',
                ),
              ),
            TextFormField(
              key: const Key('unitCostField'),
              controller: _unitCostController,
              decoration: const InputDecoration(labelText: '단가'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return '단가를 입력하세요';
                if (double.tryParse(value) == null) return '숫자를 입력하세요';
                return null;
              },
            ),
            if (_selectedIngredient?.isExpiryTracked ?? false)
              Row(
                children: [
                  Text(
                    _expiryDate == null
                        ? '유통기한 미선택'
                        : '유통기한: ${_expiryDate!.toIso8601String().substring(0, 10)}',
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) setState(() => _expiryDate = picked);
                    },
                    child: const Text('날짜 선택'),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _save,
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedIngredient == null) return;

    final ingredient = _selectedIngredient!;
    final purchaseQty = double.parse(_purchaseQtyController.text);
    final unitCost = double.parse(_unitCostController.text);
    final baseQty = purchaseQtyToBaseQty(purchaseQty, ingredient.conversionFactor);

    final repository = ref.read(lotRepositoryProvider);
    await repository.receiveLot(
      ingredientId: ingredient.id,
      supplierId: _selectedSupplier?.id,
      receivedDate: DateTime.now(),
      expiryDate: _expiryDate,
      unitCost: unitCost,
      baseQty: baseQty,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('입고 등록 완료')),
      );
      _formKey.currentState!.reset();
      _purchaseQtyController.clear();
      _unitCostController.clear();
      setState(() {
        _selectedSupplier = null;
        _selectedIngredient = null;
        _expiryDate = null;
      });
    }
  }
}
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/features/inbound/inbound_form_screen_test.dart`
Expected: PASS (1 test passed)

- [ ] **Step 5: Commit**

```bash
git add lib/features/inbound test/features/inbound
git commit -m "feat: add inbound registration screen"
```

---

### Task 12: main.dart 연결 + 기존 카운터 스캐폴딩 제거

**Files:**
- Modify: `lib/main.dart`
- Delete: `test/widget_test.dart` (기본 카운터 앱을 테스트하던 파일 — 화면이 전부 교체되어 더 이상 유효하지 않음)

- [ ] **Step 1: 기존 카운터 스모크 테스트 삭제**

Run: `rm test/widget_test.dart`

- [ ] **Step 2: main.dart를 홈 화면 + 라우팅으로 교체**

`lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/ingredient_management/ingredient_list_screen.dart';
import 'features/inbound/inbound_form_screen.dart';
import 'features/supplier_management/supplier_list_screen.dart';

void main() {
  runApp(const ProviderScope(child: StockControlApp()));
}

class StockControlApp extends StatelessWidget {
  const StockControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '재고관리',
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('재고관리')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SupplierListScreen()),
              ),
              child: const Text('거래처 관리'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const IngredientListScreen(),
                ),
              ),
              child: const Text('품목 관리'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InboundFormScreen()),
              ),
              child: const Text('입고 등록'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 전체 테스트 스위트 실행**

Run: `flutter test`
Expected: PASS — 지금까지 작성한 모든 테스트(도메인 3개, DAO 4개, 리포지토리 2개, 위젯 1개)가 통과

- [ ] **Step 4: Windows 데스크톱에서 수동 확인 (Visual Studio 설치 후 진행)**

`flutter doctor`에서 `Visual Studio - develop Windows apps`가 X로 나옴(C++ 워크로드 미설치) — `flutter run -d windows`가 이 상태로는 빌드되지 않는다. 임시로 `flutter run -d chrome`으로 확인을 시도했으나, `driftDatabase()`가 웹 컴파일 시 별도의 `web:` 파라미터(WASM sqlite3 + 워커 설정)를 요구하는 걸 발견했다 — `Invalid argument(s): When compiling to the web, the 'web' parameter needs to be set.` 웹은 애초에 지원 대상이 아니므로 이 설정은 추가하지 않기로 함. Visual Studio 설치는 사용자가 편할 때 진행하기로 하고, 그 전까지 이 단계는 보류.

Visual Studio(Desktop development with C++) 설치 후:

Run: `flutter run -d windows`

확인 사항:
1. 홈 화면에 "거래처 관리", "품목 관리", "입고 등록" 버튼 3개가 보이는가
2. "거래처 관리" → 우측 하단 + 버튼으로 거래처 하나 등록 후 목록에 표시되는가
3. "품목 관리" → 품목 하나(예: 양파, baseUnit=g, purchaseUnit=박스, conversionFactor=20000, isExpiryTracked=false) 등록 후 목록에 표시되는가
4. "입고 등록" → 방금 만든 거래처/품목 선택, 수량 2 입력 시 "= 40000 g" 환산값이 보이는가, 단가 입력 후 저장 시 스낵바로 "입고 등록 완료"가 뜨는가
5. 앱을 종료 후 재실행했을 때 등록한 거래처/품목이 남아있는가 (로컬 DB 영속성 확인)

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat: wire up home screen navigation and remove counter scaffold"
```

---

## Self-Review 결과

**스펙 커버리지**: 도메인 모델(Ingredient/Supplier/Lot/StockMovement는 Drift 코드젠 클래스로 대체, enum 2종은 별도 파일) — Task 2,3,5,6 / 로컬 DB 스키마 — Task 5,6 / 초기재고(Lot 없는 예외) 처리 — Task 7 / 입고 등록 화면 — Task 9,10,11 / 파일 구조 — 전체 태스크에 반영 / 테스트 전략(인메모리 DB, 위젯 검증 최소화) — Task 6,7,11 / 범위 밖 항목(재고조회, 폐기/조정, 실사, 반응형, 서버, 알림, 엑셀업로드) — 이번 계획에 포함하지 않음, 스펙과 일치.

**타입 일관성 확인**: `LotRepository.receiveLot`의 파라미터명(`ingredientId`, `supplierId`, `receivedDate`, `expiryDate`, `unitCost`, `baseQty`, `type`, `memo`)이 Task 7 테스트와 Task 11 화면의 호출부에서 동일하게 사용됨. DAO 메서드명(`insertSupplier`, `insertIngredient`, `insertLot`, `getById`, `updateRemainingQty`, `insertMovement`, `movementsForLot`, `watchAll`)이 정의된 Task 6과 사용되는 Task 9/10/11/Self-Review 전체에서 일치함.
