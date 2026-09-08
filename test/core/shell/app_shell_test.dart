import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/core/shell/app_shell.dart';
import 'package:stockcontrol/core/shell/more_screen.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/features/supplier_management/supplier_list_screen.dart';

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
      'shows a navigation rail with 5 destinations on wide screens and '
      'switches the selected content', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.byType(NavigationRail), findsOneWidget);
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
      'shows a bottom nav with 4 items on narrow screens and opens '
      'MoreScreen from the fourth item', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
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

    await tester.pumpWidget(wrap());
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
}
