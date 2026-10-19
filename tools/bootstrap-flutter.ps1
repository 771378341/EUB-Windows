[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'This SDK bootstrap must run on Windows.' }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Install Git for Windows before running Flutter.' }
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:DASH__SUPPRESS_ANALYTICS = 'true'
$Version = '3.47.3'
$ExpectedHash = '44822ab53afb543c6fb446c078ba4f495e3eeddaafb88d879bde606447ddce24'
$SdkParent = Join-Path $env:LOCALAPPDATA "EUBBuild\Flutter-$Version"
$SdkBin = Join-Path $SdkParent 'flutter\bin'
$Flutter = Join-Path $SdkBin 'flutter.bat'
if (-not (Test-Path $Flutter)) {
    New-Item -ItemType Directory -Force -Path $SdkParent | Out-Null
    $Archive = Join-Path $env:TEMP "EUB-Flutter-$Version.zip"
    if ((-not (Test-Path $Archive)) -or ((Get-FileHash -Algorithm SHA256 $Archive).Hash.ToLowerInvariant() -ne $ExpectedHash)) {
        Invoke-WebRequest -UseBasicParsing -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_$Version-stable.zip" -OutFile $Archive
    }
    if ((Get-FileHash -Algorithm SHA256 $Archive).Hash.ToLowerInvariant() -ne $ExpectedHash) { throw 'Flutter SDK checksum mismatch.' }
    Expand-Archive -Path $Archive -DestinationPath $SdkParent -Force
}
$env:PATH = "$SdkBin;$env:PATH"
if ($env:GITHUB_PATH) { Add-Content -Path $env:GITHUB_PATH -Value $SdkBin }
& $Flutter --disable-analytics
if ($LASTEXITCODE -ne 0) { throw 'Flutter SDK initialization failed.' }
& $Flutter --version
if ($LASTEXITCODE -ne 0) { throw 'Unable to run Flutter SDK.' }
Write-Host "Flutter $Version is ready at $Flutter"
