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
    Say "已备份：$backup"
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
  if ($runningClients.Count -eq 0) {
    return
  }

  foreach ($processName in $runningClients) {
    if ($processName -ieq "codex") {
      Say "当前检测到 Codex CLI 正在运行。"
    } elseif ($processName -ieq "chatgpt") {
      Say "当前检测到 ChatGPT 正在运行。"
    }
  }
  Say "请彻底退出并结束以上进程，然后重新打开。"
}

function Show-WritePlan {
  $existingFiles = @()
  foreach ($path in @($ConfigFile, $AuthFile)) {
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      $existingFiles += $path
    }
  }

  if ($existingFiles.Count -eq 0) {
    Say "未发现旧配置，将创建："
    Say "  - $ConfigFile"
    Say "  - $AuthFile"
    return
  }

  Say "检测到已有配置，将先备份再覆盖："
  foreach ($path in $existingFiles) {
    Say "  - $path"
  }
}

function Read-ValidatedApiKey {
  while ($true) {
    $apiKey = Read-Host "请输入 UseGoodAI API Key"
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
      Say "API Key 不能为空，请重新输入。"
      continue
    }
    if (-not $apiKey.StartsWith("sk-", [System.StringComparison]::Ordinal)) {
      Say "API Key 格式错误，必须以 sk- 开头，请重新输入。"
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

Say "UseGoodAI Codex 一键配置"
Say ""
Say "接口地址：$CodexBaseUrl"
Say "默认模型：$CodexModel"
Say ""
Say "脚本不会安装软件；新配置不会写入沙盒或审批字段。"
Say ""

Show-WritePlan
Say ""

$ApiKey = Read-ValidatedApiKey

Write-CodexFiles -ApiKey $ApiKey

Say ""
Say "Codex 配置已写入。"
Report-RunningClients
Say "Codex App / ChatGPT：重新打开后新建任务发送：测试"
Say "Codex CLI：启动新的 Codex 会话后发送：测试"
