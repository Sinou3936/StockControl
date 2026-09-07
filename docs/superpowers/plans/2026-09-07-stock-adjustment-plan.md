# 폐기/조정 등록 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 재고 조회 화면에서 로트를 탭해 진입하는 폐기/조정 등록 화면을 추가하고, 재고를 음수로 만드는 시도는 저장 자체를 막는다.

**Architecture:** 재고 초과 감소를 막는 검증(`applyQuantityChange`)을 DB와 분리된 순수 함수로 만들어 테스트한다. `LotRepository`에 기존 로트의 수량을 변경하는 트랜잭션 메서드를 추가하고, 화면은 그 메서드를 호출한 뒤 예외 여부에 따라 에러 표시 또는 이전 화면 복귀를 결정한다.

**Tech Stack:** Flutter, Drift, Riverpod (기존 스택 그대로, 신규 의존성 없음)

---

### Task 1: 도메인 로직 — applyQuantityChange

**Files:**
- Create: `lib/domain/stock_adjustment.dart`
- Test: `test/domain/stock_adjustment_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/domain/stock_adjustment_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/domain/stock_adjustment.dart';

void main() {
  group('applyQuantityChange', () {
    test('increases remainingQty when change is positive', () {
      expect(applyQuantityChange(1000, 500), 1500);
    });

    test('decreases remainingQty when change is negative', () {
      expect(applyQuantityChange(1000, -400), 600);
    });

    test('allows decreasing exactly to zero', () {
      expect(applyQuantityChange(1000, -1000), 0);
    });

    test('throws InsufficientStockException when change would go negative',
        () {
      expect(
        () => applyQuantityChange(1000, -1001),
        throwsA(
          isA<InsufficientStockException>()
              .having((e) => e.remainingQty, 'remainingQty', 1000)
              .having((e) => e.requestedQty, 'requestedQty', 1001),
        ),
      );
    });
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/domain/stock_adjustment_test.dart`
Expected: FAIL — `lib/domain/stock_adjustment.dart` 파일이 없어 컴파일 에러

- [ ] **Step 3: 최소 구현 작성**

`lib/domain/stock_adjustment.dart`:
```dart
class InsufficientStockException implements Exception {
  InsufficientStockException({
    required this.remainingQty,
    required this.requestedQty,
  });

  final double remainingQty;
  final double requestedQty;
}

double applyQuantityChange(double remainingQty, double change) {
  final newQty = remainingQty + change;
  if (newQty < 0) {
    throw InsufficientStockException(
      remainingQty: remainingQty,
      requestedQty: -change,
    );
  }
  return newQty;
}
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/domain/stock_adjustment_test.dart`
Expected: PASS (4 tests passed)

- [ ] **Step 5: Commit**

```bash
git add lib/domain/stock_adjustment.dart test/domain/stock_adjustment_test.dart
git commit -m "feat: add applyQuantityChange domain logic"
```

---

### Task 2: LotRepository — recordQuantityChange

**Files:**
- Modify: `lib/data/repositories/lot_repository.dart`
- Modify: `test/data/repositories/lot_repository_test.dart`

- [ ] **Step 1: 실패하는 테스트 추가**

`test/data/repositories/lot_repository_test.dart` 맨 위 import에 추가:

```dart
import 'package:stockcontrol/domain/stock_adjustment.dart';
```

파일의 `main()` 안, 기존 두 `test(...)` 다음에 이어서 추가 (닫는 `}` 앞):

```dart
  test('recordQuantityChange reduces remainingQty for a disposal', () async {
    final lotId = await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 7),
        unitCost: 10.0,
        remainingQty: 1000,
      ),
    );

    await repository.recordQuantityChange(
      lotId: lotId,
      type: MovementType.disposal,
      quantity: -300,
      memo: '유통기한 지남',
    );

    final lot = await db.lotDao.getById(lotId);
    final movements = await db.stockMovementDao.movementsForLot(lotId);

    expect(lot.remainingQty, 700);
    expect(movements, hasLength(1));
    expect(movements.first.type, 'disposal');
    expect(movements.first.quantity, -300);
    expect(movements.first.memo, '유통기한 지남');
  });

  test('recordQuantityChange increases remainingQty for an adjustment',
      () async {
    final lotId = await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 7),
        unitCost: 10.0,
        remainingQty: 1000,
      ),
    );

    await repository.recordQuantityChange(
      lotId: lotId,
      type: MovementType.adjustment,
      quantity: 200,
    );

    final lot = await db.lotDao.getById(lotId);
    expect(lot.remainingQty, 1200);
  });

  test(
      'recordQuantityChange throws and writes nothing when the change would '
      'go negative', () async {
    final lotId = await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 7),
        unitCost: 10.0,
        remainingQty: 100,
      ),
    );

    await expectLater(
      () => repository.recordQuantityChange(
        lotId: lotId,
        type: MovementType.disposal,
        quantity: -500,
      ),
      throwsA(isA<InsufficientStockException>()),
    );

    final lot = await db.lotDao.getById(lotId);
    final movements = await db.stockMovementDao.movementsForLot(lotId);

    expect(lot.remainingQty, 100);
    expect(movements, isEmpty);
  });
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/data/repositories/lot_repository_test.dart`
Expected: FAIL — `recordQuantityChange` 메서드가 없어 컴파일 에러

- [ ] **Step 3: 최소 구현 작성**

`lib/data/repositories/lot_repository.dart` 맨 위 import에 추가:

```dart
import '../../domain/stock_adjustment.dart';
```

`LotRepository` 클래스 안, `receiveLot` 메서드 다음에 이어서 추가:

```dart
  Future<void> recordQuantityChange({
    required int lotId,
    required MovementType type,
    required double quantity,
    DateTime? occurredAt,
    String? memo,
  }) async {
    await _db.transaction(() async {
      final lot = await _db.lotDao.getById(lotId);
      final newQty = applyQuantityChange(lot.remainingQty, quantity);

      await _db.lotDao.updateRemainingQty(lotId, newQty);
      await _db.stockMovementDao.insertMovement(
        StockMovementsCompanion.insert(
          lotId: lotId,
          type: type.toDbString(),
          quantity: quantity,
          occurredAt: occurredAt ?? DateTime.now(),
          memo: Value(memo),
        ),
      );
    });
  }
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/data/repositories/lot_repository_test.dart`
Expected: PASS (5 tests passed)

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/lot_repository.dart test/data/repositories/lot_repository_test.dart
git commit -m "feat: add LotRepository.recordQuantityChange"
```

---

### Task 3: 폐기/조정 등록 화면

**Files:**
- Create: `lib/features/stock_adjustment/stock_adjustment_form_screen.dart`
- Test: `test/features/stock_adjustment/stock_adjustment_form_screen_test.dart`

- [ ] **Step 1: 실패하는 위젯 테스트 작성**

`test/features/stock_adjustment/stock_adjustment_form_screen_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/features/stock_adjustment/stock_adjustment_form_screen.dart';

void main() {
  late AppDatabase db;
  late Ingredient ingredient;
  late Lot lot;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final ingredientId = await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
      ),
    );
    final lotId = await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        receivedDate: DateTime(2026, 9, 7),
        unitCost: 10,
        remainingQty: 100,
      ),
    );
    ingredient = (await db.ingredientDao.watchAll().first).first;
    lot = await db.lotDao.getById(lotId);
  });

  tearDown(() => db.close());

  Widget wrap(Widget child) => ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: child),
      );

  testWidgets('shows an error and stays when disposal exceeds remaining stock',
      (tester) async {
    await tester.pumpWidget(
      wrap(StockAdjustmentFormScreen(lot: lot, ingredient: ingredient)),
    );

    await tester.enterText(find.byKey(const Key('quantityField')), '500');
    await tester.tap(find.text('저장'));
    await tester.pump();

    expect(find.textContaining('남은 수량'), findsWidgets);
    expect(find.byType(StockAdjustmentFormScreen), findsOneWidget);
  });

  testWidgets('pops back to the previous screen after a valid disposal',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StockAdjustmentFormScreen(
                      lot: lot,
                      ingredient: ingredient,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('quantityField')), '30');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.byType(StockAdjustmentFormScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/features/stock_adjustment/stock_adjustment_form_screen_test.dart`
Expected: FAIL — `lib/features/stock_adjustment/stock_adjustment_form_screen.dart` 파일이 없어 컴파일 에러

- [ ] **Step 3: 화면 구현**

`lib/features/stock_adjustment/stock_adjustment_form_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../../data/local/database.dart';
import '../../domain/movement_type.dart';
import '../../domain/stock_adjustment.dart';

enum _AdjustmentDirection { increase, decrease }

class StockAdjustmentFormScreen extends ConsumerStatefulWidget {
  const StockAdjustmentFormScreen({
    super.key,
    required this.lot,
    required this.ingredient,
  });

  final Lot lot;
  final Ingredient ingredient;

  @override
  ConsumerState<StockAdjustmentFormScreen> createState() =>
      _StockAdjustmentFormScreenState();
}

class _StockAdjustmentFormScreenState
    extends ConsumerState<StockAdjustmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _memoController = TextEditingController();

  MovementType _type = MovementType.disposal;
  _AdjustmentDirection _direction = _AdjustmentDirection.decrease;
  String? _errorText;

  @override
  void dispose() {
    _quantityController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('폐기/조정 등록')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${widget.ingredient.name} · 남은 수량 '
              '${widget.lot.remainingQty}${widget.ingredient.baseUnit}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '입고일 '
              '${widget.lot.receivedDate.toIso8601String().substring(0, 10)}',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MovementType>(
              key: const Key('typeDropdown'),
              initialValue: _type,
              decoration: const InputDecoration(labelText: '유형'),
              items: const [
                DropdownMenuItem(
                  value: MovementType.disposal,
                  child: Text('폐기'),
                ),
                DropdownMenuItem(
                  value: MovementType.adjustment,
                  child: Text('조정'),
                ),
              ],
              onChanged: (value) => setState(() => _type = value!),
            ),
            if (_type == MovementType.adjustment)
              DropdownButtonFormField<_AdjustmentDirection>(
                key: const Key('directionDropdown'),
                initialValue: _direction,
                decoration: const InputDecoration(labelText: '증감'),
                items: const [
                  DropdownMenuItem(
                    value: _AdjustmentDirection.increase,
                    child: Text('증가'),
                  ),
                  DropdownMenuItem(
                    value: _AdjustmentDirection.decrease,
                    child: Text('감소'),
                  ),
                ],
                onChanged: (value) => setState(() => _direction = value!),
              ),
            TextFormField(
              key: const Key('quantityField'),
              controller: _quantityController,
              decoration: const InputDecoration(labelText: '수량'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '수량을 입력하세요';
                }
                if (double.tryParse(value) == null) return '숫자를 입력하세요';
                return null;
              },
            ),
            TextFormField(
              key: const Key('memoField'),
              controller: _memoController,
              decoration: const InputDecoration(labelText: '메모(선택)'),
            ),
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red),
                ),
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

    final enteredQty = double.parse(_quantityController.text);
    final signedQty = _type == MovementType.disposal
        ? -enteredQty
        : (_direction == _AdjustmentDirection.increase
            ? enteredQty
            : -enteredQty);

    final memo = _memoController.text.trim().isEmpty
        ? null
        : _memoController.text.trim();

    setState(() => _errorText = null);

    try {
      await ref.read(lotRepositoryProvider).recordQuantityChange(
            lotId: widget.lot.id,
            type: _type,
            quantity: signedQty,
            memo: memo,
          );
    } on InsufficientStockException catch (e) {
      setState(() {
        _errorText =
            '남은 수량(${e.remainingQty})보다 많이 뺄 수 없습니다 (요청: ${e.requestedQty})';
      });
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }
}
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/features/stock_adjustment/stock_adjustment_form_screen_test.dart`
Expected: PASS (2 tests passed)

- [ ] **Step 5: Commit**

```bash
git add lib/features/stock_adjustment test/features/stock_adjustment
git commit -m "feat: add disposal/adjustment registration screen"
```

---

### Task 4: 재고 조회 화면에서 연결

**Files:**
- Modify: `lib/features/stock_overview/stock_overview_screen.dart`
- Modify: `test/features/stock_overview/stock_overview_screen_test.dart`

- [ ] **Step 1: 실패하는 테스트 추가**

`test/features/stock_overview/stock_overview_screen_test.dart` 맨 위 import에 추가:

```dart
import 'package:stockcontrol/features/stock_adjustment/stock_adjustment_form_screen.dart';
```

`expect(find.text('임박'), findsOneWidget);` 다음, 기존의 정리용 pump 코드 앞에 이어서 추가:

```dart
    await tester.tap(find.text('임박'));
    await tester.pumpAndSettle();

    expect(find.byType(StockAdjustmentFormScreen), findsOneWidget);

```

(파일 맨 마지막의 `await tester.pumpWidget(const SizedBox.shrink());` / `await tester.pump(...)` 두 줄은 그대로 유지)

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/features/stock_overview/stock_overview_screen_test.dart`
Expected: FAIL — 로트 행을 탭해도 화면 전환이 없어 `StockAdjustmentFormScreen`을 찾지 못함

- [ ] **Step 3: 로트 행을 탭 가능하게 수정**

`lib/features/stock_overview/stock_overview_screen.dart` 맨 위 import에 추가:

```dart
import '../stock_adjustment/stock_adjustment_form_screen.dart';
```

`_IngredientGroupSection`의 `for (final lot in group.lots) _LotRow(lot: lot, now: DateTime.now()),` 줄을 아래로 교체:

```dart
        for (final lot in group.lots)
          _LotRow(
            lot: lot,
            ingredient: group.ingredient,
            now: DateTime.now(),
          ),
```

`_LotRow` 클래스 전체를 아래 내용으로 교체:

```dart
class _LotRow extends StatelessWidget {
  const _LotRow({
    required this.lot,
    required this.ingredient,
    required this.now,
  });

  final Lot lot;
  final Ingredient ingredient;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final near = isNearExpiry(lot.expiryDate, now: now);
    final expiryText = lot.expiryDate == null
        ? '유통기한 관리 안 함'
        : '유통기한 ${lot.expiryDate!.toIso8601String().substring(0, 10)}';

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StockAdjustmentFormScreen(
            lot: lot,
            ingredient: ingredient,
          ),
        ),
      ),
      child: Container(
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
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Text('${lot.remainingQty}'),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/features/stock_overview/stock_overview_screen_test.dart`
Expected: PASS (1 test passed)

- [ ] **Step 5: 정적 분석 확인**

Run: `flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 6: 전체 테스트 스위트 실행**

Run: `flutter test`
Expected: PASS — 이번 스펙에서 추가한 테스트(도메인 4개, 리포지토리 3개 추가, 화면 위젯 2개)를 포함해 전부 통과

- [ ] **Step 7: Commit**

```bash
git add lib/features/stock_overview test/features/stock_overview
git commit -m "feat: link stock overview lots to the adjustment screen"
```

---

## Self-Review 결과

**스펙 커버리지**: 진입 경로(재고 조회→로트 탭) — Task 4 / 폐기·조정 한 화면 + 유형 드롭다운 — Task 3 / 수량 부호(폐기=항상 감소, 조정=+/-) — Task 3 `_save()` / 음수 재고 방지(저장 차단+에러) — Task 1(순수 검증) + Task 2(트랜잭션 내 적용) + Task 3(에러 표시) / 저장 후 이전 화면 복귀 — Task 3 / 범위 밖 항목(마감 실사, 검색/필터, 반응형, 레시피 자동차감) — 이번 계획에 포함하지 않음, 스펙과 일치.

**타입 일관성 확인**: `applyQuantityChange(remainingQty, change)`와 `InsufficientStockException(remainingQty, requestedQty)` — Task 1에서 정의된 시그니처가 Task 2(`recordQuantityChange`)와 Task 3(화면의 catch 블록)에서 동일하게 사용됨. `LotRepository.recordQuantityChange({lotId, type, quantity, occurredAt, memo})`가 Task 3의 `_save()` 호출부와 일치. `StockAdjustmentFormScreen({lot, ingredient})` 생성자가 Task 3의 테스트와 Task 4의 `_LotRow` 호출부에서 동일하게 사용됨.
