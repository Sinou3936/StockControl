import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/export/purchase_order_pdf.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/domain/purchase_order.dart';

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

PurchaseOrder makeOrder(int lineCount) => PurchaseOrder(
  store: const Store(id: 'store-1', name: '울산점'),
  supplier: Supplier(
    id: 1,
    name: '가나다상사',
    contact: '010-1234-5678',
    createdAt: DateTime(2026, 10, 1),
  ),
  date: DateTime(2026, 10, 7),
  lines: [
    for (var i = 0; i < lineCount; i++)
      PurchaseOrderLine(ingredient: makeIngredient(i, '양파$i'), qty: i + 1),
  ],
);

ByteData readFont(String name) =>
    ByteData.sublistView(File('assets/fonts/$name').readAsBytesSync());

/// PDF 안의 쪽 수. 쪽 객체는 압축되지 않아서 글자로 읽어 셀 수 있다.
int pageCount(Uint8List bytes) => RegExp(
  r'/Type\s*/Page(?!s)',
).allMatches(String.fromCharCodes(bytes)).length;

Future<Uint8List> build(int lineCount) => buildPurchaseOrderPdf(
  makeOrder(lineCount),
  regularFont: readFont('NanumGothic-Regular.ttf'),
  boldFont: readFont('NanumGothic-Bold.ttf'),
);

void main() {
  test('한글 글꼴로 만든 PDF는 %PDF로 시작하고 비어 있지 않다', () async {
    final bytes = await build(3);

    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });

  test('줄이 적으면 한 쪽, 많으면 여러 쪽으로 나뉜다', () async {
    expect(pageCount(await build(3)), 1);
    expect(pageCount(await build(120)), greaterThan(1));
  });

  test('pubspec에 등록한 글꼴을 앱 번들에서 읽을 수 있다', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final regular = await rootBundle.load(
      'assets/fonts/NanumGothic-Regular.ttf',
    );
    final bold = await rootBundle.load('assets/fonts/NanumGothic-Bold.ttf');

    expect(regular.lengthInBytes, greaterThan(1000000));
    expect(bold.lengthInBytes, greaterThan(1000000));
  });
}
