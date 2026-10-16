param([string]$SourceUrl, [string]$Backend, [string]$WorkRoot)
$ErrorActionPreference='Stop'
$target=Join-Path $WorkRoot ([Guid]::NewGuid().ToString('N'))
$appRoot=Join-Path $target 'app'
$resources=Join-Path $appRoot 'resources'
$null=[IO.Directory]::CreateDirectory($resources)
$null=New-Item -ItemType SymbolicLink -Path (Join-Path $resources 'codex.exe') -Target $Backend
$env:OS='Windows_NT'
$env:CODEX_HOME=$target
function Get-AppxPackage { param($Name,$ErrorAction); [pscustomobject]@{InstallLocation=$appRoot} }
function Get-RunningCodexClients { return @() }
# Intercept process discovery for the generated process helper; never stop a real client.
function Get-Process { param($Id,$Name,$ErrorAction); return @() }
$config="model=`"gpt-existing`"`r`n[features]`r`ngoals=true`r`n"
[IO.File]::WriteAllText((Join-Path $target 'config.toml'),$config,(New-Object Text.UTF8Encoding($false)))

# This is the exact documented invocation, including the HTTP response decoding.
$Error.Clear()
irm $SourceUrl | iex
if (@($Error | Where-Object {$_.Exception -is [System.Management.Automation.CommandNotFoundException] -or $_.CategoryInfo.Category -eq 'ParserError'}).Count) { throw 'HTTP pipeline produced PowerShell parsing errors' }
$catalog=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $target 'usegoodai-models.json')))
if (@($catalog.models | Where-Object {$_.slug -ceq 'minimax-m3'}).Count -ne 1) { throw 'Expected exactly one MiniMax M3' }
if ((Get-ConfigInfo ([IO.File]::ReadAllText((Join-Path $target 'config.toml')))).Values['model'] -cne '"gpt-existing"') { throw 'Default model changed' }
Write-Output 'PowerShell HTTP irm | iex import passed; no real process was stopped'
