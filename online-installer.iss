#define MyAppVersion "0.2.3"
#define PayloadURL "https://github.com/pranaylokegaonkar/Xoddy-Billing-Downloads/releases/download/v0.2.3/XoddyBilling-App.zip"
#ifndef PayloadHash
  #error PayloadHash must be supplied from the verified Windows build
#endif

[Setup]
AppId={{560C53E2-7BD4-42BF-81CB-F3AF9A0BCD12}
AppName=Xoddy Billing Software
AppVersion={#MyAppVersion}
AppPublisher=Xoddy
DefaultDirName={localappdata}\Programs\XoddyBilling
DefaultGroupName=Xoddy Billing
PrivilegesRequired=lowest
MinVersion=10.0
ArchitecturesAllowed=x64compatible
OutputDir=online-dist
OutputBaseFilename=XoddyBilling-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=yes
UninstallDisplayIcon={app}\XoddyBilling.exe
ExtraDiskSpaceRequired=900000000
SetupLogging=yes

[Files]
Source: "{tmp}\xoddy-payload\*"; DestDir: "{app}"; Flags: external ignoreversion recursesubdirs createallsubdirs; ExternalSize: 900000000

[Icons]
Name: "{group}\Xoddy Billing Software"; Filename: "{app}\XoddyBilling.exe"
Name: "{autodesktop}\Xoddy Billing Software"; Filename: "{app}\XoddyBilling.exe"

[Run]
Filename: "{app}\XoddyBilling.exe"; Description: "Launch Xoddy Billing Software"; Flags: nowait postinstall skipifsilent

[Code]
var
  DownloadPage: TDownloadWizardPage;

procedure InitializeWizard;
begin
  WizardForm.WelcomeLabel2.Caption :=
    'This small setup downloads the application package over HTTPS and installs its executable and supporting files.' + #13#10#13#10 +
    'An internet connection is required. Python is included. Your billing data stays on this PC.' + #13#10#13#10 +
    'Downloads are verified before installation. This build is unsigned.';
  DownloadPage := CreateDownloadPage(
    'Downloading Xoddy Billing Software',
    'Downloading application files and checking their SHA-256 checksum. Please keep your internet connected.',
    nil);
  DownloadPage.ShowBaseNameInsteadOfUrl := True;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ExitCode: Integer;
  ScriptPath: String;
  Script: String;
begin
  Result := '';
  DownloadPage.Clear;
  DownloadPage.Add('{#PayloadURL}', 'XoddyBilling-App.zip', '{#PayloadHash}');
  DownloadPage.Show;
  try
    try
      DownloadPage.Download;
      ScriptPath := ExpandConstant('{tmp}\extract-xoddy.ps1');
      Script :=
        '$ErrorActionPreference = ''Stop''' + #13#10 +
        'Expand-Archive -LiteralPath (Join-Path $PSScriptRoot ''XoddyBilling-App.zip'') ' +
        '-DestinationPath (Join-Path $PSScriptRoot ''xoddy-payload'') -Force';
      if not SaveStringToFile(ScriptPath, Script, False) then
        RaiseException('Could not prepare application extraction.');
      DownloadPage.SetText('Preparing application files', 'Extracting the verified package. Please wait.');
      if not Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
        '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + ScriptPath + '"',
        '', SW_HIDE, ewWaitUntilTerminated, ExitCode) then
        RaiseException('Could not start application extraction.');
      if ExitCode <> 0 then
        RaiseException('Application extraction failed. No application files were replaced.');
      if not FileExists(ExpandConstant('{tmp}\xoddy-payload\XoddyBilling.exe')) or
        not DirExists(ExpandConstant('{tmp}\xoddy-payload\_internal')) then
        RaiseException('The downloaded package is missing required application files.');
    except
      if DownloadPage.AbortedByUser then
        Result := 'Download cancelled. No new application files were installed.'
      else
        Result := 'Download or integrity verification failed. Check your connection and try again. ' +
          GetExceptionMessage;
    end;
  finally
    DownloadPage.Hide;
  end;
end;
