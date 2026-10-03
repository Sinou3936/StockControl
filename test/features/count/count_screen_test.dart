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

  // 마감 실사는 하단 탭(앱의 첫 화면 안)에 들어가므로 별도 화면으로 열지 않고
  // home으로 직접 띄운다. 제출 후 화면이 닫히면 앱 전체가 사라진다.
  Widget wrapAsTab() => UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CountScreen()),
      );

  testWidgets(
      'shows a difference dialog, applies the correction on confirm, and '
      'stays on the screen with the field cleared', (tester) async {
    await tester.pumpWidget(wrapAsTab());
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

    expect(find.byType(CountScreen), findsOneWidget);
    final field = tester.widget<TextFormField>(
      find.byKey(Key('countField_$ingredientId')),
    );
    expect(field.controller?.text ?? '', isEmpty);
    expect(find.text('실사가 반영되었습니다'), findsOneWidget);

    final lot = await db.lotDao.getById(lotId);
    expect(lot.remainingQty, 700);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('counting zero empties the stock and keeps the screen open',
      (tester) async {
    await tester.pumpWidget(wrapAsTab());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(Key('countField_$ingredientId')), '0');
    await tester.tap(find.text('실사 제출'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확정'));
    await tester.pumpAndSettle();

    expect(find.byType(CountScreen), findsOneWidget);
    final lot = await db.lotDao.getById(lotId);
    expect(lot.remainingQty, 0);

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
