$ErrorActionPreference = "Stop"

$CodexBaseUrl = "https://api.usegoodai.com"
$CodexModel = "gpt-5.6-sol"

$CodexHome = Join-Path $HOME ".codex"
$ConfigFile = Join-Path $CodexHome "config.toml"
$AuthFile = Join-Path $CodexHome "auth.json"

function Say([string]$Message) {
  Write-Host $Message
}

function Backup-IfExists([string]$Path) {
  if (Test-Path -LiteralPath $Path) {
    $stamp = Get-Date -Format "yyyyMMddHHmmss"
    $backup = "$Path.bak.$stamp"
    $suffix = 1
    while (Test-Path -LiteralPath $backup) {
      $backup = "$Path.bak.$stamp.$suffix"
      $suffix += 1
    }
    Copy-Item -LiteralPath $Path -Destination $backup
  }
}

function Get-RunningCodexClients {
  return @(
    Get-Process -ErrorAction SilentlyContinue |
      Where-Object { $_.ProcessName -match "^(codex|chatgpt)$" } |
      Select-Object -ExpandProperty ProcessName -Unique
  )
}

function Report-RunningClients {
  $runningClients = @(Get-RunningCodexClients)
  $codexRunning = $runningClients -icontains "codex"
  $chatgptRunning = $runningClients -icontains "chatgpt"

  if ($chatgptRunning -and $codexRunning) {
    Say "当前检测到 ChatGPT 软件和 Codex CLI 正在运行，请完全退出并结束任务后，重新打开测试连接，如有问题请联系网站客服。"
    return
  }
  if ($chatgptRunning) {
    Say "当前检测到 ChatGPT 软件正在运行，请完全退出并结束任务后，重新打开测试连接，如有问题请联系网站客服。"
    return
  }
  if ($codexRunning) {
    Say "当前检测到 Codex CLI 正在运行，请完全退出并结束任务后，重新打开测试连接，如有问题请联系网站客服。"
    return
  }
  Say "当前未检测到 ChatGPT/Codex CLI 运行，请启动软件后进行测试。"
}

function Show-WritePlan {
  $existingFiles = @()
  foreach ($path in @($ConfigFile, $AuthFile)) {
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      $existingFiles += $path
    }
  }

  if ($existingFiles.Count -eq 0) {
    return
  }

  Say ""
  Say "检测到已有旧配置，将会在备份后再覆盖。"
}

function Read-ValidatedApiKey {
  while ($true) {
    $apiKey = Read-Host "请粘贴从 UseGoodAI 中转站复制过来的 API Key，然后回车确认"
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
      Say ""
      Say "API Key 不能为空，请重新输入。"
      Say ""
      continue
    }
    if (-not $apiKey.StartsWith("sk-", [System.StringComparison]::Ordinal)) {
      Say ""
      Say "API Key 格式错误，必须以 sk- 开头，请重新输入。"
      Say ""
      continue
    }
    return $apiKey
  }
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Write-CodexFiles([string]$ApiKey) {
  if (-not (Test-Path -LiteralPath $CodexHome)) {
    New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null
  }

  $configTemp = Join-Path $CodexHome (".config.toml.tmp." + [Guid]::NewGuid().ToString("N"))
  $authTemp = Join-Path $CodexHome (".auth.json.tmp." + [Guid]::NewGuid().ToString("N"))
  try {
    $content = @"
model_provider = "OpenAI"
model = "$CodexModel"
review_model = "$CodexModel"
model_reasoning_effort = "high"
disable_response_storage = true
network_access = "enabled"
windows_wsl_setup_acknowledged = true

[model_providers.OpenAI]
name = "OpenAI"
base_url = "$CodexBaseUrl"
wire_api = "responses"
requires_openai_auth = false
http_headers = { "x-openai-actor-authorization" = "local-image-extension" }

[features]
goals = true
image_generation = true
"@

    $payload = [ordered]@{ OPENAI_API_KEY = $ApiKey }
    $json = $payload | ConvertTo-Json -Depth 5
    Write-Utf8NoBom -Path $configTemp -Content $content
    Write-Utf8NoBom -Path $authTemp -Content ($json + "`n")

    Backup-IfExists $ConfigFile
    Backup-IfExists $AuthFile
    Move-Item -LiteralPath $configTemp -Destination $ConfigFile -Force
    Move-Item -LiteralPath $authTemp -Destination $AuthFile -Force
  } finally {
    Remove-Item -LiteralPath $configTemp -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $authTemp -Force -ErrorAction SilentlyContinue
  }
}

Say "欢迎使用 UseGoodAI 中转站 Codex 一键配置脚本。"
Say ""
Say "本脚本不会安装、修改任何软件，只会配置用户目录下 .codex 文件夹中的 config.toml 和 auth.json 文件。"

Show-WritePlan
Say ""

$ApiKey = Read-ValidatedApiKey

Write-CodexFiles -ApiKey $ApiKey

Say ""
Say "配置已经完成，可以关闭 PowerShell 了。"
Say ""
Report-RunningClients
Say ""
Say "感谢您对 UseGoodAI 中转站的支持，使用过程中如有问题请联系网站客服。"
