# 在 Windows 上实际打开接入助手，检查“新打开的窗口接管”的每种情况。
# GitHub Actions 的 windows-quick-connect 工作流运行它；不用任何真实密钥。
#   -New       要发布的助手 exe
#   -Previous  上一个稳定版助手 exe（1.1.3，用 Wails 自带的单窗口锁）
#   -Version   要发布的版本号
param(
  [Parameter(Mandatory = $true)][string]$New,
  [Parameter(Mandatory = $true)][string]$Previous,
  [Parameter(Mandatory = $true)][string]$Version
)
$ErrorActionPreference = "Stop"
$Product = "UseGoodAI中转快速接入助手"
$Work = Join-Path $(if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }) "helper-smoke"
$Log = Join-Path $env:LOCALAPPDATA "UseGoodAI\QuickConnect\startup.log"
$FakeLink = "usegoodai://import?key=sk-smoke-not-a-real-key-0000&name=smoke"

New-Item -ItemType Directory -Force -Path $Work | Out-Null
$NewExe = Join-Path $Work "1.$Product.exe"
$OldExe = Join-Path $Work "previous-$Product.exe"
Copy-Item -LiteralPath $New -Destination $NewExe -Force
Copy-Item -LiteralPath $Previous -Destination $OldExe -Force
# 只检查本次测试写入的记录。
$LogStart = if (Test-Path -LiteralPath $Log) { @(Get-Content -LiteralPath $Log -Encoding UTF8).Count } else { 0 }

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class SmokeNative {
  [DllImport("ntdll.dll")] public static extern int NtSuspendProcess(IntPtr process);
}
"@

function Step([string]$Text) { Write-Host ""; Write-Host "== $Text" }

function Start-Helper([string]$Exe, [string[]]$Arguments = @()) {
  if ($Arguments.Count -gt 0) {
    return Start-Process -FilePath $Exe -ArgumentList $Arguments -PassThru
  }
  return Start-Process -FilePath $Exe -PassThru
}

function Wait-Window($Process, [int]$Seconds = 45) {
  $deadline = (Get-Date).AddSeconds($Seconds)
  while ((Get-Date) -lt $deadline) {
    $Process.Refresh()
    if ($Process.HasExited) { throw "进程 $($Process.Id) 提前退出，退出码 $($Process.ExitCode)" }
    if ($Process.MainWindowHandle -ne [IntPtr]::Zero -and $Process.MainWindowTitle -eq $Product) {
      Write-Host "进程 $($Process.Id) 出现窗口「$($Process.MainWindowTitle)」"
      return
    }
    Start-Sleep -Milliseconds 250
  }
  throw "进程 $($Process.Id) $Seconds 秒内没有出现窗口"
}

function Wait-Exit($Process, [int]$Seconds) {
  if (-not $Process.WaitForExit($Seconds * 1000)) { throw "进程 $($Process.Id) $Seconds 秒内没有退出" }
  Write-Host "进程 $($Process.Id) 已退出"
}

function Assert-Running($Process) {
  $Process.Refresh()
  if ($Process.HasExited) { throw "进程 $($Process.Id) 不应该退出" }
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
  Get-Process | Where-Object { $_.Path -and $_.Path.StartsWith($Work, [StringComparison]::OrdinalIgnoreCase) } |
    ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
}

try {
  Step "版本号"
  $actual = (Get-Item -LiteralPath $NewExe).VersionInfo.ProductVersion
  if ($actual -ne $Version) { throw "exe 版本是 $actual，应为 $Version" }
  Write-Host "版本 $actual"

  Step "第一次打开出现窗口"
  $a = Start-Helper $NewExe
  Wait-Window $a

  Step "再次打开：旧窗口空闲，由新窗口接管"
  $b = Start-Helper $NewExe
  Wait-Exit $a 15
  Wait-Window $b

  Step "旧窗口卡死：新窗口结束它并接管"
  [void][SmokeNative]::NtSuspendProcess($b.Handle)
  $c = Start-Helper $NewExe
  Wait-Exit $b 20
  Wait-Window $c

  Step "带导入链接打开：接管后由新窗口处理链接"
  $d = Start-Helper $NewExe @($FakeLink)
  Wait-Exit $c 15
  Wait-Window $d

  Step "旧版 1.1.3 在运行：新版关闭它并接管"
  Stop-Process -Id $d.Id -Force
  Wait-Exit $d 15
  $old = Start-Helper $OldExe
  Wait-Window $old
  $e = Start-Helper $NewExe
  Wait-Exit $old 20
  Wait-Window $e

  Step "新版运行时打开旧版：旧版把链接交给新版后退出"
  $old2 = Start-Helper $OldExe @($FakeLink)
  Wait-Exit $old2 20
  Start-Sleep -Seconds 2
  Assert-Running $e

  Step "启动记录"
  Stop-Helpers
  Start-Sleep -Seconds 2
  $lines = @(Get-Content -LiteralPath $Log -Encoding UTF8) | Select-Object -Skip $LogStart
  $text = $lines -join "`n"
  Write-Host $text
  Set-Content -LiteralPath (Join-Path $Work "startup.log") -Value $lines -Encoding UTF8
  if ($text -match "sk-smoke") { throw "启动记录里出现了导入链接里的密钥" }
  foreach ($expected in @("启动 $Version", "空闲，由本次打开接管", "没有响应，结束它", "旧版助手")) {
    if (-not $text.Contains($expected)) { throw "启动记录里缺少「$expected」" }
  }
  Write-Host ""
  Write-Host "全部通过"
} catch {
  Save-Screen "failure"
  if (Test-Path -LiteralPath $Log) {
    Copy-Item -LiteralPath $Log -Destination (Join-Path $Work "startup.log") -Force
    Write-Host "---- startup.log ----"
    Get-Content -LiteralPath $Log -Encoding UTF8 | Write-Host
  }
  throw
} finally {
  Stop-Helpers
}
