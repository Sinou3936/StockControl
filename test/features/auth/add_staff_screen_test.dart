import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/features/auth/add_staff_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Widget wrap() => ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: AddStaffScreen()),
      );

  testWidgets('shows an error when name, pin, or store is missing',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.tap(find.text('추가'));
    await tester.pump();

    expect(find.text('이름, 6자리 PIN, 매장을 모두 입력하세요'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('shows seeded stores in the dropdown', (tester) async {
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-1', name: '울산점'),
    );

    await tester.pumpWidget(wrap());
    await tester.pump();

    final dropdown = tester.widget<DropdownButton<Store>>(
      find.byKey(const Key('newStaffStoreDropdown')),
    );
    expect(dropdown.items, hasLength(1));
    expect(dropdown.items!.first.value!.name, '울산점');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
