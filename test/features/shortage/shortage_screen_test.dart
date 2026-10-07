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
}
