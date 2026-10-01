# 재고관리 앱 — 8-2-1: syncId 추가 스펙

## 배경

8단계(서버 + 동기화 큐)는 8-1(백엔드+로그인, 완료)과 8-2(실제 재고 데이터 동기화)로 나눴었다. 8-2를 브레인스토밍하면서, 거래처/품목/로트/재고이동이 전부 로컬 전용 자동증가 정수 ID를 쓰고 있다는 게 걸림돌로 드러났다 — 이 상태로 동기화하면 서로 다른 기기가 각자 만든 행에 ID가 꼬인다. 이 스펙은 동기화를 시작하기 전에 필요한 전제 작업만 다룬다: 각 테이블에 서버와 공유할 수 있는 안정적인 식별자(`syncId`)를 추가하는 것.

이 작업은 8-2를 둘로 나눈 것의 앞부분이다 — **8-2-1(이 스펙)**: `syncId` 추가. **8-2-2(다음 스펙)**: 실제 아웃박스 큐 + push/pull 동기화 로직.

## 이번 스펙의 범위

- `Suppliers`/`Ingredients`/`Lots`/`StockMovements` 테이블에 `syncId`(UUID, nullable) 컬럼 추가
- 새 행을 만들 때 `syncId`를 자동으로 채워주는 공용 헬퍼 추가
- 기존 로컬 정수 ID 체계는 전혀 건드리지 않음

**범위 밖** (8-2-2에서 다룸):
- 실제 서버 전송/수신 로직, 아웃박스 큐 테이블, 동기화 워커
- Supabase 쪽 `suppliers`/`ingredients`/`lots`/`stock_movements` 테이블 생성

## 전제/결정 사항

- **로컬 정수 ID를 UUID로 전면 전환하지 않는다.** 그러면 1~7단계에서 만든 거의 모든 화면·DAO·도메인 함수·테스트(`int ingredientId`, `int lotId`를 쓰는 곳 전부)를 건드려야 해서 범위가 너무 커지고, 그만큼 회귀 버그가 생길 자리도 늘어난다. 대신 각 테이블에 **`syncId`라는 새 nullable 컬럼만 추가**한다 — 로컬 정수 ID는 지금처럼 화면·DAO·조인에 계속 쓰고, `syncId`는 오직 동기화 계층(8-2-2)에서만 쓴다. 이렇게 하면 기존 코드는 전혀 안 바뀌고, 복잡도가 동기화 계층 안에만 갇힌다.
- **Supabase 쪽 테이블의 기본키(`id`)는 클라이언트가 만든 `syncId`를 그대로 쓴다** — 서버가 별도로 ID를 새로 발급하지 않는다. 그래야 로컬↔서버 ID가 항상 일치하고, 나중에 "서버가 새로 매긴 ID를 로컬에 다시 반영"하는 복잡한 단계가 필요 없다.
- **`syncId` 생성은 화면/리포지토리가 아니라 각 DAO의 insert 메서드 안에서 자동으로 채운다.** 이렇게 하면 화면(`SupplierListScreen`/`IngredientListScreen`)이나 `LotRepository`는 전혀 안 건드려도 된다 — 호출하는 쪽이 `syncId`를 챙겨야 한다는 걸 기억할 필요 자체가 없어진다. 8-2-2에서 "쓰기마다 큐에도 기록"하는 로직도 같은 자리(DAO의 insert 메서드)에 자연스럽게 이어 붙일 수 있다.
- **지금 로컬 DB 데이터는 전부 테스트용**이라(1차/2차 때와 동일한 전제) 복잡한 `onUpgrade` 마이그레이션 없이, 로컬 DB 파일을 지우고 새로 시작하는 방식으로 간다.

## 아키텍처

### `uuid` 패키지 추가

`flutter pub add uuid` — UUID v4 생성을 위해 새 의존성을 추가한다.

### `syncId` 생성 헬퍼

`lib/domain/sync_id.dart`:
```dart
import 'package:uuid/uuid.dart';

String generateSyncId() => const Uuid().v4();
```

PIN 해시의 `generatePinSalt()`와 같은 자리에, 같은 패턴으로 둔다 — 순수 함수라 테스트하기 쉽고, 나중에 8-2-2에서 재사용한다.

### 테이블 변경

`Suppliers`/`Ingredients`/`Lots`/`StockMovements` 전부 동일하게 `TextColumn get syncId => text().nullable()();` 추가. `schemaVersion`을 4로 올린다(매장 작업에서 이미 3으로 올려뒀음).

### 생성 시점에 `syncId` 채우기

네 DAO(`SupplierDao`/`IngredientDao`/`LotDao`/`StockMovementDao`)의 insert 메서드를 각각 아래 패턴으로 바꾼다 — `SupplierDao` 예시:

```dart
Future<int> insertSupplier(SuppliersCompanion entry) =>
    into(suppliers).insert(entry.copyWith(syncId: Value(generateSyncId())));
```

호출하는 쪽(화면, `LotRepository`)이 넘긴 `Companion`에 `syncId`가 있든 없든 **DAO가 항상 새로 생성해서 덮어쓴다** — 호출부는 지금 그대로 둬도 된다. `LotDao.insertLot`/`StockMovementDao.insertMovement`도 동일한 패턴이라, `LotRepository`의 `receiveLot`/`recordQuantityChange`/`submitCountCorrections`는 전혀 수정할 필요가 없다. `updateRemainingQty`(로트 수량만 고치는 메서드)는 새 행을 만드는 게 아니라 손대지 않는다 — `remainingQty`는 애초에 동기화 대상이 아니다(8-2-2에서 다룸).

## 파일 구조

```
lib/
  domain/
    sync_id.dart                      # 신규
  data/
    local/
      tables/
        suppliers_table.dart          # 수정: syncId 추가
        ingredients_table.dart        # 수정: syncId 추가
        lots_table.dart               # 수정: syncId 추가
        stock_movements_table.dart    # 수정: syncId 추가
      daos/
        supplier_dao.dart             # 수정: insertSupplier가 syncId 자동 채움
        ingredient_dao.dart           # 수정: insertIngredient가 syncId 자동 채움
        lot_dao.dart                  # 수정: insertLot이 syncId 자동 채움
        stock_movement_dao.dart       # 수정: insertMovement가 syncId 자동 채움
      database.dart                   # 수정: schemaVersion 4
```

화면(`SupplierListScreen`/`IngredientListScreen`)과 `LotRepository`는 수정 대상이 아니다 — DAO 레벨에서 전부 처리되므로 호출부는 그대로 둔다.

## 테스트 전략

- `generateSyncId()`: 호출할 때마다 다른 값이 나오는지, 빈 문자열이 아닌지 (기존 `generatePinSalt` 테스트와 같은 패턴)
- 각 DAO의 insert 메서드: 호출부가 `syncId`를 안 넘겨도 결과 행에 `syncId`가 채워지는지, 두 번 호출하면 서로 다른 `syncId`가 나오는지
- 기존 테스트는 전부 수정 없이 통과해야 한다 — `syncId`가 nullable이고 DAO 내부에서 자동으로 채워지므로 기존 `...Companion.insert(...)` 호출부(화면, 테스트 포함)는 전혀 안 깨진다.
