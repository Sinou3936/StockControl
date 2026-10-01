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
