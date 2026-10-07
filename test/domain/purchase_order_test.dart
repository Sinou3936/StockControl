import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/domain/purchase_order.dart';
import 'package:stockcontrol/domain/stock_shortage.dart';

const ulsan = Store(id: 'store-1', name: '울산점');

Ingredient makeIngredient({
  int id = 1,
  String name = '양파',
  double safety = 5000,
  double conversionFactor = 20000,
}) => Ingredient(
  id: id,
  name: name,
  baseUnit: 'g',
  purchaseUnit: '박스',
  conversionFactor: conversionFactor,
  isExpiryTracked: false,
  safetyStockQty: safety,
  createdAt: DateTime(2026, 10, 1),
);

StockShortage makeShortage({
  required double safety,
  required double current,
  double conversionFactor = 20000,
}) => StockShortage(
  ingredient: makeIngredient(
    safety: safety,
    conversionFactor: conversionFactor,
  ),
  store: ulsan,
  currentQty: current,
);

Supplier makeSupplier(String name) =>
    Supplier(id: 1, name: name, createdAt: DateTime(2026, 10, 1));

void main() {
  group('suggestOrderQty', () {
    test('부족분이 구매 단위 한 개에 못 미치면 1이다', () {
      // 5,000g 기준, 1,200g 남음 → 3,800g 부족, 1박스 = 20,000g
      final shortage = makeShortage(safety: 5000, current: 1200);

      expect(suggestOrderQty(shortage), 1);
    });

    test('부족분이 구매 단위의 정확한 배수면 그 배수다', () {
      final shortage = makeShortage(safety: 40000, current: 0);

      expect(suggestOrderQty(shortage), 2);
    });

    test('부족분이 배수를 조금 넘으면 올림한다', () {
      final shortage = makeShortage(safety: 40001, current: 0);

      expect(suggestOrderQty(shortage), 3);
    });

    test('환산계수가 0 이하이거나 숫자가 아니면 예외 없이 1이다', () {
      for (final factor in [0.0, -5.0, double.nan, double.infinity]) {
        final shortage = makeShortage(
          safety: 5000,
          current: 0,
          conversionFactor: factor,
        );

        expect(suggestOrderQty(shortage), 1, reason: '환산계수 $factor');
      }
    });
  });

  group('buildPurchaseOrder', () {
    test('수량이 0 이하인 줄은 빠지고 남은 줄의 순서는 유지된다', () {
      final order = buildPurchaseOrder(
        store: ulsan,
        supplier: makeSupplier('가나다상사'),
        date: DateTime(2026, 10, 7),
        lines: [
          PurchaseOrderLine(
            ingredient: makeIngredient(id: 1, name: '양파'),
            qty: 2,
          ),
          PurchaseOrderLine(
            ingredient: makeIngredient(id: 2, name: '당근'),
            qty: 0,
          ),
          PurchaseOrderLine(
            ingredient: makeIngredient(id: 3, name: '대파'),
            qty: -1,
          ),
          PurchaseOrderLine(
            ingredient: makeIngredient(id: 4, name: '마늘'),
            qty: 5,
          ),
        ],
      );

      expect(order.lines.map((l) => l.ingredient.name), ['양파', '마늘']);
    });

    test('모든 줄이 빠지면 줄이 없는 발주서가 된다', () {
      final order = buildPurchaseOrder(
        store: ulsan,
        supplier: makeSupplier('가나다상사'),
        date: DateTime(2026, 10, 7),
        lines: [PurchaseOrderLine(ingredient: makeIngredient(), qty: 0)],
      );

      expect(order.lines, isEmpty);
    });
  });

  group('파일 이름과 날짜', () {
    test('형식마다 확장자와 MIME 형식이 정해져 있다', () {
      expect(PurchaseOrderFormat.pdf.fileExtension, 'pdf');
      expect(PurchaseOrderFormat.pdf.mimeType, 'application/pdf');
      expect(PurchaseOrderFormat.xlsx.fileExtension, 'xlsx');
      expect(
        PurchaseOrderFormat.xlsx.mimeType,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    });

    test('날짜는 월과 일이 한 자리여도 두 자리로 채운다', () {
      expect(formatPurchaseOrderDate(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('파일 이름에 쓸 수 없는 문자는 _로 바뀐다', () {
      final order = PurchaseOrder(
        store: ulsan,
        supplier: makeSupplier('가나/다:상사'),
        date: DateTime(2026, 10, 7),
        lines: const [],
      );

      expect(
        purchaseOrderFileName(order, PurchaseOrderFormat.pdf),
        '발주서_울산점_가나_다_상사_20261007.pdf',
      );
    });

    test('엑셀 파일 이름은 .xlsx로 끝나고 날짜가 두 자리로 채워진다', () {
      final order = PurchaseOrder(
        store: ulsan,
        supplier: makeSupplier('가나다상사'),
        date: DateTime(2026, 1, 5),
        lines: const [],
      );

      expect(
        purchaseOrderFileName(order, PurchaseOrderFormat.xlsx),
        '발주서_울산점_가나다상사_20260105.xlsx',
      );
    });
  });
}
