param([Parameter(Mandatory=$true)][string]$TestExe)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Windows.Forms, System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ErrorDialogMouse {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
}
'@
$work = Join-Path $env:RUNNER_TEMP 'error-ui'
$report = Join-Path $work 'report'
New-Item -ItemType Directory -Force $report | Out-Null
$env:USEGOODAI_ERROR_UI_TEST='1'
$env:USEGOODAI_ERROR_UI_ROOT=Join-Path $work 'appdata'
$expectedLog=Join-Path $env:USEGOODAI_ERROR_UI_ROOT 'UseGoodAI\QuickConnect\logs\latest-error.log'
$process=$null
function Shot([string]$Name) {
  $screen=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bitmap=New-Object System.Drawing.Bitmap $screen.Width,$screen.Height
  $graphics=[System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.CopyFromScreen($screen.Location,[System.Drawing.Point]::Empty,$screen.Size)
  $bitmap.Save((Join-Path $report "$Name.png"))
  $graphics.Dispose(); $bitmap.Dispose()
}
function Find-Button($Window,[string]$Name) {
  $condition=New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty,$Name)
  $element=$Window.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$condition)
  if (-not $element) { throw "没有按钮：$Name" }
  return $element
}
function Click-Control($Element) {
  [ErrorDialogMouse]::SetForegroundWindow($process.MainWindowHandle) | Out-Null
  Start-Sleep -Milliseconds 200
  $bounds=$Element.Current.BoundingRectangle
  if ($bounds.IsEmpty) { throw '控件没有可点击区域' }
  [ErrorDialogMouse]::SetCursorPos([int]($bounds.X+$bounds.Width/2),[int]($bounds.Y+$bounds.Height/2)) | Out-Null
  [ErrorDialogMouse]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
  Start-Sleep -Milliseconds 80
  [ErrorDialogMouse]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
}
try {
  $start=New-Object System.Diagnostics.ProcessStartInfo
  $start.FileName=$TestExe
  $start.Arguments='-test.run=^TestNativeErrorDialog$ -test.v'
  $start.UseShellExecute=$false
  $start.CreateNoWindow=$true
  $start.RedirectStandardOutput=$true
  $start.RedirectStandardError=$true
  $process=[System.Diagnostics.Process]::Start($start)
  $condition=New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty,$process.Id)
  $deadline=(Get-Date).AddSeconds(30)
  do {
    Start-Sleep -Milliseconds 200
    if ($process.HasExited) { throw ('弹窗测试提前退出：'+$process.StandardError.ReadToEnd()+$process.StandardOutput.ReadToEnd()) }
    $window=[System.Windows.Automation.AutomationElement]::RootElement.FindFirst([System.Windows.Automation.TreeScope]::Children,$condition)
  } until ($window -or (Get-Date) -gt $deadline)
  if (-not $window) { throw '未出现原生错误弹窗' }
  Shot 'error-dialog'
  $copy=Find-Button $window '复制错误信息'
  Click-Control $copy
  Start-Sleep -Milliseconds 300
  $text=Get-Clipboard -Raw
  if (-not $text.Contains('0x80004005') -or $text.Contains('sk-ui-fake-secret') -or -not $text.Contains('1.1.9')) { throw '复制结果错误或泄露假 Key' }
  if ($process.HasExited) { throw '复制操作关闭了错误弹窗' }
  Shot 'copied-error'
  if (-not (Test-Path -LiteralPath $expectedLog)) { throw '未按固定位置保存备用日志' }
  $log=Get-Content -LiteralPath $expectedLog -Raw
  if ($log.Contains('sk-ui-fake-secret') -or -not $log.Contains('0x80004005')) { throw '日志没有错误详情或未隐藏 Key' }
  $open=Find-Button $window '打开日志文件夹'
  Click-Control $open
  $shell=New-Object -ComObject Shell.Application
  $deadline=(Get-Date).AddSeconds(15)
  $opened=$null
  do {
    Start-Sleep -Milliseconds 300
    foreach ($item in @($shell.Windows())) {
      try { if ($item.Document.Folder.Self.Path -eq (Split-Path $expectedLog)) { $opened=$item; break } } catch {}
    }
  } until ($opened -or (Get-Date) -gt $deadline)
  if (-not $opened) { throw '打开日志文件夹按钮没有打开正确目录' }
  Shot 'opened-logs'
  $opened.Quit()
  $close=Find-Button $window '关闭'
  Click-Control $close
  if (-not $process.WaitForExit(15000) -or $process.ExitCode -ne 0) { throw '错误弹窗未正常关闭' }
  Copy-Item -LiteralPath $expectedLog -Destination (Join-Path $report 'latest-error.log')
  @{version='1.0.1';assistant='1.1.9';copy='passed';openLogFolder='passed';redaction='passed';close='passed';productionFault='not injected; tested the same native reporting function from a test-only executable'} | ConvertTo-Json | Set-Content (Join-Path $report 'report.json')
  Write-Host '错误弹窗：复制、打开固定日志目录、脱敏和关闭全部通过'
} catch {
  Shot 'failure'
  if (Test-Path -LiteralPath $expectedLog) { Copy-Item -LiteralPath $expectedLog -Destination (Join-Path $report 'latest-error.log') }
  throw
} finally {
  if ($process -and -not $process.HasExited) { Stop-Process -Id $process.Id -Force }
  Remove-Item Env:USEGOODAI_ERROR_UI_TEST -ErrorAction SilentlyContinue
  Remove-Item Env:USEGOODAI_ERROR_UI_ROOT -ErrorAction SilentlyContinue
}
