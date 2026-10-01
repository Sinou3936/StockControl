# 재고관리 앱 — 매장(Store) 도메인 모델 1차: 스토어 모델 + 관리 화면 스펙

## 배경

프로젝트는 처음부터 "단일 매장, location 개념 없음"을 전제로 설계됐다(1단계 도메인 모델 스펙 참고). 그런데 실제로는 **매장이 11곳**이고, 각 매장이 재고를 독립적으로 관리하면서도 본사 차원의 합산 보고가 필요하다는 사실이 뒤늦게 확인됐다 — 실제 거래명세서 참고자료(특정 매장의 월별 거래처별 입출고 내역)로도 매장별 독립 운영 구조가 재확인됐다.

이 작업은 범위가 커서 두 단계로 나눈다:
- **1차 (이 스펙)**: 매장 도메인 모델 + 관리 화면 + 직원 계정과 매장 연결
- **2차 (별도 스펙)**: 기존 화면(재고 조회/입고 등록/마감 실사)을 매장 기준으로 필터링, 사장님의 매장 선택/전체 합산 보기

## 이번 스펙의 범위

- Supabase `stores` 테이블 + RLS
- `profiles` 테이블에 `store_id` 컬럼 추가
- 로컬 Drift에 `Stores` 테이블(서버 캐싱용) + `Lots.storeId` 컬럼 추가
- `CachedProfiles`에 `storeId`/`storeName` 캐싱
- 사장 전용 "매장 관리" 화면 (매장 추가/조회)
- "직원 추가" 화면에 소속 매장 선택 추가
- `AuthRepository`/`AuthSession`에 매장 정보 통합

**범위 밖** (2차 이후):
- 재고 조회/입고 등록/마감 실사 화면을 매장 기준으로 필터링
- 사장님의 매장 선택 전환 UI, 여러 매장 합산 보기 화면
- 품목/거래처/로트/재고이동 데이터 자체의 서버 동기화 (8-2, 여전히 별도 작업)
- 매장 정보 수정/삭제 (이번엔 추가/조회만 — 매장이 잘못 등록된 경우는 Supabase 대시보드에서 직접 수정)

## 전제/결정 사항

- **품목/거래처는 그대로 공통(전사 공유) 마스터데이터**다 — 매장마다 복제하지 않는다. 그래야 본사가 "전체 생수 재고 합계" 같은 집계를 품목 단위로 의미 있게 뽑을 수 있다.
- **실제 재고(Lot)는 매장별로 분리**된다 — 같은 품목이라도 매장마다 별개의 Lot으로 존재하고, `Lot.storeId`로 소속 매장을 구분한다. `StockMovement`는 `lotId`를 통해 간접적으로 매장이 정해지므로 별도 컬럼을 추가하지 않는다.
- **직원은 매장 1곳에 소속**되고 그 매장 재고만 다룬다. **사장은 특정 매장을 선택해서 그 매장 기준으로 직접 작업할 수도 있고, 전체 매장 합산 보고서도 볼 수 있어야 한다** — 이 두 가지 사장님 기능 자체(선택 전환 UI, 합산 화면)는 2차에서 구현하지만, 그걸 가능하게 하는 데이터 구조(매장 목록, 직원-매장 연결)는 1차에서 미리 갖춰둔다.
- **사장님 기기도 11개 매장 전체 데이터를 로컬에 다 들고 있는 방향**으로 간다(오프라인에서도 합산 가능). 이 앱의 재고 기록은 숫자/텍스트 위주라 11개 매장을 합쳐도 데이터량이 크지 않고, 8-2에서 어차피 "새 기록이 생길 때마다 조금씩 보내는" 증분 동기화로 설계할 예정이라 한 번에 다 받는 부담도 없다.
- **매장 목록은 앱 안에서 사장이 직접 관리**한다(거래처/품목처럼) — Supabase 대시보드에서 개발자가 수동으로 넣는 방식은 매장이 늘어나거나 바뀔 때마다 개발자를 거쳐야 해서 비효율적이다.
- **매장 정보는 다른 재고 데이터와 달리 처음부터 서버(Supabase)에 있어야 한다.** 품목/거래처/로트/재고이동은 전부 로컬에만 있고 서버 동기화가 아직 없는 상태(8-2 몫)지만, 매장만은 예외다 — 직원 계정(Supabase Auth, `profiles` 테이블)에 "소속 매장"을 저장하려면 그 매장 ID가 모든 기기에서 동일하게 통해야 하기 때문이다. 로컬 `Stores` 테이블은 이 서버 데이터를 읽기 전용으로 캐싱해두는 역할만 한다.
- **로컬 매장 ID는 Supabase가 생성하는 UUID 문자열을 그대로 쓴다** (로컬 Drift의 autoIncrement 정수 ID가 아님) — 나중에 8-2에서 Lot/StockMovement 자체를 서버와 동기화할 때, 지금 로컬에 넣어둔 `Lot.storeId` 값이 서버의 매장 ID와 이미 일치하도록 미리 맞춰두기 위해서다.
- **지금 로컬 DB의 데이터는 전부 테스트용이라 보존할 필요가 없다** — 그래서 이번 스키마 변경은 기존 데이터를 보존하는 정교한 마이그레이션(`onUpgrade`) 대신, 로컬 DB 파일을 지우고 새로 시작하는 방식으로 간다. (실제 서비스를 시작한 이후였다면 8-1 때처럼 `onUpgrade`로 조심스럽게 마이그레이션했을 것이다.)
- **Supabase 연동 테스트는 8-1에서 만든 패턴을 재사용**한다 — `supabase_testing` 패키지가 현재 쓰는 `supabase_flutter` 안정 버전과 호환되지 않는다는 걸 8-1에서 이미 확인했으므로, 매장 관련 Supabase 호출도 직접 정의한 `StoreGateway` 인터페이스(실제 구현 + 테스트용 가짜 구현)로 감싼다.

## 아키텍처

### Supabase 쪽 설정 (SQL Editor에서 실행)

```sql
create table public.stores (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

alter table public.stores enable row level security;

create policy "Authenticated users can read all stores"
  on public.stores for select
  to authenticated
  using (true);

create policy "Owners can insert stores"
  on public.stores for insert
  to authenticated
  with check (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'owner'
    )
  );

alter table public.profiles
  add column store_id uuid references public.stores(id);
```

`profiles.store_id`는 사장이면 `null`(전체 매장 의미), 직원이면 소속 매장의 UUID다. DB 레벨에서 "직원은 반드시 store_id가 있어야 한다"는 제약은 걸지 않고 앱 쪽(`AddStaffScreen`의 필수 선택)에서 보장한다 — 과하게 엄격한 DB 제약은 지금 단계에서 YAGNI로 판단했다.

### 로컬 Drift 스키마

- `Stores` 테이블(신규): `id`(text, PK, Supabase UUID), `name`(text) — 서버 데이터를 그대로 캐싱만 하는 읽기 전용 테이블
- `Lots` 테이블: `storeId`(text, `Stores` 참조, **nullable**) 컬럼 추가 — `LotsCompanion.insert(...)`를 호출하는 기존 코드(입고 등록 화면, 3~6단계에서 만든 여러 테스트)가 이미 많아서, 지금 바로 필수값으로 만들면 이번 스펙의 범위를 벗어난 화면들까지 전부 고쳐야 한다. 매장 선택을 실제로 반영해서 항상 값이 채워지도록 하는 건 2차(화면 연동)의 몫이다.
- `CachedProfiles` 테이블: `storeId`(text, nullable), `storeName`(text, nullable) 컬럼 추가 — 오프라인 상태에서도 "내가 어느 매장 소속인지" 보여줄 수 있도록
- `schemaVersion`을 3으로 올리고, 이번엔 기존 데이터 보존용 `onUpgrade` 마이그레이션을 작성하지 않는다 — 대신 로컬 `stockcontrol.sqlite` 파일을 수동으로 삭제하고 앱을 다시 실행하라고 안내한다 (전제/결정 사항 참고).

### 매장 동기화 (StoreGateway / StoreRepository)

```dart
abstract class StoreGateway {
  Future<List<Map<String, dynamic>>> fetchAllStores();
  Future<Map<String, dynamic>> createStore(String name);
}
```

- `SupabaseStoreGateway`: `_client.from('stores').select()` / `.insert({...}).select().single()`으로 실제 구현
- `FakeStoreGateway`(테스트용): 인메모리 리스트로 동일한 동작을 흉내냄
- `StoreRepository`: `StoreGateway`로 서버에 쓰고, 성공하면 로컬 `StoreDao`에도 반영(write-through) — 조회는 항상 로컬 `StoreDao.watchAll()`을 통해 하므로 오프라인에서도 매장 목록을 볼 수 있다. 앱 시작 시(또는 매장 관리 화면 진입 시) `refreshFromServer()`를 호출해 서버 최신 목록을 로컬에 동기화한다.

### 인증 연동

- `AuthGateway.fetchProfile(userId)`: Supabase 조회 시 `stores` 테이블을 조인해서 매장명도 함께 가져오도록 수정 (`select('*, stores(name)')`)
- `AuthGateway.insertProfile(...)`에 `storeId` 파라미터 추가 (사장이 아닌 직원 생성 시 필수)
- `AuthRepository.login()`: 캐싱할 때 `storeId`/`storeName`도 `CachedProfiles`에 같이 저장
- `AuthRepository.addStaff(...)`에 `required String storeId` 파라미터 추가
- `AuthSession`(Riverpod 상태)에 `storeId`, `storeName` 필드 추가 — 2차에서 재고 조회/입고 등록 화면이 이 값을 읽어 필터링하게 된다. `isOwner`는 기존 그대로 유지.

### 매장 관리 화면 (`StoreManagementScreen`)

- 거래처 관리 화면(`SupplierListScreen`)과 같은 패턴: 목록 + 이름 입력 폼으로 추가
- `StoreRepository`를 통해 추가(서버 insert + 로컬 캐시 갱신)
- 사장 전용 — `MoreScreen`(모바일)과 `AppShell` 데스크톱 사이드바에 "직원 추가"와 같은 조건(`session?.isOwner ?? false`)으로 진입 항목 추가

### 직원 추가 화면 변경

- 로컬 `Stores` 캐시를 드롭다운으로 보여주고 매장 선택을 필수로 받는다
- 매장을 선택하지 않으면 에러 메시지로 막는다 (기존 이름/PIN 검증과 같은 자리에 추가)
- `AuthRepository.addStaff()` 호출 시 선택한 매장의 ID를 전달

## 파일 구조

```
lib/
  data/
    local/
      tables/
        stores_table.dart            # 신규: Stores 테이블
      daos/
        store_dao.dart                # 신규: Store CRUD/watch
      database.dart                   # 수정: Stores 테이블/DAO 등록, schemaVersion 3
    services/
      store_gateway.dart              # 신규: StoreGateway 인터페이스 + SupabaseStoreGateway
    repositories/
      store_repository.dart           # 신규: 서버 write-through + 로컬 캐시
      auth_repository.dart            # 수정: login/addStaff에 storeId 반영
  core/
    providers/
      store_providers.dart            # 신규: storeDaoProvider, storeRepositoryProvider
      auth_providers.dart             # 수정: AuthSession에 storeId/storeName
  features/
    store_management/
      store_management_screen.dart    # 신규
    auth/
      add_staff_screen.dart           # 수정: 매장 선택 드롭다운 추가
  core/
    shell/
      more_screen.dart                # 수정: "매장 관리" 항목 추가 (사장 전용)
      app_shell.dart                  # 수정: 데스크톱 사이드바에 "매장 관리" 추가 (사장 전용)
```

## 테스트 전략

- `StoreDao`: upsert/watch 단위 테스트 (기존 `CachedProfileDao` 테스트와 같은 패턴)
- `StoreRepository`: `FakeStoreGateway`로 매장 생성/조회 경로 테스트, 서버 실패 시 로컬 캐시는 그대로 유지되는지 확인
- `AuthRepository`: 기존 `login`/`addStaff` 테스트에 `storeId`/`storeName` 캐싱·전달 검증 추가 (`FakeAuthGateway`의 프로필 데이터에 `store_id`/매장명 필드 반영)
- `StoreManagementScreen`, `AddStaffScreen` 위젯 테스트: 매장 목록 표시, 매장 미선택 시 에러 처리
