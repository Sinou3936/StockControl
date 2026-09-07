# 재고 조회 화면 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 품목별로 그룹화된 재고 현황을 로트 단위로 조회하는 화면을 추가하고, 유통기한이 임박(3일 이내)한 로트를 강조 표시한다.

**Architecture:** 순수 도메인 로직(`isNearExpiry`, `groupLotsByIngredient`)을 DB와 분리해서 DB 없이 테스트한다. `LotDao`에 `Lots`↔`Ingredients` 조인 쿼리 메서드 하나를 추가하고, 화면은 그 스트림을 구독해 도메인 함수로 가공한 뒤 그린다. 새 Riverpod provider는 필요 없다 — 기존 `lotDaoProvider`를 그대로 쓴다.

**Tech Stack:** Flutter, Drift, Riverpod (기존 스택 그대로, 신규 의존성 없음)

---

## 코드젠 관련 참고사항

Task 3(`LotDao`에 메서드 추가)은 `@DriftAccessor` 어노테이션이나 테이블 목록을 바꾸지 않는다 — 이미 생성되어 있는 `_$LotDaoMixin`에 손을 안 대고, 그냥 평범한 Dart 메서드 하나를 클래스 본문에 추가하는 것이다. 그래서 이번엔 `build_runner`를 다시 돌릴 필요가 없고, 다른 순수 로직 태스크와 마찬가지로 엄격한 TDD(RED→GREEN)를 그대로 적용한다.

---

### Task 1: 도메인 로직 — isNearExpiry

**Files:**
- Create: `lib/domain/stock_overview.dart`
- Test: `test/domain/stock_overview_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/domain/stock_overview_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/domain/stock_overview.dart';

void main() {
  group('isNearExpiry', () {
    final now = DateTime(2026, 9, 7);

    test('returns false when expiryDate is null', () {
      expect(isNearExpiry(null, now: now), isFalse);
    });

    test('returns true when expiry date is already past', () {
      expect(isNearExpiry(DateTime(2026, 9, 5), now: now), isTrue);
    });

    test('returns true when expiry date is today', () {
      expect(isNearExpiry(DateTime(2026, 9, 7), now: now), isTrue);
    });

    test('returns true when exactly at the threshold (3 days from now)', () {
      expect(isNearExpiry(DateTime(2026, 9, 10), now: now), isTrue);
    });

    test('returns false when beyond the threshold', () {
      expect(isNearExpiry(DateTime(2026, 9, 11), now: now), isFalse);
    });

    test('supports a custom threshold', () {
      expect(
        isNearExpiry(DateTime(2026, 9, 14), now: now, thresholdDays: 7),
        isTrue,
      );
    });
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/domain/stock_overview_test.dart`
Expected: FAIL — `lib/domain/stock_overview.dart` 파일이 없어 컴파일 에러

- [ ] **Step 3: 최소 구현 작성**

`lib/domain/stock_overview.dart`:
```dart
bool isNearExpiry(
  DateTime? expiryDate, {
  required DateTime now,
  int thresholdDays = 3,
}) {
  if (expiryDate == null) return false;
  return !expiryDate.isAfter(now.add(Duration(days: thresholdDays)));
}
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/domain/stock_overview_test.dart`
Expected: PASS (6 tests passed)

- [ ] **Step 5: Commit**

```bash
git add lib/domain/stock_overview.dart test/domain/stock_overview_test.dart
git commit -m "feat: add isNearExpiry domain logic"
```

---

### Task 2: 도메인 로직 — 품목별 그룹화

**Files:**
- Modify: `lib/domain/stock_overview.dart`
- Modify: `test/domain/stock_overview_test.dart`

- [ ] **Step 1: 실패하는 테스트 추가**

`test/domain/stock_overview_test.dart`의 `import` 아래, 기존 `isNearExpiry` group 뒤에 이어서 추가:

```dart
import 'package:stockcontrol/data/local/database.dart';
```

(파일 맨 위 import 목록에 위 줄을 추가한다)

```dart
Ingredient _makeIngredient(int id, String name) => Ingredient(
      id: id,
      name: name,
      baseUnit: 'g',
      purchaseUnit: '박스',
      conversionFactor: 20000,
      isExpiryTracked: true,
      createdAt: DateTime(2026, 9, 7),
    );

Lot _makeLot(
  int id,
  int ingredientId, {
  DateTime? expiryDate,
  double remainingQty = 1000,
}) =>
    Lot(
      id: id,
      ingredientId: ingredientId,
      receivedDate: DateTime(2026, 9, 7),
      expiryDate: expiryDate,
      unitCost: 10,
      remainingQty: remainingQty,
      createdAt: DateTime(2026, 9, 7),
    );

void _groupLotsByIngredientTests() {
  final now = DateTime(2026, 9, 7);

  group('groupLotsByIngredient', () {
    test('groups rows by ingredient and sums remainingQty', () {
      final onion = _makeIngredient(1, '양파');
      final rows = [
        LotWithIngredient(
          lot: _makeLot(1, 1, remainingQty: 5000),
          ingredient: onion,
        ),
        LotWithIngredient(
          lot: _makeLot(2, 1, remainingQty: 3000),
          ingredient: onion,
        ),
      ];

      final groups = groupLotsByIngredient(rows, now: now);

      expect(groups, hasLength(1));
      expect(groups.first.ingredient.name, '양파');
      expect(groups.first.lots, hasLength(2));
      expect(groups.first.totalRemainingQty, 8000);
    });

    test('sorts groups with a near-expiry lot before ones without', () {
      final onion = _makeIngredient(1, '양파');
      final carrot = _makeIngredient(2, '당근');
      final rows = [
        LotWithIngredient(
          lot: _makeLot(1, 1, expiryDate: now.add(const Duration(days: 30))),
          ingredient: onion,
        ),
        LotWithIngredient(
          lot: _makeLot(2, 2, expiryDate: now.add(const Duration(days: 1))),
          ingredient: carrot,
        ),
      ];

      final groups = groupLotsByIngredient(rows, now: now);

      expect(groups.first.ingredient.name, '당근');
      expect(groups.first.hasNearExpiryLot, isTrue);
      expect(groups.last.ingredient.name, '양파');
      expect(groups.last.hasNearExpiryLot, isFalse);
    });

    test('sorts groups alphabetically when urgency is equal', () {
      final onion = _makeIngredient(1, '양파');
      final carrot = _makeIngredient(2, '당근');
      final rows = [
        LotWithIngredient(lot: _makeLot(1, 1), ingredient: onion),
        LotWithIngredient(lot: _makeLot(2, 2), ingredient: carrot),
      ];

      final groups = groupLotsByIngredient(rows, now: now);

      expect(groups.map((g) => g.ingredient.name), ['당근', '양파']);
    });
  });
}
```

`main()` 함수 안, 기존 `group('isNearExpiry', ...)` 호출 다음 줄에 `_groupLotsByIngredientTests();` 호출을 추가한다.

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/domain/stock_overview_test.dart`
Expected: FAIL — `LotWithIngredient`, `IngredientStockGroup`, `groupLotsByIngredient`가 정의되어 있지 않아 컴파일 에러

- [ ] **Step 3: 최소 구현 작성**

`lib/domain/stock_overview.dart`에 이어서 추가 (파일 맨 위에 import 추가 필요):

```dart
import 'package:stockcontrol/data/local/database.dart';
```

```dart
class LotWithIngredient {
  LotWithIngredient({required this.lot, required this.ingredient});

  final Lot lot;
  final Ingredient ingredient;
}

class IngredientStockGroup {
  IngredientStockGroup({
    required this.ingredient,
    required this.lots,
    required this.hasNearExpiryLot,
  });

  final Ingredient ingredient;
  final List<Lot> lots;
  final bool hasNearExpiryLot;

  double get totalRemainingQty =>
      lots.fold(0.0, (sum, lot) => sum + lot.remainingQty);
}

List<IngredientStockGroup> groupLotsByIngredient(
  List<LotWithIngredient> rows, {
  required DateTime now,
}) {
  final byIngredient = <int, List<LotWithIngredient>>{};
  for (final row in rows) {
    byIngredient.putIfAbsent(row.ingredient.id, () => []).add(row);
  }

  final groups = byIngredient.values.map((groupRows) {
    final lots = groupRows.map((r) => r.lot).toList();
    return IngredientStockGroup(
      ingredient: groupRows.first.ingredient,
      lots: lots,
      hasNearExpiryLot:
          lots.any((lot) => isNearExpiry(lot.expiryDate, now: now)),
    );
  }).toList();

  groups.sort((a, b) {
    if (a.hasNearExpiryLot != b.hasNearExpiryLot) {
      return a.hasNearExpiryLot ? -1 : 1;
    }
    return a.ingredient.name.compareTo(b.ingredient.name);
  });

  return groups;
}
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/domain/stock_overview_test.dart`
Expected: PASS (9 tests passed)

- [ ] **Step 5: Commit**

```bash
git add lib/domain/stock_overview.dart test/domain/stock_overview_test.dart
git commit -m "feat: add ingredient-grouped stock overview domain logic"
```

---

### Task 3: LotDao — 조인 쿼리 추가

**Files:**
- Modify: `lib/data/local/daos/lot_dao.dart`
- Modify: `test/data/local/lot_dao_test.dart`

- [ ] **Step 1: 실패하는 테스트 추가**

`test/data/local/lot_dao_test.dart` 맨 위 import에 추가:

```dart
import 'package:stockcontrol/domain/stock_overview.dart';
```

기존 `test('inserts a lot and updates its remainingQty', ...)` 다음에 이어서 추가:

```dart
  test(
      'watchAvailableLotsWithIngredient excludes zero-quantity lots and '
      'sorts by expiry', () async {
    await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 1),
        unitCost: 15.0,
        remainingQty: 0,
      ),
    );
    final soonLotId = await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 3),
        expiryDate: Value(DateTime(2026, 9, 8)),
        unitCost: 15.0,
        remainingQty: 5000,
      ),
    );
    final laterLotId = await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 5),
        expiryDate: Value(DateTime(2026, 10, 1)),
        unitCost: 15.0,
        remainingQty: 3000,
      ),
    );

    final rows = await db.lotDao.watchAvailableLotsWithIngredient().first;

    expect(rows, hasLength(2));
    expect(rows[0].lot.id, soonLotId);
    expect(rows[1].lot.id, laterLotId);
    expect(rows[0].ingredient.name, '양파');
  });
```

파일 맨 위 import에 `package:drift/drift.dart`도 필요하다 (`Value` 사용):

```dart
import 'package:drift/drift.dart';
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/data/local/lot_dao_test.dart`
Expected: FAIL — `watchAvailableLotsWithIngredient` 메서드가 없어 컴파일 에러

- [ ] **Step 3: 최소 구현 작성**

`lib/data/local/daos/lot_dao.dart` 맨 위 import에 추가:

```dart
import '../../../domain/stock_overview.dart';
import '../tables/ingredients_table.dart';
```

`LotDao` 클래스 안에 메서드 추가:

```dart
  Stream<List<LotWithIngredient>> watchAvailableLotsWithIngredient() {
    final query = select(lots).join([
      innerJoin(ingredients, ingredients.id.equalsExp(lots.ingredientId)),
    ])
      ..where(lots.remainingQty.isBiggerThanValue(0))
      ..orderBy([OrderingTerm.asc(lots.expiryDate)]);

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => LotWithIngredient(
                  lot: row.readTable(lots),
                  ingredient: row.readTable(ingredients),
                ),
              )
              .toList(),
        );
  }
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/data/local/lot_dao_test.dart`
Expected: PASS (2 tests passed)

- [ ] **Step 5: Commit**

```bash
git add lib/data/local/daos/lot_dao.dart test/data/local/lot_dao_test.dart
git commit -m "feat: add LotDao.watchAvailableLotsWithIngredient join query"
```

---

### Task 4: 재고 조회 화면

**Files:**
- Create: `lib/features/stock_overview/stock_overview_screen.dart`
- Test: `test/features/stock_overview/stock_overview_screen_test.dart`

- [ ] **Step 1: 실패하는 위젯 테스트 작성**

`test/features/stock_overview/stock_overview_screen_test.dart`:
```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/features/stock_overview/stock_overview_screen.dart';

void main() {
  testWidgets('shows ingredient groups and flags near-expiry lots',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final ingredientId = await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: true,
      ),
    );
    await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime.now(),
        expiryDate: Value(DateTime.now().add(const Duration(days: 1))),
        unitCost: 10,
        remainingQty: 5000,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: StockOverviewScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('양파'), findsWidgets);
    expect(find.text('임박'), findsOneWidget);

    // Drift watch() 스트림의 구독 취소 시 예약되는 정리용 타이머(0초 지연)를
    // 테스트 종료 전에 흘려보낸다 (inbound_form_screen_test.dart와 동일 패턴).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/features/stock_overview/stock_overview_screen_test.dart`
Expected: FAIL — `lib/features/stock_overview/stock_overview_screen.dart` 파일이 없어 컴파일 에러

- [ ] **Step 3: 화면 구현**

`lib/features/stock_overview/stock_overview_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/dao_providers.dart';
import '../../data/local/database.dart';
import '../../domain/stock_overview.dart';

class StockOverviewScreen extends ConsumerWidget {
  const StockOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.watch(lotDaoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('재고 조회')),
      body: StreamBuilder<List<LotWithIngredient>>(
        stream: dao.watchAvailableLotsWithIngredient(),
        builder: (context, snapshot) {
          final groups = groupLotsByIngredient(
            snapshot.data ?? [],
            now: DateTime.now(),
          );

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) =>
                _IngredientGroupSection(group: groups[index]),
          );
        },
      ),
    );
  }
}

class _IngredientGroupSection extends StatelessWidget {
  const _IngredientGroupSection({required this.group});

  final IngredientStockGroup group;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '${group.ingredient.name} · 총 ${group.totalRemainingQty}'
            '${group.ingredient.baseUnit}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final lot in group.lots)
          _LotRow(lot: lot, now: DateTime.now()),
      ],
    );
  }
}

class _LotRow extends StatelessWidget {
  const _LotRow({required this.lot, required this.now});

  final Lot lot;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final near = isNearExpiry(lot.expiryDate, now: now);
    final expiryText = lot.expiryDate == null
        ? '유통기한 관리 안 함'
        : '유통기한 ${lot.expiryDate!.toIso8601String().substring(0, 10)}';

    return Container(
      color: near ? Colors.red.shade50 : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(expiryText)),
          if (near)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text(
                '임박',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          Text('${lot.remainingQty}'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/features/stock_overview/stock_overview_screen_test.dart`
Expected: PASS (1 test passed)

- [ ] **Step 5: Commit**

```bash
git add lib/features/stock_overview test/features/stock_overview
git commit -m "feat: add stock overview screen"
```

---

### Task 5: 홈 화면에 연결

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: import와 버튼 추가**

`lib/main.dart` 맨 위 import에 추가:

```dart
import 'features/stock_overview/stock_overview_screen.dart';
```

`HomeScreen`의 `Column` `children` 목록, "입고 등록" 버튼 다음에 이어서 추가:

```dart
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StockOverviewScreen(),
                ),
              ),
              child: const Text('재고 조회'),
            ),
```

- [ ] **Step 2: 정적 분석 확인**

Run: `flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 3: 전체 테스트 스위트 실행**

Run: `flutter test`
Expected: PASS — 이번 스펙에서 추가한 테스트(도메인 9개, DAO 1개 추가, 위젯 1개)를 포함해 전부 통과

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: add stock overview navigation to home screen"
```

---

## Self-Review 결과

**스펙 커버리지**: 품목별 그룹화 — Task 2 / 유통기한 3일 임박 기준 — Task 1 / "임박" 배지(D-day 카운트다운 대신 단순화) — Task 4 / remainingQty>0 필터링 + 유통기한순 정렬 — Task 3 / 그룹 자체 정렬(임박 우선, 그다음 이름순) — Task 2 / ConsumerWidget(상태 없음) — Task 4 / 홈 화면 연결 — Task 5 / 범위 밖 항목(폐기·조정, 마감 실사, 검색/필터, 반응형) — 이번 계획에 포함하지 않음, 스펙과 일치.

**타입 일관성 확인**: `LotWithIngredient`(lot, ingredient 필드), `IngredientStockGroup`(ingredient, lots, hasNearExpiryLot 필드 + totalRemainingQty 게터), `groupLotsByIngredient(rows, {required now})`, `isNearExpiry(expiryDate, {required now, thresholdDays = 3})`, `LotDao.watchAvailableLotsWithIngredient()` — Task 1·2에서 정의된 시그니처가 Task 3(DAO)·Task 4(화면)에서 동일하게 사용됨. `lotDaoProvider`는 기존 Task 8(`lib/core/providers/dao_providers.dart`)에서 이미 정의된 것을 그대로 재사용.
