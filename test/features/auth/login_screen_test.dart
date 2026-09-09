import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/auth_providers.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/data/repositories/auth_repository.dart';
import 'package:stockcontrol/domain/pin_hash.dart';
import 'package:stockcontrol/features/auth/login_screen.dart';

import '../../support/fake_auth_gateway.dart';

void main() {
  late AppDatabase db;
  late FakeAuthGateway gateway;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    gateway = FakeAuthGateway(throwNetworkError: true);

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(
          AuthRepository(gateway, db.cachedProfileDao),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  Widget wrap() => UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LoginScreen()),
      );

  testWidgets('logs in with the correct pin and sets the auth session',
      (tester) async {
    await db.cachedProfileDao.upsertProfile(
      CachedProfilesCompanion.insert(
        id: 'user-1',
        displayName: '사장님',
        role: 'owner',
        email: 'owner@internal.local',
        pinHash: hashPin('123456', 'salt'),
        pinSalt: 'salt',
      ),
    );

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.text('사장님'), findsOneWidget);

    await tester.tap(find.text('사장님'));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('pinField')), '123456');
    await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
    await tester.pump();
    await tester.pump();

    expect(container.read(authSessionProvider)?.displayName, '사장님');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('shows an error and does not set a session for a wrong pin',
      (tester) async {
    await db.cachedProfileDao.upsertProfile(
      CachedProfilesCompanion.insert(
        id: 'user-1',
        displayName: '사장님',
        role: 'owner',
        email: 'owner@internal.local',
        pinHash: hashPin('123456', 'salt'),
        pinSalt: 'salt',
      ),
    );

    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.tap(find.text('사장님'));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('pinField')), '000000');
    await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
    await tester.pump();
    await tester.pump();

    expect(find.text('PIN이 올바르지 않습니다'), findsOneWidget);
    expect(container.read(authSessionProvider), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
      'logs in via manual email entry when the device has no cached '
      'profiles yet (first login on a new device)', (tester) async {
    // 이 테스트만 온라인 성공 시나리오라 별도의 가짜 게이트웨이를 쓴다
    // (바깥 setUp의 컨테이너는 네트워크 오류만 내는 게이트웨이를 쓰고 있음).
    final onlineGateway = FakeAuthGateway()
      ..seedUser(
        id: 'user-9',
        email: 'owner@internal.local',
        password: '123456',
        displayName: '사장님',
        role: 'owner',
      );

    final onlineContainer = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(
          AuthRepository(onlineGateway, db.cachedProfileDao),
        ),
      ],
    );
    addTearDown(onlineContainer.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: onlineContainer,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('manualEntryButton')));
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('emailField')),
      'owner@internal.local',
    );
    await tester.enterText(find.byKey(const Key('manualPinField')), '123456');
    await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
    await tester.pump();
    await tester.pump();

    expect(onlineContainer.read(authSessionProvider)?.displayName, '사장님');

    final cached = await db.cachedProfileDao.getById('user-9');
    expect(cached, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
