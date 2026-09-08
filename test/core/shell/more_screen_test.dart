import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/core/shell/more_screen.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/features/ingredient_management/ingredient_list_screen.dart';
import 'package:stockcontrol/features/supplier_management/supplier_list_screen.dart';

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
}
