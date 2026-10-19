#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\dist"
#endif
[Setup]
AppId=EUB.Danmaku.Windows
AppName=EUB弹幕
AppVersion={#AppVersion}
AppPublisher=EUB
DefaultDirName={localappdata}\Programs\EUBDanmaku
DefaultGroupName=EUB弹幕
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=EUBDanmaku-{#AppVersion}-Windows-x64-setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\EUBDanmaku.exe
LicenseFile=..\LICENSE
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; Flags: unchecked
[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{autoprograms}\EUB弹幕"; Filename: "{app}\EUBDanmaku.exe"
Name: "{autodesktop}\EUB弹幕"; Filename: "{app}\EUBDanmaku.exe"; Tasks: desktopicon
[Run]
Filename: "{app}\EUBDanmaku.exe"; Description: "启动 EUB弹幕"; Flags: nowait postinstall skipifsilent
