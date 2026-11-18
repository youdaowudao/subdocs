param([Parameter(Mandatory=$true)][string]$Exe)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class UpdateWindowMouse {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(int flags, int x, int y, int data, UIntPtr extra);
}
'@

$program = (Resolve-Path -LiteralPath $Exe).Path
$manifestPath = [IO.Path]::ChangeExtension($program, '.json')
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$work = Join-Path $env:RUNNER_TEMP 'assistant-update-window'
$serve = Join-Path $work 'download'
$appData = Join-Path $work 'AppData'
$codex = Join-Path $work 'Codex'
New-Item -ItemType Directory -Force $serve,$appData,$codex | Out-Null
$launcher = Join-Path $work 'old-launcher.exe'
$cache = Join-Path $appData 'UseGoodAI/QuickConnect/updates'
$newExe = Join-Path $cache "$($manifest.version)-$($manifest.sha256).exe"
$active = Join-Path $cache 'active.json'
$download = Join-Path $serve ([IO.Path]::GetFileName($program))
$originalLocalAppData = $env:LOCALAPPDATA
$originalCodexHome = $env:CODEX_HOME
$originalBrowser = $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS
$auth = Join-Path $codex 'auth.json'
[IO.File]::WriteAllText($auth, '{"OPENAI_API_KEY":"synthetic-codex-key"}')
$authHash = (Get-FileHash -LiteralPath $auth).Hash

function Wait-For([scriptblock]$Condition, [string]$Description) {
  $deadline = (Get-Date).AddSeconds(90)
  while ((Get-Date) -lt $deadline) {
    if (& $Condition) { return }
    Start-Sleep -Milliseconds 200
  }
  throw "测试超时：$Description"
}

function Window-Process([string]$ProgramPath) {
  Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -ieq $ProgramPath -and $_.MainWindowHandle -ne [IntPtr]::Zero } |
    Select-Object -First 1
}

function Find-Text($Process, [string]$Name) {
  if (-not $Process) { return }
  $window = [System.Windows.Automation.AutomationElement]::FromHandle($Process.MainWindowHandle)
  $condition = New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::NameProperty), $Name
  $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
}

function Click-Text($Process, [string]$Name) {
  $button = Find-Text $Process $Name
  if (-not $button -or $button.Current.BoundingRectangle.IsEmpty) { throw "未找到按钮：$Name" }
  [UpdateWindowMouse]::SetForegroundWindow($Process.MainWindowHandle) | Out-Null
  Start-Sleep -Milliseconds 200
  $bounds = $button.Current.BoundingRectangle
  [UpdateWindowMouse]::SetCursorPos([int]($bounds.X + $bounds.Width/2), [int]($bounds.Y + $bounds.Height/2)) | Out-Null
  Start-Sleep -Milliseconds 100
  [UpdateWindowMouse]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
  Start-Sleep -Milliseconds 100
  [UpdateWindowMouse]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
}

$server = $null
try {
  # Compile the current updater as an older launcher and point only that
  # fixture at loopback. What it installs is the actual release EXE.
  $source = (Resolve-Path -LiteralPath 'connect/product.go').Path
  $oldProduct = Join-Path $work 'product.go'
  $overlay = Join-Path $work 'overlay.json'
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  $oldSource = [regex]::Replace([IO.File]::ReadAllText($source), '(?m)^(\s*Version\s*=\s*)"[^"]+"', '${1}"1.1.22"')
  [IO.File]::WriteAllText($oldProduct, $oldSource, $utf8)
  [IO.File]::WriteAllText($overlay, (@{Replace = @{$source = $oldProduct}} | ConvertTo-Json), $utf8)
  go build -overlay $overlay -tags desktop,production,wv2runtime.browser -ldflags '-H windowsgui -X main.assistantUpdateDownloadURL=http://127.0.0.1:19473/' -o $launcher .
  if ($LASTEXITCODE -ne 0) { throw '旧版启动器夹具构建失败' }

  Copy-Item -LiteralPath $manifestPath -Destination $serve
  $bytes = [IO.File]::ReadAllBytes($program)
  $bytes[0] = $bytes[0] -bxor 1
  [IO.File]::WriteAllBytes($download, $bytes)
  $server = Start-Process -FilePath 'python' -ArgumentList @('-m','http.server','19473','--bind','127.0.0.1','--directory',"`"$serve`"") -PassThru
  Wait-For {
    try {
      (Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 -Uri "http://127.0.0.1:19473/$([IO.Path]::GetFileName($manifestPath))").StatusCode -eq 200
    } catch { $false }
  } '模拟下载站启动'

  $env:LOCALAPPDATA = $appData
  $env:CODEX_HOME = $codex
  $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = '--force-renderer-accessibility'
  Start-Process -FilePath $launcher
  Wait-For { Find-Text (Window-Process $launcher) '更新并重启' } '助手启动时提示有新版'
  Click-Text (Window-Process $launcher) '更新并重启'
  Wait-For { Find-Text (Window-Process $launcher) '重试更新' } '校验失败后旧窗口仍可用'
  if ((Test-Path -LiteralPath $newExe) -or (Test-Path -LiteralPath $active)) { throw '损坏的更新已被缓存或激活' }

  Copy-Item -LiteralPath $program -Destination $download -Force
  Click-Text (Window-Process $launcher) '重试更新'
  Wait-For { (Test-Path -LiteralPath $active) -and (Window-Process $newExe) } '新版助手完成重启'
  if ((Get-FileHash -LiteralPath $newExe).Hash -ine $manifest.sha256) { throw '更新后的 EXE 哈希不符' }
  if ((Get-Content -LiteralPath $active -Raw | ConvertFrom-Json).version -ne $manifest.version) { throw '未激活新版' }
  if (Window-Process $launcher) { throw '旧窗口在更新后仍然存在' }
  (Window-Process $newExe).CloseMainWindow() | Out-Null
  Wait-For { -not (Window-Process $newExe) } '关闭新版窗口'
  Start-Process -FilePath $launcher
  Wait-For { Window-Process $newExe } '再次打开原 EXE 仍进入新版'
  if ((Get-FileHash -LiteralPath $auth).Hash -ne $authHash) { throw '助手更新改写了 Codex 凭据' }
  @{version=$manifest.version; checked_on_start=$true; rejects_corruption=$true; opens_new_version=$true; old_launcher_opens_new_version=$true; codex_auth_preserved=$true; sha256=$manifest.sha256} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $work 'report.json') -Encoding UTF8
} finally {
  if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force }
  Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -iin @($launcher, $newExe) } |
    Stop-Process -Force -ErrorAction SilentlyContinue
  $env:LOCALAPPDATA = $originalLocalAppData
  $env:CODEX_HOME = $originalCodexHome
  $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = $originalBrowser
}
