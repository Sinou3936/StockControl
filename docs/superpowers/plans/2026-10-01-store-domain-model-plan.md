# 매장(Store) 도메인 모델 1차 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 매장(Store) 엔티티를 추가하고, 직원 계정을 매장 1곳에 연결하며, 사장 전용 "매장 관리" 화면을 만든다. 재고 조회/입고 등록/마감 실사 화면을 매장 기준으로 필터링하는 작업(2차)은 포함하지 않는다.

**Architecture:** 매장 정보는 품목/거래처와 달리 처음부터 Supabase(`stores` 테이블)에 존재해야 한다 — 직원 계정(Supabase Auth)에 소속 매장을 저장해야 하기 때문이다. 로컬 Drift의 `Stores` 테이블은 서버 데이터를 읽기 전용으로 캐싱만 한다(write-through: 쓰기는 항상 서버 먼저, 성공하면 로컬에도 반영). `Lot`에 매장을 연결할 `storeId` 컬럼을 추가하되, 기존 입고 등록 화면 등 범위 밖 코드가 깨지지 않도록 **nullable**로 둔다. 8-1에서 겪은 `supabase_testing` 패키지 비호환 문제 때문에, 매장 관련 Supabase 호출도 `StoreGateway` 인터페이스(실제 구현 + 테스트용 가짜 구현) 패턴을 그대로 재사용한다.

**Tech Stack:** Flutter, Supabase(Postgres), Drift(로컬 캐시), Riverpod. 새 패키지 의존성 추가 없음(8-1에서 이미 다 설치됨).

---

## 사전 준비 (코드 작업 시작 전, 수동으로 완료)

**Supabase 대시보드 → SQL Editor**에서 아래 SQL을 실행한다:

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

**로컬 DB 초기화**: 이번 작업은 로컬 Drift 스키마가 바뀐다(Task 1 참고). 지금 로컬 DB에 든 데이터는 전부 테스트용이라 보존할 필요가 없으므로, Task 1 완료 후 `flutter run`하기 전에 로컬 `stockcontrol.sqlite` 파일을 지운다. 파일 위치는 보통 `%APPDATA%\com.example.stockcontrol\stockcontrol.sqlite` 또는 앱 실행 중 콘솔에 출력되는 DB 경로를 확인한다 — Task 1 완료 시 다시 안내한다.

---

### Task 1: 로컬 스키마 변경 — Stores 테이블, Lots/CachedProfiles 컬럼 추가

**Files:**
- Create: `lib/data/local/tables/stores_table.dart`
- Create: `lib/data/local/daos/store_dao.dart`
- Modify: `lib/data/local/tables/lots_table.dart`
- Modify: `lib/data/local/tables/cached_profiles_table.dart`
- Modify: `lib/data/local/database.dart`
- Test: `test/data/local/store_dao_test.dart`

- [ ] **Step 1: Stores 테이블 작성**

`lib/data/local/tables/stores_table.dart`:
```dart
import 'package:drift/drift.dart';

class Stores extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {id};
}
```

`id`는 로컬 autoIncrement 정수가 아니라 **Supabase가 생성한 UUID 문자열을 그대로 저장**한다 — 나중에 8-2에서 Lot을 서버와 동기화할 때 `Lot.storeId` 값이 서버 매장 ID와 이미 일치해야 하기 때문이다.

- [ ] **Step 2: StoreDao 작성**

`lib/data/local/daos/store_dao.dart`:
```dart
import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/stores_table.dart';

part 'store_dao.g.dart';

@DriftAccessor(tables: [Stores])
class StoreDao extends DatabaseAccessor<AppDatabase> with _$StoreDaoMixin {
  StoreDao(super.db);

  Future<void> upsertStore(StoresCompanion entry) =>
      into(stores).insertOnConflictUpdate(entry);

  Stream<List<Store>> watchAll() => select(stores).watch();
}
```

- [ ] **Step 3: Lots 테이블에 storeId 추가**

`lib/data/local/tables/lots_table.dart` 전체를 아래 내용으로 교체:
```dart
import 'package:drift/drift.dart';

import 'ingredients_table.dart';
import 'stores_table.dart';
import 'suppliers_table.dart';

class Lots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ingredientId => integer().references(Ingredients, #id)();
  IntColumn get supplierId =>
      integer().nullable().references(Suppliers, #id)();
  TextColumn get storeId => text().nullable().references(Stores, #id)();
  DateTimeColumn get receivedDate => dateTime()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  RealColumn get unitCost => real()();
  RealColumn get remainingQty => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

`storeId`를 **nullable**로 두는 이유: `LotsCompanion.insert(...)`를 호출하는 기존 코드(입고 등록 화면, 3~6단계에서 만든 여러 테스트)가 이미 많다. 지금 필수값으로 만들면 이번 스펙 범위 밖인 화면들까지 전부 고쳐야 한다. 매장을 실제로 선택해서 항상 값이 채워지도록 하는 건 2차(화면 연동)의 몫이다.

- [ ] **Step 4: CachedProfiles 테이블에 매장 정보 캐시 컬럼 추가**

`lib/data/local/tables/cached_profiles_table.dart` 전체를 아래 내용으로 교체:
```dart
import 'package:drift/drift.dart';

class CachedProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get role => text()();
  TextColumn get email => text()();
  TextColumn get pinHash => text()();
  TextColumn get pinSalt => text()();
  TextColumn get storeId => text().nullable()();
  TextColumn get storeName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 5: AppDatabase에 Stores/StoreDao 등록 + schemaVersion 3**

`lib/data/local/database.dart` 전체를 아래 내용으로 교체:
```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/cached_profile_dao.dart';
import 'daos/ingredient_dao.dart';
import 'daos/lot_dao.dart';
import 'daos/stock_movement_dao.dart';
import 'daos/store_dao.dart';
import 'daos/supplier_dao.dart';
import 'tables/cached_profiles_table.dart';
import 'tables/ingredients_table.dart';
import 'tables/lots_table.dart';
import 'tables/stock_movements_table.dart';
import 'tables/stores_table.dart';
import 'tables/suppliers_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Suppliers,
    Ingredients,
    Lots,
    StockMovements,
    CachedProfiles,
    Stores,
  ],
  daos: [
    SupplierDao,
    IngredientDao,
    LotDao,
    StockMovementDao,
    CachedProfileDao,
    StoreDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'stockcontrol'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) => m.createAll(),
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(cachedProfiles);
          }
        },
      );
}
```

`onUpgrade`는 1→2 마이그레이션 코드를 그대로 둔다(해롭지 않음). 2→3 전용 마이그레이션은 작성하지 않는다 — "사전 준비"에서 안내한 대로 로컬 DB 파일을 지우고 새로 시작하는 것을 전제로 한다(지금 로컬 데이터는 전부 테스트용이라고 확인함).

- [ ] **Step 6: 코드젠 실행**

Run: `dart run build_runner build`
Expected: `BUILD SUCCESSFUL`, `store_dao.g.dart`와 갱신된 `database.g.dart`/`cached_profile_dao.g.dart`/`lot_dao.g.dart` 생성됨

- [ ] **Step 7: 검증 테스트 작성**

`test/data/local/store_dao_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('upserts a store and reads it back', () async {
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-1', name: '울산점'),
    );

    final all = await db.storeDao.watchAll().first;

    expect(all, hasLength(1));
    expect(all.first.name, '울산점');
  });

  test('upsert replaces an existing store with the same id', () async {
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-1', name: '울산점'),
    );
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-1', name: '울산점(개명)'),
    );

    final all = await db.storeDao.watchAll().first;

    expect(all, hasLength(1));
    expect(all.first.name, '울산점(개명)');
  });
}
```

- [ ] **Step 8: 테스트 실행하여 통과 확인**

Run: `flutter test test/data/local/store_dao_test.dart`
Expected: PASS (2 tests passed)

- [ ] **Step 9: 기존 테스트 전체 실행 확인**

Run: `flutter test`
Expected: `Lots`/`CachedProfiles`에 컬럼이 늘었을 뿐 기존 컬럼은 그대로라 기존 테스트는 전부 그대로 PASS해야 한다.

- [ ] **Step 10: Commit**

```bash
git add lib/data/local test/data/local/store_dao_test.dart
git commit -m "feat: add Stores table and link Lots/CachedProfiles to it"
```

**로컬 DB 파일 삭제 안내**: 이 커밋 이후 `flutter run`하기 전에 기존 `stockcontrol.sqlite` 파일을 지운다 (사전 준비 참고).

---

### Task 2: StoreGateway + StoreRepository

**Files:**
- Create: `lib/data/services/store_gateway.dart`
- Create: `lib/data/repositories/store_repository.dart`
- Create: `test/support/fake_store_gateway.dart`
- Test: `test/data/repositories/store_repository_test.dart`

- [ ] **Step 1: StoreGateway 인터페이스 + 실제 구현 작성**

`lib/data/services/store_gateway.dart`:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class StoreGateway {
  Future<List<Map<String, dynamic>>> fetchAllStores();
  Future<Map<String, dynamic>> createStore(String name);
}

class SupabaseStoreGateway implements StoreGateway {
  SupabaseStoreGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> fetchAllStores() {
    return _client.from('stores').select();
  }

  @override
  Future<Map<String, dynamic>> createStore(String name) {
    return _client.from('stores').insert({'name': name}).select().single();
  }
}
```

- [ ] **Step 2: 테스트용 가짜 StoreGateway 작성**

`test/support/fake_store_gateway.dart`:
```dart
import 'package:stockcontrol/data/services/store_gateway.dart';

class FakeStoreGateway implements StoreGateway {
  final List<Map<String, dynamic>> stores = [];

  @override
  Future<List<Map<String, dynamic>>> fetchAllStores() async =>
      List.of(stores);

  @override
  Future<Map<String, dynamic>> createStore(String name) async {
    final store = {'id': 'fake-store-${stores.length + 1}', 'name': name};
    stores.add(store);
    return store;
  }
}
```

- [ ] **Step 3: 실패하는 테스트 작성**

`test/data/repositories/store_repository_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/data/repositories/store_repository.dart';

import '../../support/fake_store_gateway.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('addStore writes to the gateway and caches it locally', () async {
    final gateway = FakeStoreGateway();
    final repository = StoreRepository(gateway, db.storeDao);

    await repository.addStore('울산점');

    final cached = await db.storeDao.watchAll().first;
    expect(cached, hasLength(1));
    expect(cached.first.name, '울산점');
    expect(gateway.stores, hasLength(1));
  });

  test('refreshFromServer pulls all gateway stores into the local cache',
      () async {
    final gateway = FakeStoreGateway()
      ..stores.add({'id': 'store-1', 'name': '울산점'})
      ..stores.add({'id': 'store-2', 'name': '부산점'});
    final repository = StoreRepository(gateway, db.storeDao);

    await repository.refreshFromServer();

    final cached = await db.storeDao.watchAll().first;
    expect(cached, hasLength(2));
    expect(cached.map((s) => s.name), containsAll(['울산점', '부산점']));
  });
}
```

- [ ] **Step 4: 테스트 실행하여 실패 확인**

Run: `flutter test test/data/repositories/store_repository_test.dart`
Expected: FAIL — `lib/data/repositories/store_repository.dart` 파일이 없어 컴파일 에러

- [ ] **Step 5: StoreRepository 구현**

`lib/data/repositories/store_repository.dart`:
```dart
import '../local/daos/store_dao.dart';
import '../local/database.dart';
import '../services/store_gateway.dart';

class StoreRepository {
  StoreRepository(this._gateway, this._storeDao);

  final StoreGateway _gateway;
  final StoreDao _storeDao;

  Future<void> refreshFromServer() async {
    final rows = await _gateway.fetchAllStores();
    for (final row in rows) {
      await _storeDao.upsertStore(
        StoresCompanion.insert(
          id: row['id'] as String,
          name: row['name'] as String,
        ),
      );
    }
  }

  Future<void> addStore(String name) async {
    final row = await _gateway.createStore(name);
    await _storeDao.upsertStore(
      StoresCompanion.insert(
        id: row['id'] as String,
        name: row['name'] as String,
      ),
    );
  }

  Stream<List<Store>> watchAll() => _storeDao.watchAll();
}
```

- [ ] **Step 6: 테스트 실행하여 통과 확인**

Run: `flutter test test/data/repositories/store_repository_test.dart`
Expected: PASS (2 tests passed)

- [ ] **Step 7: Commit**

```bash
git add lib/data/services/store_gateway.dart lib/data/repositories/store_repository.dart test/support/fake_store_gateway.dart test/data/repositories/store_repository_test.dart
git commit -m "feat: add StoreGateway and StoreRepository"
```

---

### Task 3: Riverpod providers

**Files:**
- Create: `lib/core/providers/store_providers.dart`

- [ ] **Step 1: provider 작성**

`lib/core/providers/store_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/store_repository.dart';
import '../../data/services/store_gateway.dart';
import 'database_provider.dart';

final storeDaoProvider =
    Provider((ref) => ref.watch(appDatabaseProvider).storeDao);

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository(
    SupabaseStoreGateway(Supabase.instance.client),
    ref.watch(storeDaoProvider),
  );
});
```

- [ ] **Step 2: 정적 분석 확인**

Run: `flutter analyze lib/core/providers`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/core/providers/store_providers.dart
git commit -m "feat: add store providers"
```

---

### Task 4: 매장 관리 화면

**Files:**
- Create: `lib/features/store_management/store_management_screen.dart`
- Create: `lib/core/shell/store_management_route.dart`
- Test: `test/features/store_management/store_management_screen_test.dart`

- [ ] **Step 1: 실패하는 위젯 테스트 작성**

`test/features/store_management/store_management_screen_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/core/providers/store_providers.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/data/repositories/store_repository.dart';
import 'package:stockcontrol/features/store_management/store_management_screen.dart';

import '../../support/fake_store_gateway.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  testWidgets('adds a store and shows it in the list', (tester) async {
    final gateway = FakeStoreGateway();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          storeRepositoryProvider.overrideWithValue(
            StoreRepository(gateway, db.storeDao),
          ),
        ],
        child: const MaterialApp(home: StoreManagementScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('newStoreNameField')),
      '울산점',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('울산점'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/features/store_management/store_management_screen_test.dart`
Expected: FAIL — `lib/features/store_management/store_management_screen.dart` 파일이 없어 컴파일 에러

- [ ] **Step 3: 화면 구현**

`lib/features/store_management/store_management_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/store_providers.dart';
import '../../data/local/database.dart';
import '../../data/repositories/store_repository.dart';

class StoreManagementScreen extends ConsumerWidget {
  const StoreManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.watch(storeDaoProvider);
    final repository = ref.watch(storeRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('매장 관리')),
      body: StreamBuilder<List<Store>>(
        stream: dao.watchAll(),
        builder: (context, snapshot) {
          final stores = snapshot.data ?? [];
          return ListView.builder(
            itemCount: stores.length,
            itemBuilder: (context, index) {
              final store = stores[index];
              return ListTile(title: Text(store.name));
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, repository),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddDialog(
    BuildContext context,
    StoreRepository repository,
  ) async {
    final nameController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('매장 등록'),
        content: TextField(
          key: const Key('newStoreNameField'),
          controller: nameController,
          decoration: const InputDecoration(labelText: '매장 이름'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              await repository.addStore(nameController.text.trim());
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 진입 경로 helper 작성**

`lib/core/shell/store_management_route.dart`:
```dart
import 'package:flutter/material.dart';

import '../../features/store_management/store_management_screen.dart';

void pushStoreManagementScreen(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const StoreManagementScreen()),
  );
}
```

- [ ] **Step 5: 테스트 실행하여 통과 확인**

Run: `flutter test test/features/store_management/store_management_screen_test.dart`
Expected: PASS (1 test passed)

- [ ] **Step 6: Commit**

```bash
git add lib/features/store_management lib/core/shell/store_management_route.dart test/features/store_management
git commit -m "feat: add store management screen"
```

---

### Task 5: AuthGateway — 매장 정보 반영

**Files:**
- Modify: `lib/data/services/auth_gateway.dart`
- Modify: `test/support/fake_auth_gateway.dart`

- [ ] **Step 1: AuthGateway.insertProfile에 storeId 추가**

`lib/data/services/auth_gateway.dart`에서 `insertProfile` 시그니처와 `SupabaseAuthGateway` 구현을 아래로 교체:

```dart
  Future<void> insertProfile({
    required String id,
    required String displayName,
    required String role,
    String? storeId,
  });
```
(추상 메서드 시그니처 — `AuthGateway` 안)

```dart
  @override
  Future<void> insertProfile({
    required String id,
    required String displayName,
    required String role,
    String? storeId,
  }) {
    return _client.from('profiles').insert({
      'id': id,
      'display_name': displayName,
      'role': role,
      'store_id': storeId,
    });
  }
```
(`SupabaseAuthGateway` 안, 기존 `insertProfile` 구현 교체)

- [ ] **Step 2: AuthGateway.fetchProfile이 매장명도 같이 가져오도록 수정**

`SupabaseAuthGateway.fetchProfile`을 아래로 교체:

```dart
  @override
  Future<Map<String, dynamic>> fetchProfile(String userId) {
    return _client
        .from('profiles')
        .select('*, stores(name)')
        .eq('id', userId)
        .single();
  }
```

PostgREST가 `profiles.store_id → stores.id` 외래키를 보고 `stores(name)`을 중첩 객체로 넣어준다 — `store_id`가 null이면(사장 계정) `stores`도 `null`로 온다.

- [ ] **Step 3: 정적 분석 확인**

Run: `flutter analyze lib/data/services/auth_gateway.dart`
Expected: `No issues found!`

- [ ] **Step 4: FakeAuthGateway를 새 시그니처에 맞게 업데이트**

`test/support/fake_auth_gateway.dart` 전체를 아래 내용으로 교체:

```dart
import 'package:stockcontrol/data/services/auth_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.throwNetworkError = false});

  final bool throwNetworkError;
  final Map<String, _FakeUser> _usersByEmail = {};
  final Map<String, Map<String, dynamic>> _profilesById = {};

  void seedUser({
    required String id,
    required String email,
    required String password,
    required String displayName,
    required String role,
    String? storeId,
    String? storeName,
  }) {
    _usersByEmail[email] = _FakeUser(id: id, password: password);
    _profilesById[id] = {
      'id': id,
      'display_name': displayName,
      'role': role,
      'store_id': storeId,
      'stores': storeName == null ? null : {'name': storeName},
    };
  }

  @override
  Future<AuthGatewayUser> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (throwNetworkError) {
      throw AuthRetryableFetchException(message: '시뮬레이션된 네트워크 오류');
    }
    final user = _usersByEmail[email];
    if (user == null || user.password != password) {
      throw const AuthApiException('이메일 또는 PIN이 올바르지 않습니다');
    }
    return AuthGatewayUser(user.id);
  }

  @override
  Future<AuthGatewayUser> signUp({
    required String email,
    required String password,
  }) async {
    final id = 'fake-user-${_usersByEmail.length + 1}';
    _usersByEmail[email] = _FakeUser(id: id, password: password);
    return AuthGatewayUser(id);
  }

  @override
  Future<Map<String, dynamic>> fetchProfile(String userId) async {
    final profile = _profilesById[userId];
    if (profile == null) {
      throw const AuthApiException('프로필을 찾을 수 없습니다');
    }
    return profile;
  }

  @override
  Future<void> insertProfile({
    required String id,
    required String displayName,
    required String role,
    String? storeId,
  }) async {
    _profilesById[id] = {
      'id': id,
      'display_name': displayName,
      'role': role,
      'store_id': storeId,
      'stores': null,
    };
  }
}

class _FakeUser {
  _FakeUser({required this.id, required this.password});

  final String id;
  final String password;
}
```

`insertProfile`에서는 `stores: null`로 둔다 — 실제 서버도 방금 넣은 `store_id`로 매장명을 바로 조인해서 돌려주지 않고, 그 매장명은 `AddStaffScreen`이 이미 알고 있어서(드롭다운에서 고른 값) `AuthRepository.addStaff()`가 별도 파라미터로 받는다(Task 6 참고).

- [ ] **Step 5: 기존 테스트 실행 확인**

Run: `flutter test test/data/repositories/auth_repository_test.dart test/features/auth`
Expected: 아직 `AuthRepository`/`AuthResult`가 `store_id`/`stores`를 안 읽으므로 기존 테스트는 그대로 PASS (새 필드는 무시됨)

- [ ] **Step 6: Commit**

```bash
git add lib/data/services/auth_gateway.dart test/support/fake_auth_gateway.dart
git commit -m "feat: carry store info through AuthGateway"
```

---

### Task 6: AuthRepository + AddStaffScreen — 매장 정보 반영

이 태스크는 `AuthRepository.addStaff()`의 시그니처를 바꾸는 작업과, 그 시그니처를 호출하는 유일한 곳인 `AddStaffScreen`을 고치는 작업을 하나로 묶는다 — 둘을 별개 태스크로 나누면 그 사이에 `flutter analyze lib`가 깨진 채로 커밋이 남는다(이 프로젝트는 지금까지 매 커밋 전에 `flutter analyze` 클린을 확인해왔다).

**Files:**
- Modify: `lib/data/repositories/auth_repository.dart`
- Modify: `test/data/repositories/auth_repository_test.dart`
- Modify: `lib/features/auth/add_staff_screen.dart`
- Modify: `test/features/auth/add_staff_screen_test.dart`

- [ ] **Step 1: 실패하는 테스트 추가**

`test/data/repositories/auth_repository_test.dart` 맨 끝 (`}` 앞)에 아래 두 테스트를 추가:

```dart

  test('login carries the store id and name from the profile', () async {
    final gateway = FakeAuthGateway()
      ..seedUser(
        id: 'user-10',
        email: 'staff10@internal.local',
        password: '111111',
        displayName: '직원10',
        role: 'staff',
        storeId: 'store-1',
        storeName: '울산점',
      );

    final repository = AuthRepository(gateway, db.cachedProfileDao);

    final result = await repository.login(
      id: 'user-10',
      email: 'staff10@internal.local',
      pin: '111111',
    );

    expect(result.storeId, 'store-1');
    expect(result.storeName, '울산점');

    final cached = await db.cachedProfileDao.getById('user-10');
    expect(cached!.storeId, 'store-1');
    expect(cached.storeName, '울산점');
  });

  test('addStaff caches the selected store id and name for the new staff',
      () async {
    final gateway = FakeAuthGateway()
      ..seedUser(
        id: 'user-1',
        email: 'owner@internal.local',
        password: '123456',
        displayName: '사장님',
        role: 'owner',
      );

    final repository = AuthRepository(gateway, db.cachedProfileDao);

    await repository.addStaff(
      displayName: '직원1',
      pin: '111111',
      ownerEmail: 'owner@internal.local',
      ownerPin: '123456',
      storeId: 'store-1',
      storeName: '울산점',
    );

    final cachedProfiles = await db.cachedProfileDao.watchAll().first;
    final staff = cachedProfiles.singleWhere((p) => p.role == 'staff');

    expect(staff.storeId, 'store-1');
    expect(staff.storeName, '울산점');
  });
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/data/repositories/auth_repository_test.dart`
Expected: FAIL — `AuthResult`에 `storeId`/`storeName`가 없고, `addStaff`에 `storeId`/`storeName` 파라미터가 없어서 컴파일 에러

- [ ] **Step 3: AuthRepository 수정**

`lib/data/repositories/auth_repository.dart` 전체를 아래 내용으로 교체:

```dart
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/pin_hash.dart';
import '../local/daos/cached_profile_dao.dart';
import '../local/database.dart';
import '../services/auth_gateway.dart';

enum AuthOutcome { success, invalidPin, offlineNoCache }

class AuthResult {
  AuthResult({
    required this.outcome,
    this.userId,
    this.displayName,
    this.role,
    this.storeId,
    this.storeName,
  });

  final AuthOutcome outcome;
  final String? userId;
  final String? displayName;
  final String? role;
  final String? storeId;
  final String? storeName;
}

class AuthRepository {
  AuthRepository(this._gateway, this._cachedProfileDao);

  final AuthGateway _gateway;
  final CachedProfileDao _cachedProfileDao;

  Future<AuthResult> login({
    String? id,
    required String email,
    required String pin,
  }) async {
    try {
      final user = await _gateway.signInWithPassword(
        email: email,
        password: pin,
      );
      final profileRow = await _gateway.fetchProfile(user.id);
      final displayName = profileRow['display_name'] as String;
      final role = profileRow['role'] as String;
      final storeId = profileRow['store_id'] as String?;
      final storeName =
          (profileRow['stores'] as Map<String, dynamic>?)?['name'] as String?;

      final salt = generatePinSalt();
      await _cachedProfileDao.upsertProfile(
        CachedProfilesCompanion.insert(
          id: user.id,
          displayName: displayName,
          role: role,
          email: email,
          pinHash: hashPin(pin, salt),
          pinSalt: salt,
          storeId: Value(storeId),
          storeName: Value(storeName),
        ),
      );

      return AuthResult(
        outcome: AuthOutcome.success,
        userId: user.id,
        displayName: displayName,
        role: role,
        storeId: storeId,
        storeName: storeName,
      );
    } on AuthRetryableFetchException {
      if (id == null) {
        return AuthResult(outcome: AuthOutcome.offlineNoCache);
      }
      final cached = await _cachedProfileDao.getById(id);
      if (cached == null) {
        return AuthResult(outcome: AuthOutcome.offlineNoCache);
      }
      if (hashPin(pin, cached.pinSalt) == cached.pinHash) {
        return AuthResult(
          outcome: AuthOutcome.success,
          userId: cached.id,
          displayName: cached.displayName,
          role: cached.role,
          storeId: cached.storeId,
          storeName: cached.storeName,
        );
      }
      return AuthResult(outcome: AuthOutcome.invalidPin);
    } on AuthException {
      return AuthResult(outcome: AuthOutcome.invalidPin);
    }
  }

  Future<void> addStaff({
    required String displayName,
    required String pin,
    required String ownerEmail,
    required String ownerPin,
    required String storeId,
    required String storeName,
  }) async {
    final syntheticEmail =
        'staff-${DateTime.now().millisecondsSinceEpoch}@internal.local';

    final newUser = await _gateway.signUp(
      email: syntheticEmail,
      password: pin,
    );

    await _gateway.insertProfile(
      id: newUser.id,
      displayName: displayName,
      role: 'staff',
      storeId: storeId,
    );

    final salt = generatePinSalt();
    await _cachedProfileDao.upsertProfile(
      CachedProfilesCompanion.insert(
        id: newUser.id,
        displayName: displayName,
        role: 'staff',
        email: syntheticEmail,
        pinHash: hashPin(pin, salt),
        pinSalt: salt,
        storeId: Value(storeId),
        storeName: Value(storeName),
      ),
    );

    // signUp()이 세션을 방금 만든 직원 계정으로 바꿔버리므로, 사장 계정으로
    // 다시 로그인해서 세션을 복구한다.
    await _gateway.signInWithPassword(email: ownerEmail, password: ownerPin);
  }
}
```

`addStaff`가 `storeName`까지 파라미터로 받는 이유: `AddStaffScreen`이 매장 드롭다운에서 이미 이름까지 알고 있는 상태라, `AuthRepository` 안에서 다시 `StoreDao`를 조회하는 왕복을 추가하기보다 호출부에서 그대로 넘겨받는 쪽이 더 간단하다(YAGNI).

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/data/repositories/auth_repository_test.dart`
Expected: PASS (7 tests passed)

`addStaff()`의 시그니처가 바뀌었으니, 이 메서드를 호출하는 `AddStaffScreen`도 바로 이어서 고친다 — 매장을 아직 선택할 수 없는 상태로 두면 `flutter analyze lib`가 깨진 채로 커밋하게 된다.

- [ ] **Step 5: AddStaffScreen 테스트를 매장 포함 형태로 수정**

`test/features/auth/add_staff_screen_test.dart` 전체를 아래 내용으로 교체:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/features/auth/add_staff_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Widget wrap() => ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: AddStaffScreen()),
      );

  testWidgets('shows an error when name, pin, or store is missing',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.tap(find.text('추가'));
    await tester.pump();

    expect(find.text('이름, 6자리 PIN, 매장을 모두 입력하세요'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('shows seeded stores in the dropdown', (tester) async {
    await db.storeDao.upsertStore(
      StoresCompanion.insert(id: 'store-1', name: '울산점'),
    );

    await tester.pumpWidget(wrap());
    await tester.pump();

    final dropdown = tester.widget<DropdownButton<Store>>(
      find.byKey(const Key('newStaffStoreDropdown')),
    );
    expect(dropdown.items, hasLength(1));
    expect(dropdown.items!.first.value!.name, '울산점');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
```

- [ ] **Step 6: 테스트 실행하여 실패 확인**

Run: `flutter test test/features/auth/add_staff_screen_test.dart`
Expected: FAIL — 에러 메시지 문구가 달라서 첫 테스트 실패, 두 번째 테스트는 드롭다운이 없어서 실패 (그리고 `addStaff(...)` 호출에 `storeId`/`storeName`이 빠져서 컴파일 자체가 안 됨)

- [ ] **Step 7: AddStaffScreen 화면 수정**

`lib/features/auth/add_staff_screen.dart` 전체를 아래 내용으로 교체:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/store_providers.dart';
import '../../data/local/database.dart';

class AddStaffScreen extends ConsumerStatefulWidget {
  const AddStaffScreen({super.key});

  @override
  ConsumerState<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends ConsumerState<AddStaffScreen> {
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  Store? _selectedStore;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dao = ref.watch(storeDaoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('직원 추가')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('newStaffNameField'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            TextField(
              key: const Key('newStaffPinField'),
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'PIN (6자리)'),
            ),
            StreamBuilder<List<Store>>(
              stream: dao.watchAll(),
              builder: (context, snapshot) {
                final stores = snapshot.data ?? [];
                return DropdownButton<Store>(
                  key: const Key('newStaffStoreDropdown'),
                  hint: const Text('소속 매장 선택'),
                  value: _selectedStore,
                  items: [
                    for (final store in stores)
                      DropdownMenuItem(
                        value: store,
                        child: Text(store.name),
                      ),
                  ],
                  onChanged: (store) =>
                      setState(() => _selectedStore = store),
                );
              },
            ),
            if (_errorText != null)
              Text(_errorText!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _submit, child: const Text('추가')),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final pin = _pinController.text.trim();
    final store = _selectedStore;

    if (name.isEmpty || pin.length != 6 || store == null) {
      setState(() => _errorText = '이름, 6자리 PIN, 매장을 모두 입력하세요');
      return;
    }

    final owner = ref.read(authSessionProvider);
    if (owner == null) return;

    setState(() => _errorText = null);

    try {
      await ref.read(authRepositoryProvider).addStaff(
            displayName: name,
            pin: pin,
            ownerEmail: owner.email,
            ownerPin: owner.pin,
            storeId: store.id,
            storeName: store.name,
          );
    } catch (e) {
      setState(() => _errorText = '직원 추가에 실패했습니다: $e');
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }
}
```

- [ ] **Step 8: 테스트 실행하여 통과 확인**

Run: `flutter test test/features/auth/add_staff_screen_test.dart`
Expected: PASS (2 tests passed)

**실행 중 발견한 문제**: `DropdownButton`는 닫혀있는 상태에서 `hint`만 보여주고 `DropdownMenuItem`들은 메뉴를 열어야 오버레이에 렌더링된다 — 그래서 `find.text('울산점')`로는 아무것도 못 찾는다(위 코드에 이미 반영: 메뉴를 여는 대신 `tester.widget<DropdownButton<Store>>(...).items`로 직접 확인한다).

- [ ] **Step 9: 정적 분석 확인**

Run: `flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 10: Commit**

```bash
git add lib/data/repositories/auth_repository.dart test/data/repositories/auth_repository_test.dart lib/features/auth/add_staff_screen.dart test/features/auth/add_staff_screen_test.dart
git commit -m "feat: carry store info through AuthRepository and require it when adding staff"
```

---

### Task 7: AuthSession에 매장 정보 추가 + LoginScreen 반영

**Files:**
- Modify: `lib/core/providers/auth_providers.dart`
- Modify: `lib/features/auth/login_screen.dart`

- [ ] **Step 1: AuthSession에 필드 추가**

`lib/core/providers/auth_providers.dart`에서 `AuthSession` 클래스를 아래로 교체:

```dart
class AuthSession {
  AuthSession({
    required this.id,
    required this.email,
    required this.pin,
    required this.displayName,
    required this.role,
    this.storeId,
    this.storeName,
  });

  final String id;
  final String email;
  final String pin;
  final String displayName;
  final String role;
  final String? storeId;
  final String? storeName;

  bool get isOwner => role == 'owner';
}
```

- [ ] **Step 2: LoginScreen에서 세션 생성 시 매장 정보 포함**

`lib/features/auth/login_screen.dart`의 `_submit` 메서드 안, `AuthSession(...)` 생성 부분을 아래로 교체:

```dart
    if (result.outcome == AuthOutcome.success) {
      ref.read(authSessionProvider.notifier).setSession(
            AuthSession(
              id: result.userId!,
              email: email,
              pin: pin,
              displayName: result.displayName!,
              role: result.role!,
              storeId: result.storeId,
              storeName: result.storeName,
            ),
          );
      return;
    }
```

- [ ] **Step 3: 정적 분석 확인**

Run: `flutter analyze lib/core/providers lib/features/auth`
Expected: `No issues found!`

- [ ] **Step 4: 기존 테스트 실행 확인**

Run: `flutter test test/features/auth/login_screen_test.dart test/core/shell`
Expected: PASS — `AuthSession`의 새 필드는 전부 선택값(optional)이라 기존 호출부가 그대로 컴파일된다

- [ ] **Step 5: Commit**

```bash
git add lib/core/providers/auth_providers.dart lib/features/auth/login_screen.dart
git commit -m "feat: carry store info into AuthSession"
```

---

### Task 8: 진입 경로 — MoreScreen + AppShell에 "매장 관리" 추가

**Files:**
- Modify: `lib/core/shell/more_screen.dart`
- Modify: `lib/core/shell/app_shell.dart`
- Modify: `test/core/shell/more_screen_test.dart`

- [ ] **Step 1: 실패하는 테스트 추가**

`test/core/shell/more_screen_test.dart`의 `import` 목록에 아래를 추가:

```dart
import 'package:stockcontrol/features/store_management/store_management_screen.dart';
```

그리고 `logging out clears the auth session` 테스트 다음(파일 맨 끝 `}` 앞)에 아래 테스트를 추가:

```dart

  testWidgets('shows store management for an owner and navigates to it',
      (tester) async {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    container.read(authSessionProvider.notifier).setSession(
          AuthSession(
            id: 'user-1',
            email: 'owner@internal.local',
            pin: '123456',
            displayName: '사장님',
            role: 'owner',
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MoreScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('매장 관리'));
    await tester.pumpAndSettle();

    expect(find.byType(StoreManagementScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/core/shell/more_screen_test.dart`
Expected: FAIL — "매장 관리" 항목이 없어서 `find.text('매장 관리')`가 아무것도 못 찾음

- [ ] **Step 3: MoreScreen 수정**

`lib/core/shell/more_screen.dart`에서 import 목록에 추가:

```dart
import 'store_management_route.dart';
```

그리고 `직원 추가` `ListTile` 바로 앞에 아래 블록을 추가:

```dart
          if (session?.isOwner ?? false)
            ListTile(
              title: const Text('매장 관리'),
              onTap: () => pushStoreManagementScreen(context),
            ),
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/core/shell/more_screen_test.dart`
Expected: PASS (4 tests passed)

- [ ] **Step 5: AppShell 데스크톱 사이드바에 "매장 관리" 추가**

`lib/core/shell/app_shell.dart`에서 import 목록에 추가:

```dart
import 'store_management_route.dart';
```

`onDestinationSelected` 콜백을 아래로 교체:

```dart
            onDestinationSelected: (index) {
              if (isOwner && index == 5) {
                pushAddStaffScreen(context);
                return;
              }
              if (isOwner && index == 6) {
                pushStoreManagementScreen(context);
                return;
              }
              setState(() => _selectedIndex = index);
            },
```

`destinations` 리스트의 "직원 추가" 항목 바로 다음에 추가:

```dart
              if (isOwner)
                const NavigationRailDestination(
                  icon: Icon(Icons.store_mall_directory_outlined),
                  label: Text('매장 관리'),
                ),
```

- [ ] **Step 6: 정적 분석 + 전체 테스트 확인**

Run: `flutter analyze lib`
Expected: `No issues found!`

Run: `flutter test`
Expected: 8-1 끝낸 시점의 63개에 이번 스펙에서 늘어난 9개(StoreDao +2, StoreRepository +2, StoreManagementScreen +1, AuthRepository +2, AddStaffScreen +1 — 기존 1개가 2개로 바뀜, MoreScreen +1)를 더해 총 72개 통과

- [ ] **Step 7: Commit**

```bash
git add lib/core/shell test/core/shell/more_screen_test.dart
git commit -m "feat: add store management entry points to more screen and app shell"
```

---

### Task 9: 수동 확인 (실제 Supabase 프로젝트 대상)

- [ ] **Step 1**: 로컬 `stockcontrol.sqlite` 파일을 지우고 `flutter run -d windows`(또는 `chrome`) 실행
- [ ] **Step 2**: 로그인 후 "매장 관리" 화면에서 매장을 1~2개 추가 — 추가한 매장이 목록에 바로 뜨는지, Supabase 대시보드의 `stores` 테이블에도 실제로 들어갔는지 확인
- [ ] **Step 3**: "직원 추가" 화면에서 방금 만든 매장이 드롭다운에 뜨는지, 매장을 선택하지 않고 추가를 누르면 에러가 뜨는지 확인
- [ ] **Step 4**: 매장을 선택해서 직원을 추가하고, Supabase 대시보드의 `profiles` 테이블에서 그 직원의 `store_id`가 제대로 들어갔는지 확인
- [ ] **Step 5**: 그 직원 계정으로 로그아웃 후 다시 로그인해서 정상적으로 로그인되는지 확인 (매장 조인 쿼리가 깨지지 않았는지 확인하는 셈)

---

## Self-Review 결과

**스펙 커버리지**: `stores` 테이블 + RLS — 사전 준비(수동) / 로컬 `Stores`/`Lots.storeId`/`CachedProfiles` 캐시 컬럼 — Task 1 / `StoreGateway`+`StoreRepository`(write-through) — Task 2 / Riverpod providers — Task 3 / 매장 관리 화면(사장 전용) — Task 4·8 / 직원 계정-매장 연결(`AuthGateway`/`AuthRepository`/`AuthSession`/`AddStaffScreen`) — Task 5~7 / 범위 밖 항목(재고 조회/입고 등록/마감 실사 화면 매장 필터링, 매장 선택 전환·합산 보기, 실데이터 동기화, 매장 수정·삭제) — 이번 계획에 포함하지 않음, 스펙과 일치.

**타입 일관성 확인**: `AuthResult(outcome, userId, displayName, role, storeId, storeName)`이 Task 6에서 정의된 그대로 Task 6 자신(`AddStaffScreen`은 `AuthResult`를 직접 안 쓰지만 `addStaff`의 `storeId`/`storeName` 파라미터가 일치)과 Task 7(`LoginScreen`의 `AuthSession` 생성)에서 동일하게 쓰인다. `AuthRepository.addStaff({displayName, pin, ownerEmail, ownerPin, storeId, storeName})` 시그니처가 같은 Task 6 안의 `AddStaffScreen` 호출부와 일치 — 시그니처 변경과 호출부 수정을 한 태스크로 묶어서, 두 태스크 사이에 `flutter analyze`가 깨진 채로 커밋되는 중간 상태가 생기지 않는다(자가 검토 중 발견해서 Task 6으로 합쳤다). `AuthGateway.insertProfile`의 `storeId` 파라미터가 `SupabaseAuthGateway`/`FakeAuthGateway` 양쪽에 동일하게 반영됨. `Store`(Drift 생성 클래스)의 `id`/`name` 필드가 `StoreDao`/`StoreRepository`/`StoreManagementScreen`/`AddStaffScreen`에서 전부 동일하게 쓰임.

**스키마 변경의 하위 호환**: `Lots.storeId`를 nullable로 둬서 3~6단계에서 만든 기존 `LotsCompanion.insert(...)` 호출부(입고 등록 화면, 여러 테스트)가 전혀 깨지지 않는다 — 실제로 Task 1 Step 9에서 `flutter test` 전체 실행으로 이를 확인한다. `CachedProfiles.storeId`/`storeName`과 `AuthSession.storeId`/`storeName`도 전부 nullable/optional이라 8-1에서 만든 기존 로그인 테스트가 그대로 통과한다(Task 7 Step 4에서 확인).
