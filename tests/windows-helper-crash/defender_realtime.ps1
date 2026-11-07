# 按用户电脑的样子运行各版助手：打开 Windows 安全中心的实时保护和云保护（不上传样本），
# 给文件加上「从网上下载」标记，再双击般启动，看新版是否被拦截或闪退。
param([Parameter(Mandatory = $true)][string]$Folder)
$ErrorActionPreference = "Continue"
$Product = "UseGoodAI中转快速接入助手"

try {
  Set-MpPreference -DisableRealtimeMonitoring $false -DisableBehaviorMonitoring $false -DisableIOAVProtection $false `
    -MAPSReporting Advanced -SubmitSamplesConsent NeverSend -ErrorAction Stop
} catch { Write-Host "无法打开实时保护：$($_.Exception.Message)" }
Start-Sleep -Seconds 5
$status = Get-MpComputerStatus
Write-Host ("实时保护 {0}，行为监控 {1}，云保护 {2}，防篡改 {3}，引擎 {4}，病毒库 {5}" -f $status.RealTimeProtectionEnabled,
  $status.BehaviorMonitorEnabled, (Get-MpPreference).MAPSReporting, $status.IsTamperProtected, $status.AMEngineVersion, $status.AntivirusSignatureVersion)

$work = Join-Path $env:USERPROFILE "Downloads\helper-realtime"
New-Item -ItemType Directory -Force -Path $work | Out-Null
$rows = @()
foreach ($file in Get-ChildItem -LiteralPath $Folder -File | Sort-Object Name) {
  $target = Join-Path $work $file.Name
  Copy-Item -LiteralPath $file.FullName -Destination $target -Force
  Set-Content -LiteralPath $target -Stream Zone.Identifier -Value "[ZoneTransfer]`r`nZoneId=3`r`nHostUrl=https://docs.usegoodai.com/download/" -Encoding Ascii
  $scan = & (Join-Path $env:ProgramFiles "Windows Defender\MpCmdRun.exe") -Scan -ScanType 3 -File $target -DisableRemediation 2>&1 | Out-String
  $scanVerdict = if ($LASTEXITCODE -eq 0) { "没有威胁" } elseif ($LASTEXITCODE -eq 2) { "发现威胁" } else { "扫描出错 $LASTEXITCODE" }
  $run = ""
  if ($file.Name -like "helper-*") {
    try {
      $process = Start-Process -FilePath $target -PassThru -ErrorAction Stop
      $deadline = (Get-Date).AddSeconds(40)
      $window = $false
      while ((Get-Date) -lt $deadline) {
        $process.Refresh()
        if ($process.HasExited) { break }
        if ($process.MainWindowHandle -ne [IntPtr]::Zero -and $process.MainWindowTitle -eq $Product) { $window = $true; break }
        Start-Sleep -Milliseconds 250
      }
      if ($window) { Start-Sleep -Seconds 5; $process.Refresh() }
      $run = if ($process.HasExited) { "闪退，退出码 $($process.ExitCode)" } elseif ($window) { "窗口正常" } else { "40 秒没出窗口" }
      Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
      Start-Sleep -Seconds 3
    } catch { $run = "无法启动：$($_.Exception.Message)" }
  } else {
    $output = (& $target version 2>&1 | Out-String).Trim()
    $run = "version 输出：$output，退出码 $LASTEXITCODE"
  }
  Write-Host "=== $($file.Name)：扫描 $scanVerdict；运行 $run"
  $rows += "| $($file.Name) | $scanVerdict | $run |"
}
Write-Host "---- 安全中心检测记录"
Get-MpThreatDetection -ErrorAction SilentlyContinue | Format-List | Out-String | Write-Host
Get-WinEvent -LogName "Microsoft-Windows-Windows Defender/Operational" -MaxEvents 40 -ErrorAction SilentlyContinue |
  Where-Object { $_.Id -in 1006, 1007, 1008, 1015, 1116, 1117, 1118, 1119, 5007 -and $_.TimeCreated -gt (Get-Date).AddMinutes(-20) } |
  ForEach-Object { Write-Host "[$($_.Id) $($_.TimeCreated)] $($_.Message)" }
if ($env:GITHUB_STEP_SUMMARY) {
  (@("### 实时保护下运行（$env:ImageOS）", "", "| 文件 | 扫描 | 运行 |", "|---|---|---|") + $rows + @("")) -join "`n" |
    Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
}
