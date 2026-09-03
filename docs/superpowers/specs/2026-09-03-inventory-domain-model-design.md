# 재고관리 앱 — 1차 스펙: 도메인 모델 + 로컬 DB + 입고 등록

## 배경

음식점 대상 재고관리 앱. 전체 로드맵은 10단계로 구성되며, 이번 스펙은 그중 1~3단계
(도메인 모델 확정 → 로컬 DB 스키마 → 입고 등록 화면)를 다룬다. 서버 동기화, 반응형
레이아웃, 안전재고 알림 등은 이후 스펙에서 별도로 다룬다.

## 전체 로드맵 (참고용)

1. 도메인 모델 확정
2. 로컬 DB 스키마 + Drift 세팅 (← 이번 스펙)
3. 입고 등록 화면 (← 이번 스펙)
4. 재고 조회 (로트별, 유통기한 임박 정렬)
5. 폐기/조정 등록
6. 마감 실사 (이론재고 vs 실사재고 차이 리포트)
7. 반응형 레이아웃 분기 (윈도우 대응)
8. 서버 + 동기화 큐
9. 안전재고 알림 + 발주서 생성
10. (선택) POS 연동, 레시피 기반 자동차감
    - 참고: 거래처/품목 대량 등록(엑셀/파일 업로드)도 이 이후 단계에서 별도 스펙으로 검토

## 이번 스펙의 전제

- **대상 매장**: 단일 매장. 매장/지점 엔티티는 도메인 모델에 넣지 않는다.
- **개발/테스트 플랫폼**: Windows 데스크톱. 반응형 레이아웃 분기는 7단계에서 다루므로
  지금은 단일 화면 레이아웃으로만 구현한다.
- **상태관리/DI**: Riverpod. 별도 DI 프레임워크(get_it 등)는 사용하지 않는다 — DB,
  DAO, 리포지토리를 모두 provider로 노출한다.
- **단위 변환**: 품목별 커스텀 단위(예: 양파 1박스 = 20kg)를 지원한다. 다단계 변환
  (박스→캔→g)은 지원하지 않고 단일 배율(conversionFactor)만 지원한다. 이 값은 품목
  관리 화면에서 사용자가 언제든 수정할 수 있는 일반 필드이며, DB 제약이 아니다.
  주의: factor를 변경해도 기존에 생성된 Lot의 remainingQty는 소급 재계산되지 않는다
  (새로 입고되는 로트부터 새 factor 적용).

## 도메인 모델 (lib/domain/)

### Ingredient (재료)
- id, name, category(nullable)
- baseUnit: 재고/사용 단위 (g, ml, ea 중 하나)
- purchaseUnit: 구매 단위 (예: 박스, 캔) — 자유 텍스트
- conversionFactor: 구매단위 1개 = baseUnit 몇 개인지 (예: 1박스=20kg → 20)
- isExpiryTracked: 유통기한 관리 여부 (소금처럼 관리하지 않는 품목 대응)
- safetyStockQty: nullable, 이후 단계(9단계 안전재고 알림)에서 사용 — 지금은 필드만
  존재, 로직 없음

### Supplier (거래처)
- id, name, contact(nullable), memo(nullable)

### Lot (로트)
- id, ingredientId(fk), supplierId(fk, **nullable**)
- receivedDate, expiryDate(nullable — isExpiryTracked=false인 품목은 없음)
- unitCost: baseUnit 당 입고 단가
- remainingQty: 이 로트에 남은 수량 (baseUnit 기준)
  - **비정규화 캐시**: StockMovement 생성 시 같은 트랜잭션 안에서 함께 갱신한다.
    매 조회마다 SUM으로 재계산하지 않는 이유는 재고 조회가 가장 잦은 연산이기
    때문. 6단계(마감 실사)에서 "원장 재계산값 vs 캐시값" 대사 로직으로 정합성을
    검증할 수 있다.
- supplierId가 nullable인 이유: 초기재고 등록(앱 도입 시점의 기존 재고)은 특정
  거래처 거래가 아니므로 거래처 없이 Lot을 생성할 수 있어야 한다.

### StockMovement (재고이동/원장)
- id, lotId(fk, **not null** — 모든 이동은 반드시 하나의 Lot에 귀속된다)
- type: inbound | usage | disposal | adjustment | countCorrection
- quantity: 부호 있는 값, baseUnit 기준 (+입고, -출고/폐기)
- occurredAt, memo(nullable), createdAt
- 이것이 "진실의 원장"이다. Lot.remainingQty는 여기서 파생되며, 대사 가능해야 한다.
- **초기재고 등록**: 별도 이동 타입을 추가하지 않는다. Lot 생성(supplierId=null) +
  StockMovement(type=adjustment, memo="초기재고")로 표현한다.

## 로컬 DB 스키마 (Drift) — lib/data/local/tables/

```
Suppliers: id(pk, autoinc), name, contact(nullable), memo(nullable), createdAt

Ingredients: id(pk, autoinc), name, category(nullable),
  baseUnit(text: 'g'|'ml'|'ea'), purchaseUnit(text),
  conversionFactor(real), isExpiryTracked(bool),
  safetyStockQty(real, nullable), createdAt

Lots: id(pk, autoinc), ingredientId(fk), supplierId(fk, nullable),
  receivedDate(dateTime), expiryDate(dateTime, nullable),
  unitCost(real), remainingQty(real), createdAt

StockMovements: id(pk, autoinc), lotId(fk),
  type(text: 'inbound'|'usage'|'disposal'|'adjustment'|'countCorrection'),
  quantity(real), occurredAt(dateTime), memo(nullable), createdAt
```

이번 단계에서는 음수 재고 방지 등의 제약을 스키마에 걸지 않는다. usage/disposal
UI가 구현되는 4~5단계에서 애플리케이션 레벨 검증을 추가한다.

## 입고 등록 화면 (lib/features/inbound/)

**흐름**: 거래처 선택(또는 신규 등록) → 품목 선택(또는 신규 등록) → 수량 입력
(purchaseUnit 기준, baseUnit 환산값을 자동 표시) → 단가 입력 → 유통기한 입력
(isExpiryTracked=true인 품목만) → 저장

**저장 시 트랜잭션**: `Lot` 1건 생성 + `StockMovement`(type=inbound,
quantity=+환산된 baseUnit 수량) 1건 생성. `db.transaction()`으로 원자성 보장,
실패 시 자동 롤백.

**구성**:
- `InboundFormScreen` (ConsumerWidget)
- `inboundFormProvider` — 폼 상태(선택된 거래처/품목/입력값) 관리
- `SupplierRepository`, `IngredientRepository`, `LotRepository` — DAO를 감싸는
  provider

거래처/품목 "신규 등록"이 없으면 입고 등록 자체를 테스트할 수 없으므로, 최소한의
관리 화면(목록 + 등록 폼)을 이번 스펙에 포함한다. 엑셀/파일 업로드를 통한 대량
등록은 이번 스펙 범위 밖이며, 이후 별도 스펙(발주서/거래처 관리 고도화 시점)에서
다룬다.

## 파일 구조

```
lib/
  domain/
    ingredient.dart
    unit.dart              # baseUnit enum
    lot.dart
    stock_movement.dart
    supplier.dart
  data/
    local/
      database.dart         # Drift @DriftDatabase
      tables/
        suppliers_table.dart
        ingredients_table.dart
        lots_table.dart
        stock_movements_table.dart
      daos/
        supplier_dao.dart
        ingredient_dao.dart
        lot_dao.dart
        stock_movement_dao.dart
    repositories/
      supplier_repository.dart
      ingredient_repository.dart
      lot_repository.dart
  features/
    inbound/
      inbound_form_screen.dart
      inbound_form_provider.dart
    supplier_management/
      supplier_list_screen.dart
    ingredient_management/
      ingredient_list_screen.dart
  main.dart
```

## 테스트 전략

- Drift `NativeDatabase.memory()`로 인메모리 DB를 띄워 DAO 단위 테스트 (파일 I/O
  없이 빠른 검증)
- 핵심 검증 대상:
  - 입고 시 Lot 생성 + StockMovement 생성 + remainingQty 갱신이 하나의 트랜잭션으로
    원자적으로 처리되는가
  - conversionFactor 환산이 정확한가
  - 초기재고 등록(supplierId=null, type=adjustment) 케이스가 정상 동작하는가
- 위젯 테스트는 입고 폼의 필수값 검증(수량/단가 미입력 시 저장 차단) 정도로 최소화

## 이번 스펙의 범위 밖 (다음 단계에서 다룸)

- 로트별 재고 조회, 유통기한 임박 정렬 (4단계)
- 폐기/조정 UI, 음수 재고 방지 검증 (5단계)
- 마감 실사 리포트 (6단계)
- 반응형 레이아웃/모바일 대응 (7단계)
- 서버 동기화 (8단계)
- 안전재고 알림/발주서 (9단계)
- 거래처/품목 엑셀 업로드 대량 등록
