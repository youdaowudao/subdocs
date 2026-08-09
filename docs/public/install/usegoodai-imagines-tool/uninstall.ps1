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
    $PackageRoot = Join-Path $UnpackPath $PackageRootName
    $InstallerCorePath = Join-Path $PackageRoot "installer\安装.py"
    if (-not (Test-Path -LiteralPath $InstallerCorePath -PathType Leaf)) {
        throw "卸载包内缺少卸载入口。"
    }

    $InstallerArguments = @($InstallerCorePath, "uninstall", "--source-root", $PackageRoot) + $args
    $PythonCommand = $null
    $PythonPrefixArguments = @()
    $PyCommand = Get-Command py -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $PyCommand) {
        & $PyCommand.Path -3 --version *> $null
        if ($LASTEXITCODE -eq 0) {
            $PythonCommand = $PyCommand.Path
            $PythonPrefixArguments = @("-3")
        }
    }

    if ($null -eq $PythonCommand) {
        $PythonExecutable = Get-Command python -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $PythonExecutable) {
            & $PythonExecutable.Path --version *> $null
            if ($LASTEXITCODE -eq 0) {
                $PythonCommand = $PythonExecutable.Path
            }
        }
    }

    if ($null -eq $PythonCommand) {
        throw "卸载失败：未找到可用的 Python 3。请先安装 Python 3，再重新运行本卸载脚本。"
    }

    $PythonInvocationArguments = $PythonPrefixArguments + $InstallerArguments
    & $PythonCommand @PythonInvocationArguments
    if ($LASTEXITCODE -ne 0) {
        throw "包内卸载核心返回退出码 $LASTEXITCODE。"
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
