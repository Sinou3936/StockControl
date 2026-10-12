import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:excel/excel.dart' show Excel;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/auth_providers.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/core/providers/store_providers.dart';
import 'package:stockcontrol/core/theme/app_theme.dart';
import 'package:stockcontrol/data/import/import_file_gateway.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/features/excel_import/excel_import_screen.dart';

import '../../support/import_test_files.dart';

/// 파일 선택·양식 저장을 기록만 하는 가짜.
class FakeGateway implements ImportFileGateway {
  final savedTemplates = <Uint8List>[];
  String? saveResult = '저장위치/양식.xlsx';
  Uint8List? nextFile;

  @override
  Future<String?> saveTemplate(Uint8List bytes) async {
    savedTemplates.add(bytes);
    return saveResult;
  }

  @override
  Future<Uint8List?> pickWorkbook() async => nextFile;
}

const ulsan = Store(id: 'a', name: '울산점');

Uint8List goodFile() => xlsx(
  suppliers: [
    ['가나다상사', null],
  ],
  ingredients: [
    ['쌀 20KG', 'g', '포', 20000, null, '아니오'],
  ],
  inbound: [
    ['2026-09-29', '가나다상사', '쌀 20KG', 2, 45000, null],
  ],
);

void main() {
  late AppDatabase db;
  late FakeGateway gateway;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    gateway = FakeGateway();
    await db.storeDao.upsertStore(StoresCompanion.insert(id: 'a', name: '울산점'));
  });

  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester, {
    Store? store = ulsan,
    double width = 800,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          importFileGatewayProvider.overrideWithValue(gateway),
          authSessionProvider.overrideWith(
            (ref) => AuthSessionNotifier()
              ..setSession(
                AuthSession(
                  id: 'owner',
                  email: 'owner@internal.local',
                  pin: '123456',
                  displayName: '사장님',
                  role: 'owner',
                ),
              ),
          ),
          selectedStoreProvider.overrideWith((ref) => store),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ExcelImportScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// 파일을 고르고(가짜) 미리보기가 나올 때까지 기다린다.
  Future<void> pick(WidgetTester tester, Uint8List? bytes) async {
    gateway.nextFile = bytes;
    await tester.tap(find.byKey(const Key('pickFileButton')));
    await tester.pumpAndSettle();
  }

  testWidgets('양식 받기는 저장 함수에 네 시트짜리 파일을 넘기고 저장 위치를 안내한다', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('templateButton')));
    await tester.pumpAndSettle();

    final excel = Excel.decodeBytes(gateway.savedTemplates.single);
    expect(excel.tables.keys.toList(), ['안내', '거래처', '품목', '입고']);
    expect(find.text('저장했습니다: 저장위치/양식.xlsx'), findsOneWidget);

    await dispose(tester);
  });

  testWidgets('양식 저장 창을 취소하면 안내가 나오지 않는다', (tester) async {
    gateway.saveResult = null;
    await pump(tester);

    await tester.tap(find.byKey(const Key('templateButton')));
    await tester.pumpAndSettle();

    expect(gateway.savedTemplates, hasLength(1));
    expect(find.textContaining('저장했습니다'), findsNothing);

    await dispose(tester);
  });

  testWidgets('매장을 고르지 않았으면 안내만 나온다', (tester) async {
    await pump(tester, store: null);

    expect(find.text('매장을 선택해주세요'), findsOneWidget);
    expect(find.byKey(const Key('pickFileButton')), findsNothing);
    expect(find.byKey(const Key('templateButton')), findsNothing);

    await dispose(tester);
  });

  testWidgets('정상 파일은 미리보기에 요약과 환산 결과를 보여 준다', (tester) async {
    await pump(tester);
    await pick(tester, goodFile());

    final summary = find.byKey(const Key('previewSummary'));
    expect(
      find.descendant(of: summary, matching: find.text('새 거래처 1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('새 품목 1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('입고 1건')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('단가 없음 0건')),
      findsOneWidget,
    );
    expect(find.text('입고 날짜 2026-09-29 ~ 2026-09-29'), findsOneWidget);
    expect(find.text('쌀 20KG · 2포 × 20,000 = 40,000g'), findsOneWidget);
    expect(find.byKey(const Key('commitButton')), findsOneWidget);
    expect(find.byKey(const Key('errorList')), findsNothing);
    // 미리보기만으로는 아무것도 저장되지 않는다.
    expect(await db.select(db.lots).get(), isEmpty);

    await dispose(tester);
  });

  testWidgets('미리보기에 올릴 매장 이름과 새로 만들어질 거래처·품목 이름이 보인다', (tester) async {
    await pump(tester);
    await pick(tester, goodFile());

    final summary = find.byKey(const Key('previewSummary'));
    expect(
      find.descendant(of: summary, matching: find.text('매장 울산점')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('새 거래처: 가나다상사')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('새 품목: 쌀 20KG')),
      findsOneWidget,
    );

    await dispose(tester);
  });

  testWidgets('새 이름이 많으면 앞의 10개만 보이고 나머지는 외 N개', (tester) async {
    await pump(tester);
    await pick(
      tester,
      xlsx(
        suppliers: [
          for (var i = 1; i <= 12; i++) ['거래처$i', null],
        ],
      ),
    );

    final summary = find.byKey(const Key('previewSummary'));
    expect(
      find.descendant(of: summary, matching: find.textContaining('거래처10')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.textContaining('거래처11')),
      findsNothing,
    );
    expect(
      find.descendant(of: summary, matching: find.textContaining('외 2개')),
      findsOneWidget,
    );

    await dispose(tester);
  });

  testWidgets('결과 안내에도 어느 매장에 올렸는지 적힌다', (tester) async {
    await pump(tester);
    await pick(tester, goodFile());

    await tester.tap(find.byKey(const Key('commitButton')));
    await tester.pumpAndSettle();

    expect(find.textContaining('울산점에'), findsOneWidget);

    await dispose(tester);
  });

  testWidgets('올리기를 누르면 저장되고 화면이 닫히지 않은 채 결과가 나온다', (tester) async {
    await pump(tester);
    await pick(tester, goodFile());

    await tester.tap(find.byKey(const Key('commitButton')));
    await tester.pumpAndSettle();

    final lots = await db.select(db.lots).get();
    expect(lots, hasLength(1));
    expect(lots.single.storeId, 'a');
    expect(find.byKey(const Key('resultCard')), findsOneWidget);
    expect(find.textContaining('입고 1건을 등록했습니다'), findsOneWidget);
    // 탭 화면처럼 pop 하지 않는다.
    expect(find.byType(ExcelImportScreen), findsOneWidget);
    expect(find.byKey(const Key('pickFileButton')), findsOneWidget);
    expect(find.byKey(const Key('previewSummary')), findsNothing);

    await dispose(tester);
  });

  testWidgets('오류 파일은 줄 번호와 이유를 보여 주고 올리기가 없다', (tester) async {
    await pump(tester);
    await pick(
      tester,
      xlsx(
        ingredients: [
          ['쌀', 'g', '포', 20000, null, '아니오'],
        ],
        inbound: [
          ['2026-09-29', '모르는거래처', '쌀', 2, 45000, null],
        ],
      ),
    );

    expect(find.byKey(const Key('errorList')), findsOneWidget);
    expect(find.textContaining('입고 시트 2번째 줄: 거래처 "모르는거래처"'), findsOneWidget);
    expect(find.byKey(const Key('commitButton')), findsNothing);
    expect(await db.select(db.lots).get(), isEmpty);

    await tester.tap(find.byKey(const Key('anotherFileButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pickFileButton')), findsOneWidget);
    expect(find.byKey(const Key('errorList')), findsNothing);

    await dispose(tester);
  });

  testWidgets('오류가 50개를 넘으면 외 N개로 줄여 보여 준다', (tester) async {
    await pump(tester);
    await pick(
      tester,
      xlsx(
        ingredients: [
          ['쌀', 'g', '포', 20000, null, '아니오'],
        ],
        inbound: [
          for (var i = 0; i < 55; i++)
            ['2026-09-29', '모르는거래처', '쌀', 2, 45000, null],
        ],
      ),
    );

    expect(find.text('외 5개'), findsOneWidget);
    expect(find.textContaining('입고 시트'), findsNWidgets(50));

    await dispose(tester);
  });

  testWidgets('같은 파일을 다시 올리면 중복 의심이 나오고 체크해야 올리기가 켜진다', (tester) async {
    await pump(tester);
    await pick(tester, goodFile());
    await tester.tap(find.byKey(const Key('commitButton')));
    await tester.pumpAndSettle();

    await pick(tester, goodFile());

    expect(find.byKey(const Key('duplicateList')), findsOneWidget);
    expect(find.textContaining('입고 시트 2번째 줄 · 쌀 20KG'), findsOneWidget);
    FilledButton commit() =>
        tester.widget<FilledButton>(find.byKey(const Key('commitButton')));
    expect(commit().onPressed, isNull);

    await tester.tap(find.byKey(const Key('duplicateConfirm')));
    await tester.pump();
    expect(commit().onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('commitButton')));
    await tester.pumpAndSettle();
    expect(await db.select(db.lots).get(), hasLength(2));

    await dispose(tester);
  });

  testWidgets('매장을 바꾸면 이전 매장 기준의 미리보기가 사라진다', (tester) async {
    await db.storeDao.upsertStore(StoresCompanion.insert(id: 'b', name: '부산점'));
    await pump(tester);
    await pick(tester, goodFile());
    expect(find.byKey(const Key('previewSummary')), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ExcelImportScreen)),
    );
    container.read(selectedStoreProvider.notifier).state = const Store(
      id: 'b',
      name: '부산점',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('previewSummary')), findsNothing);
    expect(find.byKey(const Key('pickFileButton')), findsOneWidget);

    await dispose(tester);
  });

  testWidgets('엑셀이 아닌 파일은 안내만 나오고 미리보기가 없다', (tester) async {
    await pump(tester);
    await pick(tester, Uint8List.fromList([1, 2, 3]));

    expect(find.textContaining('엑셀 파일(.xlsx)을 읽을 수 없습니다'), findsOneWidget);
    expect(find.byKey(const Key('previewSummary')), findsNothing);
    expect(find.byKey(const Key('pickFileButton')), findsOneWidget);

    await dispose(tester);
  });

  testWidgets('파일 선택 창을 취소하면 아무 변화가 없다', (tester) async {
    await pump(tester);
    await pick(tester, null);

    expect(find.byKey(const Key('previewSummary')), findsNothing);
    expect(find.byKey(const Key('errorList')), findsNothing);
    expect(find.byKey(const Key('pickFileButton')), findsOneWidget);

    await dispose(tester);
  });

  testWidgets('단가 없음과 유통기한 무시 건수를 알려 준다', (tester) async {
    await pump(tester);
    await pick(
      tester,
      xlsx(
        suppliers: [
          ['가나다상사', null],
        ],
        ingredients: [
          ['쌀', 'g', '포', 20000, null, '아니오'],
        ],
        inbound: [
          ['2026-09-29', '가나다상사', '쌀', 2, null, '2026-10-05'],
        ],
      ),
    );

    expect(find.text('단가 없음 1건'), findsOneWidget);
    expect(find.text('유통기한 무시 1건'), findsOneWidget);

    await dispose(tester);
  });

  testWidgets('폭 320에서 긴 이름과 긴 오류 문구가 넘치지 않는다', (tester) async {
    const longName = '아주아주아주 긴 이름의 품목 20KG(햅쌀,국내산)(특등급)';
    await pump(tester, width: 320);
    await pick(
      tester,
      xlsx(
        suppliers: [
          ['가나다상사', null],
        ],
        ingredients: [
          [longName, 'g', '포', 20000, null, '아니오'],
        ],
        inbound: [
          ['2026-09-29', '가나다상사', longName, 2, 45000, null],
        ],
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('anotherFileButton')));
    await tester.pumpAndSettle();
    await pick(
      tester,
      xlsx(
        inbound: [
          [
            '2026-09-29',
            '매우매우매우 긴 이름의 모르는 거래처 가나다상사본점',
            longName,
            2,
            45000,
            null,
          ],
        ],
      ),
    );
    expect(find.byKey(const Key('errorList')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await dispose(tester);
  });
}
