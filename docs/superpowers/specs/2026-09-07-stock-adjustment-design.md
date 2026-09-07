# 재고관리 앱 — 5단계 스펙: 폐기/조정 등록

## 배경

로드맵 5단계(폐기/조정 등록)에 대한 스펙이다. 1~4단계(도메인 모델, 로컬 DB, 입고 등록, 재고 조회)는 이미 구현/테스트/커밋 완료된 상태이며, 이번 스펙은 그 위에 "기존 로트의 수량을 줄이거나(폐기) 보정하는(조정)" 기능을 추가한다.

## 이번 스펙의 범위

- 재고 조회 화면의 로트 행을 탭하면 열리는 폐기/조정 등록 화면 하나
- 재고 초과 감소를 막는 검증 로직

**범위 밖** (다음 단계에서 다룸): 마감 실사(6단계), 검색/필터링, 반응형 레이아웃, 레시피 기반 자동 사용량 차감(10단계 선택 사항).

## 전제/결정 사항

- **진입 경로**: 재고 조회 화면(`StockOverviewScreen`)의 로트 행을 탭 → 그 로트가 미리 선택된 상태로 폐기/조정 폼이 열린다. 품목→로트를 직접 다시 고르는 별도 화면은 만들지 않는다 (엉뚱한 로트를 고를 위험을 없앤다).
- **화면 구성**: 폐기와 조정을 하나의 화면/폼으로 합치고, 유형 드롭다운(폐기/조정)으로 구분한다. 같은 메커니즘(로트의 `remainingQty` 조정 + 원장 기록)이라 코드 중복을 피한다.
- **수량 부호**: 폐기는 항상 감소(사용자는 양수로 입력, 내부에서 자동으로 음수 변환). 조정은 증가/감소 방향을 사용자가 직접 고르고, 그에 따라 부호 있는 값을 만든다 — 실사 보정처럼 늘어나는 경우도 있어야 하기 때문이다.
- **음수 재고 방지**: 로트의 남은 수량보다 많은 양을 감소시키려 하면 **저장 자체를 막고 에러 메시지**를 보여준다 (Phase 1 스펙에서 "이번 단계 범위 아님, 추후 usage/disposal 구현 시 검증 로직 추가"라고 미뤄뒀던 부분을 지금 채운다).
- **저장 후 동작**: 성공하면 이전 화면(재고 조회)으로 돌아간다. 목록은 스트림으로 자동 갱신되므로 별도 스낵바는 두지 않는다 — 입고 등록 화면(연속 입력을 전제로 화면에 머무름)과는 반대 UX다.

## 도메인 로직 (lib/domain/stock_adjustment.dart)

```dart
class InsufficientStockException implements Exception {
  InsufficientStockException({
    required this.remainingQty,
    required this.requestedQty,
  });
  final double remainingQty;
  final double requestedQty;
}

double applyQuantityChange(double remainingQty, double change) {
  final newQty = remainingQty + change;
  if (newQty < 0) {
    throw InsufficientStockException(
      remainingQty: remainingQty,
      requestedQty: -change,
    );
  }
  return newQty;
}
```

`applyQuantityChange`는 "현재 남은 수량 + 부호 있는 변화량"을 계산하는 순수 함수다. 결과가 음수면 `InsufficientStockException`을 던진다. DB 없이 테스트 가능.

## 데이터 레이어 (lib/data/repositories/lot_repository.dart에 메서드 추가)

```dart
Future<void> recordQuantityChange({
  required int lotId,
  required MovementType type,
  required double quantity,
  DateTime? occurredAt,
  String? memo,
}) async {
  await _db.transaction(() async {
    final lot = await _db.lotDao.getById(lotId);
    final newQty = applyQuantityChange(lot.remainingQty, quantity);

    await _db.lotDao.updateRemainingQty(lotId, newQty);
    await _db.stockMovementDao.insertMovement(
      StockMovementsCompanion.insert(
        lotId: lotId,
        type: type.toDbString(),
        quantity: quantity,
        occurredAt: occurredAt ?? DateTime.now(),
        memo: Value(memo),
      ),
    );
  });
}
```

`applyQuantityChange`가 예외를 던지면 `_db.transaction()`이 자동으로 롤백한다 — Lot도 안 바뀌고 StockMovement도 생성되지 않는다. `receiveLot()`(Phase 1)이 원자성을 보장했던 것과 같은 메커니즘을 재사용한다.

## 화면

### 수정: lib/features/stock_overview/stock_overview_screen.dart

`_LotRow`를 탭 가능하게 만들어서, 탭하면 `StockAdjustmentFormScreen(lot: lot, ingredient: group.ingredient)`으로 이동한다.

### 신규: lib/features/stock_adjustment/stock_adjustment_form_screen.dart

- 상단에 대상 로트 정보 표시(품목명, 현재 남은 수량, 입고일)
- 유형 드롭다운: 폐기 / 조정
- **폐기 선택 시**: 수량 입력 필드만 표시 (항상 감소로 처리)
- **조정 선택 시**: 증가/감소 선택 + 수량 입력 필드
- 메모 입력 필드(선택)
- 저장 버튼 → `LotRepository.recordQuantityChange(...)` 호출
  - `InsufficientStockException` 발생 시: 에러 텍스트 표시, 화면 유지
  - 성공 시: 이전 화면으로 `pop()`

## 테스트 전략

- `applyQuantityChange` 단위 테스트: 증가, 정상 범위 내 감소, 초과 감소 시 예외, 정확히 0이 되는 경계값 — DB 없이 테스트
- `LotRepository.recordQuantityChange` 통합 테스트 (인메모리 DB): 폐기가 `remainingQty`를 정확히 줄이고 `disposal` 타입 이동을 남기는지, 조정 증가가 반영되는지, 재고 초과 시 예외가 발생하고 **Lot과 StockMovement 둘 다 변경/생성되지 않는지**(롤백 검증)
- 화면 위젯 테스트: 재고 초과 감소 시도 시 에러 메시지가 뜨고 화면에 남아있는지, 정상 저장 시 이전 화면으로 돌아가는지

## 파일 구조

```
lib/
  domain/
    stock_adjustment.dart          # InsufficientStockException, applyQuantityChange
  data/
    repositories/
      lot_repository.dart          # recordQuantityChange() 메서드 추가
  features/
    stock_overview/
      stock_overview_screen.dart   # 로트 행 탭 가능하게 수정
    stock_adjustment/
      stock_adjustment_form_screen.dart
```
