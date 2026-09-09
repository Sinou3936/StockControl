# 백엔드 설정 + PIN 로그인 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Supabase 백엔드를 연결하고, 이름 선택 + 6자리 PIN으로 로그인하는 화면(온라인/오프라인 모두 동작)과 사장 전용 "직원 추가" 화면을 추가한다.

**Architecture:** Supabase Auth를 "가짜 이메일 + PIN을 비밀번호로 사용"하는 방식으로 감싼다. 로그인 성공 시 PIN을 해시해서 로컬 Drift DB에 캐싱해두고, 네트워크 오류로 온라인 로그인이 안 될 때는 이 로컬 캐시로 대체한다. `AuthRepository`가 이 온라인/오프라인 전환 로직을 전담하고, 화면은 그 결과만 보고 반응한다.

**Tech Stack:** Flutter, Supabase(Auth + Postgres), Drift(로컬 캐시), Riverpod, `crypto`(해시). 테스트용 Supabase 대체물은 별도 패키지 없이, 이 계획에서 직접 정의하는 `AuthGateway` 인터페이스와 그 가짜 구현(`FakeAuthGateway`)으로 충당한다 — 실행 중 발견한 변경사항 참고.

---

## 사전 준비 (코드 작업 시작 전, 수동으로 완료됨)

- Supabase 프로젝트: `https://nrgrqxzpzliolkgacfmj.supabase.co`
- anon key(공개 가능, JWT의 `role` 클레임이 `anon`인 것을 직접 디코딩해서 확인함):
  `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5yZ3JxeHpwemxpb2xrZ2FjZm1qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5NzQ5OTgsImV4cCI6MjA4OTU1MDk5OH0.h5SprHQg8odLyueLSypX9Hin1XQnvRrnxARzhk4ZDjg`

**Task 1 시작 전에 Supabase 대시보드에서 아래를 수동으로 설정해야 한다** (앱 코드가 아니라 Supabase 프로젝트 설정):

1. **Authentication → Providers → Email**: "Confirm email" 옵션을 끈다 (내부용 가짜 이메일은 실제 수신함이 없어 인증 메일을 확인할 수 없음)
2. **Authentication → Providers → Email → Password**: "Minimum password length"를 확인한다 — Supabase 대시보드는 6 미만으로 낮출 수 없으므로 6으로 맞춘다 (PIN도 4자리 대신 6자리 숫자로 결정)
3. **SQL Editor**에서 아래 SQL 실행:
   ```sql
   create table public.profiles (
     id uuid primary key references auth.users(id) on delete cascade,
     display_name text not null,
     role text not null check (role in ('owner', 'staff')),
     created_at timestamptz not null default now()
   );

   alter table public.profiles enable row level security;

   create policy "Authenticated users can read all profiles"
     on public.profiles for select
     to authenticated
     using (true);

   create policy "Users can insert their own profile"
     on public.profiles for insert
     to authenticated
     with check (auth.uid() = id);
   ```
4. **Authentication → Users → Add user**로 사장 계정을 1개 만든다 (예: 이메일 `owner@internal.local`, 비밀번호로 6자리 PIN 입력, "Auto Confirm User" 체크)
5. **SQL Editor**에서 방금 만든 사장 계정의 `profiles` 행을 하나 만든다 (아래 SQL의 `<owner-user-id>`는 3번 단계에서 만든 사용자의 UUID로 교체 — Authentication → Users 목록에서 확인 가능):
   ```sql
   insert into public.profiles (id, display_name, role)
   values ('<owner-user-id>', '사장님', 'owner');
   ```

---

## 실행 중 발견한 변경사항

Task 1 진행 중, `supabase_testing`(0.1.1)이 아직 정식 출시되지 않은 `supabase` 3.0.0-dev 프리릴리스에만 의존한다는 사실이 드러났다 — 우리가 쓰는 안정 버전 `supabase_flutter`(2.17.2)는 `supabase` 2.16.1에 의존하므로, 이 둘을 동시에 pubspec에 넣는 것 자체가 버전 충돌로 불가능하다(`flutter pub add --dev supabase_testing http` 실행 시 즉시 실패로 확인됨). 새로 나온 패키지라 아직 안정 버전 라인을 지원하지 않는 상태로 보인다.

그래서 Task 4 이후 계획을 다음과 같이 바꿨다:
- `AuthRepository`가 `SupabaseClient`를 직접 들고 있는 대신, 이 계획에서 직접 정의하는 작은 인터페이스 `AuthGateway`(로그인/회원가입/프로필 조회·삽입 4개 메서드)에 의존하도록 한다.
- 실제 앱에서는 `SupabaseAuthGateway`(Supabase SDK를 감싼 구현)를 쓰고, 테스트에서는 `test/support/fake_auth_gateway.dart`에 정의하는 순수 인메모리 `FakeAuthGateway`를 쓴다 — HTTP 레이어를 흉내 낼 필요 없이 로그인 성공/네트워크 오류(`AuthRetryableFetchException`)/PIN 불일치(`AuthApiException`) 세 시나리오를 직접 제어할 수 있다.
- 새 의존성 추가 없이(추가 mocking 라이브러리 없이) 기존 Drift 테스트들과 같은 스타일(진짜 객체 대신 손으로 만든 가짜 구현)을 유지한다.

---

### Task 1: 의존성 추가 + Supabase 설정 + AuthGateway 인터페이스

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/config/supabase_config.dart`
- Create: `lib/data/services/auth_gateway.dart`

- [ ] **Step 1: 런타임 의존성 추가**

Run:
```bash
flutter pub add supabase_flutter crypto
```

- [ ] **Step 2: Supabase 설정 상수 파일 작성**

`lib/core/config/supabase_config.dart`:
```dart
const supabaseUrl = 'https://nrgrqxzpzliolkgacfmj.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5yZ3JxeHpwemxpb2xrZ2FjZm1qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5NzQ5OTgsImV4cCI6MjA4OTU1MDk5OH0.h5SprHQg8odLyueLSypX9Hin1XQnvRrnxARzhk4ZDjg';
```

- [ ] **Step 3: AuthGateway 인터페이스 + 실제 구현 작성**

`lib/data/services/auth_gateway.dart`:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGatewayUser {
  AuthGatewayUser(this.id);

  final String id;
}

abstract class AuthGateway {
  Future<AuthGatewayUser> signInWithPassword({
    required String email,
    required String password,
  });

  Future<AuthGatewayUser> signUp({
    required String email,
    required String password,
  });

  Future<Map<String, dynamic>> fetchProfile(String userId);

  Future<void> insertProfile({
    required String id,
    required String displayName,
    required String role,
  });
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<AuthGatewayUser> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw const AuthApiException('로그인에 실패했습니다');
    }
    return AuthGatewayUser(user.id);
  }

  @override
  Future<AuthGatewayUser> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(email: email, password: password);
    final user = response.user;
    if (user == null) {
      throw const AuthApiException('계정 생성에 실패했습니다');
    }
    return AuthGatewayUser(user.id);
  }

  @override
  Future<Map<String, dynamic>> fetchProfile(String userId) {
    return _client.from('profiles').select().eq('id', userId).single();
  }

  @override
  Future<void> insertProfile({
    required String id,
    required String displayName,
    required String role,
  }) {
    return _client.from('profiles').insert({
      'id': id,
      'display_name': displayName,
      'role': role,
    });
  }
}
```

`AuthGateway`는 순수 인터페이스라 이 파일 자체에는 단위 테스트를 붙이지 않는다 — `SupabaseAuthGateway`는 실제 네트워크 없이는 검증할 수 없고(수동 확인은 Task 8에서 진행), 분기 로직(성공/실패)의 테스트는 Task 4에서 `FakeAuthGateway`로 검증한다.

- [ ] **Step 4: 정적 분석 확인**

Run: `flutter analyze lib/data/services/auth_gateway.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/config/supabase_config.dart lib/data/services/auth_gateway.dart
git commit -m "chore: add Supabase dependency and AuthGateway abstraction"
```

---

### Task 2: 도메인 로직 — PIN 해시

**Files:**
- Create: `lib/domain/pin_hash.dart`
- Test: `test/domain/pin_hash_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/domain/pin_hash_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/domain/pin_hash.dart';

void main() {
  group('hashPin', () {
    test('produces the same hash for the same pin and salt', () {
      expect(hashPin('1234', 'salt-a'), hashPin('1234', 'salt-a'));
    });

    test('produces different hashes for different pins', () {
      expect(hashPin('1234', 'salt-a'), isNot(hashPin('5678', 'salt-a')));
    });

    test('produces different hashes for different salts', () {
      expect(hashPin('1234', 'salt-a'), isNot(hashPin('1234', 'salt-b')));
    });
  });

  group('generatePinSalt', () {
    test('produces a non-empty string', () {
      expect(generatePinSalt(), isNotEmpty);
    });

    test('produces different values on each call', () {
      expect(generatePinSalt(), isNot(generatePinSalt()));
    });
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/domain/pin_hash_test.dart`
Expected: FAIL — `lib/domain/pin_hash.dart` 파일이 없어 컴파일 에러

- [ ] **Step 3: 최소 구현 작성**

`lib/domain/pin_hash.dart`:
```dart
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

String hashPin(String pin, String salt) {
  final bytes = utf8.encode('$salt:$pin');
  return sha256.convert(bytes).toString();
}

String generatePinSalt() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/domain/pin_hash_test.dart`
Expected: PASS (5 tests passed)

- [ ] **Step 5: Commit**

```bash
git add lib/domain/pin_hash.dart test/domain/pin_hash_test.dart
git commit -m "feat: add PIN hashing domain logic"
```

---

### Task 3: 오프라인 로그인 캐시 테이블

**Files:**
- Create: `lib/data/local/tables/cached_profiles_table.dart`
- Create: `lib/data/local/daos/cached_profile_dao.dart`
- Modify: `lib/data/local/database.dart`
- Test: `test/data/local/cached_profile_dao_test.dart`

- [ ] **Step 1: 테이블 작성**

`lib/data/local/tables/cached_profiles_table.dart`:
```dart
import 'package:drift/drift.dart';

class CachedProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get role => text()();
  TextColumn get email => text()();
  TextColumn get pinHash => text()();
  TextColumn get pinSalt => text()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 2: DAO 작성**

`lib/data/local/daos/cached_profile_dao.dart`:
```dart
import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/cached_profiles_table.dart';

part 'cached_profile_dao.g.dart';

@DriftAccessor(tables: [CachedProfiles])
class CachedProfileDao extends DatabaseAccessor<AppDatabase>
    with _$CachedProfileDaoMixin {
  CachedProfileDao(super.db);

  Future<void> upsertProfile(CachedProfilesCompanion entry) =>
      into(cachedProfiles).insertOnConflictUpdate(entry);

  Future<CachedProfile?> getById(String id) =>
      (select(cachedProfiles)..where((p) => p.id.equals(id)))
          .getSingleOrNull();

  Stream<List<CachedProfile>> watchAll() => select(cachedProfiles).watch();
}
```

- [ ] **Step 3: AppDatabase에 테이블/DAO 등록 + 마이그레이션 추가**

`lib/data/local/database.dart` 전체를 아래 내용으로 교체:

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/cached_profile_dao.dart';
import 'daos/ingredient_dao.dart';
import 'daos/lot_dao.dart';
import 'daos/stock_movement_dao.dart';
import 'daos/supplier_dao.dart';
import 'tables/cached_profiles_table.dart';
import 'tables/ingredients_table.dart';
import 'tables/lots_table.dart';
import 'tables/stock_movements_table.dart';
import 'tables/suppliers_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Suppliers, Ingredients, Lots, StockMovements, CachedProfiles],
  daos: [
    SupplierDao,
    IngredientDao,
    LotDao,
    StockMovementDao,
    CachedProfileDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'stockcontrol'));

  @override
  int get schemaVersion => 2;

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

이 마이그레이션이 중요한 이유: 이미 실제로 이 앱을 설치해서 쓰고 있다면(개발 중인 Windows PC 포함) 로컬에 `stockcontrol.sqlite` 파일이 이미 존재하고 `schemaVersion`이 1로 저장되어 있다. `onUpgrade`가 없으면 새 버전을 설치했을 때 `CachedProfiles` 테이블이 생성되지 않고 에러가 난다.

- [ ] **Step 4: 코드젠 실행**

Run: `dart run build_runner build`
Expected: `BUILD SUCCESSFUL`, `cached_profile_dao.g.dart`와 갱신된 `database.g.dart` 생성됨

- [ ] **Step 5: 검증 테스트 작성**

`test/data/local/cached_profile_dao_test.dart`:
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

  test('upserts a profile and reads it back by id', () async {
    await db.cachedProfileDao.upsertProfile(
      CachedProfilesCompanion.insert(
        id: 'user-1',
        displayName: '테스터',
        role: 'owner',
        email: 'user-1@internal.local',
        pinHash: 'hash-a',
        pinSalt: 'salt-a',
      ),
    );

    final profile = await db.cachedProfileDao.getById('user-1');

    expect(profile, isNotNull);
    expect(profile!.displayName, '테스터');
    expect(profile.role, 'owner');
  });

  test('upsert replaces an existing profile with the same id', () async {
    await db.cachedProfileDao.upsertProfile(
      CachedProfilesCompanion.insert(
        id: 'user-1',
        displayName: '테스터',
        role: 'owner',
        email: 'user-1@internal.local',
        pinHash: 'hash-a',
        pinSalt: 'salt-a',
      ),
    );
    await db.cachedProfileDao.upsertProfile(
      CachedProfilesCompanion.insert(
        id: 'user-1',
        displayName: '테스터',
        role: 'owner',
        email: 'user-1@internal.local',
        pinHash: 'hash-b',
        pinSalt: 'salt-b',
      ),
    );

    final profile = await db.cachedProfileDao.getById('user-1');
    expect(profile!.pinHash, 'hash-b');

    final all = await db.cachedProfileDao.watchAll().first;
    expect(all, hasLength(1));
  });
}
```

- [ ] **Step 6: 테스트 실행하여 통과 확인**

Run: `flutter test test/data/local/cached_profile_dao_test.dart`
Expected: PASS (2 tests passed)

- [ ] **Step 7: Commit**

```bash
git add lib/data/local test/data/local/cached_profile_dao_test.dart
git commit -m "feat: add local cache table for offline PIN login"
```

---

### Task 4: AuthRepository — 로그인 (온라인/오프라인)

**Files:**
- Create: `lib/data/repositories/auth_repository.dart`
- Create: `test/support/fake_auth_gateway.dart`
- Test: `test/data/repositories/auth_repository_test.dart`

- [ ] **Step 1: 테스트용 가짜 AuthGateway 작성**

`test/support/fake_auth_gateway.dart`:
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
  }) {
    _usersByEmail[email] = _FakeUser(id: id, password: password);
    _profilesById[id] = {'id': id, 'display_name': displayName, 'role': role};
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
  }) async {
    _profilesById[id] = {'id': id, 'display_name': displayName, 'role': role};
  }
}

class _FakeUser {
  _FakeUser({required this.id, required this.password});

  final String id;
  final String password;
}
```

`FakeAuthGateway`는 `test/support/`에 두고 이후 Task 6의 위젯 테스트에서도 그대로 재사용한다 — `seedUser()`로 "서버에 이미 존재하는 사용자"를 등록해두고, `throwNetworkError: true`로 네트워크 실패 시나리오를 재현한다.

- [ ] **Step 2: 실패하는 테스트 작성**

`test/data/repositories/auth_repository_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/data/repositories/auth_repository.dart';
import 'package:stockcontrol/domain/pin_hash.dart';

import '../../support/fake_auth_gateway.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('login succeeds online and caches the profile locally', () async {
    final gateway = FakeAuthGateway()
      ..seedUser(
        id: 'user-1',
        email: 'owner@internal.local',
        password: '123456',
        displayName: '사장님',
        role: 'owner',
      );

    final repository = AuthRepository(gateway, db.cachedProfileDao);

    final result = await repository.login(
      id: 'user-1',
      email: 'owner@internal.local',
      pin: '123456',
    );

    expect(result.outcome, AuthOutcome.success);
    expect(result.displayName, '사장님');
    expect(result.role, 'owner');

    final cached = await db.cachedProfileDao.getById('user-1');
    expect(cached, isNotNull);
    expect(cached!.displayName, '사장님');
  });

  test('falls back to the local cache when the network is unavailable',
      () async {
    await db.cachedProfileDao.upsertProfile(
      CachedProfilesCompanion.insert(
        id: 'user-2',
        displayName: '직원1',
        role: 'staff',
        email: 'staff1@internal.local',
        pinHash: hashPin('567890', 'fixed-salt'),
        pinSalt: 'fixed-salt',
      ),
    );

    final gateway = FakeAuthGateway(throwNetworkError: true);
    final repository = AuthRepository(gateway, db.cachedProfileDao);

    final result = await repository.login(
      id: 'user-2',
      email: 'staff1@internal.local',
      pin: '567890',
    );

    expect(result.outcome, AuthOutcome.success);
    expect(result.displayName, '직원1');
    expect(result.role, 'staff');
  });

  test('rejects an incorrect pin even when using the offline cache',
      () async {
    await db.cachedProfileDao.upsertProfile(
      CachedProfilesCompanion.insert(
        id: 'user-2',
        displayName: '직원1',
        role: 'staff',
        email: 'staff1@internal.local',
        pinHash: hashPin('567890', 'fixed-salt'),
        pinSalt: 'fixed-salt',
      ),
    );

    final gateway = FakeAuthGateway(throwNetworkError: true);
    final repository = AuthRepository(gateway, db.cachedProfileDao);

    final result = await repository.login(
      id: 'user-2',
      email: 'staff1@internal.local',
      pin: '000000',
    );

    expect(result.outcome, AuthOutcome.invalidPin);
  });

  test(
      'reports no offline cache when the device has never logged in '
      'before', () async {
    final gateway = FakeAuthGateway(throwNetworkError: true);
    final repository = AuthRepository(gateway, db.cachedProfileDao);

    final result = await repository.login(
      id: 'user-3',
      email: 'staff2@internal.local',
      pin: '111111',
    );

    expect(result.outcome, AuthOutcome.offlineNoCache);
  });

  test(
      'reports no offline cache when logging in without a known id at all '
      '(first login on a new device)', () async {
    final gateway = FakeAuthGateway(throwNetworkError: true);
    final repository = AuthRepository(gateway, db.cachedProfileDao);

    final result = await repository.login(
      email: 'owner@internal.local',
      pin: '123456',
    );

    expect(result.outcome, AuthOutcome.offlineNoCache);
  });
}
```

- [ ] **Step 3: 테스트 실행하여 실패 확인**

Run: `flutter test test/data/repositories/auth_repository_test.dart`
Expected: FAIL — `lib/data/repositories/auth_repository.dart` 파일이 없어 컴파일 에러

- [ ] **Step 4: 최소 구현 작성**

`lib/data/repositories/auth_repository.dart`:
```dart
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
  });

  final AuthOutcome outcome;
  final String? userId;
  final String? displayName;
  final String? role;
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

      final salt = generatePinSalt();
      await _cachedProfileDao.upsertProfile(
        CachedProfilesCompanion.insert(
          id: user.id,
          displayName: displayName,
          role: role,
          email: email,
          pinHash: hashPin(pin, salt),
          pinSalt: salt,
        ),
      );

      return AuthResult(
        outcome: AuthOutcome.success,
        userId: user.id,
        displayName: displayName,
        role: role,
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
        );
      }
      return AuthResult(outcome: AuthOutcome.invalidPin);
    } on AuthException {
      return AuthResult(outcome: AuthOutcome.invalidPin);
    }
  }
}
```

- [ ] **Step 5: 테스트 실행하여 통과 확인**

Run: `flutter test test/data/repositories/auth_repository_test.dart`
Expected: PASS (5 tests passed)

- [ ] **Step 6: Commit**

```bash
git add lib/data/repositories/auth_repository.dart test/support/fake_auth_gateway.dart test/data/repositories/auth_repository_test.dart
git commit -m "feat: add AuthRepository with online/offline PIN login"
```

---

### Task 5: AuthRepository — 직원 추가 + Riverpod providers

**Files:**
- Modify: `lib/data/repositories/auth_repository.dart`
- Modify: `lib/core/providers/dao_providers.dart`
- Create: `lib/core/providers/auth_providers.dart`

- [ ] **Step 1: addStaff 메서드 추가**

`lib/data/repositories/auth_repository.dart`의 `AuthRepository` 클래스 안, `login` 메서드 다음에 이어서 추가:

```dart
  Future<void> addStaff({
    required String displayName,
    required String pin,
    required String ownerEmail,
    required String ownerPin,
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
    );

    // signUp()이 세션을 방금 만든 직원 계정으로 바꿔버리므로, 사장 계정으로
    // 다시 로그인해서 세션을 복구한다.
    await _gateway.signInWithPassword(email: ownerEmail, password: ownerPin);
  }
```

- [ ] **Step 2: 정적 분석 확인**

Run: `flutter analyze lib/data/repositories/auth_repository.dart`
Expected: `No issues found!`

- [ ] **Step 3: DAO provider 추가**

`lib/core/providers/dao_providers.dart` 맨 끝에 이어서 추가:

```dart
final cachedProfileDaoProvider =
    Provider((ref) => ref.watch(appDatabaseProvider).cachedProfileDao);
```

- [ ] **Step 4: 인증 세션 provider 작성**

`lib/core/providers/auth_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/services/auth_gateway.dart';
import 'dao_providers.dart';

class AuthSession {
  AuthSession({
    required this.id,
    required this.email,
    required this.pin,
    required this.displayName,
    required this.role,
  });

  final String id;
  final String email;
  final String pin;
  final String displayName;
  final String role;

  bool get isOwner => role == 'owner';
}

class AuthSessionNotifier extends StateNotifier<AuthSession?> {
  AuthSessionNotifier() : super(null);

  void setSession(AuthSession session) => state = session;

  void clear() => state = null;
}

final authSessionProvider =
    StateNotifierProvider<AuthSessionNotifier, AuthSession?>(
  (ref) => AuthSessionNotifier(),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    SupabaseAuthGateway(Supabase.instance.client),
    ref.watch(cachedProfileDaoProvider),
  );
});
```

- [ ] **Step 5: 정적 분석 확인**

Run: `flutter analyze lib/core/providers`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/data/repositories/auth_repository.dart lib/core/providers
git commit -m "feat: add addStaff and auth session providers"
```

---

### Task 6: 로그인 화면

**Files:**
- Create: `lib/features/auth/login_screen.dart`
- Test: `test/features/auth/login_screen_test.dart`

- [ ] **Step 1: 실패하는 위젯 테스트 작성**

`test/features/auth/login_screen_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/core/providers/auth_providers.dart';
import 'package:stockcontrol/core/providers/database_provider.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/data/repositories/auth_repository.dart';
import 'package:stockcontrol/domain/pin_hash.dart';
import 'package:stockcontrol/features/auth/login_screen.dart';

import '../../support/fake_auth_gateway.dart';

void main() {
  late AppDatabase db;
  late FakeAuthGateway gateway;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    gateway = FakeAuthGateway(throwNetworkError: true);

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(
          AuthRepository(gateway, db.cachedProfileDao),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  Widget wrap() => UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LoginScreen()),
      );

  testWidgets('logs in with the correct pin and sets the auth session',
      (tester) async {
    await db.cachedProfileDao.upsertProfile(
      CachedProfilesCompanion.insert(
        id: 'user-1',
        displayName: '사장님',
        role: 'owner',
        email: 'owner@internal.local',
        pinHash: hashPin('123456', 'salt'),
        pinSalt: 'salt',
      ),
    );

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.text('사장님'), findsOneWidget);

    await tester.tap(find.text('사장님'));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('pinField')), '123456');
    await tester.tap(find.text('로그인'));
    await tester.pump();
    await tester.pump();

    expect(container.read(authSessionProvider)?.displayName, '사장님');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('shows an error and does not set a session for a wrong pin',
      (tester) async {
    await db.cachedProfileDao.upsertProfile(
      CachedProfilesCompanion.insert(
        id: 'user-1',
        displayName: '사장님',
        role: 'owner',
        email: 'owner@internal.local',
        pinHash: hashPin('123456', 'salt'),
        pinSalt: 'salt',
      ),
    );

    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.tap(find.text('사장님'));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('pinField')), '000000');
    await tester.tap(find.text('로그인'));
    await tester.pump();
    await tester.pump();

    expect(find.text('PIN이 올바르지 않습니다'), findsOneWidget);
    expect(container.read(authSessionProvider), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
      'logs in via manual email entry when the device has no cached '
      'profiles yet (first login on a new device)', (tester) async {
    // 이 테스트만 온라인 성공 시나리오라 별도의 가짜 게이트웨이를 쓴다
    // (바깥 setUp의 컨테이너는 네트워크 오류만 내는 게이트웨이를 쓰고 있음).
    final onlineGateway = FakeAuthGateway()
      ..seedUser(
        id: 'user-9',
        email: 'owner@internal.local',
        password: '123456',
        displayName: '사장님',
        role: 'owner',
      );

    final onlineContainer = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(
          AuthRepository(onlineGateway, db.cachedProfileDao),
        ),
      ],
    );
    addTearDown(onlineContainer.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: onlineContainer,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('manualEntryButton')));
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('emailField')),
      'owner@internal.local',
    );
    await tester.enterText(find.byKey(const Key('manualPinField')), '123456');
    await tester.tap(find.text('로그인'));
    await tester.pump();
    await tester.pump();

    expect(onlineContainer.read(authSessionProvider)?.displayName, '사장님');

    final cached = await db.cachedProfileDao.getById('user-9');
    expect(cached, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/features/auth/login_screen_test.dart`
Expected: FAIL — `lib/features/auth/login_screen.dart` 파일이 없어 컴파일 에러

- [ ] **Step 3: 화면 구현**

`lib/features/auth/login_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/dao_providers.dart';
import '../../data/local/database.dart';
import '../../data/repositories/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  CachedProfile? _selected;
  bool _manualEntry = false;
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dao = ref.watch(cachedProfileDaoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: StreamBuilder<List<CachedProfile>>(
        stream: dao.watchAll(),
        builder: (context, snapshot) {
          final profiles = snapshot.data ?? [];

          if (_manualEntry) return _buildManualEntry();
          if (_selected != null) return _buildPinEntry(_selected!.displayName);

          return ListView(
            children: [
              for (final profile in profiles)
                ListTile(
                  title: Text(profile.displayName),
                  onTap: () => setState(() => _selected = profile),
                ),
              TextButton(
                key: const Key('manualEntryButton'),
                onPressed: () => setState(() => _manualEntry = true),
                child: const Text('이메일로 로그인 (이 기기가 처음이신가요?)'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildManualEntry() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            key: const Key('emailField'),
            controller: _emailController,
            decoration: const InputDecoration(labelText: '이메일'),
          ),
          TextField(
            key: const Key('manualPinField'),
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'PIN'),
          ),
          if (_errorText != null)
            Text(_errorText!, style: const TextStyle(color: Colors.red)),
          ElevatedButton(
            onPressed: () => _submit(
              id: null,
              email: _emailController.text.trim(),
              pin: _pinController.text,
            ),
            child: const Text('로그인'),
          ),
          TextButton(
            onPressed: () => setState(() {
              _manualEntry = false;
              _errorText = null;
            }),
            child: const Text('이름 목록으로 돌아가기'),
          ),
        ],
      ),
    );
  }

  Widget _buildPinEntry(String displayName) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(displayName),
          const SizedBox(height: 16),
          TextField(
            key: const Key('pinField'),
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'PIN'),
          ),
          if (_errorText != null)
            Text(_errorText!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _submit(
              id: _selected!.id,
              email: _selected!.email,
              pin: _pinController.text,
            ),
            child: const Text('로그인'),
          ),
          TextButton(
            onPressed: () => setState(() {
              _selected = null;
              _errorText = null;
              _pinController.clear();
            }),
            child: const Text('다른 사용자'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit({
    required String? id,
    required String email,
    required String pin,
  }) async {
    final result = await ref.read(authRepositoryProvider).login(
          id: id,
          email: email,
          pin: pin,
        );

    if (result.outcome == AuthOutcome.success) {
      ref.read(authSessionProvider.notifier).setSession(
            AuthSession(
              id: result.userId!,
              email: email,
              pin: pin,
              displayName: result.displayName!,
              role: result.role!,
            ),
          );
      return;
    }

    setState(() {
      _errorText = result.outcome == AuthOutcome.offlineNoCache
          ? '이 기기에서 온라인으로 로그인한 기록이 없습니다'
          : 'PIN이 올바르지 않습니다';
    });
  }
}
```

`_selected`(이름 목록에서 고른 경우)와 수동 입력(`_manualEntry`, 이 기기에 캐시가 없는 첫 로그인) 두 경로가 같은 `_submit()`을 공유한다 — 차이는 `id`를 아는지(캐시에서 골랐으니 앎) 모르는지(수동 입력이라 모름, `AuthRepository.login()`이 이 경우 오프라인 대체를 시도하지 않고 곧바로 `offlineNoCache`를 반환한다)뿐이다.

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/features/auth/login_screen_test.dart`
Expected: PASS (3 tests passed)

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/login_screen.dart test/features/auth/login_screen_test.dart
git commit -m "feat: add PIN login screen"
```

---

### Task 7: 직원 추가 화면 + 진입 경로

**Files:**
- Create: `lib/features/auth/add_staff_screen.dart`
- Test: `test/features/auth/add_staff_screen_test.dart`
- Modify: `lib/core/shell/more_screen.dart`
- Modify: `lib/core/shell/app_shell.dart`

- [ ] **Step 1: 실패하는 위젯 테스트 작성 (폼 검증만)**

`test/features/auth/add_staff_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/features/auth/add_staff_screen.dart';

void main() {
  testWidgets('shows an error when name or pin is missing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AddStaffScreen()),
      ),
    );

    await tester.tap(find.text('추가'));
    await tester.pump();

    expect(find.text('이름과 6자리 PIN을 입력하세요'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `flutter test test/features/auth/add_staff_screen_test.dart`
Expected: FAIL — `lib/features/auth/add_staff_screen.dart` 파일이 없어 컴파일 에러

- [ ] **Step 3: 화면 구현**

`lib/features/auth/add_staff_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_providers.dart';

class AddStaffScreen extends ConsumerStatefulWidget {
  const AddStaffScreen({super.key});

  @override
  ConsumerState<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends ConsumerState<AddStaffScreen> {
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    if (name.isEmpty || pin.length != 6) {
      setState(() => _errorText = '이름과 6자리 PIN을 입력하세요');
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
          );
    } catch (e) {
      setState(() => _errorText = '직원 추가에 실패했습니다: $e');
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }
}
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `flutter test test/features/auth/add_staff_screen_test.dart`
Expected: PASS (1 test passed)

- [ ] **Step 5: MoreScreen에 사장 전용 항목 추가**

`lib/core/shell/more_screen.dart`를 아래 내용으로 교체:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ingredient_management/ingredient_list_screen.dart';
import '../../features/supplier_management/supplier_list_screen.dart';
import '../providers/auth_providers.dart';
import 'auth_add_staff_route.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('더보기')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('거래처 관리'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SupplierListScreen()),
            ),
          ),
          ListTile(
            title: const Text('품목 관리'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const IngredientListScreen(),
              ),
            ),
          ),
          if (session?.isOwner ?? false)
            ListTile(
              title: const Text('직원 추가'),
              onTap: () => pushAddStaffScreen(context),
            ),
        ],
      ),
    );
  }
}
```

여기서 `pushAddStaffScreen`은 다음 단계에서 만들 작은 공용 함수다 — `MoreScreen`과 `AppShell` 둘 다 같은 방식으로 `AddStaffScreen`을 열게 하기 위함이다.

`lib/core/shell/auth_add_staff_route.dart` (신규 파일):
```dart
import 'package:flutter/material.dart';

import '../../features/auth/add_staff_screen.dart';

void pushAddStaffScreen(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const AddStaffScreen()),
  );
}
```

- [ ] **Step 6: 데스크톱 사이드바에 6번째 목적지 추가**

`lib/core/shell/app_shell.dart` 맨 위 import에 추가:

```dart
import '../providers/auth_providers.dart';
import 'auth_add_staff_route.dart';
```

`_AppShellState`를 `ConsumerState<AppShell>`로 바꿔야 한다 — `class _AppShellState extends State<AppShell>`를 `class _AppShellState extends ConsumerState<AppShell>`로 교체하고, `class AppShell extends StatefulWidget`을 `class AppShell extends ConsumerStatefulWidget`으로, `State<AppShell> createState()`를 `ConsumerState<AppShell> createState()`로 교체한다.

`_buildDesktop()` 메서드 시작 부분에 아래를 추가:

```dart
  Widget _buildDesktop() {
    final isOwner = ref.watch(authSessionProvider)?.isOwner ?? false;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              if (isOwner && index == 5) {
                pushAddStaffScreen(context);
                return;
              }
              setState(() => _selectedIndex = index);
            },
```

(`NavigationRail(` 다음 줄부터 기존 `selectedIndex: _selectedIndex,`와 `onDestinationSelected: (index) => setState(() => _selectedIndex = index),` 두 줄을 위 코드로 교체한다)

`NavigationRail`의 `destinations` 리스트 마지막(`품목 관리` 다음)에 조건부로 추가:

```dart
              if (isOwner)
                const NavigationRailDestination(
                  icon: Icon(Icons.person_add_outlined),
                  label: Text('직원 추가'),
                ),
```

(`destinations: const [...]`가 `const`였는데 이제 `isOwner`라는 실행 시점 값에 따라 항목이 달라지므로, `destinations: [` 앞의 `const`를 제거해야 한다)

- [ ] **Step 7: 정적 분석 확인**

Run: `flutter analyze lib/core/shell`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/features/auth/add_staff_screen.dart test/features/auth/add_staff_screen_test.dart lib/core/shell
git commit -m "feat: add staff creation screen and owner-only navigation entries"
```

---

### Task 8: main.dart 연결 (로그인 게이트) + 최종 확인

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Supabase 초기화 + 로그인 게이트 추가**

`lib/main.dart` 전체를 아래 내용으로 교체:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/providers/auth_providers.dart';
import 'core/shell/app_shell.dart';
import 'features/auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const ProviderScope(child: StockControlApp()));
}

class StockControlApp extends ConsumerWidget {
  const StockControlApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);

    return MaterialApp(
      title: '재고관리',
      home: session == null ? const LoginScreen() : const AppShell(),
    );
  }
}
```

- [ ] **Step 2: 정적 분석 확인**

Run: `flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 3: 전체 테스트 스위트 실행**

Run: `flutter test`
Expected: PASS — 이번 스펙에서 추가한 테스트(PIN 해시 5개, 캐시 DAO 2개, AuthRepository 5개, 로그인 화면 3개, 직원 추가 화면 1개, 총 16개 추가)를 포함해 전부 통과

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: gate app entry behind PIN login"
```

- [ ] **Step 5: 수동 확인 (실제 Supabase 프로젝트 대상)**

Run: `flutter run -d windows` (또는 `flutter run -d chrome`)

확인 사항:
1. 앱을 처음 실행하면 로그인 화면이 뜬다 — 이 기기는 아직 로컬 캐시가 없으니 이름 목록이 비어있는 게 정상이다. "이메일로 로그인" 버튼을 눌러 사전 준비 단계에서 만든 사장 계정(이메일 + PIN)으로 로그인한다.
2. 로그인 성공 시 `AppShell`(재고 조회 화면)로 진입하는가
3. 앱을 재시작하면 이번엔 로그인 화면에 방금 그 사장 이름이 목록에 뜨는가 (로컬 캐시에 저장됐는지 확인)
4. "직원 추가" 화면에서 새 직원을 만들고, 사장 세션이 유지되는지(다시 로그인 화면으로 튕기지 않는지) 확인
5. 앱을 완전히 종료했다가 인터넷을 끄고 다시 실행 → 방금 만든 사장/직원 이름으로 PIN 입력 시 오프라인 로그인이 되는지 확인

---

## Self-Review 결과

**스펙 커버리지**: Supabase Auth 설정(이메일 확인 끄기, 비밀번호 최소 길이) + `profiles` 테이블 — "사전 준비" 섹션(수동) / PIN 로그인(온라인) — Task 4 / PIN 로그인(오프라인 캐시 대체) — Task 3+4 / 세션 비유지(매번 재입력) — Task 6·8(별도 영속화 코드를 두지 않음으로써 자연히 만족) / 직원 추가 + 세션 복구 트릭 — Task 5·7 / role 기반 진입 경로 숨김 — Task 7 / 로그인 게이트 — Task 8 / 범위 밖 항목(재고 데이터 동기화, 마스터데이터 수정·삭제 잠금, PIN 찾기, 로그인 시도 제한) — 이번 계획에 포함하지 않음, 스펙과 일치.

**타입 일관성 확인**: `AuthResult(outcome, userId, displayName, role)`과 `AuthOutcome{success, invalidPin, offlineNoCache}` — Task 4에서 정의된 게 Task 6(`LoginScreen`)의 분기 처리와 정확히 일치. `AuthRepository.login({id, email, pin})`과 `addStaff({displayName, pin, ownerEmail, ownerPin})` 시그니처가 Task 6·7의 호출부와 일치. `AuthSession(id, email, pin, displayName, role)` + `isOwner` 게터가 Task 6(세션 설정)과 Task 7(`owner.email`/`owner.pin` 사용, `session?.isOwner`)에서 동일하게 쓰임. `CachedProfiles` 테이블의 컬럼명(`id, displayName, role, email, pinHash, pinSalt`)이 Task 3의 DAO·테스트와 Task 4·6의 `CachedProfilesCompanion.insert(...)` 호출부에서 전부 일치.

**실행 중 발견/반영한 변경사항 재확인**: `supabase_testing` 의존성 충돌로 Task 1~6을 `AuthGateway`/`SupabaseAuthGateway`/`FakeAuthGateway` 구조로 다시 썼다(위 "실행 중 발견한 변경사항" 참고). `AuthGateway`의 4개 메서드(`signInWithPassword`, `signUp`, `fetchProfile`, `insertProfile`)가 Task 1(인터페이스 정의) → Task 4(`AuthRepository`가 소비 + `FakeAuthGateway`가 구현) → Task 5(`SupabaseAuthGateway`가 실제 앱에서 주입) → Task 6(`FakeAuthGateway`를 위젯 테스트에서 재사용)까지 시그니처가 전부 일치. PIN 자릿수는 Supabase 대시보드의 비밀번호 최소 길이 제약(6 미만 불가)에 맞춰 4자리에서 6자리로 변경했고, 스펙·계획·화면 코드(`maxLength`, 에러 메시지)에 전부 반영했다.

**초기 검토에서 발견하고 계획에 반영한 위험 요소**: "이름 목록이 로컬 캐시에서만 나온다"는 설계라면, 최초 실행 시(또는 새 기기에서) 로컬 캐시가 비어 있어 로그인 화면에 고를 이름이 하나도 없어서 아예 로그인을 못 하는 문제가 있었다. Task 6의 "이메일로 로그인" 경로(`_manualEntry`, `AuthRepository.login()`의 `id`를 선택적 파라미터로 변경)로 해결했다 — 이 경로는 이름 목록에 없는 사람(또는 이 기기에 처음 로그인하는 사람)도 이메일+PIN을 직접 입력해서 온라인으로 로그인할 수 있게 하고, 성공하면 그 즉시 로컬 캐시에 저장되어 다음부터는 이름 목록에 나타난다.
