import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/auth_providers.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/core/providers/store_providers.dart';
import 'package:stockcontrol/core/providers/sync_providers.dart';
import 'package:stockcontrol/core/shell/more_screen.dart';
import 'package:stockcontrol/core/theme/app_theme.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/data/repositories/store_repository.dart';
import 'package:stockcontrol/features/ingredient_management/ingredient_list_screen.dart';
import 'package:stockcontrol/features/store_management/store_management_screen.dart';
import 'package:stockcontrol/features/supplier_management/supplier_list_screen.dart';

import '../../support/corner_pixels.dart';
import '../../support/fake_store_gateway.dart';
import '../../support/fake_sync_controller.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Widget wrap() => ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: MoreScreen()),
      );

  testWidgets('메뉴 묶음 카드의 네 모서리에서 테두리가 끊기지 않는다', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: RepaintBoundary(
          key: boundaryKey,
          child: const MaterialApp(home: MoreScreen()),
        ),
      ),
    );
    await tester.pump();

    final groups = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_MenuGroup',
    );
    expect(groups, findsNWidgets(2));

    final pixels = await capturePixels(tester, boundaryKey);
    for (var g = 0; g < 2; g++) {
      final rect = tester.getRect(groups.at(g));
      for (final corner in CardCorner.values) {
        expectBorderColor(
          cornerArcColor(pixels, rect, corner),
          border: AppColors.border,
          fill: AppColors.surface,
          where: '묶음 $g ${corner.name}',
        );
      }
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('navigates to supplier management when tapped', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.tap(find.text('거래처 관리'));
    await tester.pumpAndSettle();

    expect(find.byType(SupplierListScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('navigates to ingredient management when tapped',
      (tester) async {
    await tester.pumpWidget(wrap());

    await tester.tap(find.text('품목 관리'));
    await tester.pumpAndSettle();

    expect(find.byType(IngredientListScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('logging out clears the auth session', (tester) async {
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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MoreScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('로그아웃'));
    await tester.pump();

    expect(container.read(authSessionProvider), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('shows store management for an owner and navigates to it',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        storeRepositoryProvider.overrideWithValue(
          StoreRepository(FakeStoreGateway(), db.storeDao),
        ),
      ],
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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MoreScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('매장 관리'));
    await tester.pumpAndSettle();

    expect(find.byType(StoreManagementScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('tapping 지금 동기화 runs a sync and shows the last synced time',
      (tester) async {
    late FakeSyncController fake;
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        syncControllerProvider.overrideWith((ref) {
          fake = FakeSyncController(
            ref,
            initial: SyncStatus(lastSyncedAt: DateTime(2026, 10, 4, 9, 5, 7)),
          );
          return fake;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MoreScreen()),
      ),
    );

    expect(find.text('마지막 동기화 09:05:07'), findsOneWidget);

    await tester.tap(find.text('지금 동기화'));
    await tester.pump();

    expect(fake.syncCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('shows the sync error message and disables the tile while '
      'syncing', (tester) async {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        syncControllerProvider.overrideWith(
          (ref) => FakeSyncController(
            ref,
            initial: const SyncStatus(errorMessage: '서버에 연결할 수 없습니다'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MoreScreen()),
      ),
    );

    expect(find.text('서버에 연결할 수 없습니다'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
