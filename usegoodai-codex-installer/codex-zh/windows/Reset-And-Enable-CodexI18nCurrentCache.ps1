[CmdletBinding()]
param(
    [ValidateRange(1, 65535)]
    [int]$Port = 9240,

    [ValidateRange(10, 300)]
    [int]$TimeoutSeconds = 120,

    [switch]$SkipProcessStop,

    [switch]$ValidateOnly,

    [switch]$NoAutoRestart,

    [switch]$CurrentKeyOnly,

    [switch]$DiagnoseAfterRestart,

    [ValidateRange(0, 65535)]
    [int]$DiagnosticPort = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-CommandFailure {
    param([object]$ErrorRecord)

    Write-Host ''
    Write-Host '========================================' -ForegroundColor DarkGray
    Write-Host '[失败] 中文缓存修复未完成。' -ForegroundColor Red
    # UseGoodAI：系统异常也使用中文说明，避免直接向用户输出英文异常。
    $reason = $ErrorRecord.Exception.Message
    if ($reason -notmatch '[一-鿿]') { $reason = '运行未完成，请完全退出 ChatGPT 后重试。' }
    Write-Host "原因：$reason" -ForegroundColor Red
}

trap {
    Write-CommandFailure $_
    break
}

# UseGoodAI：关闭进程复用 install/codex.ps1 的 Stop-RunningClients 及其依赖，原样复制。
function Get-RunningCodexClients {
  $sessionId = (Get-Process -Id $PID).SessionId
  return @(
    Get-Process -Name "codex", "chatgpt" -ErrorAction SilentlyContinue |
      Where-Object { $_.SessionId -eq $sessionId }
  )
}

function Get-OwnProcessIds {
  $ids = @()
  $current = $PID
  $childStart = $null
  while ($current -and ($ids -notcontains $current)) {
    $process = Get-CimInstance Win32_Process -Filter "ProcessId = $current" -ErrorAction Stop
    # UseGoodAI：已退出父进程的编号可能被新进程复用（Windows 实测为 ChatGPT.exe），
    # 启动时间晚于子进程的不是祖先，停止向上查找，否则会漏关 Codex。
    if (-not $process -or ($childStart -and $process.CreationDate -gt $childStart)) {
      break
    }
    $ids += $current
    $childStart = $process.CreationDate
    $current = $process.ParentProcessId
  }
  return $ids
}

function Test-ProcessExited($Process) {
  try {
    return $Process.HasExited
  } catch {
    return $false
  }
}

function Stop-RunningClients {
  $result = @{ ChatGPT = $false; Codex = $false; Left = $false }
  try {
    $clients = @(Get-RunningCodexClients)
    $result.ChatGPT = @($clients | Where-Object { $_.ProcessName -ieq "chatgpt" }).Count -gt 0
    $result.Codex = @($clients | Where-Object { $_.ProcessName -ieq "codex" }).Count -gt 0
    if ($clients.Count -eq 0) {
      return $result
    }

    $ownIds = @(Get-OwnProcessIds)
    $targets = @($clients | Where-Object { $ownIds -notcontains $_.Id })
    if ($targets.Count -lt $clients.Count) {
      $result.Left = $true
    }
    if ($targets.Count -gt 0) {
      $targets | Stop-Process -Force -ErrorAction SilentlyContinue
      for ($attempt = 0; $attempt -le 10; $attempt++) {
        if ($attempt -gt 0) {
          Start-Sleep -Milliseconds 500
        }
        $remaining = @($targets | Where-Object { -not (Test-ProcessExited $_) })
        if ($remaining.Count -eq 0) {
          break
        }
      }
      if ($remaining.Count -gt 0) {
        $result.Left = $true
      }
    }
  } catch {
    $result.Left = $true
  }
  return $result
}

# UseGoodAI：关闭用复用的 Stop-RunningClients；之后按上游做法等进程列表清空（最多 10 秒）。
function Stop-CodexClients {
    $stopResult = Stop-RunningClients
    $sessionId = (Get-Process -Id $PID).SessionId
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
        $remaining = @(
            Get-CimInstance Win32_Process |
                Where-Object { $_.SessionId -eq $sessionId -and $_.Name -match '^(ChatGPT|Codex)(\.exe)?$' }
        )
        if ($remaining.Count -eq 0) {
            break
        }
        Start-Sleep -Milliseconds 250
    }
    while ([DateTime]::UtcNow -lt $deadline)

    return ($stopResult.Left -or $remaining.Count -gt 0)
}

$processPattern = '^(ChatGPT|Codex|codex-command-runner|codex-windows-sandbox-service|codex-code-mode-host)(\.exe)?$'

# UseGoodAI：删除风险提醒，只显示操作进度。
Write-Host '正在关闭 ChatGPT……'

$remaining = @()
$processStopSkipped = $SkipProcessStop.IsPresent

if (-not $processStopSkipped) {
    # UseGoodAI：改用复用的 Stop-RunningClients 关闭 ChatGPT/Codex。
    if (Stop-CodexClients) {
        throw '未能自动关闭 ChatGPT/ChatGPT。请重启电脑后再运行本命令。'
    }
}

$ccSwitchProcesses = @(
    Get-CimInstance Win32_Process |
        Where-Object {
            $_.Name -match 'cc.?switch' -or
            $_.CommandLine -match 'cc.?switch'
        }
)

if ($ccSwitchProcesses.Count -gt 0) {
    Write-Host 'CC Switch 正在运行；若它重新打开 ChatGPT，请先退出 CC Switch。'
}

if ($ValidateOnly) {
    $remaining = @(
        Get-CimInstance Win32_Process |
            Where-Object { $_.Name -match $processPattern }
    )
    Write-Host "检查完成，当前 ChatGPT 进程数：$($remaining.Count)。"
    return
}

# UseGoodAI：核心脚本不再从 Gitee 下载；发布时由 build.py 原样嵌入。
$coreScript = [scriptblock]::Create([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Enable-CodexI18nCurrentCache.ps1')))

try {
    $coreArguments = @{
        Port = $Port
        TimeoutSeconds = $TimeoutSeconds
    }
    if (-not $NoAutoRestart -or $DiagnoseAfterRestart) {
        $coreArguments.RestartAfterSuccess = $true
    }
    if ($CurrentKeyOnly) {
        $coreArguments.CurrentKeyOnly = $true
    }
    if ($DiagnoseAfterRestart) {
        $coreArguments.DiagnoseAfterRestart = $true
        $coreArguments.DiagnosticPort = $DiagnosticPort
    }

    & $coreScript @coreArguments

    Write-Host ''
    Write-Host '========================================' -ForegroundColor DarkGray
    if ($DiagnoseAfterRestart) {
        Write-Host '[成功] 中文缓存已写入，ChatGPT 已用诊断端口重新启动。' -ForegroundColor Green
        Write-Host '上方已输出最新启动状态，可用于判断缓存键是否变化及 enable_i18n 是否生效。' -ForegroundColor Green
    }
    elseif ($NoAutoRestart) {
        Write-Host '[成功] 当前缓存键的中文开关已经写入。' -ForegroundColor Green
        Write-Host '已跳过自动重启，请手动完全退出并重新打开 ChatGPT。' -ForegroundColor Yellow
    }
    else {
        Write-Host '[成功] 中文缓存已经写入，ChatGPT 已关闭。' -ForegroundColor Green
        Write-Host '请重新打开 ChatGPT，检查界面是否显示中文。' -ForegroundColor Green
    }
}
catch {
    $failure = $_
    # UseGoodAI：失败后也关闭调试实例，不自动重开。
    Write-Host '正在关闭 ChatGPT……'
    if (Stop-CodexClients) { Write-Host 'ChatGPT 尚未完全退出，请手动退出。' }
    Write-CommandFailure $failure
    return
}
