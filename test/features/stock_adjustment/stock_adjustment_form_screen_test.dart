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
