[CmdletBinding()]
param([switch]$Installer)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Windows and Visual Studio C++ tools are required.' }
if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64') { throw 'This build kit targets Windows x64. Use an x64 Windows host.' }
$Root = Split-Path $PSScriptRoot -Parent
$Dist = Join-Path $Root 'dist'
New-Item -ItemType Directory -Force -Path $Dist | Out-Null
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:DASH__SUPPRESS_ANALYTICS = 'true'
function Invoke-Flutter {
    param([string[]]$Arguments)
    & flutter @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Flutter command failed: $($Arguments -join ' ')" }
}
Push-Location $Root
Start-Transcript -Path (Join-Path $Dist 'windows-build.log') -Force | Out-Null
try {
    $VsWhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path $VsWhere)) { throw 'Install Visual Studio with Desktop development with C++.' }
    $Vs = (& $VsWhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
    if (-not $Vs) { throw 'The Visual Studio C++ workload was not found.' }
    & (Join-Path $PSScriptRoot 'bootstrap-flutter.ps1')
    Invoke-Flutter -Arguments @('config', '--enable-windows-desktop')
    Invoke-Flutter -Arguments @('pub', 'get', '--enforce-lockfile')
    Invoke-Flutter -Arguments @('analyze', '--no-pub', 'lib/desktop', 'lib/main.dart', 'lib/utils/app_settings_manager.dart', 'lib/services/pip_manager.dart', 'lib/components/player/player_device_control_mixin.dart', 'lib/components/player/player_playback_controller.dart', 'lib/components/player/player_gesture_handler.dart', 'lib/components/player/video_player_widget.dart', 'lib/pages/play_page.dart', 'lib/pages/live_play_page.dart', 'lib/pages/custom_player_page.dart', 'lib/pages/settings_page.dart', 'lib/tv/tv_home_design.dart', 'test/windows_input_test.dart', 'integration_test/windows_smoke_test.dart')
    Invoke-Flutter -Arguments @('test', '--no-pub')
    $Fixture = Join-Path $Root 'integration_test\fixtures\smoke.mp4'
    Invoke-Flutter -Arguments @('test', 'integration_test/windows_smoke_test.dart', '-d', 'windows', "--dart-define=EUB_TEST_MEDIA_PATH=$Fixture")
    Invoke-Flutter -Arguments @('build', 'windows', '--release', '--no-pub')
    $Release = Join-Path $Root 'build\windows\x64\runner\Release'
    if (-not (Test-Path (Join-Path $Release 'EUBDanmaku.exe'))) { throw 'Release executable is missing.' }
    if (-not (Test-Path (Join-Path $Release 'libmpv-2.dll'))) { throw 'Windows playback DLL is missing.' }
    $Match = [regex]::Match((Get-Content (Join-Path $Root 'pubspec.yaml') -Raw), '(?m)^version:\s*(\d+\.\d+\.\d+)')
    if (-not $Match.Success) { throw 'Cannot determine app version.' }
    $Version = $Match.Groups[1].Value
    $Crt = Get-ChildItem -Path (Join-Path $Vs 'VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT') -Directory | Sort-Object FullName -Descending | Select-Object -First 1
    if (-not $Crt) { throw 'Visual C++ app-local redistributable DLLs were not found.' }
    Copy-Item -Path (Join-Path $Crt.FullName '*.dll') -Destination $Release -Force
    Copy-Item -Path (Join-Path $Root 'LICENSE') -Destination (Join-Path $Release 'EUB-LICENSE.txt') -Force
    @"
EUB Danmaku Windows $Version
Run EUBDanmaku.exe. Keep the data folder and all DLL files together.
Space: play/pause. Left/Right: seek 10 seconds. Up/Down: application volume.
M: mute. F/F11 or double-click video: fullscreen. Esc: exit video fullscreen.
Ctrl+K: search. Ctrl+H: history.
"@ | Set-Content -Encoding UTF8 (Join-Path $Release 'README-Windows.txt')
    $NoticeDir = Join-Path $Release 'ThirdPartyNotices'
    New-Item -ItemType Directory -Force -Path $NoticeDir | Out-Null
    $Cache = if ($env:PUB_CACHE) { $env:PUB_CACHE } else { Join-Path $env:LOCALAPPDATA 'Pub\Cache' }
    foreach ($Package in @('media_kit', 'media_kit_video', 'video_player_media_kit', 'media_kit_libs_windows_video', 'window_manager')) {
        $PackageDir = Get-ChildItem -Path (Join-Path $Cache "hosted\pub.dev\$Package-*") -Directory | Sort-Object Name -Descending | Select-Object -First 1
        if ($PackageDir) { Get-ChildItem -Path $PackageDir.FullName -File -Filter 'LICENSE*' | ForEach-Object { Copy-Item $_.FullName (Join-Path $NoticeDir "$Package-$($_.Name)") -Force } }
    }
    foreach ($Dependency in @('libmpv', 'ANGLE')) {
        $Folder = Join-Path $Root "build\windows\x64\$Dependency"
        if (Test-Path $Folder) {
            Get-ChildItem $Folder -Recurse -File | Where-Object { $_.Name -match '^(LICENSE|COPYING|COPYRIGHT)' } | ForEach-Object {
                $Relative = $_.FullName.Substring($Folder.Length).TrimStart('\', '/')
                $Target = Join-Path $NoticeDir (Join-Path $Dependency $Relative)
                New-Item -ItemType Directory -Force -Path (Split-Path $Target -Parent) | Out-Null
                Copy-Item $_.FullName $Target -Force
            }
        }
    }
    $Zip = Join-Path $Dist "EUBDanmaku-$Version-Windows-x64-portable.zip"
    Compress-Archive -Path (Join-Path $Release '*') -DestinationPath $Zip -Force
    if ($Installer) {
        $Iscc = Get-Command 'ISCC.exe' -ErrorAction SilentlyContinue
        $Compiler = if ($Iscc) { $Iscc.Source } else { Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe' }
        if (-not (Test-Path $Compiler)) { throw 'Install Inno Setup 6.3 or later to create the installer.' }
        & $Compiler "/DAppVersion=$Version" "/DSourceDir=$Release" "/DOutputDir=$Dist" (Join-Path $Root 'packaging\EUBWindows.iss')
        if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed.' }
    }
    Get-ChildItem $Dist -File | Where-Object { $_.Extension -in '.zip', '.exe' } | ForEach-Object {
        $Hash = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
        "$Hash  $($_.Name)"
    } | Set-Content -Encoding ASCII (Join-Path $Dist 'SHA256SUMS.txt')
    Write-Host "Windows build completed: $Dist"
} finally {
    Stop-Transcript | Out-Null
    Pop-Location
}
