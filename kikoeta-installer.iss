; Kikoeta Windows installer (Inno Setup 6).
; Pass version/source/output values with ISCC /D parameters. The workflow
; reads the version from app/pubspec.yaml, so the installer cannot drift.

#define MyAppName "Kikoeta"
#define MyAppPublisher "chenflxs"
#define MyAppURL "https://github.com/chenflxs/kikoeta"
#define MyAppExeName "kikoeta_app.exe"

#ifndef MyAppVersion
#define MyAppVersion "0.0.0"
#endif
#ifndef MyAppVersionCode
#define MyAppVersionCode "0"
#endif
#ifndef MySourceDir
#define MySourceDir "."
#endif
#ifndef MyOutputDir
#define MyOutputDir "."
#endif
#ifndef MyOutputBaseFilename
#define MyOutputBaseFilename "kikoeta-windows-setup"
#endif
#ifndef MyArchitecturesAllowed
#define MyArchitecturesAllowed "x64compatible"
#endif

[Setup]
AppId={{8E2C9F41-7A3B-4D5E-9C10-2F6B8D4A1E57}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={code:GetDefaultDir}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir={#MyOutputDir}
OutputBaseFilename={#MyOutputBaseFilename}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed={#MyArchitecturesAllowed}
ArchitecturesInstallIn64BitMode={#MyArchitecturesAllowed}
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务:"; Flags: checkedonce

[Files]
Source: "{#MySourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "kikoeta_data"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "运行 {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\kikoeta_data"

[Code]
function GetDefaultDir(Param: string): string;
begin
  if DirExists('D:\') then
    Result := 'D:\kikoeta'
  else
    Result := ExpandConstant('{localappdata}\Programs\Kikoeta');
end;
