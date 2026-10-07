import 'package:excel/excel.dart' show Data, Excel, IntCellValue, TextCellValue;
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/export/purchase_order_xlsx.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/domain/purchase_order.dart';

Ingredient makeIngredient(int id, String name, String purchaseUnit) =>
    Ingredient(
      id: id,
      name: name,
      baseUnit: 'g',
      purchaseUnit: purchaseUnit,
      conversionFactor: 20000,
      isExpiryTracked: false,
      safetyStockQty: 5000,
      createdAt: DateTime(2026, 10, 1),
    );

PurchaseOrder makeOrder({String? contact = '010-1234-5678'}) => PurchaseOrder(
  store: const Store(id: 'store-1', name: '울산점'),
  supplier: Supplier(
    id: 1,
    name: '가나다상사',
    contact: contact,
    createdAt: DateTime(2026, 10, 1),
  ),
  date: DateTime(2026, 10, 7),
  lines: [
    PurchaseOrderLine(ingredient: makeIngredient(1, '양파', '박스'), qty: 2),
    PurchaseOrderLine(ingredient: makeIngredient(2, '대파', '단'), qty: 10),
  ],
);

/// 셀의 글자. TextCellValue.value는 문자열이 아니라 TextSpan이라 .text로
/// 꺼내야 한다. toString()을 쓰면 TextSpan(...) 디버그 문자열이 나온다.
String? text(Data? cell) {
  final value = cell?.value;
  if (value is TextCellValue) return value.value.text;
  return value?.toString();
}

void main() {
  test('시트 이름은 발주서 하나뿐이다', () {
    final back = Excel.decodeBytes(buildPurchaseOrderXlsx(makeOrder()));

    expect(back.tables.keys.toList(), ['발주서']);
  });

  test('위쪽에 제목과 발주 정보가 들어간다', () {
    final rows = Excel.decodeBytes(
      buildPurchaseOrderXlsx(makeOrder()),
    )['발주서'].rows;

    expect(text(rows[0][0]), '발주서');
    expect(rows[1].take(2).map(text), ['발주일', '2026-10-07']);
    expect(rows[2].take(2).map(text), ['매장', '울산점']);
    expect(rows[3].take(2).map(text), ['거래처', '가나다상사']);
    expect(rows[4].take(2).map(text), ['연락처', '010-1234-5678']);
  });

  test('품목 표에 머리글과 각 줄이 들어간다', () {
    final rows = Excel.decodeBytes(
      buildPurchaseOrderXlsx(makeOrder()),
    )['발주서'].rows;

    expect(rows[5].take(4).map(text), ['품목', '수량', '단위', '비고']);
    expect(rows[6].take(3).map(text), ['양파', '2', '박스']);
    expect(rows[7].take(3).map(text), ['대파', '10', '단']);
  });

  test('수량은 글자가 아니라 숫자 셀이다', () {
    final rows = Excel.decodeBytes(
      buildPurchaseOrderXlsx(makeOrder()),
    )['발주서'].rows;

    final qty = rows[6][1]!.value;
    expect(qty, isA<IntCellValue>());
    expect((qty as IntCellValue).value, 2);
  });

  test('연락처가 없어도 만들어지고 그 칸은 비어 있다', () {
    final rows = Excel.decodeBytes(
      buildPurchaseOrderXlsx(makeOrder(contact: null)),
    )['발주서'].rows;

    expect(text(rows[4][0]), '연락처');
    expect(text(rows[4][1]) ?? '', '');
  });
}
