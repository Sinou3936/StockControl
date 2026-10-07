import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/data/export/purchase_order_exporter.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/domain/purchase_order.dart';
import 'package:stockcontrol/domain/stock_shortage.dart';
import 'package:stockcontrol/features/purchase_order/purchase_order_screen.dart';

const ulsan = Store(id: 'store-1', name: '울산점');

Ingredient makeIngredient(int id, String name) => Ingredient(
  id: id,
  name: name,
  baseUnit: 'g',
  purchaseUnit: '박스',
  conversionFactor: 20000,
  isExpiryTracked: false,
  safetyStockQty: 5000,
  createdAt: DateTime(2026, 10, 1),
);

StockShortage makeShortage(int id, String name, {double current = 1200}) =>
    StockShortage(
      ingredient: makeIngredient(id, name),
      store: ulsan,
      currentQty: current,
    );

/// 저장 요청을 기록만 하는 가짜.
class FakeExporter implements PurchaseOrderExporter {
  final saved = <({PurchaseOrder order, PurchaseOrderFormat format})>[];
  Future<String?> Function()? onSave;
  String? result = '저장위치/발주서.pdf';

  @override
  Future<String?> save(PurchaseOrder order, PurchaseOrderFormat format) async {
    saved.add((order: order, format: format));
    final handler = onSave;
    if (handler != null) return handler();
    return result;
  }
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(
        name: '가나다상사',
        contact: const Value('010-1234-5678'),
      ),
    );
  });

  tearDown(() => db.close());

  Future<FakeExporter> pumpScreen(
    WidgetTester tester, {
    List<StockShortage>? shortages,
  }) async {
    final exporter = FakeExporter();
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          purchaseOrderExporterProvider.overrideWithValue(exporter),
        ],
        child: MaterialApp(
          home: PurchaseOrderScreen(
            store: ulsan,
            shortages:
                shortages ??
                [makeShortage(1, '양파'), makeShortage(2, '당근', current: 0)],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return exporter;
  }

  Future<void> disposeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> pickSupplier(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(const Key('supplierDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  VoidCallback? onPressed(WidgetTester tester, String key) =>
      tester.widget<FilledButton>(find.byKey(Key(key))).onPressed;

  String qtyText(WidgetTester tester, int id) =>
      tester.widget<TextField>(find.byKey(Key('qty_$id'))).controller!.text;

  testWidgets('열면 수량이 부족분을 구매 단위로 올린 값으로 채워져 있다', (tester) async {
    await pumpScreen(tester);

    // 양파: 3,800g 부족 → 1박스, 당근: 5,000g 부족 → 1박스
    expect(qtyText(tester, 1), '1');
    expect(qtyText(tester, 2), '1');

    await disposeScreen(tester);
  });

  testWidgets('거래처를 고르기 전에는 저장 버튼이 눌리지 않는다', (tester) async {
    await pumpScreen(tester);

    expect(onPressed(tester, 'savePdfButton'), isNull);
    expect(onPressed(tester, 'saveXlsxButton'), isNull);

    await pickSupplier(tester, '가나다상사');

    expect(onPressed(tester, 'savePdfButton'), isNotNull);
    expect(onPressed(tester, 'saveXlsxButton'), isNotNull);

    await disposeScreen(tester);
  });

  testWidgets('고친 수량과 고른 거래처가 발주서에 담겨 저장된다', (tester) async {
    final exporter = await pumpScreen(tester);
    await pickSupplier(tester, '가나다상사');

    await tester.enterText(find.byKey(const Key('qty_1')), '3');
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveXlsxButton')));
    await tester.pump();

    final call = exporter.saved.single;
    expect(call.format, PurchaseOrderFormat.xlsx);
    expect(call.order.store.id, 'store-1');
    expect(call.order.supplier.name, '가나다상사');
    expect(call.order.lines.map((l) => (l.ingredient.name, l.qty)).toList(), [
      ('양파', 3),
      ('당근', 1),
    ]);

    await disposeScreen(tester);
  });

  testWidgets('PDF 저장 버튼은 PDF 형식으로 저장을 요청한다', (tester) async {
    final exporter = await pumpScreen(tester);
    await pickSupplier(tester, '가나다상사');

    await tester.tap(find.byKey(const Key('savePdfButton')));
    await tester.pump();

    expect(exporter.saved.single.format, PurchaseOrderFormat.pdf);

    await disposeScreen(tester);
  });

  testWidgets('체크를 해제한 품목은 발주서에서 빠진다', (tester) async {
    final exporter = await pumpScreen(tester);
    await pickSupplier(tester, '가나다상사');

    await tester.tap(find.byKey(const Key('check_2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('savePdfButton')));
    await tester.pump();

    expect(exporter.saved.single.order.lines.map((l) => l.ingredient.name), [
      '양파',
    ]);

    await disposeScreen(tester);
  });

  testWidgets('수량을 0으로 하면 그 줄이 빠지고, 모두 0이면 저장할 수 없다', (tester) async {
    final exporter = await pumpScreen(tester);
    await pickSupplier(tester, '가나다상사');

    await tester.enterText(find.byKey(const Key('qty_1')), '0');
    await tester.pump();
    await tester.tap(find.byKey(const Key('savePdfButton')));
    await tester.pump();
    expect(exporter.saved.single.order.lines.map((l) => l.ingredient.name), [
      '당근',
    ]);

    await tester.enterText(find.byKey(const Key('qty_2')), '0');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(onPressed(tester, 'savePdfButton'), isNull);
    expect(onPressed(tester, 'saveXlsxButton'), isNull);

    await disposeScreen(tester);
  });

  testWidgets('수량칸에는 숫자가 아닌 글자가 들어가지 않고 그 줄은 빠진다', (tester) async {
    final exporter = await pumpScreen(tester);
    await pickSupplier(tester, '가나다상사');

    await tester.enterText(find.byKey(const Key('qty_1')), 'abc');
    await tester.pump();

    expect(qtyText(tester, 1), '');
    await tester.tap(find.byKey(const Key('savePdfButton')));
    await tester.pump();
    expect(exporter.saved.single.order.lines.map((l) => l.ingredient.name), [
      '당근',
    ]);

    await disposeScreen(tester);
  });

  testWidgets('수량칸은 5자리까지만 받는다', (tester) async {
    final exporter = await pumpScreen(tester);
    await pickSupplier(tester, '가나다상사');

    // 19자리를 넘는 수는 int로 읽히지 않아 그 줄이 파일에서 조용히 빠진다.
    // 화면에는 체크된 채 숫자가 보이므로, 입력 자체를 5자리로 막는다.
    await tester.enterText(
      find.byKey(const Key('qty_1')),
      '1234567890123456789012345',
    );
    await tester.pump();

    expect(qtyText(tester, 1), '12345');
    await tester.tap(find.byKey(const Key('savePdfButton')));
    await tester.pump();
    expect(
      exporter.saved.single.order.lines
          .map((l) => (l.ingredient.name, l.qty))
          .toList(),
      [('양파', 12345), ('당근', 1)],
    );

    await disposeScreen(tester);
  });

  testWidgets('거래처가 하나도 없으면 먼저 등록하라고 안내한다', (tester) async {
    await db.delete(db.suppliers).go();

    await pumpScreen(tester);

    expect(find.text('거래처 관리에서 거래처를 먼저 등록하세요'), findsOneWidget);
    expect(find.byKey(const Key('supplierDropdown')), findsNothing);
    expect(onPressed(tester, 'savePdfButton'), isNull);

    await disposeScreen(tester);
  });

  testWidgets('부족한 품목이 없으면 안내만 보이고 저장 버튼은 없다', (tester) async {
    await pumpScreen(tester, shortages: const []);

    expect(find.text('부족한 품목이 없습니다'), findsOneWidget);
    expect(find.byKey(const Key('savePdfButton')), findsNothing);

    await disposeScreen(tester);
  });

  testWidgets('열어 둔 동안 재고가 바뀌어도 입력한 수량이 덮이지 않는다', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.byKey(const Key('qty_1')), '7');
    await tester.pump();

    // 같은 매장의 재고를 충분히 채운다. 부족 목록을 계속 지켜보는 화면이었다면
    // 이 변경으로 줄이 사라지거나 수량이 제안값으로 되돌아간다.
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-1', name: '울산점'),
    );
    final ingredientId = await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
        safetyStockQty: const Value(5000),
      ),
    );
    await db.lotDao.insertLot(
      LotsCompanion.insert(
        ingredientId: ingredientId,
        storeId: const Value('store-1'),
        receivedDate: DateTime(2026, 10, 1),
        unitCost: 10,
        remainingQty: 99999,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('qty_1')), findsOneWidget);
    expect(qtyText(tester, 1), '7');

    await disposeScreen(tester);
  });

  testWidgets('저장하면 저장했다는 메시지가 보인다', (tester) async {
    final exporter = await pumpScreen(tester);
    exporter.result = 'C:\\문서\\발주서.pdf';
    await pickSupplier(tester, '가나다상사');

    await tester.tap(find.byKey(const Key('savePdfButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('저장했습니다: C:\\문서\\발주서.pdf'), findsOneWidget);

    await disposeScreen(tester);
  });

  testWidgets('저장 창을 취소하면 아무 메시지도 뜨지 않는다', (tester) async {
    final exporter = await pumpScreen(tester);
    exporter.result = null;
    await pickSupplier(tester, '가나다상사');

    await tester.tap(find.byKey(const Key('savePdfButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);

    await disposeScreen(tester);
  });

  testWidgets('저장이 실패하면 이유를 보여주고 다시 시도할 수 있다', (tester) async {
    final exporter = await pumpScreen(tester);
    exporter.onSave = () async => throw StateError('디스크가 가득 찼습니다');
    await pickSupplier(tester, '가나다상사');

    await tester.tap(find.byKey(const Key('savePdfButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('저장하지 못했습니다'), findsOneWidget);
    expect(onPressed(tester, 'savePdfButton'), isNotNull);

    await disposeScreen(tester);
  });

  testWidgets('저장하는 동안 다시 눌러도 한 번만 저장한다', (tester) async {
    final exporter = await pumpScreen(tester);
    final done = Completer<String?>();
    exporter.onSave = () => done.future;
    await pickSupplier(tester, '가나다상사');

    await tester.tap(find.byKey(const Key('savePdfButton')));
    await tester.pump();

    // 끝나기 전에는 두 버튼 모두 눌리지 않는다.
    expect(onPressed(tester, 'savePdfButton'), isNull);
    expect(onPressed(tester, 'saveXlsxButton'), isNull);
    expect(exporter.saved, hasLength(1));

    done.complete('발주서.pdf');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(onPressed(tester, 'savePdfButton'), isNotNull);
    expect(exporter.saved, hasLength(1));

    await disposeScreen(tester);
  });
}
