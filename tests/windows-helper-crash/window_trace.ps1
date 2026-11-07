# Check the actual usegoodai:// registry entry and visible desktop windows,
# rather than treating a live process/MainWindowHandle as a visible UI.
param(
  [Parameter(Mandatory = $true)][string]$Folder,
  [string]$WorkName = 'helper-window-trace'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class WindowTrace {
  public struct Rect { public int left, top, right, bottom; }
  public class State {
    public long hwnd;
    public uint pid;
    public string title, cls;
    public bool visible, minimized, foreground;
    public int cloaked, left, top, right, bottom;
  }
  delegate bool EnumProc(IntPtr hwnd, IntPtr lParam);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc callback, IntPtr lParam);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
  [DllImport("user32.dll")] static extern bool IsIconic(IntPtr hwnd);
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int size);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder text, int size);
  [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr hwnd, int attribute, out int value, int size);
  [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hwnd, int command);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
  public static State[] Windows() {
    var states = new List<State>();
    IntPtr foreground = GetForegroundWindow();
    EnumWindows((hwnd, unused) => {
      uint pid; GetWindowThreadProcessId(hwnd, out pid);
      var title = new StringBuilder(512); GetWindowText(hwnd, title, 512);
      var cls = new StringBuilder(256); GetClassName(hwnd, cls, 256);
      Rect rect; GetWindowRect(hwnd, out rect);
      int cloaked; DwmGetWindowAttribute(hwnd, 14, out cloaked, 4);
      states.Add(new State { hwnd=hwnd.ToInt64(), pid=pid, title=title.ToString(), cls=cls.ToString(),
        visible=IsWindowVisible(hwnd), minimized=IsIconic(hwnd), foreground=hwnd==foreground, cloaked=cloaked,
        left=rect.left, top=rect.top, right=rect.right, bottom=rect.bottom });
      return true;
    }, IntPtr.Zero);
    return states.ToArray();
  }
}
'@

$root = Join-Path $env:RUNNER_TEMP $WorkName
New-Item -ItemType Directory -Force -Path $root | Out-Null
$env:CODEX_HOME = Join-Path $root 'isolated-codex'
$product = 'UseGoodAI中转快速接入助手'
# Intentionally invalid: the real import/queue/display path runs, but no API
# request or customer configuration write can succeed.
$link = 'usegoodai://import?v=1&app=codex&key=not-a-key&name=window-test'
$script:rows = New-Object 'System.Collections.Generic.List[object]'
$script:failures = New-Object 'System.Collections.Generic.List[string]'
$script:label = ''
$script:phase = ''
$script:lastState = ''
$script:phaseStart = Get-Date

function Helpers {
  @(Get-Process | Where-Object { $_.Path -and $_.Path.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) })
}
function Stop-Helpers {
  Helpers | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
  Start-Sleep -Seconds 2
}
function Snapshot {
  $ids = @(Helpers | ForEach-Object { $_.Id })
  $all = @([WindowTrace]::Windows())
  $windows = @($all | Where-Object { $_.pid -in $ids })
  $fg = @($all | Where-Object foreground | Select-Object cls, title, pid)
  $state = @{ pids=$ids; windows=$windows; foreground=$fg } | ConvertTo-Json -Depth 5 -Compress
  if ($state -ne $script:lastState) {
    $script:lastState = $state
    $row = [ordered]@{ label=$script:label; phase=$script:phase; seconds=[Math]::Round(((Get-Date)-$script:phaseStart).TotalSeconds,2); state=(ConvertFrom-Json $state) }
    $script:rows.Add($row)
    Write-Host ($row | ConvertTo-Json -Depth 7 -Compress)
  }
}
function Save-Screen([string]$Name) {
  $bounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
  $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $bitmap.Save((Join-Path $root "$script:label-$Name.png"))
  } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Begin-Phase([string]$Name) {
  $script:phase = $Name
  $script:phaseStart = Get-Date
  $script:lastState = ''
}
function Watch-UI([int]$Seconds = 15) {
  $deadline = (Get-Date).AddSeconds($Seconds)
  $shot = $false
  while ((Get-Date) -lt $deadline) {
    [System.Windows.Forms.Application]::DoEvents()
    Snapshot
    if (-not $shot -and ((Get-Date)-$script:phaseStart).TotalSeconds -ge 1) {
      Save-Screen "$script:phase-1s"
      $shot = $true
    }
    Start-Sleep -Milliseconds 100
  }
  Save-Screen "$script:phase-final"
  $ids = @(Helpers | ForEach-Object { $_.Id })
  $visible = @([WindowTrace]::Windows() | Where-Object {
    $_.pid -in $ids -and $_.title -eq $product -and $_.visible -and -not $_.minimized -and $_.cloaked -eq 0 -and $_.right -gt $_.left
  })
  if ($visible.Count -ne 1) {
    $script:failures.Add("$script:label/$script:phase : $($ids.Count) helper processes, $($visible.Count) visible main windows")
  }
}

# A foreground page is present while the shell invokes the registered URL
# handler. This reproduces foreground contention without browser prompts.
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Browser foreground simulation'
$form.Width = 1000; $form.Height = 760
$form.Show()
function Browser-ToFront {
  $form.Activate()
  [void][WindowTrace]::SetForegroundWindow($form.Handle)
  [System.Windows.Forms.Application]::DoEvents()
}

try {
  foreach ($file in Get-ChildItem -LiteralPath $Folder -Filter 'helper-*.exe' | Sort-Object Name) {
    $script:label = $file.BaseName
    $dir = Join-Path $root $script:label
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $exe = Join-Path $dir "1.$product.exe"
    Copy-Item -LiteralPath $file.FullName -Destination $exe -Force
    Stop-Helpers
    Begin-Phase 'double-click'
    Start-Process -FilePath $exe
    Watch-UI
    $command = (Get-Item 'Registry::HKEY_CURRENT_USER\Software\Classes\usegoodai\shell\open\command').GetValue('')
    if ($command -ne ('"' + $exe + '" "%1"')) { throw "The tested executable did not register itself" }

    Begin-Phase 'protocol-running'
    Browser-ToFront
    Start-Process -FilePath $link
    Watch-UI

    Begin-Phase 'protocol-minimized'
    $ids = @(Helpers | ForEach-Object { $_.Id })
    foreach ($window in [WindowTrace]::Windows() | Where-Object { $_.pid -in $ids -and $_.title -eq $product }) {
      [void][WindowTrace]::ShowWindowAsync([IntPtr]$window.hwnd, 6)
    }
    Browser-ToFront
    Start-Process -FilePath $link
    Watch-UI

    Stop-Helpers
    Begin-Phase 'protocol-cold'
    Browser-ToFront
    Start-Process -FilePath $link
    Watch-UI

    Begin-Phase 'protocol-burst'
    Browser-ToFront
    1..3 | ForEach-Object { Start-Process -FilePath $link; Start-Sleep -Milliseconds 100 }
    Watch-UI 20
    Stop-Helpers
  }
} finally {
  Stop-Helpers
  $form.Dispose()
  $script:rows | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $root 'windows.json') -Encoding UTF8
  $script:failures | Set-Content -LiteralPath (Join-Path $root 'failures.txt') -Encoding UTF8
  $startup = Join-Path $env:LOCALAPPDATA 'UseGoodAI\QuickConnect\startup.log'
  if (Test-Path -LiteralPath $startup) { Copy-Item -LiteralPath $startup -Destination $root }
}
if ($script:failures.Count) { throw ($script:failures -join "`n") }
