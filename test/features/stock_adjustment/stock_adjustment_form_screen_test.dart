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

  testWidgets(
    'shows an error and stays when disposal exceeds remaining stock',
    (tester) async {
      await tester.pumpWidget(
        wrap(StockAdjustmentFormScreen(lot: lot, ingredient: ingredient)),
      );

      await tester.enterText(find.byKey(const Key('quantityField')), '500');
      await tester.tap(find.text('저장'));
      await tester.pump();

      expect(find.textContaining('남은 수량'), findsWidgets);
      expect(find.byType(StockAdjustmentFormScreen), findsOneWidget);
    },
  );

  testWidgets('수량에 쉼표가 붙어도 숫자로 읽어 남은 수량과 비교한다', (tester) async {
    await tester.pumpWidget(
      wrap(StockAdjustmentFormScreen(lot: lot, ingredient: ingredient)),
    );

    await tester.enterText(find.byKey(const Key('quantityField')), '1000');
    await tester.pump();
    expect(find.text('1,000'), findsOneWidget);

    await tester.tap(find.text('저장'));
    await tester.pump();

    // 쉼표 때문에 숫자로 못 읽었다면 '숫자를 입력하세요'가 나온다.
    expect(find.text('숫자를 입력하세요'), findsNothing);
    expect(find.textContaining('남은 수량'), findsWidgets);
  });

  Future<void> pumpTall(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      wrap(StockAdjustmentFormScreen(lot: lot, ingredient: ingredient)),
    );
  }

  bool switchValue(WidgetTester tester) => tester
      .widget<SwitchListTile>(find.byKey(const Key('expiryTrackedSwitch')))
      .value;

  testWidgets('변경 내용에 유통기한 관리 스위치가 품목의 현재 값으로 보인다', (tester) async {
    await pumpTall(tester);

    expect(find.text('유통기한 관리'), findsOneWidget);
    expect(switchValue(tester), isFalse); // setUp의 품목은 관리 안 함

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('스위치를 켜면 저장 버튼 없이 바로 품목에 저장되고 화면과 입력은 그대로다', (tester) async {
    await pumpTall(tester);
    await db.delete(db.syncQueue).go();
    await tester.enterText(find.byKey(const Key('quantityField')), '30');

    await tester.tap(find.byKey(const Key('expiryTrackedSwitch')));
    await tester.pumpAndSettle();

    final saved = (await db.select(db.ingredients).get()).single;
    expect(saved.isExpiryTracked, isTrue);
    expect(switchValue(tester), isTrue);
    // 화면은 닫히지 않고, 적어 둔 수량도 남아 있고, 재고 기록은 만들어지지 않는다.
    expect(find.byType(StockAdjustmentFormScreen), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(await db.select(db.stockMovements).get(), isEmpty);
    expect(find.text('유통기한 관리를 켰습니다'), findsOneWidget);
    // 다른 기기로 전달된다.
    final queued = await db.select(db.syncQueue).get();
    expect(queued.map((q) => q.targetTable), ['ingredients']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('켠 스위치를 다시 끌 수 있다', (tester) async {
    await pumpTall(tester);

    await tester.tap(find.byKey(const Key('expiryTrackedSwitch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expiryTrackedSwitch')));
    await tester.pumpAndSettle();

    final saved = (await db.select(db.ingredients).get()).single;
    expect(saved.isExpiryTracked, isFalse);
    expect(switchValue(tester), isFalse);
    expect(find.text('유통기한 관리를 껐습니다'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('pops back to the previous screen after a valid disposal', (
    tester,
  ) async {
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
