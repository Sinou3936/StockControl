# 재고관리 앱 — 8-2-2: 아웃박스 큐 + 동기화 스펙

## 배경

8-2-1에서 거래처/품목/로트/재고이동에 `syncId`(UUID)를 추가해뒀다. 이 스펙은 그 위에서 실제로 로컬↔Supabase 동기화를 돌리는 부분을 다룬다 — 오프라인에서도 쓰기가 항상 성공하고, 온라인 복귀 시 쌓인 변경사항을 안전하게 서버로 올리고, 다른 기기가 만든 데이터를 받아오는 전체 메커니즘.

## 이번 스펙의 범위

- 로컬 아웃박스 큐(`SyncQueue`) — 거래처/품목/로트/재고이동을 만들 때마다 자동 기록
- 큐를 순서대로, 중복 안전하게 서버로 올리는 push 로직
- 서버의 새 데이터를 받아와 로컬에 반영하는 pull 로직 (역할별 범위 다르게)
- Supabase에 `suppliers`/`ingredients`/`lots`/`stock_movements` 테이블 생성
- 동기화를 언제 시도할지(트리거) 결정

**범위 밖**:
- 매장/직원 계정 자체의 동기화 — 이미 1차/8-1에서 "바로 쓰기" 방식으로 따로 돌아가고 있고, 이번 스펙에서 바꾸지 않는다
- 외부 POS 연동 (완전히 별도 주제, 나중에 따로 브레인스토밍)
- 사용자가 "저장"을 두 번 눌러서 생기는 중복 입력 방지(화면 레벨 문제, 범위 밖)
- 삭제(delete) 동기화 — 지금 이 앱엔 삭제 기능 자체가 없다

## 전제/결정 사항

- **`Lot.remainingQty`는 동기화하지 않는다.** 여러 기기가 오프라인에서 같은 로트를 건드리면(예: 둘 다 폐기 입력) 수량 자체를 동기화할 경우 진짜 충돌이 생긴다. 대신 **`StockMovement`(추가만 되는 원장)만 동기화**하고, `remainingQty`는 각 기기가 로컬에서 그 로트의 `StockMovement` 합계로 재계산한다 — 충돌이 구조적으로 생기지 않는다.
- **중복 전송은 무해해야 한다.** 네트워크가 중간에 끊기거나 앱이 꺼지면 같은 큐 항목을 다시 보낼 수 있다 — `upsert`(같은 `syncId`면 덮어쓰기)로 처리해서, 같은 걸 두 번 보내도 서버에 중복 행이 안 생기게 한다.
- **큐는 순서대로, 하나씩, 실패하면 거기서 멈춘다(FIFO, stop-on-failure).** 로트와 그 로트의 첫 재고이동처럼 서로 참조하는 행들은 생성 순서대로 큐에 쌓이므로, 이 순서를 지켜서 하나씩 처리하면 "참조하는 품목이 아직 서버에 없는데 로트부터 올라가는" 문제가 자연스럽게 안 생긴다. 하나 실패하면 그 뒤 항목들은 건드리지 않고 다음 시도 때 이어서 한다.
- **큐는 로컬 SQLite 테이블이라 앱이 중간에 꺼져도 사라지지 않는다.** 재시작하면 안 보낸 항목이 그대로 남아있고, 거기서부터 이어서 보낸다 — 앱이 동기화 도중 종료돼도 데이터가 꼬이거나 사라지지 않는다. (단, 이건 데이터 안전성 얘기이지 "앱이 자주 꺼져도 된다"는 뜻은 아니다 — 평소 앱 안정성은 별개로 챙겨야 한다.)
- **받아오기(pull) 범위는 역할에 따라 다르다.** 품목/거래처는 매장 구분이 없는 공통 데이터라 모든 기기가 전체를 받는다. 로트/재고이동은 직원 기기는 자기 매장 것만, 사장 기기(윈도우든 폰이든 — 반응형 앱이라 기기 종류는 상관없음)는 전체 11개 매장을 받는다.
- **"보기"는 이미 오프라인이 된다.** 재고 조회 같은 화면은 처음부터 로컬 DB만 보고 그리므로, 인터넷이 없으면 마지막으로 받아온 시점의 데이터가 그대로 보인다 — 이 스펙에서 추가로 할 일은 없다.
- **동기화 시도 트리거는 단순하게 간다.** 앱 시작(로그인 직후)과, 앱이 켜져 있는 동안의 주기적 타이머(예: 60초마다) — 네트워크 연결 감지 패키지(`connectivity_plus` 등)를 새로 추가하지 않고, 실패하면 조용히 다음 시도 때 재시도하는 방식으로 충분하다고 본다.
- **Supabase RLS는 "로그인한 사람이면 전부 읽기/쓰기 가능"으로 단순하게 간다.** 매장 단위로 서버에서까지 쓰기 권한을 막는 건 지금 단계에선 과설계(YAGNI)로 본다 — 화면에서 이미 매장 기준으로 걸러서 보여주고 있고, 이 앱의 위협 모델은 외부 공격자가 아니라 내부 직원이라 서버 레벨 접근 제어의 실익이 적다.

## 아키텍처

### 로컬 스키마 추가

- `SyncQueue`(신규): `id`(로컬 PK), `tableName`(text: `suppliers`/`ingredients`/`lots`/`stock_movements`), `recordId`(int, 그 테이블의 로컬 ID), `createdAt`
- `SyncCursors`(신규): `tableName`(text, PK), `lastSyncedAt`(datetime, nullable — null이면 "한 번도 안 받아옴" = 전체를 받아와야 함)
- `schemaVersion`을 5로 올린다(8-2-1에서 4로 올려뒀음)

### 쓰기마다 큐에 기록 — DAO 안에서 처리

8-2-1에서 "각 DAO의 insert 메서드가 `syncId`를 자동으로 채운다"고 했는데, 같은 자리에서 큐에도 기록한다:

```dart
Future<int> insertSupplier(SuppliersCompanion entry) {
  return attachedDatabase.transaction(() async {
    final id = await into(suppliers).insert(
      entry.copyWith(syncId: Value(generateSyncId())),
    );
    await attachedDatabase.syncQueueDao.enqueue('suppliers', id);
    return id;
  });
}
```

`Lots`/`StockMovements`도 같은 패턴이다. `LotRepository.receiveLot`이 이미 자기 트랜잭션 안에서 `_db.lotDao.insertLot(...)`과 `_db.stockMovementDao.insertMovement(...)`를 순서대로 호출하므로, 그 트랜잭션 안에서 로트 큐 항목이 먼저, 재고이동 큐 항목이 나중에 쌓인다 — 화면이나 리포지토리는 전혀 수정할 필요가 없다.

### Push — `SyncGateway` + `SyncRepository`

8-1/1차와 같은 패턴(인터페이스 + 실제 구현 + 테스트용 가짜 구현)을 그대로 재사용한다 — `supabase_testing`이 여전히 못 쓰는 상태이기 때문이다.

```dart
abstract class SyncGateway {
  Future<void> upsert(String tableName, Map<String, dynamic> payload);
  Future<List<Map<String, dynamic>>> fetchSince(
    String tableName,
    DateTime? since, {
    String? storeId,
  });
}
```

`SyncRepository.pushPending()`은 큐를 오래된 것부터 하나씩 가져와서:
1. `tableName`+`recordId`로 로컬 행을 조회 (각 DAO의 기존 `getById`류 메서드 재사용)
2. 그 행을 서버 payload로 변환 — 로트/재고이동은 참조하는 품목/거래처/로트의 `syncId`를 찾아서 넣어야 한다(로컬 정수 FK → 참조 행의 `syncId`로 변환). `Lots`의 `storeId`는 이미 1차 때부터 UUID 문자열이라 그대로 쓴다. `remainingQty`는 payload에서 제외한다.
3. `gateway.upsert(tableName, payload)` 호출 — 성공하면 큐 항목 삭제, 실패하면 **그 자리에서 멈추고 나머지 큐는 다음 시도로 넘긴다**

### Pull — `SyncRepository.pullUpdates()`

정해진 순서(거래처 → 품목 → 로트 → 재고이동 — 참조 대상이 먼저 오게)로 테이블마다:
1. `SyncCursors`에서 그 테이블의 `lastSyncedAt` 확인
2. 역할에 따라 범위 결정 — 로트/재고이동은 직원이면 `storeId`로 필터, 사장이면 전체. 품목/거래처는 필터 없음. (재고이동 자체엔 `storeId`가 없으므로, 서버의 `stock_movements` 테이블에 그 이동이 속한 로트의 `store_id`를 push 시점에 같이 넣어둔다 — 필터링을 위한 비정규화 컬럼)
3. `gateway.fetchSince(tableName, cursor, storeId: ...)`로 가져온 각 행을:
   - 그 행의 `syncId`로 로컬에 이미 있는지 조회 (각 DAO에 `getBySyncId` 메서드 추가)
   - 있으면 건너뜀(이 모델에서 동기화 대상 필드는 사실상 불변이라 다시 쓸 이유가 없음)
   - 없으면 새 로컬 행을 만든다 — FK는 역방향으로 변환(서버가 준 `ingredient_id`가 실은 그 품목의 `syncId`이므로, 그 `syncId`를 가진 로컬 품목을 찾아 로컬 정수 ID로 바꿔 넣는다). 같은 pull 사이클 안에서 품목/거래처를 로트보다 먼저 처리하므로 참조 대상이 없을 일은 없다.
4. 받아온 행 중 가장 늦은 `createdAt`으로 `SyncCursors`를 갱신

### Supabase 쪽 설정

```sql
create table public.suppliers (
  id uuid primary key,
  name text not null,
  contact text,
  memo text,
  created_at timestamptz not null default now()
);

create table public.ingredients (
  id uuid primary key,
  name text not null,
  category text,
  base_unit text not null,
  purchase_unit text not null,
  conversion_factor double precision not null,
  is_expiry_tracked boolean not null,
  safety_stock_qty double precision,
  created_at timestamptz not null default now()
);

create table public.lots (
  id uuid primary key,
  ingredient_id uuid not null references public.ingredients(id),
  supplier_id uuid references public.suppliers(id),
  store_id uuid references public.stores(id),
  received_date timestamptz not null,
  expiry_date timestamptz,
  unit_cost double precision not null,
  created_at timestamptz not null default now()
);

create table public.stock_movements (
  id uuid primary key,
  lot_id uuid not null references public.lots(id),
  store_id uuid references public.stores(id),
  type text not null,
  quantity double precision not null,
  occurred_at timestamptz not null,
  memo text,
  created_at timestamptz not null default now()
);

alter table public.suppliers enable row level security;
alter table public.ingredients enable row level security;
alter table public.lots enable row level security;
alter table public.stock_movements enable row level security;

create policy "Authenticated users can read/write suppliers"
  on public.suppliers for all to authenticated using (true) with check (true);
create policy "Authenticated users can read/write ingredients"
  on public.ingredients for all to authenticated using (true) with check (true);
create policy "Authenticated users can read/write lots"
  on public.lots for all to authenticated using (true) with check (true);
create policy "Authenticated users can read/write stock_movements"
  on public.stock_movements for all to authenticated using (true) with check (true);
```

`lots`/`stock_movements`에 `remaining_qty`/`quantity`(로트 잔량)가 없는 걸 눈여겨볼 것 — 의도된 설계다(전제/결정 사항 참고). `stock_movements.store_id`는 로컬 테이블엔 없는 컬럼이지만, 서버 쪽엔 pull 필터링을 위해 push할 때 로트의 `storeId`를 복사해서 같이 보낸다.

### 트리거

`SyncRepository.runSync()`(push 전체 드레인 + pull 전체) 하나로 묶고, `main.dart`에서 로그인 성공 시 1회 호출 + `Timer.periodic(Duration(seconds: 60))`로 반복 호출한다. 실패(네트워크 오류 등)는 조용히 넘기고 다음 타이머에 재시도한다.

## 파일 구조

```
lib/
  data/
    local/
      tables/
        sync_queue_table.dart         # 신규
        sync_cursors_table.dart       # 신규
      daos/
        sync_queue_dao.dart           # 신규
        sync_cursor_dao.dart          # 신규
        supplier_dao.dart             # 수정: insertSupplier가 큐에도 기록 + getBySyncId 추가
        ingredient_dao.dart           # 수정: 동일 + getBySyncId
        lot_dao.dart                  # 수정: 동일 + getBySyncId
        stock_movement_dao.dart       # 수정: 동일 + getBySyncId
      database.dart                   # 수정: 새 테이블 등록, schemaVersion 5
    services/
      sync_gateway.dart               # 신규: SyncGateway 인터페이스 + SupabaseSyncGateway
    repositories/
      sync_repository.dart            # 신규: pushPending + pullUpdates
  core/
    providers/
      sync_providers.dart             # 신규
  main.dart                           # 수정: 로그인 후 동기화 트리거 시작
```

## 테스트 전략

- `SyncQueueDao`: enqueue/가장 오래된 것 가져오기/삭제
- 각 DAO의 insert 메서드: 호출하면 큐에도 한 줄 쌓이는지
- `SyncRepository.pushPending`: `FakeSyncGateway`로 — 성공 시 큐가 비는지, 실패 시 그 항목부터 멈추고 그 뒤 큐는 그대로 남는지, 같은 큐 항목을 두 번 처리해도(재시도 시뮬레이션) 로컬 상태가 달라지지 않는지
- `SyncRepository.pullUpdates`: 가짜 서버 응답으로 — 역할별 범위(직원은 자기 매장만, 사장은 전체)가 올바르게 적용되는지, 이미 로컬에 있는 `syncId`는 중복 생성 안 되는지, FK가 올바르게 로컬 ID로 역변환되는지
- 수동 확인: 실제 두 기기(또는 두 세션)로 오프라인 입고 등록 → 온라인 복귀 → 서로의 변경사항이 보이는지
