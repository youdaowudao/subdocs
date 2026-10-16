function Read-PrivateText([string]$Path) {
  $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw (New-ModelImportError '目标文件不是普通文件，停止导入。') }
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

function Read-ModelInput($ReadSet, [string]$Path, [string]$Step) {
  $full=[IO.Path]::GetFullPath($Path)
  foreach ($entry in $ReadSet) { if ([StringComparer]::OrdinalIgnoreCase.Equals($entry.Path,$full)) { return $entry.Text } }
  $text=Invoke-ModelStep $Step $full { if (Test-PrivatePath $full) { Read-PrivateText $full } else { $null } }
  $ReadSet.Add(@{Path=$full; Text=$text})
  return $text
}

function Test-ModelReadSet($ReadSet) {
  foreach ($entry in $ReadSet) {
    Invoke-ModelStep '核对导入期间的输入文件' $entry.Path {
      $now=if (Test-PrivatePath $entry.Path) { Read-PrivateText $entry.Path } else { $null }
      if (($null -eq $now) -ne ($null -eq $entry.Text) -or $now -cne $entry.Text) { throw (New-ModelImportError '配置或模型目录在导入过程中被修改，请重新运行。') }
    }
  }
}

function Read-ValidatedModelCatalog([string]$Path) {
  $catalog=ConvertFrom-ModelJson (Read-PrivateText $Path) '解析模型目录' $Path
  Test-ModelCatalog $catalog
  return $catalog
}

function Write-ModelTransaction($Files, [string]$TargetHome, $Original, $ReadSet=@()) {
  $id=(Get-Date -Format 'yyyyMMddHHmmss')+'.'+[Guid]::NewGuid().ToString('N')
  $stage=Join-Path $TargetHome ('.usegoodai-models-'+$id)
  $snapshots=New-Object 'System.Collections.Generic.List[object]'
  $committed=New-Object 'System.Collections.Generic.List[int]'
  $written=New-Object 'System.Collections.Generic.List[int]'
  Test-ModelReadSet $ReadSet
  foreach ($file in $Files) {
    $snapshot=Invoke-ModelStep '检查并读取写入前的原文件' $file.Path {
    if (Test-PrivatePath $file.Path) {
      $content=Read-PrivateText $file.Path
      # Snapshot bytes as well as text, so rollback retains the original BOM/encoding exactly.
      @{Text=$content; Bytes=[IO.File]::ReadAllBytes($file.Path)}
    } else { $null }
    }
    $snapshots.Add($snapshot)
  }
  $originalNow=if ($null -ne $snapshots[2]) { $snapshots[2].Text } else { $null }
  if (($null -eq $originalNow) -ne ($null -eq $Original) -or $originalNow -cne $Original) { throw (New-ModelImportError '配置在导入过程中被修改，请重新运行。') }
  Invoke-ModelStep '创建私有暂存目录' $stage { $null=[IO.Directory]::CreateDirectory($stage) }
  try {
    for ($index=0; $index -lt $Files.Count; $index++) {
      if ($Files[$index].Keep) { continue }
      Invoke-ModelStep '写入暂存文件' (Join-Path $stage ('file-'+$index)) { Write-PrivateText (Join-Path $stage ('file-'+$index)) $Files[$index].Text }
    }
    $stagedCatalog=Join-Path $stage 'file-0'
    if (-not $Files[2].Keep) { $null=Get-ConfigInfo (Read-PrivateText (Join-Path $stage 'file-2')) }
    $validated=Read-ValidatedModelCatalog $stagedCatalog
    $expected=ConvertFrom-Json -InputObject $Files[0].Text
    $actualIds=New-OrdinalMap; foreach ($model in $validated.models) { $actualIds[$model.slug]=$true }
    if ($actualIds.Count -ne $expected.models.Count) { throw (New-ModelImportError '暂存模型目录与本次导入不一致，停止导入。') }
    foreach ($model in $expected.models) { if (-not $actualIds.ContainsKey($model.slug)) { throw (New-ModelImportError '暂存模型目录与本次导入不一致，停止导入。') } }
    Test-ModelReadSet $ReadSet
    for ($index=0; $index -lt $Files.Count; $index++) {
      $now=if (Test-PrivatePath $Files[$index].Path) { Read-PrivateText $Files[$index].Path } else { $null }
      $before=if ($null -ne $snapshots[$index]) { $snapshots[$index].Text } else { $null }
      if (($null -eq $now) -ne ($null -eq $before) -or $now -cne $before) { throw (New-ModelImportError '配置在导入过程中被修改，请重新运行。') }
    }
    for ($index=0; $index -lt $Files.Count; $index++) {
      if ($Files[$index].Keep) { continue }
      if ($null -ne $snapshots[$index]) { Invoke-ModelStep '备份原文件' $Files[$index].Path { [IO.File]::Copy($Files[$index].Path,($Files[$index].Path+'.bak.'+$id),$false) } }
    }
    for ($index=0; $index -lt $Files.Count; $index++) {
      if ($Files[$index].Keep) { continue }
      $committed.Add($index)
      Invoke-ModelStep '提交导入文件' $Files[$index].Path { Move-StagedFile (Join-Path $stage ('file-'+$index)) $Files[$index].Path }
      $written.Add($index)
    }
    # Check the committed files locally; never launch or control an App process.
    $final=Read-ValidatedModelCatalog $Files[0].Path
    $finalIds=New-OrdinalMap; foreach ($model in $final.models) { $finalIds[$model.slug]=$true }
    if ($finalIds.Count -ne $expected.models.Count) { throw (New-ModelImportError '已写入模型目录与本次导入不一致，停止导入。') }
    foreach ($model in $expected.models) { if (-not $finalIds.ContainsKey($model.slug)) { throw (New-ModelImportError '已写入模型目录与本次导入不一致，停止导入。') } }
    $normalized=ConvertTo-Json -InputObject (ConvertTo-CanonicalValue $validated.models) -Depth 100 -Compress
    $effective=ConvertTo-Json -InputObject (ConvertTo-CanonicalValue $final.models) -Depth 100 -Compress
    if ($normalized -cne $effective) { throw (New-ModelImportError '已写入的模型元数据与本次导入不一致，停止导入。') }
    foreach ($file in $Files) {
      $now=if (Test-PrivatePath $file.Path) { Read-PrivateText $file.Path } else { $null }
      if (($null -eq $now) -ne ($null -eq $file.Text) -or $now -cne $file.Text) { throw (New-ModelImportError '写入后的文件与本次导入不一致，停止导入。') }
    }
  } catch {
    if ($committed.Count) {
      $conflictPath=$null
      for ($index=0; $index -lt $Files.Count; $index++) {
        $now=$null; $found=$false
        try {
          $null=Get-Item -LiteralPath $Files[$index].Path -Force -ErrorAction Stop
          $found=$true
          $now=Read-PrivateText $Files[$index].Path
        } catch {
          if ($found -or $_.CategoryInfo.Category -ne [System.Management.Automation.ErrorCategory]::ObjectNotFound) { $conflictPath=$Files[$index].Path; break }
        }
        $matchesOutput=$null -ne $now -and $now -ceq $Files[$index].Text
        $matchesBefore=if ($null -eq $snapshots[$index]) { $null -eq $now } else { $null -ne $now -and $now -ceq $snapshots[$index].Text }
        if (-not $matchesOutput -and ($written.Contains($index) -or -not $matchesBefore)) { $conflictPath=$Files[$index].Path; break }
      }
      if ($conflictPath) {
        $problem=New-ModelImportError '导入过程中出现外部修改，已保留当前内容和备份，软件未关闭。'
        $problem.Data['ModelImportStep']='核对失败后的文件状态'; $problem.Data['ModelImportTarget']=$conflictPath
        throw $problem
      }
    }
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
    if ($restoreFailed) { throw (New-ModelImportError '写入失败且恢复未完成，请使用同目录的 .bak 备份恢复；软件未关闭。') }
    throw
  } finally {
    if ([IO.Directory]::Exists($stage)) { try { [IO.Directory]::Delete($stage,$true) } catch { } }
  }
}

function Start-ModelInstaller([string]$CodexHomePath, [string]$CodexPath, [switch]$Uninstall) {
  if ($env:OS -ne 'Windows_NT') { throw (New-ModelImportError '这个脚本用于 Windows；macOS 请运行 codex-models.sh。') }
  if (-not $CodexHomePath) { $CodexHomePath=if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' } }
  $targetHome=[IO.Path]::GetFullPath($CodexHomePath)
  # CodexPath remains accepted for compatibility with saved commands, but is
  # deliberately unused. Windows import and uninstall only read/write files.
  if ($Uninstall) {
    $result=Remove-ImportedModels $targetHome
    if (-not $result.Changed) { Write-Host '没有需要移除的国产模型。'; return }
    Write-Host '已移除本工具导入的国产模型，原 GPT 和其他模型已保留。'
    if ($result.Active) { Write-Host '请手动退出并重新打开 ChatGPT App，新建任务后选择模型。' }
    return
  }
  $count=Invoke-ModelImport $targetHome $DomesticCatalog
  Write-Host "已写入 $count 个国产模型的配置，原 GPT 和其他模型已保留。"
  Write-Host '请手动退出并重新打开 ChatGPT App，新建任务后选择模型；API Key 分组由你在中转站切换。'
}
