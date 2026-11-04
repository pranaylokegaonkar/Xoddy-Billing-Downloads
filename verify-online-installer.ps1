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
$hash = (Get-FileHash $exe -Algorithm SHA256).Hash.ToLower()
if (!$env:PAYLOAD_HASH -or $hash -ne $env:PAYLOAD_HASH) {
    throw "Installed executable hash mismatch."
}
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
} finally {
    Get-Process -Name XoddyBilling -ErrorAction SilentlyContinue | Stop-Process -Force
}
