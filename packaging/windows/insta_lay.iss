; Inno Setup script for Insta Lay (Windows).
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

#define MyAppName "Insta Lay"
#define MyAppPublisher "AMDphreak"
#define MyAppURL "https://github.com/amdphreak/insta-lay"
#define MyAppExeName "insta_lay.exe"

[Setup]
AppId={{8F3C9A2E-4B1D-4E6A-9C70-INSTALAY0001}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputBaseFilename=InstaLay-{#MyAppVersion}-windows-{#MyAppArch}-setup
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

[Files]
Source: "{#MyAppSource}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
