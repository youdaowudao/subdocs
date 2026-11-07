# 用最新病毒库扫描各版接入助手和生图程序，看新版是否被 Windows 安全中心当成威胁。
# 文件从 Git 历史取出：11-05 构建（不闪退）、11-07 16:05 构建、1.1.4，以及生图 V0.9.0、V0.9.1。
param([Parameter(Mandatory = $true)][string]$Folder)
$ErrorActionPreference = "Continue"
try { Update-MpSignature -ErrorAction Stop } catch { Write-Host "更新病毒库失败：$($_.Exception.Message)" }
$status = Get-MpComputerStatus
Write-Host ("引擎 {0}，病毒库 {1}（{2}）" -f $status.AMEngineVersion, $status.AntivirusSignatureVersion, $status.AntivirusSignatureLastUpdated)
$scanner = Join-Path $env:ProgramFiles "Windows Defender\MpCmdRun.exe"
$rows = @()
foreach ($file in Get-ChildItem -LiteralPath $Folder -File | Sort-Object Name) {
  $output = (& $scanner -Scan -ScanType 3 -File $file.FullName -DisableRemediation 2>&1 | Out-String).Trim()
  $code = $LASTEXITCODE
  $verdict = if ($code -eq 0) { "没有威胁" } elseif ($code -eq 2) { "发现威胁" } else { "扫描出错 $code" }
  Write-Host "=== $($file.Name)：$verdict"
  Write-Host $output
  $rows += "| $($file.Name) | $verdict |"
}
Get-MpThreatDetection -ErrorAction SilentlyContinue | Format-List | Out-String | Write-Host
Get-MpThreat -ErrorAction SilentlyContinue | Format-List ThreatName, Resources | Out-String | Write-Host
if ($env:GITHUB_STEP_SUMMARY) {
  (@("### 病毒库扫描（$env:ImageOS）", "", "| 文件 | 结果 |", "|---|---|") + $rows + @("")) -join "`n" |
    Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
}
