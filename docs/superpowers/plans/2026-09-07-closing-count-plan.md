# 마감 실사 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 품목별 실사 수량을 한 화면에서 입력받아 이론재고와 비교하고, 차이가 있는 품목을 확인 다이얼로그로 보여준 뒤 확정하면 로트별로 반영한다.

**Architecture:** 로트별 차이 배분(FIFO 부족분 차감 / 최근 로트 초과분 가산)을 DB와 분리된 순수 함수로 만들어 테스트한다. `LotRepository`에 기존 `recordQuantityChange`(5단계)를 재사용하는 트랜잭션 메서드를 추가해 여러 로트에 걸친 조정을 한 번에 원자적으로 반영한다.

**Tech Stack:** Flutter, Drift, Riverpod (기존 스택 그대로, 신규 의존성 없음)

---

### Task 1: 도메인 로직 — 차이 배분

**Files:**
- Create: `lib/domain/stock_count.dart`
- Test: `test/domain/stock_count_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/domain/stock_count_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/domain/stock_count.dart';

Ingredient _makeIngredient(int id, String name) => Ingredient(
      id: id,
      name: name,
      baseUnit: 'g',
      purchaseUnit: '박스',
      conversionFactor: 20000,
      isExpiryTracked: false,
      createdAt: DateTime(2026, 9, 7),
    );

Lot _makeLot(
  int id, {
  required DateTime receivedDate,
  double remainingQty = 1000,
}) =>
    Lot(
      id: id,
      ingredientId: 1,
      receivedDate: receivedDate,
      unitCost: 10,
      remainingQty: remainingQty,
      createdAt: receivedDate,
    );

void main() {
  group('distributeCountDifference', () {
    test('returns an empty list when there is no difference', () {
      final lots = [_makeLot(1, receivedDate: DateTime(2026, 9, 1))];
      expect(distributeCountDifference(lots, 0), isEmpty);
    });

    test('takes a shortfall entirely from a single lot when it covers it',
        () {
      final lots = [
        _makeLot(1, receivedDate: DateTime(2026, 9, 1), remainingQty: 1000),
      ];

      final adjustments = distributeCountDifference(lots, -300);

      expect(adjustments, hasLength(1));
      expect(adjustments.first.lotId, 1);
      expect(adjustments.first.change, -300);
    });

    test('spreads a shortfall across lots oldest-received first', () {
      final lots = [
        _makeLot(2, receivedDate: DateTime(2026, 9, 5), remainingQty: 1000),
        _makeLot(1, receivedDate: DateTime(2026, 9, 1), remainingQty: 500),
      ];

      final adjustments = distributeCountDifference(lots, -700);

      expect(adjustments, hasLength(2));
      expect(adjustments[0].lotId, 1);
      expect(adjustments[0].change, -500);
      expect(adjustments[1].lotId, 2);
      expect(adjustments[1].change, -200);
    });

    test('adds a surplus entirely to the most recently received lot', () {
      final lots = [
        _makeLot(1, receivedDate: DateTime(2026, 9, 1), remainingQty: 500),
        _makeLot(2, receivedDate: DateTime(2026, 9, 5), remainingQty: 500),
      ];

      final adjustments = distributeCountDifference(lots, 200);

      expect(adjustments, hasLength(1));
      expect(adjustments.first.lotId, 2);
      expect(adjustments.first.change, 200);
    });
  });

  group('CountDifference', () {
    test('computes difference as actual minus theoretical', () {
      final diff = CountDifference(
        ingredient: _makeIngredient(1, '양파'),
        theoreticalQty: 1000,
        actualQty: 700,
      );

      expect(diff.difference, -300);
    });
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/domain/stock_count_test.dart`
Expected: FAIL — `lib/domain/stock_count.dart` 파일이 없어 컴파일 에러

- [ ] **Step 3: 최소 구현 작성**

`lib/domain/stock_count.dart`:
```dart
import 'package:stockcontrol/data/local/database.dart';

class LotQuantityAdjustment {
  LotQuantityAdjustment({required this.lotId, required this.change});

  final int lotId;
  final double change;
}

List<LotQuantityAdjustment> distributeCountDifference(
  List<Lot> lots,
  double difference,
) {
  if (difference == 0) return [];

  if (difference > 0) {
    final mostRecent = lots.reduce(
      (a, b) => a.receivedDate.isAfter(b.receivedDate) ? a : b,
    );
    return [LotQuantityAdjustment(lotId: mostRecent.id, change: difference)];
  }

  final sorted = [...lots]
    ..sort((a, b) => a.receivedDate.compareTo(b.receivedDate));
  var remaining = -difference;
  final adjustments = <LotQuantityAdjustment>[];
  for (final lot in sorted) {
    if (remaining <= 0) break;
    final take = remaining < lot.remainingQty ? remaining : lot.remainingQty;
    if (take > 0) {
      adjustments.add(LotQuantityAdjustment(lotId: lot.id, change: -take));
      remaining -= take;
    }
  }
  return adjustments;
}

class CountDifference {
  CountDifference({
    required this.ingredient,
    required this.theoreticalQty,
    required this.actualQty,
  });

  final Ingredient ingredient;
  final double theoreticalQty;
  final double actualQty;

  double get difference => actualQty - theoreticalQty;
}
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/domain/stock_count_test.dart`
Expected: PASS (5 tests passed)

- [ ] **Step 5: Commit**

```bash
git add lib/domain/stock_count.dart test/domain/stock_count_test.dart
git commit -m "feat: add stock count difference distribution logic"
```

---

### Task 2: LotRepository — submitCountCorrections

**Files:**
- Modify: `lib/data/repositories/lot_repository.dart`
- Modify: `test/data/repositories/lot_repository_test.dart`

- [ ] **Step 1: 실패하는 테스트 추가**

`test/data/repositories/lot_repository_test.dart` 맨 위 import에 추가:

```dart
import 'package:stockcontrol/domain/stock_count.dart';
```

파일의 `main()` 안, 기존 마지막 `test(...)` 다음에 이어서 추가 (닫는 `}` 앞):

```dart
  test(
      'submitCountCorrections applies adjustments across multiple lots '
      'atomically', () async {
    final oldLotId = await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 1),
        unitCost: 10.0,
        remainingQty: 500,
      ),
    );
    final newLotId = await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 5),
        unitCost: 10.0,
        remainingQty: 1000,
      ),
    );

    await repository.submitCountCorrections([
      LotQuantityAdjustment(lotId: oldLotId, change: -500),
      LotQuantityAdjustment(lotId: newLotId, change: -200),
    ]);

    final oldLot = await db.lotDao.getById(oldLotId);
    final newLot = await db.lotDao.getById(newLotId);
    final oldMovements = await db.stockMovementDao.movementsForLot(oldLotId);
    final newMovements = await db.stockMovementDao.movementsForLot(newLotId);

    expect(oldLot.remainingQty, 0);
    expect(newLot.remainingQty, 800);
    expect(oldMovements.first.type, 'countCorrection');
    expect(newMovements.first.type, 'countCorrection');
  });
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/data/repositories/lot_repository_test.dart`
Expected: FAIL — `submitCountCorrections` 메서드가 없어 컴파일 에러

- [ ] **Step 3: 최소 구현 작성**

`lib/data/repositories/lot_repository.dart` 맨 위 import에 추가:

```dart
import '../../domain/stock_count.dart';
```

`LotRepository` 클래스 안, `recordQuantityChange` 메서드 다음에 이어서 추가:

```dart
  Future<void> submitCountCorrections(
    List<LotQuantityAdjustment> adjustments,
  ) async {
    await _db.transaction(() async {
      for (final adjustment in adjustments) {
        await recordQuantityChange(
          lotId: adjustment.lotId,
          type: MovementType.countCorrection,
          quantity: adjustment.change,
          memo: '마감 실사 보정',
        );
      }
    });
  }
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/data/repositories/lot_repository_test.dart`
Expected: PASS (6 tests passed)

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/lot_repository.dart test/data/repositories/lot_repository_test.dart
git commit -m "feat: add LotRepository.submitCountCorrections"
```

---

### Task 3: 마감 실사 화면

**Files:**
- Create: `lib/features/count/count_screen.dart`
- Test: `test/features/count/count_screen_test.dart`

- [ ] **Step 1: 실패하는 위젯 테스트 작성**

`test/features/count/count_screen_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/features/count/count_screen.dart';

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
        receivedDate: DateTime(2026, 9, 1),
        unitCost: 10,
        remainingQty: 1000,
      ),
    );
  });

  tearDown(() => db.close());

  Widget wrap() => ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CountScreen()),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets(
      'shows a difference dialog and applies the correction on confirm',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(Key('countField_$ingredientId')),
      '700',
    );
    await tester.tap(find.text('실사 제출'));
    await tester.pumpAndSettle();

    expect(find.textContaining('차이 -300'), findsOneWidget);

    await tester.tap(find.text('확정'));
    await tester.pumpAndSettle();

    expect(find.byType(CountScreen), findsNothing);

    final lot = await db.lotDao.getById(lotId);
    expect(lot.remainingQty, 700);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('shows a message and makes no change when counts match',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(Key('countField_$ingredientId')),
      '1000',
    );
    await tester.tap(find.text('실사 제출'));
    await tester.pump();

    expect(find.text('차이가 있는 품목이 없습니다'), findsOneWidget);
    expect(find.byType(CountScreen), findsOneWidget);

    final lot = await db.lotDao.getById(lotId);
    expect(lot.remainingQty, 1000);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/features/count/count_screen_test.dart`
Expected: FAIL — `lib/features/count/count_screen.dart` 파일이 없어 컴파일 에러

- [ ] **Step 3: 화면 구현**

`lib/features/count/count_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/dao_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../domain/stock_count.dart';
import '../../domain/stock_overview.dart';

class CountScreen extends ConsumerStatefulWidget {
  const CountScreen({super.key});

  @override
  ConsumerState<CountScreen> createState() => _CountScreenState();
}

class _CountScreenState extends ConsumerState<CountScreen> {
  final Map<int, double> _enteredCounts = {};

  @override
  Widget build(BuildContext context) {
    final dao = ref.watch(lotDaoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('마감 실사')),
      body: StreamBuilder<List<LotWithIngredient>>(
        stream: dao.watchAvailableLotsWithIngredient(),
        builder: (context, snapshot) {
          final groups = groupLotsByIngredient(
            snapshot.data ?? [],
            now: DateTime.now(),
          );

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return ListTile(
                      title: Text(group.ingredient.name),
                      subtitle: Text(
                        '이론재고 ${group.totalRemainingQty}'
                        '${group.ingredient.baseUnit}',
                      ),
                      trailing: SizedBox(
                        width: 100,
                        child: TextFormField(
                          key: Key('countField_${group.ingredient.id}'),
                          decoration:
                              const InputDecoration(labelText: '실사 수량'),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            final parsed = double.tryParse(value);
                            if (parsed == null) {
                              _enteredCounts.remove(group.ingredient.id);
                            } else {
                              _enteredCounts[group.ingredient.id] = parsed;
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () => _submit(groups),
                  child: const Text('실사 제출'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submit(List<IngredientStockGroup> groups) async {
    final differences = <CountDifference>[];
    for (final group in groups) {
      final actual = _enteredCounts[group.ingredient.id];
      if (actual == null) continue;
      final diff = CountDifference(
        ingredient: group.ingredient,
        theoreticalQty: group.totalRemainingQty,
        actualQty: actual,
      );
      if (diff.difference != 0) differences.add(diff);
    }

    if (differences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('차이가 있는 품목이 없습니다')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('실사 차이 확인'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final diff in differences)
                Text(
                  '${diff.ingredient.name}: 이론 ${diff.theoreticalQty}'
                  '${diff.ingredient.baseUnit} / 실사 ${diff.actualQty}'
                  '${diff.ingredient.baseUnit} / 차이 ${diff.difference}'
                  '${diff.ingredient.baseUnit}',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('확정'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final adjustments = <LotQuantityAdjustment>[];
    for (final diff in differences) {
      final group = groups.firstWhere(
        (g) => g.ingredient.id == diff.ingredient.id,
      );
      adjustments.addAll(
        distributeCountDifference(group.lots, diff.difference),
      );
    }

    await ref.read(lotRepositoryProvider).submitCountCorrections(adjustments);

    if (mounted) Navigator.of(context).pop();
  }
}
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/features/count/count_screen_test.dart`
Expected: PASS (2 tests passed)

- [ ] **Step 5: Commit**

```bash
git add lib/features/count test/features/count
git commit -m "feat: add closing count screen"
```

---

### Task 4: 홈 화면에 연결

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: import와 버튼 추가**

`lib/main.dart` 맨 위 import에 추가:

```dart
import 'features/count/count_screen.dart';
```

`HomeScreen`의 `Column` `children` 목록, "재고 조회" 버튼 다음에 이어서 추가:

```dart
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CountScreen()),
              ),
              child: const Text('마감 실사'),
            ),
```

- [ ] **Step 2: 정적 분석 확인**

Run: `flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 3: 전체 테스트 스위트 실행**

Run: `flutter test`
Expected: PASS — 이번 스펙에서 추가한 테스트(도메인 5개, 리포지토리 1개 추가, 화면 위젯 2개)를 포함해 전부 통과

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: add closing count navigation to home screen"
```

---

## Self-Review 결과

**스펙 커버리지**: 품목 단위 실사 입력 — Task 3 / 로트 0개 품목 제외(재고 조회와 같은 데이터 소스 재사용) — Task 3 / 부족분 FIFO 배분 — Task 1 / 초과분 최근 로트 가산 — Task 1 / 입력 안 한 품목 제외 — Task 3(`_enteredCounts`에 없으면 skip) / 차이 리포트 다이얼로그 → 확정 후 반영 — Task 3 / 원자성(여러 로트 한 번에) — Task 2 / 홈 화면 연결 — Task 4 / 범위 밖 항목(반응형, 서버 동기화, 안전재고 알림, 로트 0개 품목 실사) — 이번 계획에 포함하지 않음, 스펙과 일치.

**타입 일관성 확인**: `LotQuantityAdjustment(lotId, change)`, `CountDifference(ingredient, theoreticalQty, actualQty)` + `difference` 게터, `distributeCountDifference(lots, difference)` — Task 1에서 정의된 시그니처가 Task 2(`submitCountCorrections`가 `List<LotQuantityAdjustment>`를 받음)와 Task 3(화면에서 두 함수/클래스를 그대로 사용)에서 동일하게 사용됨. `LotRepository.submitCountCorrections(List<LotQuantityAdjustment>)`가 Task 3의 `_submit()` 호출부와 일치. 화면은 `IngredientStockGroup`/`LotWithIngredient`/`groupLotsByIngredient`(4단계에서 정의)를 재사용.
