import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/auth_providers.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/core/shell/app_shell.dart';
import 'package:stockcontrol/core/shell/more_screen.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/features/excel_import/excel_import_screen.dart';

AuthSession owner() => AuthSession(
  id: 'owner',
  email: 'owner@internal.local',
  pin: '123456',
  displayName: '사장님',
  role: 'owner',
);

AuthSession staff() => AuthSession(
  id: 'staff',
  email: 'staff@internal.local',
  pin: '111111',
  displayName: '직원',
  role: 'staff',
  storeId: 'a',
  storeName: '울산점',
);

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> pumpHome(
    WidgetTester tester,
    Widget home,
    AuthSession session,
    double width,
  ) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    container.read(authSessionProvider.notifier).setSession(session);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: home),
      ),
    );
    await tester.pump();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Finder inRail(String text) => find.descendant(
    of: find.byType(NavigationRail),
    matching: find.text(text),
  );

  testWidgets('데스크톱: 사장은 레일의 엑셀 업로드로 화면을 연다', (tester) async {
    await pumpHome(tester, const AppShell(), owner(), 1000);

    expect(inRail('엑셀 업로드'), findsOneWidget);
    await tester.tap(inRail('엑셀 업로드'));
    await tester.pumpAndSettle();

    expect(find.byType(ExcelImportScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await dispose(tester);
  });

  testWidgets('데스크톱: 직원에게는 엑셀 업로드가 없다', (tester) async {
    await pumpHome(tester, const AppShell(), staff(), 1000);

    expect(inRail('엑셀 업로드'), findsNothing);

    await dispose(tester);
  });

  testWidgets('폰: 사장의 더보기에 엑셀 업로드가 있고 열린다', (tester) async {
    await pumpHome(tester, const MoreScreen(), owner(), 390);

    expect(find.text('엑셀 업로드'), findsOneWidget);
    await tester.tap(find.text('엑셀 업로드'));
    await tester.pumpAndSettle();

    expect(find.byType(ExcelImportScreen), findsOneWidget);

    await dispose(tester);
  });

  testWidgets('폰: 직원의 더보기에는 엑셀 업로드가 없다', (tester) async {
    await pumpHome(tester, const MoreScreen(), staff(), 390);

    expect(find.text('엑셀 업로드'), findsNothing);

    await dispose(tester);
  });
}
