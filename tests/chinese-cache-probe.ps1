param([Parameter(Mandatory)][string]$ReportDir, [Parameter(Mandatory)][ValidateSet('block', 'longhang')][string]$Network)
$ErrorActionPreference = 'Stop'
$script:HarnessTestsRoot = $PSScriptRoot
$harness = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'codex-chinese-desktop.ps1'))
$prefix = $harness.Substring(0, $harness.IndexOf('# ---------- Scenario ----------')).Replace('$PSScriptRoot', '$script:HarnessTestsRoot')
. ([scriptblock]::Create($prefix)) -Script docs/public/install/chinese.ps1 -Network $Network -Expect record -Auth login -Locale override -ReportDir $ReportDir
# Reuse the existing read-only database copier without executing its experiment.
$tokens = $null; $parseErrors = $null
$tree = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'chinese-cache-persistence.ps1'), [ref]$tokens, [ref]$parseErrors)
$copy = $tree.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Save-Database'}, $true)
. ([scriptblock]::Create($copy.Extent.Text))
$report.environment = @{ sha = $env:GITHUB_SHA; scriptSha256 = (Get-FileHash $scriptPath).Hash; imageVersion = $env:ImageVersion; os = (Get-CimInstance Win32_OperatingSystem).Caption }
$hostsPath = Join-Path $env:SystemRoot 'System32/drivers/etc/hosts'
$originalHosts = [IO.File]::ReadAllBytes($hostsPath)
try {
    Install-Codex
    Set-NetworkCondition
    $null = New-Item -ItemType Directory -Force $configDir
    "# ci-unchanged`n[desktop]`nlocaleOverride = `"zh-CN`"`n" | Set-Content $config -Encoding ASCII
    Complete-PrivacyScreen
    $report.baseline = Get-I18nSnapshot 'probe-baseline'
    if (@($report.baseline.caches | Where-Object source -EQ 'Network').Count) { throw 'Offline baseline leaked to the network' }
    $null = Start-Codex
    Start-Sleep -Seconds 50
    $report.before = Save-Screen 'before-repair'
    $row = Invoke-OneLine 'first-repair'
    # Match the full matrix's first ordinary reopen. No extra disk copy or SDK call before it.
    $null = Start-Codex
    Start-Sleep -Seconds 50
    $report.ordinaryReopen = Save-Screen 'ordinary-reopen'
    Stop-Codex
    $report.after = Get-I18nSnapshot 'after-first-normal-reopen'
    Save-Database 'original-outcome'
    $report.cacheLost = -not @($report.after.caches).Count -or $report.after.liveEnableI18n -ne $true -or $report.after.cjkCount -lt 5
    Save-Report

    # Introspection only after the original outcome and raw WAL have been preserved.
    # getDataSync can populate SDK memory; none of the preceding acceptance uses it.
    $diagnostic = @'
(async () => {
    const until = Date.now() + 60000;
    const find = () => {const r=window.__STATSIG__ || globalThis.__STATSIG__; return r?.firstInstance || r?.instance?.();};
    let client = find();
    while ((!client || String(client.loadingStatus)!=="Ready") && Date.now()<until) {await new Promise(r=>setTimeout(r,250));client=find();}
    const context = client?.getContext();
    const adapter = client?.dataAdapter;
    const key = adapter ? String(adapter._getCacheKey(context.user)) : null;
    const rawBefore = key ? localStorage.getItem(key) : null;
    const keysBefore = Object.keys(localStorage);
    let data = null, dataError = null;
    try {data=adapter?.getDataSync(context.user);} catch(error) {dataError=String(error);}
    return JSON.stringify({origin:location.origin,href:location.href,isSecureContext,topFrame:window.top===window,
      status:client?.loadingStatus,stableID:context?.stableID,user:context?.user,key,keysBefore,rawBefore,
      keysAfter:Object.keys(localStorage),storageConstructor:localStorage.constructor.name,
      nativeGetItem:String(Object.getPrototypeOf(localStorage).getItem),
      adapterConstructor:adapter?.constructor.name,adapterKeys:adapter ? Object.keys(adapter):[],
      options:{disableStorage:adapter?._options?.disableStorage,disableStableID:adapter?._options?.disableStableID,cacheLimit:adapter?._cacheLimit},
      inMemoryKeys:Object.keys(adapter?._inMemoryCache?._data||{}),data,dataError,
      contextHasUpdates:context?.values?.has_updates,contextFormat:context?.values?.response_format,
      text:(document.body?.innerText||'').slice(0,500)});
})()
'@
    $null = Start-Codex '--remote-debugging-port=9333 --remote-allow-origins=http://127.0.0.1:9333'
    try {
        $report.diagnosticAfterOutcome = @(Invoke-Cdp 9333 $diagnostic)[-1]
        $report.targetsAfterOutcome = [object[]](Invoke-RestMethod 'http://127.0.0.1:9333/json/list' -TimeoutSec 3)
        $report.processesAfterOutcome = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'ChatGPT|Codex|chrome' } | Select-Object ProcessId, ParentProcessId, Name, ExecutablePath, CommandLine)
    } finally { Stop-Codex }
    Save-Database 'after-introspection'
    if (-not $row.success) { Add-Failure 'The original published command did not succeed' }
    if ($report.cacheLost) { Add-Failure 'The original published command lost its cache on the first ordinary reopen' }
    Save-Report
    if ($report.failures.Count) { throw ($report.failures -join ' | ') }
} finally {
    Stop-Codex
    [IO.File]::WriteAllBytes($hostsPath, $originalHosts)
    if (Get-Variable networkFixture -Scope Script -ErrorAction SilentlyContinue) { Stop-Process $script:networkFixture.Id -Force -ErrorAction Continue }
    ipconfig /flushdns | Out-Null
    Save-Report
}
