# 재고관리 (StockControl)

11개 매장을 가진 음식점 체인을 위한 **재고관리 앱**입니다. 매장마다 입고·폐기·마감 실사를 기록하고, 사장은 전체 매장의 재고를 한눈에 봅니다. 오프라인에서도 저장이 항상 성공하고, 서버 동기화는 뒤에서 도는 큐가 맡습니다.

Windows PC(매장 PC)와 안드로이드 폰에서 같은 코드로 돌아갑니다.

## 주요 기능

- **재고 조회**: 품목별 재고와 로트(입고 묶음)별 수량, 유통기한 임박 표시. 날짜를 골라 **그날 끝 기준 재고**를 볼 수 있고, 그날 입고한 내역도 봅니다.
- **입고 등록**: 거래처·품목·수량(구매 단위)·단가·유통기한을 입력하면 기본 단위로 환산해 저장합니다.
- **폐기·조정, 마감 실사**: 재고는 덮어쓰지 않고 기록을 추가합니다. 실사 차이는 조정 기록으로 남습니다.
- **안전재고 알림과 발주서**: 안전재고보다 부족한 품목을 보여 주고, 거래처별 발주서를 PDF나 엑셀 파일로 만듭니다.
- **엑셀 업로드** (사장 전용): 양식을 받아 채운 `.xlsx`로 거래처·품목·입고를 한 번에 등록합니다. 올리기 전에 미리보기와 오류 줄 번호를 보여 줍니다.
- **매장·직원 관리**: 사장 계정과 직원(PIN 로그인) 계정. 직원은 자기 매장만 봅니다.
- **여러 기기 동기화**: 로컬 DB에 먼저 저장하고, 서버(Supabase)로 보내고 받는 큐가 백그라운드에서 돕니다.

## 기술 구성

| 영역 | 사용 |
|---|---|
| 앱 | Flutter (Windows, Android), Dart ^3.11 |
| 로컬 DB | [Drift](https://drift.simonbinder.eu/) (SQLite) — 로컬이 항상 기준 |
| 상태·의존성 | Riverpod |
| 서버 | Supabase (인증, Postgres) |
| 파일 | `excel`, `pdf`, `file_picker` |

핵심 설계: 재고는 덮어쓰는 수량이 아니라 **입출고 기록(`StockMovement`)을 로트별로 더한 값**입니다. 기록은 추가만 하고 고치지 않습니다.

## 폴더 구조

```
lib/
  main.dart            앱 시작
  core/                공통: 설정, 로케일, 포맷, 테마, 위젯, 앱 껍데기(탭·메뉴)
  domain/              순수 규칙 (환산, 임박 판정, 안전재고, 엑셀 검증 등) — Flutter·DB에 의존하지 않음
  data/
    local/             Drift 테이블과 DAO
    repositories/      저장·동기화 로직
    import/, export/   엑셀 업로드 읽기·저장, 발주서 파일 만들기
    services/          서버(Supabase) 연결
  features/            화면 (재고, 입고, 실사, 발주, 엑셀 업로드, 품목·거래처·매장 관리, 로그인)
test/                  lib/와 같은 구조의 테스트
docs/                  설계(specs)·구현 계획(plans)·코드 리뷰 기록
installer/             Windows 설치 프로그램 (Inno Setup)
tool/                  PDF 안내서 만드는 스크립트
```

## 개발 환경에서 실행하기

필요한 것

- Flutter 3.41 이상 (Dart 3.11)
- Windows 데스크톱 빌드: Visual Studio의 **"C++를 사용한 데스크톱 개발"** 워크로드, Windows **개발자 모드** 켜기 (플러그인이 심볼릭 링크를 씁니다)
- 안드로이드: Android SDK와 에뮬레이터 또는 기기

```powershell
flutter pub get
flutter run -d windows        # 또는 안드로이드 기기·에뮬레이터
```

- 서버 접속 정보는 `lib/core/config/supabase_config.dart`에 있습니다.
- Drift가 만든 `*.g.dart`는 저장소에 들어 있습니다. 테이블이나 DAO를 고쳤을 때만 `dart run build_runner build`를 다시 돌립니다.
- Chrome(웹)은 지원하지 않습니다.
- 로컬 DB 파일은 Windows에서 `Documents\stockcontrol.sqlite`입니다. 스키마가 바뀐 옛 DB로 `no such table` 오류가 나면 이 파일을 지우거나(Windows), `adb shell pm clear com.khs.stockcontrol`(에뮬레이터)로 지웁니다. 진짜 마이그레이션은 아직 없습니다.

## 테스트

```powershell
flutter analyze
flutter test --timeout 90s
```

- Windows에서는 **`flutter test`를 동시에 두 개 돌리지 마세요.** 둘 다 `sqlite3.dll`을 같은 곳에 복사하다가 도구가 죽습니다.
- 화면 테스트에서 실제 스트림을 `await ...first`로 기다리면 멈춥니다. 값은 `db.select(...).get()`으로 읽습니다.

## 빌드와 배포

- **Windows 설치 프로그램**: `installer\build_installer.ps1`이 릴리스 빌드부터 `StockControl-Setup-<버전>.exe`까지 만듭니다. 자세한 방법은 [installer/README.md](installer/README.md)를 보세요. 버전은 `pubspec.yaml`의 `version:`을 따릅니다.
- **안드로이드 APK**: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`
- **설치 방법 안내서 PDF**: `dart run tool/make_install_guide.dart` → `docs/manual/install-guide.pdf`

## 문서

- 단계마다 `docs/superpowers/specs/`에 설계, `docs/superpowers/plans/`에 구현 계획이 있습니다. 새 작업을 시작하기 전에 관련 스펙을 먼저 읽습니다.
- 코드 리뷰 질문과 판단 기록: [docs/code-review-notes.md](docs/code-review-notes.md)
- 개발 규칙과 틀리기 쉬운 점(동기화, 시간대, 테스트 요령 등): [CLAUDE.md](CLAUDE.md)

## 기여할 때 주의

이 저장소는 **공개**입니다. 다음은 절대 올리지 않습니다.

- 실제 거래처·품목·매장 이름이나 실제 입고 데이터 (샘플과 테스트는 `가나다상사`, `쌀 20KG` 같은 일반 이름을 씁니다)
- 업무 화면 캡처, 거래명세서, 실제 엑셀 파일. 설계에 쓴 샘플은 `excel_samples/`(무시됨)에 둡니다.
- 사용 설명서 PDF와 캡처 (`*.pdf`, `docs/manual/`은 git이 무시합니다)

## 라이선스

아직 정하지 않았습니다.
