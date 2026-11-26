$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class AGYWindow {
  [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr w);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr w, out Rect r);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags,uint dx,uint dy,uint data,UIntPtr extra);
}
"@
function Capture([string]$name) {
  try {
    $bounds=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp=New-Object System.Drawing.Bitmap($bounds.Width,$bounds.Height)
    $g=[System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($bounds.X,$bounds.Y,0,0,$bmp.Size)
    $bmp.Save((Join-Path $env:AGY_TEST_EVIDENCE $name))
    $g.Dispose(); $bmp.Dispose()
  } catch { Write-Host "Screenshot unavailable: $($_.Exception.Message)" }
}
$window=$null
for ($i=0; $i -lt 90; $i++) {
  $window=Get-Process -Name Antigravity -ErrorAction SilentlyContinue | Where-Object {$_.MainWindowHandle -ne 0} | Select-Object -First 1
  if ($window) {break}; Start-Sleep -Seconds 1
}
if (-not $window) {throw 'No actual Antigravity window in runner session'}
Start-Sleep -Seconds 6
Capture 'before.png'
$h=$window.MainWindowHandle
$shell=New-Object -ComObject WScript.Shell
[void]$shell.AppActivate($window.Id)
[void][AGYWindow]::SetForegroundWindow($h)
Start-Sleep -Milliseconds 300
if ([AGYWindow]::GetForegroundWindow() -ne $h) {throw 'Runner did not allow actual foreground window activation'}
$r=New-Object AGYWindow+Rect
if (-not [AGYWindow]::GetWindowRect($h,[ref]$r)){throw 'Unable to read window rectangle'}
[void][AGYWindow]::SetCursorPos([int]($r.Left+($r.Right-$r.Left)*0.55),[int]($r.Bottom-90))
[AGYWindow]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
[AGYWindow]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
[System.Windows.Forms.SendKeys]::SendWait('test{ENTER}')
Start-Sleep -Seconds 8
Capture 'after.png'
[System.Windows.Forms.SendKeys]::SendWait('%{F4}')
