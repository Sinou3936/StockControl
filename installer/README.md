# Windows 설치 프로그램

매장 PC에 앱을 설치하는 `StockControl-Setup-<버전>.exe`를 만든다 ([Inno Setup](https://jrsoftware.org/isinfo.php) 사용).

## 만들기

1. 한 번만: Inno Setup 6.3 이상을 설치한다 — `winget install JRSoftware.InnoSetup`
2. 켜져 있는 재고관리 앱을 끈다 (켜 둔 exe는 다시 빌드할 수 없다).
3. 저장소 폴더에서:
   ```powershell
   powershell -ExecutionPolicy Bypass -File installer\build_installer.ps1
   ```
   릴리스 빌드 → VC++ 런타임 DLL 찾기 → 설치 프로그램 컴파일을 한 번에 한다.
   이미 빌드해 둔 릴리스 폴더를 쓰려면 `-SkipBuild`.
4. 결과: `installer\Output\StockControl-Setup-1.0.0.exe`. 이 파일 하나를 매장 PC로 옮겨 실행한다.

버전은 `pubspec.yaml`의 `version:`(예: `1.0.0+1`의 `1.0.0`)을 따른다. 새 버전을 낼 때 그 숫자를 올린다.

## 설치되는 곳과 동작

- 관리자 권한 없이 `%LOCALAPPDATA%\Programs\StockControl`에 설치한다 (시작 메뉴 바로가기, 바탕화면 바로가기는 선택).
- 새 버전은 같은 설치 프로그램을 다시 실행하면 옛 버전 위에 덮어 설치된다 (`AppId`가 같아서). 켜져 있는 앱은 설치 전에 닫도록 안내한다.
- **데이터는 지워지지 않는다.** 로컬 DB는 `Documents\stockcontrol.sqlite`에 있고 설치·제거와 상관없다.
- VC++ 런타임(`msvcp140.dll`, `vcruntime140.dll`, `vcruntime140_1.dll`)을 exe 옆에 함께 넣어서 깨끗한 PC에서도 실행된다. 이 DLL은 빌드할 때 이 PC의 Visual Studio 재배포 폴더에서 복사한다 (저장소에는 들어 있지 않다).

## 알아 둘 점

- 설치 프로그램에 코드 서명이 없어서 처음 실행하면 Windows SmartScreen이 "알 수 없는 게시자" 경고를 띄울 수 있다 (추가 정보 → 실행). 서명 인증서를 사면 없앨 수 있다.
- `AppId`(`installer\stockcontrol.iss`)는 바꾸지 않는다. 바꾸면 업그레이드가 아니라 별개 프로그램으로 설치된다.