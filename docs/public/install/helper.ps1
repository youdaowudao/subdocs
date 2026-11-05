# UseGoodAI中转快速接入助手：下载到桌面并打开（Windows）。
# 下载的是可直接运行的程序，不是压缩包。下载失败时去 QQ 群文件下载。

# 先出字：后面任何一步慢，用户都已经看到脚本在运行。
Write-Host "UseGoodAI 中转快速接入助手：下载到桌面并打开。"
Write-Host "下载失败时，进 QQ 群 1020015031，在群文件下载「中转站快速导入工具」，解压后打开「1.UseGoodAI中转快速接入助手」。"
Write-Host ""

# 下载并每 0.5 秒刷新一次进度，下载慢的时候用户能看到还在动。
# 60 秒没有收到任何数据就判定网络中断。
function Save-UseGoodAIDownload([string]$Url, [string]$Path) {
  $client = New-Object System.Net.WebClient
  $client.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) UseGoodAI-Helper")
  $started = Get-Date
  $lastGrowth = $started
  $lastSize = [long]0
  try {
    $task = $client.DownloadFileTaskAsync($Url, $Path)
    while (-not $task.IsCompleted) {
      Start-Sleep -Milliseconds 500
      $size = [long]0
      if (Test-Path -LiteralPath $Path) {
        $size = (Get-Item -LiteralPath $Path).Length
      }
      $now = Get-Date
      if ($size -gt $lastSize) {
        $lastSize = $size
        $lastGrowth = $now
      } elseif (($now - $lastGrowth).TotalSeconds -gt 60) {
        $client.CancelAsync()
        Write-Host ""
        throw "60 秒没有收到数据，网络可能中断了。"
      }
      $seconds = [int]($now - $started).TotalSeconds
      if ($size -eq 0) {
        Write-Host -NoNewline ("`r正在连接服务器，已等待 {0} 秒……          " -f $seconds)
      } else {
        Write-Host -NoNewline ("`r正在下载，已用 {0} 秒，已下载 {1:N1} MB（约 20 MB）          " -f $seconds, ($size / 1MB))
      }
    }
    Write-Host ""
    $task.GetAwaiter().GetResult()
  } finally {
    $client.Dispose()
  }
}

function Start-UseGoodAIHelper {
  $ErrorActionPreference = "Stop"

  $QqGroup = "1020015031"
  $DownloadUrl = "https://docs.usegoodai.com/download/usegoodai-quick-connect-windows-x64.exe"
  $FileName = "UseGoodAI中转快速接入助手.exe"
  $MinimumBytes = 1MB

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

    # 只按程序名查一个进程，不枚举全部进程，避免卡住。
    $processName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $running = @(Get-Process -Name $processName -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $target })
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

    $downloaded = $false
    for ($attempt = 1; $attempt -le 2 -and -not $downloaded; $attempt++) {
      try {
        Save-UseGoodAIDownload $DownloadUrl $partial
        $downloaded = $true
      } catch {
        if ($attempt -ge 2) {
          throw
        }
        Write-Host "第 $attempt 次下载没成功（$($_.Exception.Message)），2 秒后重试……"
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
