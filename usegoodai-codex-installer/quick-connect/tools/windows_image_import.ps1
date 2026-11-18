param([Parameter(Mandatory=$true)][string]$Exe)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
$exePath = (Resolve-Path -LiteralPath $Exe).Path
$work = Join-Path $env:RUNNER_TEMP 'image-import-window'
$homePath = Join-Path $work '隔离 Codex'
New-Item -ItemType Directory -Force $homePath | Out-Null
$originalHome = $env:CODEX_HOME
$originalArguments = $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS
$authPath = Join-Path $homePath 'auth.json'
$toolDir = Join-Path $homePath 'tools/usegoodai-imagines-tool'
$skillPath = Join-Path $homePath 'skills/usegoodai-image-generation/SKILL.md'
$keyPath = Join-Path $homePath 'tools/usegoodai-imagines-tool/api-key'
$log = Join-Path $work 'imports.txt'
$hold = Join-Path $work 'hold'
$link = 'usegoodai://import?v=2&app=image&key=sk-picture-test-fixture&name=fixture'
[IO.File]::WriteAllText($authPath, '{"OPENAI_API_KEY":"sk-codex-test-fixture"}')
$authHash = (Get-FileHash -LiteralPath $authPath).Hash
$gateway = $null

function Wait-For([scriptblock]$Condition, [string]$Description, [int]$Seconds = 30) {
  $deadline = (Get-Date).AddSeconds($Seconds)
  while ((Get-Date) -lt $deadline) {
    if (& $Condition) { return }
    Start-Sleep -Milliseconds 150
  }
  throw "测试超时：$Description"
}

function Import-Count {
  if (Test-Path -LiteralPath $log) { return @(Get-Content -LiteralPath $log).Count }
  return 0
}

function Window-Names {
  $process = Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -ieq $exePath -and $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
  if (-not $process) { return }
  $window = [System.Windows.Automation.AutomationElement]::FromHandle($process.MainWindowHandle)
  $window.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition) |
    ForEach-Object { $_.Current.Name }
}

function Verify-Result([int]$Count, [string]$Case) {
  Wait-For { (Import-Count) -ge $Count } "收到画图链接 $Case"
  Wait-For {
    $names = @(Window-Names)
    @($names | Where-Object { $_ -like '画图密钥已导入*' }).Count -gt 0 -and
      @($names | Where-Object { $_ -like 'V0.9.7 已安装*' }).Count -gt 0
  } "显示画图成功和工具状态 $Case"
  if ((Get-FileHash -LiteralPath $authPath).Hash -ne $authHash) { throw "Codex 凭据被改写 $Case" }
  if ([IO.File]::ReadAllText($keyPath).Trim() -cne 'sk-picture-test-fixture') { throw "画图凭据错误 $Case" }
  if ((Import-Count) -ne $Count) { throw "同一条链接被重复处理 $Case" }
  Write-Host "$Case PASS"
}

try {
  $env:CODEX_HOME = $homePath
  $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = '--force-renderer-accessibility'
  $mock = Join-Path $PSScriptRoot 'windows_image_import_mock.py'
  $gateway = Start-Process -FilePath 'python' -ArgumentList @("`"$mock`"", "`"$work`"") -PassThru
  Wait-For { Test-Path -LiteralPath (Join-Path $work 'ready') } '模拟服务启动'
  Start-Process -FilePath $exePath -ArgumentList $link
  Verify-Result 1 '从画图链接冷启动'

  [IO.File]::WriteAllText($hold, '')
  Start-Process -FilePath $exePath -ArgumentList $link
  Wait-For { (Import-Count) -eq 2 } '第一条连点链接正在执行'
  Start-Process -FilePath $exePath -ArgumentList $link
  Start-Sleep -Seconds 2
  Remove-Item -LiteralPath $hold
  Verify-Result 2 '导入未结束时再次点击'
  Start-Sleep -Seconds 2
  if ((Import-Count) -ne 2) { throw '连点被排进了第二次导入' }

  Start-Process -FilePath $exePath -ArgumentList $link
  Verify-Result 3 '完成后再点击'

  Start-Process -FilePath $exePath -ArgumentList 'usegoodai://import?v=2&app=codex&key=sk-unaccepted-codex-fixture'
  Wait-For { @(Window-Names) -contains 'Codex 状态' } '从生图页切到 Codex'
  Wait-For { @(Window-Names) -contains '选编程分组的密钥，点「一键导入 Codex」。' } 'Codex 接入步骤'
  Start-Process -FilePath $exePath -ArgumentList $link
  Verify-Result 4 '从 Codex 切回生图'
  Start-Process -FilePath $exePath -ArgumentList 'usegoodai://import?v=1&app=claude&key=sk-unaccepted-claude-fixture'
  Wait-For { @(Window-Names) -contains 'Claude 桌面版' } '从生图页切到 Claude'
  Wait-For { @(Window-Names) -contains '选 Claude 分组的密钥，点「一键导入 Claude」。' } 'Claude 接入步骤'
  if ((Get-FileHash -LiteralPath $authPath).Hash -ne $authHash) { throw '拒绝的链接改写了 Codex 凭据' }
  if ([IO.File]::ReadAllText($keyPath).Trim() -cne 'sk-picture-test-fixture') { throw '切换工具改写了画图凭据' }
  if (-not (Test-Path -LiteralPath $skillPath)) { throw '首轮安装没有写入 Skill' }
  Move-Item -LiteralPath $toolDir -Destination (Join-Path $work 'removed-tool')
  Start-Process -FilePath $exePath -ArgumentList $link
  Verify-Result 5 '删掉工具目录后保留 Skill 并重新导入'
  if (-not (Test-Path -LiteralPath (Join-Path $toolDir 'install-manifest.json'))) { throw '安装记录未恢复' }
  @{cases=7; image_imports=5; switched_to=@('codex','claude'); codex_auth_unchanged=$true; repaired_skill_only=$true; network='loopback mock'} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $work 'report.json') -Encoding UTF8
} finally {
  if ($gateway -and -not $gateway.HasExited) { Stop-Process -Id $gateway.Id -Force }
  Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -ieq $exePath } |
    Stop-Process -Force -ErrorAction SilentlyContinue
  $env:CODEX_HOME = $originalHome
  $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = $originalArguments
}
