param(
    [Parameter(Mandatory)][string]$Script,
    [Parameter(Mandatory)][ValidateSet('block', 'blackhole', 'online', 'longhang', 'dns-fail', 'polluted')][string]$Network,
    [Parameter(Mandatory)][ValidateSet('pass', 'record')][string]$Expect,
    [Parameter(Mandatory)][ValidateSet('login', 'apikey')][string]$Auth,
    [Parameter(Mandatory)][ValidateSet('override', 'system')][string]$Locale,
    [Parameter(Mandatory)][string]$ReportDir,
    [int]$Stress = 0
)
$ErrorActionPreference = 'Stop'
$null = New-Item -ItemType Directory -Force -Path $ReportDir
$repo = Split-Path $PSScriptRoot
$scriptPath = Join-Path $repo $Script
$temp = Join-Path $env:RUNNER_TEMP 'codex-chinese-work'
$null = New-Item -ItemType Directory -Force -Path $temp
$ps = Join-Path $PSHOME 'powershell.exe'
$configDir = Join-Path $env:USERPROFILE '.codex'
$config = Join-Path $configDir 'config.toml'
$report = [ordered]@{ script = $Script; network = $Network; expect = $Expect; auth = $Auth; locale = $Locale; failures = @() }
$reportPath = Join-Path $ReportDir 'report.json'

function Save-Report { $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $reportPath -Encoding UTF8 }
function Add-Failure([string]$Text) { $report.failures += $Text; Write-Warning $Text; Save-Report }
function Wait-Until([scriptblock]$Condition, [double]$Seconds, [int]$StepMs = 250) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    do {
        $value = & $Condition
        if ($value) { return $value }
        Start-Sleep -Milliseconds $StepMs
    } while ($watch.Elapsed.TotalSeconds -lt $Seconds)
    return $null
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing, UIAutomationClient, UIAutomationTypes, System.Net.Http
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class CiDesktop {
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr window, int command);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr window, IntPtr surface, uint flags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out RECT rect);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("ole32.dll")] private static extern int CoCreateInstance(ref Guid clsid, IntPtr outer, uint context, ref Guid iid, out IntPtr result);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate int Activate(IntPtr self, [MarshalAs(UnmanagedType.LPWStr)] string aumid, [MarshalAs(UnmanagedType.LPWStr)] string arguments, int options, out uint processId);
    public static int Launch(string aumid, string arguments, out uint processId) {
        Guid clsid = new Guid("45BA127D-10A8-46EA-8AB7-56EA9078943C");
        Guid iid = new Guid("2e941141-7f97-4756-ba1d-9decde894a3d");
        IntPtr manager;
        int hr = CoCreateInstance(ref clsid, IntPtr.Zero, 4, ref iid, out manager);
        if (hr < 0) { processId = 0; return hr; }
        try {
            IntPtr method = Marshal.ReadIntPtr(Marshal.ReadIntPtr(manager), 3 * IntPtr.Size);
            Activate call = (Activate)Marshal.GetDelegateForFunctionPointer(method, typeof(Activate));
            return call(manager, aumid, arguments, 0, out processId);
        } finally { Marshal.Release(manager); }
    }
}
'@

# ---------- Official Codex ----------
function Install-Codex {
    if (-not (Get-AppxPackage -Name OpenAI.Codex)) {
        $msix = Join-Path $temp 'ChatGPT-arm64.msix'
        & curl.exe -fsSL --retry 2 --connect-timeout 20 --max-time 400 'https://persistent.oaistatic.com/codex-app-prod/ChatGPT-arm64.msix' -o $msix
        if ($LASTEXITCODE -ne 0) { throw 'OpenAI MSIX download failed.' }
        $signature = Get-AuthenticodeSignature -LiteralPath $msix
        $report.download = @{ sha256 = (Get-FileHash $msix).Hash; signature = $signature.Status.ToString(); signer = $signature.SignerCertificate.Subject }
        Add-AppxPackage -Path $msix
    }
    $package = Get-AppxPackage -Name OpenAI.Codex | Sort-Object Version -Descending | Select-Object -First 1
    [xml]$manifest = Get-Content -Raw -LiteralPath (Join-Path $package.InstallLocation 'AppxManifest.xml')
    $app = @($manifest.Package.Applications.Application) | Where-Object Id -EQ 'App' | Select-Object -First 1
    $exe = Join-Path $package.InstallLocation ($app.Executable.Replace('/', '\'))
    $script:codex = @{ Aumid = "$($package.PackageFamilyName)!App"; Exe = $exe; Dir = $package.InstallLocation }
    $report.codex = @{ displayName = [string]$manifest.Package.Properties.DisplayName; package = $package.PackageFullName; version = $package.Version.ToString(); signatureKind = $package.SignatureKind.ToString(); executable = $app.Executable }
    Save-Report
}
function Get-CodexProcesses {
    @(Get-CimInstance Win32_Process | Where-Object { $_.Name -in @('ChatGPT.exe', 'Codex.exe', 'codex.exe') })
}
function Get-CodexMain {
    @(Get-CodexProcesses | Where-Object { $_.ExecutablePath -eq $script:codex.Exe -and $_.CommandLine -notmatch '--type=|crashpad' })
}
function Start-Codex([string]$Arguments = '') {
    [uint32]$id = 0
    $hr = [CiDesktop]::Launch($script:codex.Aumid, $Arguments, [ref]$id)
    if ($hr -lt 0) { throw ('Activation failed 0x{0:X8}' -f $hr) }
    if (-not (Wait-Until { Get-CodexMain } 30)) { throw 'Codex did not start.' }
    return $id
}
function Stop-Codex {
    $all = Get-CodexProcesses
    foreach ($item in $all) { Stop-Process -Id $item.ProcessId -Force -ErrorAction SilentlyContinue }
    if (-not (Wait-Until { -not (Get-CodexProcesses) } 15)) { throw 'Harness could not stop Codex.' }
}

# ---------- Runner first-use screen ----------
function Complete-PrivacyScreen {
    $clicked = @()
    for ($attempt = 0; $attempt -lt 8; $attempt++) {
        $found = $false
        foreach ($window in [Windows.Automation.AutomationElement]::RootElement.FindAll([Windows.Automation.TreeScope]::Children, [Windows.Automation.Condition]::TrueCondition)) {
            try {
                $elements = @($window) + @($window.FindAll([Windows.Automation.TreeScope]::Descendants, [Windows.Automation.Condition]::TrueCondition))
            } catch { continue }
            if (-not (@($elements | ForEach-Object { $_.Current.Name }) -match 'privacy settings for your device')) { continue }
            $found = $true
            $button = $elements | Where-Object { $_.Current.ControlType -eq [Windows.Automation.ControlType]::Button -and $_.Current.Name -in @('Accept', 'Next') } | Sort-Object { if ($_.Current.Name -eq 'Accept') { 0 } else { 1 } } | Select-Object -First 1
            if ($button) {
                $pattern = $null
                if ($button.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) { $pattern.Invoke(); $clicked += $button.Current.Name }
            }
        }
        if (-not $found) { break }
        Start-Sleep -Seconds 2
    }
    if ($clicked.Count) { $report.privacyClicks = @($report.privacyClicks) + $clicked | Where-Object { $_ } }
}

# ---------- Screen evidence ----------
function Save-Screen([string]$Label) {
    Complete-PrivacyScreen
    $main = Get-CodexMain | Select-Object -First 1
    $gui = if ($main) { Get-Process -Id $main.ProcessId -ErrorAction SilentlyContinue } else { $null }
    if ($gui -and $gui.MainWindowHandle -ne [IntPtr]::Zero) {
        $null = [CiDesktop]::ShowWindowAsync($gui.MainWindowHandle, 3)
        $null = [CiDesktop]::SetForegroundWindow($gui.MainWindowHandle)
        Start-Sleep -Milliseconds 800
    }
    $bounds = [Windows.Forms.SystemInformation]::VirtualScreen
    $bitmap = New-Object Drawing.Bitmap($bounds.Width, $bounds.Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.Size)
        $bitmap.Save((Join-Path $ReportDir "$Label.png"), [Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
    if ($gui -and $gui.MainWindowHandle -ne [IntPtr]::Zero) {
        $rect = New-Object CiDesktop+RECT
        if ([CiDesktop]::GetWindowRect($gui.MainWindowHandle, [ref]$rect) -and ($rect.Right - $rect.Left) -gt 0 -and ($rect.Bottom - $rect.Top) -gt 0) {
            $image = New-Object Drawing.Bitmap(($rect.Right - $rect.Left), ($rect.Bottom - $rect.Top))
            $surface = [Drawing.Graphics]::FromImage($image)
            try {
                $hdc = $surface.GetHdc()
                try { $printed = [CiDesktop]::PrintWindow($gui.MainWindowHandle, $hdc, 2) } finally { $surface.ReleaseHdc($hdc) }
                if ($printed) { $image.Save((Join-Path $ReportDir "$Label-window.png"), [Drawing.Imaging.ImageFormat]::Png) }
            } finally { $surface.Dispose(); $image.Dispose() }
        }
    }
    $pids = @(Get-CodexProcesses | ForEach-Object ProcessId)
    $labels = @(
        foreach ($window in [Windows.Automation.AutomationElement]::RootElement.FindAll([Windows.Automation.TreeScope]::Children, [Windows.Automation.Condition]::TrueCondition)) {
            if ($window.Current.ProcessId -notin $pids) { continue }
            $window.Current.Name
            foreach ($element in $window.FindAll([Windows.Automation.TreeScope]::Descendants, [Windows.Automation.Condition]::TrueCondition)) {
                if ($element.Current.Name) { $element.Current.Name }
            }
        }
    ) | Where-Object { $_ } | Select-Object -Unique -First 150
    $labels | Set-Content -LiteralPath (Join-Path $ReportDir "$Label.txt") -Encoding UTF8
    return @{ labels = $labels.Count; chineseLabels = @($labels | Where-Object { $_ -match '[一-鿿]' }) | Select-Object -First 12 }
}

# ---------- Objective i18n state through a separate debug launch ----------
$snapshotJs = @'
(async () => {
    const started = Date.now();
    const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
    const getClient = () => {
        const root = window.__STATSIG__ || globalThis.__STATSIG__;
        if (!root) return null;
        return root.firstInstance || (typeof root.instance === "function" ? root.instance() : null);
    };
    let client = getClient();
    while ((!client || String(client.loadingStatus || "") !== "Ready") && Date.now() - started < 60000) {
        await sleep(250);
        client = getClient();
    }
    const readyMs = Date.now() - started;
    const settle = Date.now();
    await sleep(3000);
    while (Date.now() - settle < 25000) {
        const visible = (document.body?.innerText || "").replace(/Thinking/g, "").trim();
        if (visible.length > 30) break;
        await sleep(500);
    }
    const caches = Object.keys(localStorage).filter(key => key.startsWith("statsig.cached.evaluations.")).map(key => {
        try {
            const wrapper = JSON.parse(localStorage.getItem(key));
            const payload = typeof wrapper.data === "string" ? JSON.parse(wrapper.data) : wrapper.data;
            let value = null;
            for (const meta of Object.values(payload?.layer_configs || {})) {
                if (!meta || typeof meta !== "object") continue;
                const found = [meta.v !== undefined && payload.values ? payload.values[String(meta.v)] : null, meta.value, meta]
                    .find(item => item && Object.prototype.hasOwnProperty.call(item, "enable_i18n"));
                if (found) { value = found; break; }
            }
            return { key, source: wrapper.source ?? null, enableI18n: value?.enable_i18n ?? null, localeSource: value?.locale_source ?? null };
        } catch (error) { return { key, error: String(error) }; }
    });
    let live = null, currentKey = null, liveError = null;
    try {
        live = client?.getLayer("72216192", { disableExposureLog: true })?.get("enable_i18n", null) ?? null;
        currentKey = client ? String(client.dataAdapter._getCacheKey(client.getContext().user)) : null;
    } catch (error) { liveError = String(error); }
    const text = (document.body?.innerText || "").slice(0, 800);
    return JSON.stringify({
        statsigStatus: client?.loadingStatus ?? null, readyMs, liveEnableI18n: live, liveError, currentKey,
        htmlLang: document.documentElement.lang, caches,
        cjkCount: (text.match(/[一-鿿]/g) || []).length, textSample: text
    });
})()
'@

function Invoke-Cdp([int]$Port, [string]$Expression = '', [string]$Method = 'Runtime.evaluate', [object]$Parameters = $null) {
    $handler = [Net.Http.HttpClientHandler]::new(); $handler.UseProxy = $false
    $http = [Net.Http.HttpClient]::new($handler); $http.Timeout = [TimeSpan]::FromSeconds(3)
    try {
        $socketUrl = Wait-Until {
            try {
                $targets = ConvertFrom-Json $http.GetStringAsync("http://127.0.0.1:$Port/json/list").GetAwaiter().GetResult()
                foreach ($target in @($targets)) { if ($target.type -eq 'page' -and $target.url -eq 'app://-/index.html') { return $target.webSocketDebuggerUrl } }
            } catch { }
        } 90 500
    } finally { $http.Dispose() }
    if (-not $socketUrl) { throw "No Codex page on debug port $Port." }
    $socket = [Net.WebSockets.ClientWebSocket]::new(); $socket.Options.Proxy = $null
    $cancel = [Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds(90))
    try {
        $socket.ConnectAsync([Uri]$socketUrl, $cancel.Token).GetAwaiter().GetResult()
        if ($null -eq $Parameters) { $Parameters = @{ expression = $Expression; awaitPromise = $true; returnByValue = $true } }
        $body = @{ id = 1; method = $Method; params = $Parameters } | ConvertTo-Json -Depth 6 -Compress
        $bytes = [Text.Encoding]::UTF8.GetBytes($body)
        $socket.SendAsync([ArraySegment[byte]]::new($bytes), 'Text', $true, $cancel.Token).GetAwaiter().GetResult()
        $buffer = [byte[]]::new(65536)
        while ($true) {
            $stream = [IO.MemoryStream]::new()
            do {
                $chunk = $socket.ReceiveAsync([ArraySegment[byte]]::new($buffer), $cancel.Token).GetAwaiter().GetResult()
                $stream.Write($buffer, 0, $chunk.Count)
            } while (-not $chunk.EndOfMessage)
            $message = ConvertFrom-Json ([Text.Encoding]::UTF8.GetString($stream.ToArray()))
            if ($message.PSObject.Properties['id'] -and $message.id -eq 1) { break }
        }
        if ($message.PSObject.Properties['error']) { throw ('CDP error: ' + $message.error.message) }
        if ($message.result.PSObject.Properties['exceptionDetails']) { throw ('Page error: ' + ($message.result.exceptionDetails | ConvertTo-Json -Compress -Depth 5)) }
        if ($Method -ne 'Runtime.evaluate') { return $message.result }
        return ConvertFrom-Json $message.result.result.value
    } finally { $socket.Dispose(); $cancel.Dispose() }
}
function Get-I18nSnapshot([string]$Label, [string]$Extra = '') {
    Stop-Codex
    $null = Start-Codex ('--remote-debugging-port=9333 --remote-allow-origins=http://127.0.0.1:9333 ' + $Extra).Trim()
    try { $snapshot = @(Invoke-Cdp 9333 $snapshotJs)[-1] }
    catch { $snapshot = [pscustomobject]@{ error = $_.Exception.Message } }
    finally {
        Start-Sleep -Seconds 6
        Stop-Codex
    }
    $report["snapshot_$Label"] = $snapshot
    Save-Report
    return $snapshot
}

# ---------- Network conditions without VPN ----------
$blockedHosts = @(
    'chatgpt.com', 'www.chatgpt.com', 'ab.chatgpt.com', 'chat.openai.com', 'openai.com', 'www.openai.com',
    'api.openai.com', 'auth.openai.com', 'auth0.openai.com', 'platform.openai.com', 'cdn.openai.com',
    'oaistatic.com', 'cdn.oaistatic.com', 'persistent.oaistatic.com', 'oaiusercontent.com', 'files.oaiusercontent.com',
    'statsig.com', 'api.statsig.com', 'statsigapi.net', 'events.statsigapi.net', 'api.statsigcdn.com',
    'featuregates.org', 'featureassets.org', 'prodregistryv2.org', 'assetsconfigcdn.org', 'beyondwickedmapping.org',
    'o33249.ingest.sentry.io', 'o33249.ingest.us.sentry.io', 'browser-intake-datadoghq.com', 'rum.browser-intake-datadoghq.com'
)
function Set-NetworkCondition {
    if ($Network -in @('longhang', 'dns-fail')) {
        $readyFile = Join-Path $temp 'network-ready'
        $script:networkFixture = Start-Process -FilePath (Get-Command python).Source -ArgumentList @("`"$PSScriptRoot/codex-chinese-network.py`"", '--mode', $Network, '--ready', "`"$readyFile`"") -PassThru -WindowStyle Hidden
        if (-not (Wait-Until { Test-Path $readyFile } 15)) { throw 'Network fixture failed to start' }
    }
    switch ($Network) {
        'block' {
            Set-NetFirewallProfile -All -Enabled True
            $exes = @(Get-ChildItem -LiteralPath $script:codex.Dir -Recurse -Filter *.exe -ErrorAction SilentlyContinue)
            $index = 0
            foreach ($exe in $exes) {
                $index += 1
                $null = New-NetFirewallRule -DisplayName "ci-block-codex-$index" -Direction Outbound -Action Block -Program $exe.FullName
            }
            $report.networkSetup = @{ firewall = 'outbound blocked'; programs = @($exes | ForEach-Object Name) }
        }
        'blackhole' {
            $hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
            $lines = foreach ($name in $blockedHosts) { "192.0.2.1 $name" }
            Add-Content -LiteralPath $hostsPath -Value $lines -Encoding ASCII
            ipconfig /flushdns | Out-Null
            $report.networkSetup = @{ hosts = '192.0.2.1 (unroutable, connections hang)'; names = $blockedHosts }
        }
        'longhang' {
            $hostsPath = Join-Path $env:SystemRoot 'System32/drivers/etc/hosts'
            Add-Content -LiteralPath $hostsPath -Value @($blockedHosts | ForEach-Object { "127.0.0.2 $_" }) -Encoding ASCII
            ipconfig /flushdns | Out-Null
            $report.networkSetup = @{ note = 'TLS accepted but never replied to for five minutes'; target = '127.0.0.2:443' }
        }
        'polluted' {
            $hostsPath = Join-Path $env:SystemRoot 'System32/drivers/etc/hosts'
            Add-Content -LiteralPath $hostsPath -Value @($blockedHosts | ForEach-Object { "127.0.0.1 $_" }) -Encoding ASCII
            ipconfig /flushdns | Out-Null
            $report.networkSetup = @{ note = 'DNS polluted to loopback, connection refused' }
        }
        'dns-fail' {
            $interfaces = @(Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { @($_.ServerAddresses).Count -gt 0 })
            foreach ($adapter in $interfaces) {
                $adapter | Set-DnsClientServerAddress -ServerAddresses @('127.0.0.1')
            }
            ipconfig /flushdns | Out-Null
            $report.networkSetup = @{ note = 'Local DNS responds NXDOMAIN'; adapters = @($interfaces | ForEach-Object InterfaceAlias) }
        }
        'online' { $report.networkSetup = @{ note = 'runner network unchanged' } }
    }
    Save-Report
}
function Get-RemoteConnections {
    $pids = @(Get-CodexProcesses | ForEach-Object ProcessId)
    @(Get-NetTCPConnection -ErrorAction SilentlyContinue | Where-Object {
        $_.OwningProcess -in $pids -and $_.RemoteAddress -notin @('127.0.0.1', '::1', '0.0.0.0', '::') -and $_.State -eq 'Established'
    } | ForEach-Object { "$($_.RemoteAddress):$($_.RemotePort)" }) | Select-Object -Unique
}

# ---------- Disk evidence of Codex local storage ----------
function Get-StorageEvidence([string]$Label) {
    $root = Join-Path $env:LOCALAPPDATA 'Packages\OpenAI.Codex_2p2nqsd0c76g0'
    $dirs = @(Get-ChildItem -LiteralPath $root -Recurse -Directory -Filter leveldb -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match 'Local Storage' })
    $latin1 = [Text.Encoding]::GetEncoding(28591)
    $evidence = [ordered]@{ dirs = @() }
    foreach ($dir in $dirs) {
        $files = foreach ($file in Get-ChildItem -LiteralPath $dir.FullName -File -ErrorAction SilentlyContinue) {
            $row = [ordered]@{ name = $file.Name; size = $file.Length; written = $file.LastWriteTimeUtc.ToString('HH:mm:ss.fff') }
            if ($file.Extension -in @('.log', '.ldb')) {
                try {
                    $text = $latin1.GetString([IO.File]::ReadAllBytes($file.FullName))
                    $row.statsigKeys = ([regex]::Matches($text, 'statsig\.cached\.evaluations\.\d+')).Count
                    $row.marker = ([regex]::Matches($text, 'codex-current-key')).Count
                } catch { $row.readError = $_.Exception.Message }
            }
            $row
        }
        $evidence.dirs += @{ path = $dir.FullName.Substring($root.Length); files = @($files) }
    }
    $evidence.packageProcesses = @(Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($script:codex.Dir, [StringComparison]::OrdinalIgnoreCase) } | ForEach-Object { "$($_.ProcessId) $($_.Name)" })
    $report["disk_$Label"] = $evidence
    Save-Report
}

# ---------- Run the published one-line command ----------
function Invoke-OneLine([string]$Label) {
    $portFile = Join-Path $temp "$Label-port"
    $server = Start-Job -ArgumentList $scriptPath, $portFile -ScriptBlock {
        param($Path, $PortPath)
        $content = [IO.File]::ReadAllBytes($Path)
        $listen = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
        $listen.Start()
        try {
            [IO.File]::WriteAllText($PortPath, [string]$listen.LocalEndpoint.Port)
            $client = $listen.AcceptTcpClient()
            try {
                $stream = $client.GetStream()
                $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::ASCII, $false, 1024, $true)
                do { $line = $reader.ReadLine() } while ($line)
                $head = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: text/plain; charset=utf-8`r`nContent-Length: $($content.Length)`r`nConnection: close`r`n`r`n")
                $stream.Write($head, 0, $head.Length); $stream.Write($content, 0, $content.Length); $stream.Flush()
            } finally { $client.Dispose() }
        } finally { $listen.Stop() }
    }
    $port = Wait-Until { if (Test-Path $portFile) { Get-Content $portFile } } 20
    if (-not $port) { throw 'Local HTTP fixture did not start.' }
    $entry = Join-Path $temp "$Label-entry.ps1"
    # Record Chinese output faithfully; the command itself runs unchanged.
    "[Console]::OutputEncoding = [Text.Encoding]::UTF8`r`nirm http://127.0.0.1:$port/chinese.ps1 | iex" | Set-Content -LiteralPath $entry -Encoding ASCII

    $original = @(Get-CodexMain | ForEach-Object { Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue } | Where-Object { $_ })
    $stdout = Join-Path $ReportDir "$Label-stdout.txt"
    $stderr = Join-Path $ReportDir "$Label-stderr.txt"
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $child = Start-Process -FilePath $ps -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $entry) -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -WindowStyle Hidden
    $null = $child.Handle
    $closedAt = $null; $debugSeen = $null; $outputAt = $null
    $lastLength = 0; $lastOutputSeconds = 0; $outputGaps = @(); $progressLines = @()
    do {
        if (Test-Path $stdout) {
            # Read metadata only: the child owns the redirected file while running.
            $liveLength = (Get-Item -LiteralPath $stdout).Length
            if ($liveLength -gt $lastLength) {
                $outputGaps += ($watch.Elapsed.TotalSeconds - $lastOutputSeconds)
                $lastOutputSeconds = $watch.Elapsed.TotalSeconds
                $lastLength = $liveLength
            }
        }
        if (-not $outputAt -and (Test-Path $stdout) -and (Get-Item $stdout).Length -gt 0) { $outputAt = $watch.Elapsed.TotalSeconds }
        if ($original.Count -and -not $closedAt -and -not @($original | Where-Object { -not $_.HasExited }).Count) { $closedAt = $watch.Elapsed.TotalSeconds }
        if (-not $debugSeen) {
            $debug = Get-CodexMain | Where-Object CommandLine -Match '--remote-debugging-port=(\d+)' | Select-Object -First 1
            if ($debug) { $debugSeen = @{ seconds = $watch.Elapsed.TotalSeconds; port = [int]([regex]::Match($debug.CommandLine, '--remote-debugging-port=(\d+)').Groups[1].Value) } }
        }
        if ($child.HasExited) { break }
        Start-Sleep -Milliseconds 250
    } while ($watch.Elapsed.TotalSeconds -lt 300)
    $timedOut = -not $child.HasExited
    if ($timedOut) { $child.Kill() }
    $child.WaitForExit()
    Receive-Job $server -ErrorAction SilentlyContinue | Out-Null
    Remove-Job $server -Force
    $out = (Get-Content -Raw -Encoding UTF8 -LiteralPath $stdout -ErrorAction SilentlyContinue) + (Get-Content -Raw -Encoding UTF8 -LiteralPath $stderr -ErrorAction SilentlyContinue)
    Start-Sleep -Seconds 2
    $row = [ordered]@{
        maxOutputGap = [Math]::Round(($outputGaps | Measure-Object -Maximum).Maximum, 2)
        chineseProgressLines = @($out -split "`r?`n" | Where-Object { $_ -match '已等待.*秒' })
        exitCode = $child.ExitCode; seconds = [Math]::Round($watch.Elapsed.TotalSeconds, 1); timedOut = $timedOut
        codexWasRunning = $original.Count -gt 0
        closeSeconds = if ($closedAt) { [Math]::Round($closedAt, 1) } else { $null }
        firstOutputSeconds = if ($outputAt) { [Math]::Round($outputAt, 1) } else { $null }
        closeAfterOutputSeconds = if ($closedAt -and $outputAt) { [Math]::Round($closedAt - $outputAt, 1) } else { $null }
        debugLaunch = $debugSeen
        success = ($out -match '\[成功\]' -or $out -match '已启用语言开关并设置简体中文') -and $out -notmatch '\[失败\]' -and $child.ExitCode -eq 0 -and -not $timedOut
        leftDebugProcesses = @(Get-CodexMain | Where-Object CommandLine -Match '--remote-debugging-port=').Count
        leftListeners = if ($debugSeen) { @(Get-NetTCPConnection -State Listen -LocalPort $debugSeen.port -ErrorAction SilentlyContinue).Count } else { 0 }
        listenerOwners = if ($debugSeen) { @(Get-NetTCPConnection -State Listen -LocalPort $debugSeen.port -ErrorAction SilentlyContinue | ForEach-Object { $owner = Get-CimInstance Win32_Process -Filter "ProcessId = $($_.OwningProcess)" -ErrorAction SilentlyContinue; "$($_.OwningProcess) $($owner.Name) $($owner.CommandLine)" }) } else { @() }
        leftListenersAfter10s = $null
        codexRunningAfter = @(Get-CodexMain).Count
        messages = @(($out -split "`r?`n") | Where-Object { $_ -match '成功|失败|原因|错误|警告|WARN|Error|error|未能|Codex' } | Select-Object -Last 14)
    }
    Get-StorageEvidence "after-$Label"
    if ($row.leftListeners) {
        Start-Sleep -Seconds 8
        $row.leftListenersAfter10s = @(Get-NetTCPConnection -State Listen -LocalPort $debugSeen.port -ErrorAction SilentlyContinue).Count
    }
    $row.windowEvidence = Save-Screen "closed-$Label"
    $report["run_$Label"] = $row
    Save-Report
    return $row
}

function Complete-AppOnboarding {
    $onboardingJs = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'chinese-onboarding.js'))
    Stop-Codex
    $null = Start-Codex '--remote-debugging-port=9333 --remote-allow-origins=http://127.0.0.1:9333'
    $report.onboarding = @()
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $mainReady = $false
    try {
        while ($watch.Elapsed.TotalSeconds -lt 150) {
            $state = @(Invoke-Cdp 9333 $onboardingJs)[-1]
            $report.onboarding += @{ seconds = [Math]::Round($watch.Elapsed.TotalSeconds, 1); action = $state.action; done = $state.done }
            Save-Report
            if ($state.done) {
                $report.mainBeforeRepair = $state
                $report.screen_main_before = Save-Screen 'main-before-repair'
                $mainReady = $true
                break
            }
            Start-Sleep -Seconds 1
        }
        if (-not $mainReady) { throw 'The API-key fixture did not reach the main conversation screen.' }
    } finally { Stop-Codex }
    Save-Report
}

# ---------- Scenario ----------
$report.environment = @{ os = (Get-CimInstance Win32_OperatingSystem).Caption; arch = $env:PROCESSOR_ARCHITECTURE; shell = $PSVersionTable.PSVersion.ToString(); sha = $env:GITHUB_SHA; scriptSha256 = (Get-FileHash $scriptPath).Hash }
$tokens = $null; $errors = $null
$null = [Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText($scriptPath, [Text.Encoding]::UTF8), [ref]$tokens, [ref]$errors)
$report.parseErrors = @($errors | ForEach-Object { $_.Message })
Save-Report
if ($errors.Count) { Add-Failure 'Published script has PowerShell parse errors.' }

$hostsPath = Join-Path $env:SystemRoot 'System32/drivers/etc/hosts'
$originalHosts = [IO.File]::ReadAllBytes($hostsPath)
$originalDns = @(Get-DnsClientServerAddress -AddressFamily IPv4)
try {

Install-Codex
Set-NetworkCondition
$null = New-Item -ItemType Directory -Force -Path $configDir
$configText = "# ci-unchanged`n"
if ($Auth -eq 'apikey') {
    # Same shape as install/codex.ps1 writes; a closed local port and a fake key keep the relay out of the test.
    $configText += "model_provider = `"OpenAI`"`nmodel = `"gpt-6.1-sol`"`n`n[model_providers.OpenAI]`nname = `"OpenAI`"`nbase_url = `"http://127.0.0.1:9/v1`"`nwire_api = `"responses`"`nrequires_openai_auth = true`n`n"
    "{`n  `"OPENAI_API_KEY`": `"sk-ci-fake-key-not-real`"`n}`n" | Set-Content -LiteralPath (Join-Path $configDir 'auth.json') -Encoding ASCII
}
if ($Locale -eq 'override') {
    # Codex 设置里选了简体中文；测试机系统是英文。
    $configText += "[desktop]`nlocaleOverride = `"zh-CN`"`n"
} else {
    # 没选过语言的用户：把 Windows 语言列表和区域格式设为中文。
    Set-WinUserLanguageList -LanguageList zh-CN, en-US -Force
    Set-Culture zh-CN
    $report.windowsLanguages = @((Get-WinUserLanguageList) | ForEach-Object LanguageTag)
}
$configText | Set-Content -LiteralPath $config -Encoding ASCII
Complete-PrivacyScreen
if ($Auth -eq 'apikey') { Complete-AppOnboarding }

$baseline = Get-I18nSnapshot 'baseline'
$report.baselineRemote = 'see snapshot'
$null = Start-Codex
Start-Sleep -Seconds 50
$report.remoteBefore = @(Get-RemoteConnections)
$report.screen_before = Save-Screen 'before'
Save-Report

$runs = @()
# 1: Codex open, first repair.
$runs += Invoke-OneLine 'run1-open'
if (-not (Get-CodexMain)) { $null = Start-Codex }
Start-Sleep -Seconds 50
$report.screen_after1 = Save-Screen 'after1'
Stop-Codex
Get-StorageEvidence 'after-reopen1'
$null = Start-Codex
Start-Sleep -Seconds 12
$report.remoteAfter1 = @(Get-RemoteConnections)
# 2: Codex open again, cache already repaired.
$runs += Invoke-OneLine 'run2-open-again'
if (-not (Get-CodexMain)) { $null = Start-Codex }
Start-Sleep -Seconds 50
$report.screen_after2 = Save-Screen 'after2'
# 3: Codex closed.
Stop-Codex
$runs += Invoke-OneLine 'run3-closed'
$final = Get-I18nSnapshot 'final'
if ($Locale -eq 'system') {
    # 中文 Windows 上 Chromium 的界面语言是 zh-CN；英文测试机用 --lang 模拟。
    $null = Get-I18nSnapshot 'final_chinese_ui' '--lang=zh-CN'
}
$null = Start-Codex
Start-Sleep -Seconds 50
$report.screen_final = Save-Screen 'final'
Stop-Codex
Save-Report

# Stress: Codex open, run again and again; every run must succeed and find the previous cache.
for ($i = 1; $i -le $Stress; $i++) {
    if (-not (Get-CodexMain)) { $null = Start-Codex }
    Start-Sleep -Seconds 12
    $row = Invoke-OneLine "stress$i"
    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $ReportDir "stress$i-stdout.txt")
    $row.previousCachePresent = $text -match '(seededFrom\s*:\s*current-cache|缓存来源：已有缓存)'
    if (-not $row.success) {
        Add-Failure "stress$i did not succeed."
        $row.leftover = @(Get-CodexProcesses | ForEach-Object { "$($_.ProcessId) parent=$($_.ParentProcessId) session=$($_.SessionId) start=$($_.CreationDate.ToString('HH:mm:ss')) $($_.CommandLine)".Substring(0, [Math]::Min(220, 60 + $_.CommandLine.Length)) })
    }
    if (-not $row.previousCachePresent) { Add-Failure "stress$i found the previous run's cache missing." }
    if ($row.leftDebugProcesses -or $row.leftListeners) { Add-Failure "stress$i left a debug instance or listener." }
    Save-Report
}
if ($Stress) {
    $stressFinal = Get-I18nSnapshot 'stress_final'
    if ($stressFinal.liveEnableI18n -ne $true -or $stressFinal.cjkCount -lt 5) { Add-Failure 'After the stress runs Codex is not Chinese.' }
}

if ($Expect -eq 'pass') {
    foreach ($name in @('run1-open', 'run2-open-again', 'run3-closed')) {
        $row = $report["run_$name"]
        if (-not $row.success) { Add-Failure "$name did not succeed." }
        if ($row.leftDebugProcesses -or $row.leftListeners) { Add-Failure "$name left a debug instance or listener." }
        if ($name -ne 'run1-open') {
            # The previous run's cache must have survived the close; otherwise its success was fake.
            $text = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $ReportDir "$name-stdout.txt")
            if ($text -notmatch '(seededFrom\s*:\s*current-cache|缓存来源：已有缓存)') { Add-Failure "$name found the previous run's cache missing (not persisted)." }
        }
        if ($row.codexRunningAfter -gt 0) { Add-Failure "$name reopened or left a desktop process." }
        if ($row.seconds -gt 180) { Add-Failure "$name took more than three minutes." }
        if ($row.maxOutputGap -gt 12) { Add-Failure "$name had no progress for $($row.maxOutputGap) seconds." }
        if ($row.codexWasRunning -and ($null -eq $row.closeSeconds -or $null -eq $row.closeAfterOutputSeconds -or $row.closeAfterOutputSeconds -gt 6)) { Add-Failure "$name closed the running Codex slowly or not at all." }
    }
    if ($final.PSObject.Properties['error'] -or $final.liveEnableI18n -ne $true) { Add-Failure 'After the repair Codex did not load enable_i18n=true.' }
    if (-not $final.PSObject.Properties['cjkCount'] -or $final.cjkCount -lt 5) { Add-Failure 'After the repair the Codex page text is not Chinese.' }
    if ($Network -ne 'online' -and $baseline.PSObject.Properties['caches'] -and @($baseline.caches | Where-Object { $_.source -eq 'Network' }).Count) {
        Add-Failure 'Baseline Statsig cache came from the network; the no-VPN simulation leaked.'
    }
}
Save-Report
if ($report.failures.Count) { throw ('Failures: ' + ($report.failures -join ' | ')) }

} finally {
    [IO.File]::WriteAllBytes($hostsPath, $originalHosts)
    foreach ($dns in $originalDns) {
        if (@($dns.ServerAddresses).Count) {
            Set-DnsClientServerAddress -InterfaceIndex $dns.InterfaceIndex -ServerAddresses $dns.ServerAddresses -ErrorAction Continue
        } else {
            Set-DnsClientServerAddress -InterfaceIndex $dns.InterfaceIndex -ResetServerAddresses -ErrorAction Continue
        }
    }
    ipconfig /flushdns | Out-Null
    if (Get-Variable networkFixture -Scope Script -ErrorAction SilentlyContinue) {
        Stop-Process -Id $script:networkFixture.Id -Force -ErrorAction SilentlyContinue
    }
}
