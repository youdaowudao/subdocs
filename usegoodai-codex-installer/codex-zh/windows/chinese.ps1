#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw '此命令用于 Windows 上的微软商店版 Codex 桌面应用。'
}

. (Join-Path $PSScriptRoot 'desktop.ps1')
. (Join-Path $PSScriptRoot 'config.ps1')
. (Join-Path $PSScriptRoot 'core.ps1')

$runLock = [Threading.Mutex]::new($false, 'Local\UseGoodAI-Codex-Chinese')
$locked = $false
$debugProcessId = 0
$canReopen = $false
$localeSaved = $false
$repairFailed = $false
try {
    try { $locked = $runLock.WaitOne(0) } catch [Threading.AbandonedMutexException] { $locked = $true }
    if (-not $locked) { throw 'Codex 中文化命令已经在运行。' }

    $desktop = Get-OfficialCodexDesktop
    Add-AppActivationInterop
    $codexHome = [Environment]::GetEnvironmentVariable('CODEX_HOME', 'User')
    if (-not $codexHome) { $codexHome = [Environment]::GetEnvironmentVariable('CODEX_HOME', 'Machine') }
    if (-not $codexHome) { $codexHome = Join-Path $env:USERPROFILE '.codex' }
    $configPath = Join-Path ([IO.Path]::GetFullPath($codexHome)) 'config.toml'
    $null = Get-CodexLocaleEdit $configPath

    Close-ExistingCodexDesktop $desktop
    $canReopen = $true
    if (@(Get-CodexDesktopProcesses $desktop).Count) {
        throw 'Codex 已被其他程序打开。请退出 Codex，若 CC Switch 自动打开它，先退出 CC Switch 再重试。'
    }

    Save-CodexLocaleEdit (Get-CodexLocaleEdit $configPath)
    $localeSaved = $true
    $port = Get-CodexLoopbackPort
    if (@(Get-CodexDesktopProcesses $desktop).Count) {
        throw 'Codex 已被其他程序打开，已停止调试启动。'
    }
    $debugProcessId = Start-OfficialCodexDesktop $desktop "--remote-debugging-port=$port --remote-allow-origins=http://127.0.0.1:$port"
    Enable-CodexLanguageCache $desktop $debugProcessId $port
} catch {
    $repairFailed = $true
    if ($localeSaved) {
        Write-Warning '简体中文偏好已保存。语言缓存没有通过验证。'
    }
    throw
} finally {
    try {
        if ($debugProcessId) { Stop-StartedDebugProcess $desktop $debugProcessId $port }
        if ($canReopen -and @(Get-CodexDesktopProcesses $desktop).Count -eq 0) {
            $null = Start-OfficialCodexDesktop $desktop
        }
    } catch {
        if (-not $repairFailed) { throw }
        Write-Warning ('清理或正常重开 Codex 时出错：' + $_.Exception.Message)
    } finally {
        if ($locked) { $runLock.ReleaseMutex() }
        $runLock.Dispose()
    }
}

Write-Host '已启用语言开关并设置简体中文。请查看重新打开的 Codex 菜单。'
