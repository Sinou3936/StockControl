import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/auth_providers.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/core/providers/sync_providers.dart';
import 'package:stockcontrol/core/shell/app_shell.dart';
import 'package:stockcontrol/core/shell/more_screen.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/features/store_management/store_management_screen.dart';
import 'package:stockcontrol/features/supplier_management/supplier_list_screen.dart';

import '../../support/fake_sync_controller.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Widget wrap() => ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: AppShell()),
      );

  testWidgets(
      'shows a navigation rail with 6 destinations on wide screens and '
      'switches the selected content', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.byType(NavigationRail), findsOneWidget);
    // 제목이 개수를 말하므로 실제로 센다. 세지 않으면 항목이 늘어도 제목만
    // 그럴듯하게 남아 거짓이 된다.
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).destinations,
      hasLength(6),
    );
    expect(find.text('거래처 관리'), findsOneWidget);
    expect(find.text('품목 관리'), findsOneWidget);
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);

    await tester.tap(find.text('입고 등록'));
    await tester.pump();

    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
      'shows a bottom nav with 5 items on narrow screens and opens '
      'MoreScreen from the last item', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .items,
      hasLength(5),
    );
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);

    await tester.tap(find.text('입고'));
    await tester.pump();

    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);

    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();

    expect(find.byType(MoreScreen), findsOneWidget);

    await tester.tap(find.text('거래처 관리'));
    await tester.pumpAndSettle();

    expect(find.byType(SupplierListScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('keeps entered form values when switching tabs (IndexedStack)',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('입고 등록'));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('purchaseQtyField')), '3');

    await tester.tap(find.text('재고 조회'));
    await tester.pump();
    await tester.tap(find.text('입고 등록'));
    await tester.pump();

    expect(find.text('3'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('desktop sidebar logout button clears the auth session',
      (tester) async {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    container.read(authSessionProvider.notifier).setSession(
          AuthSession(
            id: 'user-1',
            email: 'owner@internal.local',
            pin: '123456',
            displayName: '사장님',
            role: 'owner',
          ),
        );

    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('logoutButton')));
    await tester.pump();

    expect(container.read(authSessionProvider), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
      'shrinking the window while a desktop-only tab is selected falls back '
      'to a valid tab instead of crashing', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.tap(find.text('품목 관리'));
    await tester.pump();
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 5);

    tester.view.physicalSize = const Size(390, 800);
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);

    tester.view.physicalSize = const Size(1000, 800);
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 5);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('desktop sidebar sync button runs a sync', (tester) async {
    late FakeSyncController fake;
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        syncControllerProvider.overrideWith((ref) {
          fake = FakeSyncController(ref);
          return fake;
        }),
      ],
    );
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('syncButton')));
    await tester.pump();

    expect(fake.syncCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('부족 탭이 데스크톱 사이드바와 폰 하단 탭 모두에 있다', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('부족 재고'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('부족 재고'),
      ),
    );
    await tester.pump();
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 3);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('탭이 늘어난 뒤에도 폰 하단의 더보기가 열린다', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('더보기'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MoreScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('탭이 늘어난 뒤에도 사장 전용 항목이 올바른 화면을 연다',
      (tester) async {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    container.read(authSessionProvider.notifier).setSession(
          AuthSession(
            id: 'user-1',
            email: 'owner@internal.local',
            pin: '123456',
            displayName: '사장님',
            role: 'owner',
          ),
        );

    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('직원 추가'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('직원 추가'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('탭이 늘어난 뒤에도 사장의 매장 관리가 열린다', (tester) async {
    // 이 테스트가 없으면 index == 7 분기를 아무도 검증하지 않는다. 7을 놓치면
    // 어느 분기도 걸리지 않아 setState(_selectedIndex = 7)이 돌고,
    // IndexedStack은 children이 6개뿐이라 RangeError로 화면이 깨진다.
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    container.read(authSessionProvider.notifier).setSession(
          AuthSession(
            id: 'user-1',
            email: 'owner@internal.local',
            pin: '123456',
            displayName: '사장님',
            role: 'owner',
          ),
        );

    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('매장 관리'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StoreManagementScreen), findsOneWidget);

    // 이 화면은 서버에서 매장 목록을 새로 받으려고 Supabase를 직접 쓴다.
    // 테스트 환경에는 초기화된 인스턴스가 없어 그 단정이 난다. 여기서 볼 것은
    // 레일 인덱스 7이 이 화면을 연다는 것뿐이므로, 나는 예외가 그 하나임을
    // 확인하고 넘긴다. Hero 충돌 같은 다른 예외가 끼면 메시지가 달라져 깨진다.
    expect(
      tester.takeException().toString(),
      contains('You must initialize the supabase instance'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('부족 탭을 보던 중 창을 좁혀도 부족 탭에 그대로 있다',
      (tester) async {
    // 클램프 경계가 _primaryScreens.length(4)여야 한다. 3으로 되돌아가면
    // 부족 재고를 보던 사용자가 창을 좁히는 순간 재고 조회로 튕긴다.
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('부족 재고'),
      ),
    );
    await tester.pump();
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 3);

    tester.view.physicalSize = const Size(390, 800);
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 3);
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      3,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('부족 건수가 배지로 보이고 0이면 숨는다', (tester) async {
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-1', name: '울산점'),
    );
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-2', name: '부산점'),
    );

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    container.read(authSessionProvider.notifier).setSession(
          AuthSession(
            id: 'user-1',
            email: 'owner@internal.local',
            pin: '123456',
            displayName: '사장님',
            role: 'owner',
          ),
        );

    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // 추적 중인 품목이 없으면 부족도 0이라 숫자가 뜨지 않아야 한다.
    expect(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('2'),
      ),
      findsNothing,
    );

    // 두 매장 모두 재고 0이므로 부족 2건이 된다.
    await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
        safetyStockQty: const Value(5000),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
