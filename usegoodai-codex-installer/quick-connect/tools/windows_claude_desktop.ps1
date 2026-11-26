param([Parameter(Mandatory=$true)][ValidateSet('website','store')][string]$Channel)
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Use a disposable Windows desktop runner only.' }
$os = Get-CimInstance Win32_OperatingSystem
if ($os.ProductType -ne 1 -or $os.Caption -notmatch 'Windows 11') { throw 'Windows 11 desktop required.' }
$work = Join-Path $env:RUNNER_TEMP 'claude-desktop-test'
New-Item -ItemType Directory -Force $work | Out-Null
$report = [ordered]@{ channel = $Channel; os = $os.Caption; build = $os.BuildNumber; architecture = $env:PROCESSOR_ARCHITECTURE; assistantHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $env:QUICK_CONNECT_EXE).Hash; registered = $false; initialWindow = $false; releaseConfig = $false; processClosed = $false; reopened = $false; modelRequest = $false }
$package = $null
$gateway = $null
$oldGateway = $env:CLAUDE_TEST_LOCAL_GATEWAY

function Save-Report { $report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $work 'report.json') -Encoding UTF8 }
function Desktop-Processes {
  if (-not $package) { return }
  Get-Process -Name Claude -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($package.InstallLocation + '\', [StringComparison]::OrdinalIgnoreCase) }
}
function Wait-Desktop {
  $deadline = (Get-Date).AddSeconds(90)
  do {
    $window = Desktop-Processes | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if ($window) { return $window }
    Start-Sleep -Seconds 1
  } while ((Get-Date) -lt $deadline)
  throw 'No actual Claude desktop window appeared.'
}
function Open-Desktop {
  Start-Process explorer.exe -ArgumentList "shell:AppsFolder\$($package.PackageFamilyName)!$appId"
  Wait-Desktop
}
function Record-Files([string]$Label) {
  $roots = @((Join-Path $env:LOCALAPPDATA 'Claude-3p'), (Join-Path $env:LOCALAPPDATA 'Claude'), (Join-Path $env:LOCALAPPDATA ('Packages\' + $package.PackageFamilyName + '\LocalCache')))
  $files = foreach ($root in $roots) { if (Test-Path -LiteralPath $root) { Get-ChildItem -LiteralPath $root -Filter claude_desktop_config.json -Recurse -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName } }
  $report[$Label] = @($files)
  Save-Report
}
function Run-Go([string[]]$testArgs) {
  & go @testArgs
  if ($LASTEXITCODE -ne 0) { throw "Go test failed: $LASTEXITCODE" }
}
function Save-Window($Window, [string]$Label) {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  Add-Type -AssemblyName UIAutomationClient
  Add-Type -AssemblyName UIAutomationTypes
  $shell = New-Object -ComObject WScript.Shell
  [void]$shell.AppActivate($Window.Id)
  Start-Sleep -Seconds 2
  $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bitmap = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
    $bitmap.Save((Join-Path $work ($Label + '.png')), [System.Drawing.Imaging.ImageFormat]::Png)
  } finally { $graphics.Dispose(); $bitmap.Dispose() }
  try {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($Window.MainWindowHandle)
    $nodes = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
    $names = foreach ($node in $nodes) { $node.Current.Name }
    $names | Set-Content -LiteralPath (Join-Path $work ($Label + '-uia.txt')) -Encoding UTF8
  } catch { Write-Host "UI automation inspection unavailable: $($_.Exception.Message)" }
}

try {
  if ($Channel -eq 'store') {
    $family = 'AnthropicPBC.Claude_fnn82j28hfe8t'
    $name = 'AnthropicPBC.Claude'
    & winget install --id 9P6K58THS811 --source msstore --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw "Microsoft Store installation failed: $LASTEXITCODE" }
  } else {
    $family = 'Claude_pzs8sxrjxfjjc'
    $name = 'Claude'
    $installer = Join-Path $work 'Claude.msix'
    # Official Claude Desktop enterprise deployment link, ARM64.
    Invoke-WebRequest -UseBasicParsing -Uri 'https://claude.ai/api/desktop/win32/arm64/msix/latest/redirect' -OutFile $installer -TimeoutSec 300
    Add-AppxPackage -Path $installer
    Remove-Item -LiteralPath $installer
  }
  $package = Get-AppxPackage -Name $name | Where-Object { $_.PackageFamilyName -eq $family } | Sort-Object Version -Descending | Select-Object -First 1
  if (-not $package) { throw 'Official package was not registered for this user.' }
  $report.registered = $true
  $report.package = $package | Select-Object Name, PackageFamilyName, PackageFullName, Version, InstallLocation, Publisher
  $manifest = Get-AppxPackageManifest -Package $package.PackageFullName
  $appId = @($manifest.Package.Applications.Application)[0].Id
  if (-not $appId) { throw 'Cannot locate the real desktop activation entry.' }
  Record-Files 'beforeFirstOpen'
  Run-Go @('test','-count=1','-v','-run','^TestClaudeNative','./connect')
  Run-Go @('test','-count=1','-v','-timeout=4m','-run','^TestClaudeReleaseWritesBothConfigurations$','.')
  $report.releaseConfig = $true
  $window = Open-Desktop
  $report.initialWindow = $true
  Record-Files 'afterFirstOpen'
  Save-Window $window 'initial'

  # Use the actual current-user config only in this disposable runner; the
  # candidate's key checks go to the existing mock, then the app goes to loopback.
  $port = 19473
  $gatewayLog = Join-Path $work 'gateway.log'
  $gateway = Start-Process python -ArgumentList @('-u','tools/claude_gateway_fixture.py',"$port") -RedirectStandardOutput $gatewayLog -RedirectStandardError (Join-Path $work 'gateway-error.log') -PassThru -WindowStyle Hidden
  Start-Sleep -Seconds 2
  if ($gateway.HasExited) { throw 'Local mock gateway failed to start.' }
  $env:CLAUDE_TEST_LOCAL_GATEWAY = "http://127.0.0.1:$port"
  Run-Go @('test','-count=1','-v','-timeout=4m','-run','^TestClaudeReleaseActualDesktopProfile$','.')
  $report.actualProfile = $true
  if (@(Desktop-Processes).Count) { throw 'The real Claude desktop process was not closed by the candidate.' }
  $report.processClosed = $true
  $window = Open-Desktop
  $report.reopened = $true
  Record-Files 'afterReconnect'
  Save-Window $window 'reopened'

  # Attempt a real new chat using the focused Claude window, never typing into
  # another application. The local endpoint records whether it got a message.
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ClaudeForeground {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
}
'@
  $shell = New-Object -ComObject WScript.Shell
  [void]$shell.AppActivate($window.Id)
  [uint32]$foregroundPid = 0
  [void][ClaudeForeground]::GetWindowThreadProcessId([ClaudeForeground]::GetForegroundWindow(), [ref]$foregroundPid)
  if ($foregroundPid -ne $window.Id) { throw 'Claude did not become the foreground window.' }
  [System.Windows.Forms.SendKeys]::SendWait('^n')
  Start-Sleep -Seconds 2
  [void][ClaudeForeground]::GetWindowThreadProcessId([ClaudeForeground]::GetForegroundWindow(), [ref]$foregroundPid)
  if ($foregroundPid -ne $window.Id) { throw 'Claude lost foreground focus.' }
  [System.Windows.Forms.SendKeys]::SendWait('test')
  [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
  $deadline = (Get-Date).AddSeconds(45)
  do {
    if ((Test-Path -LiteralPath $gatewayLog) -and (Select-String -LiteralPath $gatewayLog -Pattern 'received local /v1/messages' -Quiet)) { $report.modelRequest = $true; break }
    Start-Sleep -Seconds 1
  } while ((Get-Date) -lt $deadline)
  Save-Window $window 'new-chat'
  if (-not $report.modelRequest) { throw 'A real new conversation with the local gateway could not be verified.' }
} catch {
  $report.error = $_.Exception.Message
  throw
} finally {
  Save-Report
  $env:CLAUDE_TEST_LOCAL_GATEWAY = $oldGateway
  Desktop-Processes | Stop-Process -Force -ErrorAction SilentlyContinue
  if ($gateway -and -not $gateway.HasExited) { Stop-Process -Id $gateway.Id -Force -ErrorAction SilentlyContinue }
  $installer = Join-Path $work 'Claude.msix'
  if (Test-Path -LiteralPath $installer) { Remove-Item -LiteralPath $installer -Force }
}
