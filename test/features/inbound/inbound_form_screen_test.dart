import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/features/inbound/inbound_form_screen.dart';

void main() {
  testWidgets('shows validation errors when required fields are empty',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: InboundFormScreen()),
      ),
    );

    await tester.tap(find.text('저장'));
    await tester.pump();

    expect(find.text('수량을 입력하세요'), findsOneWidget);
    expect(find.text('단가를 입력하세요'), findsOneWidget);

    // Drift의 watch() 스트림이 구독 취소 시 예약하는 정리용 타이머(0초 지연)가
    // 테스트 종료 시점까지 남아있지 않도록, 위젯을 교체해 dispose를 유도한 뒤
    // duration을 준 pump()로 가짜 시계를 흘려보내 그 타이머를 실행시킨다.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
