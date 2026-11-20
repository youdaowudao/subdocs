param([Parameter(Mandatory)][string]$ReportDir)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $ReportDir | Out-Null
$repo = Split-Path $PSScriptRoot
$core = Join-Path $repo 'usegoodai-codex-installer/codex-zh/windows/Enable-CodexI18nCurrentCache.ps1'
$parseTokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText($core), [ref]$parseTokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
foreach ($statement in $ast.EndBlock.Statements) {
    if ($statement -is [Management.Automation.Language.FunctionDefinitionAst]) {
        . ([scriptblock]::Create($statement.Extent.Text))
    }
}
$results = @()
foreach ($mode in @('receive-hang', 'handshake-hang', 'send-hang', 'events', 'race', 'always-race', 'other-error', 'fragmented', 'reload-race')) {
    $ready = Join-Path $ReportDir "$mode-port"
    $serverMode = if ($mode -eq 'reload-race') { 'race' } else { $mode }
    $server = Start-Process -FilePath (Get-Command python).Source -ArgumentList @("`"$PSScriptRoot/codex-chinese-network.py`"", '--mode', $serverMode, '--ready', "`"$ready`"") -PassThru -WindowStyle Hidden
    try {
        $until = [DateTime]::UtcNow.AddSeconds(15)
        while (-not (Test-Path $ready) -and [DateTime]::UtcNow -lt $until) { Start-Sleep -Milliseconds 100 }
        if (-not (Test-Path $ready)) { throw "Fixture did not start: $mode" }
        $port = [int](Get-Content $ready)
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $didFail = $false; $value = $null; $errorText = ''
        $expression = 'JSON.stringify({ok:true})'
        if ($mode -eq 'reload-race') { $expression = 'location.reload(); "reload-requested"' }
        if ($mode -eq 'send-hang') { $expression = 'x' * (16MB) }
        $messages = @(& {
            try { $script:fixtureValue = Invoke-CdpExpression "ws://127.0.0.1:$port/devtools/page/current" $expression 12 }
            catch { $script:fixtureFailure = $_.Exception.Message }
        } 6>&1)
        $value = $script:fixtureValue
        $errorText = $script:fixtureFailure
        $didFail = -not [string]::IsNullOrEmpty($errorText)
        $script:fixtureValue = $null; $script:fixtureFailure = $null
        $seconds = $watch.Elapsed.TotalSeconds
        $text = ($messages | Out-String)
        $text | Set-Content (Join-Path $ReportDir "$mode.txt") -Encoding UTF8
        $attemptsFile = [IO.Path]::ChangeExtension($ready, '.attempts')
        $attempts = if (Test-Path $attemptsFile) { [int](Get-Content $attemptsFile) } else { 0 }
        $expectSuccess = $mode -in @('race', 'fragmented')
        if ($expectSuccess -and ($didFail -or -not ($value | ConvertFrom-Json).ok)) { throw "$mode should succeed: $errorText" }
        if (-not $expectSuccess -and -not $didFail) { throw "$mode should fail" }
        if ($seconds -gt 16) { throw "$mode exceeded deadline: $seconds" }
        if ($mode -in @('receive-hang', 'events') -and ($text -notmatch '已等待 5 秒' -or $text -notmatch '已等待 10 秒')) { throw "$mode missing progress" }
        if ($mode -eq 'race' -and $attempts -ne 2) { throw "Race was not retried exactly once: $attempts" }
        if ($mode -in @('other-error', 'reload-race') -and $attempts -ne 1) { throw "Unrelated error was retried: $attempts" }
        $results += @{ mode = $mode; seconds = [Math]::Round($seconds, 2); attempts = $attempts; error = $errorText; passed = $true }
    } finally { Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue }
}
$results | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $ReportDir 'cdp-results.json') -Encoding UTF8
