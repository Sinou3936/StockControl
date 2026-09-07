# 재고관리 앱 — 6단계 스펙: 마감 실사

## 배경

로드맵 6단계(마감 실사, 이론재고 vs 실사재고 차이 리포트)에 대한 스펙이다. 1~5단계(도메인 모델, 로컬 DB, 입고 등록, 재고 조회, 폐기/조정)는 이미 구현/테스트/커밋 완료된 상태이며, 이번 스펙은 그 위에 "여러 품목을 한 번에 실사하고, 이론재고와의 차이를 확인한 뒤 확정 반영하는" 기능을 추가한다.

## 이번 스펙의 범위

- 재고 조회 화면과 같은 품목 목록에 실사 수량 입력 필드를 더한 실사 화면
- 실사 수량과 이론재고(로트 합계)의 차이를 보여주는 확인 다이얼로그(차이 리포트)
- 확정 시 로트별로 차이를 반영하는 로직(FIFO 부족분 차감 / 최근 로트 초과분 가산)

**범위 밖** (다음 단계에서 다룸): 반응형 레이아웃(7단계), 서버 동기화(8단계), 안전재고 알림(9단계). 로트가 하나도 없는 품목의 실사(아래 전제 참고)도 범위 밖이다.

## 전제/결정 사항

- **실사 단위**: 로트가 아니라 **품목 단위**로 실사 수량을 입력받는다 — 직원이 실제로 세는 건 "품목 총량"이지 "이 로트가 몇 kg인지"가 아니기 때문이다.
- **대상 품목**: 재고 조회 화면과 동일하게, **로트가 하나 이상 있는 품목만** 실사 대상이다. 한 번도 입고된 적 없는 품목(로트 0개)에서 실사로 재고가 발견되는 경우는 이번 스펙 범위 밖이다 — 붙일 로트가 없는 예외 상황이라 입고 등록/초기재고 흐름으로 따로 처리한다.
- **부족분 배분(FIFO)**: 실사 수량이 이론재고보다 적으면, 입고가 오래된 로트부터 순서대로 차감한다. 부족분이 한 로트보다 크면 여러 로트에 걸쳐 순차적으로 뺀다. 실사 입력값이 0 이상으로 검증되는 한, 부족분이 이론재고(그 품목 로트들의 합)를 넘는 일은 수학적으로 없다.
- **초과분 배분**: 실사 수량이 이론재고보다 많으면, 가장 최근에 입고된 로트 하나에 전부 더한다.
- **입력 안 한 품목**: 실사 화면에서 값을 입력하지 않은 품목은 이번 실사에서 건드리지 않는다 — 부분 실사(일부 품목만 세는 경우)를 지원한다.
- **차이 리포트 → 확정 흐름**: 제출 버튼을 누르면 곧바로 반영하지 않고, 이론재고와 실사 수량이 다른 품목만 모아 확인 다이얼로그를 먼저 보여준다. 사용자가 확정해야 실제로 DB에 반영된다.
- **원자성**: 여러 품목에 걸친 로트 조정 전체가 하나의 트랜잭션으로 처리된다 — 기존 `LotRepository.recordQuantityChange`(5단계)를 재사용하고, Drift의 중첩 트랜잭션(세이브포인트)으로 감싼다.

## 도메인 로직 (lib/domain/stock_count.dart)

```dart
class LotQuantityAdjustment {
  LotQuantityAdjustment({required this.lotId, required this.change});
  final int lotId;
  final double change; // 부호 있음
}

List<LotQuantityAdjustment> distributeCountDifference(
  List<Lot> lots,
  double difference,
) {
  if (difference == 0) return [];

  if (difference > 0) {
    final mostRecent = lots.reduce(
      (a, b) => a.receivedDate.isAfter(b.receivedDate) ? a : b,
    );
    return [LotQuantityAdjustment(lotId: mostRecent.id, change: difference)];
  }

  final sorted = [...lots]
    ..sort((a, b) => a.receivedDate.compareTo(b.receivedDate));
  var remaining = -difference;
  final adjustments = <LotQuantityAdjustment>[];
  for (final lot in sorted) {
    if (remaining <= 0) break;
    final take = remaining < lot.remainingQty ? remaining : lot.remainingQty;
    if (take > 0) {
      adjustments.add(LotQuantityAdjustment(lotId: lot.id, change: -take));
      remaining -= take;
    }
  }
  return adjustments;
}

class CountDifference {
  CountDifference({
    required this.ingredient,
    required this.theoreticalQty,
    required this.actualQty,
  });

  final Ingredient ingredient;
  final double theoreticalQty;
  final double actualQty;

  double get difference => actualQty - theoreticalQty;
}
```

세 가지 모두 DB 없이 테스트 가능한 순수 로직이다.

## 데이터 레이어 (lib/data/repositories/lot_repository.dart에 메서드 추가)

```dart
Future<void> submitCountCorrections(
  List<LotQuantityAdjustment> adjustments,
) async {
  await _db.transaction(() async {
    for (final adjustment in adjustments) {
      await recordQuantityChange(
        lotId: adjustment.lotId,
        type: MovementType.countCorrection,
        quantity: adjustment.change,
        memo: '마감 실사 보정',
      );
    }
  });
}
```

기존 `recordQuantityChange`(5단계에서 만든 트랜잭션 메서드)를 그대로 재사용한다. Drift는 트랜잭션 안에서 트랜잭션을 다시 호출하면 세이브포인트로 처리하므로, 전체가 하나의 원자적 작업이 된다.

## 화면 (lib/features/count/count_screen.dart)

- `StockOverviewScreen`과 같은 데이터 소스(`LotDao.watchAvailableLotsWithIngredient()` + `groupLotsByIngredient()`)를 사용해 품목별 목록을 보여준다.
- 각 품목 행에 이론재고(참고용 표시)와 실사 수량 입력 필드를 둔다. 입력값이 없는 품목은 이번 실사에서 제외된다.
- "실사 제출" 버튼: 입력된 품목들에 대해 `CountDifference`를 계산하고, `difference != 0`인 것만 모아 확인 다이얼로그(차이 리포트: 품목명, 이론재고, 실사재고, 차이)를 띄운다.
- 다이얼로그에서 확정하면, 각 `CountDifference`를 그 품목의 로트 목록과 함께 `distributeCountDifference`에 넣어 로트별 조정 목록을 만들고, 전부 합쳐서 `LotRepository.submitCountCorrections(...)`를 한 번 호출한다.
- 성공 시 이전 화면(홈)으로 돌아간다.
- 차이가 없거나(전부 일치) 아무것도 입력하지 않았으면 다이얼로그 없이 바로 안내 후 종료.

## 홈 화면 연결

`HomeScreen`에 "마감 실사" 버튼 추가.

## 테스트 전략

- `distributeCountDifference` 단위 테스트: 부족분이 한 로트로 충분한 경우, 여러 로트에 걸쳐야 하는 경우(FIFO 순서 확인), 초과분이 최근 로트에 붙는 경우, 차이가 0이면 빈 리스트를 반환하는 경우 — DB 없이 테스트
- `CountDifference.difference` getter 테스트 (간단한 계산 확인)
- `LotRepository.submitCountCorrections` 통합 테스트 (인메모리 DB): 여러 로트에 걸친 조정이 한 번의 호출로 전부 반영되는지 확인
- 화면 위젯 테스트: 실사 수량 입력 후 제출 시 차이가 있는 품목만 다이얼로그에 표시되는지, 확정 후 반영되고 이전 화면으로 돌아가는지

## 파일 구조

```
lib/
  domain/
    stock_count.dart              # LotQuantityAdjustment, distributeCountDifference, CountDifference
  data/
    repositories/
      lot_repository.dart         # submitCountCorrections() 메서드 추가
  features/
    count/
      count_screen.dart
  main.dart                       # HomeScreen에 "마감 실사" 버튼 추가
```
