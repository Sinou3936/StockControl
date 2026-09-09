import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/features/auth/add_staff_screen.dart';

void main() {
  testWidgets('shows an error when name or pin is missing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AddStaffScreen()),
      ),
    );

    await tester.tap(find.text('추가'));
    await tester.pump();

    expect(find.text('이름과 6자리 PIN을 입력하세요'), findsOneWidget);
  });
}
