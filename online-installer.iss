#define MyAppVersion "0.2.2"
#define PayloadURL "https://github.com/pranaylokegaonkar/Xoddy-Billing-Downloads/releases/download/v0.2.2/XoddyBilling.exe"
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
Source: "{tmp}\XoddyBilling.exe"; DestDir: "{app}"; Flags: external ignoreversion; ExternalSize: 257560029

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
    'This small setup downloads approximately 258 MB of application files over HTTPS.' + #13#10#13#10 +
    'An internet connection is required. Python is included. Your billing data stays on this PC.' + #13#10#13#10 +
    'Downloads are verified before installation. This build is unsigned.';
  DownloadPage := CreateDownloadPage(
    'Downloading Xoddy Billing Software',
    'Downloading approximately 258 MB and checking its SHA-256 checksum. Please keep your internet connected.',
    nil);
  DownloadPage.ShowBaseNameInsteadOfUrl := True;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  DownloadPage.Clear;
  DownloadPage.Add('{#PayloadURL}', 'XoddyBilling.exe', '{#PayloadHash}');
  DownloadPage.Show;
  try
    try
      DownloadPage.Download;
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
