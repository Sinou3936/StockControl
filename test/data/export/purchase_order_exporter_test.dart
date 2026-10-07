import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/export/purchase_order_exporter.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/domain/purchase_order.dart';

PurchaseOrder makeOrder() => PurchaseOrder(
  store: const Store(id: 'store-1', name: '울산점'),
  supplier: Supplier(id: 1, name: '가나다상사', createdAt: DateTime(2026, 10, 1)),
  date: DateTime(2026, 10, 7),
  lines: [
    PurchaseOrderLine(
      ingredient: Ingredient(
        id: 1,
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
        safetyStockQty: 5000,
        createdAt: DateTime(2026, 10, 1),
      ),
      qty: 2,
    ),
  ],
);

void main() {
  late List<({String fileName, Uint8List bytes, String mimeType})> calls;
  late int fontLoads;

  /// 저장 창은 가짜로, 글꼴은 파일에서 직접 읽는다.
  FilePurchaseOrderExporter makeExporter({Uri? result}) {
    calls = [];
    fontLoads = 0;
    return FilePurchaseOrderExporter(
      saveFile: ({required fileName, required bytes, required mimeType}) async {
        calls.add((fileName: fileName, bytes: bytes, mimeType: mimeType));
        return result;
      },
      loadFont: (path) async {
        fontLoads++;
        return ByteData.sublistView(File(path).readAsBytesSync());
      },
    );
  }

  test('PDF를 만들어 저장 창에 넘기고 Windows 경로를 돌려준다', () async {
    final saved = Uri.file('C:/docs/발주서.pdf');
    final exporter = makeExporter(result: saved);
    final order = makeOrder();

    final shown = await exporter.save(order, PurchaseOrderFormat.pdf);

    expect(shown, saved.toFilePath());
    expect(calls, hasLength(1));
    expect(calls.single.mimeType, 'application/pdf');
    expect(
      calls.single.fileName,
      purchaseOrderFileName(order, PurchaseOrderFormat.pdf),
    );
    expect(String.fromCharCodes(calls.single.bytes.take(4)), '%PDF');
    expect(fontLoads, 2);
  });

  test('엑셀은 글꼴을 읽지 않고 xlsx 파일을 넘긴다', () async {
    final exporter = makeExporter(result: Uri.file('C:/docs/발주서.xlsx'));

    await exporter.save(makeOrder(), PurchaseOrderFormat.xlsx);

    expect(
      calls.single.mimeType,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    // xlsx는 zip이라 PK로 시작한다.
    expect(String.fromCharCodes(calls.single.bytes.take(2)), 'PK');
    expect(fontLoads, 0);
  });

  test('저장 창을 취소하면 null이다', () async {
    final exporter = makeExporter(result: null);

    final shown = await exporter.save(makeOrder(), PurchaseOrderFormat.xlsx);

    expect(shown, isNull);
  });

  test('Android처럼 content 주소가 돌아오면 파일 이름만 보여준다', () async {
    final exporter = makeExporter(
      result: Uri.parse('content://com.android.providers/document/1'),
    );
    final order = makeOrder();

    final shown = await exporter.save(order, PurchaseOrderFormat.pdf);

    expect(shown, purchaseOrderFileName(order, PurchaseOrderFormat.pdf));
  });

  test('savedDisplayText는 취소면 null, file 주소면 경로, 그 밖은 이름이다', () {
    expect(savedDisplayText(null, 'a.pdf'), isNull);
    expect(
      savedDisplayText(Uri.file('C:/x/a.pdf'), 'a.pdf'),
      Uri.file('C:/x/a.pdf').toFilePath(),
    );
    expect(savedDisplayText(Uri.parse('content://x/1'), 'a.pdf'), 'a.pdf');
  });
}
