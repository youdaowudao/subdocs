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
        Get-ChildItem $dir.FullName -File | Where-Object Extension -In @('.log', '.ldb') | Copy-Item -Destination $destination
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
$diagnostic = @'
(() => {
    const root = window.__STATSIG__ || globalThis.__STATSIG__;
    const client = root?.firstInstance || (typeof root?.instance === "function" ? root.instance() : null);
    let context = null, currentKey = null, adapterData = null;
    try {
        context = client?.getContext();
        currentKey = client ? String(client.dataAdapter._getCacheKey(context.user)) : null;
        const d = client?.dataAdapter.getDataSync(context.user);
        adapterData = d ? {source: d.source, stableID: d.stableID, fullUserHash: d.fullUserHash, hasData: Boolean(d.data)} : null;
    } catch {}
    const caches = Object.keys(localStorage).filter(k => k.startsWith('statsig.cached.evaluations.')).map(key => {
        try { return {key, wrapper: JSON.parse(localStorage.getItem(key))}; }
        catch { return {key, invalid: true}; }
    });
    return JSON.stringify({time: Date.now(), status: client?.loadingStatus, currentKey,
        stableID: context?.stableID, user: context?.user, hasUpdates: context?.values?.has_updates,
        adapterData, caches, text: (document.body?.innerText || '').slice(0, 300)});
})()
'@
$null = Start-Codex '--remote-debugging-port=9333 --remote-allow-origins=http://127.0.0.1:9333'
$report.processesReopen = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'ChatGPT|codex|msedge|webview|crashpad' } | Select-Object ProcessId, ParentProcessId, Name, ExecutablePath, CommandLine)
$samples = @()
try {
    for ($i = 0; $i -lt 120; $i++) {
        try { $samples += @(Invoke-Cdp 9333 $diagnostic)[-1] }
        catch { $samples += @{ error = $_.Exception.Message } }
        $report.startupSamples = $samples
        Save-Report
        Start-Sleep -Milliseconds 500
    }
} finally { Start-Sleep -Seconds 6; Stop-Codex }
Save-Database 'after-debug-reopen'
$report.final = Get-I18nSnapshot 'final'
Save-Report
