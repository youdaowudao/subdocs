$ErrorActionPreference = "Stop"

$PackageUrl = "https://docs.usegoodai.com/install/usegoodai-imagines-tool/releases/v0.2-r1/usegoodai-imagines-tool-v0.2-r1.zip"
$ExpectedSha256 = "ff8bf231c6a2ef5b157413bafb4312ef2bff5ec6fc6e44b83ab395650bd883e5"
$PackageRootName = "usegoodai-imagines-tool-v0.2-r1"
$TemporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("usegoodai-imagines-tool-" + [System.Guid]::NewGuid().ToString("N"))
$ArchivePath = Join-Path $TemporaryRoot "package.zip"
$UnpackPath = Join-Path $TemporaryRoot "unpacked"

try {
    New-Item -ItemType Directory -Path $TemporaryRoot | Out-Null

    Write-Host "正在准备卸载中转站生图工具 V0.2-r1……"
    Invoke-WebRequest -UseBasicParsing -Uri $PackageUrl -OutFile $ArchivePath

    $ActualSha256 = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($ActualSha256 -ne $ExpectedSha256) {
        throw "卸载包 SHA-256 校验不通过，已停止卸载。"
    }

    Expand-Archive -LiteralPath $ArchivePath -DestinationPath $UnpackPath
    $UninstallerPath = Join-Path $UnpackPath "$PackageRootName\installer\uninstall.ps1"
    if (-not (Test-Path -LiteralPath $UninstallerPath -PathType Leaf)) {
        throw "卸载包内缺少卸载入口。"
    }

    & $UninstallerPath @args
    if ($LASTEXITCODE -ne 0) {
        throw "包内卸载器返回退出码 $LASTEXITCODE。"
    }
}
catch {
    [Console]::Error.WriteLine("卸载失败：" + $_.Exception.Message)
}
finally {
    if (Test-Path -LiteralPath $TemporaryRoot) {
        Remove-Item -LiteralPath $TemporaryRoot -Recurse -Force
    }
}
