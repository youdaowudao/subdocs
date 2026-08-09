$ErrorActionPreference = "Stop"

$ReleaseBase = "https://docs.usegoodai.com/install/usegoodai-imagines-tool/releases/v0.2-r2"
$Architecture = if ([string]::IsNullOrWhiteSpace($env:PROCESSOR_ARCHITEW6432)) {
    $env:PROCESSOR_ARCHITECTURE
} else {
    $env:PROCESSOR_ARCHITEW6432
}

switch ($Architecture.ToUpperInvariant()) {
    "AMD64" {
        $Artifact = "usegoodai-imagines-tool-v0.2-r2-windows-amd64.exe"
        $ExpectedSha256 = "1dfb2d02bbdc1c027eda31dbf84acc5283dc0abffa6672390b19ab545ddb701b"
    }
    "ARM64" {
        $Artifact = "usegoodai-imagines-tool-v0.2-r2-windows-arm64.exe"
        $ExpectedSha256 = "2e340964ea8002c143fa7087f9d7cddeac90c36e8d6ea17ecbee6ef32744cd83"
    }
    default {
        throw ("卸载失败：暂不支持当前 Windows 架构：" + $Architecture + "。")
    }
}

$TemporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("usegoodai-imagines-tool-" + [System.Guid]::NewGuid().ToString("N"))
$BinaryPath = Join-Path $TemporaryRoot $Artifact

try {
    New-Item -ItemType Directory -Path $TemporaryRoot | Out-Null
    Write-Host "正在准备卸载中转站生图工具 V0.2-r2……"
    Invoke-WebRequest -UseBasicParsing -Uri "$ReleaseBase/$Artifact" -OutFile $BinaryPath

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
