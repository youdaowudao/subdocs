param([Parameter(Mandatory)][string]$ReportDir)
$ErrorActionPreference = 'Stop'
# Reuse the official app installer, activation, one-line runner and evidence collection.
$harness = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'codex-chinese-desktop.ps1'))
$script:HarnessTestsRoot = $PSScriptRoot
$prefix = $harness.Substring(0, $harness.IndexOf('# ---------- Scenario ----------')).Replace('$PSScriptRoot', '$script:HarnessTestsRoot')
. ([scriptblock]::Create($prefix)) -Script docs/public/install/chinese.ps1 -Network online -Expect record -Auth apikey -Locale override -ReportDir $ReportDir
$report.environment = @{ os = (Get-CimInstance Win32_OperatingSystem).Caption; arch = $env:PROCESSOR_ARCHITECTURE; shell = $PSVersionTable.PSVersion.ToString(); sha = $env:GITHUB_SHA; scriptSha256 = (Get-FileHash $scriptPath).Hash }
Save-Report
Install-Codex
New-Item -ItemType Directory -Force $configDir | Out-Null
"# ci-failure-cleanup`n[desktop]`nlocaleOverride = `"zh-CN`"`n" | Set-Content $config -Encoding ASCII
$null = Start-Codex
Start-Sleep -Seconds 8
$report.screen_before = Save-Screen 'before-failure'
Stop-Codex
$readyFile = Join-Path $temp 'occupied-port-ready'
# Occupy the fixed debug port and keep HTTP connections unanswered. The published
# command must time out, close its real temporary ChatGPT instance, and leave this
# unrelated listener alone. Stop the fixture ourselves after verifying ownership.
$fixture = Start-Job -ArgumentList $readyFile -ScriptBlock {
    param($Ready)
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 9240)
    $listener.Start()
    try {
        [IO.File]::WriteAllText($Ready, [string]$PID)
        $client = $listener.AcceptTcpClient()
        try { Start-Sleep -Seconds 300 } finally { $client.Dispose() }
    } finally { $listener.Stop() }
}
try {
    if (-not (Wait-Until { Test-Path $readyFile } 15)) { throw 'Occupied-port fixture did not start.' }
    $row = Invoke-OneLine 'timeout-cleanup'
    if ($row.success) { Add-Failure 'The command reported success without a working debug page.' }
    if ($row.seconds -gt 150) { Add-Failure 'The failed operation exceeded 150 seconds.' }
    if ($row.codexRunningAfter -or @(Get-CodexProcesses).Count) { Add-Failure 'Failure left a ChatGPT process.' }
    if ($row.maxOutputGap -gt 12) { Add-Failure 'The failure wait had a long silent interval.' }
    $out = Get-Content -Raw -Encoding UTF8 (Join-Path $ReportDir 'timeout-cleanup-stdout.txt')
    if ($out -notmatch '\[失败\]' -or $out -notmatch '已等待.*秒') { Add-Failure 'Failure/progress messages are missing.' }
    $fixturePid = [int](Get-Content $readyFile)
    $listenerOwners = @(Get-NetTCPConnection -LocalPort 9240 -State Listen -ErrorAction SilentlyContinue | ForEach-Object OwningProcess)
    if ($listenerOwners.Count -ne 1 -or $listenerOwners[0] -ne $fixturePid) { Add-Failure 'The unrelated listener was changed.' }
    $late = @()
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while ($watch.Elapsed.TotalSeconds -lt 10) {
        $late += @(Get-CodexProcesses | ForEach-Object ProcessId)
        Start-Sleep -Milliseconds 300
    }
    $report.lateProcesses = @($late | Select-Object -Unique)
    if ($late.Count) { Add-Failure 'ChatGPT reopened after the failed operation.' }
    Save-Report
} finally {
    Stop-Job $fixture -ErrorAction SilentlyContinue
    Remove-Job $fixture -Force -ErrorAction SilentlyContinue
    Stop-Codex
}
if (@(Get-NetTCPConnection -LocalPort 9240 -State Listen -ErrorAction SilentlyContinue).Count) { Add-Failure 'Fixture port remained open after cleanup.' }
Save-Report
if ($report.failures.Count) { throw ($report.failures -join ' | ') }
