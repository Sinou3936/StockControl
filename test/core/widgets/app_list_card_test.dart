import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/theme/app_theme.dart';
import 'package:stockcontrol/core/widgets/app_widgets.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    Widget? trailing,
    VoidCallback? onTap,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppListCard(title: '양파', trailing: trailing, onTap: onTap),
      ),
    ),
  );

  testWidgets('onTap을 넘기면 눌린다는 chevron이 하나 보인다', (tester) async {
    await pumpCard(tester, onTap: () {});

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.chevron_right));
    expect(icon.size, 20);
    expect(icon.color, AppColors.textMuted);
  });

  testWidgets('onTap을 넘기지 않으면 chevron이 없다', (tester) async {
    await pumpCard(tester);

    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('trailing과 onTap이 둘 다 있으면 둘 다 보인다', (tester) async {
    await pumpCard(tester, trailing: const InfoChip('유통기한 관리'), onTap: () {});

    expect(find.text('유통기한 관리'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('trailing만 있고 onTap이 없으면 trailing만 보인다', (tester) async {
    await pumpCard(tester, trailing: const InfoChip('유통기한 관리'));

    expect(find.text('유통기한 관리'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });
}
