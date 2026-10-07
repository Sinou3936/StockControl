import 'package:stockcontrol/data/local/database.dart';

import 'stock_shortage.dart';

/// 발주서 파일 형식.
enum PurchaseOrderFormat {
  pdf('pdf', 'application/pdf'),
  xlsx(
    'xlsx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );

  const PurchaseOrderFormat(this.fileExtension, this.mimeType);

  /// 점(.)을 뺀 확장자.
  final String fileExtension;
  final String mimeType;
}

/// 발주서의 한 줄. 수량은 구매 단위(박스 등) 기준 정수다.
class PurchaseOrderLine {
  const PurchaseOrderLine({required this.ingredient, required this.qty});

  final Ingredient ingredient;
  final int qty;
}

/// 매장 하나, 거래처 하나에 대한 발주서.
class PurchaseOrder {
  const PurchaseOrder({
    required this.store,
    required this.supplier,
    required this.date,
    required this.lines,
  });

  final Store store;
  final Supplier supplier;
  final DateTime date;
  final List<PurchaseOrderLine> lines;
}

/// 부족분을 구매 단위로 올린 수. 안전재고까지만 채우는 양이라 어디까지나
/// 사용자가 고칠 수 있는 제안값이다.
///
/// 환산계수가 0 이하이거나 숫자가 아니면 1을 돌려준다. 0으로 나눈 값을
/// 올림하면 예외가 나는데, 품목 등록 화면이 환산계수의 양수 여부를 검사하지
/// 않아서 이런 값이 들어올 수 있다.
int suggestOrderQty(StockShortage shortage) {
  final factor = shortage.ingredient.conversionFactor;
  if (!factor.isFinite || factor <= 0) return 1;
  return (shortage.shortfall / factor).ceil();
}

/// 수량이 0 이하인 줄을 빼고 발주서를 만든다. 남은 줄은 입력 순서를 지킨다.
PurchaseOrder buildPurchaseOrder({
  required Store store,
  required Supplier supplier,
  required DateTime date,
  required List<PurchaseOrderLine> lines,
}) {
  return PurchaseOrder(
    store: store,
    supplier: supplier,
    date: date,
    lines: [
      for (final line in lines)
        if (line.qty > 0) line,
    ],
  );
}

String _two(int n) => n.toString().padLeft(2, '0');

/// `2026-10-07` 형식. PDF와 엑셀이 같은 형식을 쓴다.
String formatPurchaseOrderDate(DateTime date) =>
    '${date.year}-${_two(date.month)}-${_two(date.day)}';

/// `발주서_{매장}_{거래처}_{yyyyMMdd}.{확장자}`. 파일 이름에 쓸 수 없는
/// 문자는 `_`로 바꾼다 — 거래처 이름에 `/` 같은 문자가 있어도 저장이
/// 실패하지 않게 하려는 것이다.
String purchaseOrderFileName(PurchaseOrder order, PurchaseOrderFormat format) {
  // 이 문자 집합은 windows_file_picker의 validateFileName과 같아야 한다. 더
  // 좁으면 그 플러그인이 isolate 안에서 예외를 던지는데 거기에는 onError가
  // 없어서, 저장이 영원히 끝나지 않고 저장 버튼이 계속 막힌다.
  String clean(String text) =>
      text.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  final d = order.date;
  final stamp = '${d.year}${_two(d.month)}${_two(d.day)}';
  return '발주서_${clean(order.store.name)}_${clean(order.supplier.name)}'
      '_$stamp.${format.fileExtension}';
}
