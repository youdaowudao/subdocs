param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$ReportDir,
    [ValidateSet('10', '11')][string]$WindowsVersion = '11'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Windows.Forms, System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ChineseUIInput {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern void keybd_event(byte key,byte scan,int flags,UIntPtr extra);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
    [DllImport("user32.dll")] public static extern void mouse_event(int flags,int x,int y,int data,UIntPtr extra);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hwnd,int msg,IntPtr w,IntPtr l);
}
'@
$null = New-Item -ItemType Directory -Force $ReportDir
$os = Get-CimInstance Win32_OperatingSystem
if ($os.ProductType -ne 1 -or $os.Caption -notmatch ("Windows " + $WindowsVersion + '\b')) { throw 'This test requires the requested Windows desktop OS.' }
$exePath = (Resolve-Path -LiteralPath $Exe).Path
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$work = Join-Path $env:TEMP 'UseGoodAI中文化 UI 测试'
$null = New-Item -ItemType Directory -Force $work
$copy = Join-Path $work '接入助手.exe'
Copy-Item -LiteralPath $exePath -Destination $copy -Force
$report = [ordered]@{ os = $os.Caption; build = $os.BuildNumber; architecture = $env:PROCESSOR_ARCHITECTURE; powershell = $PSVersionTable.PSVersion.ToString(); exeSha256 = (Get-FileHash $copy).Hash; version = (Get-Item $copy).VersionInfo.ProductVersion; cases = @(); failures = @() }
$path = Join-Path $ReportDir 'report.json'
function Save-Report { $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $path -Encoding UTF8 }
function Require($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Wait-Until([scriptblock]$Condition, [int]$Seconds) {
    $until = [DateTime]::UtcNow.AddSeconds($Seconds)
    do { $value = & $Condition; if ($value) { return $value }; Start-Sleep -Milliseconds 200 } while ([DateTime]::UtcNow -lt $until)
    throw 'Timed out waiting for the UI test condition.'
}
function Read-Record([string]$File) {
    if (-not $File -or -not (Test-Path -LiteralPath $File)) { return '' }
    $stream = New-Object IO.FileStream($File, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::UTF8, $true)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}
function Save-Screen([string]$Name) {
    $bounds = [Windows.Forms.SystemInformation]::VirtualScreen
    $bitmap = New-Object Drawing.Bitmap($bounds.Width, $bounds.Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.Size); $bitmap.Save((Join-Path $ReportDir ($Name + '.png'))) }
    finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Find-Text([string]$Text) {
    $condition = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::NameProperty, $Text)
    return $window.FindFirst([Windows.Automation.TreeScope]::Descendants, $condition)
}
function Chinese-Button { Find-Text '一键中文化（没有梯子才需要）' }
function Worker {
    @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.ParentProcessId -eq $assistant.Id -and $_.CommandLine -match 'chinese-tool.*run\.ps1' }) | Select-Object -First 1
}
function Console-Window {
    [Windows.Automation.AutomationElement]::RootElement.FindAll([Windows.Automation.TreeScope]::Children, [Windows.Automation.Condition]::TrueCondition) |
        Where-Object { $_.Current.Name -like '*UseGoodAI 一键中文化*' -and -not $_.Current.IsOffscreen } | Select-Object -First 1
}
function Click-Chinese {
    $button = Wait-Until { Chinese-Button } 15
    Require $button.Current.IsEnabled 'Chinese button is disabled before a run.'
    [ChineseUIInput]::SetForegroundWindow($assistant.MainWindowHandle) | Out-Null
    $button.SetFocus()
    $bounds = $button.Current.BoundingRectangle
    Require (-not $button.Current.IsOffscreen -and $bounds.Width -gt 0) 'Chinese button has no visible clickable area.'
    [ChineseUIInput]::SetCursorPos([int]($bounds.X+$bounds.Width/2),[int]($bounds.Y+$bounds.Height/2)) | Out-Null
    [ChineseUIInput]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
    [ChineseUIInput]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
    # An immediate second invocation must be ignored/disabled, without clicking
    # the newly foregrounded console and accidentally selecting its text.
    try { $button.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke() } catch { }
}

# Reuse the existing desktop test's activation and download helpers only,
# without running its already-passed core matrix.
$coreTest = [IO.File]::ReadAllText((Join-Path $repo 'tests/codex-chinese-desktop.ps1'), [Text.Encoding]::UTF8)
$type = [regex]::Match($coreTest, "(?s)Add-Type -TypeDefinition @'\r?\n(.*?)\r?\n'@")
Add-Type -TypeDefinition $type.Groups[1].Value
$ast = [Management.Automation.Language.Parser]::ParseInput($coreTest, [ref]$null, [ref]$null)
foreach ($name in @('Get-CodexProcesses','Get-CodexMain','Start-Codex','Complete-PrivacyScreen')) {
    $function = $ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $false) | Select-Object -First 1
    Invoke-Expression $function.Extent.Text
}
function Install-OfficialApp {
    if (-not (Get-AppxPackage -Name OpenAI.Codex)) {
        $architecture = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
        $packageFile = Join-Path $work 'ChatGPT.msix'
        $downloaded = $false
        foreach ($file in @("ChatGPT-$architecture.msix", 'ChatGPT.msix')) {
            & curl.exe -fsSL --connect-timeout 20 --max-time 400 ("https://persistent.oaistatic.com/codex-app-prod/"+$file) -o $packageFile
            if ($LASTEXITCODE -eq 0) { $downloaded = $true; break }
        }
        Require $downloaded 'Official ChatGPT package download did not complete.'
        $signature = Get-AuthenticodeSignature -LiteralPath $packageFile
        Require ($signature.Status -eq 'Valid') 'Official package signature is not valid.'
        Add-AppxPackage -Path $packageFile
        $report.packageSha256 = (Get-FileHash $packageFile).Hash
    }
    $package = Get-AppxPackage -Name OpenAI.Codex | Sort-Object Version -Descending | Select-Object -First 1
    [xml]$manifest = Get-Content -LiteralPath (Join-Path $package.InstallLocation 'AppxManifest.xml') -Raw
    $app = @($manifest.Package.Applications.Application) | Where-Object Id -EQ 'App' | Select-Object -First 1
    $script:codex = @{ Aumid = "$($package.PackageFamilyName)!App"; Exe = (Join-Path $package.InstallLocation $app.Executable.Replace('/','\')) }
    $report.chatgpt = @{ package = $package.PackageFullName; version = $package.Version.ToString(); minimumOS = [string]$manifest.Package.Dependencies.TargetDeviceFamily.MinVersion }
    Save-Report
}
function Run-Case([string]$Name, [bool]$Success, [bool]$CloseEarly = $false) {
    $before = @((Get-ChildItem -LiteralPath $logDir -Filter '中文化_*.txt' -ErrorAction SilentlyContinue).FullName)
    $script:stage = $Name + ': click'
    Write-Host $script:stage
    $watch = [Diagnostics.Stopwatch]::StartNew()
    Click-Chinese
    $worker = Wait-Until { Worker } 20
    $script:stage = $Name + ': visible console'
    $console = Wait-Until { Console-Window } 45
    $process = Get-Process -Id $worker.ProcessId
    $log = Wait-Until { Get-ChildItem -LiteralPath $logDir -Filter '中文化_*.txt' | Where-Object FullName -NotIn $before | Select-Object -First 1 } 15
    Require ((@(Worker)).Count -eq 1) 'Repeated clicking started more than one worker.'
    $running = Find-Text '正在中文化…'
    Require ($running -and -not $running.Current.IsEnabled) 'Chinese action must stay disabled while its console runs.'
    $script:stage = $Name + ': result'
    $firstCountdown = $null
    $end = [DateTime]::UtcNow.AddSeconds(190)
    do {
        $text = Read-Record $log.FullName
        if ($text -match '已完成，5 秒后自动关闭') { $firstCountdown = $watch.Elapsed.TotalSeconds; break }
        if (-not $Success -and $text -match '\[失败\]') { break }
        Start-Sleep -Milliseconds 200
    } until ($process.HasExited -or [DateTime]::UtcNow -gt $end)
    Save-Screen ($Name+'-console')
    if ($Success) {
        Require ($null -ne $firstCountdown -and -not $process.HasExited) 'Success did not leave a visible five-second countdown.'
        if ($CloseEarly) {
            [ChineseUIInput]::PostMessage([IntPtr]$console.Current.NativeWindowHandle, 16, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
        }
        Require ($process.WaitForExit(12000)) 'Successful console did not close.'
        $final = Read-Record $log.FullName
        if (-not $CloseEarly) {
            Require (($watch.Elapsed.TotalSeconds-$firstCountdown) -ge 4 -and ($watch.Elapsed.TotalSeconds-$firstCountdown) -lt 10) 'Countdown closure did not take about five seconds.'
            Require (([regex]::Matches($final, '已完成，[1-5] 秒后自动关闭')).Count -eq 5) 'Countdown record is incomplete.'
        }
        Require ($final -match '\[成功\]' -and $final -notmatch '\[失败\]') 'Actual operation failed.'
    } else {
        Start-Sleep -Seconds 7
        Require (-not $process.HasExited) 'Failure console closed automatically.'
        Require ((Read-Record $log.FullName) -notmatch '已完成，5 秒后') 'Failure was treated as success.'
        $script:stage = $Name + ': close retained console'
        $consoleHandle = [IntPtr]$console.Current.NativeWindowHandle
        [ChineseUIInput]::SetForegroundWindow($consoleHandle) | Out-Null
        # Native title-bar click focuses the target before sending Enter.
        # SendKeys immediately after SetForegroundWindow can hit the driver.
        $bounds = $console.Current.BoundingRectangle
        [ChineseUIInput]::SetCursorPos([int]($bounds.X+$bounds.Width/2),[int]($bounds.Y+12)) | Out-Null
        [ChineseUIInput]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
        [ChineseUIInput]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
        $null = Wait-Until { [ChineseUIInput]::GetForegroundWindow() -eq $consoleHandle } 5
        Start-Sleep -Milliseconds 300
        [ChineseUIInput]::keybd_event(13,0,0,[UIntPtr]::Zero)
        [ChineseUIInput]::keybd_event(13,0,2,[UIntPtr]::Zero)
        Require ($process.WaitForExit(15000)) 'Failure console did not respond to Enter.'
    }
    $null = Wait-Until { $button = Chinese-Button; $button -and $button.Current.IsEnabled } 15
    if ($Success -and -not $CloseEarly) {
        $null = Wait-Until { Find-Text ("中文设置已完成，请自己重新打开 ChatGPT。运行记录："+$log.FullName) } 15
    }
    Require (-not $assistant.HasExited) 'Assistant closed with its PowerShell window.'
    if ($Success) {
        Require (-not (Get-CodexProcesses)) 'ChatGPT was left running after the button completed.'
        Require (-not (Get-NetTCPConnection -State Listen -LocalPort 9240 -ErrorAction SilentlyContinue)) 'Debug port was left listening.'
    }
    $destination = Join-Path $ReportDir ($Name+'.txt')
    Copy-Item -LiteralPath $log.FullName -Destination $destination
    $report.cases += @{ name = $Name; seconds = [Math]::Round($watch.Elapsed.TotalSeconds,2); expectedSuccess = $Success; workerExit = $process.ExitCode; visibleConsole = $true; record = (Split-Path $destination -Leaf); passed = $true }
    Save-Report
}

$originalAccessibility = $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS
$assistant = $null
$launched = $null
$logDir = Join-Path $env:LOCALAPPDATA 'UseGoodAI/QuickConnect/logs'
try {
    Complete-PrivacyScreen
    $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = '--force-renderer-accessibility'
    $launched = Start-Process -FilePath $copy -PassThru
    $assistant = Wait-Until { Get-Process | Where-Object { $_.Path -ieq $copy -and $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1 } 90
    $window = [Windows.Automation.AutomationElement]::FromHandle($assistant.MainWindowHandle)
    $button = Wait-Until { Chinese-Button } 25
    $models = Find-Text '导入国产模型'
    Require ($models -and $button.Current.BoundingRectangle.Top -ge $models.Current.BoundingRectangle.Bottom) 'Chinese entry is not below the two tools.'
    Save-Screen 'entry'
    if (-not (Get-AppxPackage -Name OpenAI.Codex)) { Run-Case 'missing-app' $false }
    Install-OfficialApp
    $null = Start-Codex
    Start-Sleep -Seconds 5
    Run-Case 'app-open' $true
    Run-Case 'repeat' $true
    Run-Case 'app-closed' $true
    Run-Case 'manual-console-close' $true $true
    $unpacked = Join-Path $env:LOCALAPPDATA 'UseGoodAI/QuickConnect/chinese-tool/chinese.ps1'
    Require ((Get-FileHash $unpacked).Hash -eq (Get-FileHash (Join-Path $repo 'docs/public/install/chinese.ps1')).Hash) 'Bundled core bytes changed.'
    Save-Screen 'finished'
} catch {
    $report.failedStage = $script:stage
    $report.failures += $_.Exception.Message
    Save-Screen 'failure'
    Get-ChildItem -LiteralPath $logDir -Filter '中文化_*.txt' -ErrorAction SilentlyContinue | Copy-Item -Destination $ReportDir -Force
    throw
} finally {
    $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = $originalAccessibility
    Save-Report
    if ($assistant -and -not $assistant.HasExited) { $assistant.CloseMainWindow() | Out-Null }
}
