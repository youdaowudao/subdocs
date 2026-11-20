param(
    [Parameter(Mandatory)][string]$ReportDir,
    [Parameter(Mandatory)][ValidateSet('online', 'blackhole')][string]$Network,
    [Parameter(Mandatory)][ValidateSet('apikey', 'login')][string]$Auth
)
$ErrorActionPreference = 'Stop'
$script:HarnessTestsRoot = $PSScriptRoot
$harness = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'codex-chinese-desktop.ps1'))
$prefix = $harness.Substring(0, $harness.IndexOf('# ---------- Scenario ----------')).Replace('$PSScriptRoot', '$script:HarnessTestsRoot')
. ([scriptblock]::Create($prefix)) -Script docs/public/install/chinese.ps1 -Network $Network -Expect record -Auth $Auth -Locale override -ReportDir $ReportDir
$report.purpose = 'Eight exact HTTP commands in one native Windows PowerShell 5.1 process; global interop types are reused.'
$report.environment = @{ os = (Get-CimInstance Win32_OperatingSystem).Caption; arch = $env:PROCESSOR_ARCHITECTURE; shell = $PSVersionTable.PSVersion.ToString(); sha = $env:GITHUB_SHA; scriptSha256 = (Get-FileHash $scriptPath).Hash; imageVersion = $env:ImageVersion }
$hostsPath = Join-Path $env:SystemRoot 'System32/drivers/etc/hosts'
$originalHosts = [IO.File]::ReadAllBytes($hostsPath)
$server = $null; $child = $null
try {
    Install-Codex
    Set-NetworkCondition
    $null = New-Item -ItemType Directory -Force $configDir
    $configText = "# session-fixture-preserve`n"
    if ($Auth -eq 'apikey') {
        $configText += "model_provider = `"OpenAI`"`nmodel = `"gpt-6.1-sol`"`n[model_providers.OpenAI]`nname = `"OpenAI`"`nbase_url = `"http://127.0.0.1:9/v1`"`nwire_api = `"responses`"`nrequires_openai_auth = true`n"
        '{"OPENAI_API_KEY":"sk-ci-fake-key-not-real"}' | Set-Content (Join-Path $configDir 'auth.json') -Encoding ASCII
    }
    $configText += "[desktop]`nlocaleOverride = `"zh-CN`"`n"
    $configText | Set-Content $config -Encoding ASCII
    $initialConfigText = [IO.File]::ReadAllText($config)
    $initialConfigText | Set-Content (Join-Path $ReportDir 'config-fixture-before-app.txt') -Encoding UTF8
    Complete-PrivacyScreen
    if ($Auth -eq 'apikey') { Complete-AppOnboarding }
    $report.baseline = Get-I18nSnapshot 'session-baseline'
    # Establish the application's own first-use changes before invoking any repair command.
    $report.normalStartupConfigs = @()
    for ($baselineRound = 1; $baselineRound -le 2; $baselineRound++) {
        $null = Start-Codex
        Start-Sleep -Seconds 50
        Stop-Codex
        $normalConfig = [IO.File]::ReadAllText($config)
        $normalConfig | Set-Content (Join-Path $ReportDir "config-normal-startup-$baselineRound.txt") -Encoding UTF8
        $report.normalStartupConfigs += @{ round = $baselineRound; sha256 = (Get-FileHash $config).Hash; changedFromFixture = $normalConfig -ne $initialConfigText }
        Save-Report
    }
    $configHash = (Get-FileHash $config).Hash
    $null = Start-Codex
    Start-Sleep -Seconds 12
    $portFile = Join-Path $temp 'repeat-session-port'
    $server = Start-Job -ArgumentList $scriptPath, $portFile -ScriptBlock {
        param($Path, $PortPath)
        $content = [IO.File]::ReadAllBytes($Path)
        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
        $listener.Start()
        [IO.File]::WriteAllText($PortPath, [string]$listener.LocalEndpoint.Port)
        try {
            for ($i = 1; $i -le 8; $i++) {
                $client = $listener.AcceptTcpClient()
                try {
                    $stream = $client.GetStream()
                    $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::ASCII, $false, 1024, $true)
                    do { $line = $reader.ReadLine() } while ($line)
                    $head = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: text/plain; charset=utf-8`r`nContent-Length: $($content.Length)`r`nConnection: close`r`n`r`n")
                    $stream.Write($head, 0, $head.Length); $stream.Write($content, 0, $content.Length); $stream.Flush()
                } finally { $client.Dispose() }
            }
        } finally { $listener.Stop() }
    }
    $port = Wait-Until { if (Test-Path $portFile) { Get-Content $portFile } } 20
    if (-not $port) { throw 'Session HTTP server did not start' }
    $entry = Join-Path $temp 'repeat-session-entry.ps1'
    $program = @'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'
for ($i = 1; $i -le 8; $i++) {
    if ($i -eq 2 -or $i -ge 4) {
        [uint32]$testActivationId = 0
        $hr = [CodexCurrentCache.NativeActivation]::Activate('__AUMID__', '', [ref]$testActivationId)
        if ($hr -lt 0) { throw 'Normal test reopen failed' }
        if ($i -eq 2) { Start-Sleep -Seconds 50 } else { Start-Sleep -Seconds 12 }
    }
    $configBeforeRepair = (Get-FileHash '__CONFIG_PATH__').Hash
    $watch = [Diagnostics.Stopwatch]::StartNew()
    irm http://127.0.0.1:__PORT__/chinese.ps1 | iex
    $state = @{ attempt = $i; shellPid = $PID; seconds = [Math]::Round($watch.Elapsed.TotalSeconds, 2); configBefore = $configBeforeRepair; configAfter = (Get-FileHash '__CONFIG_PATH__').Hash; remaining = @(Get-Process -Name ChatGPT, Codex -ErrorAction SilentlyContinue).Count; port = @(Get-NetTCPConnection -State Listen -LocalPort 9240 -ErrorAction SilentlyContinue).Count }
    Write-Host ('__CI_STATE__' + ($state | ConvertTo-Json -Compress))
}
'@
    $program = $program.Replace('__PORT__', [string]$port).Replace('__AUMID__', $script:codex.Aumid).Replace('__CONFIG_PATH__', $config.Replace("'", "''"))
    [IO.File]::WriteAllText($entry, $program, [Text.UTF8Encoding]::new($false))
    $stdout = Join-Path $ReportDir 'same-session-stdout.txt'
    $stderr = Join-Path $ReportDir 'same-session-stderr.txt'
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $child = Start-Process $ps -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $entry) -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -WindowStyle Hidden
    $null = $child.Handle
    while (-not $child.HasExited -and $watch.Elapsed.TotalSeconds -lt 1000) { Start-Sleep -Seconds 1 }
    if (-not $child.HasExited) { $child.Kill(); throw 'Persistent PowerShell exceeded its test cap' }
    $child.WaitForExit()
    $output = Get-Content -Raw -Encoding UTF8 $stdout
    $report.session = @{ seconds = $watch.Elapsed.TotalSeconds; exit = $child.ExitCode; successes = ([regex]::Matches($output, '\[成功\]')).Count; failures = ([regex]::Matches($output, '\[失败\]')).Count; priorCacheReads = ([regex]::Matches($output, '缓存来源：已有缓存')).Count; attempts = @($output -split "`r?`n" | Where-Object { $_.StartsWith('__CI_STATE__') } | ForEach-Object { $_.Substring(12) | ConvertFrom-Json }) }
    Save-Report
    if ($report.session.exit -or $report.session.successes -ne 8 -or $report.session.failures) { Add-Failure 'The same PowerShell session did not succeed eight times' }
    if ($report.session.priorCacheReads -lt 7) { Add-Failure 'The same session lost a previously written cache' }
    if (@($report.session.attempts).Count -ne 8 -or @($report.session.attempts | Select-Object -ExpandProperty shellPid -Unique).Count -ne 1) { Add-Failure 'The test did not execute eight times in one PowerShell process' }
    foreach ($attempt in $report.session.attempts) {
        if ($attempt.remaining -or $attempt.port) { Add-Failure 'An attempt left application processes or its debug listener' }
        if ($attempt.seconds -gt 180) { Add-Failure 'An attempt exceeded three minutes' }
    }
    [IO.File]::ReadAllText($config) | Set-Content (Join-Path $ReportDir 'config-after-repair.txt') -Encoding UTF8
    $report.final = Get-I18nSnapshot 'session-final'
    if ($report.final.liveEnableI18n -ne $true -or $report.final.cjkCount -lt 5) { Add-Failure 'The final session window was not Chinese' }
    $report.configBeforeRepairSha256 = $configHash
    $report.configAfterRepairSha256 = (Get-FileHash $config).Hash
    # Plain App startup already changes its own CUA pipe and adds managed runtime fields.
    # Assert every pre-existing user value, including nested provider and locale settings.
    $preservation = & python (Join-Path $script:HarnessTestsRoot 'chinese-config-preservation.py') (Join-Path $ReportDir 'config-fixture-before-app.txt') $config
    if ($LASTEXITCODE) { throw 'Cannot parse the real configuration for preservation checks' }
    $report.originalSettings = $preservation | ConvertFrom-Json
    if (-not $report.originalSettings.preserved) { Add-Failure ('Original user configuration changed: ' + ($report.originalSettings.changed -join ', ')) }
    Save-Report
    if ($report.failures.Count) { throw ($report.failures -join ' | ') }
} finally {
    if ($child -and -not $child.HasExited) { $child.Kill() }
    if ($server) { Stop-Job $server -ErrorAction Continue; Remove-Job $server -Force -ErrorAction Continue }
    Stop-Codex
    [IO.File]::WriteAllBytes($hostsPath, $originalHosts)
    ipconfig /flushdns | Out-Null
    Save-Report
}
