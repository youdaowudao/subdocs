param([Parameter(Mandatory=$true)][string]$Exe)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$exePath = (Resolve-Path -LiteralPath $Exe).Path
$source = Join-Path $PSScriptRoot '../../install/codex-models.ps1'
$work = Join-Path $env:RUNNER_TEMP 'models-import-window'
$homePath = Join-Path $work '用户 目录'
New-Item -ItemType Directory -Force $homePath | Out-Null
$originalHome = $env:CODEX_HOME
$originalLocalAppData = $env:LOCALAPPDATA
$originalArguments = $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS
$auth = '{"OPENAI_API_KEY":"sk-models-test-fixture"}'
$config = "model = `"gpt-6.1-sol`"`r`napproval_policy = `"never`"`r`n"
[IO.File]::WriteAllText((Join-Path $homePath 'config.toml'), $config)
[IO.File]::WriteAllText((Join-Path $homePath 'auth.json'), $auth)
$process = $null
$launched = $null
$webview = $null

function Evaluate-WebView([string]$Expression) {
  $command = @{id=1; method='Runtime.evaluate'; params=@{expression=$Expression; returnByValue=$true}} | ConvertTo-Json -Compress
  $request = [Text.Encoding]::UTF8.GetBytes($command)
  $timeout = [Threading.CancellationTokenSource]::new(10000)
  $message = [IO.MemoryStream]::new()
  try {
    $webview.SendAsync([ArraySegment[byte]]::new($request), [Net.WebSockets.WebSocketMessageType]::Text, $true, $timeout.Token).GetAwaiter().GetResult() | Out-Null
    $buffer = [byte[]]::new(4096)
    do {
      $chunk = $webview.ReceiveAsync([ArraySegment[byte]]::new($buffer), $timeout.Token).GetAwaiter().GetResult()
      if ($chunk.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Close) { throw '助手窗口连接已断开' }
      $message.Write($buffer, 0, $chunk.Count)
    } until ($chunk.EndOfMessage)
    $response = [Text.Encoding]::UTF8.GetString($message.ToArray()) | ConvertFrom-Json
    if ($response.error -or $response.result.exceptionDetails) { throw "助手窗口操作失败：$($response | ConvertTo-Json -Compress -Depth 6)" }
    return $response.result.result.value
  } finally {
    $message.Dispose()
    $timeout.Dispose()
  }
}

function Wait-For([scriptblock]$Condition, [string]$Description) {
  $deadline = (Get-Date).AddSeconds(90)
  do {
    if (& $Condition) { return }
    Start-Sleep -Milliseconds 250
  } until ((Get-Date) -gt $deadline)
  throw "测试超时：$Description"
}

try {
  $env:CODEX_HOME = $homePath
  $env:LOCALAPPDATA = Join-Path $work 'AppData'
  New-Item -ItemType Directory -Force $env:LOCALAPPDATA | Out-Null
  # Drive the actual WebView2 controls without depending on the desktop's DPI.
  $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = '--remote-debugging-port=19478 --remote-debugging-address=127.0.0.1'
  $launched = Start-Process -FilePath $exePath -PassThru
  $deadline = (Get-Date).AddSeconds(90)
  do {
    Start-Sleep -Milliseconds 250
    $process = Get-Process -ErrorAction SilentlyContinue |
      Where-Object { $_.Path -ieq $exePath -and $_.MainWindowHandle -ne [IntPtr]::Zero } |
      Select-Object -First 1
  } until ($process -or (Get-Date) -gt $deadline)
  if (-not $process) { throw '助手窗口没有启动' }
  $desktopPage = $null
  Wait-For {
    try {
      $script:desktopPage = (Invoke-RestMethod -Uri 'http://127.0.0.1:19478/json/list' -TimeoutSec 2) |
        Where-Object { $_.type -eq 'page' -and $_.webSocketDebuggerUrl } | Select-Object -First 1
      $null -ne $desktopPage
    } catch { $false }
  } '实际助手窗口的 WebView2'
  $webview = New-Object Net.WebSockets.ClientWebSocket
  $connectTimeout = [Threading.CancellationTokenSource]::new(10000)
  try { $webview.ConnectAsync([Uri]$desktopPage.webSocketDebuggerUrl, $connectTimeout.Token).GetAwaiter().GetResult() | Out-Null }
  finally { $connectTimeout.Dispose() }
  Wait-For { Evaluate-WebView 'document.querySelector("#status")?.dataset.state !== "loading" && Boolean(document.querySelector("#go-models")?.offsetWidth)' } 'Codex 工具入口显示'
  Evaluate-WebView 'document.querySelector("#go-models").click()' | Out-Null
  Wait-For { Evaluate-WebView 'document.querySelector("#shell")?.dataset.tool === "models"' } '打开国产模型页'
  Evaluate-WebView 'document.querySelector("#connect").click()' | Out-Null
  Wait-For { Evaluate-WebView 'document.querySelector("#connect-label")?.textContent === "确认导入（会关闭 Codex）"' } '显示导入确认按钮'
  Evaluate-WebView 'document.querySelector("#connect").click()' | Out-Null

  $catalogPath = Join-Path $homePath 'usegoodai-models.json'
  $manifestPath = Join-Path $homePath 'usegoodai-models.managed.json'
  $deadline = (Get-Date).AddSeconds(90)
  while ((-not (Test-Path -LiteralPath $manifestPath)) -and (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 250
  }
  $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  if (@($manifest).Count -ne 10) { throw '助手窗口没有完成 10 个国产模型的导入' }
  $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($id in @('gpt-6.2-sol','gpt-6.2-astra') + $manifest) {
    if (@($catalog.models | Where-Object { $_.slug -ceq $id -and $_.visibility -ceq 'list' }).Count -ne 1) {
      throw "导入后缺少或重复 $id"
    }
  }
  $afterConfig = [IO.File]::ReadAllText((Join-Path $homePath 'config.toml'))
  if (-not $afterConfig.Contains('model = "gpt-6.1-sol"') -or
      -not $afterConfig.Contains('approval_policy = "never"') -or -not $afterConfig.Contains('usegoodai-models.json')) {
    throw '导入未启用目录，或原设置发生变化'
  }
  if ([IO.File]::ReadAllText((Join-Path $homePath 'auth.json')) -cne $auth -or
      (Test-Path -LiteralPath (Join-Path $homePath 'models_cache.json'))) { throw '原凭据或缓存发生变化' }
  $unpacked = Join-Path $env:LOCALAPPDATA 'UseGoodAI/QuickConnect/models-tool/codex-models.ps1'
  if ((Get-FileHash -LiteralPath $unpacked).Hash -ne (Get-FileHash -LiteralPath $source).Hash) { throw 'EXE 解出的脚本与上层源码不一致' }
  $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.CopyFromScreen($bounds.Location,[System.Drawing.Point]::Empty,$bounds.Size)
    $bitmap.Save((Join-Path $work 'import-result.png'))
  } finally { $graphics.Dispose(); $bitmap.Dispose() }
  @{
    version = (Get-Item -LiteralPath $exePath).VersionInfo.ProductVersion
    system = [Environment]::OSVersion.VersionString
    embedded_script_sha256 = (Get-FileHash -LiteralPath $unpacked).Hash
    count = @($manifest).Count
    result = '原生窗口双击确认，执行内置脚本并写入 10 个国产模型和两个 GPT-6.2，原默认模型和 Key 保留'
  } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $work 'report.json') -Encoding UTF8
} finally {
  if ($webview) { $webview.Dispose() }
  if ($process -and -not $process.HasExited) { Stop-Process -Id $process.Id -Force }
  if ($launched -and -not $launched.HasExited) { Stop-Process -Id $launched.Id -Force }
  $env:CODEX_HOME = $originalHome
  $env:LOCALAPPDATA = $originalLocalAppData
  $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = $originalArguments
}
