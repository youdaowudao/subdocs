[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'UseGoodAI 一键中文化'
$logPath = $env:USEGOODAI_CHINESE_LOG
$scriptPath = $env:USEGOODAI_CHINESE_SCRIPT
$transcribing = $false
$caughtFailure = $false
$utf8 = New-Object Text.UTF8Encoding($false)

try {
    Start-Transcript -LiteralPath $logPath -Append -ErrorAction Stop | Out-Null
    $transcribing = $true
    # The released script is UTF-8 without a BOM, like irm | iex. Read it
    # explicitly as UTF-8 rather than changing its bytes for PowerShell 5.1.
    $original = [IO.File]::ReadAllText($scriptPath, [Text.Encoding]::UTF8)
    & ([scriptblock]::Create($original))
}
catch {
    $caughtFailure = $true
    Write-Host '[失败] 中文化未完成，请查看上方记录。' -ForegroundColor Red
}
finally {
    if ($transcribing) {
        try { Stop-Transcript -ErrorAction Stop | Out-Null }
        catch { $caughtFailure = $true }
    }
}

$lastResult = ''
try {
    foreach ($line in [IO.File]::ReadAllLines($logPath, [Text.Encoding]::UTF8)) {
        if ($line -match '^\[(成功|失败)\]') { $lastResult = $Matches[1] }
    }
}
catch { $caughtFailure = $true }

function Write-RunMessage([string]$Message, [ConsoleColor]$Color = [ConsoleColor]::Gray) {
    Write-Host $Message -ForegroundColor $Color
    try { [IO.File]::AppendAllText($logPath, $Message + [Environment]::NewLine, $utf8) }
    catch {
        $script:caughtFailure = $true
        Write-Host '运行记录未能完整保存，请保留本窗口截图。' -ForegroundColor Red
    }
}

Write-RunMessage ("运行记录：" + $logPath)
if (-not $caughtFailure -and $lastResult -eq '成功') {
    for ($seconds = 5; $seconds -ge 1; $seconds--) {
        Write-RunMessage ("已完成，$seconds 秒后自动关闭本窗口。") Green
        if ($caughtFailure) { break }
        Start-Sleep -Seconds 1
    }
    if (-not $caughtFailure) { exit 0 }
}

Write-RunMessage '本次未完成，窗口保留。关闭后可在助手里重试。' Red
Read-Host '按回车关闭本窗口' | Out-Null
exit 1
