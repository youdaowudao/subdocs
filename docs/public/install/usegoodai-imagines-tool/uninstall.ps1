$ErrorActionPreference = "Stop"

function Download-WithPercent {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][string]$Activity
    )

    Add-Type -AssemblyName System.Net.Http
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $Handler = [System.Net.Http.HttpClientHandler]::new()
    $Handler.AllowAutoRedirect = $false
    $Client = [System.Net.Http.HttpClient]::new($Handler)
    $Response = $null
    $Source = $null
    $Target = $null
    try {
        $Response = $Client.GetAsync($Uri, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        if (-not $Response.IsSuccessStatusCode) {
            throw ("下载返回 HTTP " + [int]$Response.StatusCode + "。")
        }
        $TotalBytes = $Response.Content.Headers.ContentLength
        if ($null -eq $TotalBytes -or $TotalBytes -le 0) {
            throw "服务器未返回文件大小，无法显示下载百分比。"
        }
        $Source = $Response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $Target = [System.IO.FileStream]::new($Destination, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $Buffer = [byte[]]::new(131072)
        [long]$DownloadedBytes = 0
        while (($ReadCount = $Source.Read($Buffer, 0, $Buffer.Length)) -gt 0) {
            $Target.Write($Buffer, 0, $ReadCount)
            $DownloadedBytes += $ReadCount
            $Percent = [Math]::Min(100, [int][Math]::Floor(($DownloadedBytes * 100.0) / $TotalBytes))
            Write-Progress -Activity $Activity -Status ("{0}%" -f $Percent) -PercentComplete $Percent
        }
    }
    finally {
        Write-Progress -Activity $Activity -Completed
        if ($null -ne $Target) { $Target.Dispose() }
        if ($null -ne $Source) { $Source.Dispose() }
        if ($null -ne $Response) { $Response.Dispose() }
        $Client.Dispose()
    }
}

$ReleaseBase = "https://docs.usegoodai.com/install/usegoodai-imagines-tool/releases/v0.3-r1"
$Architecture = if ([string]::IsNullOrWhiteSpace($env:PROCESSOR_ARCHITEW6432)) {
    $env:PROCESSOR_ARCHITECTURE
} else {
    $env:PROCESSOR_ARCHITEW6432
}

if ($Architecture.ToUpperInvariant() -ne "AMD64") {
    throw ("卸载失败：V0.3-r1 仅支持 64 位 x64 Windows，当前架构为 " + $Architecture + "。")
}
$Artifact = "usegoodai-imagines-tool-v0.3-r1-windows-amd64.exe"
$ExpectedSha256 = "bd0171618879dd0dd60f7afc62735af6b1eaa81b33042ba799f0790d84f3d2d9"

$TemporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("usegoodai-imagines-tool-" + [System.Guid]::NewGuid().ToString("N"))
$BinaryPath = Join-Path $TemporaryRoot $Artifact

try {
    New-Item -ItemType Directory -Path $TemporaryRoot | Out-Null
    Download-WithPercent -Uri "$ReleaseBase/$Artifact" -Destination $BinaryPath -Activity "正在准备卸载中转站生图工具 V0.3-r1"

    $ActualSha256 = (Get-FileHash -LiteralPath $BinaryPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($ActualSha256 -ne $ExpectedSha256) {
        throw "卸载程序 SHA-256 校验不通过，已停止卸载。"
    }

    & $BinaryPath uninstall @args
    if ($LASTEXITCODE -ne 0) {
        throw "卸载程序返回退出码 $LASTEXITCODE。"
    }
}
catch {
    throw ("卸载失败：" + $_.Exception.Message)
}
finally {
    if (Test-Path -LiteralPath $TemporaryRoot) {
        Remove-Item -LiteralPath $TemporaryRoot -Recurse -Force
    }
}
