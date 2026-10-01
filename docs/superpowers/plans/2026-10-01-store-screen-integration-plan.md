# 매장(Store) 도메인 모델 2차 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 재고 조회/입고 등록/마감 실사 화면을 매장 기준으로 동작하게 한다 — 직원은 자기 매장만, 사장은 특정 매장을 고르거나 전체 합산을 볼 수 있게.

**Architecture:** 새 파생 provider `activeStoreIdProvider` 하나가 "지금 이 화면이 어느 매장 기준으로 동작해야 하는가"를 결정한다(직원은 고정값, 사장은 드롭다운 선택값). 세 화면 모두 이 provider 하나만 보고 동작한다. 별도의 "합산 전용 화면"은 만들지 않는다 — 재고 조회/마감 실사가 이미 로트(Lot) 단위로 나열하므로, 매장 필터를 안 거는 것 자체가 "합산 + 세부 보기"가 된다.

**Tech Stack:** Flutter, Riverpod, Drift. 새 패키지 의존성 없음.

---

### Task 1: `selectedStoreProvider` + `activeStoreIdProvider`

**Files:**
- Modify: `lib/core/providers/store_providers.dart`
- Test: `test/core/providers/store_providers_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/core/providers/store_providers_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/auth_providers.dart';
import 'package:stockcontrol/core/providers/store_providers.dart';
import 'package:stockcontrol/data/local/database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  test('is null when there is no session', () {
    expect(container.read(activeStoreIdProvider), isNull);
  });

  test('is the session store id for a staff session', () {
    container.read(authSessionProvider.notifier).setSession(
          AuthSession(
            id: 'user-1',
            email: 'staff1@internal.local',
            pin: '111111',
            displayName: '직원1',
            role: 'staff',
            storeId: 'store-1',
            storeName: '울산점',
          ),
        );

    expect(container.read(activeStoreIdProvider), 'store-1');
  });

  test('is null for an owner until a store is selected', () async {
    container.read(authSessionProvider.notifier).setSession(
          AuthSession(
            id: 'user-owner',
            email: 'owner@internal.local',
            pin: '123456',
            displayName: '사장님',
            role: 'owner',
          ),
        );

    expect(container.read(activeStoreIdProvider), isNull);

    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-1', name: '울산점'),
    );
    final store = (await db.storeDao.watchAll().first).first;
    container.read(selectedStoreProvider.notifier).state = store;

    expect(container.read(activeStoreIdProvider), 'store-1');
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/core/providers/store_providers_test.dart`
Expected: FAIL — `selectedStoreProvider`/`activeStoreIdProvider`가 없어서 컴파일 에러

- [ ] **Step 3: provider 추가**

`lib/core/providers/store_providers.dart` 전체를 아래 내용으로 교체:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/local/database.dart';
import '../../data/repositories/store_repository.dart';
import '../../data/services/store_gateway.dart';
import 'auth_providers.dart';
import 'database_provider.dart';

final storeDaoProvider =
    Provider((ref) => ref.watch(appDatabaseProvider).storeDao);

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository(
    SupabaseStoreGateway(Supabase.instance.client),
    ref.watch(storeDaoProvider),
  );
});

/// 사장이 상단 드롭다운에서 고른 매장. `null`이면 "전체 합산"을 뜻한다.
/// 직원 세션에서는 이 provider를 쓰지 않는다 — `activeStoreIdProvider`를 보라.
final selectedStoreProvider = StateProvider<Store?>((ref) => null);

/// 지금 화면이 어느 매장 기준으로 동작해야 하는지. 직원은 자기 매장으로
/// 고정, 사장은 `selectedStoreProvider`를 따른다(선택 안 하면 null = 전체
/// 합산). 세 화면(재고 조회/입고 등록/마감 실사)과 `StoreSwitcher`는 이
/// provider 하나만 보면 된다.
final activeStoreIdProvider = Provider<String?>((ref) {
  final session = ref.watch(authSessionProvider);
  if (session == null) return null;
  if (!session.isOwner) return session.storeId;
  return ref.watch(selectedStoreProvider)?.id;
});
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/core/providers/store_providers_test.dart`
Expected: PASS (3 tests passed)

- [ ] **Step 5: 정적 분석 확인**

Run: `flutter analyze lib/core/providers`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/providers/store_providers.dart test/core/providers/store_providers_test.dart
git commit -m "feat: add activeStoreIdProvider for store-scoped screens"
```

---

### Task 2: `StoreSwitcher` 위젯

**Files:**
- Create: `lib/features/stock/store_switcher.dart`
- Test: `test/features/stock/store_switcher_test.dart`

- [ ] **Step 1: 실패하는 위젯 테스트 작성**

`test/features/stock/store_switcher_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/auth_providers.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/core/providers/store_providers.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/features/stock/store_switcher.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  testWidgets('hides for a staff session', (tester) async {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    container.read(authSessionProvider.notifier).setSession(
          AuthSession(
            id: 'user-1',
            email: 'staff1@internal.local',
            pin: '111111',
            displayName: '직원1',
            role: 'staff',
            storeId: 'store-1',
            storeName: '울산점',
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: StoreSwitcher())),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('storeSwitcherDropdown')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
      'shows stores plus an aggregate option for an owner, and updates '
      'the selection', (tester) async {
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-1', name: '울산점'),
    );

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    container.read(authSessionProvider.notifier).setSession(
          AuthSession(
            id: 'user-owner',
            email: 'owner@internal.local',
            pin: '123456',
            displayName: '사장님',
            role: 'owner',
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: StoreSwitcher())),
      ),
    );
    await tester.pump();

    final dropdown = tester.widget<DropdownButton<Store?>>(
      find.byKey(const Key('storeSwitcherDropdown')),
    );
    expect(dropdown.items, hasLength(2));
    expect(dropdown.value, isNull);

    const store = Store(id: 'store-1', name: '울산점');
    container.read(selectedStoreProvider.notifier).state = store;
    await tester.pump();

    expect(container.read(selectedStoreProvider)?.name, '울산점');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/features/stock/store_switcher_test.dart`
Expected: FAIL — `lib/features/stock/store_switcher.dart` 파일이 없어 컴파일 에러

- [ ] **Step 3: 위젯 구현**

`lib/features/stock/store_switcher.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/store_providers.dart';
import '../../data/local/database.dart';

class StoreSwitcher extends ConsumerWidget {
  const StoreSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(authSessionProvider)?.isOwner ?? false;
    if (!isOwner) return const SizedBox.shrink();

    final dao = ref.watch(storeDaoProvider);
    final selected = ref.watch(selectedStoreProvider);

    return StreamBuilder<List<Store>>(
      stream: dao.watchAll(),
      builder: (context, snapshot) {
        final stores = snapshot.data ?? [];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DropdownButton<Store?>(
            key: const Key('storeSwitcherDropdown'),
            value: selected,
            items: [
              const DropdownMenuItem<Store?>(
                value: null,
                child: Text('전체 합산'),
              ),
              for (final store in stores)
                DropdownMenuItem<Store?>(
                  value: store,
                  child: Text(store.name),
                ),
            ],
            onChanged: (value) =>
                ref.read(selectedStoreProvider.notifier).state = value,
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/features/stock/store_switcher_test.dart`
Expected: PASS (2 tests passed)

**실행 중 발견한 문제**: 두 번째 테스트에서 매장을 직접 DB에서 다시 읽어오려고 `await db.storeDao.watchAll().first`를 썼더니 `testWidgets` 안에서 영원히 멈췄다. `testWidgets`는 가짜 비동기(zone) 환경이라 `tester.pump()`로 넘기지 않는 real Timer/Stream 알림이 멀쩡히 끝나지 않는다(Drift `.watch()`의 알림 메커니즘이 여기 해당) — `tester.runAsync()`로 감싸거나, 아예 DB를 다시 거치지 않고 `const Store(id: 'store-1', name: '울산점')`처럼 값을 직접 만들어 쓰면 된다. 같은 패턴이 Task 1의 `test()`(플레인 Dart 테스트, `testWidgets` 아님)에서는 멀쩡히 동작했다 — 문제는 `testWidgets` 환경 안에서 real stream을 직접 await할 때만 생긴다. 위 코드에 이미 반영.

- [ ] **Step 5: Commit**

```bash
git add lib/features/stock/store_switcher.dart test/features/stock/store_switcher_test.dart
git commit -m "feat: add StoreSwitcher dropdown widget"
```

---

### Task 3: `LotDao` — storeId 필터

**Files:**
- Modify: `lib/data/local/daos/lot_dao.dart`
- Modify: `test/data/local/lot_dao_test.dart`

- [ ] **Step 1: 실패하는 테스트 추가**

`test/data/local/lot_dao_test.dart` 맨 끝 (`}` 앞)에 추가:
```dart

  test('watchAvailableLotsWithIngredient filters by storeId when given',
      () async {
    final storeOneLotId = await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        storeId: const Value('store-1'),
        receivedDate: DateTime(2026, 9, 1),
        unitCost: 15.0,
        remainingQty: 1000,
      ),
    );
    await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        storeId: const Value('store-2'),
        receivedDate: DateTime(2026, 9, 1),
        unitCost: 15.0,
        remainingQty: 2000,
      ),
    );

    final rows = await db.lotDao
        .watchAvailableLotsWithIngredient(storeId: 'store-1')
        .first;

    expect(rows, hasLength(1));
    expect(rows.first.lot.id, storeOneLotId);
  });
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/data/local/lot_dao_test.dart`
Expected: FAIL — `watchAvailableLotsWithIngredient`에 `storeId` 파라미터가 없어서 컴파일 에러

- [ ] **Step 3: LotDao 수정**

`lib/data/local/daos/lot_dao.dart`에서 `watchAvailableLotsWithIngredient` 메서드를 아래로 교체:
```dart
  Stream<List<LotWithIngredient>> watchAvailableLotsWithIngredient({
    String? storeId,
  }) {
    final query = select(lots).join([
      innerJoin(ingredients, ingredients.id.equalsExp(lots.ingredientId)),
    ])
      ..where(lots.remainingQty.isBiggerThanValue(0));

    if (storeId != null) {
      query.where(lots.storeId.equals(storeId));
    }

    query.orderBy([OrderingTerm.asc(lots.expiryDate)]);

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
Expected: PASS (3 tests passed — 기존 2개 + 신규 1개)

- [ ] **Step 5: Commit**

```bash
git add lib/data/local/daos/lot_dao.dart test/data/local/lot_dao_test.dart
git commit -m "feat: filter watchAvailableLotsWithIngredient by store"
```

---

### Task 4: `LotRepository.receiveLot` — storeId 반영

**Files:**
- Modify: `lib/data/repositories/lot_repository.dart`
- Modify: `test/data/repositories/lot_repository_test.dart`

- [ ] **Step 1: 실패하는 테스트 추가**

`test/data/repositories/lot_repository_test.dart` 맨 끝 (`}` 앞)에 추가:
```dart

  test('receiveLot records the given storeId on the new lot', () async {
    final lotId = await repository.receiveLot(
      ingredientId: ingredientId,
      storeId: 'store-1',
      receivedDate: DateTime(2026, 9, 3),
      unitCost: 15.0,
      baseQty: 1000,
    );

    final lot = await db.lotDao.getById(lotId);
    expect(lot.storeId, 'store-1');
  });
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/data/repositories/lot_repository_test.dart`
Expected: FAIL — `receiveLot`에 `storeId` 파라미터가 없어서 컴파일 에러

- [ ] **Step 3: LotRepository 수정**

`lib/data/repositories/lot_repository.dart`에서 `receiveLot` 메서드를 아래로 교체:
```dart
  Future<int> receiveLot({
    required int ingredientId,
    int? supplierId,
    String? storeId,
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
          storeId: Value(storeId),
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
```

`storeId`를 `required`가 아니라 선택값으로 둔 이유: 기존 테스트(`creates a lot and a matching inbound movement atomically` 등 5개)가 이미 `storeId` 없이 `receiveLot(...)`을 호출하고 있다 — 지금 필수로 만들면 이번 스펙 범위 밖인 그 테스트들까지 전부 고쳐야 한다. `InboundFormScreen`만 항상 실제 값을 넘기도록 Task 6에서 고친다.

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/data/repositories/lot_repository_test.dart`
Expected: PASS (7 tests passed — 기존 6개 + 신규 1개)

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/lot_repository.dart test/data/repositories/lot_repository_test.dart
git commit -m "feat: record storeId when receiving a lot"
```

---

### Task 5: `StockOverviewScreen` — 매장 필터 + 매장 이름 표시 + 전환 드롭다운

**Files:**
- Modify: `lib/features/stock_overview/stock_overview_screen.dart`

- [ ] **Step 1: 화면 수정**

`lib/features/stock_overview/stock_overview_screen.dart` 전체를 아래 내용으로 교체:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/dao_providers.dart';
import '../../core/providers/store_providers.dart';
import '../../data/local/database.dart';
import '../../domain/stock_overview.dart';
import '../stock/store_switcher.dart';
import '../stock_adjustment/stock_adjustment_form_screen.dart';

class StockOverviewScreen extends ConsumerWidget {
  const StockOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.watch(lotDaoProvider);
    final storeId = ref.watch(activeStoreIdProvider);
    final storeDao = ref.watch(storeDaoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('재고 조회'),
        actions: const [StoreSwitcher()],
      ),
      body: StreamBuilder<List<Store>>(
        stream: storeDao.watchAll(),
        builder: (context, storeSnapshot) {
          final storeNames = {
            for (final s in storeSnapshot.data ?? <Store>[]) s.id: s.name,
          };

          return StreamBuilder<List<LotWithIngredient>>(
            stream: dao.watchAvailableLotsWithIngredient(storeId: storeId),
            builder: (context, snapshot) {
              final groups = groupLotsByIngredient(
                snapshot.data ?? [],
                now: DateTime.now(),
              );

              return ListView.builder(
                itemCount: groups.length,
                itemBuilder: (context, index) => _IngredientGroupSection(
                  group: groups[index],
                  storeNames: storeNames,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _IngredientGroupSection extends StatelessWidget {
  const _IngredientGroupSection({
    required this.group,
    required this.storeNames,
  });

  final IngredientStockGroup group;
  final Map<String, String> storeNames;

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
          _LotRow(
            lot: lot,
            ingredient: group.ingredient,
            now: DateTime.now(),
            storeName: storeNames[lot.storeId],
          ),
      ],
    );
  }
}

class _LotRow extends StatelessWidget {
  const _LotRow({
    required this.lot,
    required this.ingredient,
    required this.now,
    this.storeName,
  });

  final Lot lot;
  final Ingredient ingredient;
  final DateTime now;
  final String? storeName;

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
            if (storeName != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  storeName!,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
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

`storeId`가 없는 로트(1차 적용 이전 테스트 데이터, 또는 세션이 없는 경우)는 `storeNames[lot.storeId]`가 `null`을 반환해서 매장 이름 표시 없이 그냥 기존처럼 나온다 — 하위 호환이 깨지지 않는다.

- [ ] **Step 2: 기존 테스트 실행 확인**

Run: `flutter test test/features/stock_overview/stock_overview_screen_test.dart`
Expected: PASS — 이 테스트는 세션을 설정하지 않으므로 `activeStoreIdProvider`가 `null`(필터 없음)이 되어 기존 로트가 그대로 보인다. 수정 없이 통과해야 한다.

- [ ] **Step 3: 정적 분석 확인**

Run: `flutter analyze lib/features/stock_overview`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/stock_overview/stock_overview_screen.dart
git commit -m "feat: filter stock overview by store and show store names"
```

---

### Task 6: `InboundFormScreen` — 매장 미선택 시 막기 + storeId 반영

**Files:**
- Modify: `lib/features/inbound/inbound_form_screen.dart`
- Modify: `test/features/inbound/inbound_form_screen_test.dart`
- Modify: `test/core/shell/app_shell_test.dart`

- [ ] **Step 1: 기존 테스트에 세션 추가 + 신규 테스트 추가**

`test/features/inbound/inbound_form_screen_test.dart` 전체를 아래 내용으로 교체:
```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/auth_providers.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/features/inbound/inbound_form_screen.dart';

void main() {
  testWidgets('shows validation errors when required fields are empty',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    container.read(authSessionProvider.notifier).setSession(
          AuthSession(
            id: 'user-1',
            email: 'staff1@internal.local',
            pin: '111111',
            displayName: '직원1',
            role: 'staff',
            storeId: 'store-1',
            storeName: '울산점',
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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

  testWidgets('shows a prompt instead of the form when no store is selected',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: InboundFormScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('매장을 선택해주세요'), findsOneWidget);
    expect(find.byKey(const Key('purchaseQtyField')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/features/inbound/inbound_form_screen_test.dart`
Expected: FAIL — "매장을 선택해주세요" 안내가 아직 없어서 두 번째 테스트 실패

- [ ] **Step 3: 화면 수정**

`lib/features/inbound/inbound_form_screen.dart` 전체를 아래 내용으로 교체:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/dao_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/store_providers.dart';
import '../../data/local/database.dart';
import '../../domain/unit_conversion.dart';
import '../ingredient_management/ingredient_list_screen.dart';
import '../stock/store_switcher.dart';
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
    final storeId = ref.watch(activeStoreIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('입고 등록'),
        actions: const [StoreSwitcher()],
      ),
      body: storeId == null
          ? const Center(child: Text('매장을 선택해주세요'))
          : _buildForm(storeId),
    );
  }

  Widget _buildForm(String storeId) {
    final supplierDao = ref.watch(supplierDaoProvider);
    final ingredientDao = ref.watch(ingredientDaoProvider);

    return Form(
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
            onPressed: () => _save(storeId),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Future<void> _save(String storeId) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedIngredient == null) return;

    final ingredient = _selectedIngredient!;
    final purchaseQty = double.parse(_purchaseQtyController.text);
    final unitCost = double.parse(_unitCostController.text);
    final baseQty =
        purchaseQtyToBaseQty(purchaseQty, ingredient.conversionFactor);

    final repository = ref.read(lotRepositoryProvider);
    await repository.receiveLot(
      ingredientId: ingredient.id,
      supplierId: _selectedSupplier?.id,
      storeId: storeId,
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
Expected: PASS (2 tests passed)

- [ ] **Step 5: 전체 테스트 실행하여 회귀 확인**

Run: `flutter test`
Expected: `test/core/shell/app_shell_test.dart`의 `keeps entered form values when switching tabs (IndexedStack)`가 깨진다 — 이 테스트는 세션 없이 `AppShell` 안의 `InboundFormScreen`에 바로 텍스트를 입력하는데, 이제 세션이 없으면 폼 대신 "매장을 선택해주세요"가 뜨어서 `purchaseQtyField`를 찾지 못한다.

`test/core/shell/app_shell_test.dart`에서 해당 테스트를 아래로 교체(세션 추가):
```dart
  testWidgets('keeps entered form values when switching tabs (IndexedStack)',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    container.read(authSessionProvider.notifier).setSession(
          AuthSession(
            id: 'user-1',
            email: 'staff1@internal.local',
            pin: '111111',
            displayName: '직원1',
            role: 'staff',
            storeId: 'store-1',
            storeName: '울산점',
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('입고 등록'));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('purchaseQtyField')), '3');

    await tester.tap(find.text('재고 조회'));
    await tester.pump();
    await tester.tap(find.text('입고 등록'));
    await tester.pump();

    expect(find.text('3'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
```

이 테스트는 이미 `ProviderScope`를 쓰는 `wrap()` 헬퍼 대신 `UncontrolledProviderScope`+`ProviderContainer`로 바꿔서 세션을 주입한다 — 같은 파일의 "desktop sidebar logout button" 테스트와 동일한 패턴이다.

Run: `flutter test`
Expected: PASS 전부

- [ ] **Step 6: 정적 분석 확인**

Run: `flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/inbound/inbound_form_screen.dart test/features/inbound/inbound_form_screen_test.dart test/core/shell/app_shell_test.dart
git commit -m "feat: require a store before registering inbound stock"
```

---

### Task 7: `CountScreen` — 매장 필터 + 매장 미선택 시 막기

**Files:**
- Modify: `lib/features/count/count_screen.dart`
- Modify: `test/features/count/count_screen_test.dart`

- [ ] **Step 1: 기존 테스트에 세션/storeId 반영 + 신규 테스트 추가**

`test/features/count/count_screen_test.dart` 전체를 아래 내용으로 교체:
```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/auth_providers.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/features/count/count_screen.dart';

void main() {
  late AppDatabase db;
  late int ingredientId;
  late int lotId;
  late ProviderContainer container;

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
        storeId: const Value('store-1'),
        receivedDate: DateTime(2026, 9, 1),
        unitCost: 10,
        remainingQty: 1000,
      ),
    );

    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    container.read(authSessionProvider.notifier).setSession(
          AuthSession(
            id: 'user-1',
            email: 'staff1@internal.local',
            pin: '111111',
            displayName: '직원1',
            role: 'staff',
            storeId: 'store-1',
            storeName: '울산점',
          ),
        );
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  Widget wrap() => UncontrolledProviderScope(
        container: container,
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

  testWidgets('shows a prompt instead of the form when no store is selected',
      (tester) async {
    final noSessionContainer = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(noSessionContainer.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: noSessionContainer,
        child: const MaterialApp(home: CountScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('매장을 선택해주세요'), findsOneWidget);
    expect(find.byKey(Key('countField_$ingredientId')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/features/count/count_screen_test.dart`
Expected: FAIL — "매장을 선택해주세요" 안내가 아직 없어서 세 번째 테스트 실패 (기존 2개는 storeId가 일치하므로 이미 통과할 수도 있음 — 그래도 화면을 고치기 전까진 전체 필터링 로직이 없는 상태)

- [ ] **Step 3: 화면 수정**

`lib/features/count/count_screen.dart` 전체를 아래 내용으로 교체:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/dao_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/store_providers.dart';
import '../../domain/stock_count.dart';
import '../../domain/stock_overview.dart';
import '../stock/store_switcher.dart';

class CountScreen extends ConsumerStatefulWidget {
  const CountScreen({super.key});

  @override
  ConsumerState<CountScreen> createState() => _CountScreenState();
}

class _CountScreenState extends ConsumerState<CountScreen> {
  final Map<int, double> _enteredCounts = {};

  @override
  Widget build(BuildContext context) {
    final storeId = ref.watch(activeStoreIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('마감 실사'),
        actions: const [StoreSwitcher()],
      ),
      body: storeId == null
          ? const Center(child: Text('매장을 선택해주세요'))
          : _buildCountList(storeId),
    );
  }

  Widget _buildCountList(String storeId) {
    final dao = ref.watch(lotDaoProvider);

    return StreamBuilder<List<LotWithIngredient>>(
      stream: dao.watchAvailableLotsWithIngredient(storeId: storeId),
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
Expected: PASS (3 tests passed)

- [ ] **Step 5: 정적 분석 + 전체 테스트 확인**

Run: `flutter analyze lib`
Expected: `No issues found!`

Run: `flutter test`
Expected: 1차 끝낸 시점의 72개에 이번 스펙에서 늘어난 테스트(store_providers +3, StoreSwitcher +2, LotDao +1, LotRepository +1, InboundFormScreen +1, CountScreen +1 — 총 9개 추가)를 더해 총 81개 통과

- [ ] **Step 6: Commit**

```bash
git add lib/features/count/count_screen.dart test/features/count/count_screen_test.dart
git commit -m "feat: require a store before taking a closing count"
```

---

### Task 8: 수동 확인 (실제 앱 대상)

- [ ] **Step 1**: 사장 계정으로 로그인 → 재고 조회가 "전체 합산"으로 시작하는지, 각 로트 행에 매장 이름이 보이는지 확인
- [ ] **Step 2**: 입고 등록 화면 진입 → "매장을 선택해주세요" 안내가 뜨는지, 드롭다운에서 매장을 고르면 폼이 나타나는지 확인
- [ ] **Step 3**: 매장을 골라서 입고 등록 → 재고 조회에서 그 로트가 선택한 매장으로 필터링됐을 때 보이는지, "전체 합산"으로 돌아가면 매장 이름과 함께 여전히 보이는지 확인
- [ ] **Step 4**: 마감 실사도 동일하게 매장 미선택 시 막히는지, 매장 선택 후 그 매장 로트만 나오는지 확인
- [ ] **Step 5**: 직원 계정으로 로그인 → 드롭다운 자체가 안 보이고 자기 매장 로트만 바로 나오는지 확인

---

## Self-Review 결과

**스펙 커버리지**: `activeStoreIdProvider`/`selectedStoreProvider` — Task 1 / `StoreSwitcher` 드롭다운 — Task 2 / `LotDao` 매장 필터 — Task 3 / `LotRepository.receiveLot` storeId 반영 — Task 4 / 재고 조회 필터+매장 이름 표시 — Task 5 / 입고 등록 매장 미선택 시 막기 — Task 6 / 마감 실사 매장 필터+막기 — Task 7 / 범위 밖 항목(품목·거래처 관리, 실데이터 동기화, 안전재고 알림) — 이번 계획에 포함하지 않음, 스펙과 일치.

**타입 일관성 확인**: `activeStoreIdProvider`(Task 1)가 Task 5·6·7 세 화면에서 전부 동일한 이름으로 쓰임. `LotDao.watchAvailableLotsWithIngredient({String? storeId})`(Task 3)가 Task 5·7의 호출부와 일치. `LotRepository.receiveLot(..., String? storeId, ...)`(Task 4)가 Task 6의 호출부와 일치. `StoreSwitcher`(Task 2)가 Task 5·6·7의 `AppBar(actions: [...])`에서 동일하게 쓰임.

**기존 테스트와의 호환성 확인**: `LotDao`/`LotRepository`의 `storeId`를 전부 선택값(옵션)으로 둬서, 3~6단계에서 만든 기존 call site(= `LotsCompanion.insert`를 storeId 없이 호출하는 곳들)가 깨지지 않는다. `StockOverviewScreen`의 기존 테스트는 세션이 없어 `activeStoreIdProvider`가 `null`(필터 없음)이 되므로 수정 없이 통과한다. `InboundFormScreen`/`CountScreen`은 "매장 미선택 시 막기"가 생겨서 기존 테스트에 세션(또는 매장 일치하는 로트)을 추가해야 했다 — Task 6·7에서 테스트 파일을 교체하며 반영했다. **실행 중 추가로 발견**: `test/core/shell/app_shell_test.dart`의 "keeps entered form values..." 테스트도 `AppShell` 내부의 `InboundFormScreen`에 세션 없이 바로 텍스트를 입력하고 있어서 같은 이유로 깨졌다 — Task 6에 해당 테스트 수정을 추가로 반영했다(7단계 전체 스위트 실행에서 발견됨, 자가 검토 당시엔 `app_shell_test.dart`가 `InboundFormScreen`을 간접적으로 쓴다는 걸 놓쳤다).

**태스크 순서 확인**: Task 6(입고 등록)은 Task 4(`receiveLot`의 storeId)와 Task 1·2(provider·위젯)에 의존하고, Task 7(마감 실사)은 Task 3(`LotDao` 필터)과 Task 1·2에 의존한다 — 전부 더 앞선 태스크 번호라 실행 순서상 문제없다. 매 태스크가 "화면 수정 + 그 화면의 테스트 수정"을 한 태스크 안에서 같이 끝내므로, 8-1/1차에서 자가 검토로 발견했던 "시그니처 변경과 호출부 수정 사이에 빌드가 깨지는 커밋" 문제가 재발하지 않는다.
