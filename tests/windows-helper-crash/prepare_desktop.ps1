# Only for disposable GitHub-hosted Win11 ARM VMs. No software is installed.
# Their first-login privacy desktop can obscure every application while
# IsWindowVisible still returns true (actions/runner-images#14069).
$ErrorActionPreference = 'Stop'
$work = Join-Path $env:RUNNER_TEMP 'helper-desktop-check'
New-Item -ItemType Directory -Force -Path $work | Out-Null
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

function Save-Desktop([string]$Name) {
  $bounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
  $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $bitmap.Save((Join-Path $work "$Name.png"))
  } finally { $graphics.Dispose(); $bitmap.Dispose() }
}

Save-Desktop 'before'
$policy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE'
New-Item -Path $policy -Force | Out-Null
New-ItemProperty -Path $policy -Name DisablePrivacyExperience -PropertyType DWord -Value 1 -Force | Out-Null
Get-Process -Name CloudExperienceHostBroker, UserOOBEBroker -ErrorAction SilentlyContinue |
  Stop-Process -Force -ErrorAction SilentlyContinue
if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
Start-Sleep -Seconds 3

# WinAppDriver is already present in the hosted image. Its desktop session
# can send input to the first-login UI when normal SendKeys cannot.
# API: https://github.com/microsoft/WinAppDriver/blob/master/Docs/SupportedAPIs.md
$driver = $null
$sessionId = $null
$base = 'http://127.0.0.1:4723'
try {
  try { $null = Invoke-RestMethod "$base/status" -TimeoutSec 2 } catch {
    $path = Join-Path ${env:ProgramFiles(x86)} 'Windows Application Driver\WinAppDriver.exe'
    if (-not (Test-Path -LiteralPath $path)) { throw 'The hosted image has no preinstalled WinAppDriver.' }
    $driver = Start-Process -FilePath $path -WindowStyle Hidden -PassThru `
      -RedirectStandardOutput (Join-Path $work 'driver.log') -RedirectStandardError (Join-Path $work 'driver-error.log')
    Start-Sleep -Seconds 3
  }
  $created = Invoke-RestMethod "$base/session" -Method Post -ContentType 'application/json' `
    -Body '{"desiredCapabilities":{"app":"Root","platformName":"Windows"}}' -TimeoutSec 15
  $sessionId = $created.sessionId
  if (-not $sessionId) { $sessionId = $created.value.sessionId }
  if (-not $sessionId) { throw 'WinAppDriver did not create a desktop session.' }
  $source = Invoke-RestMethod "$base/session/$sessionId/source" -TimeoutSec 10
  $source.value | Set-Content -LiteralPath (Join-Path $work 'before-source.xml') -Encoding UTF8
  foreach ($code in @(0xE007, 0xE007, 0xE00C)) {
    $body = @{ value=@([string][char]$code) } | ConvertTo-Json -Compress
    $null = Invoke-RestMethod "$base/session/$sessionId/keys" -Method Post -ContentType 'application/json; charset=utf-8' `
      -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 10
    Start-Sleep -Seconds 3
    Save-Desktop ("after-key-{0:x}" -f $code)
  }
  $source = Invoke-RestMethod "$base/session/$sessionId/source" -TimeoutSec 10
  $source.value | Set-Content -LiteralPath (Join-Path $work 'after-source.xml') -Encoding UTF8
} catch {
  Write-Warning "Desktop preparation: $($_.Exception.Message)"
} finally {
  if ($sessionId) {
    try { $null = Invoke-RestMethod "$base/session/$sessionId" -Method Delete -TimeoutSec 5 } catch {}
  }
  if ($driver) { Stop-Process -Id $driver.Id -Force -ErrorAction SilentlyContinue }
}
Get-Process -Name explorer, winlogon, WWAHost, CloudExperienceHostBroker, UserOOBEBroker -ErrorAction SilentlyContinue |
  Select-Object Id, ProcessName, SessionId, MainWindowTitle
query session
Save-Desktop 'after'
# window_trace.ps1 independently verifies that its foreground test window
# can really activate. Preparation failure must never become a GUI pass.
