# 在 Windows 上检查生图工具写入的 Codex 放行规则是否真的生效。
# 做法：安装发布版生图工具（假 Key），让 Codex 连到本地假模型服务器，
# 由假模型下发 Skill 里写的那条命令，看 Codex 实际执行时是否离开沙箱。
# 不需要任何真实 Key；结果写入 $WorkRoot\report.md。
param(
    [Parameter(Mandatory = $true)][string]$Tool,
    [Parameter(Mandatory = $true)][string]$Sandbox,
    [string]$WorkRoot = (Join-Path $env:RUNNER_TEMP 'image-rules')
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding = [Text.UTF8Encoding]::new($false)
$utf8 = [Text.UTF8Encoding]::new($false)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Tool = (Resolve-Path $Tool).Path
New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null
$logDir = Join-Path $WorkRoot 'mock-log'
$commandFile = Join-Path $WorkRoot 'command.txt'
$portFile = Join-Path $WorkRoot 'port'
$outside = Join-Path $WorkRoot 'outside'
$work = Join-Path $WorkRoot 'work'
New-Item -ItemType Directory -Force -Path $logDir, $outside, $work | Out-Null
$report = [Collections.Generic.List[string]]::new()
function Note([string]$text) { Write-Host $text; $report.Add($text) }

# 假模型服务器
[IO.File]::WriteAllText($commandFile, 'echo start', $utf8)
$server = Start-Process -FilePath python -ArgumentList @('-I', (Join-Path $here 'mock_responses.py'), '--port-file', $portFile, '--log-dir', $logDir, '--command-file', $commandFile) -PassThru -NoNewWindow -RedirectStandardError (Join-Path $WorkRoot 'mock.err')
for ($i = 0; $i -lt 50 -and -not (Test-Path $portFile); $i++) { Start-Sleep -Milliseconds 200 }
$port = (Get-Content $portFile -Raw).Trim()

function Write-Config([string]$codexHome) {
    New-Item -ItemType Directory -Force -Path $codexHome | Out-Null
    $sandboxLine = if ($Sandbox -eq 'default') { '' } else { "[windows]`nsandbox = `"$Sandbox`"`n" }
    $config = @"
model = "mock-model"
model_provider = "mock"
approval_policy = "on-request"
sandbox_mode = "read-only"
check_for_update_on_startup = false

[model_providers.mock]
name = "mock"
base_url = "http://127.0.0.1:$port/v1"
wire_api = "responses"

$sandboxLine
"@
    [IO.File]::WriteAllText((Join-Path $codexHome 'config.toml'), $config, $utf8)
}

function Use-Home([string]$codexHome) {
    if ($codexHome -eq (Join-Path $env:USERPROFILE '.codex')) { Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue }
    else { $env:CODEX_HOME = $codexHome }
}

function Install-Into([string]$codexHome) {
    Write-Config $codexHome
    Use-Home $codexHome
    $output = "sk-fake-not-real-0000`n" | & $Tool install 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "安装失败：$output" }
    $rules = Get-Content -LiteralPath (Join-Path $codexHome 'rules\usegoodai-imagines-tool.rules') -Raw -Encoding UTF8
    $skill = Get-Content -LiteralPath (Join-Path $codexHome 'skills\usegoodai-image-generation\SKILL.md') -Encoding UTF8
    $line = $skill | Where-Object { $_ -match " generate --model '<模型>' --prompt" } | Select-Object -First 1
    $prefix = $line.Substring(0, $line.IndexOf(' generate --model'))
    Note ''
    Note "### 安装位置：$codexHome"
    Note ''
    Note "Skill 里的工具命令：``$prefix``"
    Note ''
    Note '```'
    Note $rules.TrimEnd()
    Note '```'
    if ($output -match '提示：') { Note "安装提示：$(($output -split "`n" | Where-Object { $_ -match '提示：' }) -join ' ')" }
    return $prefix
}

# 让 Codex 执行一条命令，返回 Codex 实际用的命令行和命令输出。
function Invoke-Codex([string]$codexHome, [string]$command) {
    Use-Home $codexHome
    [IO.File]::WriteAllText($commandFile, $command, $utf8)
    $outputs = Join-Path $logDir 'outputs.jsonl'
    if (Test-Path $outputs) { Clear-Content $outputs }
    Push-Location $work
    try {
        $events = cmd /c "codex exec --json --skip-git-repo-check draw-an-apple < NUL 2> `"$WorkRoot\exec.err`"" | Out-String
    } finally { Pop-Location }
    $ran = ''
    foreach ($eventLine in ($events -split "`n")) {
        if ($eventLine -match '"item.started"' -and $eventLine -match 'command_execution') {
            $ran = ($eventLine | ConvertFrom-Json).item.command
        }
    }
    $result = ''
    if (Test-Path $outputs) {
        foreach ($outLine in (Get-Content $outputs -Encoding UTF8)) { if ($outLine) { $result += ($outLine | ConvertFrom-Json).output } }
    }
    if (-not $result) { $result = "（Codex 没有执行命令）`n$events`n$(Get-Content "$WorkRoot\exec.err" -Raw -ErrorAction SilentlyContinue)" }
    return [pscustomobject]@{ Ran = $ran; Output = $result }
}

# 判断生图工具这次是否在沙箱外运行。
function Test-ToolCase([string]$label, [string]$codexHome, [string]$prefix, [string]$probe) {
    $command = "$prefix doctor --output-dir '$probe'"
    $r = Invoke-Codex $codexHome $command
    $network = if ($r.Output -match '网络已连通') { '能联网' } elseif ($r.Output -match '无法联网') { '联网被拦' } else { '未知' }
    $write = if ($r.Output -match '"name":"输出目录","ok":true') { '能写入' } elseif ($r.Output -match '"name":"输出目录","ok":false') { '写入被拦' } else { '未知' }
    $sandboxEnv = if ($r.Output -match '当前命令在 Codex 沙箱（([^）]*)）') { "沙箱变量=$($Matches[1])" } else { '无沙箱变量' }
    Note "| $label | ``$command`` | $network | $write | $sandboxEnv |"
    Add-Content -Path (Join-Path $WorkRoot 'details.txt') -Value "== $label`nCodex 执行：$($r.Ran)`n$($r.Output)`n" -Encoding UTF8
    return ($network -eq '能联网' -and $write -eq '能写入')
}

Note "## 沙箱设置：$Sandbox（$([Environment]::OSVersion.VersionString)）"
$homes = [ordered]@{
    '默认位置'   = (Join-Path $env:USERPROFILE '.codex')
    '中文用户名' = (Join-Path $env:USERPROFILE '张三\.codex')
    '带空格'     = (Join-Path $env:USERPROFILE 'John Smith\.codex')
}
$prefixes = @{}
foreach ($name in $homes.Keys) { $prefixes[$name] = Install-Into $homes[$name] }

Note ''
Note '| 情况 | Codex 收到的命令 | 联网 | 写沙箱外目录 | 沙箱变量 |'
Note '|---|---|---|---|---|'
$results = [ordered]@{}
$i = 0
foreach ($name in $homes.Keys) {
    $i++
    $results[$name] = Test-ToolCase $name $homes[$name] $prefixes[$name] (Join-Path $outside "probe$i")
}

# 对照组：没有放行规则的同一个程序，应该留在沙箱里。
$other = Join-Path $WorkRoot 'other\usegoodai-imagines-tool.exe'
New-Item -ItemType Directory -Force -Path (Split-Path $other) | Out-Null
Copy-Item -LiteralPath $Tool -Destination $other -Force
$control = Test-ToolCase '对照：未放行的同名程序' $homes['默认位置'] $other (Join-Path $outside 'probe-control')

# 解除下载锁定的规则：给程序加上下载标记，让 Codex 执行 Skill 里的修复命令。
$defaultExe = Join-Path $homes['默认位置'] 'tools\usegoodai-imagines-tool\usegoodai-imagines-tool.exe'
Set-Content -LiteralPath $defaultExe -Stream Zone.Identifier -Value "[ZoneTransfer]`r`nZoneId=3"
$unblockCommand = "Unblock-File -LiteralPath $($prefixes['默认位置'])"
$r = Invoke-Codex $homes['默认位置'] $unblockCommand
$unblocked = -not (Get-Item -LiteralPath $defaultExe -Stream Zone.Identifier -ErrorAction SilentlyContinue)
Note "| 修复：解除下载锁定 | ``$unblockCommand`` | - | $(if ($unblocked) { '已解除' } else { '没解除' }) | - |"
Add-Content -Path (Join-Path $WorkRoot 'details.txt') -Value "== 解除下载锁定`nCodex 执行：$($r.Ran)`n$($r.Output)`n" -Encoding UTF8

# Codex 自带的规则检查（只比较拆好的命令词，不经过 PowerShell 解析）
Note ''
Note '### codex execpolicy check（直接给命令词）'
foreach ($name in $homes.Keys) {
    $rulesPath = Join-Path $homes[$name] 'rules\usegoodai-imagines-tool.rules'
    $exe = Join-Path $homes[$name] 'tools\usegoodai-imagines-tool\usegoodai-imagines-tool.exe'
    $check = codex execpolicy check --rules $rulesPath $exe doctor 2>&1 | Out-String
    Note "- $name：$(if ($check -match '"decision":"allow"') { 'allow' } else { '不匹配' })"
}

$server | Stop-Process -Force -ErrorAction SilentlyContinue
Note ''
Note "对照组留在沙箱里：$(-not $control)"
[IO.File]::WriteAllLines((Join-Path $WorkRoot 'report.md'), $report, $utf8)
if ($env:GITHUB_STEP_SUMMARY) { [IO.File]::AppendAllLines($env:GITHUB_STEP_SUMMARY, $report, $utf8) }
$failed = @($results.Keys | Where-Object { -not $results[$_] })
if ($control) { Write-Host '对照组也离开了沙箱，这台机器上的沙箱没有拦截，本次结果不能说明规则是否生效。'; exit 2 }
if ($failed.Count -gt 0 -or -not $unblocked) { Write-Host "放行规则没有生效：$($failed -join '、')$(if (-not $unblocked) { ' 解除下载锁定' })"; exit 1 }
Write-Host '全部情况都已离开沙箱。'
