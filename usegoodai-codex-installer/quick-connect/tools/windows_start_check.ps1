# 助手“一打开就闪退”的复现与验证：在 GitHub 的 Windows 11 与 Windows Server 上，
# 按客户电脑的样子打开线上正在发布的助手和候选版，逐项对比：
#   1. 家用默认的 Defender（实时保护、云保护、自动提交样本、拦截不需要的应用）+ 浏览器下载标记，双击打开；
#   2. WebView2 数据目录损坏：旧版卡在后台没有窗口，之后每次双击都无声退出；
#   3. 已开的助手不响应：之后双击的助手卡住，没有窗口；
#   4. WebView2 怎么都起不来：要有提示框，不能无声退出，点「确定」改用命令窗口。
# 线上版的结果只做复现记录；候选版必须全部通过。不使用任何真实 Key 或 Secrets。
param(
  [Parameter(Mandatory = $true)][string]$Candidate,
  [Parameter(Mandatory = $true)][string]$Report
)
$ErrorActionPreference = "Stop"
$Product = "UseGoodAI中转快速接入助手"
$LiveUrl = "https://docs.usegoodai.com/download/usegoodai-quick-connect-windows-x64.exe"
$Folder = Join-Path $env:USERPROFILE "Downloads\中转站快速导入工具"
$LiveExe = Join-Path $Folder "$Product.exe"
$NewExe = Join-Path $Folder "1.$Product.exe"
$Data = Join-Path $env:LOCALAPPDATA "UseGoodAI\QuickConnect"
$Record = Join-Path $Data "logs\启动记录.txt"
$Shots = Join-Path (Split-Path -Parent $Report) "screens"
New-Item -ItemType Directory -Force -Path $Folder, $Shots | Out-Null
$results = [ordered]@{ system = (Get-CimInstance Win32_OperatingSystem).Caption + " " + [Environment]::OSVersion.Version; problems = @() }

Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class StartNative {
  public delegate bool EnumProc(IntPtr hwnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc callback, IntPtr lParam);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int max);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder text, int max);
  [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr hwnd, int id);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hwnd, uint msg, IntPtr w, IntPtr l);
  [DllImport("ntdll.dll")] public static extern int NtSuspendProcess(IntPtr process);
  public static string Text(IntPtr hwnd) { var b = new StringBuilder(4096); GetWindowText(hwnd, b, b.Capacity); return b.ToString(); }
  public static string Class(IntPtr hwnd) { var b = new StringBuilder(256); GetClassName(hwnd, b, b.Capacity); return b.ToString(); }
  public static List<IntPtr> Visible() {
    var list = new List<IntPtr>();
    EnumWindows((h, l) => { if (IsWindowVisible(h)) list.Add(h); return true; }, IntPtr.Zero);
    return list;
  }
}
"@

function Step([string]$Text) { Write-Host ""; Write-Host "== $Text" }
function Problem([string]$Text) { Write-Host "!! $Text"; $script:results.problems += $Text }

function Helper-Processes {
  @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -and ($_.Path -ieq $LiveExe -or $_.Path -ieq $NewExe)
  })
}

function Helper-Windows {
  $ids = @(Helper-Processes | ForEach-Object { [uint32]$_.Id })
  foreach ($hwnd in [StartNative]::Visible()) {
    [uint32]$owner = 0
    [void][StartNative]::GetWindowThreadProcessId($hwnd, [ref]$owner)
    if ($ids -contains $owner) {
      [pscustomobject]@{ Hwnd = $hwnd; Pid = $owner; Title = [StartNative]::Text($hwnd); Class = [StartNative]::Class($hwnd) }
    }
  }
}

# 等助手主窗口（不算提示框）；$Except 是要忽略的进程（例如被挂起的旧窗口）。
function Wait-Main([int]$Seconds, [uint32]$Except = 0) {
  $start = Get-Date
  while (((Get-Date) - $start).TotalSeconds -lt $Seconds) {
    $found = @(Helper-Windows | Where-Object { $_.Title -eq $Product -and $_.Class -ne '#32770' -and $_.Pid -ne $Except })
    if ($found.Count -gt 0) {
      return [pscustomobject]@{ Pid = $found[0].Pid; Seconds = [math]::Round(((Get-Date) - $start).TotalSeconds, 1) }
    }
    Start-Sleep -Milliseconds 300
  }
  return $null
}

function Wait-Dialog([int]$Seconds) {
  $start = Get-Date
  while (((Get-Date) - $start).TotalSeconds -lt $Seconds) {
    $dialog = @(Helper-Windows | Where-Object { $_.Class -eq '#32770' })
    if ($dialog.Count -gt 0) {
      $text = [StartNative]::Text([StartNative]::GetDlgItem($dialog[0].Hwnd, 0xFFFF))
      return [pscustomobject]@{ Hwnd = $dialog[0].Hwnd; Title = $dialog[0].Title; Text = $text; Seconds = [math]::Round(((Get-Date) - $start).TotalSeconds, 1) }
    }
    Start-Sleep -Milliseconds 300
  }
  return $null
}

function Stop-Helpers {
  Helper-Processes | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
  # WebView2 的浏览器进程会占着数据目录。
  Get-CimInstance Win32_Process -Filter "Name='msedgewebview2.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*UseGoodAI*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  Start-Sleep -Seconds 2
}

function Reset-Data {
  Stop-Helpers
  if (Test-Path -LiteralPath $Data) {
    & icacls $Data /remove:d $env:USERNAME /T /C /Q | Out-Null
    Remove-Item -LiteralPath $Data -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Record-Text {
  if (Test-Path -LiteralPath $Record) { return (Get-Content -LiteralPath $Record -Raw -Encoding UTF8) }
  return "（没有启动记录）"
}

function Save-Screen([string]$Name) {
  try {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $bitmap.Save((Join-Path $Shots "$Name.png"))
    $graphics.Dispose(); $bitmap.Dispose()
  } catch { Write-Host "截图失败：$($_.Exception.Message)" }
}

function Security-Events([datetime]$Since) {
  $events = @()
  foreach ($log in @(
      @{ LogName = 'Microsoft-Windows-Windows Defender/Operational'; Id = 1006, 1007, 1015, 1116, 1117, 1118, 1119, 1120 },
      @{ LogName = 'Microsoft-Windows-CodeIntegrity/Operational'; Id = 3033, 3034, 3076, 3077, 3089 },
      @{ LogName = 'Application'; Id = 1000, 1001, 1002 })) {
    try {
      $events += @(Get-WinEvent -FilterHashtable @{ LogName = $log.LogName; Id = $log.Id; StartTime = $Since } -ErrorAction Stop |
        ForEach-Object { "{0} {1}：{2}" -f $_.LogName, $_.Id, (($_.Message -replace '\s+', ' ').Substring(0, [Math]::Min(300, ($_.Message -replace '\s+', ' ').Length))) })
    } catch {}
  }
  try { $events += @(Get-MpThreatDetection -ErrorAction Stop | Where-Object { $_.InitialDetectionTime -ge $Since } | ForEach-Object { "Defender 检测：$($_.ThreatID) $($_.Resources -join ', ')" }) } catch {}
  return $events
}

function Mark-Downloaded([string]$Path) {
  Set-Content -LiteralPath $Path -Stream Zone.Identifier -Encoding Ascii -Value "[ZoneTransfer]`r`nZoneId=3`r`nReferrerUrl=https://docs.usegoodai.com/`r`nHostUrl=$LiveUrl"
}

try {
  Step "准备：线上版（浏览器下载的文件名）与候选版，都带下载标记"
  Invoke-WebRequest -Uri $LiveUrl -OutFile $LiveExe -UseBasicParsing
  Copy-Item -LiteralPath $Candidate -Destination $NewExe -Force
  Mark-Downloaded $LiveExe
  Mark-Downloaded $NewExe
  $results.live_version = (Get-Item -LiteralPath $LiveExe).VersionInfo.ProductVersion
  $results.candidate_version = (Get-Item -LiteralPath $NewExe).VersionInfo.ProductVersion
  Write-Host "线上版 $($results.live_version)，候选版 $($results.candidate_version)"

  Step "1. 家用默认的 Defender，双击打开"
  try {
    Set-MpPreference -DisableRealtimeMonitoring $false -DisableBehaviorMonitoring $false -DisableIOAVProtection $false `
      -MAPSReporting Advanced -SubmitSamplesConsent SendSafeSamples -CloudBlockLevel Default -PUAProtection Enabled -ErrorAction Stop
  } catch { Write-Host "设置 Defender 失败：$($_.Exception.Message)" }
  $status = Get-MpComputerStatus
  $preference = Get-MpPreference
  $results.defender = "实时保护 $($status.RealTimeProtectionEnabled)，行为监控 $($status.BehaviorMonitorEnabled)，下载扫描 $($status.IoavProtectionEnabled)，" +
    "云保护 $($preference.MAPSReporting)，自动提交样本 $($preference.SubmitSamplesConsent)，拦截不需要的应用 $($preference.PUAProtection)，病毒库 $($status.AntivirusSignatureVersion)"
  Write-Host $results.defender
  $scenario = [ordered]@{}
  foreach ($item in @(@{ Name = 'live'; Exe = $LiveExe }, @{ Name = 'candidate'; Exe = $NewExe })) {
    Reset-Data
    $since = Get-Date
    Start-Process -FilePath $item.Exe | Out-Null
    $main = Wait-Main 90
    Save-Screen "1-defender-$($item.Name)"
    $scenario[$item.Name] = [ordered]@{
      opened = [bool]$main; seconds = $(if ($main) { $main.Seconds } else { $null })
      file_kept = (Test-Path -LiteralPath $item.Exe); events = @(Security-Events $since); record = (Record-Text)
    }
    Write-Host "$($item.Name)：打开 $([bool]$main)，文件还在 $($scenario[$item.Name].file_kept)"
    $scenario[$item.Name].events | ForEach-Object { Write-Host "  $_" }
  }
  $results.defender_defaults = $scenario
  if (-not $scenario.candidate.opened) { Problem "家用默认 Defender 下候选版没有打开" }

  Step "2. WebView2 数据目录损坏（EBWebView 位置是一个文件）"
  $scenario = [ordered]@{}
  Reset-Data
  New-Item -ItemType Directory -Force -Path $Data | Out-Null
  Set-Content -LiteralPath (Join-Path $Data "EBWebView") -Value "damaged"
  $first = Start-Process -FilePath $LiveExe -PassThru
  $main = Wait-Main 40
  $first.Refresh()
  $second = Start-Process -FilePath $LiveExe -PassThru
  $secondMain = Wait-Main 15
  $second.Refresh()
  Save-Screen "2-damaged-live"
  $scenario.live = [ordered]@{
    first_opened = [bool]$main; first_still_running = (-not $first.HasExited)
    second_opened = [bool]$secondMain; second_exited = $second.HasExited; record = (Record-Text)
  }
  Write-Host "线上版：第一次打开 $([bool]$main)，仍在后台 $(-not $first.HasExited)；再次双击打开 $([bool]$secondMain)，已退出 $($second.HasExited)"
  # 线上版卡住的进程留着，候选版要能自己把它结束掉。
  $start = Get-Date
  Start-Process -FilePath $NewExe | Out-Null
  $main = Wait-Main 180
  Save-Screen "2-damaged-candidate"
  $text = Record-Text
  $scenario.candidate = [ordered]@{ opened = [bool]$main; seconds = $(if ($main) { $main.Seconds } else { $null }); record = $text }
  Write-Host "候选版：打开 $([bool]$main)，用时 $($scenario.candidate.seconds) 秒"
  Write-Host $text
  if (-not $main) { Problem "数据目录损坏时候选版没有打开" }
  foreach ($want in @('换新数据目录再试', '已记住')) { if (-not $text.Contains($want)) { Problem "数据目录损坏：启动记录缺少「$want」" } }
  if ($main -and $scenario.live.first_still_running -and -not $text.Contains('已结束卡住的助手')) { Problem "没有结束卡在后台的线上版" }
  Stop-Helpers
  Start-Process -FilePath $NewExe | Out-Null
  $again = Wait-Main 60
  $text = Record-Text
  $scenario.candidate_again = [ordered]@{ opened = [bool]$again; seconds = $(if ($again) { $again.Seconds } else { $null }); uses_saved = $text.Contains('WebView2 数据目录 WebView2-') }
  Write-Host "候选版再次打开：$([bool]$again)，用时 $($scenario.candidate_again.seconds) 秒，直接用记住的数据目录 $($scenario.candidate_again.uses_saved)"
  if (-not $again -or -not $scenario.candidate_again.uses_saved) { Problem "数据目录损坏：再次打开没有直接用记住的数据目录" }
  $results.damaged_profile = $scenario

  Step "3. 已开的助手不响应（进程被挂起）"
  $scenario = [ordered]@{}
  foreach ($item in @(@{ Name = 'live'; Exe = $LiveExe }, @{ Name = 'candidate'; Exe = $NewExe })) {
    Reset-Data
    Start-Process -FilePath $item.Exe | Out-Null
    $main = Wait-Main 90
    if (-not $main) { Problem "$($item.Name)：不响应场景第一次没有打开"; continue }
    Start-Sleep -Seconds 25
    $hung = Get-Process -Id $main.Pid
    [void][StartNative]::NtSuspendProcess($hung.Handle)
    $later = Start-Process -FilePath $item.Exe -PassThru
    $fresh = Wait-Main $(if ($item.Name -eq 'live') { 30 } else { 120 }) $main.Pid
    $later.Refresh(); $hung.Refresh()
    Save-Screen "3-hung-$($item.Name)"
    $scenario[$item.Name] = [ordered]@{
      new_window = [bool]$fresh; seconds = $(if ($fresh) { $fresh.Seconds } else { $null })
      later_still_running = (-not $later.HasExited); hung_ended = $hung.HasExited; record = (Record-Text)
    }
    Write-Host "$($item.Name)：再次双击出现新窗口 $([bool]$fresh)，卡住的进程已结束 $($hung.HasExited)，后来的进程仍挂着 $(-not $later.HasExited)"
  }
  if (-not $scenario.candidate.new_window -or -not $scenario.candidate.hung_ended) { Problem "已开的助手不响应时，候选版没有结束它并打开新窗口" }
  elseif (-not $scenario.candidate.record.Contains('已结束卡住的助手')) { Problem "不响应场景：启动记录缺少「已结束卡住的助手」" }
  $results.hung_window = $scenario

  Step "4. WebView2 怎么都起不来（数据目录下不能新建文件夹）"
  $scenario = [ordered]@{}
  foreach ($item in @(@{ Name = 'live'; Exe = $LiveExe }, @{ Name = 'candidate'; Exe = $NewExe })) {
    Reset-Data
    New-Item -ItemType Directory -Force -Path (Join-Path $Data "logs") | Out-Null
    & icacls $Data /deny "$($env:USERNAME):(AD)" | Out-Null
    $process = Start-Process -FilePath $item.Exe -PassThru
    $dialog = Wait-Dialog $(if ($item.Name -eq 'live') { 60 } else { 200 })
    $main = $null
    if (-not $dialog) { $main = Wait-Main 1 }
    $process.Refresh()
    Save-Screen "4-no-webview-$($item.Name)"
    $entry = [ordered]@{
      dialog = [bool]$dialog; dialog_text = $(if ($dialog) { $dialog.Text } else { $null }); seconds = $(if ($dialog) { $dialog.Seconds } else { $null })
      opened = [bool]$main; exited = $process.HasExited; exit_code = $(if ($process.HasExited) { $process.ExitCode } else { $null }); record = (Record-Text)
    }
    Write-Host "$($item.Name)：提示框 $([bool]$dialog)，窗口 $([bool]$main)，进程已退出 $($process.HasExited)"
    if ($dialog) { Write-Host "  提示：$($dialog.Text)" }
    if ($item.Name -eq 'candidate' -and $dialog) {
      # 点「确定」：应打开改用的命令窗口（网站的 PowerShell 接入脚本）。
      $before = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | ForEach-Object { $_.ProcessId })
      [void][StartNative]::PostMessage($dialog.Hwnd, 0x0111, [IntPtr]1, [IntPtr]::Zero)
      Start-Sleep -Seconds 8
      $fallback = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $before -notcontains $_.ProcessId -and $_.CommandLine -like '*install/codex.ps1*' })
      $entry.fallback_started = ($fallback.Count -gt 0)
      Save-Screen "4-fallback-window"
      $fallback | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
      Write-Host "  点确定后打开命令窗口：$($entry.fallback_started)"
    } elseif ($dialog) {
      [void][StartNative]::PostMessage($dialog.Hwnd, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    }
    $scenario[$item.Name] = $entry
    & icacls $Data /remove:d $env:USERNAME | Out-Null
  }
  if (-not $scenario.candidate.dialog) { Problem "WebView2 起不来时候选版没有提示框" }
  elseif (-not $scenario.candidate.dialog_text.Contains('窗口没能打开')) { Problem "提示框内容不对：$($scenario.candidate.dialog_text)" }
  elseif (-not $scenario.candidate.fallback_started) { Problem "点「确定」后没有打开命令窗口" }
  $results.no_webview = $scenario
} catch {
  Problem "脚本出错：$($_.Exception.Message) $($_.InvocationInfo.PositionMessage)"
  Save-Screen "error"
} finally {
  Reset-Data
  $results | ConvertTo-Json -Depth 6 | Out-File -LiteralPath $Report -Encoding utf8
}

if ($env:GITHUB_STEP_SUMMARY) {
  $lines = @("### 助手打开稳妥性（$($results.system)）", "", "线上版 $($results.live_version)，候选版 $($results.candidate_version)；$($results.defender)", "")
  if ($results.problems.Count -eq 0) { $lines += "候选版全部通过。" } else { $lines += $results.problems | ForEach-Object { "- $_" } }
  ($lines -join "`n") | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
}
if ($results.problems.Count -gt 0) { exit 1 }
Write-Host "候选版全部通过"
