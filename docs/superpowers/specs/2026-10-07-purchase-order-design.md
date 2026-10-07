# 재고관리 앱 — 9-2: 발주서 파일 만들기 스펙

## 배경

9-1에서 매장별로 안전재고에 못 미치는 품목을 한 화면에 모아 보여주게 됐다. 하지만 거기서 끝이다. 부족한 걸 알아도 거래처에 얼마를 주문할지는 사람이 머릿속이나 종이로 계산해야 한다. 특히 재고는 기본 단위(g 등)로 세고 주문은 구매 단위(박스 등)로 해서, 환산을 사람이 한다.

이 스펙은 부족 재고에서 이어서 **거래처별 발주서를 PDF와 엑셀 파일로 만들어 저장**하게 한다. 발주서를 앱에 보관하거나 보내는 기능은 만들지 않는다.

현재 거래처 발주는 전화로 한다고 알고 있다 (실제 현황은 확인하지 못했다). 그래서 발주서는 거래처에 자동으로 전달되는 것이 아니라, 사장이 전화하며 보거나 직접 첨부하는 **파일**이다.

## 이번 스펙의 범위

- 부족 재고 화면에 "발주서 만들기" 진입 (사장 계정만)
- 발주서 화면: 거래처 선택, 품목 체크, 수량 확인·수정
- 수량 제안: 부족분을 구매 단위로 올림한 값을 미리 채움
- PDF 저장, 엑셀 저장
- 한글이 깨지지 않는 PDF를 위해 한글 글꼴을 앱에 포함

**범위 밖** — 아래는 모두 필요가 생겼을 때 그때 고치는 것으로 한다 (사용자 결정):
- 공유(카카오톡·메일), 인쇄 — 저장만 한다.
- 발주 이력 — 발주서를 저장하지 않는다. 새 테이블도, 동기화 변경도, Supabase SQL도 없다.
- 거래처와 품목의 연결 — 품목을 여러 거래처에서 나눠 산다고 해서 만들지 않는다. 거래처는 발주서를 만들 때 고른다.
- 여러 매장을 합친 발주 — 발주서는 매장 하나 단위다. 합쳐서 발주하는 것으로 드러나면 그때 고친다.
- 직원이 사장에게 보내는 발주 요청 — 당장은 필요 없다고 했다.
- 단가·금액 — 전화 발주라 발주서에 가격을 담지 않는다.
- 최근 입고한 거래처를 미리 선택해 두는 것 — 매번 고르는 게 번거로워지면 입고 기록의 거래처로 덧붙일 수 있다.

## 전제/결정 사항

**사용자가 정한 것**

1. **PDF와 엑셀을 둘 다 만든다.** PDF는 고정해서 쓰고, 엑셀은 고쳐서 쓴다.
2. **저장만 한다.** 공유·인쇄·이력은 하지 않는다.
3. **거래처는 발주서를 만들 때 고른다.** 품목을 여러 거래처에서 나눠 산다.
4. **수량은 제안값을 채워 두되 직접 고칠 수 있다.**
5. **발주서는 매장 하나 + 거래처 하나 단위다.** 합쳐서 발주하게 되면 그때 고친다.
6. **발주는 사장이 한다.**

**제가 정한 기본값 (스펙 검토 때 바꿀 수 있다)**

7. **수량 제안은 `부족분 ÷ 환산계수`를 올림한 구매 단위 수다.** 양파 안전재고 5,000g, 현재 1,200g, 1박스 20,000g이면 3,800g 부족 → 1박스. 안전재고까지만 채우는 양이라 도착하자마자 다시 기준선에 걸릴 수 있으므로 어디까지나 제안이다.
8. **전체 합산을 보는 중에는 발주서를 만들 수 없다.** 발주서는 매장이 정해져야 하므로 버튼을 비활성화하고 "매장을 고르면 발주서를 만들 수 있습니다"를 보여준다. 입고 등록 화면이 매장 없이 "매장을 선택해주세요"를 보여주는 것과 같은 방식이다.
9. **발주서 화면을 열 때 부족 목록을 한 번 복사해 둔다.** 화면을 보는 중에 동기화로 재고가 바뀌어도 입력 중인 수량이 덮이지 않는다. 새로 반영하려면 화면을 다시 연다.
10. **수량이 0 이하인 품목은 발주서에서 빠진다.** 체크를 해제하는 것과 같다.
11. **환산계수가 0 이하인 품목은 제안 수량을 1로 둔다.** 0으로 나누면 올림이 예외를 던진다. 품목 등록 화면이 환산계수의 양수 여부를 검사하지 않아서 생길 수 있는 값이다.
12. **부동소수점 오차 때문에 제안이 한 단위 더 나올 수 있으나 보정하지 않는다.** 수정 가능한 제안값이라 틀려도 사용자가 고칠 수 있다. 실제 재고 수량이 소수를 얼마나 쓰는지는 확인하지 못했다.

## 아키텍처

### 수량 제안과 발주서 조립 (`lib/domain/purchase_order.dart`)

DB, 파일, 화면을 모르는 순수 함수. 9-1의 `StockShortage`를 받는다.

```dart
/// 발주서의 한 줄. 수량은 구매 단위(박스 등) 기준 정수.
class PurchaseOrderLine {
  const PurchaseOrderLine({required this.ingredient, required this.qty});

  final Ingredient ingredient;
  final int qty;
}

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

/// 부족분을 구매 단위로 올린 수. 환산계수가 0 이하면 1.
int suggestOrderQty(StockShortage shortage);

/// 수량이 0 이하인 줄을 빼고 발주서를 만든다. 줄 순서는 입력 순서를 지킨다.
PurchaseOrder buildPurchaseOrder({
  required Store store,
  required Supplier supplier,
  required DateTime date,
  required List<PurchaseOrderLine> lines,
});
```

### 파일 만들기 (`lib/data/export/`)

`PurchaseOrder`를 받아 파일 바이트를 돌려주는 함수 두 개. 저장은 모른다.

```dart
Uint8List buildPurchaseOrderXlsx(PurchaseOrder order);

Future<Uint8List> buildPurchaseOrderPdf(
  PurchaseOrder order, {
  required ByteData regularFont,
  required ByteData boldFont,
});
```

글꼴을 인자로 받는 이유는 테스트에서 실제 글꼴 파일을 넘겨 한글이 들어간 PDF를 만들어 볼 수 있게 하려는 것이다.

**두 파일의 내용은 같다.** 제목 "발주서", 발주 날짜, 매장 이름, 거래처 이름과 연락처, 품목 표(품목명 / 수량 / 단위), 비고 칸. 수량 단위는 품목의 `purchaseUnit`이다.

**파일 이름**: `발주서_{매장}_{거래처}_{yyyyMMdd}.pdf` 또는 `.xlsx`. 파일 이름에 쓸 수 없는 문자(`\ / : * ? " < > |`)는 `_`로 바꾼다.

### 저장 (`PurchaseOrderExporter`)

```dart
enum PurchaseOrderFormat { pdf, xlsx }

abstract class PurchaseOrderExporter {
  /// 저장한 경로. 사용자가 저장 창을 취소하면 null.
  Future<String?> save(PurchaseOrder order, PurchaseOrderFormat format);
}
```

실제 구현은 바이트를 만들고, 시스템의 "다른 이름으로 저장" 창에서 위치를 고르게 한다. 폰에서 앱 전용 폴더에 조용히 저장하면 사용자가 파일을 찾을 수 없어서 위치를 직접 고르게 하는 쪽을 택했다. Riverpod provider로 두어 테스트에서 가짜로 바꿔 끼운다.

### 화면 (`lib/features/purchase_order/purchase_order_screen.dart`)

- 위쪽: 매장 이름(고정), 날짜, 거래처 드롭다운.
- 가운데: 부족 품목마다 체크박스, 품목명, 수량 입력칸(제안값이 채워져 있음), 구매 단위. 기본으로 전부 체크.
- 아래: **PDF 저장**, **엑셀 저장** 버튼. 거래처를 안 골랐거나 수량이 있는 줄이 하나도 없으면 비활성화.
- 거래처가 하나도 없으면 "거래처 관리에서 거래처를 먼저 등록하세요"를 보여준다.
- 저장하면 SnackBar로 "저장했습니다 + 경로"를 보여준다. 취소하면 아무것도 보이지 않는다.

거래처 드롭다운은 선택한 객체를 붙잡지 않고 id로 목록에서 다시 찾아 넘긴다. 거래처는 지금 수정되는 경로가 없어 실제로는 생기지 않지만, 9-1에서 입고 등록의 품목 드롭다운이 같은 원인으로 깨졌던 일이 있어서 같은 방어를 둔다.

### 진입 (`lib/features/shortage/shortage_screen.dart`)

AppBar나 목록 위에 **"발주서 만들기"** 버튼을 둔다. 사장 계정에만 보인다. 사장이 전체 합산을 보는 중이면 비활성화하고 안내 문구를 보여준다 (결정 8). 열 때 `shortagesProvider`의 현재 값을 복사해서 넘긴다 (결정 9).

### 한글 글꼴

PDF에 한글을 넣으려면 글꼴 파일이 필요하다. 오픈 라이선스(SIL OFL) 한글 글꼴의 Regular와 Bold를 `assets/fonts/`에 넣고 `pubspec.yaml`의 `assets`에 등록한다. 글꼴 파일은 수 MB라 앱 크기가 그만큼 늘어난다. 엑셀은 이 제약이 없다.

### 새 패키지

PDF 생성, 엑셀 생성, 저장 창을 위한 패키지 세 개가 필요하다. 지금 `pubspec.yaml`에는 없다. **어떤 패키지로 할지와 버전은 계획서를 쓸 때 실제로 확인한다.** 엑셀은 라이선스 제약이 없는 쪽을 고른다. 저장 창은 Windows와 Android에서 모두 동작하는지 계획 단계에서 확인하고, 안 되면 대안을 정한다.

## 파일 구조

```
assets/fonts/
  (한글 글꼴 Regular, Bold)          # 신규
lib/
  domain/
    purchase_order.dart              # 신규: PurchaseOrder, suggestOrderQty, buildPurchaseOrder
  data/export/
    purchase_order_xlsx.dart         # 신규
    purchase_order_pdf.dart          # 신규
    purchase_order_exporter.dart     # 신규: 인터페이스 + 실제 구현 + provider
  features/
    purchase_order/
      purchase_order_screen.dart     # 신규
    shortage/
      shortage_screen.dart           # 수정: 발주서 만들기 진입
pubspec.yaml                         # 수정: 패키지, 글꼴 등록
```

## 테스트 전략

**순수 함수 (`test/domain/purchase_order_test.dart`)**
- 부족분이 구매 단위 한 개에 못 미치면 1이 된다
- 부족분이 구매 단위의 정확한 배수면 그 배수가 된다
- 부족분이 배수를 조금 넘으면 올림된다
- 환산계수가 0 이하면 1이다 (예외가 나지 않는다)
- 수량 0 이하인 줄은 발주서에서 빠지고, 남은 줄의 순서가 유지된다

**엑셀 (`test/data/export/purchase_order_xlsx_test.dart`)**
- 만든 바이트를 같은 패키지로 다시 읽어 매장·거래처·품목명·수량이 들어 있다

**PDF (`test/data/export/purchase_order_pdf_test.dart`)**
- 실제 글꼴을 넘겨 만들었을 때 `%PDF`로 시작하고 비어 있지 않다
- 한글이 실제로 안 깨지는지는 자동 테스트로 확인할 수 없다. 수동 확인으로 둔다.

**파일 이름**
- 쓸 수 없는 문자가 `_`로 바뀐다

**화면 (`test/features/purchase_order/purchase_order_screen_test.dart`)** — 가짜 `PurchaseOrderExporter`로 넘어온 발주서를 잡는다.
- 열면 수량이 제안값으로 채워져 있다
- 수량을 고치면 고친 값이 발주서에 담긴다
- 체크를 해제하거나 수량을 0으로 하면 그 줄이 빠진다
- 거래처를 안 골랐으면 저장 버튼이 눌리지 않는다
- 거래처가 하나도 없으면 안내 문구가 보인다
- 열어 둔 동안 재고가 바뀌어도 입력한 수량이 덮이지 않는다

**진입 (`test/features/shortage/shortage_screen_test.dart`)**
- 사장 계정에는 "발주서 만들기"가 있고 직원 계정에는 없다
- 사장이 전체 합산을 보는 중이면 비활성화된다
- 매장을 고른 사장이 누르면 발주서 화면이 열린다

## 수동 확인 (구현 후)

1. PDF를 PDF 뷰어로 열어 **한글이 깨지지 않았는지** 본다 (자동 테스트가 못 잡는 부분)
2. 엑셀을 엑셀로 열어 열 너비와 내용이 읽을 만한지 본다
3. Windows에서 저장 창이 뜨고 고른 위치에 파일이 생기는지 본다
4. 폰(에뮬레이터)에서 저장한 파일을 사용자가 찾을 수 있는 위치에 저장되는지 본다
5. 실제 품목 하나로 제안 수량이 맞는지 손으로 계산해 대조한다
6. 전체 합산 상태에서 버튼이 막히고, 매장을 고르면 열리는지 본다
