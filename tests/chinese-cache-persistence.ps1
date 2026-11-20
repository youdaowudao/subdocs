param([Parameter(Mandatory)][string]$ReportDir, [ValidateSet('candidate', 'old')][string]$Variant = 'candidate')
$ErrorActionPreference = 'Stop'
$script:HarnessTestsRoot = $PSScriptRoot
$harness = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'codex-chinese-desktop.ps1'))
$prefix = $harness.Substring(0, $harness.IndexOf('# ---------- Scenario ----------')).Replace('$PSScriptRoot', '$script:HarnessTestsRoot')
. ([scriptblock]::Create($prefix)) -Script docs/public/install/chinese.ps1 -Network block -Expect record -Auth login -Locale override -ReportDir $ReportDir
if ($Variant -eq 'old') {
    $scriptPath = Join-Path $temp 'old-1.1.0.ps1'
    $readOld = @'
import subprocess,pathlib,sys
pathlib.Path(sys.argv[1]).write_bytes(subprocess.check_output(['git','show','5e228f0:docs/public/install/chinese.ps1']))
'@
    $readOld | & python - $scriptPath
    if ($LASTEXITCODE) { throw 'Could not read the exact released control script.' }
}
$report.environment = @{ os = (Get-CimInstance Win32_OperatingSystem).Caption; arch = $env:PROCESSOR_ARCHITECTURE; shell = $PSVersionTable.PSVersion.ToString(); sha = $env:GITHUB_SHA; variant = $Variant; scriptSha256 = (Get-FileHash $scriptPath).Hash }
Save-Report
Install-Codex
Set-NetworkCondition
New-Item -ItemType Directory -Force $configDir | Out-Null
"# ci-cache-preservation`n[desktop]`nlocaleOverride = `"zh-CN`"`n" | Set-Content $config -Encoding ASCII
$null = Get-I18nSnapshot 'baseline'
$null = Start-Codex
Start-Sleep -Seconds 50
$report.screen_before = Save-Screen 'before'
$report.processesBefore = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'ChatGPT|codex|msedge|webview|crashpad' } | Select-Object ProcessId, ParentProcessId, Name, ExecutablePath, CommandLine)
Save-Report
$null = Invoke-OneLine 'first'
function Save-Database([string]$Label) {
    $packageRoot = Join-Path $env:LOCALAPPDATA 'Packages/OpenAI.Codex_2p2nqsd0c76g0'
    $index = 0
    foreach ($dir in Get-ChildItem $packageRoot -Recurse -Directory -Filter leveldb -ErrorAction SilentlyContinue | Where-Object FullName -Match 'Local Storage') {
        $index++
        $destination = Join-Path $ReportDir "$Label-db$index"
        New-Item -ItemType Directory -Force $destination | Out-Null
        Get-ChildItem $dir.FullName -File | Where-Object { $_.Name -ne 'LOCK' } | Copy-Item -Destination $destination
    }
}
Save-Database 'after-command'
# Match the failed desktop scenario exactly: normal reopen for 50 seconds,
# then close and inspect. A direct debug reopen alone has preserved the cache.
$null = Start-Codex
Start-Sleep -Seconds 50
$report.normalReopenScreen = Save-Screen 'normal-reopen'
$report.processesNormalReopen = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'ChatGPT|codex' } | Select-Object ProcessId, ParentProcessId, Name, CommandLine)
Stop-Codex
Save-Database 'after-normal-reopen'
Save-Report
# Inspect the ordinary reopen first, without getDataSync or startup injection.
$report.originalFinal = Get-I18nSnapshot 'original-final'
$report.originalAllKeys = $null
$null = Start-Codex '--remote-debugging-port=9333 --remote-allow-origins=http://127.0.0.1:9333'
try {
    $report.originalAllKeys = @(Invoke-Cdp 9333 'JSON.stringify({keys:Object.keys(localStorage), origin:location.origin, href:location.href})')[-1]
    $report.originalTargets = @(Invoke-RestMethod 'http://127.0.0.1:9333/json/list' -TimeoutSec 3)
} finally { Stop-Codex }
Save-Database 'after-original-inspection'
Save-Report

# Diagnostic control only. Keep the page algorithm identical; replace the final
# renderer kill with the debugger's page-close endpoint in a temp file.
# This modified file is not a candidate or a release acceptance result.
$raw = [IO.File]::ReadAllText($scriptPath)
$parseTokens = $null; $parseErrors = $null
$tree = [Management.Automation.Language.Parser]::ParseInput($raw, [ref]$parseTokens, [ref]$parseErrors)
$function = $tree.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Save-CodexStorage' }, $true)
if (-not $function) { throw 'Cannot locate the shutdown control point.' }
$control = @'
function Save-CodexStorage {
    $targets = [object[]](Invoke-RestMethod 'http://127.0.0.1:9240/json/list' -TimeoutSec 3)
    $pages = @($targets | Where-Object { $_.type -eq 'page' -and $_.url -eq 'app://-/index.html' })
    if (-not $pages.Count) { throw 'No application page to close' }
    foreach ($page in $pages) {
        $null = Invoke-WebRequest -UseBasicParsing -Uri ("http://127.0.0.1:9240/json/close/" + $page.id) -TimeoutSec 3
    }
    $watch = [Diagnostics.Stopwatch]::StartNew()
    do {
        Start-Sleep -Milliseconds 250
        try {
            $left = [object[]](Invoke-RestMethod 'http://127.0.0.1:9240/json/list' -TimeoutSec 2)
            $leftPages = @($left | Where-Object { $_.type -eq 'page' -and $_.url -eq 'app://-/index.html' })
        } catch {
            if (-not @(Get-CodexMainProcesses).Count) { $leftPages = @() }
            else { throw }
        }
    } while ($leftPages.Count -and $watch.Elapsed.TotalSeconds -lt 5)
    if ($leftPages.Count) { throw 'Application page refused normal close' }
    Start-Sleep -Seconds 2
}

'@
$raw = $raw.Remove($function.Extent.StartOffset, $function.Extent.EndOffset - $function.Extent.StartOffset).Insert($function.Extent.StartOffset, $control)
$scriptPath = Join-Path $temp 'page-close-control.ps1'
[IO.File]::WriteAllText($scriptPath, $raw, [Text.UTF8Encoding]::new($false))
$report.controlSha256 = (Get-FileHash $scriptPath).Hash
$report.controlPurpose = 'Diagnostic temporary script; page-close endpoint replaces renderer kill. Not a candidate acceptance.'
$null = Invoke-OneLine 'graceful-control'
Save-Database 'after-graceful-command'
$null = Start-Codex
Start-Sleep -Seconds 50
$report.gracefulNormalScreen = Save-Screen 'graceful-normal-reopen'
Stop-Codex
Save-Database 'after-graceful-normal-reopen'
$report.gracefulFinal = Get-I18nSnapshot 'graceful-final'
Save-Report
