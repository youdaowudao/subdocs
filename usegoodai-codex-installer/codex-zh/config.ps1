function New-ConfigError([string]$Message) {
    return [FormatException]::new($Message)
}

# TOML statement and key scanning adapted from codex-domestic-models/src/core.ps1.
function New-TomlSyntaxError([string]$Message, [string]$Text, [int]$Offset) {
  $prefix=$Text.Substring(0,[Math]::Min($Offset,$Text.Length))
  $line=1; foreach ($character in $prefix.ToCharArray()) { if ([int]$character -eq 10) { $line++ } }
  $column=$prefix.Length-$prefix.LastIndexOf("`n")
  return (New-ConfigError ($Message+' 第 '+$line+' 行，第 '+$column+' 列。'))
}

function Get-TomlString([string]$Raw) {
  $value = $Raw.Trim()
  if ($value -cmatch "^'[^'\r\n]*'$") { return $value.Substring(1, $value.Length - 2) }
  if ($value -cmatch '^"(?:[^"\\\r\n]|\\.)*"$') {
    try {
      $value = [regex]::Replace($value, '\\(?:U[0-9a-fA-F]{8}|e|[\s\S])', {
        param($match)
        $token=$match.Value
        if ($token -ceq '\e') { return '\u001b' }
        if ($token[1] -cne 'U' -or $token.Length -ne 10) { return $token }
        $decoded=[char]::ConvertFromUtf32([Convert]::ToInt32($token.Substring(2),16))
        $encoded=ConvertTo-Json -InputObject $decoded -Compress
        return $encoded.Substring(1,$encoded.Length-2)
      })
      return ($value | ConvertFrom-Json -ErrorAction Stop)
    } catch { throw (New-ConfigError 'TOML 字符串格式无效。') }
  }
  throw (New-ConfigError '配置键必须是单行 TOML 字符串。')
}

function Get-TomlKeyParts([string]$Raw) {
  $parts = New-Object 'System.Collections.Generic.List[string]'
  $pos = 0
  $pattern = '\s*("(?:[^"\\]|\\.)*"|''[^'']*''|[A-Za-z0-9_-]+)\s*'
  while ($pos -lt $Raw.Length) {
    $match = [regex]::Match($Raw.Substring($pos), '^' + $pattern)
    if (-not $match.Success) { throw (New-ConfigError '无法识别 TOML 字段或配置段。') }
    $key = $match.Groups[1].Value
    if ($key.StartsWith('"') -or $key.StartsWith("'")) { $key = Get-TomlString $key }
    $parts.Add($key)
    $pos += $match.Length
    if ($pos -eq $Raw.Length) { break }
    if ($Raw[$pos] -cne '.') { throw (New-ConfigError 'TOML 字段路径无效。') }
    $pos += 1
    if ($pos -eq $Raw.Length) { throw (New-ConfigError 'TOML 字段路径以点结尾。') }
  }
  if (-not $parts.Count) { throw (New-ConfigError '空 TOML 字段。') }
  return ,$parts.ToArray()
}

function Get-TomlStatements([string]$Text) {
  $records = New-Object 'System.Collections.Generic.List[object]'
  $depth = New-Object 'System.Collections.Generic.Stack[char]'
  $clean = New-Object System.Text.StringBuilder
  $start = 0; $quote = ''; $quoteStart = 0; $triple = $false; $escaped = $false; $comment = $false
  for ($i = 0; $i -lt $Text.Length; $i++) {
    $ch = [string]$Text[$i]
    if ($comment) {
      if ($ch -cne "`n") { [void]$clean.Append(' '); continue }
      $comment = $false
    }
    if ($quote) {
      [void]$clean.Append($ch)
      if ($escaped) { $escaped = $false; continue }
      if ($quote -ceq '"' -and $ch -ceq '\') { $escaped = $true; continue }
      if ($ch -ceq $quote) {
        if (-not $triple) { $quote = '' }
        elseif ($i + 2 -lt $Text.Length -and $Text.Substring($i, 3) -ceq ($quote * 3)) {
          $run = 3
          while ($run -lt 5 -and $i + $run -lt $Text.Length -and [string]$Text[$i + $run] -ceq $quote) { $run += 1 }
          [void]$clean.Append($Text.Substring($i + 1, $run - 1)); $i += $run - 1; $quote = ''; $triple = $false
        }
      } elseif ($ch -ceq "`n" -and -not $triple) { throw (New-TomlSyntaxError 'TOML 字符串未闭合。' $Text $quoteStart) }
      continue
    }
    if ($ch -ceq '#') { $comment = $true; [void]$clean.Append(' '); continue }
    if ($ch -ceq '"' -or $ch -ceq "'") {
      $quote = $ch; $quoteStart = $i; $triple = $i + 2 -lt $Text.Length -and $Text.Substring($i, 3) -ceq ($ch * 3)
      [void]$clean.Append($ch)
      if ($triple) { [void]$clean.Append($ch * 2); $i += 2 }
      continue
    }
    if ($ch -ceq '[' -or $ch -ceq '{') { $depth.Push([char]$ch) }
    if ($ch -ceq ']' -or $ch -ceq '}') {
      $expected = if ($ch -ceq ']') { '[' } else { '{' }
      if (-not $depth.Count -or [string]$depth.Pop() -cne $expected) { throw (New-TomlSyntaxError 'TOML 括号不匹配。' $Text $i) }
    }
    [void]$clean.Append($ch)
    if ($ch -ceq "`n" -and -not $depth.Count) {
      $records.Add(@{Start=$start; End=$i+1; Code=$clean.ToString()}); $start=$i+1; [void]$clean.Clear()
    }
  }
  if ($quote) { throw (New-TomlSyntaxError 'TOML 字符串未闭合。' $Text $quoteStart) }
  if ($depth.Count) { throw (New-TomlSyntaxError 'TOML 括号未闭合。' $Text $Text.Length) }
  if ($start -lt $Text.Length) { $records.Add(@{Start=$start; End=$Text.Length; Code=$clean.ToString()}) }
  return ,$records.ToArray()
}

function Set-CodexChineseLocale([string]$Text) {
    $newline = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $records = Get-TomlStatements $Text
    $scope = @()
    $firstTable = $Text.Length
    $desktopTable = $null
    $rootDesktopKeys = $false
    $desktopChildren = $false
    $locale = $null
    $assignment = 'localeOverride = "zh-CN"'

    foreach ($record in $records) {
        $code = $record.Code.Trim()
        if (-not $code) { continue }

        if ($code.StartsWith('[')) {
            $header = [regex]::Match($code, '^(\[\[?)([\s\S]*?)(\]\]?)$')
            if (-not $header.Success -or $header.Groups[1].Length -ne $header.Groups[3].Length) {
                throw (New-ConfigError 'TOML 配置段无效。')
            }
            if ($firstTable -eq $Text.Length) { $firstTable = $record.Start }
            $scope = Get-TomlKeyParts $header.Groups[2].Value.Trim()
            if ($scope[0] -ceq 'desktop') {
                if ($scope.Count -eq 1) {
                    if ($desktopTable -or $rootDesktopKeys -or $header.Groups[1].Value -ceq '[[') {
                        throw (New-ConfigError 'desktop 配置段重复或格式无效。')
                    }
                    $desktopTable = $record
                } else {
                    if ($scope[1] -ceq 'localeOverride') {
                        throw (New-ConfigError 'localeOverride 必须是单个字符串。')
                    }
                    $desktopChildren = $true
                }
            }
            continue
        }

        $keyValue = [regex]::Match($record.Code, '^(?<key>(?:"(?:[^"\\]|\\.)*"|''[^'']*''|[^"''=])+?)=')
        if (-not $keyValue.Success) { throw (New-ConfigError 'TOML 配置行无效。') }
        $parts = Get-TomlKeyParts $keyValue.Groups['key'].Value.Trim()
        $path = @($scope) + @($parts)
        if ($path[0] -cne 'desktop') { continue }
        if ($scope.Count -eq 0) {
            if ($parts.Count -eq 1) {
                throw (New-ConfigError 'desktop 使用内联表或标量，无法只改语言字段。')
            }
            $rootDesktopKeys = $true
        }
        if ($path[1] -cne 'localeOverride') { continue }
        if ($path.Count -ne 2 -or $locale) { throw (New-ConfigError 'localeOverride 重复或格式无效。') }
        $value = [regex]::Match($record.Code.Substring($keyValue.Length), '^\s*(?<value>"(?:[^"\\\r\n]|\\.)*"|''[^''\r\n]*'')\s*$')
        if (-not $value.Success) { throw (New-ConfigError 'localeOverride 必须是单行字符串。') }
        $locale = $value.Groups['value']
        $valueStart = $record.Start + $keyValue.Length + $locale.Index
    }

    if ($locale) {
        if ((Get-TomlString $locale.Value) -ceq 'zh-CN') { return $Text }
        return $Text.Remove($valueStart, $locale.Length).Insert($valueStart, '"zh-CN"')
    }
    if ($desktopTable) {
        $lead = if ($Text[$desktopTable.End - 1] -eq "`n") { '' } else { $newline }
        return $Text.Insert($desktopTable.End, $lead + $assignment + $newline)
    }
    if ($rootDesktopKeys) {
        $lead = if ($firstTable -gt 0 -and $Text[$firstTable - 1] -ne "`n") { $newline } else { '' }
        return $Text.Insert($firstTable, $lead + 'desktop.' + $assignment + $newline)
    }

    $lead = if ($Text.Length -and -not $Text.EndsWith("`n")) { $newline } else { '' }
    if ($desktopChildren) {
        return $Text.Insert($firstTable, '[desktop]' + $newline + $assignment + $newline + $newline)
    }
    return $Text + $lead + '[desktop]' + $newline + $assignment + $newline
}

function Get-CodexLocaleEdit([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($item -and ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint))) {
        throw (New-ConfigError 'config.toml 不是普通文件，已停止。')
    }
    [byte[]]$bytes = @()
    if ($item) { $bytes = [IO.File]::ReadAllBytes($Path) }
    $hasBom = $bytes.Count -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $offset = if ($hasBom) { 3 } else { 0 }
    $encoding = [Text.UTF8Encoding]::new($hasBom, $true)
    $text = $encoding.GetString([byte[]]$bytes, $offset, $bytes.Count - $offset)
    $updated = Set-CodexChineseLocale $text
    return @{
        Path = $Path
        Exists = [bool]$item
        Original = [Convert]::ToBase64String([byte[]]$bytes)
        Text = $updated
        Changed = $updated -cne $text
        Encoding = $encoding
    }
}

function Save-CodexLocaleEdit($Edit) {
    $current = Get-CodexLocaleEdit $Edit.Path
    if ($current.Exists -ne $Edit.Exists -or $current.Original -cne $Edit.Original) {
        throw 'config.toml 在运行期间被修改，请重新运行。'
    }
    if (-not $Edit.Changed) { return }

    $parent = [IO.Path]::GetDirectoryName($Edit.Path)
    $null = [IO.Directory]::CreateDirectory($parent)
    $id = [Guid]::NewGuid().ToString('N')
    $temp = $Edit.Path + '.codex-zh.tmp.' + $id
    try {
        [IO.File]::WriteAllText($temp, $Edit.Text, $Edit.Encoding)
        if ($Edit.Exists) {
            [IO.File]::Replace($temp, $Edit.Path, $Edit.Path + '.codex-zh.bak.' + $id)
        } else {
            [IO.File]::Move($temp, $Edit.Path)
        }
    } finally {
        if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) }
    }
}
