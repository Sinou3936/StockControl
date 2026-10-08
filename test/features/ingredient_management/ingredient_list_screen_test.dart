import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/core/widgets/app_widgets.dart';
import 'package:stockcontrol/features/ingredient_management/ingredient_list_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addIngredient({double? safety, bool expiry = false}) =>
      db.ingredientDao.insertIngredient(
        IngredientsCompanion.insert(
          name: '양파',
          baseUnit: 'g',
          purchaseUnit: '박스',
          conversionFactor: 20000,
          isExpiryTracked: expiry,
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

  group('품목 카드의 칩', () {
    testWidgets('안전재고와 유통기한 관리가 둘 다 해당하면 칩이 둘 다 보인다', (tester) async {
      await addIngredient(safety: 5000, expiry: true);

      await pumpScreen(tester);

      expect(find.text('안전재고 5,000g'), findsOneWidget);
      expect(find.text('유통기한 관리'), findsOneWidget);

      await disposeScreen(tester);
    });

    testWidgets('안전재고만 해당하면 안전재고 칩만 보인다', (tester) async {
      await addIngredient(safety: 5000);

      await pumpScreen(tester);

      expect(find.text('안전재고 5,000g'), findsOneWidget);
      expect(find.text('유통기한 관리'), findsNothing);

      await disposeScreen(tester);
    });

    testWidgets('유통기한 관리만 해당하면 그 칩만 보인다', (tester) async {
      await addIngredient(expiry: true);

      await pumpScreen(tester);

      expect(find.text('유통기한 관리'), findsOneWidget);
      expect(find.textContaining('안전재고'), findsNothing);

      await disposeScreen(tester);
    });

    testWidgets('둘 다 해당하지 않으면 칩이 없다', (tester) async {
      await addIngredient();

      await pumpScreen(tester);

      expect(find.byType(InfoChip), findsNothing);

      await disposeScreen(tester);
    });

    testWidgets('좁은 폭에서 두 칩이 있어도 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await addIngredient(safety: 5000, expiry: true);

      await pumpScreen(tester);

      expect(find.text('안전재고 5,000g'), findsOneWidget);
      expect(find.text('유통기한 관리'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await disposeScreen(tester);
    });
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

  const safetyStockError = '숫자로 입력해 주세요 (예: 5000). 비우면 알림에서 제외됩니다.';

  Future<double?> savedSafety(int id) async =>
      (await db.select(db.ingredients).get())
          .firstWhere((i) => i.id == id)
          .safetyStockQty;

  Future<void> openSafetyStockDialog(WidgetTester tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('양파'));
    await tester.pumpAndSettle();
  }

  Future<void> openAddDialogAndFill(
    WidgetTester tester, {
    required String safety,
  }) async {
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
      safety,
    );
  }

  testWidgets('수정 다이얼로그에 천 단위 콤마가 든 5,000을 넣으면 5000으로 저장된다', (tester) async {
    final id = await addIngredient();

    await openSafetyStockDialog(tester);
    await tester.enterText(find.byKey(const Key('safetyStockField')), '5,000');
    await tester.tap(find.widgetWithText(TextButton, '저장'));
    await tester.pumpAndSettle();

    expect(await savedSafety(id), 5000);

    await disposeScreen(tester);
  });

  testWidgets('수정 다이얼로그에 0을 넣고 저장하면 추적이 해제되고 다이얼로그가 닫힌다', (tester) async {
    final id = await addIngredient(safety: 5000);

    await openSafetyStockDialog(tester);
    await tester.enterText(find.byKey(const Key('safetyStockField')), '0');
    await tester.tap(find.widgetWithText(TextButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safetyStockField')), findsNothing);
    expect(await savedSafety(id), isNull);

    await disposeScreen(tester);
  });

  testWidgets('수정 다이얼로그에 5000g를 넣으면 오류를 보이고 저장하지 않는다', (tester) async {
    final id = await addIngredient(safety: 5000);

    await openSafetyStockDialog(tester);
    await tester.enterText(find.byKey(const Key('safetyStockField')), '5000g');
    await tester.tap(find.widgetWithText(TextButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.text(safetyStockError), findsOneWidget);
    expect(find.byKey(const Key('safetyStockField')), findsOneWidget);
    expect(await savedSafety(id), 5000);

    await disposeScreen(tester);
  });

  testWidgets('오류가 뜬 뒤 값을 고치면 오류가 사라지고 저장된다', (tester) async {
    final id = await addIngredient(safety: 3000);

    await openSafetyStockDialog(tester);
    await tester.enterText(find.byKey(const Key('safetyStockField')), '5000g');
    await tester.tap(find.widgetWithText(TextButton, '저장'));
    await tester.pumpAndSettle();
    expect(find.text(safetyStockError), findsOneWidget);

    await tester.enterText(find.byKey(const Key('safetyStockField')), '5000');
    await tester.pump();
    expect(find.text(safetyStockError), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safetyStockField')), findsNothing);
    expect(await savedSafety(id), 5000);

    await disposeScreen(tester);
  });

  testWidgets('소수 안전재고는 반올림 없이 채워지고 그대로 저장해도 값이 같다', (tester) async {
    final id = await addIngredient(safety: 12.345);

    await openSafetyStockDialog(tester);

    final field = tester.widget<TextField>(
      find.byKey(const Key('safetyStockField')),
    );
    expect(field.controller!.text, '12.345');

    await tester.tap(find.widgetWithText(TextButton, '저장'));
    await tester.pumpAndSettle();

    expect(await savedSafety(id), 12.345);

    await disposeScreen(tester);
  });

  testWidgets('신규 등록에서 안전재고에 abc를 넣으면 오류를 보이고 품목을 만들지 않는다', (tester) async {
    await openAddDialogAndFill(tester, safety: 'abc');
    await tester.tap(find.widgetWithText(TextButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.text(safetyStockError), findsOneWidget);
    expect(find.byKey(const Key('newSafetyStockField')), findsOneWidget);
    expect(await db.select(db.ingredients).get(), isEmpty);

    await disposeScreen(tester);
  });

  testWidgets('신규 등록에서 안전재고 2,500을 넣으면 2500으로 만들어진다', (tester) async {
    await openAddDialogAndFill(tester, safety: '2,500');
    await tester.tap(find.widgetWithText(TextButton, '저장'));
    await tester.pumpAndSettle();

    final saved = (await db.select(db.ingredients).get()).firstWhere(
      (i) => i.name == '당근',
    );
    expect(saved.safetyStockQty, 2500);

    await disposeScreen(tester);
  });

  testWidgets('신규 등록의 안전재고 칸에 기본 단위가 보인다', (tester) async {
    await openAddDialogAndFill(tester, safety: '');

    expect(
      find.descendant(
        of: find.byKey(const Key('newSafetyStockField')),
        matching: find.text('g'),
      ),
      findsOneWidget,
    );

    await disposeScreen(tester);
  });
}
