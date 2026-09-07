# 재고관리 앱 — 4단계 스펙: 재고 조회 화면

## 배경

전체 로드맵 10단계 중 4단계(재고 조회, 로트별·유통기한 임박 정렬)에 대한 스펙이다. 1~3단계(도메인 모델, 로컬 DB, 입고 등록)는 이미 구현/테스트/커밋 완료된 상태이며, 이번 스펙은 그 위에 조회 화면 하나만 추가한다.

## 이번 스펙의 범위

- 재고 조회 화면 하나(품목별로 그룹화된 로트 목록, 유통기한 임박 강조)
- 홈 화면에 이 화면으로 가는 버튼 추가

**범위 밖** (다음 단계에서 다룸): 폐기/조정 등록(5단계), 마감 실사(6단계), 검색/필터링, 반응형 레이아웃.

## 전제/결정 사항

- **목록 구조**: 품목별로 그룹화 — 품목 헤더(이름 + 총 남은 수량) 아래에 그 품목의 로트들을 나열한다. 사용자가 목업 A(접었다 펼치는 카드형)와 B(항상 펼쳐진 목록형)를 비교해보고 **B(항상 펼쳐진 목록형)**로 결정했다.
- **유통기한 "임박" 기준**: 오늘 기준 **3일 이내**(이미 지난 것 포함)면 임박으로 간주하고 강조한다.
- **임박 표시 방식**: 목업에서 보여준 "D-1", "오늘" 같은 D-day 카운트다운은 만들지 않는다. 배경색 강조 + "임박" 배지 텍스트 하나로 단순화한다 — 지금 요구사항은 "3일 이내인지 아닌지"만 필요하고, 정확한 날짜 카운트다운은 이번 스펙에 없는 기능이라 과설계하지 않는다.
- **정렬**: 품목 그룹 자체는 "임박 로트가 있는 품목이 먼저" 오도록 정렬하고, 그다음은 이름순. 각 품목 안의 로트는 유통기한이 빠른 순으로 정렬한다(로드맵에 명시된 요구사항).
- **표시 대상**: `remainingQty > 0`인 로트만 보여준다. 다 소진된 로트는 자동으로 목록에서 빠진다(로트 자체를 지우거나 숨김 플래그를 두는 게 아니라, 조회 시점에 필터링).
- **자료구조 선택**: 조인 결과(`LotWithIngredient`)와 화면 표시 단위(`IngredientStockGroup`)를 각각 클래스로 만든다. Dart 3의 레코드(record) 문법도 대안이 될 수 있었지만, `IngredientStockGroup`에 `totalRemainingQty` 같은 계산된 getter를 붙이기에는 이름 붙은 필드를 가진 클래스가 레코드보다 더 직관적이라고 판단해 클래스로 결정했다.

## 도메인 로직 (lib/domain/stock_overview.dart)

```dart
bool isNearExpiry(DateTime? expiryDate, {required DateTime now, int thresholdDays = 3}) {
  if (expiryDate == null) return false;
  return !expiryDate.isAfter(now.add(Duration(days: thresholdDays)));
}

class LotWithIngredient {
  LotWithIngredient({required this.lot, required this.ingredient});
  final Lot lot;
  final Ingredient ingredient;
}

class IngredientStockGroup {
  IngredientStockGroup({
    required this.ingredient,
    required this.lots,
    required this.hasNearExpiryLot,
  });
  final Ingredient ingredient;
  final List<Lot> lots;
  final bool hasNearExpiryLot;

  double get totalRemainingQty =>
      lots.fold(0.0, (sum, lot) => sum + lot.remainingQty);
}

List<IngredientStockGroup> groupLotsByIngredient(
  List<LotWithIngredient> rows, {
  required DateTime now,
}) {
  // ingredientId로 묶고, hasNearExpiryLot=true인 그룹을 먼저, 그다음 이름순으로 정렬
}
```

- `isNearExpiry`: 이미 지난 경우도 포함해 "지금 기준 임박 여부"를 판단하는 순수 함수. DB 없이 테스트 가능.
- `LotWithIngredient`: DB 조인 결과 한 행을 표현하는 값 객체. `Lot`과 `Ingredient`가 항상 짝을 이루도록 보장한다 (두 리스트를 따로 들고 다니다 순서가 어긋나는 위험을 없앤다).
- `IngredientStockGroup`: 화면의 품목 섹션 하나에 대응하는 단위. `hasNearExpiryLot`은 정렬에 쓰기 위해 생성 시점에 미리 계산해서 필드로 저장한다(매번 다시 계산하는 게터로 두지 않음).
- `groupLotsByIngredient`: 순수 함수, DB 없이 테스트 가능.

## 데이터 레이어 (lib/data/local/daos/lot_dao.dart에 메서드 추가)

```dart
Stream<List<LotWithIngredient>> watchAvailableLotsWithIngredient() {
  final query = select(lots).join([
    innerJoin(ingredients, ingredients.id.equalsExp(lots.ingredientId)),
  ])
    ..where(lots.remainingQty.isBiggerThanValue(0))
    ..orderBy([OrderingTerm.asc(lots.expiryDate)]);

  return query.watch().map(
    (rows) => rows
        .map((row) => LotWithIngredient(
              lot: row.readTable(lots),
              ingredient: row.readTable(ingredients),
            ))
        .toList(),
  );
}
```

`LotDao`는 `@DriftAccessor(tables: [Lots])`로만 선언되어 있지만, `Lots`가 `Ingredients`를 외래키로 참조하고 있어서 `ingredients` 테이블 접근자를 이미 갖고 있다 (기존 DAO들과 동일한 패턴). 새 Riverpod provider는 필요 없다 — 기존 `lotDaoProvider`(Task 8에서 이미 생성)를 화면에서 그대로 사용한다.

## 화면 (lib/features/stock_overview/stock_overview_screen.dart)

**흐름**: `lotDaoProvider.watchAvailableLotsWithIngredient()` 스트림 구독 → `groupLotsByIngredient(rows, now: DateTime.now())`로 그룹 리스트 생성 → `ListView.builder`로 그룹마다 헤더(품목명 + 총 수량) + 로트 행들을 나열.

- 로트 행: 입고일, 유통기한(없으면 "유통기한 관리 안 함" 표시), 남은 수량
- `isNearExpiry`가 true인 로트 행은 배경색 강조 + "임박" 배지 텍스트 표시

**타입**: `ConsumerWidget` (상태 없음 — 사용자 입력을 기억할 필요가 없는 순수 조회 화면이라 `ConsumerStatefulWidget`이 필요 없다).

**홈 화면 연결**: `HomeScreen`에 "재고 조회" 버튼 1개 추가.

## 테스트 전략

- `isNearExpiry` 단위 테스트: 이미 지남, 경계값(정확히 3일 후), 기준 이내, 기준 밖, `null`(유통기한 미관리) — 전부 DB 없이 테스트
- `groupLotsByIngredient` 단위 테스트: 그룹화가 정확한지, 임박 품목이 우선 정렬되는지, 동일 우선순위 내 이름순 정렬, `totalRemainingQty` 합산 정확성 — `Lot`/`Ingredient`는 생성자로 직접 만들어서 테스트(실제 DB 불필요)
- `LotDao.watchAvailableLotsWithIngredient()` 통합 테스트: 인메모리 DB로 `remainingQty=0`인 로트가 제외되는지, 유통기한 순 정렬이 맞는지, 조인이 정확한지 검증
- 위젯 테스트는 최소한으로: 품목 그룹 헤더가 뜨는지, 임박 로트에 "임박" 배지 텍스트가 뜨는지 정도만 확인

## 파일 구조

```
lib/
  domain/
    stock_overview.dart          # isNearExpiry, LotWithIngredient, IngredientStockGroup, groupLotsByIngredient
  data/
    local/
      daos/
        lot_dao.dart              # watchAvailableLotsWithIngredient() 메서드 추가
  features/
    stock_overview/
      stock_overview_screen.dart
  main.dart                       # HomeScreen에 "재고 조회" 버튼 추가
```
