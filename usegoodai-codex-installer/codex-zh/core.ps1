function Get-CodexDebugSocket($Desktop, [uint32]$ProcessId, [int]$Port) {
    Add-Type -AssemblyName System.Net.Http
    $handler = [Net.Http.HttpClientHandler]::new()
    $handler.UseProxy = $false
    $handler.AllowAutoRedirect = $false
    $http = [Net.Http.HttpClient]::new($handler)
    $http.Timeout = [TimeSpan]::FromSeconds(2)
    $http.MaxResponseContentBufferSize = 1MB
    try {
        $timer = [Diagnostics.Stopwatch]::StartNew()
        do {
            $listeners = @(Get-NetTCPConnection -State Listen -ErrorAction Stop |
                Where-Object LocalPort -EQ $Port)
            if ($listeners.Count) {
                if (-not (Get-StartedDebugProcess $Desktop $ProcessId $Port)) {
                    throw '调试端口不属于本次启动的 Codex。若 CC Switch 正在自动打开 Codex，请退出后重试。'
                }
                foreach ($listener in $listeners) {
                    if ($listener.OwningProcess -ne $ProcessId -or $listener.LocalAddress -notin @('127.0.0.1', '::1')) {
                        throw '调试端口发生冲突，或监听范围超出本机。'
                    }
                }
                try {
                    $json = $http.GetStringAsync("http://127.0.0.1:$Port/json/list").GetAwaiter().GetResult()
                } catch {
                    Start-Sleep -Milliseconds 250
                    continue
                }
                $targets = ConvertFrom-Json -InputObject $json
                foreach ($target in $targets) {
                    $fields = $target.PSObject.Properties
                    if (-not $fields['type'] -or $target.type -cne 'page' -or
                        -not $fields['url'] -or $target.url -cne 'app://-/index.html' -or
                        -not $fields['webSocketDebuggerUrl']) { continue }
                    $socketUri = [Uri]$target.webSocketDebuggerUrl
                    if (-not $socketUri.IsAbsoluteUri -or $socketUri.Scheme -ne 'ws' -or
                        $socketUri.Port -ne $Port -or $socketUri.Host -notin @('127.0.0.1', '[::1]', 'localhost') -or
                        $socketUri.UserInfo -or $socketUri.AbsolutePath -notmatch '^/devtools/page/[^/]+$') {
                        throw 'Codex 返回了无法安全连接的调试地址。'
                    }
                    $localUri = [UriBuilder]::new($socketUri)
                    $localUri.Host = '127.0.0.1'
                    return $localUri.Uri
                }
            }
            Start-Sleep -Milliseconds 250
        } while ($timer.Elapsed.TotalSeconds -lt 30)
        throw '等待 Codex 调试窗口超时。请确认官方客户端能启动、本机连接未被代理或安全软件拦截。'
    } finally {
        $http.Dispose()
    }
}

function Invoke-CodexDebug($Desktop, [uint32]$ProcessId, [int]$Port, [string]$Method, $Parameters) {
    $debugUri = Get-CodexDebugSocket $Desktop $ProcessId $Port
    $socket = [Net.WebSockets.ClientWebSocket]::new()
    $socket.Options.Proxy = [Net.WebProxy]::new()
    $cancel = [Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds(45))
    try {
        [void]$socket.ConnectAsync($debugUri, $cancel.Token).GetAwaiter().GetResult()
        $json = ConvertTo-Json -InputObject @{ id = 1; method = $Method; params = $Parameters } -Depth 5 -Compress
        $bytes = [Text.Encoding]::UTF8.GetBytes($json)
        [void]$socket.SendAsync([ArraySegment[byte]]::new($bytes), [Net.WebSockets.WebSocketMessageType]::Text, $true, $cancel.Token).GetAwaiter().GetResult()
        $buffer = [byte[]]::new(8192)
        do {
            $stream = [IO.MemoryStream]::new()
            try {
                do {
                    $chunk = $socket.ReceiveAsync([ArraySegment[byte]]::new($buffer), $cancel.Token).GetAwaiter().GetResult()
                    if ($chunk.MessageType -ne [Net.WebSockets.WebSocketMessageType]::Text) {
                        throw 'Codex 关闭了调试连接。'
                    }
                    $stream.Write($buffer, 0, $chunk.Count)
                    if ($stream.Length -gt 1MB) { throw 'Codex 调试响应超出预期。' }
                } while (-not $chunk.EndOfMessage)
                $response = ConvertFrom-Json -InputObject ([Text.Encoding]::UTF8.GetString($stream.ToArray()))
            } finally {
                $stream.Dispose()
            }
        } until ($response.PSObject.Properties['id'] -and $response.id -eq 1)
        if ($response.PSObject.Properties['error']) { throw ('Codex 调试调用失败：' + $Method) }
        return $response.result
    } finally {
        $socket.Dispose()
        $cancel.Dispose()
    }
}

function Get-CodexCacheResult($Desktop, [uint32]$ProcessId, [int]$Port, [bool]$Write, [int]$ReadyTimeoutMs = 40000) {
    $expressionSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'language-cache.js'))
    $mode = if ($Write) { 'true' } else { 'false' }
    $result = Invoke-CodexDebug $Desktop $ProcessId $Port 'Runtime.evaluate' @{
        expression = '(' + $expressionSource + "`n)($mode, $ReadyTimeoutMs)"
        awaitPromise = $true
        returnByValue = $true
    }
    if ($result.PSObject.Properties['exceptionDetails']) {
        $details = $result.exceptionDetails.PSObject.Properties['exception']
        $description = if ($details -and $details.Value.PSObject.Properties['description']) { $details.Value.description } else { '' }
        if ($description -match 'QuotaExceededError') { throw 'Codex 的本地缓存空间不足，语言开关没有写入。' }
        if ($description -match 'Statsig did not become ready') { throw 'Codex 的语言功能服务未就绪或使用了未支持的缓存接口。' }
        throw '未找到可安全读写的 Codex 语言缓存。请确认客户端版本，或让官方客户端先完成一次联网启动。'
    }
    return $result.result.value
}

function Enable-CodexLanguageCache($Desktop, [uint32]$ProcessId, [int]$Port) {
    $result = Get-CodexCacheResult $Desktop $ProcessId $Port $true
    if (-not $result.enabled) { throw '未能写入 Codex 语言开关。' }
    $null = Invoke-CodexDebug $Desktop $ProcessId $Port 'Page.reload' @{}
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        Start-Sleep -Milliseconds 500
        try {
            $result = Get-CodexCacheResult $Desktop $ProcessId $Port $false 3000
            if ($result.enabled -and $result.liveEnabled) { return }
        } catch {
            # The new renderer may not have its cache and Statsig client yet.
        }
    } while ($timer.Elapsed.TotalSeconds -lt 15)
    throw '刷新后 Codex 未读取到已启用的语言开关。'
}
