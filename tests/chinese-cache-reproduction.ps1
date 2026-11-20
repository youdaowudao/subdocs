param([Parameter(Mandatory)][string]$ReportDir)
$ErrorActionPreference = 'Stop'
$script:HarnessTestsRoot = $PSScriptRoot
$harness = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'codex-chinese-desktop.ps1'))
$harness = $harness.Replace('$PSScriptRoot', '$script:HarnessTestsRoot')
$failure = $null
try {
    # Run the full failed scenario without startup observers or database reads.
    . ([scriptblock]::Create($harness)) -Script docs/public/install/chinese.ps1 -Network block -Expect pass -Auth login -Locale override -Stress 5 -ReportDir $ReportDir
} catch { $failure = $_.Exception.Message }
finally {
    # Collect diagnostics only after all eight attempts have ended.
    $packageRoot = Join-Path $env:LOCALAPPDATA 'Packages/OpenAI.Codex_2p2nqsd0c76g0'
    $index = 0
    foreach ($dir in Get-ChildItem $packageRoot -Recurse -Directory -Filter leveldb -ErrorAction SilentlyContinue | Where-Object FullName -Match 'Local Storage') {
        $index++
        $destination = Join-Path $ReportDir "final-db$index"
        New-Item -ItemType Directory -Force $destination | Out-Null
        Get-ChildItem $dir.FullName -File | Where-Object { $_.Name -ne 'LOCK' } | Copy-Item -Destination $destination -ErrorAction Continue
    }
    if ($failure) { $failure | Set-Content (Join-Path $ReportDir 'reproduction-failure.txt') -Encoding UTF8 }
}
if ($failure) { throw $failure }
