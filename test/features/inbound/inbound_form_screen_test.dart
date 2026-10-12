import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/auth_providers.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/features/inbound/inbound_form_screen.dart';

void main() {
  testWidgets('shows validation errors when required fields are empty', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    container
        .read(authSessionProvider.notifier)
        .setSession(
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

  testWidgets('shows a prompt instead of the form when no store is selected', (
    tester,
  ) async {
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

  testWidgets('미리 고른 품목의 안전재고가 바뀌어도 품목 드롭다운이 깨지지 않는다', (tester) async {
    // drift가 생성한 Ingredient.==는 safetyStockQty를 포함한다. 폼이 품목
    // 객체를 붙잡아 둔 상태에서 그 값이 바뀌면(사장이 고쳤거나 동기화로
    // 받았거나) 붙잡은 객체가 새 목록의 어떤 항목과도 같지 않게 되어,
    // DropdownButton이 "값에 해당하는 항목이 정확히 하나" 단정에 걸린다.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final id = await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
      ),
    );
    // watchAll().first를 testWidgets 안에서 기다리면 멈춘다. 한 번 읽는
    // 쿼리는 괜찮다.
    final ingredient = (await db.select(db.ingredients).get()).firstWhere(
      (i) => i.id == id,
    );

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    container
        .read(authSessionProvider.notifier)
        .setSession(
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
        child: MaterialApp(
          home: InboundFormScreen(initialIngredient: ingredient),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await db.ingredientDao.updateSafetyStock(id, 6000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);

    final dropdown = tester.widget<DropdownButtonFormField<Ingredient>>(
      find.byKey(const Key('ingredientDropdown')),
    );
    expect(dropdown.initialValue?.id, id);
    expect(dropdown.initialValue?.safetyStockQty, 6000);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('수량과 단가에 천 단위 쉼표가 붙고 저장은 쉼표 없는 값으로 된다', (tester) async {
    // 저장 버튼이 화면 안에 들어오도록 키운다.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-1', name: '울산점'),
    );
    await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
      ),
    );
    final ingredient = (await db.select(db.ingredients).get()).single;

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    container
        .read(authSessionProvider.notifier)
        .setSession(
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
        child: MaterialApp(
          home: InboundFormScreen(initialIngredient: ingredient),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byKey(const Key('purchaseQtyField')), '1234');
    await tester.enterText(find.byKey(const Key('unitCostField')), '45000');
    await tester.pump();

    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('purchaseQtyField')),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      '1,234',
    );
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('unitCostField')),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      '45,000',
    );
    // 환산 미리보기도 쉼표 때문에 깨지지 않는다: 1,234 박스 x 20,000 g.
    expect(find.text('24,680,000 g'), findsOneWidget);

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    final lot = (await db.select(db.lots).get()).single;
    expect(lot.unitCost, 45000);
    expect(lot.remainingQty, 24680000);
    expect(find.text('숫자를 입력하세요'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
