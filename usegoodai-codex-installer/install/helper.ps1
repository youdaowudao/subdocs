# UseGoodAI中转快速接入助手：下载到桌面并打开（Windows）。
# 下载的是可直接运行的程序，不是压缩包。下载失败时去 QQ 群文件下载。

function Start-UseGoodAIHelper {
  $ErrorActionPreference = "Stop"
  $ProgressPreference = "SilentlyContinue"

  $QqGroup = "1020015031"
  $DownloadUrl = "https://docs.usegoodai.com/download/usegoodai-quick-connect-windows-x64.exe"
  $FileName = "UseGoodAI中转快速接入助手.exe"
  $MinimumBytes = 1MB

  Write-Host "UseGoodAI 中转快速接入助手：下载到桌面并打开。"
  Write-Host "下载失败时，进 QQ 群 $QqGroup，在群文件下载「中转站快速导入工具」，解压后打开「1.UseGoodAI中转快速接入助手」。"
  Write-Host ""

  if ($env:OS -ne "Windows_NT") {
    Write-Host "这条命令只能在 Windows 上用。Mac 请进 QQ 群 $QqGroup，在群文件下载 Mac 版。"
    return
  }

  $partial = Join-Path ([System.IO.Path]::GetTempPath()) ("usegoodai-helper-" + [guid]::NewGuid().ToString("N") + ".part")
  try {
    $desktop = [Environment]::GetFolderPath("Desktop")
    if ([string]::IsNullOrEmpty($desktop)) {
      $desktop = Join-Path $HOME "Desktop"
    }
    if (-not (Test-Path -LiteralPath $desktop -PathType Container)) {
      New-Item -ItemType Directory -Path $desktop -Force | Out-Null
    }
    $target = Join-Path $desktop $FileName

    $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $target })
    if ($running.Count -gt 0) {
      Write-Host "助手已经在运行，已把它的窗口调到前面。"
      Start-Process -FilePath $target
      return
    }

    try {
      [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {
      # 系统已经默认支持 TLS 1.2 时不需要设置。
    }

    Write-Host "正在下载助手（约 20 MB），请稍候……"
    $downloaded = $false
    for ($attempt = 1; $attempt -le 2 -and -not $downloaded; $attempt++) {
      try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $partial -UseBasicParsing -TimeoutSec 300
        $downloaded = $true
      } catch {
        if ($attempt -ge 2) {
          throw
        }
        Write-Host "第 $attempt 次下载没成功，2 秒后重试……"
        Start-Sleep -Seconds 2
      }
    }

    # 只认真正的 Windows 程序（开头是 MZ）。网页错误页或被网络劫持的内容一律不放到桌面。
    $length = (Get-Item -LiteralPath $partial).Length
    $head = New-Object byte[] 2
    $stream = [System.IO.File]::OpenRead($partial)
    try {
      [void]$stream.Read($head, 0, 2)
    } finally {
      $stream.Close()
    }
    if ($length -lt $MinimumBytes -or $head[0] -ne 0x4D -or $head[1] -ne 0x5A) {
      throw "下载到的内容不是助手程序（$length 字节），可能是网络或代理返回了网页。"
    }

    Move-Item -LiteralPath $partial -Destination $target -Force
    try {
      Unblock-File -LiteralPath $target
    } catch {
      # 文件本来就没有网络来源标记。
    }
    Write-Host "已下载到桌面：$target"

    Start-Process -FilePath $target
    Write-Host "助手已打开。回网站点「一键导入 Codex」，浏览器问是否打开时点「打开」。"
    Write-Host "以后双击桌面上的「UseGoodAI中转快速接入助手」也能打开。"
  } catch {
    Write-Host ""
    Write-Host "下载或打开失败：$($_.Exception.Message)"
    Write-Host "请进 QQ 群 $QqGroup，在群文件下载「中转站快速导入工具」，解压后打开「1.UseGoodAI中转快速接入助手」。"
  } finally {
    Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
  }
}

Start-UseGoodAIHelper
