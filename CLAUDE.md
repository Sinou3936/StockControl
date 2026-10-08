# StockControl

11개 매장 음식점 체인의 재고관리 앱. Flutter + Drift(로컬 SQLite) + Riverpod, 서버는 Supabase. 오프라인에서도 저장이 항상 성공해야 하고, 서버 동기화는 뒤에서 도는 큐다.

로드맵 1~9단계(도메인, 입고, 재고 조회, 폐기/조정, 마감 실사, 반응형, 서버·동기화, 안전재고 알림, 발주서 파일)는 끝났다. 무엇이 남았는지는 대화에서 사용자에게 확인한다.

## 문서

- 단계마다 `docs/superpowers/specs/`에 설계, `docs/superpowers/plans/`에 구현 계획이 있다. 새 작업을 시작하기 전에 관련 스펙을 먼저 읽는다 (예: 안전재고는 `2026-10-06-safety-stock-alert-design.md`, 발주서는 `2026-10-07-purchase-order-design.md`).
- 코드 리뷰 질문과 판단 기록은 `docs/code-review-notes.md`.
- `.superpowers/`는 git이 무시하는 작업 일지 폴더다 (서브에이전트 작업의 지시서·보고서·판단 기록). 코드의 근거가 필요하면 거기서 찾는다.

## 작업 방식

- `main`에서 바로 작업한다 (혼자 개발하므로 브랜치를 쓰지 않기로 했다). **푸시는 사용자가 말할 때만 한다.**
- 새 기능은 스펙 → 계획 → 구현 순서로 간다. 사용자가 승인한 단계 밖으로 나가지 않는다.
- 작업마다 독립 검토를 붙인다. 검토가 구현자가 못 본 결함을 거의 매번 잡았다. 테스트는 변이(구현 한 줄을 일부러 망가뜨려 테스트가 실패하는지)로 실제로 무는지 확인한다.
- 사용자는 개발자이고 Dart·Flutter를 배우는 중이다. 한국어로 답하고, 코드가 왜 그렇게 동작하는지 설명한다. 앱의 사장(owner)·직원(staff) 역할과 대화 상대를 구분한다 — 사장님은 앱의 최종 사용자다.
- 커밋: 메시지는 영어, 끝에 세션이 지시하는 `Co-Authored-By` 줄. PowerShell에서는 `git commit -m "제목" -m "Co-Authored-By: ..."`처럼 `-m`을 두 번 쓴다 (메시지 안에 큰따옴표를 넣으면 인용이 깨진다).
- `git add`는 경로를 직접 적는다. `dart format`은 건드린 파일에만 돌린다 (`dart format lib`는 건드리지 않은 파일 수십 개를 바꾼다).

## Windows 개발 환경

- **`flutter test`를 동시에 두 개 돌리지 않는다.** 둘 다 `sqlite3.dll`을 같은 곳에 복사하다 도구가 죽는다. 하나가 끝난 뒤에 다음을 돌린다.
- 테스트는 항상 `--timeout`을 주고 출력을 파일로 받는다: `flutter test <경로> --timeout 60s --reporter expanded *> $env:TEMP\t.log; Get-Content $env:TEMP\t.log -Tail 25`. 출력을 필터에 바로 물리면 끝날 때까지 아무것도 안 보여서 멈춘 것과 구별되지 않는다. 멈추면 `Get-Process dart,flutter_tester | Stop-Process -Force`.
- 플러그인이 든 앱을 빌드하려면 Windows **개발자 모드**가 켜져 있어야 한다 (`Building with plugins requires symlink support`). 만드는 PC에서만 필요하고 매장 PC에는 필요 없다.
- 켜 둔 Windows 앱은 실행 파일을 덮어쓰지 못해 다시 빌드할 수 없다 (`LNK1168`). 먼저 끈다.
- `python`은 Microsoft Store 안내 프로그램이라 멈춘다. `py -3`를 쓴다.
- Chrome/web은 지원하지 않는다. 두 기기 동기화는 Windows + 에뮬레이터로 시험한다.
- GitHub 푸시가 `Internal Server Error`로 거부되면 서버 장애일 수 있다. 상태 페이지는 몇 분 늦게 따라온다. 강제 옵션을 쓰지 않고 기다렸다가 다시 한다.

## 테스트를 쓸 때

- `testWidgets` 안에서 `await dao.watchAll().first`처럼 실제 스트림을 기다리면 영원히 멈춘다 (가짜 시계가 Drift의 타이머를 못 돌린다). 값은 `await db.select(db.table).get()`으로 읽는다.
- 끝날 때 `await tester.pumpWidget(const SizedBox.shrink()); await tester.pump(const Duration(milliseconds: 1));`로 화면을 치워 Drift의 정리 타이머를 돌려보낸다.
- 탭 화면(`AppShell` 안)은 성공 후에 `Navigator.pop()`하면 앱 전체가 사라진다. 폼을 비우고 SnackBar를 띄운다. 이런 화면의 테스트는 푸시된 라우트 뒤가 아니라 `home`으로 올린다.
- 테스트에서 `package:drift/drift.dart`를 가져오면서 `isNull`/`isNotNull`을 쓰면 `hide isNotNull, isNull`을 붙인다.
- excel 패키지의 `TextCellValue.value`는 문자열이 아니라 `TextSpan`이다. 읽을 때 `.value.text`.

## 데이터와 동기화에서 틀리기 쉬운 것

- 재고는 덮어쓰는 수량이 아니라 **입출고 기록(`StockMovement`)을 로트별로 더한 값**이다. 기록은 추가만 하고 고치지 않는다. `Lot.remainingQty`는 그 합계의 사본이고 서버로 동기화되지 않는다 — 다른 기기에서 받은 뒤에 기록 합계로 다시 계산한다.
- **Supabase로 보내는 시간은 항상 UTC**(`toUtc().toIso8601String()`)로. 로컬 시간은 시간대 없이 직렬화되어 서버가 UTC로 읽고, 한국 기기의 받기 기준점이 9시간 앞서가 아무것도 못 받는다.
- 받기 기준점은 기기의 `created_at`이 아니라 **서버가 찍는 `synced_at`**이다. 서버에서 값이 바뀌는 테이블은 UPDATE 때도 `synced_at`을 새로 찍는 트리거가 있어야 한다 (`ingredients`에 `touch_synced_at`가 걸려 있다).
- 보내기는 순서대로 하다가 실패하면 멈춘다. 서버가 영구히 거부하는 한 줄이 뒤를 막는다 (dead-letter 처리 없음).
- 매장 범위: 직원은 자기 매장으로 고정, 사장은 `selectedStoreProvider`이고 `null`이 "전체 합산"이다. `activeStoreIdProvider`의 `null`은 "전체 합산"과 "매장 없는 직원" 둘 다라서, 직원에게 전 매장이 보이면 안 되는 화면(부족 재고)은 세션 역할에서 직접 범위를 정한다.
- 안전재고가 `null`이거나 0 이하면 그 품목은 추적하지 않는다. 입력창은 읽을 수 없는 글자를 `null`로 저장하지 않고 오류를 보인다 (조용히 알림이 꺼진다).
- drift가 만든 데이터 클래스의 `==`는 모든 열을 비교한다. 화면이 붙잡아 둔 객체는 그 행이 바뀌면 목록의 항목과 달라져 `DropdownButton`이 값 일치 단정에 걸린다. 객체 대신 id로 목록에서 다시 찾아 넘긴다.
- 로컬 DB에는 진짜 마이그레이션이 없다 (`schemaVersion` 5, `onUpgrade`는 `from < 2`만 처리). 옛 DB를 가진 기기는 `no such table` 오류가 난다. 에뮬레이터는 `adb shell pm clear com.khs.stockcontrol`, Windows는 `Documents\stockcontrol.sqlite`를 지운다. 스키마를 바꾸는 작업은 이 점을 계획에 넣는다.
- Supabase 테이블과 트리거는 SQL Editor에서 손으로 만들었고 저장소에 SQL 파일이 없다. 새 외래키를 달면 `NOTIFY pgrst, 'reload schema';`를 한 번 돌려야 PostgREST가 관계를 인식한다.
- 수량 표시는 `formatQty`. 위젯 카드는 테두리를 `Container` 장식에 맡기지 말고 `Material(shape: RoundedRectangleBorder(side: ...))`로 그린다 — 불투명한 자식이 둥근 모서리의 테두리를 덮는다.
