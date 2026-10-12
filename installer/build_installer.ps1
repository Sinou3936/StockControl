# 재고관리 Windows 설치 프로그램을 만든다.
#   사용: powershell -ExecutionPolicy Bypass -File installer\build_installer.ps1
#         (이미 빌드해 둔 릴리스 폴더를 쓰려면 -SkipBuild)
# 결과: installer\Output\StockControl-Setup-<버전>.exe  (버전은 pubspec.yaml의 version)
param([switch]$SkipBuild)
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

# 1. 버전: pubspec.yaml의 `version: 1.0.0+1` 에서 +뒤를 뺀 1.0.0
$versionLine = Select-String -Path pubspec.yaml -Pattern '^version:\s*([0-9]+(\.[0-9]+)*)' | Select-Object -First 1
if (-not $versionLine) { throw 'pubspec.yaml에서 version을 찾지 못했습니다.' }
$version = $versionLine.Matches[0].Groups[1].Value
Write-Host "버전: $version"

# 2. 릴리스 빌드 (앱이 켜져 있으면 exe를 덮어쓰지 못하니 먼저 끈다)
if (-not $SkipBuild) {
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'flutter build windows --release 가 실패했습니다.' }
}
$release = Join-Path $root 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $release 'stockcontrol.exe'))) {
    throw "릴리스 빌드가 없습니다: $release"
}

# 3. Inno Setup 컴파일러 찾기
$iscc = @(
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
    throw "Inno Setup 6이 없습니다. 설치: winget install JRSoftware.InnoSetup"
}

# 4. VC++ 런타임 DLL(msvcp140, vcruntime140, vcruntime140_1) 폴더 찾기:
#    Visual Studio의 재배포용 폴더 (VC\Redist\MSVC\<버전>\x64\Microsoft.VC*.CRT).
$crt = Get-ChildItem "$env:ProgramFiles\Microsoft Visual Studio", "${env:ProgramFiles(x86)}\Microsoft Visual Studio" `
        -Recurse -Filter vcruntime140_1.dll -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\Redist\\MSVC\\[^\\]+\\x64\\Microsoft\.VC\d+\.CRT\\' } |
    Sort-Object FullName -Descending | Select-Object -First 1
if (-not $crt) { throw 'Visual Studio의 VC 재배포 폴더(Redist\MSVC\...\x64\Microsoft.VC*.CRT)를 찾지 못했습니다.' }
$crtDir = $crt.DirectoryName
foreach ($name in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
    if (-not (Test-Path (Join-Path $crtDir $name))) { throw "$name 이(가) $crtDir 에 없습니다." }
}
Write-Host "VC 런타임: $crtDir"

# 5. 컴파일
& $iscc "/DAppVersion=$version" "/DSourceDir=$release" "/DCrtDir=$crtDir" (Join-Path $PSScriptRoot 'stockcontrol.iss')
if ($LASTEXITCODE -ne 0) { throw 'Inno Setup 컴파일이 실패했습니다.' }

$out = Join-Path $PSScriptRoot "Output\StockControl-Setup-$version.exe"
Write-Host "완료: $out"