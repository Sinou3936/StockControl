# 코드 리뷰 Q&A 노트

Task 1~7 구현 코드를 한 파일씩 리뷰하면서 나온 질문과 답변, 그리고 "왜 이렇게 짰는지"를 기록합니다. 최신 항목이 아래에 추가됩니다.

---

## `lib/domain/base_unit.dart`

```dart
enum BaseUnit { g, ml, ea }

extension BaseUnitDb on BaseUnit {
  String toDbString() => name;
}

BaseUnit baseUnitFromDbString(String value) =>
    BaseUnit.values.firstWhere((unit) => unit.name == value);
```

**이 파일이 하는 일**: 재료의 재고/사용 단위를 g, ml, ea 세 가지로 제한하는 enum. Drift의 `Ingredients.baseUnit` 컬럼이 `TextColumn`(문자열)이라 enum 값을 그대로 저장할 수 없어서, `toDbString()`/`baseUnitFromDbString()`으로 문자열 ↔ enum을 양방향 변환한다. `name`은 Dart enum이 기본 제공하는 프로퍼티(`BaseUnit.g.name == "g"`)라 별도 매핑 테이블 없이 변환이 가능하다.

**아직 안 쓰이는 부분**: `baseUnitFromDbString()`은 지금 시점에는 호출하는 곳이 없다. 화면에서는 DB에서 읽은 문자열을 그대로 표시만 하고 있어서다. 4단계(재고조회)에서 필터링/정렬 로직을 짤 때 쓰일 가능성이 높다.

### Q: extension은 뭐야?

Dart의 `extension`은 **기존 클래스(또는 enum)를 수정하지 않고 새로운 메서드를 추가**하는 문법이다.

```dart
extension BaseUnitDb on BaseUnit {   // BaseUnitDb: 확장 이름(임의), on BaseUnit: 대상 타입
  String toDbString() => name;
}

BaseUnit.g.toDbString(); // "g" — 원래 있던 메서드처럼 호출 가능
```

주로 `int`, `String`처럼 내가 수정할 수 없는 남의 타입에 메서드를 추가하고 싶을 때 쓴다. `BaseUnit`은 내가 직접 정의한 enum이라 꼭 extension이 아니어도 되고, 아래처럼 평범한 함수로 짜도 동일하게 동작한다:

```dart
String baseUnitToDbString(BaseUnit unit) => unit.name;
```

지금 코드에서는 한 줄짜리 변환이라 extension을 쓸 실익이 크지 않고, 습관적으로 "타입에 붙는 변환 메서드는 extension으로" 짠 것에 가깝다. `baseUnitFromDbString()`은 반대로 평범한 top-level 함수로 짰는데, 이건 `on String` 확장으로 만들면 모든 `String`에 이 메서드가 붙어버려서(예: `"아무거나".baseUnitFromDbString()`처럼 의미 없는 곳에도 노출) 굳이 그렇게 하지 않고 함수로 뒀다.

---

## `lib/domain/movement_type.dart`

```dart
enum MovementType { inbound, usage, disposal, adjustment, countCorrection }

extension MovementTypeDb on MovementType {
  String toDbString() => name;
}

MovementType movementTypeFromDbString(String value) =>
    MovementType.values.firstWhere((type) => type.name == value);
```

**이 파일이 하는 일**: `base_unit.dart`와 동일한 패턴. 재고이동(원장)의 종류를 5가지로 제한하고, `StockMovements.type` 컬럼(문자열)과 양방향 변환한다.

**5가지 값의 의미**: `inbound`(정상 입고), `usage`(사용 출고, 미구현), `disposal`(폐기, 미구현), `adjustment`(수동 조정 — 초기재고 등록도 여기 해당: Lot.supplierId=null + memo="초기재고"), `countCorrection`(마감 실사 보정, 미구현). 스펙 단계에서 "이동 유형은 처음부터 다 정의해두면 나중에 enum 재설계가 없다"고 정했던 부분이라, 지금은 `inbound`/`adjustment`만 실제로 쓰이고 나머지 3개는 값만 정의된 상태다.

### Q: extension이 기존 enum의 values 배열을 그대로 쓴다는 얘기인가?

정확히는 방향에 따라 다르다:

- **enum → 문자열** (`toDbString()`, extension): `values` 배열을 안 쓰고, enum 값 **하나**의 `.name`만 꺼낸다. `MovementType.inbound.toDbString()` → `MovementType.inbound.name` → `"inbound"`.
- **문자열 → enum** (`movementTypeFromDbString()`, 평범한 top-level 함수, extension 아님): `MovementType.values`(Dart가 enum 선언 시 자동으로 만들어주는 "모든 값의 리스트") 전체를 순회하며 `.name`이 일치하는 값을 찾는다.

즉 두 방향 모두 우리가 직접 매핑 테이블을 만든 게 아니라 Dart가 자동 제공하는 `name`/`values`에 의존한다는 점은 맞는 이해이지만, "extension이 배열을 쓴다"는 정확히는 아니고 — 배열을 쓰는 건 extension이 아닌 별도 함수 쪽이다.

### Q: name과 value가 일치해야 extension이 발동하는 거지?

아니다. **"일치를 확인하는" 로직은 `movementTypeFromDbString`(문자열→enum 함수)에만 있고, extension인 `toDbString()`(enum→문자열)에는 조건/일치 개념이 아예 없다.** `toDbString()`은 무조건 `.name`을 반환하는 단순 변환이라 "발동 조건" 같은 게 없다.

`movementTypeFromDbString("inbound")`가 내부적으로 하는 일 (`firstWhere`는 "조건에 맞는 첫 항목 찾기"):

```
values = [inbound, usage, disposal, adjustment, countCorrection]
inbound.name == "inbound"?  → true → 반환하고 종료
```

`movementTypeFromDbString("disposal")`이었다면:

```
inbound.name == "disposal"?   → false, 다음
usage.name == "disposal"?     → false, 다음
disposal.name == "disposal"?  → true → 반환
```

즉 "일치해야 발동" 개념은 문자열→enum 방향의 별도 함수 얘기이고, extension 자체와는 무관하다.

### Q: enum을 새로 만들면 새로운 클래스가 나오는 거야?

맞다 (다만 이건 extension이 아니라 enum 자체에 대한 사실). Dart의 `enum`은 컴파일되면 실제로 `Enum`이라는 내장 클래스를 상속하는 클래스가 된다:

```dart
enum BaseUnit { g, ml, ea }

// 대략 이런 클래스와 동등한 효과 (단순화한 설명)
class BaseUnit extends Enum {
  static const g = BaseUnit._(0, 'g');
  static const ml = BaseUnit._(1, 'ml');
  static const ea = BaseUnit._(2, 'ea');
  static const values = [g, ml, ea];   // 계속 쓰던 그 values

  final int index;
  final String name;                    // 계속 쓰던 그 name
  const BaseUnit._(this.index, this.name);
}
```

`.name`/`.values`/`.index`가 "공짜"인 이유가 이거다 — enum 선언 자체가 이 뼈대를 자동 생성해주기 때문에 우리가 직접 짤 필요가 없다.

**반면 `extension`은 새 클래스를 만들지 않는다.** 이미 있는 타입(여기서는 위에서 생긴 `BaseUnit` 클래스) 바깥에서 메서드만 붙이는 것이라, `extension BaseUnitDb on BaseUnit`이 있어도 `BaseUnit` 클래스 정의 자체는 그대로다. 컴파일 시점에 "이 메서드 호출은 저 extension 거다"라고 연결해줄 뿐이다.

정리: **enum 선언 = 진짜 새 클래스 생성. extension 선언 = 클래스 생성 아님, 기존 타입에 메서드만 추가.**

---

## `lib/domain/unit_conversion.dart`

```dart
double purchaseQtyToBaseQty(double purchaseQty, double conversionFactor) =>
    purchaseQty * conversionFactor;
```

**이 파일이 하는 일**: 구매 단위 수량을 재고/사용 단위(baseUnit) 수량으로 환산. 예: 양파 2박스, 1박스=20000g → `purchaseQtyToBaseQty(2, 20000)` = 40000g.

**왜 함수로 뺐는가**: 같은 계산이 입고 등록 화면(수량 입력 시 환산값 미리보기)과 `LotRepository`(저장할 baseQty 계산) 두 곳에서 필요하다. 공식이 바뀔 때 한 곳만 고치면 되게 하려고 함수로 분리했다.

**문법 참고 (`=>`)**: 화살표 함수. 함수 본문이 `return` 하나뿐일 때 `{ return ...; }`를 생략하는 축약 문법. `=> purchaseQty * conversionFactor;`는 `{ return purchaseQty * conversionFactor; }`와 완전히 동일하다.

### Q: 왜 double이야? int(또는 long)로 하면 안 돼?

Dart에는 애초에 `long`이 없고 숫자 타입은 `int`/`double` 둘뿐이다. `double`을 쓴 이유:

1. **실제 값이 소수인 경우가 흔하다** — 단가(`unitCost`)가 `12.5원`처럼 소수, 저울로 재는 재료는 구매 수량 자체가 `2.5kg`처럼 소수, 환산 배율도 품목에 따라 소수가 필요할 수 있다(`1큰술 = 14.79ml` 등). `int`면 이런 값을 표현할 수 없거나 반올림 로직이 강제로 필요해진다.
2. **DB 스키마와 타입을 맞춰야 한다** — `lib/data/local/tables/*.dart`에서 `conversionFactor`, `unitCost`, `remainingQty`, `quantity`를 전부 `RealColumn`(Dart `double`)으로 정의해뒀다. 이 함수 파라미터도 `double`로 맞춰야 DB에서 읽은 값을 바로 넘길 수 있고, 곳곳에서 `int`↔`double` 변환 코드를 추가로 안 짜도 된다.

"이 재료는 항상 정수로만 다룬다"가 확실하면 `int`도 가능했겠지만, 재료마다 다르고(개수 단위 vs 무게/부피 단위) 나중에 소수 케이스가 생기면 스키마를 다시 바꿔야 하는 위험이 있어 처음부터 `double`로 통일했다.

---

## `lib/data/local/tables/suppliers_table.dart`

```dart
import 'package:drift/drift.dart';

class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get contact => text().nullable()();
  TextColumn get memo => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

**이 파일이 하는 일**: 실제 SQLite 테이블이 아니라 Drift가 테이블/코드를 자동 생성할 때 참고하는 "설계도" 클래스. `Suppliers` 자체를 코드에서 직접 생성해서 쓰는 일은 없고, `drift_dev`(코드 생성기)가 이걸 읽어서 `database.g.dart`에 실제로 쓸 `Supplier`(행 데이터 클래스)와 `SuppliersCompanion`(insert/update용 클래스)을 만들어준다. DAO 테스트의 `SuppliersCompanion.insert(name: '테스트거래처')`가 여기서 생성된 것.

컬럼 5개: `id`(자동증가 기본키), `name`(필수), `contact`/`memo`(nullable), `createdAt`(값 안 주면 DB가 현재시각 채움).

**문법: `integer().autoIncrement()()`처럼 괄호가 여러 번 붙는 이유** — Drift는 컬럼을 빌더 패턴으로 짓는다:

```dart
integer()              // 1단계: 정수 컬럼 설정 시작 (아직 미완성)
  .autoIncrement()      // 2단계: "자동증가로 해줘" (체이닝, 여전히 설정 중)
  ()                    // 3단계: 설정 객체를 함수처럼 호출해서 확정 → 진짜 Column이 됨
```

마지막 `()`는 그 설정 객체가 `call()` 메서드를 가진 "호출 가능한 객체"라서, `객체()`로 부르면 "설정 끝, 실제 컬럼으로 만들어줘"가 실행되는 것. 그래서 컬럼 선언은 항상 맨 끝에 `()`가 하나 더 붙는다. `nullable()`은 Dart의 `String?`처럼 NULL을 허용하는 컬럼으로 만들고, `withDefault(currentDateAndTime)`은 값을 안 넣었을 때 DB가 대신 채워줄 기본값을 지정한다.

---

## `lib/data/local/tables/ingredients_table.dart`

```dart
import 'package:drift/drift.dart';

class Ingredients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get category => text().nullable()();
  TextColumn get baseUnit => text()();
  TextColumn get purchaseUnit => text()();
  RealColumn get conversionFactor => real()();
  BoolColumn get isExpiryTracked => boolean()();
  RealColumn get safetyStockQty => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

**이 파일이 하는 일**: `Suppliers`와 동일한 패턴, 컬럼 8개.

| 컬럼 | 타입 | 의미 |
|---|---|---|
| `name` | 필수 텍스트 | 품목명 |
| `category` | nullable 텍스트 | 분류, 지금 화면에서 안 씀 (나중 대비) |
| `baseUnit` | 필수 텍스트 | `BaseUnit.toDbString()` 값("g"/"ml"/"ea") |
| `purchaseUnit` | 필수 텍스트 | 자유 텍스트 (예: "박스") |
| `conversionFactor` | 필수 `double` | 구매단위 1개 = baseUnit 몇 개 |
| `isExpiryTracked` | 필수 `bool` | 유통기한 관리 여부 |
| `safetyStockQty` | nullable `double` | 안전재고 — 9단계에서 쓸 예정, 지금은 미사용 |
| `createdAt` | 자동 현재시각 | Suppliers와 동일 |

**한계점**: `baseUnit`은 그냥 `TextColumn`이라 DB 레벨에서 `"g"/"ml"/"ea"` 외 문자열도 저장될 수 있다. 지금은 화면 드롭다운이 `BaseUnit.values`로만 강제해서 문제없지만, 나중에 다른 입력 경로(엑셀 업로드 등)가 생기면 검증이 필요해질 수 있다. 지금은 화면이 하나뿐이라 DB 레벨 제약(`CHECK` 등)은 안 걸었다.

### Q: RealColumn은 뭐야?

SQLite의 **REAL**(부동소수점 숫자) 저장 타입을 표현하는 Drift 컬럼 타입. Dart 쪽에서는 `double`에 대응된다. SQLite는 값을 NULL/INTEGER/REAL/TEXT/BLOB 5가지 타입 중 하나로 저장하는데, Drift는 이 이름을 그대로 따서 컬럼 타입 이름을 지었다.

지금까지 나온 컬럼 타입 대응표:

| Drift 컬럼 타입 | 빌더 함수 | SQLite 저장 타입 | Dart 타입 |
|---|---|---|---|
| `IntColumn` | `integer()` | INTEGER | `int` |
| `RealColumn` | `real()` | REAL | `double` |
| `TextColumn` | `text()` | TEXT | `String` |
| `BoolColumn` | `boolean()` | INTEGER(0/1) | `bool` |
| `DateTimeColumn` | `dateTime()` | INTEGER(타임스탬프) | `DateTime` |

`unit_conversion.dart`에서 `double`을 쓴 이유로 들었던 "DB 컬럼이 RealColumn이라 타입을 맞췄다"는 설명이 가리키던 게 바로 이 컬럼들이다.

---

## `lib/data/local/tables/lots_table.dart`

```dart
import 'package:drift/drift.dart';

import 'ingredients_table.dart';
import 'suppliers_table.dart';

class Lots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ingredientId => integer().references(Ingredients, #id)();
  IntColumn get supplierId =>
      integer().nullable().references(Suppliers, #id)();
  DateTimeColumn get receivedDate => dateTime()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  RealColumn get unitCost => real()();
  RealColumn get remainingQty => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

**이 파일이 하는 일**: 외래키(foreign key)가 처음 등장. 외래키는 "이 컬럼 값은 반드시 다른 테이블의 어떤 행을 가리켜야 한다"는 DB 레벨 제약이다.

- `ingredientId` — `Ingredients.id`를 반드시 가리켜야 함(필수). 존재하지 않는 재료의 로트가 생기는 걸 DB 레벨에서 막는다.
- `supplierId` — `.nullable()` + `Suppliers.id` 참조. 값이 없어도 되지만 있다면 반드시 존재해야 한다. **초기재고는 거래처 없이 Lot을 만들 수 있어야 한다**(브레인스토밍 결론)는 요구사항을 그대로 구현한 부분.
- `receivedDate`(입고일, 필수), `expiryDate`(유통기한, nullable — 관리 안 하는 품목 대응), `unitCost`, `remainingQty`(이 로트에 남은 수량, 스펙에서 "비정규화 캐시"라 부른 필드), `createdAt`은 이전과 동일 패턴.

**문법: `#id`** — Dart의 Symbol 리터럴. `id`를 지금 호출해서 값을 가져오는 게 아니라 "`id`라는 이름 자체"를 데이터로 전달한다. Drift는 이걸 받아 "Ingredients 테이블 설계도 안의 `id`라는 이름의 컬럼을 가리키는 것"으로 코드 생성 시점에 해석한다. (사용자가 이미 이해하고 있던 부분이라 추가 질문 없이 통과.)

---

## `lib/data/local/tables/stock_movements_table.dart`

```dart
import 'package:drift/drift.dart';

import 'lots_table.dart';

class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get lotId => integer().references(Lots, #id)();
  TextColumn get type => text()();
  RealColumn get quantity => real()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get memo => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

**이 파일이 하는 일**: 새 문법은 없고 지금까지 배운 것들의 조합. 스펙에서 "진실의 원장"이라 부른 테이블.

- `lotId` — `Lots.id`를 가리키는 **필수**(nullable 아님) 외래키. "모든 재고이동은 반드시 하나의 Lot에 귀속된다"는 원칙이 그대로 반영됨 — 초기재고도 Lot을 먼저 만들고 그 Lot에 붙는 이동으로 표현.
- `type` — `MovementType.toDbString()` 값("inbound", "adjustment" 등)
- `quantity` — 부호 있는 `double`. +면 입고, -면 출고/폐기 (스펙에서 정한 부호 규칙)
- `occurredAt` — 이동 발생 시각(필수), `memo` — nullable(초기재고 등록 시 "초기재고" 저장), `createdAt` — 동일 패턴

**짚어볼 점**: `quantity`의 부호 규칙이나 `type`이 5가지 값 중 하나여야 한다는 제약은 `ingredients_table.dart`의 `baseUnit`과 마찬가지로 DB 레벨에서 강제되지 않는다. `LotRepository`(애플리케이션 코드)가 항상 올바른 값을 넣어준다는 전제로 짜여 있다 — "DB 제약이 아니라 코드가 책임지는 규칙"이 이 프로젝트 전반에 반복되는 패턴.

---

## `lib/data/local/database.dart`

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/ingredient_dao.dart';
import 'daos/lot_dao.dart';
import 'daos/stock_movement_dao.dart';
import 'daos/supplier_dao.dart';
import 'tables/ingredients_table.dart';
import 'tables/lots_table.dart';
import 'tables/stock_movements_table.dart';
import 'tables/suppliers_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Suppliers, Ingredients, Lots, StockMovements],
  daos: [SupplierDao, IngredientDao, LotDao, StockMovementDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'stockcontrol'));

  @override
  int get schemaVersion => 1;
}
```

**이 파일이 하는 일**: 지금까지 만든 테이블 4개 + DAO 4개를 하나의 DB 클래스로 조립하는 지점.

**`part 'database.g.dart';`** — Dart의 파일 분할 기능. "이 파일의 나머지 절반은 `database.g.dart`에 있다"는 선언이고, 둘은 사실상 한 파일처럼 서로의 내용을 그냥 쓸 수 있다. `database.g.dart`는 `dart run build_runner build`가 자동 생성한 파일 (`.g.dart`의 g = generated).

**`@DriftDatabase(...)` — 어노테이션**: `@`로 시작하는 메타데이터 표시. 그 자체는 실행되는 코드가 아니라 "이 클래스에 대한 추가 정보"를 코드 생성기(drift_dev)에게 알려주는 꼬리표다. Spring Boot의 `@Component`/`@Autowired`와 "선언적으로 메타데이터를 붙인다"는 정신은 같지만, 처리 시점이 다르다 — Spring은 주로 **런타임** 리플렉션으로 처리하고, Dart의 이건 `build_runner`가 **빌드 타임**에 소스를 정적으로 읽어 `database.g.dart`라는 새 소스 코드를 생성한다. 실행 시점엔 이미 평범한 Dart 코드일 뿐이라, Java의 Lombok/어노테이션 프로세서나 C#의 소스 제너레이터에 더 가깝다.

**`class AppDatabase extends _$AppDatabase`**: `_$AppDatabase`가 `database.g.dart` 안에 자동 생성된 클래스. 앞의 `_`는 Dart의 private(파일/라이브러리 밖에서 안 보임) 표시이고, `$`는 "코드 생성기가 만든 이름"이라는 **커뮤니티 관습**(강제 규칙 아님)이다. `AppDatabase`는 이 뼈대를 상속받아 DB 연결/쿼리/트랜잭션, `db.supplierDao` 같은 DAO 접근자를 전부 공짜로 물려받는다.

> `$`는 C#의 문자열 보간(`$"Hello {name}"`)과는 무관하다. Dart의 진짜 보간은 접두사 없이 `'Hello $name'`, `'합계: ${1+2}'`처럼 쓴다. `_$AppDatabase`의 `$`는 그냥 식별자에 포함된 글자일 뿐, 코드 생성 도구들(drift_dev, json_serializable, freezed 등)이 "이건 자동 생성된 이름"이라고 표시하려고 관습적으로 붙인 것이다.

**생성자**: `AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'stockcontrol'));`

- `[QueryExecutor? executor]` — 대괄호는 선택적 파라미터(안 넘겨도 됨), `?`는 null 허용
- `executor ?? driftDatabase(name: 'stockcontrol')` — `??`는 "왼쪽이 null이면 오른쪽 값 사용". executor를 안 주면 `driftDatabase(...)`로 만든 실제 DB를 쓴다
- `: super(...)` — 부모 클래스(`_$AppDatabase`) 생성자에 그 값을 넘겨 DB 연결을 초기화

이 덕분에 같은 클래스가 실제 앱에서는 `AppDatabase()`(플랫폼에 맞는 위치에 `stockcontrol.sqlite` 파일 생성)로, 테스트에서는 `AppDatabase(NativeDatabase.memory())`(디스크에 안 쓰고 메모리에서만 도는 가짜 DB)로 둘 다 동작한다.

**참고 (계획 변경 사항)**: 원래 계획 문서는 `path_provider`로 직접 경로를 구해 `sqlite3_flutter_libs`를 쓰는 방식이었는데, Task 1 진행 중 `sqlite3_flutter_libs`가 pub.dev에서 "+eol"(수명 종료) 태그가 붙은 걸 발견해서 Drift 공식 문서가 권장하는 `drift_flutter`의 `driftDatabase()` 헬퍼로 교체했다. 계획 문서(`docs/superpowers/plans/2026-09-03-inventory-domain-model-plan.md`)의 "실행 중 발견한 변경사항" 메모에 기록해뒀다.

**`int get schemaVersion => 1;`**: DB 스키마 버전. 나중에 테이블 구조를 바꿀 때 이 숫자를 올리고 마이그레이션 코드를 추가한다. 지금은 첫 버전이라 1.

---

## DAO 파일들 — 공통 배경

### Q: DAO는 뭐의 약자야?

**DAO = Data Access Object.** Dart/Drift만의 개념이 아니라 Java/Spring 진영에서도 흔히 쓰는 디자인 패턴 이름이다(Spring의 `@Repository`/`JpaRepository`와 거의 같은 역할). "DB에 접근하는 로직을 한곳에 모아두는 객체"라는 뜻. DB 쿼리 코드를 화면(UI) 코드에 직접 흩뿌리지 않고 "이 테이블에 대한 조회/삽입/수정은 이 DAO를 거친다"는 창구를 하나로 만든다.

- `SupplierDao` → `Suppliers` 테이블 담당
- `IngredientDao` → `Ingredients` 테이블 담당
- `LotDao` → `Lots` 테이블 담당
- `StockMovementDao` → `StockMovements` 테이블 담당

화면에서는 `db.ingredientDao.watchAll()`만 호출하면 되고, 실제 SQL이 어떻게 생겼는지는 몰라도 된다.

### Q: DAO랑 database.g.dart 자동생성 순서가 어떻게 되는 거야? (lot_dao.g.dart를 보다가 나온 질문)

일직선 순서가 아니라 **서로 참조하는 구조**이고, `build_runner` 한 번 실행할 때 두 종류의 생성 파일이 동시에 만들어진다:

```
tables/*.dart (직접 작성)
      ↑ 참조         ↑ 참조
daos/*.dart (직접 작성)  ←──┐
      ↑ import            │ database.dart가
      │                    │ daos를 목록에 넣음
database.dart (직접 작성) ──┘
      │  dart run build_runner build
      ↓
┌─────────────────────┬─────────────────────┐
│ database.g.dart      │ lot_dao.g.dart 등    │
│ (_$AppDatabase)       │ (_$LotDaoMixin 등)   │
└─────────────────────┴─────────────────────┘
```

`lot_dao.dart`는 `AppDatabase` 타입이 필요해서 `database.dart`를 import하고, `database.dart`는 `LotDao` 클래스가 필요해서 `daos/lot_dao.dart`를 import한다 — 서로를 가리키는 것처럼 보이지만 실행 순서 문제가 아니라 타입 선언끼리의 참조라 Dart가 문제없이 처리한다.

`lot_dao.g.dart` 안의 `_$LotDaoMixin`은 `LotDao`가 `with`로 가져다 쓰는 부분으로, `lots`/`suppliers`/`ingredients` 같은 테이블 접근 게터를 제공한다 (`select(lots)`, `into(lots)`가 가능했던 이유). `@DriftAccessor(tables: [Lots])`라고만 선언했는데도 `suppliers`/`ingredients`까지 접근 가능한 이유는, `Lots`가 그 두 테이블을 외래키로 참조하고 있어서 Drift가 관련 테이블까지 자동으로 열어줬기 때문이다. `managers`는 안 쓰는 고급 쿼리 빌더라 무시해도 된다.

**정리**: `database.g.dart`에는 `db.supplierDao`, `db.lotDao` 같은 **DAO 접근자**가, 각 DAO 전용 `.g.dart`에는 그 DAO 안에서 쓸 **테이블 접근자**가 들어있다.

### Q: `$$IngredientsTableTableManager`의 `$$`도 자동생성 이름 관습이야?

맞다, 같은 관습인데 두 단계가 겹친 것이다.

- **`$IngredientsTable`(`$` 하나)**: 우리가 쓴 `Ingredients extends Table`은 설계도일 뿐이고, Drift가 실제 SQL을 만들 때 쓰는 진짜 구현체가 이 자동 생성 클래스다. `_$AppDatabase`와 같은 패턴 — "우리가 쓴 것의 자동 생성 버전".
- **`$$IngredientsTableTableManager`(`$` 두 개)**: `$IngredientsTable`을 기반으로 **한 번 더 생성된** 상위 기능. Drift의 "Table Manager"라는 fluent 쿼리 빌더 API용 클래스(`select()`/`into()` 없이 `db.managers.ingredients.filter(...)`처럼 쓰는 대안 API). "이미 생성된 것을 기반으로 또 생성됐다"는 의미로 `$`가 하나 더 붙었다.

**우리는 `managers`/`TableManager` 쪽을 전혀 안 쓴다.** 이 프로젝트의 DAO들은 전부 `select(ingredients)`, `into(ingredients)` 방식(내부적으로 `$IngredientsTable`을 씀)으로만 짜여 있다. `$$...Manager`류가 보이면 "안 쓰는 자동생성 부가기능"으로 넘겨도 된다.

---

## `lib/data/local/daos/supplier_dao.dart` — 문법 위주

```dart
import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/suppliers_table.dart';

part 'supplier_dao.g.dart';

@DriftAccessor(tables: [Suppliers])
class SupplierDao extends DatabaseAccessor<AppDatabase>
    with _$SupplierDaoMixin {
  SupplierDao(super.db);

  Stream<List<Supplier>> watchAll() => select(suppliers).watch();

  Future<int> insertSupplier(SuppliersCompanion entry) =>
      into(suppliers).insert(entry);
}
```

다른 3개 DAO(`IngredientDao`, `LotDao`, `StockMovementDao`)도 전부 같은 패턴이라 문법 위주로만 짚었다.

### `extends`와 `with`를 같이 쓰는 이유

Dart는 클래스 상속(`extends`)을 딱 하나만 허용한다(Java/C#과 동일). `SupplierDao`는 두 가지가 동시에 필요하다: `DatabaseAccessor<AppDatabase>`를 상속받아야 `select()`/`into()` 같은 Drift 쿼리 기능을 쓰고(진짜 부모 클래스, Drift 패키지 제공), 동시에 `suppliers`(테이블 접근자) 같은 자동생성 게터도 필요하다. `extends` 자리는 이미 찼으니 `with`(믹스인)로 끼워넣는다. `extends`는 한 번만, `with`는 여러 개(`with A, B, C`) 가능. `<AppDatabase>`는 제네릭(C#/Java와 동일 개념) — "이 DatabaseAccessor는 AppDatabase 전용"이라는 뜻.

### `SupplierDao(super.db);` — 슈퍼 파라미터 축약형

```dart
SupplierDao(super.db);
// 풀어쓰면:
SupplierDao(AppDatabase db) : super(db);
```

`super.db`는 "파라미터 하나 받아서 그대로 부모 생성자에 넘겨라"를 한 번에 처리하는 Dart 2.17+ 축약 문법. 4개 DAO 전부 이 패턴을 쓴다.

### `Stream<List<Supplier>>` vs `Future<int>`

- `Future<T>` — "언젠가 한 번 T 값을 준다" (C#의 `Task<T>`와 동일 개념)
- `Stream<T>` — "T 값을 여러 번 계속 흘려보낸다" (C#의 `IAsyncEnumerable<T>`/옵저버블에 가까움)
- `Stream<List<Supplier>>` = "거래처 목록이 바뀔 때마다 새 목록을 계속 흘려보내는 스트림". `.watch()`가 이걸 만들어줘서, DB가 바뀔 때마다 화면의 `StreamBuilder`가 자동으로 다시 그려진다.
- `SuppliersCompanion`은 `Supplier`(DB에서 읽은 완성된 행)와 다른, "insert/update할 때 넣을 값들만 담는 전용 클래스". insert 시 `id`/`createdAt`처럼 안 정해도 되는 컬럼이 있을 수 있는데, `Supplier`는 모든 필드가 항상 채워진 상태를 가정하는 클래스라 이런 "일부만 채워진 상태"를 표현할 수 없어서 Companion을 따로 둔다.

### Q: Future는 "내가 쓰고 싶을 때 요청해서 받아오는" 개념이야?

아니다, **"작업은 호출 즉시 시작되고, 완료된 후 결과를 나중에 받는" 개념**이다. `insertSupplier(entry)`를 호출하는 순간 DB insert 작업이 바로 시작되고, 끝나기까지 시간이 걸리니 함수는 결과 대신 `Future<int>`라는 "영수증"을 먼저 돌려준다. C#의 `Task<int>`와 동일 — 호출하면 바로 실행이 시작되고 `Task`/`Future`는 그 실행 중인 작업을 가리키는 핸들일 뿐이다.

`await`은 "이 Future가 끝날 때까지 기다렸다가 끝나면 진짜 값을 꺼내줘"라는 뜻(C#의 `await task`와 동일). `await` 없이 받으면 `int`가 아니라 아직 안 끝났을 수도 있는 `Future<int>` 객체 자체가 온다.

**최종 확인된 이해**: "작업은 즉시 시작되고, 완료된 후 결과를 나중에 받는다" — 정확함.
