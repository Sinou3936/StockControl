import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/auth_providers.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/core/providers/stock_date_providers.dart';
import 'package:stockcontrol/core/providers/store_providers.dart';
import 'package:stockcontrol/core/theme/app_theme.dart';
import 'package:stockcontrol/core/widgets/app_widgets.dart';
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
    // 재고 스트림의 값이 온 뒤에야 입고 스트림이 구독되므로 한 번 더 흘려보낸다.
    await tester.pump(const Duration(milliseconds: 50));

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

  /// 세션·선택 매장·실제 앱 테마를 갖춘 화면 (사장/직원 시나리오용).
  Future<void> pumpAs(
    WidgetTester tester,
    AppDatabase db, {
    required AuthSession session,
    DateTime? date,
    Store? selectedStore,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          selectedStockDateProvider.overrideWith((ref) => date),
          authSessionProvider.overrideWith(
            (ref) => AuthSessionNotifier()..setSession(session),
          ),
          selectedStoreProvider.overrideWith((ref) => selectedStore),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const StockOverviewScreen(),
        ),
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

      // 같은 날 입고 카드에도 1,000g이 있으므로 품목 카드 안에서 본다.
      expect(
        find.descendant(
          of: find.byKey(const Key('ingredientCard_1')),
          matching: find.text('1,000g'),
        ),
        findsOneWidget,
      );
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
      // 입고 스트림은 재고 스트림 다음에 구독되어 한 번 더 필요하다.
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
      // 오늘용 안내("입고를 등록하면 …")는 지난 날짜에 어울리지 않는다.
      expect(find.textContaining('입고를 등록하면'), findsNothing);

      await disposeScreen(tester);
    });

    testWidgets('지난 날짜의 카드는 임박 로트가 있어도 위험 테두리가 없다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedPastDisposal(db);

      await pumpScreen(tester, db, date: twoDaysAgoDate());

      final card = tester.widget<Material>(
        find.byKey(const Key('ingredientCard_1')),
      );
      final shape = card.shape! as RoundedRectangleBorder;
      expect(shape.side.color, AppColors.border);

      await disposeScreen(tester);
    });

    testWidgets('지난 날짜에서 오늘로 돌아온 첫 프레임에 지난 수량이 나오지 않는다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedPastDisposal(db);

      await pumpScreen(tester, db, date: twoDaysAgoDate());
      expect(
        find.descendant(
          of: find.byKey(const Key('ingredientCard_1')),
          matching: find.text('1,000g'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('backToTodayButton')));
      // 새 스트림의 값이 오기 전의 첫 프레임: 이전 모드의 값이 남아 있으면
      // 지난 합계(1,000)가 탭 가능한 오늘 모드로 그려진다.
      await tester.pump();
      expect(find.text('1,000g'), findsNothing);
      expect(find.text('1,000'), findsNothing);

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('600g'), findsOneWidget);

      await disposeScreen(tester);
    });

    testWidgets('저장된 날짜가 미래여도 달력이 오류 없이 열린다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);

      await pumpScreen(tester, db, date: tomorrow);
      await tester.tap(find.byKey(const Key('stockDateButton')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DatePickerDialog), findsOneWidget);

      await disposeScreen(tester);
    });

    testWidgets('달력에서 날짜를 고르면 그 날짜 기준 화면으로 바뀐다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await addIngredient(db, '양파');
      final lotId = await LotRepository(db).receiveLot(
        ingredientId: id,
        receivedDate: DateTime(2025, 12, 30, 9),
        unitCost: 1,
        baseQty: 1000,
      );
      await LotRepository(db).recordQuantityChange(
        lotId: lotId,
        type: MovementType.disposal,
        quantity: -400,
      );
      await setWidth(tester, 800);

      await pumpScreen(tester, db);
      expect(find.text('600g'), findsOneWidget);

      await tester.tap(find.byKey(const Key('stockDateButton')));
      await tester.pumpAndSettle();
      // 달력 칸을 누르면 달·월 경계에 따라 깨지므로 입력 모드로 바꿔 날짜를 쓴다.
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '12/31/2025');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(StockOverviewScreen)),
      );
      expect(container.read(selectedStockDateProvider), DateTime(2025, 12, 31));
      expect(find.text('2025년 12월 31일 기준 (조회 전용)'), findsOneWidget);
      expect(find.text('1,000g'), findsOneWidget);
      expect(find.text('600g'), findsNothing);

      await disposeScreen(tester);
    });

    testWidgets('지난 날짜 화면도 직원 매장의 로트만 보인다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.storeDao.upsertStore(
        StoresCompanion.insert(id: 'a', name: '울산점'),
      );
      await db.storeDao.upsertStore(
        StoresCompanion.insert(id: 'b', name: '부산점'),
      );
      final onion = await addIngredient(db, '양파');
      final carrot = await addIngredient(db, '당근');
      final twoDaysAgo = twoDaysAgoDate().add(const Duration(hours: 9));
      await LotRepository(db).receiveLot(
        ingredientId: onion,
        storeId: 'a',
        receivedDate: twoDaysAgo,
        unitCost: 1,
        baseQty: 100,
      );
      await LotRepository(db).receiveLot(
        ingredientId: carrot,
        storeId: 'b',
        receivedDate: twoDaysAgo,
        unitCost: 1,
        baseQty: 200,
      );

      await pumpAs(
        tester,
        db,
        session: AuthSession(
          id: 'staff',
          email: 'staff@internal.local',
          pin: '111111',
          displayName: '직원',
          role: 'staff',
          storeId: 'a',
          storeName: '울산점',
        ),
        date: twoDaysAgoDate(),
      );

      // 입고 카드에도 같은 이름이 있으므로 품목 카드 키로 본다.
      expect(find.byKey(Key('ingredientCard_$onion')), findsOneWidget);
      expect(find.byKey(Key('ingredientCard_$carrot')), findsNothing);

      await disposeScreen(tester);
    });
  });

  group('이 날 입고 카드', () {
    final inboundCard = find.byKey(const Key('inboundDayCard'));

    Finder inCard(Finder matching) =>
        find.descendant(of: inboundCard, matching: matching);

    DateTime pastNoon(int daysAgo) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day - daysAgo, 12);
    }

    AuthSession staffOf(String storeId, String storeName) => AuthSession(
      id: 'staff',
      email: 'staff@internal.local',
      pin: '111111',
      displayName: '직원',
      role: 'staff',
      storeId: storeId,
      storeName: storeName,
    );

    testWidgets('오늘 입고 두 건이 카드에 나온다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.storeDao.upsertStore(
        StoresCompanion.insert(id: 'a', name: '울산점'),
      );
      final supplierId = await db.supplierDao.insertSupplier(
        SuppliersCompanion.insert(name: '가나다상사'),
      );
      final onion = await addIngredient(db, '양파');
      final carrot = await addIngredient(db, '당근');
      final repo = LotRepository(db);
      await repo.receiveLot(
        ingredientId: onion,
        storeId: 'a',
        supplierId: supplierId,
        receivedDate: DateTime.now(),
        unitCost: 1,
        baseQty: 1000,
      );
      await repo.receiveLot(
        ingredientId: carrot,
        receivedDate: DateTime.now(),
        unitCost: 1,
        baseQty: 500,
      );
      final movements = await db.select(db.stockMovements).get();
      expect(movements, hasLength(2));

      await pumpScreen(tester, db);

      expect(inboundCard, findsOneWidget);
      expect(inCard(find.text('오늘 입고 2건')), findsOneWidget);
      expect(inCard(find.text('양파')), findsOneWidget);
      expect(inCard(find.text('1,000g')), findsOneWidget);
      expect(inCard(find.text('울산점')), findsOneWidget);
      expect(inCard(find.text('가나다상사')), findsOneWidget);
      expect(inCard(find.text('당근')), findsOneWidget);
      expect(inCard(find.text('500g')), findsOneWidget);
      for (final m in movements) {
        expect(find.byKey(Key('inboundEntry_${m.id}')), findsOneWidget);
      }
      // 입고 줄은 어느 날짜에서도 눌리지 않는다.
      expect(inCard(find.byType(InkWell)), findsNothing);
      expect(inCard(find.byIcon(Icons.chevron_right)), findsNothing);

      await disposeScreen(tester);
    });

    testWidgets('입고가 없으면 안내 문구가 나오고 재고 카드는 그대로 보인다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await addIngredient(db, '양파');
      // 기록 없이 로트만 넣어 재고는 있고 입고 기록은 없게 한다.
      await db.lotDao.insertLot(
        LotsCompanion.insert(
          ingredientId: id,
          receivedDate: DateTime.now(),
          unitCost: 1,
          remainingQty: 300,
        ),
      );

      await pumpScreen(tester, db);

      expect(inCard(find.text('오늘 입고 0건')), findsOneWidget);
      expect(inCard(find.text('이 날 입고된 재고가 없습니다')), findsOneWidget);
      expect(find.byKey(Key('ingredientCard_$id')), findsOneWidget);

      await disposeScreen(tester);
    });

    testWidgets('오늘 입고한 뒤 오늘 폐기해도 입고 때 수량이 나온다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await addIngredient(db, '양파');
      final lotId = await LotRepository(db).receiveLot(
        ingredientId: id,
        receivedDate: DateTime.now(),
        unitCost: 1,
        baseQty: 1000,
      );
      await LotRepository(db).recordQuantityChange(
        lotId: lotId,
        type: MovementType.disposal,
        quantity: -400,
      );

      await pumpScreen(tester, db);

      expect(inCard(find.text('1,000g')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(Key('ingredientCard_$id')),
          matching: find.text('600g'),
        ),
        findsOneWidget,
      );

      await disposeScreen(tester);
    });

    testWidgets('지난 날짜는 그날 입고만 보인다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final onion = await addIngredient(db, '양파');
      final carrot = await addIngredient(db, '당근');
      final leek = await addIngredient(db, '대파');
      final repo = LotRepository(db);
      await repo.receiveLot(
        ingredientId: onion,
        receivedDate: pastNoon(2),
        unitCost: 1,
        baseQty: 100,
      );
      await repo.receiveLot(
        ingredientId: carrot,
        receivedDate: pastNoon(1),
        unitCost: 1,
        baseQty: 200,
      );
      await repo.receiveLot(
        ingredientId: leek,
        receivedDate: DateTime.now(),
        unitCost: 1,
        baseQty: 300,
      );

      await pumpScreen(tester, db, date: twoDaysAgoDate());
      expect(inCard(find.text('이 날 입고 1건')), findsOneWidget);
      expect(inCard(find.text('양파')), findsOneWidget);
      expect(inCard(find.text('당근')), findsNothing);
      expect(inCard(find.text('대파')), findsNothing);
      // 지난 날짜에서도 입고 줄은 눌리지 않는다.
      expect(inCard(find.byType(InkWell)), findsNothing);
      expect(inCard(find.byIcon(Icons.chevron_right)), findsNothing);

      // 새 ProviderScope로 오늘 화면을 다시 올린다 (override 값이 확실히 바뀌게).
      await disposeScreen(tester);
      await pumpScreen(tester, db);
      expect(inCard(find.text('오늘 입고 1건')), findsOneWidget);
      expect(inCard(find.text('대파')), findsOneWidget);
      expect(inCard(find.text('양파')), findsNothing);
      expect(inCard(find.text('당근')), findsNothing);

      await disposeScreen(tester);
    });

    testWidgets('사용·폐기·조정은 입고 목록에 들어가지 않는다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await addIngredient(db, '양파');
      final repo = LotRepository(db);
      final lotId = await repo.receiveLot(
        ingredientId: id,
        receivedDate: DateTime.now(),
        unitCost: 1,
        baseQty: 1000,
      );
      for (final type in [
        MovementType.usage,
        MovementType.disposal,
        MovementType.adjustment,
        MovementType.countCorrection,
      ]) {
        await repo.recordQuantityChange(
          lotId: lotId,
          type: type,
          quantity: -10,
        );
      }
      expect(await db.select(db.stockMovements).get(), hasLength(5));

      await pumpScreen(tester, db);

      expect(inCard(find.text('오늘 입고 1건')), findsOneWidget);

      await disposeScreen(tester);
    });

    testWidgets('그날 재고가 다 없어졌어도 입고 카드는 보인다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await addIngredient(db, '양파');
      final lotId = await LotRepository(db).receiveLot(
        ingredientId: id,
        receivedDate: DateTime.now(),
        unitCost: 1,
        baseQty: 1000,
      );
      await LotRepository(db).recordQuantityChange(
        lotId: lotId,
        type: MovementType.disposal,
        quantity: -1000,
      );

      await pumpScreen(tester, db);

      expect(inCard(find.text('오늘 입고 1건')), findsOneWidget);
      // 카드 아래 알림 한 줄이고, 화면 전체를 덮는 빈 상태가 아니다.
      expect(find.text('표시할 재고가 없습니다'), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_outlined), findsNothing);
      expect(find.byKey(Key('ingredientCard_$id')), findsNothing);

      await disposeScreen(tester);
    });

    testWidgets('직원은 자기 매장의 입고만 카드에서 본다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.storeDao.upsertStore(
        StoresCompanion.insert(id: 'a', name: '울산점'),
      );
      await db.storeDao.upsertStore(
        StoresCompanion.insert(id: 'b', name: '부산점'),
      );
      final onion = await addIngredient(db, '양파');
      final carrot = await addIngredient(db, '당근');
      final repo = LotRepository(db);
      await repo.receiveLot(
        ingredientId: onion,
        storeId: 'a',
        receivedDate: DateTime.now(),
        unitCost: 1,
        baseQty: 100,
      );
      await repo.receiveLot(
        ingredientId: carrot,
        storeId: 'b',
        receivedDate: DateTime.now(),
        unitCost: 1,
        baseQty: 200,
      );

      await pumpAs(tester, db, session: staffOf('a', '울산점'));

      expect(inCard(find.text('오늘 입고 1건')), findsOneWidget);
      expect(inCard(find.text('양파')), findsOneWidget);
      expect(inCard(find.text('당근')), findsNothing);
      expect(inCard(find.text('부산점')), findsNothing);

      await disposeScreen(tester);
    });

    testWidgets('입고 줄은 받은 순서대로, 이른 입고가 위에 그려진다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final onion = await addIngredient(db, '양파');
      final carrot = await addIngredient(db, '당근');
      final repo = LotRepository(db);
      final now = DateTime.now();
      // 늦은 입고(당근 10시)를 먼저 넣어 id 순서와 시간 순서가 다르게 한다.
      final carrotLot = await repo.receiveLot(
        ingredientId: carrot,
        receivedDate: DateTime(now.year, now.month, now.day, 10),
        unitCost: 1,
        baseQty: 200,
      );
      final onionLot = await repo.receiveLot(
        ingredientId: onion,
        receivedDate: DateTime(now.year, now.month, now.day, 9),
        unitCost: 1,
        baseQty: 100,
      );
      final movements = await db.select(db.stockMovements).get();
      final carrotMove = movements.firstWhere((m) => m.lotId == carrotLot);
      final onionMove = movements.firstWhere((m) => m.lotId == onionLot);
      expect(onionMove.occurredAt.hour, 9);
      expect(carrotMove.occurredAt.hour, 10);

      await pumpScreen(tester, db);

      final onionTop = tester.getTopLeft(
        find.byKey(Key('inboundEntry_${onionMove.id}')),
      );
      final carrotTop = tester.getTopLeft(
        find.byKey(Key('inboundEntry_${carrotMove.id}')),
      );
      expect(onionTop.dy, lessThan(carrotTop.dy));

      await disposeScreen(tester);
    });

    testWidgets('매장 이름은 칩으로, 거래처 이름은 일반 글자로 그려진다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.storeDao.upsertStore(
        StoresCompanion.insert(id: 'a', name: '울산점'),
      );
      final supplierId = await db.supplierDao.insertSupplier(
        SuppliersCompanion.insert(name: '가나다상사'),
      );
      final onion = await addIngredient(db, '양파');
      final carrot = await addIngredient(db, '당근');
      final repo = LotRepository(db);
      await repo.receiveLot(
        ingredientId: onion,
        storeId: 'a',
        supplierId: supplierId,
        receivedDate: DateTime.now(),
        unitCost: 1,
        baseQty: 100,
      );
      // 매장도 거래처도 없는 줄에는 칩이 없다.
      await repo.receiveLot(
        ingredientId: carrot,
        receivedDate: DateTime.now(),
        unitCost: 1,
        baseQty: 200,
      );

      await pumpScreen(tester, db);

      final chips = inCard(find.byType(InfoChip));
      expect(chips, findsOneWidget);
      expect(
        find.descendant(of: chips, matching: find.text('울산점')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: chips, matching: find.text('가나다상사')),
        findsNothing,
      );
      expect(inCard(find.text('가나다상사')), findsOneWidget);

      await disposeScreen(tester);
    });

    testWidgets('지난 날짜에 재고는 없고 입고만 있으면 날짜 문구로 안내한다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await addIngredient(db, '양파');
      final repo = LotRepository(db);
      final lotId = await repo.receiveLot(
        ingredientId: id,
        receivedDate: pastNoon(2),
        unitCost: 1,
        baseQty: 1000,
      );
      // 같은 날 안에 전량 폐기: 그날 끝 합계가 0이라 재고 카드가 없다.
      await repo.recordQuantityChange(
        lotId: lotId,
        type: MovementType.disposal,
        quantity: -1000,
        occurredAt: pastNoon(2).add(const Duration(hours: 3)),
      );

      await pumpScreen(tester, db, date: twoDaysAgoDate());

      expect(inCard(find.text('이 날 입고 1건')), findsOneWidget);
      expect(find.text('이 날에는 표시할 재고가 없습니다'), findsOneWidget);
      expect(find.text('표시할 재고가 없습니다'), findsNothing);
      expect(find.byKey(Key('ingredientCard_$id')), findsNothing);

      await disposeScreen(tester);
    });

    testWidgets('사장이 고른 매장의 입고만 카드에 나온다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.storeDao.upsertStore(
        StoresCompanion.insert(id: 'a', name: '울산점'),
      );
      await db.storeDao.upsertStore(
        StoresCompanion.insert(id: 'b', name: '부산점'),
      );
      final onion = await addIngredient(db, '양파');
      final carrot = await addIngredient(db, '당근');
      final repo = LotRepository(db);
      final ulsanLot = await repo.receiveLot(
        ingredientId: onion,
        storeId: 'a',
        receivedDate: DateTime.now(),
        unitCost: 1,
        baseQty: 100,
      );
      final busanLot = await repo.receiveLot(
        ingredientId: carrot,
        storeId: 'b',
        receivedDate: DateTime.now(),
        unitCost: 1,
        baseQty: 200,
      );
      final movements = await db.select(db.stockMovements).get();
      final ulsanMove = movements.firstWhere((m) => m.lotId == ulsanLot);
      final busanMove = movements.firstWhere((m) => m.lotId == busanLot);

      await pumpAs(
        tester,
        db,
        session: AuthSession(
          id: 'owner',
          email: 'owner@internal.local',
          pin: '123456',
          displayName: '사장님',
          role: 'owner',
        ),
        selectedStore: const Store(id: 'a', name: '울산점'),
      );

      expect(inCard(find.text('오늘 입고 1건')), findsOneWidget);
      expect(find.byKey(Key('inboundEntry_${ulsanMove.id}')), findsOneWidget);
      expect(find.byKey(Key('inboundEntry_${busanMove.id}')), findsNothing);
      expect(inCard(find.text('양파')), findsOneWidget);
      expect(inCard(find.text('당근')), findsNothing);

      await disposeScreen(tester);
    });

    testWidgets('폭 320에서 긴 품목·매장·거래처 이름이 넘치지 않는다', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      const longIngredient = '국내산 무항생제 친환경 유기농 양파 대용량 업소용 특품';
      const longStore = '부산 해운대 센텀시티 지점';
      const longSupplier = '대한민국 농협 경제지주 농산물 유통 부산 공판장 직거래';
      await db.storeDao.upsertStore(
        StoresCompanion.insert(id: 'b', name: longStore),
      );
      final supplierId = await db.supplierDao.insertSupplier(
        SuppliersCompanion.insert(name: longSupplier),
      );
      final id = await addIngredient(db, longIngredient);
      await LotRepository(db).receiveLot(
        ingredientId: id,
        storeId: 'b',
        supplierId: supplierId,
        receivedDate: DateTime.now(),
        unitCost: 1,
        baseQty: 123456,
      );
      await setWidth(tester, 320);

      await pumpAs(
        tester,
        db,
        session: AuthSession(
          id: 'owner',
          email: 'owner@internal.local',
          pin: '123456',
          displayName: '사장님',
          role: 'owner',
        ),
      );

      expect(tester.takeException(), isNull);
      // 품목명은 한 줄 말줄임.
      final name = inCard(find.text(longIngredient));
      expect(name, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(name).didExceedMaxLines,
        isTrue,
      );
      // 수량 칸은 자기 글자 폭을 지킨다 (품목명에 밀려 줄바꿈되지 않는다).
      final qty = inCard(find.text('123,456g'));
      expect(qty, findsOneWidget);
      final qtyParagraph = tester.renderObject<RenderParagraph>(qty);
      expect(qtyParagraph.didExceedMaxLines, isFalse);
      expect(
        tester.getSize(qty).width,
        greaterThanOrEqualTo(
          qtyParagraph.getMaxIntrinsicWidth(double.infinity),
        ),
      );
      expect(inCard(find.text(longStore)), findsOneWidget);
      expect(inCard(find.text(longSupplier)), findsOneWidget);

      await disposeScreen(tester);
    });
  });

  group('좁은 화면의 앱바', () {
    const longStoreName = '부산 해운대 센텀시티 지점';

    for (final width in [360.0, 320.0]) {
      for (final date in [null, DateTime(2025, 12, 31)]) {
        testWidgets(
          '사장 세션, 폭 ${width.toInt()}, 날짜 ${date == null ? '오늘' : '지난 날짜'}: '
          '넘치지 않고 제목과 날짜 버튼이 보인다',
          (tester) async {
            final db = AppDatabase(NativeDatabase.memory());
            addTearDown(db.close);
            await db.storeDao.upsertStore(
              StoresCompanion.insert(id: 'a', name: '울산점'),
            );
            await db.storeDao.upsertStore(
              StoresCompanion.insert(id: 'b', name: longStoreName),
            );
            await setWidth(tester, width);

            await pumpAs(
              tester,
              db,
              session: AuthSession(
                id: 'owner',
                email: 'owner@internal.local',
                pin: '123456',
                displayName: '사장님',
                role: 'owner',
              ),
              date: date,
              selectedStore: const Store(id: 'b', name: longStoreName),
            );

            expect(tester.takeException(), isNull);
            expect(find.byKey(const Key('stockDateButton')), findsOneWidget);
            // 제목이 자기 글자 폭만큼은 남아 있어야 한다 (0폭으로 사라지지 않는다).
            final title = find.text('재고 조회');
            expect(title, findsOneWidget);
            final natural = tester
                .renderObject<RenderParagraph>(title)
                .getMaxIntrinsicWidth(double.infinity);
            expect(tester.getSize(title).width, greaterThanOrEqualTo(natural));

            await disposeScreen(tester);
          },
        );
      }
    }

    Future<void> pumpOwnerWithLongStore(WidgetTester tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.storeDao.upsertStore(
        StoresCompanion.insert(id: 'a', name: '울산점'),
      );
      await db.storeDao.upsertStore(
        StoresCompanion.insert(id: 'b', name: longStoreName),
      );
      await setWidth(tester, 360);
      await pumpAs(
        tester,
        db,
        session: AuthSession(
          id: 'owner',
          email: 'owner@internal.local',
          pin: '123456',
          displayName: '사장님',
          role: 'owner',
        ),
        selectedStore: const Store(id: 'b', name: longStoreName),
      );
    }

    testWidgets('긴 매장명은 닫힌 스위처에서 말줄임되고 폭이 화면의 22%를 넘지 않는다', (tester) async {
      await pumpOwnerWithLongStore(tester);

      final selectedText = find.descendant(
        of: find.byKey(const Key('storeSwitcherDropdown')),
        matching: find.text(longStoreName),
      );
      expect(selectedText, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(selectedText);
      expect(paragraph.didExceedMaxLines, isTrue);
      expect(tester.getSize(selectedText).width, lessThanOrEqualTo(360 * 0.22));

      await disposeScreen(tester);
    });

    testWidgets('스위처를 열면 전체 매장명이 잘리지 않고 보인다', (tester) async {
      await pumpOwnerWithLongStore(tester);

      await tester.tap(find.byKey(const Key('storeSwitcherDropdown')));
      await tester.pumpAndSettle();

      final paragraphs = tester.renderObjectList<RenderParagraph>(
        find.text(longStoreName),
      );
      expect(
        paragraphs.any(
          (p) =>
              !p.didExceedMaxLines &&
              p.size.width >= p.getMaxIntrinsicWidth(double.infinity),
        ),
        isTrue,
      );

      await disposeScreen(tester);
    });
  });
}
