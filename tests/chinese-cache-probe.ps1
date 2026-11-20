param([Parameter(Mandatory)][string]$ReportDir, [Parameter(Mandatory)][ValidateSet('block', 'longhang')][string]$Network,
    [ValidateSet('none', 'torn-tail')][string]$WalFault = 'none')
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
    if ($WalFault -eq 'torn-tail') {
        # Deliberate fault in this fresh fake-account VM only. Never used by the
        # product: reproduce LevelDB recovery after a writer died mid-record.
        Save-Database 'before-injection'
        $packageRoot = Join-Path $env:LOCALAPPDATA 'Packages/OpenAI.Codex_2p2nqsd0c76g0'
        $files = @(Get-ChildItem $packageRoot -Recurse -File -Filter '*.log' | Where-Object FullName -Match 'Local Storage[/\\]leveldb[/\\][0-9]+\.log$')
        if (-not $files.Count -or @(Get-CodexProcesses).Count) { throw 'Fault fixture needs a stopped disposable application profile' }
        foreach ($file in $files) {
            # A physical header declares a 100-byte payload; only one byte is
            # present. First recovery ignores incomplete EOF, next appends expose
            # a checksum error. Keep both original and injected bytes as evidence.
            $stream = [IO.File]::Open($file.FullName, [IO.FileMode]::Append, [IO.FileAccess]::Write, [IO.FileShare]::None)
            try { $stream.Write([byte[]](1, 2, 3, 4, 100, 0, 1, 0), 0, 8) } finally { $stream.Dispose() }
        }
        $report.injectedWalFault = @{ kind = $WalFault; files = $files.FullName; disposableVmOnly = $true }
        Save-Database 'after-injection'
    }
    $null = Start-Codex
    Start-Sleep -Seconds 50
    $report.remoteBefore = @(Get-RemoteConnections)
    $report.before = Save-Screen 'before-repair'
    Save-Report
    $row = Invoke-OneLine 'first-repair'
    # Match the full matrix's first ordinary reopen. No extra disk copy or SDK call before it.
    $null = Start-Codex
    Start-Sleep -Seconds 50
    $report.ordinaryReopen = Save-Screen 'ordinary-reopen'
    Stop-Codex
    Get-StorageEvidence 'after-reopen1'
    $report.after = Get-I18nSnapshot 'after-first-normal-reopen'
    Save-Database 'original-outcome'
    $report.resultCollected = $null -eq $report.after.PSObject.Properties['error']
    $report.ordinaryChinese = @($report.ordinaryReopen.chineseLabels | Where-Object { $_ -match '^登录\s*ChatGPT$|^继续登录$' }).Count -gt 0
    $report.cacheLost = if ($report.resultCollected) { -not @($report.after.caches).Count -or $report.after.liveEnableI18n -ne $true } else { $null }
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
    if (-not $row.success -and $WalFault -eq 'none') { Add-Failure 'The original published command did not succeed' }
    if ($WalFault -ne 'none') {
        $report.detectedCorruption = -not $row.success -and (($row.messages -join ' ') -match '本地缓存数据库报告损坏') -and -not $row.leftDebugProcesses -and -not $row.leftListeners -and -not $row.codexRunningAfter
        if (-not $report.detectedCorruption) { Add-Failure 'Torn database must not report success or leave the debug application running' }
    }
    if (-not $report.resultCollected) { Add-Failure 'The original page state could not be collected; cache loss is unconfirmed' }
    elseif ($report.cacheLost -and $WalFault -eq 'none') { Add-Failure 'The original published command lost its cache on the first ordinary reopen' }
    elseif (-not $report.cacheLost -and $WalFault -ne 'none') { Add-Failure 'The injected torn-log hypothesis did not reproduce cache loss' }
    if (-not $report.ordinaryReopen.labels) { Add-Failure 'The normal window controls could not be collected' }
    elseif (-not $report.ordinaryChinese -and $WalFault -eq 'none') { Add-Failure 'The first ordinary reopen did not show the Chinese sign-in controls' }
    Save-Report
    if ($report.failures.Count) { throw ($report.failures -join ' | ') }
} finally {
    Stop-Codex
    [IO.File]::WriteAllBytes($hostsPath, $originalHosts)
    if (Get-Variable networkFixture -Scope Script -ErrorAction SilentlyContinue) { Stop-Process $script:networkFixture.Id -Force -ErrorAction Continue }
    ipconfig /flushdns | Out-Null
    Save-Report
}
