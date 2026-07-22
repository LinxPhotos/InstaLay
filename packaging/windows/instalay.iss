; Inno Setup script for InstaLay (Windows).
; Compile via scripts/package_windows.ps1 when ISCC is installed.
#ifndef MyAppVersion
  #define MyAppVersion "0.1.0"
#endif
#ifndef MyAppArch
  #define MyAppArch "x64"
#endif
#ifndef MyAppSource
  #define MyAppSource "..\..\build\windows\x64\runner\Release"
#endif
#ifndef MyAppOutputBase
  #define MyAppOutputBase "InstaLay-setup"
#endif

#define MyAppName "InstaLay"
#define MyAppPublisher "Linx"
#define MyAppURL "https://github.com/LinxPhotos/InstaLay"
#define MyAppExeName "instalay.exe"
; Visible Start name is InstaLay; Comment + Keywords + App Paths cover Insta / Lay / Layout.
#define MyAppSearchComment "Insta Lay Layout — Instagram framing canvas"
#define MyAppSearchKeywords "Insta,Lay,Layout,Instagram,instalay"

[Setup]
AppId={{8F3C9A2E-4B1D-4E6A-9C70-1A2B3C4D5E6F}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
; Older builds used "Insta Lay" (space). Always create the current group name.
UsePreviousGroup=no
DisableProgramGroupPage=yes
PrivilegesRequired=admin
OutputBaseFilename={#MyAppOutputBase}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
#if MyAppArch == "arm64"
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#else
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#endif
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

; Remove the pre-rename Start Menu folder and old underscored exe name.
[InstallDelete]
Type: filesandordirs; Name: "{commonprograms}\Insta Lay"
Type: filesandordirs; Name: "{userprograms}\Insta Lay"
Type: files; Name: "{app}\insta_lay.exe"

[Files]
Source: "{#MyAppSource}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\scripts\windows\set_start_menu_keywords.ps1"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
; Flat Programs entry — visible in Windows 11 Start search without opening a folder.
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppSearchComment}"
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppSearchComment}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppSearchComment}"; Tasks: desktopicon

; App Paths: primary instalay.exe plus Insta / Lay / Layout / legacy insta_lay aliases.
; Display name of the pinned tile remains InstaLay (from the .lnk above).
[Registry]
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\{#MyAppExeName}"; ValueType: string; ValueData: "{app}\{#MyAppExeName}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\{#MyAppExeName}"; ValueType: string; ValueName: "Path"; ValueData: "{app}"
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\insta_lay.exe"; ValueType: string; ValueData: "{app}\{#MyAppExeName}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\insta_lay.exe"; ValueType: string; ValueName: "Path"; ValueData: "{app}"
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\Insta.exe"; ValueType: string; ValueData: "{app}\{#MyAppExeName}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\Insta.exe"; ValueType: string; ValueName: "Path"; ValueData: "{app}"
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\Lay.exe"; ValueType: string; ValueData: "{app}\{#MyAppExeName}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\Lay.exe"; ValueType: string; ValueName: "Path"; ValueData: "{app}"
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\Layout.exe"; ValueType: string; ValueData: "{app}\{#MyAppExeName}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\Layout.exe"; ValueType: string; ValueName: "Path"; ValueData: "{app}"

[Run]
; Tag Start Menu shortcuts with System.Keywords (indexed by Windows Search).
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{tmp}\set_start_menu_keywords.ps1"" -ShortcutPaths ""{autoprograms}\{#MyAppName}.lnk"" ""{group}\{#MyAppName}.lnk"" -Keywords {#MyAppSearchKeywords}"; \
  Flags: runhidden waituntilterminated; \
  StatusMsg: "Registering Start Menu search keywords..."
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
