# 原生助手窗口升级：真实点击按钮并核对实际文件；不使用真实 Key 或付费接口。
param([Parameter(Mandatory=$true)][string]$Exe)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Windows.Forms, System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ImageUpgradeMouse {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
}
'@
$Repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$Work = Join-Path $env:RUNNER_TEMP 'image-upgrade-window'
New-Item -ItemType Directory -Force $Work | Out-Null
$Candidate = (Get-Content -LiteralPath (Join-Path $Repo 'docs/public/install/usegoodai-imagines-tool/latest.json') -Raw | ConvertFrom-Json).version
$Previous = Join-Path $Repo 'docs/public/install/usegoodai-imagines-tool/releases/v0.9.3/usegoodai-imagines-tool-v0.9.3-windows-amd64.exe'
$OriginalHome = $env:CODEX_HOME
$OriginalBrowserArguments = $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS
$env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = '--force-renderer-accessibility'
$ImageExe = (Resolve-Path $Exe).Path
$Results = @()

function Find-Text($Root, [string]$Text) {
  $condition = New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::NameProperty), $Text
  return $Root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
}
function Wait-Text($Root, [string]$Text) {
  $deadline = (Get-Date).AddSeconds(45)
  while ((Get-Date) -lt $deadline) {
    $element = Find-Text $Root $Text
    if ($null -ne $element) { return $element }
    Start-Sleep -Milliseconds 250
  }
  Screen 'failed'
  $Root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition) |
    ForEach-Object { $_.Current.Name } | Set-Content -LiteralPath (Join-Path $Work 'failed-ui-names.txt') -Encoding UTF8
  throw "窗口未显示：$Text"
}
function Click($Element) {
  # Bring the real window forward before pointer input. A WebView text
  # provider's Invoke action can merely focus the parent on Server 2025.
  [ImageUpgradeMouse]::SetForegroundWindow($process.MainWindowHandle) | Out-Null
  Start-Sleep -Milliseconds 250
  $bounds = $Element.Current.BoundingRectangle
  if ($bounds.IsEmpty) { throw '控件无可点击位置' }
  Write-Host "点击实际窗口：$($Element.Current.Name)"
  [ImageUpgradeMouse]::SetCursorPos([int]($bounds.X+$bounds.Width/2), [int]($bounds.Y+$bounds.Height/2)) | Out-Null
  Start-Sleep -Milliseconds 100
  [ImageUpgradeMouse]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
  Start-Sleep -Milliseconds 100
  [ImageUpgradeMouse]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
}
function Screen([string]$Name) {
  $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.CopyFromScreen($bounds.Location,[System.Drawing.Point]::Empty,$bounds.Size)
    $bitmap.Save((Join-Path $Work "$Name.png"))
  } finally { $graphics.Dispose(); $bitmap.Dispose() }
}

try {
  foreach ($KeyState in @('saved','missing')) {
    $env:CODEX_HOME = Join-Path $Work "中文 空格 $KeyState"
    'synthetic-image-key' | & $Previous install --key-stdin | Out-Null
    if ($LASTEXITCODE -ne 0) { throw '旧版本安装失败' }
    $Tool = Join-Path $env:CODEX_HOME 'tools/usegoodai-imagines-tool'
    $KeyPath = Join-Path $Tool 'api-key'
    if ($KeyState -eq 'missing') { Remove-Item -LiteralPath $KeyPath }
    $Before = if (Test-Path -LiteralPath $KeyPath) { [IO.File]::ReadAllText($KeyPath) } else { $null }
    $process = Start-Process -FilePath $ImageExe -PassThru
    try {
      $deadline = (Get-Date).AddSeconds(45)
      do {
        Start-Sleep -Milliseconds 250
        $process.Refresh()
        if ($process.HasExited) { throw '助手未打开窗口就退出' }
      } until ($process.MainWindowHandle -ne [IntPtr]::Zero -or (Get-Date) -gt $deadline)
      if ($process.MainWindowHandle -eq [IntPtr]::Zero) { throw '助手窗口超时' }
      $window = [System.Windows.Automation.AutomationElement]::FromHandle($process.MainWindowHandle)
      Click (Wait-Text $window '生图工具（可更新）')
      $title = "V0.9.3 已安装，可更新到 V$Candidate"
      if ($KeyState -eq 'missing') { $title += '，尚未配置 Key' }
      Wait-Text $window $title | Out-Null
      Screen "before-$KeyState"
      Click (Wait-Text $window "一键更新到 V$Candidate")
      $deadline = (Get-Date).AddSeconds(45)
      do {
        Start-Sleep -Milliseconds 250
        $version = (Get-Content -LiteralPath (Join-Path $Tool 'install-manifest.json') -Raw | ConvertFrom-Json).version
      } until ($version -eq $Candidate -or (Get-Date) -gt $deadline)
      if ($version -ne $Candidate) { throw '点击更新后实际安装版本未更新' }
      $After = if (Test-Path -LiteralPath $KeyPath) { [IO.File]::ReadAllText($KeyPath) } else { $null }
      if ($Before -cne $After) { throw '升级修改或新增了密钥' }
      Screen "after-$KeyState"
      $Results += @{ key=$KeyState; old_version_display='passed'; clicked_upgrade_button='passed'; actual_version=$version; key_preserved='passed' }
    } finally {
      if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
      Start-Sleep -Seconds 2
    }
  }
  @{ version='1.0.0'; candidate=$Candidate; scope='实际 Windows 助手窗口及内置程序；临时假 Key，无真实鉴权'; results=$Results } |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $Work 'report.json') -Encoding UTF8
} finally {
  $env:CODEX_HOME = $OriginalHome
  $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = $OriginalBrowserArguments
}
