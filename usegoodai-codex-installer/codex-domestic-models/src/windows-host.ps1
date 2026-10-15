function Read-PrivateText([string]$Path) {
  $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw '目标文件不是普通文件，停止导入。' }
  return [IO.File]::ReadAllText($Path, (New-Object Text.UTF8Encoding($false,$true)))
}

function Test-PrivatePath([string]$Path) {
  return $null -ne (Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue)
}

function Write-PrivateText([string]$Path, [string]$Text) {
  [IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding($false,$true)))
}

function Move-StagedFile([string]$From, [string]$To) {
  if ([IO.File]::Exists($To)) { [IO.File]::Replace($From,$To,[NullString]::Value) }
  else { [IO.File]::Move($From,$To) }
}

function Invoke-CodexExport([string]$Backend, [string[]]$Arguments, [string]$TargetHome) {
  $start = New-Object Diagnostics.ProcessStartInfo
  $start.FileName=$Backend; $start.Arguments=$Arguments -join ' '
  $start.WorkingDirectory=$TargetHome; $start.UseShellExecute=$false; $start.CreateNoWindow=$true
  $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
  $start.StandardOutputEncoding=New-Object Text.UTF8Encoding($false,$true)
  $start.StandardErrorEncoding=New-Object Text.UTF8Encoding($false,$true)
  $start.EnvironmentVariables['CODEX_HOME']=$TargetHome
  $process = New-Object Diagnostics.Process
  $process.StartInfo=$start
  try {
    if (-not $process.Start()) { throw '无法启动 App 自带的 Codex 后端。' }
    $outputTask=$process.StandardOutput.ReadToEndAsync(); $errorTask=$process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(30000)) { $process.Kill(); $process.WaitForExit(); throw 'App 后端校验超时，原配置未更改。' }
    $output=$outputTask.GetAwaiter().GetResult(); $null=$errorTask.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0) { throw 'App 后端校验失败，原配置未更改。' }
    return $output
  } finally { $process.Dispose() }
}

function Write-ModelTransaction($Files, [string]$Backend, [string]$TargetHome, $Original) {
  $id=(Get-Date -Format 'yyyyMMddHHmmss')+'.'+[Guid]::NewGuid().ToString('N')
  $stage=Join-Path $TargetHome ('.usegoodai-models-'+$id)
  $snapshots=New-Object 'System.Collections.Generic.List[object]'
  $committed=New-Object 'System.Collections.Generic.List[int]'
  foreach ($file in $Files) {
    if (Test-PrivatePath $file.Path) {
      $content=Read-PrivateText $file.Path
      # Snapshot bytes as well as text, so rollback retains the original BOM/encoding exactly.
      $snapshots.Add(@{Text=$content; Bytes=[IO.File]::ReadAllBytes($file.Path)})
    } else { $snapshots.Add($null) }
  }
  $originalNow=if ($null -ne $snapshots[2]) { $snapshots[2].Text } else { $null }
  if (($null -eq $originalNow) -ne ($null -eq $Original) -or $originalNow -cne $Original) { throw '配置在导入过程中被修改，请重新运行。' }
  $null=[IO.Directory]::CreateDirectory($stage)
  try {
    for ($index=0; $index -lt $Files.Count; $index++) { Write-PrivateText (Join-Path $stage ('file-'+$index)) $Files[$index].Text }
    $stagedCatalog=Join-Path $stage 'file-0'
    $info=Get-ConfigInfo $Files[2].Text
    $levels=Get-TomlStringArray $info.Values['desktop.enabled-reasoning-efforts']
    $validationConfig='model_catalog_json = '+(ConvertTo-Json -InputObject $stagedCatalog -Compress)+"`n[desktop]`nenabled-reasoning-efforts = "+(ConvertTo-Json -InputObject @($levels) -Compress)+"`n"
    Write-PrivateText (Join-Path $stage 'config.toml') $validationConfig
    $validated=ConvertFrom-Json -InputObject (Invoke-CodexExport $Backend @('debug','models') $stage)
    Test-ModelCatalog $validated
    $expected=ConvertFrom-Json -InputObject $Files[0].Text
    $actualIds=New-OrdinalMap; foreach ($model in $validated.models) { $actualIds[$model.slug]=$true }
    if ($actualIds.Count -ne $expected.models.Count) { throw 'App 未读取暂存模型目录，停止导入。' }
    foreach ($model in $expected.models) { if (-not $actualIds.ContainsKey($model.slug)) { throw 'App 未读取暂存模型目录，停止导入。' } }
    for ($index=0; $index -lt $Files.Count; $index++) {
      $now=if (Test-PrivatePath $Files[$index].Path) { Read-PrivateText $Files[$index].Path } else { $null }
      $before=if ($null -ne $snapshots[$index]) { $snapshots[$index].Text } else { $null }
      if ($now -cne $before) { throw '配置在导入过程中被修改，请重新运行。' }
    }
    for ($index=0; $index -lt $Files.Count; $index++) {
      if ($null -ne $snapshots[$index]) { [IO.File]::Copy($Files[$index].Path,($Files[$index].Path+'.bak.'+$id),$false) }
    }
    for ($index=0; $index -lt $Files.Count; $index++) {
      $committed.Add($index)
      Move-StagedFile (Join-Path $stage ('file-'+$index)) $Files[$index].Path
    }
    # Validate the committed catalog without loading or changing the user's provider/auth.
    $validationConfig='model_catalog_json = '+(ConvertTo-Json -InputObject $Files[0].Path -Compress)+"`n[desktop]`nenabled-reasoning-efforts = "+(ConvertTo-Json -InputObject @($levels) -Compress)+"`n"
    Write-PrivateText (Join-Path $stage 'config.toml') $validationConfig
    $final=ConvertFrom-Json -InputObject (Invoke-CodexExport $Backend @('debug','models') $stage)
    Test-ModelCatalog $final
    $finalIds=New-OrdinalMap; foreach ($model in $final.models) { $finalIds[$model.slug]=$true }
    if ($finalIds.Count -ne $expected.models.Count) { throw 'App 未读取新模型目录，停止导入。' }
    foreach ($model in $expected.models) { if (-not $finalIds.ContainsKey($model.slug)) { throw 'App 未读取新模型目录，停止导入。' } }
    $normalized=ConvertTo-Json -InputObject (ConvertTo-CanonicalValue $validated.models) -Depth 100 -Compress
    $effective=ConvertTo-Json -InputObject (ConvertTo-CanonicalValue $final.models) -Depth 100 -Compress
    if ($normalized -cne $effective) { throw '已写入的模型元数据与本次导入不一致，停止导入。' }
    foreach ($file in $Files) {
      if ((Read-PrivateText $file.Path) -cne $file.Text) { throw '写入后的文件与本次导入不一致，停止导入。' }
    }
  } catch {
    $restoreFailed=$false
    for ($step=$committed.Count-1; $step -ge 0; $step--) {
      $index=$committed[$step]
      try {
        if ($null -eq $snapshots[$index]) { [IO.File]::Delete($Files[$index].Path) }
        else {
          $restorePath=Join-Path $stage ('restore-'+$index)
          [IO.File]::WriteAllBytes($restorePath,$snapshots[$index].Bytes)
          Move-StagedFile $restorePath $Files[$index].Path
        }
      } catch { $restoreFailed=$true }
    }
    if ($restoreFailed) { throw '写入失败且恢复未完成，请使用同目录的 .bak 备份恢复；软件未关闭。' }
    throw
  } finally {
    if ([IO.Directory]::Exists($stage)) { try { [IO.Directory]::Delete($stage,$true) } catch { } }
  }
}

function Find-DesktopBackend([string]$ExplicitPath) {
  if ($ExplicitPath) {
    $full=[IO.Path]::GetFullPath($ExplicitPath)
    if (-not [IO.File]::Exists($full)) { throw '指定的 App 后端文件不存在。' }
    return $full
  }
  $roots=New-Object 'System.Collections.Generic.List[string]'
  if (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue) {
    foreach ($package in @(Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction SilentlyContinue)) {
      if ($package.InstallLocation) { $roots.Add($package.InstallLocation); $roots.Add((Join-Path $package.InstallLocation 'app')) }
    }
  }
  foreach ($base in @($env:LOCALAPPDATA,$env:ProgramFiles)) {
    if (-not $base) { continue }
    foreach ($relative in @('Programs\Codex','Programs\ChatGPT','Codex','ChatGPT')) { $roots.Add((Join-Path $base $relative)) }
  }
  foreach ($root in $roots) {
    foreach ($relative in @('resources\codex.exe','resources\bin\codex.exe')) {
      $candidate=Join-Path $root $relative
      if ([IO.File]::Exists($candidate)) { return $candidate }
    }
  }
  throw '未找到桌面 App 自带的 Codex 后端；用 -CodexPath 指定其 resources 中的 codex.exe。'
}

function Start-ModelInstaller([string]$CodexHomePath, [string]$CodexPath) {
  if ($env:OS -ne 'Windows_NT') { throw '这个脚本用于 Windows；macOS 请运行 codex-models.sh。' }
  if (-not $CodexHomePath) { $CodexHomePath=if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' } }
  $targetHome=[IO.Path]::GetFullPath($CodexHomePath)
  Write-Host '成功导入后会自动关闭 ChatGPT/Codex，运行中的任务会中断。'
  $backend=Find-DesktopBackend $CodexPath
  $count=Invoke-ModelImport $targetHome $backend $DomesticCatalog
  Write-Host "已导入 $count 个国产模型，原 GPT 和其他模型已保留。"
  Report-RunningClients (Stop-RunningClients)
  Write-Host '重新打开 App，新建任务后选择模型；API Key 分组由你在中转站切换。'
}
