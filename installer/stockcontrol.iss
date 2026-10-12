; 재고관리 Windows 설치 프로그램 (Inno Setup 6.3 이상).
; 보통은 직접 컴파일하지 않고 installer\build_installer.ps1을 쓴다:
; 릴리스 빌드 -> VC++ 런타임 DLL 찾기 -> 이 스크립트 컴파일을 한 번에 한다.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif
#ifndef CrtDir
  #error CrtDir(msvcp140.dll 등이 있는 폴더)를 /DCrtDir=... 로 넘겨 주세요. build_installer.ps1이 알아서 넘긴다.
#endif

#define AppName "재고관리"
#define AppExe "stockcontrol.exe"

[Setup]
; AppId는 바꾸지 않는다: 같은 값이어야 새 버전이 옛 버전 위에 설치(업그레이드)된다.
AppId={{C05EB3DD-A332-4A4C-B069-D9EEF9C8D050}
AppName={#AppName}
AppVersion={#AppVersion}
DefaultDirName={autopf}\StockControl
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; 관리자 권한 없이 현재 사용자 폴더(%LOCALAPPDATA%\Programs)에 설치한다.
; 매장 PC에서 관리자 비밀번호를 묻지 않는다.
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=Output
OutputBaseFilename=StockControl-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#AppExe}
; 실행 중인 앱은 설치 전에 닫도록 안내한다 (켜 둔 exe는 덮어쓸 수 없다).
CloseApplications=yes

[Languages]
#if FileExists(CompilerPath + "Languages\Korean.isl")
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"
#endif
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; 릴리스 폴더 전체 (exe, flutter_windows.dll, 플러그인 dll, data 폴더).
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion
; VC++ 런타임: 앱이 직접 가져다 쓰는 세 개를 exe 옆에 둔다 (깨끗한 PC에서도 실행되게).
Source: "{#CrtDir}\msvcp140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#CrtDir}\vcruntime140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#CrtDir}\vcruntime140_1.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent