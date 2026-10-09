import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/l10n/app_locale.dart';

void main() {
  testWidgets('날짜 선택 달력과 뒤로 가기 말풍선이 한국어로 나온다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: appLocale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(leading: const BackButton()),
            body: TextButton(
              onPressed: () => showDatePicker(
                context: context,
                initialDate: DateTime(2026, 9, 29),
                firstDate: DateTime(2020),
                lastDate: DateTime(2026, 10, 9),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );

    // 기본 문구는 영어 "Back"이다. 한국어 설정이 있으면 "뒤로"가 된다.
    expect(find.byTooltip('뒤로'), findsOneWidget);

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('취소'), findsOneWidget);
    expect(find.text('확인'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('OK'), findsNothing);
  });
}
