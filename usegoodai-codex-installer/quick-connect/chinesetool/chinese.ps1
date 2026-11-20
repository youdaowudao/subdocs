# UseGoodAI Codex 中文化 1.1.6
# 由 codex-zh/build.py 生成。
# MIT License
#
# Copyright (c) 2026 zhenglei410
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
& {
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
    # UseGoodAI：退出确认耗时较长时同样显示中文进度，原关闭顺序不变。
    $stopWatch = [Diagnostics.Stopwatch]::StartNew()
    $nextStopProgress = 5
    $stopResult = Stop-RunningClients
    $sessionId = (Get-Process -Id $PID).SessionId
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
        $remaining = @(
            Get-CimInstance Win32_Process |
                Where-Object { $_.SessionId -eq $sessionId -and $_.Name -match '^(ChatGPT|Codex)(\.exe)?$' }
        )
        if ($stopWatch.Elapsed.TotalSeconds -ge $nextStopProgress) {
            Write-Host "正在确认 ChatGPT 已关闭，已等待 $([int]$stopWatch.Elapsed.TotalSeconds) 秒……"
            $nextStopProgress += 5
        }
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
        throw '未能自动关闭 ChatGPT。请重启电脑后再运行本命令。'
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
$coreScript = {
[CmdletBinding()]
param(
    [ValidateRange(0, 65535)]
    [int]$Port = 0,

    [ValidateRange(5, 300)]
    [int]$TimeoutSeconds = 90,

    [switch]$NoLaunch,

    [switch]$InspectOnly,

    [switch]$NoBootstrap,

    [switch]$CurrentKeyOnly,

    [switch]$RestartAfterSuccess,

    [switch]$DiagnoseAfterRestart,

    [ValidateRange(0, 65535)]
    [int]$DiagnosticPort = 0
)

# UseGoodAI：输出改为中文；缓存算法保持原版。
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CodexMainProcesses {
    Get-CimInstance Win32_Process -Filter "Name='ChatGPT.exe'" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.CommandLine -and
            $_.CommandLine -notmatch '--type=' -and
            $_.CommandLine -notmatch 'crashpad-handler'
        }
}

function Get-DebugPortFromProcess {
    param([object]$Process)

    if ($null -eq $Process -or [string]::IsNullOrWhiteSpace($Process.CommandLine)) {
        return $null
    }

    $match = [regex]::Match($Process.CommandLine, '--remote-debugging-port=(\d+)')
    if (-not $match.Success) {
        return $null
    }

    return [int]$match.Groups[1].Value
}

function Test-CdpEndpoint {
    param([int]$CandidatePort)

    if ($CandidatePort -le 0) {
        return $false
    }

    try {
        $null = Invoke-RestMethod -Uri "http://127.0.0.1:$CandidatePort/json/version" -TimeoutSec 1
        return $true
    }
    catch {
        return $false
    }
}

function Find-FreePort {
    param(
        [int[]]$ExcludePort = @()
    )

    foreach ($candidate in 9230..9270) {
        if ($ExcludePort -contains $candidate) {
            continue
        }

        $listener = $null
        try {
            $listener = [System.Net.Sockets.TcpListener]::new(
                [System.Net.IPAddress]::Loopback,
                $candidate
            )
            $listener.Start()
            return $candidate
        }
        catch {
            continue
        }
        finally {
            if ($null -ne $listener) {
                $listener.Stop()
            }
        }
    }

    throw '找不到可用的本机调试端口。'
}

function Add-AppActivationInterop {
    if ('CodexCurrentCache.NativeActivation' -as [type]) {
        return
    }

    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace CodexCurrentCache
{
    public static class NativeActivation
    {
        private const uint CLSCTX_LOCAL_SERVER = 0x4;

        [DllImport("ole32.dll")]
        private static extern int CoCreateInstance(
            ref Guid rclsid,
            IntPtr pUnkOuter,
            uint dwClsContext,
            ref Guid riid,
            out IntPtr ppv);

        [UnmanagedFunctionPointer(CallingConvention.Winapi)]
        private delegate int ActivateApplicationDelegate(
            IntPtr self,
            [MarshalAs(UnmanagedType.LPWStr)] string appUserModelId,
            [MarshalAs(UnmanagedType.LPWStr)] string arguments,
            int options,
            out uint processId);

        public static int Activate(
            string appUserModelId,
            string arguments,
            out uint processId)
        {
            Guid clsid = new Guid("45BA127D-10A8-46EA-8AB7-56EA9078943C");
            Guid iid = new Guid("2e941141-7f97-4756-ba1d-9decde894a3d");
            IntPtr manager;
            int hr = CoCreateInstance(
                ref clsid,
                IntPtr.Zero,
                CLSCTX_LOCAL_SERVER,
                ref iid,
                out manager);
            if (hr < 0)
            {
                processId = 0;
                return hr;
            }

            try
            {
                IntPtr vtable = Marshal.ReadIntPtr(manager);
                IntPtr method = Marshal.ReadIntPtr(vtable, 3 * IntPtr.Size);
                ActivateApplicationDelegate activate =
                    (ActivateApplicationDelegate)Marshal.GetDelegateForFunctionPointer(
                        method,
                        typeof(ActivateApplicationDelegate));
                return activate(manager, appUserModelId, arguments, 0, out processId);
            }
            finally
            {
                Marshal.Release(manager);
            }
        }
    }
}
'@
}

function Get-CodexAumid {
    $package = Get-AppxPackage -Name OpenAI.Codex |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if ($null -eq $package) {
        throw '当前用户尚未安装官方 ChatGPT 桌面版。'
    }

    $manifestPath = Join-Path $package.InstallLocation 'AppxManifest.xml'
    [xml]$manifest = Get-Content -Raw -LiteralPath $manifestPath
    $applications = @($manifest.Package.Applications.Application)
    $application = $applications |
        Where-Object { $_.Id -eq 'App' } |
        Select-Object -First 1

    if ($null -eq $application) {
        throw '找不到 ChatGPT 桌面版的启动入口。'
    }

    return "$($package.PackageFamilyName)!$($application.Id)"
}

function Start-CodexWithDebugPort {
    param([int]$DebugPort)

    if (@(Get-CodexMainProcesses).Count -gt 0) {
        throw 'ChatGPT 仍在运行，请完全退出后重试。'
    }

    # UseGoodAI：说明上游原有的临时启动用途，完成后不正常重开。
    Write-Host '正在临时打开 ChatGPT 以写入语言缓存，完成后会自动关闭……'
    Add-AppActivationInterop
    [uint32]$processId = 0
    $arguments = "--remote-debugging-port=$DebugPort --remote-allow-origins=http://127.0.0.1:$DebugPort"
    $hr = [CodexCurrentCache.NativeActivation]::Activate(
        (Get-CodexAumid),
        $arguments,
        [ref]$processId
    )

    if ($hr -lt 0) {
        throw ('启动 ChatGPT 失败，错误码 0x{0:X8}。' -f $hr)
    }

    Write-Host "已启动 ChatGPT，正在连接本机端口 $DebugPort。"
}

function Stop-CodexRuntimeProcesses {
    # UseGoodAI：改用入口脚本中的 Stop-CodexClients（复用 install/codex.ps1 的 Stop-RunningClients）。
    if (Stop-CodexClients) {
        throw '中文缓存已写入，但未能自动关闭 ChatGPT。请重启电脑后再打开 ChatGPT。'
    }
}

function Start-CodexNormally {
    Add-AppActivationInterop
    [uint32]$processId = 0
    $hr = [CodexCurrentCache.NativeActivation]::Activate(
        (Get-CodexAumid),
        '',
        [ref]$processId
    )

    if ($hr -lt 0) {
        throw ('启动 ChatGPT 失败，错误码 0x{0:X8}。' -f $hr)
    }

    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
        Start-Sleep -Milliseconds 300
        $running = @(Get-CodexMainProcesses)
    }
    while ($running.Count -eq 0 -and [DateTime]::UtcNow -lt $deadline)

    if ($running.Count -eq 0) {
        throw 'ChatGPT 未能启动。'
    }
}

function Resolve-DebugPort {
    if ($Port -gt 0) {
        if (-not $NoLaunch) {
            $running = @(Get-CodexMainProcesses)
            if ($running.Count -eq 0) {
                Start-CodexWithDebugPort -DebugPort $Port
            }
            elseif ((Get-DebugPortFromProcess $running[0]) -ne $Port) {
                throw 'ChatGPT 仍在运行，请完全退出后重试。'
            }
        }

        return $Port
    }

    foreach ($process in @(Get-CodexMainProcesses)) {
        $candidate = Get-DebugPortFromProcess $process
        if ($null -ne $candidate -and (Test-CdpEndpoint $candidate)) {
            return $candidate
        }
    }

    if ($NoLaunch) {
        throw '未找到 ChatGPT 调试连接。'
    }

    $freePort = Find-FreePort
    Start-CodexWithDebugPort -DebugPort $freePort
    return $freePort
}

function Wait-CdpTarget {
    param(
        [int]$DebugPort,
        [int]$WaitSeconds
    )

    # UseGoodAI：等待页面时每 5 秒显示进度。
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $nextProgress = 5
    $deadline = [DateTime]::UtcNow.AddSeconds($WaitSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        try {
            $targets = [object[]](Invoke-RestMethod -Uri "http://127.0.0.1:$DebugPort/json/list" -TimeoutSec 2)
            foreach ($target in $targets) {
                if ($null -eq $target) {
                    continue
                }

                $type = $target.PSObject.Properties['type']
                $url = $target.PSObject.Properties['url']
                $webSocket = $target.PSObject.Properties['webSocketDebuggerUrl']

                if (
                    $null -ne $type -and
                    $null -ne $url -and
                    $null -ne $webSocket -and
                    $type.Value -eq 'page' -and
                    $url.Value -eq 'app://-/index.html' -and
                    -not [string]::IsNullOrWhiteSpace([string]$webSocket.Value)
                ) {
                    return $target
                }
            }
        }
        catch {
            # Codex may still be starting.
        }

        if ($watch.Elapsed.TotalSeconds -ge $nextProgress) {
            Write-Host "正在等待 ChatGPT 页面，已等待 $([int]$watch.Elapsed.TotalSeconds) 秒……"
            $nextProgress += 5
        }
        Start-Sleep -Milliseconds 500
    }

    throw "等待 ChatGPT 页面超过 $WaitSeconds 秒，请完全退出 ChatGPT 后重试。"
}

function Get-WebSocketUrl {
    param([object]$Target)

    $property = $Target.PSObject.Properties['webSocketDebuggerUrl']
    foreach ($value in @($property.Value)) {
        $match = [regex]::Match([string]$value, '(?i)wss?://[^\s]+')
        if ($match.Success) {
            $uri = [Uri]$match.Value
            if ($uri.Host -in @('localhost', '::1', '[::1]')) {
                $builder = [UriBuilder]$uri
                $builder.Host = '127.0.0.1'
                return $builder.Uri.AbsoluteUri
            }
            return $uri.AbsoluteUri
        }
    }

    throw 'ChatGPT 页面未提供有效的本机调试地址。'
}

# UseGoodAI：异步连接、发送、接收均有超时；每 5 秒输出当前阶段，不再无期限接收。
function Wait-CdpTask {
    param($Task, $State, [int]$WaitSeconds, [string]$Stage)
    while (-not $Task.IsCompleted) {
        if ($State.Watch.Elapsed.TotalSeconds -ge $WaitSeconds) {
            throw "$Stage 超过 $WaitSeconds 秒，已停止等待。"
        }
        if ($State.Watch.Elapsed.TotalSeconds -ge $State.NextProgress) {
            Write-Host "$Stage，已等待 $([int]$State.Watch.Elapsed.TotalSeconds) 秒……"
            $State.NextProgress += 5
        }
        Start-Sleep -Milliseconds 200
    }
    if ($State.Watch.Elapsed.TotalSeconds -ge $WaitSeconds) {
        throw "$Stage 超过 $WaitSeconds 秒，已停止等待。"
    }
    try { return $Task.GetAwaiter().GetResult() }
    catch { throw "$Stage 未完成，调试连接已关闭或超时。" }
}

function Invoke-CdpOnce {
    param(
        [string]$WebSocketUrl,
        [string]$Expression,
        [int]$WaitSeconds,
        [string]$Stage = '正在等待 ChatGPT 加载'
    )

    $socket = [System.Net.WebSockets.ClientWebSocket]::new()
    $socket.Options.Proxy = $null
    $state = @{ Watch = [Diagnostics.Stopwatch]::StartNew(); NextProgress = 5 }
    $timeout = [System.Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds($WaitSeconds))
    $connectTimeout = [System.Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds([Math]::Min($WaitSeconds, 10)))

    try {
        $task = $socket.ConnectAsync([Uri]$WebSocketUrl, $connectTimeout.Token)
        [void](Wait-CdpTask $task $state $WaitSeconds '正在连接 ChatGPT')

        $payload = @{
            id = 1
            method = 'Runtime.evaluate'
            params = @{
                expression = $Expression
                awaitPromise = $true
                returnByValue = $true
            }
        } | ConvertTo-Json -Depth 12 -Compress

        $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
        $task = $socket.SendAsync(
            [ArraySegment[byte]]::new($bytes),
            [System.Net.WebSockets.WebSocketMessageType]::Text,
            $true,
            $timeout.Token
        )
        [void](Wait-CdpTask $task $state $WaitSeconds '正在发送中文设置')

        $buffer = [byte[]]::new(65536)
        $received = [Text.StringBuilder]::new()

        while ($true) {
            $task = $socket.ReceiveAsync(
                [ArraySegment[byte]]::new($buffer),
                $timeout.Token
            )
            $result = Wait-CdpTask $task $state $WaitSeconds $Stage

            if ($result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
                throw 'ChatGPT 调试连接提前关闭。'
            }

            [void]$received.Append([Text.Encoding]::UTF8.GetString($buffer, 0, $result.Count))
            if (-not $result.EndOfMessage) {
                continue
            }

            $message = $received.ToString() | ConvertFrom-Json
            [void]$received.Clear()

            $idProperty = $message.PSObject.Properties['id']
            if ($null -eq $idProperty -or [int]$idProperty.Value -ne 1) {
                continue
            }

            $errorProperty = $message.PSObject.Properties['error']
            if ($null -ne $errorProperty -and $null -ne $errorProperty.Value) {
                $errorTextProperty = $errorProperty.Value.PSObject.Properties['message']
                $pageFailure = [InvalidOperationException]::new('ChatGPT 调试调用未完成。')
                if ([string]$errorTextProperty.Value -match 'Execution context was destroyed|Cannot find context with specified id|Inspected target navigated or closed') {
                    $pageFailure.Data['CodexPageChanged'] = $true
                }
                throw $pageFailure
            }

            $resultProperty = $message.PSObject.Properties['result']
            $resultObject = $resultProperty.Value
            $exceptionProperty = $resultObject.PSObject.Properties['exceptionDetails']
            if ($null -ne $exceptionProperty -and $null -ne $exceptionProperty.Value) {
                $textProperty = $exceptionProperty.Value.PSObject.Properties['text']
                throw 'ChatGPT 页面脚本未能执行。'
            }

            $container = $resultObject.PSObject.Properties['result'].Value
            return $container.PSObject.Properties['value'].Value
        }
    }
    finally {
        $socket.Abort()
        $socket.Dispose()
        $connectTimeout.Dispose()
        $timeout.Dispose()
    }
}

# UseGoodAI：启动时页面可能切换；只对明确的页面失效错误重新查找页面并重试，沿用同一等待上限。
function Invoke-CdpExpression {
    param([string]$WebSocketUrl, [string]$Expression, [int]$WaitSeconds,
          [string]$Stage = '正在等待 ChatGPT 加载')
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while ($watch.Elapsed.TotalSeconds -lt $WaitSeconds) {
        $remaining = [Math]::Max(1, [int][Math]::Ceiling($WaitSeconds - $watch.Elapsed.TotalSeconds))
        try {
            return Invoke-CdpOnce -WebSocketUrl $WebSocketUrl -Expression $Expression -WaitSeconds $remaining -Stage $Stage
        }
        catch {
            # 原版主动刷新后允许旧连接失效；这里不能反复执行刷新。
            if (-not $_.Exception.Data.Contains('CodexPageChanged') -or $Expression -eq 'location.reload(); "reload-requested"') { throw }
            Write-Host "ChatGPT 页面正在切换，正在重新连接（已等待 $([int]$watch.Elapsed.TotalSeconds) 秒）……"
            $remaining = [int][Math]::Floor($WaitSeconds - $watch.Elapsed.TotalSeconds)
            if ($remaining -le 0) { break }
            Start-Sleep -Milliseconds 500
            $target = Wait-CdpTarget -DebugPort ([Uri]$WebSocketUrl).Port -WaitSeconds $remaining
            $WebSocketUrl = Get-WebSocketUrl -Target $target
        }
    }
    throw "$Stage 超过 $WaitSeconds 秒，已停止等待。"
}

function Assert-CodexStorageHealthy {
    # UseGoodAI：只读检查当前数据库恢复日志；损坏时不能把内存中的回读成功当作落盘成功。
    # 不删除、重建或修改数据库，不改变上游页面内缓存算法。
    $family = (Get-CodexAumid).Split('!')[0]
    $logPath = Join-Path $env:LOCALAPPDATA "Packages\$family\LocalCache\Roaming\Codex\web\Codex\Default\Local Storage\leveldb\LOG"
    if (-not (Test-Path -LiteralPath $logPath)) { return }
    $stream = [IO.File]::Open($logPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $reader = [IO.StreamReader]::new($stream)
    try { $log = $reader.ReadToEnd() } finally { $reader.Dispose() }
    if ($log -match 'Corruption:|IO error:') {
        throw 'ChatGPT 的本地缓存数据库报告损坏，本次无法确认中文设置已保存。现有数据已保留。'
    }
}

function Save-CodexStorage {
    # UseGoodAI：强制结束前先结束 Codex 的页面进程（renderer）。页面进程全部断开后，
    # Chromium 立即把本地存储写入磁盘；直接结束整个 Codex 会丢失尚未落盘的中文缓存（Windows 实测）。
    $renderers = @(
        Get-CimInstance Win32_Process -Filter "Name='ChatGPT.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -match '--type=renderer' }
    )

    foreach ($process in $renderers) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }

    Start-Sleep -Seconds 2
}

function Confirm-CurrentCacheAfterReload {
    param(
        [int]$DebugPort,
        [string]$CurrentCacheKey,
        [int]$TimeoutSeconds
    )

    $target = Wait-CdpTarget -DebugPort $DebugPort -WaitSeconds $TimeoutSeconds
    $webSocketUrl = Get-WebSocketUrl -Target $target

    try {
        $null = Invoke-CdpExpression `
            -WebSocketUrl $webSocketUrl `
            -Expression 'location.reload(); "reload-requested"' `
            -WaitSeconds 5
    }
    catch {
        # Reload normally closes the old CDP connection.
    }

    Start-Sleep -Milliseconds 750
    $escapedKey = $CurrentCacheKey.Replace('\', '\\').Replace("'", "\'")
    $verifyExpression = @"
(() => {
    const key = '$escapedKey';
    const raw = localStorage.getItem(key);
    if (raw === null) {
        return JSON.stringify({ ok: false, reason: "cache-key-missing", key });
    }
    try {
        const wrapper = JSON.parse(raw);
        const payload = typeof wrapper.data === "string"
            ? JSON.parse(wrapper.data)
            : wrapper.data;
        const values = payload?.values;
        let value = null;
        for (const metadata of Object.values(payload?.layer_configs || {})) {
            if (!metadata || typeof metadata !== "object") continue;
            const candidates = [];
            if (metadata.v !== undefined && values) {
                candidates.push(values[String(metadata.v)]);
            }
            candidates.push(metadata.value, metadata);
            value = candidates.find(candidate =>
                candidate &&
                Object.prototype.hasOwnProperty.call(candidate, "enable_i18n")
            ) || null;
            if (value) break;
        }
        return JSON.stringify({
            ok: Boolean(value && value.enable_i18n === true),
            key,
            cachedEnableI18n: value?.enable_i18n ?? null,
            cachedLocaleSource: value?.locale_source ?? null
        });
    }
    catch (error) {
        return JSON.stringify({
            ok: false,
            reason: "cache-parse-failed",
            key,
            error: String(error)
        });
    }
})()
"@

    $lastVerification = $null
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $nextProgress = 5
    for ($attempt = 1; $attempt -le 10; $attempt++) {
        try {
            $target = Wait-CdpTarget -DebugPort $DebugPort -WaitSeconds 5
            $webSocketUrl = Get-WebSocketUrl -Target $target
            $rawVerification = Invoke-CdpExpression `
                -WebSocketUrl $webSocketUrl `
                -Expression $verifyExpression `
                -Stage '正在检查语言缓存' `
                -WaitSeconds 10
            $verificationText = @($rawVerification) |
                Where-Object { $_ -is [string] } |
                Select-Object -Last 1

            if (-not [string]::IsNullOrWhiteSpace($verificationText)) {
                $lastVerification = $verificationText | ConvertFrom-Json
                if ($lastVerification.ok -eq $true) {
                    return $lastVerification
                }
            }
        }
        catch {
            # The app may still be recreating the renderer after reload.
        }

        if ($watch.Elapsed.TotalSeconds -ge $nextProgress) {
            Write-Host "正在检查刷新后的语言缓存，已等待 $([int]$watch.Elapsed.TotalSeconds) 秒……"
            $nextProgress = $watch.Elapsed.TotalSeconds + 5
        }
        Start-Sleep -Milliseconds 500
    }

    if ($null -ne $lastVerification) {
        throw (
            '刷新后读取的语言缓存未启用中文。'
        )
    }

    throw '刷新后未能确认语言缓存已保留。'
}

function Get-CurrentCacheSnapshot {
    param(
        [int]$DebugPort,
        [int]$TimeoutSeconds,
        [string]$Stage = '正在等待 ChatGPT 刷新后加载'
    )

    $target = Wait-CdpTarget -DebugPort $DebugPort -WaitSeconds $TimeoutSeconds
    $webSocketUrl = Get-WebSocketUrl -Target $target
    $snapshotExpression = @'
(async () => {
    const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
    const deadline = Date.now() + __READY_TIMEOUT_MS__;
    const targetLayer = "72216192";
    const cachePrefix = "statsig.cached.evaluations.";

    const getRoot = () => window.__STATSIG__ || globalThis.__STATSIG__;
    const getClient = () => {
        const root = getRoot();
        if (!root) return null;
        return root.firstInstance ||
            (typeof root.instance === "function" ? root.instance() : null);
    };

    let client = getClient();
    while (
        (!client || String(client.loadingStatus || "") !== "Ready") &&
        Date.now() < deadline
    ) {
        await sleep(250);
        client = getClient();
    }

    const htmlLang = String(document.documentElement.lang || "");
    if (!client) {
        return JSON.stringify({
            ok: false,
            error: "ChatGPT 配置服务未能启动。",
            currentCacheKey: null,
            currentCacheKeyExists: false,
            liveEnableI18n: null,
            allCacheKeys: [],
            htmlLang,
            statsigStatus: null
        });
    }

    const statsigStatus = String(client.loadingStatus || "");
    if (statsigStatus !== "Ready") {
        return JSON.stringify({
            ok: false,
            error: "等待 ChatGPT 配置服务超过 60 秒，尚未就绪。",
            currentCacheKey: null,
            currentCacheKeyExists: false,
            liveEnableI18n: null,
            allCacheKeys: [],
            htmlLang,
            statsigStatus
        });
    }

    const context = client.getContext();
    const currentCacheKey = String(
        client.dataAdapter._getCacheKey(context.user)
    );
    const layer = client.getLayer(targetLayer, {
        disableExposureLog: true
    });
    const allCacheKeys = Object.keys(localStorage)
        .filter(key => key.startsWith(cachePrefix))
        .sort();

    return JSON.stringify({
        ok: true,
        currentCacheKey,
        currentCacheKeyExists: localStorage.getItem(currentCacheKey) !== null,
        liveEnableI18n: layer ? layer.get("enable_i18n", null) : null,
        allCacheKeys,
        htmlLang,
        statsigStatus
    });
})()
'@
    $snapshotExpression = $snapshotExpression.Replace(
        '__READY_TIMEOUT_MS__',
        [string]([Math]::Min(60000, $TimeoutSeconds * 1000))
    )

    $rawSnapshot = Invoke-CdpExpression `
        -WebSocketUrl $webSocketUrl `
        -Expression $snapshotExpression `
        -Stage $Stage `
        -WaitSeconds $TimeoutSeconds
    $cleanSnapshot = @($rawSnapshot) |
        Where-Object { $_ -is [string] } |
        Select-Object -Last 1

    if ([string]::IsNullOrWhiteSpace($cleanSnapshot)) {
        throw '未能读取 ChatGPT 重开后的状态。'
    }

    return $cleanSnapshot | ConvertFrom-Json
}

$pageExpression = @'
(async () => {
    const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
    const inspectOnly = __INSPECT_ONLY__;
    const noBootstrap = __NO_BOOTSTRAP__;
    const patchAllExisting = __PATCH_ALL_EXISTING__;
    const targetLayer = "72216192";
    const targetLayerHash = "4269166702";
    const cachePrefix = "statsig.cached.evaluations.";
    const deadline = Date.now() + __READY_TIMEOUT_MS__;

    const getRoot = () => window.__STATSIG__ || globalThis.__STATSIG__;
    const getClient = () => {
        const root = getRoot();
        if (!root) return null;
        return root.firstInstance ||
            (typeof root.instance === "function" ? root.instance() : null);
    };

    let client = getClient();
    while (
        (!client || String(client.loadingStatus || "") !== "Ready") &&
        Date.now() < deadline
    ) {
        await sleep(250);
        client = getClient();
    }

    if (!client) {
        return JSON.stringify({
            ok: false,
            error: "ChatGPT 配置服务未能启动。",
            origin: location.origin,
            href: location.href,
            hasStatsigRoot: Boolean(getRoot())
        });
    }

    if (String(client.loadingStatus || "") !== "Ready") {
        return JSON.stringify({
            ok: false,
            error: "等待 ChatGPT 配置服务超过 60 秒，尚未就绪。",
            origin: location.origin,
            href: location.href,
            htmlLang: document.documentElement.lang,
            statsigStatus: client.loadingStatus
        });
    }

    const context = client.getContext();
    const currentCacheKey = String(client.dataAdapter._getCacheKey(context.user));

    const allCacheKeys = Object.keys(localStorage)
        .filter(key => key.startsWith(cachePrefix));
    const staleCacheKeys = allCacheKeys
        .filter(key => key !== currentCacheKey);

    const layer = client.getLayer(targetLayer, { disableExposureLog: true });
    const liveEnableI18n = layer ? layer.get("enable_i18n", null) : null;
    const currentCacheValue = localStorage.getItem(currentCacheKey);

    if (inspectOnly) {
        return JSON.stringify({
            ok: true,
            mode: "inspect",
            origin: location.origin,
            href: location.href,
            htmlLang: document.documentElement.lang,
            statsigStatus: client.loadingStatus,
            currentCacheKey,
            currentCacheKeyExists: currentCacheValue !== null,
            allCacheKeys,
            staleCacheKeys,
            patchAllExisting,
            liveEnableI18n
        });
    }

    const parseCurrentPayload = () => {
        if (currentCacheValue === null) return null;
        const wrapper = JSON.parse(currentCacheValue);
        const dataWasString = typeof wrapper.data === "string";
        const payload = dataWasString ? JSON.parse(wrapper.data) : wrapper.data;
        return { wrapper, payload, dataWasString };
    };

    let parsed = null;
    try {
        parsed = parseCurrentPayload();
    }
    catch {
        parsed = null;
    }

    let wrapper = parsed?.wrapper ?? null;
    let dataWasString = parsed?.dataWasString ?? true;
    let payload = parsed?.payload ?? null;
    let seededFrom = parsed ? "current-cache" : null;

    if (!payload && context.values && context.values.has_updates === true) {
        payload = JSON.parse(JSON.stringify(context.values));
        seededFrom = "context-values";
    }

    if (!payload && !noBootstrap) {
        payload = {
            has_updates: true,
            response_format: "init-v2",
            time: Date.now(),
            feature_gates: {},
            dynamic_configs: {},
            layer_configs: {},
            values: {},
            param_stores: {},
            sdk_flags: {},
            exposures: {}
        };
        seededFrom = "minimal-bootstrap";
    }

    if (!payload) {
        return JSON.stringify({
            ok: false,
            error: "当前语言缓存不存在，且未启用补建缓存。",
            currentCacheKey,
            allCacheKeys,
            staleCacheKeys,
            liveEnableI18n
        });
    }

    const hasOwn = (value, key) =>
        value !== null &&
        typeof value === "object" &&
        Object.prototype.hasOwnProperty.call(value, key);

    const patchExistingLayer = targetPayload => {
        const layerMap = targetPayload?.layer_configs;
        const values = targetPayload?.values;
        if (!layerMap || typeof layerMap !== "object") return false;

        for (const [name, metadata] of Object.entries(layerMap)) {
            if (!metadata || typeof metadata !== "object") continue;

            const isTarget = name === targetLayer || name === targetLayerHash;
            const candidates = [];
            if (metadata.v !== undefined && values && typeof values === "object") {
                candidates.push(values[String(metadata.v)]);
            }
            if (metadata.value && typeof metadata.value === "object") {
                candidates.push(metadata.value);
            }
            if (isTarget) candidates.push(metadata);

            for (const candidate of candidates) {
                if (candidate && hasOwn(candidate, "enable_i18n")) {
                    candidate.enable_i18n = true;
                    if (!hasOwn(candidate, "locale_source")) {
                        candidate.locale_source = "SYSTEM";
                    }
                    return true;
                }
            }
        }

        return false;
    };

    const insertI18nLayer = targetPayload => {
        targetPayload.has_updates = true;
        targetPayload.layer_configs = targetPayload.layer_configs || {};

        if (targetPayload.response_format === "init-v2" || targetPayload.values) {
            targetPayload.response_format = "init-v2";
            targetPayload.values = targetPayload.values || {};
            let index = 0;
            while (hasOwn(targetPayload.values, String(index))) index += 1;
            targetPayload.values[String(index)] = {
                enable_i18n: true,
                locale_source: "SYSTEM"
            };
            targetPayload.layer_configs[targetLayer] = {
                v: String(index),
                r: "codex-current-key",
                s: [],
                is_device_based: true
            };
        }
        else {
            targetPayload.layer_configs[targetLayer] = {
                enable_i18n: true,
                locale_source: "SYSTEM"
            };
        }
    };

    const findCachedI18nValue = currentPayload => {
        const layerMap = currentPayload?.layer_configs;
        const values = currentPayload?.values;
        if (!layerMap || typeof layerMap !== "object") return null;

        for (const metadata of Object.values(layerMap)) {
            if (!metadata || typeof metadata !== "object") continue;

            const candidates = [];
            if (metadata.v !== undefined && values && typeof values === "object") {
                candidates.push(values[String(metadata.v)]);
            }
            if (metadata.value && typeof metadata.value === "object") {
                candidates.push(metadata.value);
            }
            candidates.push(metadata);

            for (const candidate of candidates) {
                if (
                    candidate &&
                    hasOwn(candidate, "enable_i18n")
                ) {
                    return candidate;
                }
            }
        }

        return null;
    };

    let layerPatched = patchExistingLayer(payload);
    if (!layerPatched && !noBootstrap) {
        insertI18nLayer(payload);
        layerPatched = true;
    }

    if (!layerPatched) {
        return JSON.stringify({
            ok: false,
            error: "当前缓存没有语言开关，且未启用补建缓存。",
            currentCacheKey,
            allCacheKeys,
            staleCacheKeys,
            liveEnableI18n
        });
    }

    wrapper = wrapper || {};
    wrapper.source = wrapper.source || "Bootstrap";
    wrapper.data = dataWasString ? JSON.stringify(payload) : payload;
    wrapper.receivedAt = Date.now();
    wrapper.stableID = context.stableID ?? wrapper.stableID ?? null;
    wrapper.fullUserHash = wrapper.fullUserHash ?? null;

    const serialized = JSON.stringify(wrapper);
    localStorage.setItem(currentCacheKey, serialized);

    const savedWrapper = JSON.parse(localStorage.getItem(currentCacheKey));
    const savedPayload = typeof savedWrapper.data === "string"
        ? JSON.parse(savedWrapper.data)
        : savedWrapper.data;
    const savedValue = findCachedI18nValue(savedPayload);

    const staleCacheResults = [];
    let staleCachesModified = 0;

    if (patchAllExisting) {
        for (const staleKey of staleCacheKeys) {
            try {
                const staleRaw = localStorage.getItem(staleKey);
                if (staleRaw === null) {
                    staleCacheResults.push({
                        key: staleKey,
                        status: "missing-during-update"
                    });
                    continue;
                }

                const staleWrapper = JSON.parse(staleRaw);
                const staleDataWasString = typeof staleWrapper.data === "string";
                const stalePayload = staleDataWasString
                    ? JSON.parse(staleWrapper.data)
                    : staleWrapper.data;
                const beforeValue = findCachedI18nValue(stalePayload);
                const wasTrue = beforeValue?.enable_i18n === true;

                let stalePatched = patchExistingLayer(stalePayload);
                let status = wasTrue ? "already-true" : "patched";

                if (!stalePatched && !noBootstrap) {
                    insertI18nLayer(stalePayload);
                    stalePatched = true;
                    status = "layer-inserted";
                }

                if (!stalePatched) {
                    staleCacheResults.push({
                        key: staleKey,
                        status: "layer-missing-bootstrap-disabled"
                    });
                    continue;
                }

                if (!wasTrue || status === "layer-inserted") {
                    staleWrapper.data = staleDataWasString
                        ? JSON.stringify(stalePayload)
                        : stalePayload;
                    staleWrapper.receivedAt = Date.now();
                    localStorage.setItem(staleKey, JSON.stringify(staleWrapper));
                    staleCachesModified += 1;
                }

                const afterValue = findCachedI18nValue(stalePayload);
                staleCacheResults.push({
                    key: staleKey,
                    status,
                    cachedEnableI18n: afterValue?.enable_i18n ?? null
                });
            }
            catch (error) {
                staleCacheResults.push({
                    key: staleKey,
                    status: "error",
                    error: String(error)
                });
            }
        }
    }

    const finalCacheKeys = Object.keys(localStorage)
        .filter(key => key.startsWith(cachePrefix))
        .sort();

    return JSON.stringify({
        ok: Boolean(savedValue && savedValue.enable_i18n === true),
        mode: "write",
        origin: location.origin,
        href: location.href,
        htmlLang: document.documentElement.lang,
        statsigStatus: client.loadingStatus,
        currentCacheKey,
        currentCacheKeyExists: currentCacheValue !== null,
        seededFrom,
        liveEnableI18n,
        cachedEnableI18n: savedValue?.enable_i18n ?? null,
        cachedLocaleSource: savedValue?.locale_source ?? null,
        allCacheKeys: finalCacheKeys,
        staleCacheKeys,
        patchAllExisting,
        staleCachesModified: staleCachesModified > 0,
        staleCacheModifiedCount: staleCachesModified,
        staleCacheResults
    });
})()
'@

$effectiveExpression = $pageExpression.Replace(
    '__INSPECT_ONLY__',
    $(if ($InspectOnly) { 'true' } else { 'false' })
).Replace(
    '__NO_BOOTSTRAP__',
    $(if ($NoBootstrap) { 'true' } else { 'false' })
).Replace(
    '__PATCH_ALL_EXISTING__',
    $(if ($CurrentKeyOnly) { 'false' } else { 'true' })
).Replace(
    '__READY_TIMEOUT_MS__',
    [string]([Math]::Min(60000, $TimeoutSeconds * 1000))
)

$debugPort = Resolve-DebugPort
Write-Host "正在连接 ChatGPT 页面……"
$target = Wait-CdpTarget -DebugPort $debugPort -WaitSeconds $TimeoutSeconds
Write-Host '正在等待 ChatGPT 配置服务加载……'
$webSocketUrl = Get-WebSocketUrl -Target $target
$rawResult = Invoke-CdpExpression `
    -WebSocketUrl $webSocketUrl `
    -Expression $effectiveExpression `
    -Stage '正在等待 ChatGPT 配置服务加载' `
    -WaitSeconds $TimeoutSeconds

$cleanResult = @($rawResult) |
    Where-Object { $_ -is [string] } |
    Select-Object -Last 1

if ([string]::IsNullOrWhiteSpace($cleanResult)) {
    throw 'ChatGPT 页面未返回有效结果。'
}

$result = $cleanResult | ConvertFrom-Json
# UseGoodAI：只显示简短中文，不向用户输出上游英文诊断表。
if ($result.PSObject.Properties['seededFrom']) {
    $sourceLabel = switch ($result.seededFrom) {
        'current-cache' { '已有缓存' }
        'context-values' { '当前配置' }
        'minimal-bootstrap' { '补建缓存' }
        default { '当前缓存' }
    }
    Write-Host "缓存来源：$sourceLabel"
}

if (-not $result.ok) {
    $errorProperty = $result.PSObject.Properties['error']
    if ($null -ne $errorProperty) {
        throw [string]$errorProperty.Value
    }
    throw '语言缓存写入失败。'
}

if ($InspectOnly) {
    Write-Host '检查完成，未修改缓存。'
    return
}

Write-Host ''
Write-Host "语言缓存已写入。"

if ($result.patchAllExisting) {
    Write-Host "已同步 $($result.staleCacheModifiedCount) 项旧缓存。"
}
else {
    Write-Host "已保留其他旧缓存。"
}

if ($RestartAfterSuccess -or $DiagnoseAfterRestart) {
    Write-Host "正在刷新页面，检查语言缓存……"
    $persistence = Confirm-CurrentCacheAfterReload `
        -DebugPort $debugPort `
        -CurrentCacheKey $result.currentCacheKey `
        -TimeoutSeconds $TimeoutSeconds
    Write-Host "刷新检查通过，语言缓存已保留。"

    for ($check = 1; $check -le 2; $check++) {
        Write-Host (
            "正在等待第 $check/2 次复查（3 秒）……"
        )
        Start-Sleep -Seconds 3

        Write-Host "第 $check/2 次复查：正在读取语言缓存……"
        $beforeRestart = Get-CurrentCacheSnapshot `
            -DebugPort $debugPort `
            -TimeoutSeconds $TimeoutSeconds `
            -Stage "第 $check/2 次复查：正在等待 ChatGPT 加载"

        if (-not $beforeRestart.ok) { throw "第 $check/2 次复查未完成，ChatGPT 配置服务尚未就绪。" }
        if (-not $beforeRestart.currentCacheKeyExists) { throw "第 $check/2 次复查未找到语言缓存。" }
        Write-Host "第 $check/2 次复查通过，语言缓存已保留。" -ForegroundColor Cyan
    }

    Assert-CodexStorageHealthy

    if ($DiagnoseAfterRestart) {
        if ($DiagnosticPort -gt 0) {
            if ($DiagnosticPort -eq $debugPort) {
                throw '诊断端口必须与初始调试端口不同。'
            }
            $restartPort = $DiagnosticPort
        }
        else {
            $restartPort = Find-FreePort -ExcludePort @($debugPort)
        }

        Write-Host (
            "正在关闭初始调试实例，并使用诊断端口 $restartPort 重新打开 ChatGPT……"
        )
        Stop-CodexRuntimeProcesses
        Start-CodexWithDebugPort -DebugPort $restartPort

        $latest = Get-CurrentCacheSnapshot `
            -DebugPort $restartPort `
            -TimeoutSeconds $TimeoutSeconds

        Write-Host ''
        Write-Host '========== ChatGPT 重开状态 ==========' -ForegroundColor Cyan
        Write-Host ('语言缓存：' + $(if ($latest.currentCacheKeyExists) { '已保留' } else { '未找到' }))
        Write-Host "本机诊断端口：$restartPort"
        Write-Host (
            '缓存检查：' + $(if ($latest.currentCacheKey -eq $result.currentCacheKey) { '一致' } else { '已变化' })
        )

        if ($latest.ok -ne $true) {
            $errorProperty = $latest.PSObject.Properties['error']
            if ($null -ne $errorProperty -and -not [string]::IsNullOrWhiteSpace(
                [string]$errorProperty.Value
            )) {
                throw [string]$errorProperty.Value
            }
            throw 'ChatGPT 重开后尚未就绪。'
        }

        if (
            $latest.currentCacheKeyExists -ne $true -or
            $latest.liveEnableI18n -ne $true
        ) {
            Write-Host (
                '诊断窗口保持打开，供查看界面。'
            ) -ForegroundColor Yellow
            throw (
                'ChatGPT 重开后未能加载语言缓存。'
            )
        }

        Write-Host '诊断窗口保持打开，供查看界面。' `
            -ForegroundColor Yellow
    }
    else {
        # UseGoodAI：取消自动重启。先结束页面进程让缓存落盘，再关闭调试实例。
        Write-Host '正在保存语言缓存……'
        Save-CodexStorage
        Write-Host '正在关闭 ChatGPT……'
        Stop-CodexRuntimeProcesses
    }
}
else {
    Write-Host '请完全退出 ChatGPT，再重新打开以加载语言缓存。'
}
}

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
}
