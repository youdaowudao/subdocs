param([Parameter(Mandatory=$true)][string]$Exe)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Windows.Forms, System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ModelImportMouse {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
}
'@

$exePath = (Resolve-Path -LiteralPath $Exe).Path
$source = Join-Path $PSScriptRoot '../../install/codex-models.ps1'
$work = Join-Path $env:RUNNER_TEMP 'models-import-window'
$homePath = Join-Path $work '用户 目录'
New-Item -ItemType Directory -Force $homePath | Out-Null
$originalHome = $env:CODEX_HOME
$originalArguments = $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS
$auth = '{"OPENAI_API_KEY":"sk-models-test-fixture"}'
$config = "model = `"gpt-6.1-sol`"`r`napproval_policy = `"never`"`r`n"
[IO.File]::WriteAllText((Join-Path $homePath 'config.toml'), $config)
[IO.File]::WriteAllText((Join-Path $homePath 'auth.json'), $auth)
$process = $null
$launched = $null

function Click-Text([string]$Text) {
  $condition = New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::NameProperty), $Text
  $deadline = (Get-Date).AddSeconds(25)
  do {
    $element = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
    if ($null -ne $element) {
      $bounds = $element.Current.BoundingRectangle
      if (-not $bounds.IsEmpty) {
        [ModelImportMouse]::SetForegroundWindow($process.MainWindowHandle) | Out-Null
        [ModelImportMouse]::SetCursorPos([int]($bounds.X+$bounds.Width/2), [int]($bounds.Y+$bounds.Height/2)) | Out-Null
        Start-Sleep -Milliseconds 100
        [ModelImportMouse]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
        [ModelImportMouse]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
        Write-Host "已点击 $Text"
        Start-Sleep -Milliseconds 250
        return
      }
    }
    Start-Sleep -Milliseconds 200
  } until ((Get-Date) -gt $deadline)
  throw "窗口没有显示：$Text"
}

try {
  $env:CODEX_HOME = $homePath
  $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = '--force-renderer-accessibility'
  $launched = Start-Process -FilePath $exePath -PassThru
  $deadline = (Get-Date).AddSeconds(90)
  do {
    Start-Sleep -Milliseconds 250
    $process = Get-Process -ErrorAction SilentlyContinue |
      Where-Object { $_.Path -ieq $exePath -and $_.MainWindowHandle -ne [IntPtr]::Zero } |
      Select-Object -First 1
  } until ($process -or (Get-Date) -gt $deadline)
  if (-not $process) { throw '助手窗口没有启动' }
  $window = [System.Windows.Automation.AutomationElement]::FromHandle($process.MainWindowHandle)
  Click-Text '导入国产模型'
  Click-Text '导入国产模型'
  Click-Text '确认导入（会关闭 Codex）'

  $catalogPath = Join-Path $homePath 'usegoodai-models.json'
  $manifestPath = Join-Path $homePath 'usegoodai-models.managed.json'
  $deadline = (Get-Date).AddSeconds(90)
  while ((-not (Test-Path -LiteralPath $manifestPath)) -and (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 250
  }
  $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  if (@($manifest).Count -ne 10) { throw '助手窗口没有完成 10 个国产模型的导入' }
  $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($id in @('gpt-6.2-sol','gpt-6.2-astra') + $manifest) {
    if (@($catalog.models | Where-Object { $_.slug -ceq $id -and $_.visibility -ceq 'list' }).Count -ne 1) {
      throw "导入后缺少或重复 $id"
    }
  }
  $afterConfig = [IO.File]::ReadAllText((Join-Path $homePath 'config.toml'))
  if (-not $afterConfig.Contains('model = "gpt-6.1-sol"') -or
      -not $afterConfig.Contains('approval_policy = "never"') -or -not $afterConfig.Contains('usegoodai-models.json')) {
    throw '导入未启用目录，或原设置发生变化'
  }
  if ([IO.File]::ReadAllText((Join-Path $homePath 'auth.json')) -cne $auth -or
      (Test-Path -LiteralPath (Join-Path $homePath 'models_cache.json'))) { throw '原凭据或缓存发生变化' }
  $unpacked = Join-Path $env:LOCALAPPDATA 'UseGoodAI/QuickConnect/models-tool/codex-models.ps1'
  if ((Get-FileHash -LiteralPath $unpacked).Hash -ne (Get-FileHash -LiteralPath $source).Hash) { throw 'EXE 解出的脚本与上层源码不一致' }
  $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.CopyFromScreen($bounds.Location,[System.Drawing.Point]::Empty,$bounds.Size)
    $bitmap.Save((Join-Path $work 'import-result.png'))
  } finally { $graphics.Dispose(); $bitmap.Dispose() }
  @{
    version = (Get-Item -LiteralPath $exePath).VersionInfo.ProductVersion
    system = [Environment]::OSVersion.VersionString
    embedded_script_sha256 = (Get-FileHash -LiteralPath $unpacked).Hash
    count = @($manifest).Count
    result = '原生窗口双击确认，执行内置脚本并写入 10 个国产模型和两个 GPT-6.2，原默认模型和 Key 保留'
  } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $work 'report.json') -Encoding UTF8
} finally {
  if ($process -and -not $process.HasExited) { Stop-Process -Id $process.Id -Force }
  if ($launched -and -not $launched.HasExited) { Stop-Process -Id $launched.Id -Force }
  $env:CODEX_HOME = $originalHome
  $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = $originalArguments
}
