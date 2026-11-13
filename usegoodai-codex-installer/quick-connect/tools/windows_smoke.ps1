# 在 Windows 上实际打开接入助手，检查单窗口：后来打开的助手（包括网站的导入链接）
# 把参数交给已开的窗口后退出，已开的窗口一直留在屏幕上。
# GitHub Actions 的 windows-quick-connect 工作流运行它；不用任何真实密钥。
#   -New       要发布的助手 exe
#   -Previous  上一个稳定版助手 exe
#   -Version   要发布的版本号
param(
  [Parameter(Mandatory = $true)][string]$New,
  [Parameter(Mandatory = $true)][string]$Previous,
  [Parameter(Mandatory = $true)][string]$Version
)
$ErrorActionPreference = "Stop"
$Product = "UseGoodAI中转快速接入助手"
$Work = Join-Path $(if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }) "helper-smoke"
$FakeLink = "usegoodai://import?key=sk-smoke-not-a-real-key-0000&name=smoke"

New-Item -ItemType Directory -Force -Path $Work | Out-Null
$NewExe = Join-Path $Work "1.$Product.exe"
$OldExe = Join-Path $Work "previous-$Product.exe"
Copy-Item -LiteralPath $New -Destination $NewExe -Force
Copy-Item -LiteralPath $Previous -Destination $OldExe -Force

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class SmokeNative {
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hwnd);
}
"@

function Step([string]$Text) { Write-Host ""; Write-Host "== $Text" }

# 启动记录（见 startrecord.go）：每次启动写几行阶段，已有实例时追加。
$Record = Join-Path $env:LOCALAPPDATA 'UseGoodAI\QuickConnect\logs\启动记录.txt'
function Assert-Record([string[]]$Contains, [string[]]$Absent = @()) {
  $text = Get-Content -LiteralPath $Record -Raw -Encoding UTF8
  foreach ($want in $Contains) { if (-not $text.Contains($want)) { throw "启动记录缺少「$want」：`n$text" } }
  foreach ($bad in $Absent) { if ($text.Contains($bad)) { throw "启动记录不应包含「$bad」：`n$text" } }
  Write-Host $text
}

function Start-Helper([string]$Exe, [string[]]$Arguments = @()) {
  if ($Arguments.Count -gt 0) {
    return Start-Process -FilePath $Exe -ArgumentList $Arguments -PassThru
  }
  return Start-Process -FilePath $Exe -PassThru
}

# 1.1.14 起双击的进程是启动守护，窗口属于它启动的窗口进程（见 guard.go）；
# 上一稳定版则是同一个进程。按窗口标题找出带窗口的助手进程。
function Wait-Window($Launched, [int]$Seconds = 90) {
  $deadline = (Get-Date).AddSeconds($Seconds)
  while ((Get-Date) -lt $deadline) {
    foreach ($candidate in Helper-Processes) {
      $candidate.Refresh()
      if ($candidate.MainWindowHandle -ne [IntPtr]::Zero -and $candidate.MainWindowTitle -eq $Product) {
        Write-Host "打开的进程 $($Launched.Id)，窗口进程 $($candidate.Id)「$($candidate.MainWindowTitle)」"
        return $candidate
      }
    }
    $Launched.Refresh()
    if ($Launched.HasExited -and $Launched.ExitCode -ne 0) { throw "进程 $($Launched.Id) 提前退出，退出码 $($Launched.ExitCode)" }
    Start-Sleep -Milliseconds 250
  }
  throw "打开的进程 $($Launched.Id) $Seconds 秒内没有出现窗口"
}

function Wait-Exit($Process, [int]$Seconds) {
  if (-not $Process.WaitForExit($Seconds * 1000)) { throw "进程 $($Process.Id) $Seconds 秒内没有退出" }
  Write-Host "进程 $($Process.Id) 已退出"
}

# 窗口要一直开着、可见、没有最小化，看满 $Seconds 秒。
function Assert-Stays($Process, [int]$Seconds = 10) {
  $deadline = (Get-Date).AddSeconds($Seconds)
  while ((Get-Date) -lt $deadline) {
    $Process.Refresh()
    if ($Process.HasExited) { throw "进程 $($Process.Id) 不应该退出，退出码 $($Process.ExitCode)" }
    $hwnd = $Process.MainWindowHandle
    if ($hwnd -eq [IntPtr]::Zero -or -not [SmokeNative]::IsWindowVisible($hwnd) -or [SmokeNative]::IsIconic($hwnd)) {
      throw "进程 $($Process.Id) 的窗口不见了"
    }
    Start-Sleep -Milliseconds 250
  }
  Write-Host "进程 $($Process.Id) 的窗口 $Seconds 秒内一直可见"
}

function Helper-Processes {
  @(Get-Process | Where-Object { $_.Path -and $_.Path.StartsWith($Work, [StringComparison]::OrdinalIgnoreCase) })
}

function Save-Screen([string]$Name) {
  try {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $bitmap.Save((Join-Path $Work "$Name.png"))
    $graphics.Dispose(); $bitmap.Dispose()
  } catch {
    Write-Host "截图失败：$($_.Exception.Message)"
  }
}

function Stop-Helpers {
  Helper-Processes | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
}

try {
  Step "版本号"
  $actual = (Get-Item -LiteralPath $NewExe).VersionInfo.ProductVersion
  if ($actual -ne $Version) { throw "exe 版本是 $actual，应为 $Version" }
  Write-Host "版本 $actual"

  Step "第一次打开出现窗口，并且一直留着"
  $a = Wait-Window (Start-Helper $NewExe)
  Assert-Stays $a
  Save-Screen "first-open"
  Step "启动记录：第一次打开走完全部阶段"
  Assert-Record @('启动', '窗口进程', '创建窗口', '窗口已建立', '页面就绪') @('已有实例', '窗口没有打开', '已结束卡住的助手')

  Step "再次打开：参数交给已开的窗口，后来的进程退出"
  $b = Start-Helper $NewExe
  Wait-Exit $b 20
  Assert-Stays $a
  Assert-Record @('页面就绪', "已有实例  进程 $($a.Id)，窗口可见")

  Step "带导入链接打开（网站一键导入）：链接交给已开的窗口，窗口留着"
  $c = Start-Helper $NewExe @($FakeLink)
  Wait-Exit $c 20
  Assert-Stays $a 15
  Save-Screen "after-link"
  Assert-Record @('带导入链接：是') @('usegoodai://', $FakeLink)
  $left = @(Helper-Processes)
  if ($left.Count -ne 1 -or $left[0].Id -ne $a.Id) { throw "应只剩第一次打开的助手进程，实际 $($left.Count) 个" }

  Step "没有窗口时用导入链接打开：直接出现窗口，并且一直留着"
  Stop-Process -Id $a.Id -Force
  Wait-Exit $a 15
  Start-Sleep -Seconds 2
  $d = Wait-Window (Start-Helper $NewExe @($FakeLink))
  Assert-Stays $d 15
  Save-Screen "cold-link"
  Assert-Record @('带导入链接：是', '页面就绪') @('已有实例', 'usegoodai://', $FakeLink)

  Step "上一稳定版在运行时打开新版：链接交给上一稳定版的窗口"
  Stop-Process -Id $d.Id -Force
  Wait-Exit $d 15
  Start-Sleep -Seconds 2
  $old = Wait-Window (Start-Helper $OldExe)
  $e = Start-Helper $NewExe @($FakeLink)
  Wait-Exit $e 20
  Assert-Stays $old
  Assert-Record @("已有实例  进程 $($old.Id)") @('usegoodai://', $FakeLink)

  Write-Host ""
  Write-Host "全部通过"
} catch {
  Save-Screen "failure"
  throw
} finally {
  Stop-Helpers
}
