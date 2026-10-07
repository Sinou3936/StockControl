import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/features/ingredient_management/ingredient_list_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addIngredient({double? safety}) =>
      db.ingredientDao.insertIngredient(
        IngredientsCompanion.insert(
          name: '양파',
          baseUnit: 'g',
          purchaseUnit: '박스',
          conversionFactor: 20000,
          isExpiryTracked: false,
          safetyStockQty: Value(safety),
        ),
      );

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: IngredientListScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> disposeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('설정된 안전재고가 목록에 보인다', (tester) async {
    await addIngredient(safety: 5000);

    await pumpScreen(tester);

    expect(find.text('안전재고 5,000g'), findsOneWidget);

    await disposeScreen(tester);
  });

  testWidgets('품목을 누르면 안전재고를 고칠 수 있다', (tester) async {
    final id = await addIngredient();

    await pumpScreen(tester);
    await tester.tap(find.text('양파'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('safetyStockField')), '5000');
    await tester.tap(find.widgetWithText(TextButton, '저장'));
    await tester.pumpAndSettle();

    final saved = (await db.select(db.ingredients).get()).firstWhere(
      (i) => i.id == id,
    );
    expect(saved.safetyStockQty, 5000);

    await disposeScreen(tester);
  });

  testWidgets('안전재고를 비우면 추적이 해제된다', (tester) async {
    final id = await addIngredient(safety: 5000);

    await pumpScreen(tester);
    await tester.tap(find.text('양파'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('safetyStockField')), '');
    await tester.tap(find.widgetWithText(TextButton, '저장'));
    await tester.pumpAndSettle();

    final saved = (await db.select(db.ingredients).get()).firstWhere(
      (i) => i.id == id,
    );
    expect(saved.safetyStockQty, isNull);

    await disposeScreen(tester);
  });

  testWidgets('안전재고를 고치면 전송 큐에도 남는다', (tester) async {
    final id = await addIngredient();
    await db.delete(db.syncQueue).go();

    await pumpScreen(tester);
    await tester.tap(find.text('양파'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('safetyStockField')), '3000');
    await tester.tap(find.widgetWithText(TextButton, '저장'));
    await tester.pumpAndSettle();

    final queued = await db.syncQueueDao.oldest();
    expect(queued!.targetTable, 'ingredients');
    expect(queued.recordId, id);

    await disposeScreen(tester);
  });

  testWidgets('신규 등록에서 안전재고를 함께 넣을 수 있다', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '품목명'), '당근');
    await tester.enterText(
      find.widgetWithText(TextField, '구매 단위 (예: 박스)'),
      '자루',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '구매단위 1개 = base unit 몇 개'),
      '10000',
    );
    await tester.enterText(
      find.byKey(const Key('newSafetyStockField')),
      '2500',
    );
    await tester.tap(find.widgetWithText(TextButton, '저장'));
    await tester.pumpAndSettle();

    final saved = (await db.select(db.ingredients).get()).firstWhere(
      (i) => i.name == '당근',
    );
    expect(saved.safetyStockQty, 2500);

    await disposeScreen(tester);
  });

  testWidgets('신규 등록에서 안전재고를 비워 두면 추적하지 않는다', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '품목명'), '당근');
    await tester.enterText(
      find.widgetWithText(TextField, '구매 단위 (예: 박스)'),
      '자루',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '구매단위 1개 = base unit 몇 개'),
      '10000',
    );
    await tester.tap(find.widgetWithText(TextButton, '저장'));
    await tester.pumpAndSettle();

    final saved = (await db.select(db.ingredients).get()).firstWhere(
      (i) => i.name == '당근',
    );
    expect(saved.safetyStockQty, isNull);

    await disposeScreen(tester);
  });
}
