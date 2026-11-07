# 反复在助手开着时再打开它（带导入链接，就像在网站点「一键导入」），看有没有窗口闪退。
# 1.1.3 及以前：后打开的把链接交给已开的窗口后退出，已开的窗口一直在。
# 1.1.4：已开的窗口关闭，后打开的窗口接管；接管后的窗口必须出现并保持打开。
param(
  [Parameter(Mandatory = $true)][string]$Exe,
  [Parameter(Mandatory = $true)][string]$Label,
  [int]$Rounds = 20
)
$ErrorActionPreference = "Stop"
$Product = "UseGoodAI中转快速接入助手"
$Work = Join-Path $env:RUNNER_TEMP "stress-$Label"
New-Item -ItemType Directory -Force -Path $Work | Out-Null
$Helper = Join-Path $Work "1.$Product.exe"
Copy-Item -LiteralPath $Exe -Destination $Helper -Force
$Link = "usegoodai://import?key=sk-stress-not-a-real-key-0000&name=stress"
$Log = Join-Path $env:LOCALAPPDATA "UseGoodAI\QuickConnect\startup.log"

Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class StressNative {
  delegate bool EnumProc(IntPtr hwnd, IntPtr lParam);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc callback, IntPtr lParam);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder name, int size);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int size);
  public static string[] Dialogs(uint pid) {
    var found = new List<string>();
    EnumWindows((hwnd, l) => {
      uint owner; GetWindowThreadProcessId(hwnd, out owner);
      if (owner == pid && IsWindowVisible(hwnd)) {
        var cls = new StringBuilder(256); GetClassName(hwnd, cls, 256);
        if (cls.ToString() == "#32770") { var t = new StringBuilder(512); GetWindowText(hwnd, t, 512); found.Add(t.ToString()); }
      }
      return true;
    }, IntPtr.Zero);
    return found.ToArray();
  }
}
"@

function Stop-All {
  Get-Process | Where-Object { $_.Path -and $_.Path.StartsWith($Work, [StringComparison]::OrdinalIgnoreCase) } |
    ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
}

# 等 $Process 出现助手窗口；出错时返回原因。
function Wait-Window($Process, [int]$Seconds) {
  $deadline = (Get-Date).AddSeconds($Seconds)
  while ((Get-Date) -lt $deadline) {
    $Process.Refresh()
    if ($Process.HasExited) { return "进程 $($Process.Id) 没出窗口就退出了，退出码 $($Process.ExitCode)" }
    $dialogs = [StressNative]::Dialogs([uint32]$Process.Id)
    if ($dialogs.Count -gt 0) { return "进程 $($Process.Id) 弹出对话框：$($dialogs -join ' / ')" }
    if ($Process.MainWindowHandle -ne [IntPtr]::Zero -and $Process.MainWindowTitle -eq $Product) { return "" }
    Start-Sleep -Milliseconds 200
  }
  return "进程 $($Process.Id) $Seconds 秒内没有出现窗口"
}

# 窗口出现后再看 $Seconds 秒：不能退出，也不能弹出错误框。
function Watch-Alive($Process, [int]$Seconds) {
  $deadline = (Get-Date).AddSeconds($Seconds)
  while ((Get-Date) -lt $deadline) {
    $Process.Refresh()
    if ($Process.HasExited) { return "进程 $($Process.Id) 窗口出现后闪退，退出码 $($Process.ExitCode)" }
    $dialogs = [StressNative]::Dialogs([uint32]$Process.Id)
    if ($dialogs.Count -gt 0) { return "进程 $($Process.Id) 弹出对话框：$($dialogs -join ' / ')" }
    Start-Sleep -Milliseconds 200
  }
  return ""
}

$failures = New-Object System.Collections.Generic.List[string]
$logStart = if (Test-Path -LiteralPath $Log) { @(Get-Content -LiteralPath $Log -Encoding UTF8).Count } else { 0 }
try {
  $version = (Get-Item -LiteralPath $Helper).VersionInfo.ProductVersion
  Write-Host "$Label：版本 $version"
  $current = Start-Process -FilePath $Helper -PassThru
  $problem = Wait-Window $current 45
  if ($problem) { throw "第一次打开：$problem" }
  for ($round = 1; $round -le $Rounds; $round++) {
    $started = Get-Date
    $next = Start-Process -FilePath $Helper -ArgumentList @($Link) -PassThru
    # 1.1.3 及以前：后打开的进程把链接交出去后退出，原窗口留下。
    if ($next.WaitForExit(8000) -and $next.ExitCode -eq 0) {
      $current.Refresh()
      $problem = if ($current.HasExited) { "原窗口跟着退出了，退出码 $($current.ExitCode)" } else { Watch-Alive $current 4 }
    } else {
      # 1.1.4：原窗口关闭，新窗口接管。
      $next.Refresh()
      if ($next.HasExited) {
        $problem = "后打开的进程退出码 $($next.ExitCode)"
      } else {
        if (-not $current.WaitForExit(15000)) { $problem = "原窗口 15 秒内没有关闭" }
        else {
          $problem = Wait-Window $next 30
          if (-not $problem) { $problem = Watch-Alive $next 6 }
        }
        $current = $next
      }
    }
    $seconds = [int]((Get-Date) - $started).TotalSeconds
    if ($problem) {
      Write-Host "第 $round 次：失败（$seconds 秒）$problem"
      $failures.Add("第 $round 次：$problem")
      Stop-All
      Start-Sleep -Seconds 3
      $current = Start-Process -FilePath $Helper -PassThru
      $again = Wait-Window $current 45
      if ($again) { throw "失败后重新打开：$again" }
    } else {
      Write-Host "第 $round 次：正常（$seconds 秒）"
    }
  }
} finally {
  Stop-All
  if (Test-Path -LiteralPath $Log) {
    $lines = @(Get-Content -LiteralPath $Log -Encoding UTF8) | Select-Object -Skip $logStart
    Write-Host "---- startup.log ----"
    $lines | Write-Host
  }
  Get-WinEvent -FilterHashtable @{ LogName = "Application"; Id = 1000, 1001, 1026; StartTime = (Get-Date).AddMinutes(-30) } -ErrorAction SilentlyContinue |
    Select-Object -First 10 | ForEach-Object { Write-Host "---- 系统程序错误记录 $($_.TimeCreated)"; Write-Host $_.Message }
}
$summary = "| $Label | $Rounds | $($failures.Count) | $(($failures | Select-Object -First 3) -join '<br>') |"
if ($env:GITHUB_STEP_SUMMARY) { $summary | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8 }
Write-Host "$Label：$Rounds 次里失败 $($failures.Count) 次"
