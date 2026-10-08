import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/core/providers/stock_date_providers.dart';
import 'package:stockcontrol/core/theme/app_theme.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/data/repositories/lot_repository.dart';
import 'package:stockcontrol/domain/movement_type.dart';
import 'package:stockcontrol/domain/stock_by_date.dart';
import 'package:stockcontrol/features/stock_adjustment/stock_adjustment_form_screen.dart';
import 'package:stockcontrol/features/stock_overview/stock_overview_screen.dart';

import '../../support/corner_pixels.dart';

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

  Future<void> pumpScreen(
    WidgetTester tester,
    AppDatabase db, {
    DateTime? date,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          selectedStockDateProvider.overrideWith((ref) => date),
        ],
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

  /// 카드 하나만 있는 재고 조회 화면을 떠서 카드의 네 모서리 호 색을 검사한다.
  /// 마지막 로트 줄의 불투명한 배경이 아래쪽 두 모서리의 테두리를 덮던 결함을
  /// 잡으려고, 줄 배경과 테두리 색이 서로 다른 두 경우를 본다.
  Future<void> expectCardCornersKeepBorder(
    WidgetTester tester, {
    required DateTime? expiryDate,
    required Color border,
    required Color lastRowFill,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await addIngredient(db, '양파');
    await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: id,
        receivedDate: DateTime.now(),
        expiryDate: Value(expiryDate),
        unitCost: 10,
        remainingQty: 5000,
      ),
    );
    await setWidth(tester, 800);

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: RepaintBoundary(
          key: boundaryKey,
          child: const MaterialApp(home: StockOverviewScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final rect = tester.getRect(find.byKey(Key('ingredientCard_$id')));
    final pixels = await capturePixels(tester, boundaryKey);
    for (final corner in CardCorner.values) {
      expectBorderColor(
        cornerArcColor(pixels, rect, corner),
        border: border,
        fill: lastRowFill,
        where: corner.name,
      );
    }

    await disposeScreen(tester);
  }

  testWidgets('임박 로트가 있는 카드는 네 모서리까지 위험 테두리가 이어진다', (tester) async {
    await expectCardCornersKeepBorder(
      tester,
      expiryDate: DateTime.now().add(const Duration(days: 1)),
      border: AppColors.dangerBorder,
      lastRowFill: AppColors.dangerBackground,
    );
  });

  testWidgets('임박하지 않은 카드는 네 모서리까지 기본 테두리가 이어진다', (tester) async {
    await expectCardCornersKeepBorder(
      tester,
      expiryDate: null,
      border: AppColors.border,
      lastRowFill: AppColors.surface,
    );
  });

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

  /// 이틀 전에 1,000g을 입고하고 오늘 400g을 폐기한다. 유통기한은 내일이라
  /// 오늘 기준으로는 임박이다.
  Future<void> seedPastDisposal(AppDatabase db) async {
    final now = DateTime.now();
    final twoDaysAgo = DateTime(now.year, now.month, now.day - 2, 9);
    final id = await addIngredient(db, '양파');
    final lotId = await LotRepository(db).receiveLot(
      ingredientId: id,
      receivedDate: twoDaysAgo,
      expiryDate: now.add(const Duration(days: 1)),
      unitCost: 1,
      baseQty: 1000,
    );
    await LotRepository(db).recordQuantityChange(
      lotId: lotId,
      type: MovementType.disposal,
      quantity: -400,
    );
  }

  DateTime twoDaysAgoDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - 2);
  }

  group('날짜별 조회', () {
    testWidgets('오늘 화면은 지금 수량이고 날짜 버튼은 "오늘"이며 안내가 없다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedPastDisposal(db);

      await pumpScreen(tester, db);

      expect(find.text('600g'), findsOneWidget);
      expect(find.text('오늘'), findsOneWidget);
      expect(find.byKey(const Key('pastDateBanner')), findsNothing);
      expect(find.byKey(const Key('summaryNearExpiryCount')), findsOneWidget);

      await disposeScreen(tester);
    });

    testWidgets('지난 날짜는 그날 끝 기준 수량을 보인다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedPastDisposal(db);
      final date = twoDaysAgoDate();

      await pumpScreen(tester, db, date: date);

      expect(find.text('1,000g'), findsOneWidget);
      expect(find.text('600g'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('stockDateButton')),
          matching: find.text(stockDateLabel(date, now: DateTime.now())),
        ),
        findsOneWidget,
      );

      await disposeScreen(tester);
    });

    testWidgets('지난 날짜는 조회 전용이다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedPastDisposal(db);

      await pumpScreen(tester, db, date: twoDaysAgoDate());

      expect(find.textContaining('기준 (조회 전용)'), findsOneWidget);
      expect(find.text('임박'), findsNothing);
      expect(find.byKey(const Key('summaryNearExpiryCount')), findsNothing);
      expect(find.byKey(const Key('summaryItemCount')), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      await tester.tap(find.text('1,000'));
      await tester.pumpAndSettle();
      expect(find.byType(StockAdjustmentFormScreen), findsNothing);

      await disposeScreen(tester);
    });

    testWidgets('지난 날짜는 지금 기준 임박 품목을 앞으로 올리지 않는다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.now();
      final twoDaysAgo = DateTime(now.year, now.month, now.day - 2, 9);
      final repo = LotRepository(db);
      // 양파를 먼저 넣는다: 임박 우선이면 양파가 앞, 아니면 가나다순으로 당근이 앞.
      final onion = await addIngredient(db, '양파');
      final carrot = await addIngredient(db, '당근');
      await repo.receiveLot(
        ingredientId: onion,
        receivedDate: twoDaysAgo,
        expiryDate: now.add(const Duration(days: 1)),
        unitCost: 1,
        baseQty: 1000,
      );
      await repo.receiveLot(
        ingredientId: carrot,
        receivedDate: twoDaysAgo,
        unitCost: 1,
        baseQty: 500,
      );
      await setWidth(tester, 800);

      await pumpScreen(tester, db, date: twoDaysAgoDate());

      expect(
        cardTopLeft(tester, carrot).dx,
        lessThan(cardTopLeft(tester, onion).dx),
      );

      await disposeScreen(tester);
    });

    testWidgets('"오늘로 돌아가기"를 누르면 오늘 화면이 된다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedPastDisposal(db);

      await pumpScreen(tester, db, date: twoDaysAgoDate());
      expect(find.byKey(const Key('pastDateBanner')), findsOneWidget);

      await tester.tap(find.byKey(const Key('backToTodayButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('pastDateBanner')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('stockDateButton')),
          matching: find.text('오늘'),
        ),
        findsOneWidget,
      );
      expect(find.text('600g'), findsOneWidget);

      await disposeScreen(tester);
    });

    testWidgets('날짜 버튼을 누르면 달력이 뜬다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await pumpScreen(tester, db);
      await tester.tap(find.byKey(const Key('stockDateButton')));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      await disposeScreen(tester);
    });

    testWidgets('지난 날짜에 표시할 재고가 없으면 날짜가 들어간 빈 상태', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await pumpScreen(tester, db, date: twoDaysAgoDate());

      expect(find.text('이 날에는 표시할 재고가 없습니다'), findsOneWidget);
      expect(find.byKey(const Key('pastDateBanner')), findsOneWidget);

      await disposeScreen(tester);
    });
  });
}
