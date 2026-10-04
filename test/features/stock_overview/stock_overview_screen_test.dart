import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/features/stock_adjustment/stock_adjustment_form_screen.dart';
import 'package:stockcontrol/features/stock_overview/stock_overview_screen.dart';

void main() {
  testWidgets('shows ingredient groups and flags near-expiry lots', (
    tester,
  ) async {
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

    await tester.tap(find.text('임박'));
    await tester.pumpAndSettle();

    expect(find.byType(StockAdjustmentFormScreen), findsOneWidget);

    // Drift watch() 스트림의 구독 취소 시 예약되는 정리용 타이머(0초 지연)를
    // 테스트 종료 전에 흘려보낸다 (inbound_form_screen_test.dart와 동일 패턴).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  Future<int> addIngredient(AppDatabase db, String name) =>
      db.ingredientDao.insertIngredient(
        IngredientsCompanion.insert(
          name: name,
          baseUnit: 'g',
          purchaseUnit: '박스',
          conversionFactor: 20000,
          isExpiryTracked: true,
        ),
      );

  Future<void> pumpScreen(WidgetTester tester, AppDatabase db) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: StockOverviewScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> disposeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('shows an empty-state message when there is no stock', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await pumpScreen(tester, db);

    expect(find.text('표시할 재고가 없습니다'), findsOneWidget);

    await disposeScreen(tester);
  });

  Future<AppDatabase> dbWithIngredients(int count) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (var i = 1; i <= count; i++) {
      final id = await addIngredient(db, '품목$i');
      await db.lotDao.insertLot(
        LotsCompanion.insert(
          ingredientId: id,
          receivedDate: DateTime.now(),
          unitCost: 10,
          remainingQty: 100.0 * i,
        ),
      );
    }
    return db;
  }

  Future<void> setWidth(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Offset cardTopLeft(WidgetTester tester, int ingredientNumber) =>
      tester.getTopLeft(find.byKey(Key('ingredientCard_$ingredientNumber')));

  testWidgets('lays ingredient cards out three per row at the default '
      'desktop width', (tester) async {
    final db = await dbWithIngredients(4);
    await setWidth(tester, 800);

    await pumpScreen(tester, db);

    final first = cardTopLeft(tester, 1);
    final second = cardTopLeft(tester, 2);
    final third = cardTopLeft(tester, 3);
    final fourth = cardTopLeft(tester, 4);
    expect(second.dy, first.dy);
    expect(third.dy, first.dy);
    expect(second.dx, greaterThan(first.dx));
    expect(third.dx, greaterThan(second.dx));
    expect(fourth.dy, greaterThan(first.dy));
    expect(fourth.dx, first.dx);

    await disposeScreen(tester);
  });

  testWidgets('falls back to one card per row at phone width', (tester) async {
    final db = await dbWithIngredients(3);
    await setWidth(tester, 390);

    await pumpScreen(tester, db);

    final first = cardTopLeft(tester, 1);
    final second = cardTopLeft(tester, 2);
    expect(second.dx, first.dx);
    expect(second.dy, greaterThan(first.dy));

    await disposeScreen(tester);
  });

  testWidgets('summarises item count and near-expiry lot count, and formats '
      'quantities with thousands separators', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final onion = await addIngredient(db, '양파');
    final carrot = await addIngredient(db, '당근');
    await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: onion,
        receivedDate: DateTime.now(),
        expiryDate: Value(DateTime.now().add(const Duration(days: 1))),
        unitCost: 10,
        remainingQty: 5000,
      ),
    );
    await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: carrot,
        receivedDate: DateTime.now(),
        expiryDate: Value(DateTime.now().add(const Duration(days: 30))),
        unitCost: 10,
        remainingQty: 1234.5,
      ),
    );

    await pumpScreen(tester, db);

    expect(
      tester.widget<Text>(find.byKey(const Key('summaryItemCount'))).data,
      '2',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('summaryNearExpiryCount'))).data,
      '1',
    );
    expect(find.text('5,000g'), findsOneWidget);
    expect(find.text('1,234.5g'), findsOneWidget);

    await disposeScreen(tester);
  });
}
