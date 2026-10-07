import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/auth_providers.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/core/providers/store_providers.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/features/inbound/inbound_form_screen.dart';
import 'package:stockcontrol/features/purchase_order/purchase_order_screen.dart';
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

  testWidgets('판정할 매장이 없으면 기준 이상이라고 말하지 않는다', (tester) async {
    await addTrackedIngredient('양파', 5000);

    // 세션의 매장이 로컬 매장 목록에 없는 상태 — 매장 정보를 아직 받지 못한
    // 기기에서 일어난다. 판정이 한 건도 되지 않았으므로 "기준 이상"이라고
    // 안내하면 재고가 충분하다는 뜻으로 읽힌다.
    await pumpScreen(tester, staff(storeId: 'store-없는곳'));

    expect(find.text('판정할 매장이 없습니다'), findsOneWidget);
    expect(find.text('모든 품목이 기준 이상입니다'), findsNothing);
    expect(
      find.text('매장 정보를 아직 받지 못했습니다. 동기화한 뒤 다시 확인해주세요'),
      findsOneWidget,
    );

    await disposeScreen(tester);
  });

  testWidgets('매장이 지정되지 않은 직원에게는 사장에게 요청하라고 안내한다',
      (tester) async {
    await addTrackedIngredient('양파', 5000);

    await pumpScreen(tester, staff());

    expect(
      find.text('계정에 매장이 지정되지 않았습니다. 사장님께 매장 지정을 요청해주세요'),
      findsOneWidget,
    );

    await disposeScreen(tester);
  });

  testWidgets('매장을 등록하지 않은 사장에게는 매장 등록을 안내한다', (tester) async {
    // 매장을 전부 지운 상태 — 새로 설치한 사장이 처음 이 탭을 누르는 경우다.
    // 사장에게 "계정에 매장 미지정"이나 "동기화"를 안내하면 둘 다 거짓이고,
    // 정작 할 수 있는 조치를 가리키지 않는다.
    await db.delete(db.stores).go();
    await addTrackedIngredient('양파', 5000);

    await pumpScreen(tester, owner());

    expect(find.text('판정할 매장이 없습니다'), findsOneWidget);
    expect(
      find.text('매장 관리에서 매장을 등록하면 매장별로 부족한 품목을 확인할 수 있습니다'),
      findsOneWidget,
    );

    await disposeScreen(tester);
  });

  testWidgets('매장도 없고 추적 품목도 없으면 매장 안내가 먼저다', (tester) async {
    // 두 빈 상태 조건이 동시에 참인 경우. 순서가 뒤집히면 직원에게 "품목 관리
    // 에서 안전재고를 정하세요"라고, 직원이 할 수 없는 일을 안내하게 된다.
    await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
      ),
    );

    await pumpScreen(tester, staff());

    expect(find.text('판정할 매장이 없습니다'), findsOneWidget);
    expect(find.text('안전재고가 설정된 품목이 없습니다'), findsNothing);

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

    // 넘긴 것으로 끝이 아니라, 입고 폼이 그 품목을 실제로 골라 둔 상태여야
    // 한다. 이걸 보지 않으면 폼이 받은 값을 무시해도 테스트가 통과한다.
    final dropdown = tester.widget<DropdownButtonFormField<Ingredient>>(
      find.byKey(const Key('ingredientDropdown')),
    );
    expect(dropdown.initialValue?.id, id);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

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

  testWidgets('매장을 고른 사장이 누르면 그 매장의 부족 품목으로 발주서 화면이 열린다', (tester) async {
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

  /// 사장이 울산점을 고른 상태로 부족 화면을 띄운다.
  Future<void> pumpOwnerWithStore(WidgetTester tester) async {
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
  }

  testWidgets('발주서 만들기를 빠르게 두 번 눌러도 발주서 화면은 하나만 열린다', (tester) async {
    await addTrackedIngredient('양파', 5000);
    await pumpOwnerWithStore(tester);

    // 사이에 pump 없이 같은 버튼 동작을 두 번 부른다. 두 번째가 화면이 다시
    // 그려지기 전에 들어오므로 setState가 아니라 동기적인 표시로 막아야 한다.
    //
    // tester.tap을 두 번 쓰지 않는 이유: Navigator는 push 직후 그 프레임 동안
    // 포인터를 흡수해서 두 번째 탭이 버튼에 닿지 않는다(가드가 없어도 통과해
    // 버려 아무것도 증명하지 못한다). 키보드로 누르기처럼 포인터를 거치지 않는
    // 두 번째 동작은 흡수되지 않으므로, 버튼의 onPressed를 직접 두 번 부른다.
    final onPressed = tester
        .widget<FilledButton>(find.byKey(const Key('purchaseOrderButton')))
        .onPressed!;
    onPressed();
    onPressed();
    await tester.pumpAndSettle();

    // 기본값(skipOffstage: true)이면 아래에 깔린 화면은 화면 밖으로 취급되어
    // 둘을 쌓아도 하나로 센다.
    expect(
      find.byType(PurchaseOrderScreen, skipOffstage: false),
      findsOneWidget,
    );

    await disposeScreen(tester);
  });

  testWidgets('매장 이름이 바뀐 뒤에 열면 발주서에 바뀐 이름이 찍힌다', (tester) async {
    await addTrackedIngredient('양파', 5000);
    // selectedStoreProvider에는 옛 이름의 울산점 객체가 그대로 남는다.
    await pumpOwnerWithStore(tester);

    // 사장이 매장을 고른 뒤에 동기화로 새 이름을 받은 상황.
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-1', name: '울산본점'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const Key('purchaseOrderButton')));
    await tester.pumpAndSettle();

    final screen = tester.widget<PurchaseOrderScreen>(
      find.byType(PurchaseOrderScreen),
    );
    expect(screen.store.id, 'store-1');
    expect(screen.store.name, '울산본점');

    await disposeScreen(tester);
  });

  testWidgets('발주서 화면에서 돌아오면 발주서 만들기 버튼이 다시 눌린다', (tester) async {
    await addTrackedIngredient('양파', 5000);
    await pumpOwnerWithStore(tester);

    await tester.tap(find.byKey(const Key('purchaseOrderButton')));
    await tester.pumpAndSettle();
    expect(find.byType(PurchaseOrderScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(PurchaseOrderScreen, skipOffstage: false), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('purchaseOrderButton')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('purchaseOrderButton')));
    await tester.pumpAndSettle();
    expect(find.byType(PurchaseOrderScreen), findsOneWidget);

    await disposeScreen(tester);
  });
}
