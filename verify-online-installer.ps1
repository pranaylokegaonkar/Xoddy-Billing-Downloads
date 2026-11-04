# Disposable hosted Windows runner only. Never points at real company data.
$ErrorActionPreference = "Stop"
if ($env:GITHUB_ACTIONS -ne "true" -or $env:RUNNER_ENVIRONMENT -ne "github-hosted") {
    throw "Run this verification only on a disposable hosted Windows runner."
}
$setup = (Resolve-Path "online-dist/XoddyBilling-Setup.exe").Path
$root = Join-Path $env:RUNNER_TEMP ("xoddy-online-" + [guid]::NewGuid())
$installDir = Join-Path $root "installed"
$env:LOCALAPPDATA = Join-Path $root "data"
New-Item -ItemType Directory -Force $env:LOCALAPPDATA | Out-Null
# Simulate an existing installation while keeping billing data separate.
New-Item -ItemType Directory -Force $installDir | Out-Null
Set-Content (Join-Path $installDir "XoddyBilling.exe") "previous application placeholder"
$dataDir = Join-Path $env:LOCALAPPDATA "XoddyBilling"
New-Item -ItemType Directory -Force $dataDir | Out-Null
Set-Content (Join-Path $dataDir "preserve-check.txt") "Existing user files must survive."
$log = Join-Path $root "setup.log"
$install = Start-Process $setup -PassThru -ArgumentList @(
    "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/NOICONS",
    "/DIR=`"$installDir`"", "/LOG=`"$log`""
)
if (!$install.WaitForExit(600000)) { $install.Kill(); throw "Online installation timed out." }
if ($install.ExitCode -ne 0) {
    Get-Content $log
    throw "Online installer failed: $($install.ExitCode)"
}
$exe = Join-Path $installDir "XoddyBilling.exe"
if (!(Test-Path $exe)) { throw "No installed executable." }
if (!(Test-Path (Join-Path $installDir "_internal")) -or (Get-Item $exe).Length -gt 20000000) {
    throw "Expected a small executable with separate supporting files."
}
$expectedDir = Join-Path $root "expected"
Expand-Archive -LiteralPath "payload/XoddyBilling-App.zip" -DestinationPath $expectedDir
$expectedFiles = @(Get-ChildItem $expectedDir -File -Recurse)
foreach ($file in $expectedFiles) {
    $relative = [IO.Path]::GetRelativePath($expectedDir, $file.FullName)
    $installed = Join-Path $installDir $relative
    if (!(Test-Path $installed) -or (Get-FileHash $installed).Hash -ne (Get-FileHash $file.FullName).Hash) {
        throw "Installed file missing or corrupt: $relative"
    }
}
if ((Get-Content (Join-Path $dataDir "preserve-check.txt")) -ne "Existing user files must survive.") {
    throw "User data was changed during installation."
}
Write-Host "Verified $($expectedFiles.Count) installed application files."
$launcher = Start-Process $exe -PassThru
try {
    $deadline = (Get-Date).AddSeconds(120)
    $window = $null
    do {
        Start-Sleep -Seconds 1
        $window = Get-Process -Name XoddyBilling -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
        if ($window) { break }
        $launcher.Refresh()
        if ($launcher.HasExited) { throw "Application exited before showing its window." }
    } while ((Get-Date) -lt $deadline)
    if (!$window -or $window.MainWindowTitle -ne "Xoddy Billing Software") {
        throw "Native main window did not appear."
    }
    if (!(Test-Path "$env:LOCALAPPDATA/XoddyBilling/billing.sqlite3")) { throw "Database missing." }
    $window.CloseMainWindow() | Out-Null
    if (!$launcher.WaitForExit(30000)) { throw "Application did not close normally." }
    if ($launcher.ExitCode -ne 0) { throw "Application closed with an error." }
    Write-Host "PASS: HTTPS download, hash verification, installation, native launch, database creation and clean close."
    $uninstaller = Join-Path $installDir "unins000.exe"
    $uninstall = Start-Process $uninstaller -PassThru -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART"
    if (!$uninstall.WaitForExit(120000) -or $uninstall.ExitCode -ne 0) { throw "Uninstall failed." }
    if ((Test-Path $exe) -or (Test-Path (Join-Path $installDir "_internal"))) { throw "Application files left after uninstall." }
    if (!(Test-Path (Join-Path $dataDir "billing.sqlite3"))) { throw "Uninstall removed billing data." }
    Write-Host "PASS: multi-file uninstall preserves billing data."
} finally {
    Get-Process -Name XoddyBilling -ErrorAction SilentlyContinue | Stop-Process -Force
}
