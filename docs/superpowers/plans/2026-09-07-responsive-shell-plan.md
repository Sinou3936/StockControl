# 반응형 네비게이션 셸 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 화면 너비 600px을 기준으로 데스크톱(사이드바)/모바일(하단 탭) 레이아웃을 자동 전환하는 `AppShell`을 추가하고, 버튼만 있던 기존 `HomeScreen`을 대체한다.

**Architecture:** `AppShell`이 `MediaQuery`로 너비를 읽어 `NavigationRail`(데스크톱) 또는 `BottomNavigationBar`(모바일) 중 하나를 그린다. 탭 전환은 `IndexedStack`으로 처리해 화면을 오갈 때 폼 입력값이 유지되게 한다. 모바일의 "더보기"는 탭 상태를 바꾸지 않고 `MoreScreen`을 위로 띄운다.

**Tech Stack:** Flutter (기존 스택 그대로, 신규 의존성 없음)

---

### Task 1: 모바일 "더보기" 화면

**Files:**
- Create: `lib/core/shell/more_screen.dart`
- Test: `test/core/shell/more_screen_test.dart`

- [ ] **Step 1: 실패하는 위젯 테스트 작성**

`test/core/shell/more_screen_test.dart`:
```dart
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
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/core/shell/more_screen_test.dart`
Expected: FAIL — `lib/core/shell/more_screen.dart` 파일이 없어 컴파일 에러

- [ ] **Step 3: 화면 구현**

`lib/core/shell/more_screen.dart`:
```dart
import 'package:flutter/material.dart';

import '../../features/ingredient_management/ingredient_list_screen.dart';
import '../../features/supplier_management/supplier_list_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('더보기')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('거래처 관리'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SupplierListScreen()),
            ),
          ),
          ListTile(
            title: const Text('품목 관리'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const IngredientListScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/core/shell/more_screen_test.dart`
Expected: PASS (2 tests passed)

- [ ] **Step 5: Commit**

```bash
git add lib/core/shell/more_screen.dart test/core/shell/more_screen_test.dart
git commit -m "feat: add mobile more screen"
```

---

### Task 2: AppShell — 반응형 레이아웃 분기

**Files:**
- Create: `lib/core/shell/app_shell.dart`
- Test: `test/core/shell/app_shell_test.dart`

- [ ] **Step 1: 실패하는 위젯 테스트 작성**

`test/core/shell/app_shell_test.dart`:
```dart
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
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/core/shell/app_shell_test.dart`
Expected: FAIL — `lib/core/shell/app_shell.dart` 파일이 없어 컴파일 에러

- [ ] **Step 3: 화면 구현**

`lib/core/shell/app_shell.dart`:
```dart
import 'package:flutter/material.dart';

import '../../features/count/count_screen.dart';
import '../../features/ingredient_management/ingredient_list_screen.dart';
import '../../features/inbound/inbound_form_screen.dart';
import '../../features/stock_overview/stock_overview_screen.dart';
import '../../features/supplier_management/supplier_list_screen.dart';
import 'more_screen.dart';

const _kDesktopBreakpoint = 600.0;

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const _primaryScreens = [
    StockOverviewScreen(),
    InboundFormScreen(),
    CountScreen(),
  ];

  static const _desktopExtraScreens = [
    SupplierListScreen(),
    IngredientListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= _kDesktopBreakpoint;
    return isDesktop ? _buildDesktop() : _buildMobile();
  }

  Widget _buildDesktop() {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                label: Text('재고 조회'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.input),
                label: Text('입고 등록'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.fact_check_outlined),
                label: Text('마감 실사'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.store_outlined),
                label: Text('거래처 관리'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.category_outlined),
                label: Text('품목 관리'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                ..._primaryScreens,
                ..._desktopExtraScreens,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile() {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _primaryScreens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MoreScreen()),
            );
            return;
          }
          setState(() => _selectedIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: '재고',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.input), label: '입고'),
          BottomNavigationBarItem(
            icon: Icon(Icons.fact_check_outlined),
            label: '실사',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: '더보기',
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/core/shell/app_shell_test.dart`
Expected: PASS (3 tests passed)

- [ ] **Step 5: Commit**

```bash
git add lib/core/shell/app_shell.dart test/core/shell/app_shell_test.dart
git commit -m "feat: add responsive AppShell with desktop rail and mobile bottom nav"
```

---

### Task 3: main.dart 연결 + 기존 홈 화면 제거

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: main.dart를 AppShell로 교체**

`lib/main.dart` 전체를 아래 내용으로 교체:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/shell/app_shell.dart';

void main() {
  runApp(const ProviderScope(child: StockControlApp()));
}

class StockControlApp extends StatelessWidget {
  const StockControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '재고관리',
      home: const AppShell(),
    );
  }
}
```

(버튼 6개짜리 `HomeScreen` 클래스는 완전히 삭제한다 — `AppShell`이 그 역할을 대체한다)

- [ ] **Step 2: 정적 분석 확인**

Run: `flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 3: 전체 테스트 스위트 실행**

Run: `flutter test`
Expected: PASS — 이번 스펙에서 추가한 테스트(더보기 화면 2개, AppShell 3개)를 포함해 전부 통과

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: replace home screen with responsive AppShell"
```

---

## Self-Review 결과

**스펙 커버리지**: 600px 기준 반응형 분기 — Task 2(`_kDesktopBreakpoint`) / 데스크톱 5개 목적지 사이드바 — Task 2 `_buildDesktop` / 모바일 4개 하단탭 + 더보기 — Task 2 `_buildMobile` / 더보기가 탭 상태를 안 바꾸고 화면만 띄움 — Task 2(`onTap`의 `index == 3` 분기, `_selectedIndex`를 안 바꿈) / IndexedStack으로 상태 유지 — Task 2 세 번째 테스트로 검증 / 홈 화면 제거, 재고 조회가 기본 화면 — Task 3 / 범위 밖 항목(탭 기억, 서버 동기화, 안전재고 알림) — 이번 계획에 포함하지 않음, 스펙과 일치.

**타입 일관성 확인**: `AppShell`(무인자 생성자)이 Task 3의 `main.dart`에서 `home: const AppShell()`로 정확히 사용됨. `MoreScreen`(무인자 생성자)이 Task 2의 `app_shell.dart`(`import 'more_screen.dart'`)와 Task 1의 정의가 일치. `_primaryScreens`/`_desktopExtraScreens`의 화면 순서(재고조회·입고등록·마감실사·거래처관리·품목관리)가 데스크톱 `NavigationRailDestination` 5개 순서, 모바일 `BottomNavigationBarItem` 앞 3개 순서와 정확히 대응됨 — 인덱스가 어긋나면 탭과 화면이 안 맞으므로 이 순서 일치가 중요하다.
