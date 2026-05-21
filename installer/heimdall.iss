; Heimdall — Inno Setup script
; Compile from the repo root with:
;   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\heimdall.iss
; Output lands in build\installer\.

#define MyAppName        "Heimdall"
#define MyAppVersion     "1.4.8"
#define MyAppPublisher   "Larry Hsiao"
#define MyAppURL         "https://github.com/LarryHsiao/Heimdall"
#define MyAppExeName     "heimdall.exe"
#define MyAppSourceDir   "..\build\windows\x64\runner\Release"
#define MyAppOutputDir   "..\build\installer"

[Setup]
; A fixed GUID — keep this constant across versions so upgrades replace cleanly.
AppId={{4D8B7E2C-9F31-4E1A-A6D7-2B3C5F0E1A98}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
LicenseFile=
OutputDir={#MyAppOutputDir}
OutputBaseFilename=heimdall-setup-{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoProductName={#MyAppName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#MyAppSourceDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyAppSourceDir}\*.dll";            DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyAppSourceDir}\data\*";           DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}";              Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}";    Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}";        Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
