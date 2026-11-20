$ErrorActionPreference = 'Stop'
$windowsVersion = ([IO.File]::ReadAllText('C:\OEM\windows-version.txt')).Trim()
$share = 'Z:\'
for ($attempt = 0; $attempt -lt 90 -and -not (Test-Path $share); $attempt++) {
    if ($attempt -eq 15) { & net.exe use Z: '\\host.lan\Data' /persistent:no | Out-Null }
    Start-Sleep -Seconds 2
}
if (-not (Test-Path $share)) { throw 'Win10 shared report drive is unavailable.' }
$out = Join-Path $share 'report'
$null = New-Item -ItemType Directory -Force $out
$phase = 'environment'
try {
    $os = Get-CimInstance Win32_OperatingSystem
    $environment = @{ caption = $os.Caption; build = $os.BuildNumber; productType = $os.ProductType; architecture = $env:PROCESSOR_ARCHITECTURE; user = $env:USERNAME; session = (Get-Process -Id $PID).SessionId; admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
    $environment | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'environment.json') -Encoding UTF8
    if ($os.ProductType -ne 1 -or $os.Caption -notmatch ('Windows '+$windowsVersion+'\b') -or $environment.session -eq 0) { throw 'A real interactive Windows 10 desktop is required.' }
    $env:RUNNER_TEMP = 'C:\ci-temp'
    $null = New-Item -ItemType Directory -Force $env:RUNNER_TEMP
    $webview = Join-Path $env:TEMP 'MicrosoftEdgeWebview2Setup.exe'
    & curl.exe -fsSL --connect-timeout 20 --max-time 180 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' -o $webview
    if ($LASTEXITCODE -ne 0) { throw 'Official WebView2 bootstrapper download failed.' }
    $setup = Start-Process -FilePath $webview -ArgumentList '/silent /install' -Wait -PassThru
    if ($setup.ExitCode -ne 0) { throw "WebView2 setup failed: $($setup.ExitCode)" }
    $phase = 'ui'
    $testOptions = @{ Exe = 'C:\OEM\candidate.exe'; ReportDir = $out; WindowsVersion = $windowsVersion }
    if (Test-Path 'C:\OEM\layout-only.txt') { $testOptions.LayoutOnly = $true }
    & 'C:\OEM\repo\usegoodai-codex-installer\quick-connect\tools\windows_chinese_ui.ps1' @testOptions
    @{ passed = $true; phase = 'complete' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'completion.json') -Encoding UTF8
} catch {
    @{ passed = $false; phase = $phase; error = $_.Exception.Message } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'completion.json') -Encoding UTF8
}
