# 재고관리 앱 — 매장(Store) 도메인 모델 2차: 기존 화면 매장 연동 스펙

## 배경

1차(`2026-10-01-store-domain-model-design.md`/`-plan.md`)에서 매장(Store) 엔티티, 직원-매장 연결, 매장 관리 화면을 추가했다. 하지만 3~6단계에서 만든 핵심 화면(재고 조회, 입고 등록, 마감 실사)은 아직 매장을 전혀 신경 쓰지 않는다 — 모든 로트(Lot)를 매장 구분 없이 하나의 풀로 보여준다. 이 스펙은 그 화면들을 매장 기준으로 동작하도록 고친다.

## 이번 스펙의 범위

- 재고 조회(`StockOverviewScreen`), 입고 등록(`InboundFormScreen`), 마감 실사(`CountScreen`)를 매장 기준으로 필터링
- 사장 전용 "매장 선택 / 전체 합산" 드롭다운 (3개 화면 AppBar에 공통 추가)
- 전체 합산 상태에서 입고 등록·마감 실사는 매장 선택을 요구하도록 막기
- `LotRepository.receiveLot(...)`에 매장 정보 반영

**범위 밖**:
- 품목/거래처 관리 화면 — 공통 마스터데이터라 매장 연동 대상 아님 (1차 결정 유지)
- 실데이터(품목/거래처/로트/이동)의 서버 동기화 (8-2, 여전히 별도)
- 매장별 안전재고/발주 알림 (9단계 몫)

## 전제/결정 사항

- **별도의 "합산 전용 화면"을 만들지 않는다.** 재고 조회/마감 실사는 이미 로트(Lot) 단위로 행을 나열하고 있어서, 매장 필터가 없으면 그 자체로 "전체 로트 나열 = 합산 + 세부"가 된다. 필터 유무만 다르면 되므로 같은 화면·같은 쿼리를 재사용한다.
- **직원은 매장 전환 UI 자체가 안 보인다** — 로그인한 자기 매장으로 고정, 전환 불가.
- **사장은 상단에 항상 보이는 드롭다운**(재고 조회/입고 등록/마감 실사 3개 화면 AppBar `actions`)으로 "특정 매장" 또는 "전체 합산"을 고른다. **로그인 직후 기본값은 "전체 합산"**이다.
- **전체 합산 상태에서는 입고 등록·마감 실사를 할 수 없다** — 둘 다 "어느 매장의 재고냐"가 반드시 정해져야 하는 행위이기 때문이다. 이 상태로 두 화면에 들어가면 폼 대신 매장을 먼저 선택하라는 안내만 보여준다. 재고 조회는 읽기 전용이라 전체 합산 상태에서도 그대로 보여준다.
- **전체 합산으로 볼 때는 각 로트 행에 매장 이름도 함께 표시**한다 — 특정 매장으로 필터링했을 때는 다 같은 매장이라 표시해도 의미 없지만(그래도 해 둬서 분기 로직을 줄인다), 전체 합산일 때는 "이 포장이 어느 매장 것인지" 바로 보여야 한다.
- **`Lot.storeId`는 1차에서 이미 nullable로 추가돼 있다.** 2차부터는 입고 등록 화면이 항상 현재 선택된 매장으로 `storeId`를 채워 넣으므로, 이 스펙 적용 이후 새로 만들어지는 로트는 전부 매장이 채워진다. 1차 이전에 만들어진 테스트 데이터(매장 없음)는 그대로 둬도 동작엔 지장 없다(그냥 "매장 미상"으로 취급).

## 아키텍처

### 매장 선택 상태 (`selectedStoreProvider`)

```dart
final selectedStoreProvider = StateProvider<Store?>((ref) => null);
```

- `null` = 전체 합산. 사장이 드롭다운에서 고르면 이 값이 바뀐다.
- 직원 로그인 시에는 이 provider를 건드리지 않는다 — 대신 화면들은 "현재 작업 매장"을 구할 때 직접 `selectedStoreProvider`나 `authSessionProvider`를 보지 않고, 아래의 파생 provider 하나만 본다:

```dart
final activeStoreIdProvider = Provider<String?>((ref) {
  final session = ref.watch(authSessionProvider);
  if (session == null) return null;
  if (!session.isOwner) return session.storeId;
  return ref.watch(selectedStoreProvider)?.id;
});
```

  - 직원이면 항상 `session.storeId`(고정값)
  - 사장이면 `selectedStoreProvider`의 현재 값(null이면 전체 합산)
  - 세 화면(재고 조회/입고 등록/마감 실사)과 `StoreSwitcher`는 전부 이 `activeStoreIdProvider` 하나만 watch한다 — "직원인지 사장인지"를 화면마다 따로 분기하지 않아도 된다.

### 드롭다운 (`StoreSwitcher` 위젯)

- 새 공용 위젯 `lib/features/stock/store_switcher.dart`: `ref.watch(authSessionProvider)?.isOwner`가 false면 `SizedBox.shrink()`, true면 로컬 `Stores` 캐시(`storeDaoProvider.watchAll()`)를 드롭다운으로 보여주고 "전체 합산" 옵션을 맨 위에 추가. 선택이 바뀌면 `selectedStoreProvider`를 갱신한다.
- 이 위젯을 `StockOverviewScreen`/`InboundFormScreen`/`CountScreen`의 `AppBar(actions: [...])`에 공통으로 추가한다.

### 로트 조회 — 매장 필터

`LotDao.watchAvailableLotsWithIngredient`를 아래처럼 바꾼다:

```dart
Stream<List<LotWithIngredient>> watchAvailableLotsWithIngredient({
  String? storeId,
})
```

- `storeId`가 `null`이면 기존처럼 전체 로트
- `storeId`가 있으면 `lots.storeId.equals(storeId)` 조건 추가
- `LotWithIngredient`/`IngredientStockGroup`/`groupLotsByIngredient`는 손대지 않는다 — `Lot`에는 이미 1차에서 추가한 `storeId`가 있으므로, 매장 이름이 필요한 화면이 `storeDaoProvider.watchAll()`(이미 로컬에 동기화되어 있는 매장 캐시)을 따로 watch해서 `storeId → 이름` 맵을 만들고 각 로트의 `storeId`로 조회하면 된다. DAO 쿼리에 join을 추가할 필요가 없다.

### 입고 등록 — 매장 기록 + 매장 미선택 시 막기

- `LotRepository.receiveLot(...)`에 `required String? storeId` 파라미터 추가, `LotsCompanion.insert(..., storeId: Value(storeId))`로 반영
- `InboundFormScreen`: "현재 작업 매장" 헬퍼가 `null`을 반환하면(사장이 전체 합산 상태) 입력 폼 대신 "매장을 선택해주세요" 안내 위젯을 보여준다. 매장이 정해져 있으면 그 매장 ID를 `receiveLot`에 넘긴다.

### 마감 실사 — 매장 기준 조회 + 매장 미선택 시 막기

- `CountScreen`도 `InboundFormScreen`과 동일하게 매장 미선택 시 안내만 표시
- 매장이 정해져 있으면 `watchAvailableLotsWithIngredient(storeId: ...)`로 그 매장 로트만 가져와서 기존 로직(이론재고 대비 실사 입력 → 차이 계산 → `submitCountCorrections`) 그대로 수행 — 로트 자체가 이미 그 매장 것만 필터링되어 있으므로 보정 로직은 변경 없음

### 재고 조회 — 매장 필터 + 합산 시 매장 표시

- `StockOverviewScreen`: "현재 작업 매장" 헬퍼 값을 그대로 `watchAvailableLotsWithIngredient(storeId: ...)`에 넘긴다. 사장이 전체 합산이면 `storeId: null`이라 전체가 나오고, 각 로트 행에 매장 이름을 같이 보여준다. 직원/특정 매장 선택 시에는 필터링된 결과만 나온다(매장 이름 표시는 해도 되고 안 해도 되지만, 분기 없이 항상 표시하는 쪽으로 단순화한다).

## 파일 구조

```
lib/
  core/
    providers/
      store_providers.dart           # 수정: selectedStoreProvider, activeStoreIdProvider 추가
  features/
    stock/
      store_switcher.dart            # 신규: 공용 매장 선택 드롭다운 위젯
    stock_overview/
      stock_overview_screen.dart     # 수정: 매장 필터 + 매장 이름 표시 + StoreSwitcher
    inbound/
      inbound_form_screen.dart       # 수정: 매장 미선택 시 막기 + StoreSwitcher + storeId 전달
    count/
      count_screen.dart              # 수정: 매장 필터 + 매장 미선택 시 막기 + StoreSwitcher
  data/
    local/
      daos/
        lot_dao.dart                 # 수정: watchAvailableLotsWithIngredient에 storeId 필터
    repositories/
      lot_repository.dart            # 수정: receiveLot에 storeId 추가
```

## 테스트 전략

- `LotDao`: storeId로 필터링됐을 때/안 됐을 때 각각 올바른 로트만 나오는지 테스트
- `LotRepository.receiveLot`: storeId가 제대로 저장되는지 테스트
- `StockOverviewScreen`: 매장 선택 시 그 매장 로트만, 전체 합산 시 전체 + 매장 이름 표시 테스트
- `InboundFormScreen`/`CountScreen`: 매장 미선택(사장·전체 합산) 상태에서 폼 대신 안내가 뜨는지, 매장 선택 후에는 정상 동작하는지 테스트
- `StoreSwitcher`: 직원 세션이면 안 보이는지, 사장 세션이면 매장 목록 + "전체 합산" 옵션이 뜨는지, 선택 시 provider가 갱신되는지 테스트
