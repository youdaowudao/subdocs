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

$ReleaseRevision = "V0.7.5"
$ReleaseBase = "https://docs.usegoodai.com/install/usegoodai-imagines-tool/releases/v0.7.5"
$Architecture = if ([string]::IsNullOrWhiteSpace($env:PROCESSOR_ARCHITEW6432)) {
    $env:PROCESSOR_ARCHITECTURE
} else {
    $env:PROCESSOR_ARCHITEW6432
}

if ($Architecture.ToUpperInvariant() -ne "AMD64") {
    throw ("安装失败：V0.7.5 仅支持 64 位 x64 Windows，当前架构为 " + $Architecture + "。")
}
$Artifact = "usegoodai-imagines-tool-v0.7.5-windows-amd64.exe"
$ExpectedSha256 = "e66d4119185d7b24fb5786962e5ecff3578fee744d9302d0c2fcf2c73567cd51"

$ToolCodexHome = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) { Join-Path $HOME ".codex" } else { $env:CODEX_HOME }
$InstalledReleasePath = Join-Path $ToolCodexHome "tools\usegoodai-imagines-tool\RELEASE"
$InstalledBinaryPath = Join-Path $ToolCodexHome "tools\usegoodai-imagines-tool\usegoodai-imagines-tool.exe"
$NeedsDownload = $true
if ((Test-Path -LiteralPath $InstalledReleasePath -PathType Leaf) -and (Test-Path -LiteralPath $InstalledBinaryPath -PathType Leaf)) {
    $InstalledRelease = (Get-Content -LiteralPath $InstalledReleasePath -Raw).Trim()
    if ($InstalledRelease -eq $ReleaseRevision) {
        Write-Output "中转站生图工具 $ReleaseRevision 已是最新版，无需下载。"
        $NeedsDownload = $false
    }
}

$TemporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("usegoodai-imagines-tool-" + [System.Guid]::NewGuid().ToString("N"))
$BinaryPath = Join-Path $TemporaryRoot $Artifact

if ($NeedsDownload) {
    try {
        New-Item -ItemType Directory -Path $TemporaryRoot | Out-Null
        Download-WithPercent -Uri "$ReleaseBase/$Artifact" -Destination $BinaryPath -Activity "正在下载中转站生图工具 V0.7.5"

        $ActualSha256 = (Get-FileHash -LiteralPath $BinaryPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($ActualSha256 -ne $ExpectedSha256) {
            throw "安装程序 SHA-256 校验不通过，已停止安装。"
        }

        & $BinaryPath install @args
        if ($LASTEXITCODE -ne 0) {
            throw "安装程序返回退出码 $LASTEXITCODE。"
        }
    }
    catch {
        throw ("安装失败：" + $_.Exception.Message)
    }
    finally {
        if (Test-Path -LiteralPath $TemporaryRoot) {
            Remove-Item -LiteralPath $TemporaryRoot -Recurse -Force
        }
    }
}
