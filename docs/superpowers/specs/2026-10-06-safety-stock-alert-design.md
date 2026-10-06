# 재고관리 앱 — 9-1: 안전재고 부족 알림 스펙

## 배경

1단계에서 `Ingredient.safetyStockQty`(nullable) 컬럼을 만들어 뒀지만 지금까지 아무도 쓰지 않는다. 값을 입력할 화면도 없고, 읽는 코드도 없다. 그래서 재고가 바닥나는 것을 알려면 사람이 재고 조회 화면을 훑어야 한다.

게다가 재고 조회는 남은 수량이 0보다 큰 로트만 보여준다. "울산점에 양파가 한 톨도 없는 상태"는 화면에 아예 나타나지 않는다 — 가장 급한 상황이 가장 안 보인다.

이 스펙은 품목마다 안전재고 기준을 정하고, 매장별로 그 기준에 못 미치는 품목을 한 화면에 모아 보여준다. 9단계의 나머지 절반인 발주서 생성은 9-2에서 별도로 다룬다.

## 이번 스펙의 범위

- 품목에 안전재고 값 입력(신규 등록)과 수정(기존 품목)
- 매장별 부족 판정 — DB를 모르는 순수 함수
- 매장+품목별 재고 합계 조회 (`LotDao`)
- "부족 재고" 탭과 화면 (하단 탭 / 사이드바), 부족 건수 배지
- 부족 카드를 눌러 해당 품목이 선택된 입고 등록 화면으로 이동
- 안전재고 값의 기기 간 동기화 — 앱 2곳 수정 + Supabase SQL 1회 실행

**범위 밖**:
- 푸시 알림 — 앱을 켜지 않아도 알리는 기능. 이번에 만드는 판정 함수를 서버에서 재사용할 수 있도록 설계만 해두고, 구현은 별도 단계로 미룬다.
- 직원이 사장에게 보내는 발주 요청 — 발주서의 앞단이라 9-2에서 발주서와 함께 설계한다.
- 매장별로 다른 기준값 — 품목 수 × 매장 11곳만큼 입력해야 해서 접었다. 아래 "전제/결정 사항" 참고.
- 품목의 이름·단위·환산계수 수정 — 과거 로트와 어긋나는 문제가 있어 이번 범위에서 뺀다. 수정은 안전재고 값만.
- 발주서 생성 (9-2)

## 전제/결정 사항

1. **안전재고는 품목당 값 하나, 판정은 매장별로.** "양파 5,000g"을 한 번 입력하면 매장 11곳 각각에 대해 그 기준으로 판단한다. 매장마다 다른 값을 두는 방식(품목 × 매장 테이블)은 입력 부담이 크고 새 테이블·동기화가 따라붙어서 접었다. 나중에 필요해지면 "이 매장만 예외" 형태로 덧붙인다.

2. **전 매장이 같은 품목을 쓴다고 전제한다.** 그래서 안전재고가 입력된 품목은 모든 매장에서 추적한다. 실제로는 매장마다 취급 품목에 차이가 있지만, 지금은 그 차이를 데이터로 갖고 있지 않다. 어떤 매장이 실제로 쓰지 않는 품목도 "0이라 부족"으로 뜨는 것을 감수한다. 알림이 시끄러워지면 "그 매장에서 입고한 적 있는 품목만" 거르는 조건을 덧붙이면 된다 — 새 데이터 없이 입고 이력만으로 가능하다.

3. **안전재고 값이 비어 있으면 추적하지 않는다.** 즉 `safetyStockQty`가 `null`인 품목은 부족 목록에 절대 나오지 않는다. 사용자가 0을 입력하거나 입력칸을 비우면 `null`로 저장한다 (0을 기준으로 둬 봐야 "0보다 적음"은 성립하지 않아 무의미하다).

4. **사장이 안전재고를 정한다.** 다만 매장 Windows에서 직원도 부족 목록을 보기 때문에 값은 모든 기기에 전달돼야 한다. 정하는 사람이 한 명이라 동시 수정 충돌은 사실상 없고, 충돌 시 서버에 나중에 도착한 값이 이긴다.

5. **직원도 부족 목록을 본다.** 자기 매장 것만 보인다. 사장은 드롭다운으로 매장을 고르거나 전체를 본다 (기존 `StoreSwitcher`와 동일).

6. **매장이 지정되지 않은 로트는 매장별 합계에서 제외한다.** 매장 기능 이전에 만들어진 데이터용 방어 처리다. 현재 로컬 DB에는 그런 로트가 0건이다.

## 아키텍처

### 부족 판정 (`lib/domain/stock_shortage.dart`)

DB를 모르는 순수 함수. 재료 세 가지를 받아 부족 목록을 돌려준다. 나중에 푸시 알림을 붙일 때 서버 쪽에서 같은 판정을 돌려야 하므로, 화면이나 DB 코드와 섞지 않는다.

```dart
/// 매장 한 곳의 품목 하나에 대한 현재 재고 합계.
class StoreStockLevel {
  const StoreStockLevel({
    required this.ingredientId,
    required this.storeId,
    required this.totalQty,
  });

  final int ingredientId;
  final String storeId;
  final double totalQty;
}

/// 한 매장에서 한 품목이 기준에 못 미치는 상태.
class StockShortage {
  const StockShortage({
    required this.ingredient,
    required this.store,
    required this.currentQty,
  });

  final Ingredient ingredient;
  final Store store;
  final double currentQty;

  /// 추적 대상만 StockShortage가 되므로 safetyStockQty는 항상 non-null.
  double get safetyStockQty => ingredient.safetyStockQty!;
  double get shortfall => safetyStockQty - currentQty;

  /// 기준 대비 채워진 비율. 0이면 완전히 빈 상태.
  double get fillRatio => currentQty / safetyStockQty;
}

List<StockShortage> calculateShortages({
  required List<Ingredient> ingredients,
  required List<Store> stores,
  required List<StoreStockLevel> levels,
});
```

**판정 규칙**
- `safetyStockQty`가 `null`이거나 0 이하인 품목은 건너뛴다.
- 넘겨받은 매장 각각에 대해, 그 매장의 그 품목 합계를 `levels`에서 찾는다. 없으면 0으로 본다 (로트가 하나도 없는 경우).
- 합계 < 기준이면 `StockShortage` 한 건.
- 정렬: `fillRatio` 오름차순 → 매장 이름 → 품목 이름. 완전히 빈 품목이 맨 위에 온다.

매장 범위 필터는 함수가 하지 않는다. 호출하는 쪽이 `stores`에 전체 매장을 넘기거나 한 곳만 넘긴다.

### 재고 합계 조회 (`LotDao.watchStockLevelsByStore`)

```dart
Stream<List<StoreStockLevel>> watchStockLevelsByStore();
```

`lots`를 `(ingredientId, storeId)`로 묶어 `remainingQty` 합을 낸다. `storeId`가 `null`인 로트는 제외한다. 남은 수량이 0인 로트도 합계에 포함하지만 합에 영향이 없다 — 재고 조회의 `remainingQty > 0` 필터와 달리 여기서는 거르지 않는다. 품목 전체가 0인 매장은 애초에 행이 없고, 판정 함수가 0으로 처리한다.

### Provider 구성 (`lib/core/providers/shortage_providers.dart`)

Riverpod으로 세 스트림을 모아 판정 함수에 넘긴다. 스트림 결합 라이브러리를 새로 들이지 않는다.

```dart
final storesStreamProvider = StreamProvider<List<Store>>(...);
final ingredientsStreamProvider = StreamProvider<List<Ingredient>>(...);
final stockLevelsStreamProvider = StreamProvider<List<StoreStockLevel>>(...);

/// activeStoreIdProvider 기준으로 범위를 좁힌 부족 목록.
final shortagesProvider = Provider<List<StockShortage>>(...);

/// 탭 배지용.
final shortageCountProvider = Provider<int>((ref) => ref.watch(shortagesProvider).length);
```

`shortagesProvider`가 판정 대상 매장을 정하는 규칙은 **세션 역할에서 직접 끌어낸다**:

- 사장: `selectedStoreProvider`가 비어 있으면 전체 매장, 매장을 골랐으면 그 매장만
- 직원: 자기 매장만. 세션에 매장이 없으면 빈 목록 (전체로 넘어가지 않는다)
- 로그인 안 됨: 빈 목록

`activeStoreIdProvider`를 그대로 쓰지 않는 이유는 그 provider의 `null`이 두 가지 뜻을 갖기 때문이다 — 사장의 "전체 합산"이기도 하고, 매장이 지정되지 않은 직원이기도 하다. 재고 조회처럼 `null`을 "필터 없음"으로 해석하면 매장 없는 직원에게 전 매장 재고가 보인다. 부족 목록에서는 그 혼동을 없앤다.

세 스트림 중 하나라도 아직 로딩 중이면 빈 목록으로 본다 — 배지가 잠깐 안 보일 뿐 잘못된 숫자를 띄우지는 않는다.

### 화면 (`lib/features/shortage/shortage_screen.dart`)

재고 조회와 같은 카드 격자를 쓴다 (`CenteredContent` + 열 수 자동 계산 + 줄 단위 `ListView.builder`). 카드 하나가 "매장 + 품목" 한 건이다.

카드에 담는 것: 품목 이름, (전체 합산일 때) 매장 이름, `현재 수량 / 기준 수량`, 부족분, 채워진 비율 막대. 현재 수량이 0인 건은 빨간 테두리와 배경으로 구분한다.

AppBar에 `StoreSwitcher`를 둔다 (다른 화면과 동일, 직원에게는 숨겨짐).

부족이 하나도 없으면 `EmptyState`로 "모든 품목이 기준 이상입니다"를 보여준다. 안전재고가 설정된 품목이 아예 없을 때는 "품목 관리에서 안전재고를 설정하면 여기에 표시됩니다"로 안내를 달리한다 — 기능이 꺼져 있는 것인지 재고가 충분한 것인지 구분해준다.

**카드를 누르면** 해당 품목이 선택된 입고 등록 화면을 띄운다. 사장이 전체 합산을 보는 중이었다면 `selectedStoreProvider`를 그 카드의 매장으로 바꾼 뒤 띄운다 — 입고 등록은 매장이 정해져야 동작하고, 그 카드를 눌렀다는 것은 그 매장 일을 하겠다는 뜻이기 때문이다. 이 전환은 의도된 부수효과이며 다른 화면의 매장 선택에도 반영된다.

### 탭 추가 (`lib/core/shell/app_shell.dart`)

`_primaryScreens`에 `ShortageScreen`을 추가해 4개가 된다.

- 폰: 하단 탭이 재고 / 입고 / 실사 / 부족 / 더보기 5개. **"더보기"의 인덱스가 3에서 4로 바뀌므로 `onTap`의 분기 조건을 함께 고쳐야 한다.**
- Windows: 사이드바가 재고 / 입고 / 실사 / 부족 / 거래처 관리 / 품목 관리 6개. 사장 전용 항목(직원 추가, 매장 관리)의 인덱스가 5·6에서 6·7로 밀리므로 분기 조건을 함께 고친다.

"부족" 항목 아이콘 옆에 부족 건수를 빨간 배지로 단다. 0건이면 배지를 숨긴다. 창 크기를 줄였을 때의 인덱스 보정 로직(`_selectedIndex < _primaryScreens.length`)은 그대로 동작한다.

### 안전재고 입력과 수정 (`lib/features/ingredient_management/ingredient_list_screen.dart`)

- **신규 등록 다이얼로그**에 "안전재고 (선택)" 입력칸을 추가한다. 비워 두면 추적하지 않는다.
- **목록 카드**에 현재 안전재고를 표시한다 (`InfoChip`으로 "안전재고 5,000g", 미설정이면 표시 없음).
- **카드를 누르면** 안전재고만 고치는 작은 다이얼로그가 뜬다. 이름·단위·환산계수는 건드리지 않는다. 빈 값으로 저장하면 추적 해제.
- `AppListCard`에 `onTap`을 추가한다 (현재 없음).

```dart
Future<void> updateSafetyStock(int id, double? value);  // IngredientDao
```

### 안전재고 값 동기화

지금 동기화는 "새로 만든 행"만 주고받는다. 값이 바뀌는 경우를 상정하지 않고 만들었다. 안전재고는 이 전제를 처음으로 깨는 값이라 세 군데를 고친다. 보내는 내용(payload)에는 `safety_stock_qty`가 이미 포함돼 있어 그대로 쓴다.

1. **보낼 계기 만들기** — `IngredientDao.updateSafetyStock`이 값을 쓴 뒤 같은 트랜잭션에서 `syncQueueDao.enqueue('ingredients', id)`를 호출한다. 서버는 `upsert`라 기존 행을 덮어쓴다.

2. **받는 쪽이 반영하게 하기** — `SyncRepository._applyPulledRow`의 `'ingredients'` 분기는 현재 "이미 있으면 건너뜀"이다. 이를 "이미 있으면 `safetyStockQty`만 갱신"으로 바꾼다. 이름·단위·환산계수는 계속 손대지 않는다. 바뀔 수 있는 값이 안전재고 하나뿐이므로 그것만 갱신하는 것이 안전하다.

3. **서버가 수정 시각을 갱신하게 하기 (사용자가 SQL 1회 실행)** — `synced_at`은 `default now()`라 INSERT 때만 채워진다. UPDATE로 값이 바뀌어도 시각이 그대로여서, 다른 기기의 커서가 그 행을 지나쳐 버린다. 트리거로 UPDATE 때도 시각을 새로 찍게 한다.

```sql
create or replace function public.touch_synced_at()
returns trigger language plpgsql as $$
begin
  new.synced_at = now();
  return new;
end;
$$;

create trigger ingredients_touch_synced_at
  before update on public.ingredients
  for each row execute function public.touch_synced_at();
```

이 트리거는 `ingredients`에만 건다. 나머지 세 테이블은 여전히 기록용이라 수정될 일이 없다.

### 입고 등록 — 품목 미리 선택 (`lib/features/inbound/inbound_form_screen.dart`)

`InboundFormScreen`에 선택 항목인 `initialIngredient`를 추가하고, `initState`에서 `_selectedIngredient`를 채운다. 탭에서 열 때는 지금처럼 인자 없이 쓰므로 기존 동작은 그대로다.

## 파일 구조

```
lib/
  domain/
    stock_shortage.dart              # 신규: StoreStockLevel, StockShortage, calculateShortages
  data/local/daos/
    lot_dao.dart                     # 수정: watchStockLevelsByStore
    ingredient_dao.dart              # 수정: updateSafetyStock (+ 큐 기록)
  data/repositories/
    sync_repository.dart             # 수정: 품목 pull 시 안전재고 갱신
  core/providers/
    shortage_providers.dart          # 신규: 스트림 3개 + shortagesProvider + shortageCountProvider
  core/shell/
    app_shell.dart                   # 수정: 부족 탭 추가, 인덱스 분기 수정, 배지
  core/widgets/
    app_widgets.dart                 # 수정: AppListCard에 onTap
  features/
    shortage/
      shortage_screen.dart           # 신규
    ingredient_management/
      ingredient_list_screen.dart    # 수정: 안전재고 표시·입력·수정
    inbound/
      inbound_form_screen.dart       # 수정: initialIngredient
```

## 테스트 전략

**순수 함수 (`test/domain/stock_shortage_test.dart`)** — DB 없이 가장 촘촘하게 검증한다.
- 안전재고가 `null`인 품목은 결과에 없다
- 로트가 하나도 없는 매장은 현재 수량 0으로 부족에 포함된다
- 합계가 기준과 정확히 같으면 부족이 아니다 (경계값)
- 합계가 기준보다 많으면 부족이 아니다
- 여러 매장·여러 품목일 때 `fillRatio` 오름차순 → 매장 이름 → 품목 이름 순으로 정렬된다
- `stores`에 한 매장만 넘기면 그 매장 결과만 나온다

**DAO (`test/data/local/lot_dao_test.dart`)** — 메모리 DB.
- 같은 매장·같은 품목 로트 여러 개가 하나로 합산된다
- 다른 매장 로트가 섞이지 않는다
- `storeId`가 `null`인 로트는 결과에서 빠진다

**안전재고 수정 (`test/data/local/ingredient_dao_test.dart`)**
- `updateSafetyStock`이 값을 바꾸고, 같은 호출로 전송 큐에 `('ingredients', id)`가 쌓인다
- `null`을 넘기면 추적 해제된다

**동기화 (`test/data/repositories/sync_repository_test.dart`)**
- 이미 로컬에 있는 품목을 pull하면 `safetyStockQty`가 갱신된다
- 같은 pull에서 이름·환산계수는 바뀌지 않는다

**화면 (`test/features/shortage/shortage_screen_test.dart`)**
- 기준 미달 품목이 카드로 보인다
- 직원 세션에서는 자기 매장 건만 보인다
- 매장이 지정되지 않은 직원 세션에서는 아무 건도 보이지 않는다 (전 매장이 보이면 안 된다)
- 부족이 없으면 "모든 품목이 기준 이상입니다"가 보인다
- 안전재고가 설정된 품목이 하나도 없으면 설정 안내 문구가 보인다

**탭 (`test/core/shell/app_shell_test.dart`)**
- 폰에서 "더보기"가 새 인덱스에서도 열린다
- Windows에서 사장 전용 항목(직원 추가, 매장 관리)이 밀린 인덱스에서도 열린다
- 부족 건수가 0이면 배지가 없다

## 수동 확인 (구현 후)

1. Supabase SQL Editor에서 위 트리거 SQL 실행
2. Windows에서 품목 하나에 안전재고 설정 → 부족 재고 탭에 뜨는지 확인
3. 폰(에뮬레이터)에서 동기화 → 같은 기준이 반영되고 그 매장 기준으로 부족이 뜨는지 확인
4. 폰에서 안전재고 값 변경 → Windows에서 동기화 후 바뀐 값이 반영되는지 확인 (트리거가 동작하는지 확인하는 단계)
5. 부족 카드를 눌러 입고 등록이 그 품목으로 열리는지 확인
