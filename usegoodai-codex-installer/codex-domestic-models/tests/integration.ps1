param([string]$Backend, [string]$DomesticPath, [string]$WorkRoot)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../src/core.ps1')
. (Join-Path $PSScriptRoot '../src/windows-host.ps1')
$Domestic=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($DomesticPath))
$script:assertions=0
function Assert($Value) { if (-not $Value) { throw 'Assertion failed' }; $script:assertions++ }
function Setup([string]$Name) {
  $homePath=Join-Path $WorkRoot ($Name+'-'+[Guid]::NewGuid().ToString('N'))
  $null=[IO.Directory]::CreateDirectory($homePath)
  $exported=ConvertFrom-Json -InputObject (Invoke-CodexExport $Backend @('debug','models','--bundled') $homePath)
  $selected=@($exported.models | Where-Object {$_.slug -like 'gpt-*'})[0].slug
  $config=@"
# preserve comments
model = "$selected"
review_model = "$selected"
model_provider = "relay"
model_reasoning_effort = "high"
[model_providers.relay]
name = "relay"
base_url = "https://example.invalid/v1"
wire_api = "responses"
requires_openai_auth = false
[desktop]
theme = "dark"
"@
  Write-PrivateText (Join-Path $homePath 'config.toml') ($config+"`n")
  Write-PrivateText (Join-Path $homePath 'auth.json') 'sentinel-do-not-read'
  return $homePath
}
$null=[IO.Directory]::CreateDirectory($WorkRoot)
$target=Setup 'success'
Assert ((Invoke-ModelImport $target $Backend $Domestic) -eq 8)
$catalogPath=Join-Path $target 'usegoodai-models.json'
$value=ConvertFrom-Json -InputObject (Read-PrivateText $catalogPath)
Assert (@($value.models | Where-Object {$_.slug -like 'gpt-*'}).Count -gt 0)
Assert ((Read-PrivateText (Join-Path $target 'auth.json')) -ceq 'sentinel-do-not-read')
Assert (@(Get-ChildItem -LiteralPath $target -Filter 'config.toml.bak.*').Count -eq 1)
$gpt=@($value.models | Where-Object {$_.slug -like 'gpt-*'})[0]
$gpt | Add-Member custom_metadata @{keep=$true}
$owned=@($value.models | Where-Object {$_.slug -ceq $Domestic.models[0].slug})[0]
$owned | Add-Member obsolete $true
$user=ConvertFrom-Json -InputObject (ConvertTo-Json -InputObject $gpt -Depth 100); $user.slug='user-custom'
$removed=ConvertFrom-Json -InputObject (ConvertTo-Json -InputObject $gpt -Depth 100); $removed.slug='removed-domestic'
$value.models+=@($user,$removed)
Write-PrivateText $catalogPath (ConvertTo-Json -InputObject $value -Depth 100)
Write-PrivateText (Join-Path $target 'usegoodai-models.managed.json') (ConvertTo-Json -InputObject (@($Domestic.models | ForEach-Object {$_.slug})+@('removed-domestic')))
Assert ((Invoke-ModelImport $target $Backend $Domestic) -eq 8)
$value=ConvertFrom-Json -InputObject (Read-PrivateText $catalogPath)
Assert (@($value.models | Where-Object {$_.slug -ceq 'removed-domestic'}).Count -eq 0)
Assert (@($value.models | Where-Object {$_.slug -ceq 'user-custom'})[0].custom_metadata.keep)
Assert (@($value.models | Where-Object {$_.slug -ceq $gpt.slug})[0].custom_metadata.keep)
Assert ($null -eq @($value.models | Where-Object {$_.slug -ceq $Domestic.models[0].slug})[0].obsolete)
$beforeConfig=Read-PrivateText (Join-Path $target 'config.toml')
$null=Invoke-ModelImport $target $Backend $Domestic
Assert ((Read-PrivateText (Join-Path $target 'config.toml')) -ceq $beforeConfig)

$script:realExport=${function:Invoke-CodexExport}
$script:realMove=${function:Move-StagedFile}
foreach ($failure in @('write','validation','concurrent','wrong_catalog','postcommit','wrong_metadata','changed_config','changed_managed','changed_catalog')) {
  foreach ($existing in @($false,$true)) {
    $target=Setup $failure
    if ($existing) { $null=Invoke-ModelImport $target $Backend $Domestic }
    $paths=@('config.toml','usegoodai-models.json','usegoodai-models.managed.json')
    $before=@($paths | ForEach-Object { $p=Join-Path $target $_; if ([IO.File]::Exists($p)) { [Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) } else { '' } })
    $script:faulted=$false; $script:failure=$failure; $script:target=$target
    function Invoke-CodexExport([string]$Exe,[string[]]$Arguments,[string]$TargetHome) {
      $final=$false
      if ($TargetHome -cne $script:target) {
        $validationInfo=Get-ConfigInfo (Read-PrivateText (Join-Path $TargetHome 'config.toml'))
        $final=(Get-TomlString $validationInfo.Values['model_catalog_json']) -ceq (Join-Path $script:target 'usegoodai-models.json')
        if ($script:failure -ceq 'validation') { throw 'injected validation' }
        if ($script:failure -ceq 'concurrent') { [IO.File]::AppendAllText((Join-Path $script:target 'config.toml'),"# edited externally`n") }
        if ($script:failure -ceq 'wrong_catalog') { return (ConvertTo-Json -InputObject $Domestic -Depth 100) }
      }
      if ($final -and $script:failure -ceq 'postcommit') { throw 'injected final validation' }
      if ($final -and $script:failure -in @('changed_config','changed_managed','changed_catalog')) {
        $names=@{changed_config='config.toml'; changed_managed='usegoodai-models.managed.json'; changed_catalog='usegoodai-models.json'}
        [IO.File]::AppendAllText((Join-Path $script:target $names[$script:failure]),"`n")
      }
      $text=& $script:realExport $Exe $Arguments $TargetHome
      if ($final -and $script:failure -ceq 'wrong_metadata') {
        $data=ConvertFrom-Json -InputObject $text
        @($data.models | Where-Object {$_.slug -ceq $Domestic.models[0].slug})[0].context_window=42
        return (ConvertTo-Json -InputObject $data -Depth 100)
      }
      return $text
    }
    function Move-StagedFile([string]$From,[string]$To) {
      if ($script:failure -ceq 'write' -and -not $script:faulted -and $To.EndsWith('usegoodai-models.managed.json')) { $script:faulted=$true; throw 'injected write' }
      & $script:realMove $From $To
    }
    $failed=$false
    try { $null=Invoke-ModelImport $target $Backend $Domestic } catch { $failed=$true }
    Assert $failed
    for ($index=0;$index -lt $paths.Count;$index++) {
      $file=Join-Path $target $paths[$index]
      $actual=if ([IO.File]::Exists($file)) { [Convert]::ToBase64String([IO.File]::ReadAllBytes($file)) } else { '' }
      $expected=$before[$index]
      if ($failure -ceq 'concurrent' -and $index -eq 0) {
        $text=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($expected))+"# edited externally`n"
        $expected=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($text))
      }
      Assert ($actual -ceq $expected)
    }
    Assert ((Read-PrivateText (Join-Path $target 'auth.json')) -ceq 'sentinel-do-not-read')
    Assert (@(Get-ChildItem -LiteralPath $target -Directory -Force | Where-Object {$_.Name.StartsWith('.usegoodai-models-')}).Count -eq 0)
    Set-Item Function:Invoke-CodexExport $script:realExport
    Set-Item Function:Move-StagedFile $script:realMove
  }
}
foreach ($invalid in @('directory','symlink','dangling','managed_directory')) {
  $target=Setup $invalid
  $filename=if ($invalid -ceq 'managed_directory') { 'usegoodai-models.managed.json' } else { 'usegoodai-models.json' }
  $destination=Join-Path $target $filename
  $linkTarget=Join-Path $target 'link-target'
  if ($invalid -ceq 'directory' -or $invalid -ceq 'managed_directory') { $null=[IO.Directory]::CreateDirectory($destination) }
  else {
    if ($invalid -ceq 'symlink') { Write-PrivateText $linkTarget 'untouched' }
    $null=New-Item -ItemType SymbolicLink -Path $destination -Target $linkTarget
  }
  $before=Read-PrivateText (Join-Path $target 'config.toml')
  $failed=$false; try { $null=Invoke-ModelImport $target $Backend $Domestic } catch { $failed=$true }
  Assert $failed
  Assert ((Read-PrivateText (Join-Path $target 'config.toml')) -ceq $before)
  Assert (Test-PrivatePath $destination)
  if ($invalid -ceq 'symlink') { Assert ((Read-PrivateText $linkTarget) -ceq 'untouched') }
  if ($invalid -ceq 'dangling') { Assert (-not [IO.File]::Exists($linkTarget)) }
}
$target=Setup 'missing_source'
$configPath=Join-Path $target 'config.toml'
Write-PrivateText $configPath ('model_catalog_json="missing.json"'+"`n"+(Read-PrivateText $configPath))
Assert ((Invoke-ModelImport $target $Backend $Domestic) -eq 8)
$target=Setup 'relative_instructions'
$configPath=Join-Path $target 'config.toml'
Write-PrivateText (Join-Path $target 'instructions.md') "Test repository instructions.`n"
Write-PrivateText $configPath ('model_instructions_file="instructions.md"'+"`n"+(Read-PrivateText $configPath))
Assert ((Invoke-ModelImport $target $Backend $Domestic) -eq 8)
Assert ((Read-PrivateText $configPath).Contains('model_instructions_file="instructions.md"'))

# Official accounts and arbitrary service names/URLs do not depend on a relay installer.
foreach ($text in @('', 'model_provider="OpenAI"', "model_provider=`"customer`"`n[model_providers.customer]`nname=`"customer`"`nbase_url=`"https://customer.example.invalid/custom/v1`"`nwire_api=`"responses`"`nrequires_openai_auth=false`nexperimental_bearer_token=`"private-credential-do-not-print`"")) {
  $target=Setup 'provider-independent'
  $configPath=Join-Path $target 'config.toml'
  Write-PrivateText $configPath $text
  Assert ((Invoke-ModelImport $target $Backend $Domestic) -eq 8)
  $after=Read-PrivateText $configPath
  $restored=[regex]::Replace($after,'(?m)^model_catalog_json = [^\r\n]*\r?\n','')
  $restored=[regex]::Replace($restored,'\r?\n\[desktop\]\r?\nenabled-reasoning-efforts = [^\r\n]*\r?\n$','')
  Assert ($restored.TrimEnd("`r","`n") -ceq $text.TrimEnd("`r","`n"))
  Assert ((Read-PrivateText (Join-Path $target 'auth.json')) -ceq 'sentinel-do-not-read')
}
foreach ($mode in @('missing','empty','new_home')) {
  $target=Setup ('initial-'+$mode)
  if ($mode -ceq 'missing') { [IO.File]::Delete((Join-Path $target 'config.toml')) }
  elseif ($mode -ceq 'empty') { Write-PrivateText (Join-Path $target 'config.toml') '' }
  else { $target=Join-Path $target 'new/codex-home' }
  Assert ((Invoke-ModelImport $target $Backend $Domestic) -eq 8)
  $newConfig=Read-PrivateText (Join-Path $target 'config.toml')
  Assert ($newConfig -notmatch '(?m)^model_provider\s*=|^model\s*=|^base_url\s*=|^review_model\s*=')
  if ($mode -ceq 'new_home') { Assert (-not (Test-PrivatePath (Join-Path $target 'auth.json'))) }
}

# A failed final catalog validation restores absence and zero-byte configs separately.
foreach ($missing in @($false,$true)) {
  $target=Setup 'initial-rollback'
  $configPath=Join-Path $target 'config.toml'
  if ($missing) { [IO.File]::Delete($configPath) } else { Write-PrivateText $configPath '' }
  $script:target=$target
  function Invoke-CodexExport([string]$Exe,[string[]]$Arguments,[string]$TargetHome) {
    if ($TargetHome -cne $script:target) {
      $info=Get-ConfigInfo (Read-PrivateText (Join-Path $TargetHome 'config.toml'))
      if ((Get-TomlString $info.Values['model_catalog_json']) -ceq (Join-Path $script:target 'usegoodai-models.json')) { throw 'injected final validation' }
    }
    return (& $script:realExport $Exe $Arguments $TargetHome)
  }
  $failed=$false; try { $null=Invoke-ModelImport $target $Backend $Domestic } catch { $failed=$true }
  Assert $failed
  Assert ((Test-PrivatePath $configPath) -ne $missing)
  if (-not $missing) { Assert (([IO.FileInfo]$configPath).Length -eq 0) }
  Assert (-not (Test-PrivatePath (Join-Path $target 'usegoodai-models.json')))
  Assert (-not (Test-PrivatePath (Join-Path $target 'usegoodai-models.managed.json')))
  Set-Item Function:Invoke-CodexExport $script:realExport
}
Write-Output "PowerShell import/rollback: $script:assertions assertions passed"
