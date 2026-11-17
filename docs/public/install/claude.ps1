# UseGoodAI Claude 接入命令 1.1.15（Windows）。复用接入助手，不打开窗口。
function Start-UseGoodAIClaudeConnect {
  $ErrorActionPreference = "Stop"
  $temporaryDirectory = $null
  $process = $null
  $apiKey = ""
  try {
    if ($env:OS -ne "Windows_NT") {
      throw "这条命令只支持 Windows。"
    }
    Write-Host "UseGoodAI：接入 Claude 桌面版。"
    $apiKey = $env:USEGOODAI_KEY
    Remove-Item -LiteralPath Env:\USEGOODAI_KEY -ErrorAction SilentlyContinue
    while ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey.Trim() -cnotmatch '^sk-[A-Za-z0-9_-]+$') {
      if (-not [string]::IsNullOrWhiteSpace($apiKey)) {
        Write-Host "Key 格式不对，请复制完整的 UseGoodAI API Key。"
      }
      $apiKey = Read-Host "请粘贴 UseGoodAI API Key，然后回车"
    }
    $apiKey = $apiKey.Trim()
    Write-Host "正在下载接入助手，请稍等……"
    $temporaryDirectory = Join-Path ([IO.Path]::GetTempPath()) ("usegoodai-claude-" + [guid]::NewGuid().ToString("N"))
    [void][IO.Directory]::CreateDirectory($temporaryDirectory)
    $program = Join-Path $temporaryDirectory "UseGoodAI-Quick-Connect.exe"
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $client = New-Object Net.WebClient
    try {
      $client.Headers.Add("Cache-Control", "no-cache")
      $task = $client.DownloadFileTaskAsync("https://docs.usegoodai.com/download/usegoodai-quick-connect-windows-x64.exe", $program)
      $started = Get-Date
      $lastGrowth = $started
      $lastSize = [long]0
      while (-not $task.IsCompleted) {
        Start-Sleep -Milliseconds 500
        $size = if (Test-Path -LiteralPath $program) { (Get-Item -LiteralPath $program).Length } else { 0 }
        if ($size -gt $lastSize) { $lastSize = $size; $lastGrowth = Get-Date }
        if (((Get-Date) - $lastGrowth).TotalSeconds -gt 60 -or ((Get-Date) - $started).TotalMinutes -gt 5) {
          $client.CancelAsync()
          throw "下载超时，请检查网络后重新运行命令。"
        }
        Write-Host -NoNewline ("`r正在下载：{0:N1} MB，已等待 {1:N0} 秒……    " -f ($size / 1MB), ((Get-Date) - $started).TotalSeconds)
      }
      $task.GetAwaiter().GetResult()
      Write-Host ""
    } finally {
      $client.Dispose()
    }
    $size = (Get-Item -LiteralPath $program).Length
    if ($size -lt 1MB -or $size -gt 25MB) { throw "下载的文件不是完整的接入助手，请重新运行命令。" }
    $info = [Diagnostics.FileVersionInfo]::GetVersionInfo($program)
    if ($info.ProductName -ne "UseGoodAI中转快速接入助手" -or [version]$info.FileVersion -lt [version]"1.1.15") {
      throw "下载的助手版本不支持 Claude 接入命令，请稍后重新运行。"
    }
    Write-Host "正在检查密钥并配置 Claude，请先保存桌面版中进行的任务……"
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $program
    $start.Arguments = "--claude-connect"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = New-Object Text.UTF8Encoding($false)
    $start.StandardErrorEncoding = New-Object Text.UTF8Encoding($false)
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    [void]$process.Start()
    $outputTask = $process.StandardOutput.ReadToEndAsync()
    $errorTask = $process.StandardError.ReadToEndAsync()
    $request = @{key = $apiKey} | ConvertTo-Json -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($request)
    $process.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    $process.StandardInput.Close()
    if (-not $process.WaitForExit(90000)) {
      $process.Kill()
      $process.WaitForExit()
      throw "接入超时，请重新运行命令。"
    }
    $reply = $outputTask.GetAwaiter().GetResult()
    [void]$errorTask.GetAwaiter().GetResult()
    $result = $reply | ConvertFrom-Json
    if (-not $result.message -or $result.tone -notin @("success", "warning", "error")) {
      throw "没有收到接入结果，请重新运行命令。"
    }
    $global:LASTEXITCODE = $process.ExitCode
    $color = switch ($result.tone) { "success" { "Green" }; "warning" { "Yellow" }; default { "Red" } }
    Write-Host ($result.message.Replace($apiKey, "[密钥已隐藏]")) -ForegroundColor $color
  } catch {
    $global:LASTEXITCODE = 1
    $message = $_.Exception.Message
    if (-not [string]::IsNullOrEmpty($apiKey)) { $message = $message.Replace($apiKey, "[密钥已隐藏]") }
    Write-Host ("接入失败：" + $message) -ForegroundColor Red
  } finally {
    if ($null -ne $process) {
      try { if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit() } } catch {}
      $process.Dispose()
    }
    if ($temporaryDirectory -and (Test-Path -LiteralPath $temporaryDirectory)) {
      Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

Start-UseGoodAIClaudeConnect
