# UseGoodAI Codex 中文化 1.0.3
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
#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw '此命令用于 Windows 上的微软商店版 Codex 桌面应用。'
}

function Add-AppActivationInterop {
    if ('UseGoodAI.CodexChinese.NativeActivation' -as [type]) {
        return
    }

    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace UseGoodAI.CodexChinese
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

function Get-OfficialCodexDesktop {
    $packages = @(Get-AppxPackage -Name OpenAI.Codex |
        Where-Object { $_.PackageFamilyName -ceq 'OpenAI.Codex_2p2nqsd0c76g0' -and $_.SignatureKind -eq 'Store' } |
        Sort-Object Version -Descending)
    if ($packages.Count -eq 0) { throw '找不到当前 Windows 用户安装的微软商店版 Codex。' }

    $package = $packages[0]
    [xml]$manifest = Get-AppxPackageManifest -Package $package.PackageFullName
    $application = $manifest.SelectSingleNode("/*[local-name()='Package']/*[local-name()='Applications']/*[local-name()='Application'][@Id='App']")
    if (-not $application) { throw '找不到官方 Codex 桌面入口。' }
    $relativeExe = $application.GetAttribute('Executable').Replace('/', '\')
    if ($relativeExe -notmatch '^(?:[^\\/:]+\\)*(?:ChatGPT|Codex)\.exe$' -or $relativeExe -match '(?:^|\\)\.\.(?:\\|$)') {
        throw '该版 Codex 使用了未知的桌面入口。'
    }
    return @{
        Aumid = $package.PackageFamilyName + '!App'
        Executable = Join-Path $package.InstallLocation $relativeExe
        Name = Split-Path -Leaf $relativeExe
    }
}

function Get-CodexDesktopProcesses($Desktop) {
    Get-CimInstance Win32_Process -Filter ("Name='" + $Desktop.Name + "'") |
        Where-Object {
            $_.ExecutablePath -eq $Desktop.Executable -and
            $_.CommandLine -and $_.CommandLine -notmatch '(?:\s--type=|\s--crashpad-handler)'
        }
}

# Process ancestry, forced stop, and exit polling follow install/codex.ps1.
function Get-OwnProcessIds {
  $ids = @()
  $current = $PID
  while ($current -and ($ids -notcontains $current)) {
    $ids += $current
    $process = Get-CimInstance Win32_Process -Filter "ProcessId = $current" -ErrorAction Stop
    if ($process) {
      $current = $process.ParentProcessId
    } else {
      $current = 0
    }
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

function Close-ExistingCodexDesktop($Desktop) {
    $running = @(Get-CodexDesktopProcesses $Desktop)
    if ($running.Count -eq 0) { return }

    $sessionId = (Get-Process -Id $PID).SessionId
    $ownIds = @(Get-OwnProcessIds)
    if (@($running | Where-Object { $_.ProcessId -in $ownIds }).Count) {
        throw '请在 Codex 外部打开 PowerShell 后重新运行。'
    }

    $targets = @(
        foreach ($item in $running) {
            $process = Get-Process -Id $item.ProcessId -ErrorAction SilentlyContinue
            if ($process -and $process.SessionId -eq $sessionId -and
                $process.Path -eq $Desktop.Executable -and -not (Test-ProcessExited $process)) {
                $process
            }
        }
    )
    if ($targets.Count) {
        Write-Host '正在强制关闭 Codex 桌面版。'
        $targets | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    for ($attempt = 0; $attempt -le 10; $attempt++) {
        if ($attempt -gt 0) { Start-Sleep -Milliseconds 500 }
        $remaining = @($targets | Where-Object { -not (Test-ProcessExited $_) })
        if ($remaining.Count -eq 0 -and @(Get-CodexDesktopProcesses $Desktop).Count -eq 0) { return }
    }
    throw 'Codex 仍在运行。请在托盘彻底退出 Codex，若 CC Switch 自动打开它，先退出 CC Switch 再重试。'
}

function Start-OfficialCodexDesktop($Desktop, [string]$Arguments = '') {
    [uint32]$processId = 0
    $result = [UseGoodAI.CodexChinese.NativeActivation]::Activate($Desktop.Aumid, $Arguments, [ref]$processId)
    if ($result -lt 0 -or $processId -eq 0) {
        throw ('Windows 未能启动 Codex（HRESULT 0x{0:X8}）。' -f $result)
    }
    return $processId
}

function Get-CodexLoopbackPort {
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    try {
        $listener.Start()
        return $listener.LocalEndpoint.Port
    } finally {
        $listener.Stop()
    }
}

function Get-StartedDebugProcess($Desktop, [uint32]$ProcessId, [int]$Port) {
    $expected = '(?:^|\s)--remote-debugging-port=' + $Port + '(?:\s|$)'
    Get-CodexDesktopProcesses $Desktop | Where-Object {
        $_.ProcessId -eq $ProcessId -and $_.CommandLine -match $expected
    }
}

function Stop-StartedDebugProcess($Desktop, [uint32]$ProcessId, [int]$Port) {
    if (-not (Get-StartedDebugProcess $Desktop $ProcessId $Port)) {
        $remainingListener = Get-NetTCPConnection -State Listen -ErrorAction Stop |
            Where-Object { $_.OwningProcess -eq $ProcessId -and $_.LocalPort -eq $Port }
        if ($remainingListener) {
            throw '无法确认仍在监听的进程，请从托盘彻底退出 Codex 后再打开。'
        }
        return
    }
    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if (-not $process -or $process.HasExited) { return }
    $null = $process.CloseMainWindow()
    if ($process.WaitForExit(3000)) { return }
    if ((Get-StartedDebugProcess $Desktop $ProcessId $Port) -and -not $process.HasExited) {
        $process.Kill()
        if (-not $process.WaitForExit(5000)) { throw '调试进程未退出，请从托盘彻底退出 Codex。' }
    }
}

function New-ConfigError([string]$Message) {
    return [FormatException]::new($Message)
}

# TOML statement and key scanning adapted from codex-domestic-models/src/core.ps1.
function New-TomlSyntaxError([string]$Message, [string]$Text, [int]$Offset) {
  $prefix=$Text.Substring(0,[Math]::Min($Offset,$Text.Length))
  $line=1; foreach ($character in $prefix.ToCharArray()) { if ([int]$character -eq 10) { $line++ } }
  $column=$prefix.Length-$prefix.LastIndexOf("`n")
  return (New-ConfigError ($Message+' 第 '+$line+' 行，第 '+$column+' 列。'))
}

function Get-TomlString([string]$Raw) {
  $value = $Raw.Trim()
  if ($value -cmatch "^'[^'\r\n]*'$") { return $value.Substring(1, $value.Length - 2) }
  if ($value -cmatch '^"(?:[^"\\\r\n]|\\.)*"$') {
    try {
      $value = [regex]::Replace($value, '\\(?:U[0-9a-fA-F]{8}|e|[\s\S])', {
        param($match)
        $token=$match.Value
        if ($token -ceq '\e') { return '\u001b' }
        if ($token[1] -cne 'U' -or $token.Length -ne 10) { return $token }
        $decoded=[char]::ConvertFromUtf32([Convert]::ToInt32($token.Substring(2),16))
        $encoded=ConvertTo-Json -InputObject $decoded -Compress
        return $encoded.Substring(1,$encoded.Length-2)
      })
      return ($value | ConvertFrom-Json -ErrorAction Stop)
    } catch { throw (New-ConfigError 'TOML 字符串格式无效。') }
  }
  throw (New-ConfigError '配置键必须是单行 TOML 字符串。')
}

function Get-TomlKeyParts([string]$Raw) {
  $parts = New-Object 'System.Collections.Generic.List[string]'
  $pos = 0
  $pattern = '\s*("(?:[^"\\]|\\.)*"|''[^'']*''|[A-Za-z0-9_-]+)\s*'
  while ($pos -lt $Raw.Length) {
    $match = [regex]::Match($Raw.Substring($pos), '^' + $pattern)
    if (-not $match.Success) { throw (New-ConfigError '无法识别 TOML 字段或配置段。') }
    $key = $match.Groups[1].Value
    if ($key.StartsWith('"') -or $key.StartsWith("'")) { $key = Get-TomlString $key }
    $parts.Add($key)
    $pos += $match.Length
    if ($pos -eq $Raw.Length) { break }
    if ($Raw[$pos] -cne '.') { throw (New-ConfigError 'TOML 字段路径无效。') }
    $pos += 1
    if ($pos -eq $Raw.Length) { throw (New-ConfigError 'TOML 字段路径以点结尾。') }
  }
  if (-not $parts.Count) { throw (New-ConfigError '空 TOML 字段。') }
  return ,$parts.ToArray()
}

function Get-TomlStatements([string]$Text) {
  $records = New-Object 'System.Collections.Generic.List[object]'
  $depth = New-Object 'System.Collections.Generic.Stack[char]'
  $clean = New-Object System.Text.StringBuilder
  $start = 0; $quote = ''; $quoteStart = 0; $triple = $false; $escaped = $false; $comment = $false
  for ($i = 0; $i -lt $Text.Length; $i++) {
    $ch = [string]$Text[$i]
    if ($comment) {
      if ($ch -cne "`n") { [void]$clean.Append(' '); continue }
      $comment = $false
    }
    if ($quote) {
      [void]$clean.Append($ch)
      if ($escaped) { $escaped = $false; continue }
      if ($quote -ceq '"' -and $ch -ceq '\') { $escaped = $true; continue }
      if ($ch -ceq $quote) {
        if (-not $triple) { $quote = '' }
        elseif ($i + 2 -lt $Text.Length -and $Text.Substring($i, 3) -ceq ($quote * 3)) {
          $run = 3
          while ($run -lt 5 -and $i + $run -lt $Text.Length -and [string]$Text[$i + $run] -ceq $quote) { $run += 1 }
          [void]$clean.Append($Text.Substring($i + 1, $run - 1)); $i += $run - 1; $quote = ''; $triple = $false
        }
      } elseif ($ch -ceq "`n" -and -not $triple) { throw (New-TomlSyntaxError 'TOML 字符串未闭合。' $Text $quoteStart) }
      continue
    }
    if ($ch -ceq '#') { $comment = $true; [void]$clean.Append(' '); continue }
    if ($ch -ceq '"' -or $ch -ceq "'") {
      $quote = $ch; $quoteStart = $i; $triple = $i + 2 -lt $Text.Length -and $Text.Substring($i, 3) -ceq ($ch * 3)
      [void]$clean.Append($ch)
      if ($triple) { [void]$clean.Append($ch * 2); $i += 2 }
      continue
    }
    if ($ch -ceq '[' -or $ch -ceq '{') { $depth.Push([char]$ch) }
    if ($ch -ceq ']' -or $ch -ceq '}') {
      $expected = if ($ch -ceq ']') { '[' } else { '{' }
      if (-not $depth.Count -or [string]$depth.Pop() -cne $expected) { throw (New-TomlSyntaxError 'TOML 括号不匹配。' $Text $i) }
    }
    [void]$clean.Append($ch)
    if ($ch -ceq "`n" -and -not $depth.Count) {
      $records.Add(@{Start=$start; End=$i+1; Code=$clean.ToString()}); $start=$i+1; [void]$clean.Clear()
    }
  }
  if ($quote) { throw (New-TomlSyntaxError 'TOML 字符串未闭合。' $Text $quoteStart) }
  if ($depth.Count) { throw (New-TomlSyntaxError 'TOML 括号未闭合。' $Text $Text.Length) }
  if ($start -lt $Text.Length) { $records.Add(@{Start=$start; End=$Text.Length; Code=$clean.ToString()}) }
  return ,$records.ToArray()
}

function Set-CodexChineseLocale([string]$Text) {
    $newline = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $records = Get-TomlStatements $Text
    $scope = @()
    $firstTable = $Text.Length
    $desktopTable = $null
    $rootDesktopKeys = $false
    $desktopChildren = $false
    $locale = $null
    $assignment = 'localeOverride = "zh-CN"'

    foreach ($record in $records) {
        $code = $record.Code.Trim()
        if (-not $code) { continue }

        if ($code.StartsWith('[')) {
            $header = [regex]::Match($code, '^(\[\[?)([\s\S]*?)(\]\]?)$')
            if (-not $header.Success -or $header.Groups[1].Length -ne $header.Groups[3].Length) {
                throw (New-ConfigError 'TOML 配置段无效。')
            }
            if ($firstTable -eq $Text.Length) { $firstTable = $record.Start }
            $scope = Get-TomlKeyParts $header.Groups[2].Value.Trim()
            if ($scope[0] -ceq 'desktop') {
                if ($scope.Count -eq 1) {
                    if ($desktopTable -or $rootDesktopKeys -or $header.Groups[1].Value -ceq '[[') {
                        throw (New-ConfigError 'desktop 配置段重复或格式无效。')
                    }
                    $desktopTable = $record
                } else {
                    if ($scope[1] -ceq 'localeOverride') {
                        throw (New-ConfigError 'localeOverride 必须是单个字符串。')
                    }
                    $desktopChildren = $true
                }
            }
            continue
        }

        $keyValue = [regex]::Match($record.Code, '^(?<key>(?:"(?:[^"\\]|\\.)*"|''[^'']*''|[^"''=])+?)=')
        if (-not $keyValue.Success) { throw (New-ConfigError 'TOML 配置行无效。') }
        $parts = Get-TomlKeyParts $keyValue.Groups['key'].Value.Trim()
        $path = @($scope) + @($parts)
        if ($path[0] -cne 'desktop') { continue }
        if ($scope.Count -eq 0) {
            if ($parts.Count -eq 1) {
                throw (New-ConfigError 'desktop 使用内联表或标量，无法只改语言字段。')
            }
            $rootDesktopKeys = $true
        }
        if ($path[1] -cne 'localeOverride') { continue }
        if ($path.Count -ne 2 -or $locale) { throw (New-ConfigError 'localeOverride 重复或格式无效。') }
        $value = [regex]::Match($record.Code.Substring($keyValue.Length), '^\s*(?<value>"(?:[^"\\\r\n]|\\.)*"|''[^''\r\n]*'')\s*$')
        if (-not $value.Success) { throw (New-ConfigError 'localeOverride 必须是单行字符串。') }
        $locale = $value.Groups['value']
        $valueStart = $record.Start + $keyValue.Length + $locale.Index
    }

    if ($locale) {
        if ((Get-TomlString $locale.Value) -ceq 'zh-CN') { return $Text }
        return $Text.Remove($valueStart, $locale.Length).Insert($valueStart, '"zh-CN"')
    }
    if ($desktopTable) {
        $lead = if ($Text[$desktopTable.End - 1] -eq "`n") { '' } else { $newline }
        return $Text.Insert($desktopTable.End, $lead + $assignment + $newline)
    }
    if ($rootDesktopKeys) {
        $lead = if ($firstTable -gt 0 -and $Text[$firstTable - 1] -ne "`n") { $newline } else { '' }
        return $Text.Insert($firstTable, $lead + 'desktop.' + $assignment + $newline)
    }

    $lead = if ($Text.Length -and -not $Text.EndsWith("`n")) { $newline } else { '' }
    if ($desktopChildren) {
        return $Text.Insert($firstTable, '[desktop]' + $newline + $assignment + $newline + $newline)
    }
    return $Text + $lead + '[desktop]' + $newline + $assignment + $newline
}

function Get-CodexLocaleEdit([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($item -and ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint))) {
        throw (New-ConfigError 'config.toml 不是普通文件，已停止。')
    }
    [byte[]]$bytes = @()
    if ($item) { $bytes = [IO.File]::ReadAllBytes($Path) }
    $hasBom = $bytes.Count -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $offset = if ($hasBom) { 3 } else { 0 }
    $encoding = [Text.UTF8Encoding]::new($hasBom, $true)
    $text = $encoding.GetString([byte[]]$bytes, $offset, $bytes.Count - $offset)
    $updated = Set-CodexChineseLocale $text
    return @{
        Path = $Path
        Exists = [bool]$item
        Original = [Convert]::ToBase64String([byte[]]$bytes)
        Text = $updated
        Changed = $updated -cne $text
        Encoding = $encoding
    }
}

function Save-CodexLocaleEdit($Edit) {
    $current = Get-CodexLocaleEdit $Edit.Path
    if ($current.Exists -ne $Edit.Exists -or $current.Original -cne $Edit.Original) {
        throw 'config.toml 在运行期间被修改，请重新运行。'
    }
    if (-not $Edit.Changed) { return }

    $parent = [IO.Path]::GetDirectoryName($Edit.Path)
    $null = [IO.Directory]::CreateDirectory($parent)
    $id = [Guid]::NewGuid().ToString('N')
    $temp = $Edit.Path + '.codex-zh.tmp.' + $id
    try {
        [IO.File]::WriteAllText($temp, $Edit.Text, $Edit.Encoding)
        if ($Edit.Exists) {
            [IO.File]::Replace($temp, $Edit.Path, $Edit.Path + '.codex-zh.bak.' + $id)
        } else {
            [IO.File]::Move($temp, $Edit.Path)
        }
    } finally {
        if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) }
    }
}

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
    $expressionSource = @'
// The expression runs in the official Codex renderer through Electron CDP.
(async (write, timeoutMs) => {
    const until = Date.now() + timeoutMs;
    let client;
    do {
        const root = globalThis.__STATSIG__;
        client = root?.firstInstance ?? root?.instance?.();
        if (client?.loadingStatus === 'Ready') break;
        await new Promise(resolve => setTimeout(resolve, 200));
    } while (Date.now() < until);
    if (client?.loadingStatus !== 'Ready' || typeof client.dataAdapter?._getCacheKey !== 'function') {
        throw new Error('Statsig did not become ready or has an unsupported cache adapter.');
    }

    const context = client.getContext();
    const cacheKey = client.dataAdapter._getCacheKey(context.user);
    if (typeof cacheKey !== 'string' || !cacheKey.startsWith('statsig.cached.evaluations.')) {
        throw new Error('Unrecognized Statsig cache key.');
    }

    const cacheText = localStorage.getItem(cacheKey);
    const wrapper = cacheText === null ? null : JSON.parse(cacheText);
    if (cacheText !== null && (!wrapper || typeof wrapper !== 'object' || Array.isArray(wrapper))) {
        throw new Error('Invalid existing Statsig cache record.');
    }
    const stringData = typeof wrapper?.data === 'string';
    let payload = wrapper ? (stringData ? JSON.parse(wrapper.data) : wrapper.data) : null;
    if (write && cacheText === null) {
        if (context.values?.has_updates === true) {
            payload = JSON.parse(JSON.stringify(context.values));
        } else {
            // The upstream bootstrap format is used only for a missing current key.
            payload = {
                has_updates: true,
                response_format: 'init-v2',
                time: Date.now(),
                feature_gates: {},
                dynamic_configs: {},
                layer_configs: { '72216192': { v: '0', r: 'usegoodai-codex-zh', s: [], is_device_based: true } },
                values: { '0': { enable_i18n: true, locale_source: 'IDE' } },
                param_stores: {},
                sdk_flags: {},
                exposures: {}
            };
        }
    }
    if (!payload || typeof payload.layer_configs !== 'object' || payload.layer_configs === null) {
        throw new Error('No supported Statsig evaluations are available for the current client.');
    }

    const knownLayers = ['72216192', '4269166702'].filter(key =>
        Object.prototype.hasOwnProperty.call(payload.layer_configs, key));
    if (knownLayers.length !== 1) {
        throw new Error('The localization layer could not be identified unambiguously.');
    }
    const layerKey = knownLayers[0];
    const layer = payload.layer_configs[layerKey];
    if (!layer || typeof layer !== 'object' || Array.isArray(layer)) {
        throw new Error('Unsupported localization layer.');
    }

    const value = layer.v !== undefined ? payload.values?.[String(layer.v)] : (layer.value ?? layer);
    if (!value || typeof value.enable_i18n !== 'boolean') {
        throw new Error('The localization flag is missing or invalid.');
    }

    if (write && (!wrapper || value.enable_i18n !== true)) {
        if (layer.v !== undefined && value.enable_i18n !== true) {
            // Layer value slots can be shared with unrelated evaluations.
            let index = 0;
            while (Object.prototype.hasOwnProperty.call(payload.values, String(index))) index += 1;
            payload.values[String(index)] = { ...value, enable_i18n: true };
            layer.v = String(index);
        } else {
            value.enable_i18n = true;
        }
        const record = wrapper ?? {
            source: 'Bootstrap',
            receivedAt: Date.now(),
            stableID: context.stableID ?? null,
            fullUserHash: null
        };
        record.data = wrapper && !stringData ? payload : JSON.stringify(payload);
        localStorage.setItem(cacheKey, JSON.stringify(record));
    }

    const live = client.getLayer?.('72216192', { disableExposureLog: true })?.get('enable_i18n', null);
    return { enabled: write || value.enable_i18n === true, liveEnabled: live === true };
})
'@
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
