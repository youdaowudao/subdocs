#Requires -Version 5.1
param([string]$CodexHomePath, [string]$CodexPath)
$ErrorActionPreference = 'Stop'
function Say([string]$Message) { Write-Host $Message }
$DomesticCatalog = ConvertFrom-Json -InputObject @'
{"models": [{"slug": "qwen3.8-max", "display_name": "Qwen3.8 Max", "description": "千问 Max", "context_window": 1000000, "input_modalities": ["text", "image"], "default_reasoning_level": "xhigh", "apply_patch_tool_type": null, "supports_parallel_tool_calls": true, "supported_reasoning_levels": [{"effort": "low", "description": "轻度推理"}, {"effort": "medium", "description": "中度推理"}, {"effort": "xhigh", "description": "深度推理"}], "shell_type": "shell_command", "visibility": "list", "supported_in_api": true, "priority": 100, "availability_nux": null, "upgrade": null, "support_verbosity": false, "default_verbosity": null, "supports_reasoning_summaries": true, "supports_reasoning_summary_parameter": false, "default_reasoning_summary": "none", "prefer_websockets": false, "web_search_tool_type": "text", "supports_search_tool": false, "truncation_policy": {"mode": "tokens", "limit": 10000}, "supports_image_detail_original": false, "max_context_window": 1000000, "auto_compact_token_limit": null, "effective_context_window_percent": 95, "experimental_supported_tools": [], "base_instructions": "You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence.", "model_messages": {"instructions_template": "You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence."}, "use_responses_lite": false}, {"slug": "qwen3.8-flash", "display_name": "Qwen3.8 Flash", "description": "千问 Flash", "context_window": 1000000, "input_modalities": ["text", "image"], "default_reasoning_level": "xhigh", "apply_patch_tool_type": null, "supports_parallel_tool_calls": true, "supported_reasoning_levels": [{"effort": "low", "description": "轻度推理"}, {"effort": "medium", "description": "中度推理"}, {"effort": "xhigh", "description": "深度推理"}], "shell_type": "shell_command", "visibility": "list", "supported_in_api": true, "priority": 101, "availability_nux": null, "upgrade": null, "support_verbosity": false, "default_verbosity": null, "supports_reasoning_summaries": true, "supports_reasoning_summary_parameter": false, "default_reasoning_summary": "none", "prefer_websockets": false, "web_search_tool_type": "text", "supports_search_tool": false, "truncation_policy": {"mode": "tokens", "limit": 10000}, "supports_image_detail_original": false, "max_context_window": 1000000, "auto_compact_token_limit": null, "effective_context_window_percent": 95, "experimental_supported_tools": [], "base_instructions": "You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence.", "model_messages": {"instructions_template": "You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence."}, "use_responses_lite": false}, {"slug": "glm-5.3-flash", "display_name": "GLM-5.3 Flash", "description": "智谱多模态 Flash", "context_window": 1000000, "input_modalities": ["text", "image"], "default_reasoning_level": "max", "apply_patch_tool_type": null, "supports_parallel_tool_calls": false, "supported_reasoning_levels": [{"effort": "low", "description": "轻度推理"}, {"effort": "high", "description": "增强推理"}, {"effort": "max", "description": "最大推理"}], "shell_type": "shell_command", "visibility": "list", "supported_in_api": true, "priority": 102, "availability_nux": null, "upgrade": null, "support_verbosity": false, "default_verbosity": null, "supports_reasoning_summaries": true, "supports_reasoning_summary_parameter": false, "default_reasoning_summary": "none", "prefer_websockets": false, "web_search_tool_type": "text", "supports_search_tool": false, "truncation_policy": {"mode": "tokens", "limit": 10000}, "supports_image_detail_original": false, "max_context_window": 1000000, "auto_compact_token_limit": null, "effective_context_window_percent": 95, "experimental_supported_tools": [], "base_instructions": "You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence.", "model_messages": {"instructions_template": "You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence."}, "use_responses_lite": false}, {"slug": "deepseek-flash", "display_name": "DeepSeek V4.1 Flash", "description": "DeepSeek Flash", "context_window": 1048576, "input_modalities": ["text", "image"], "default_reasoning_level": "high", "apply_patch_tool_type": "freeform", "supports_parallel_tool_calls": true, "supported_reasoning_levels": [{"effort": "low", "description": "轻度推理"}, {"effort": "high", "description": "增强推理"}, {"effort": "max", "description": "最大推理"}], "shell_type": "shell_command", "visibility": "list", "supported_in_api": true, "priority": 103, "availability_nux": null, "upgrade": null, "support_verbosity": true, "default_verbosity": "low", "supports_reasoning_summaries": true, "supports_reasoning_summary_parameter": false, "default_reasoning_summary": "none", "prefer_websockets": false, "web_search_tool_type": "text", "supports_search_tool": false, "truncation_policy": {"mode": "tokens", "limit": 10000}, "supports_image_detail_original": true, "max_context_window": 1048576, "auto_compact_token_limit": null, "effective_context_window_percent": 95, "experimental_supported_tools": [], "base_instructions": "You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence.", "model_messages": {"instructions_template": "You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence."}, "use_responses_lite": false}, {"slug": "glm-5.3", "display_name": "GLM-5.3", "description": "智谱文本模型", "context_window": 1000000, "input_modalities": ["text"], "default_reasoning_level": "max", "apply_patch_tool_type": null, "supports_parallel_tool_calls": false, "supported_reasoning_levels": [{"effort": "low", "description": "轻度推理"}, {"effort": "high", "description": "增强推理"}, {"effort": "max", "description": "最大推理"}], "shell_type": "shell_command", "visibility": "list", "supported_in_api": true, "priority": 104, "availability_nux": null, "upgrade": null, "support_verbosity": false, "default_verbosity": null, "supports_reasoning_summaries": true, "supports_reasoning_summary_parameter": false, "default_reasoning_summary": "none", "prefer_websockets": false, "web_search_tool_type": "text", "supports_search_tool": false, "truncation_policy": {"mode": "tokens", "limit": 10000}, "supports_image_detail_original": false, "max_context_window": 1000000, "auto_compact_token_limit": null, "effective_context_window_percent": 95, "experimental_supported_tools": [], "base_instructions": "You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence.", "model_messages": {"instructions_template": "You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence."}, "use_responses_lite": false}, {"slug": "kimi-k3", "display_name": "Kimi K3", "description": "月之暗面多模态模型", "context_window": 1000000, "input_modalities": ["text", "image"], "default_reasoning_level": "max", "apply_patch_tool_type": null, "supports_parallel_tool_calls": false, "supported_reasoning_levels": [{"effort": "low", "description": "轻度推理"}, {"effort": "high", "description": "增强推理"}, {"effort": "max", "description": "最大推理"}], "shell_type": "shell_command", "visibility": "list", "supported_in_api": true, "priority": 105, "availability_nux": null, "upgrade": null, "support_verbosity": false, "default_verbosity": null, "supports_reasoning_summaries": true, "supports_reasoning_summary_parameter": false, "default_reasoning_summary": "none", "prefer_websockets": false, "web_search_tool_type": "text", "supports_search_tool": false, "truncation_policy": {"mode": "tokens", "limit": 10000}, "supports_image_detail_original": false, "max_context_window": 1000000, "auto_compact_token_limit": null, "effective_context_window_percent": 95, "experimental_supported_tools": [], "base_instructions": "You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence.", "model_messages": {"instructions_template": "You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence."}, "use_responses_lite": false}, {"slug": "minimax-m3", "display_name": "MiniMax M3", "description": "MiniMax 多模态模型", "context_window": 1000000, "input_modalities": ["text", "image"], "default_reasoning_level": null, "apply_patch_tool_type": null, "supports_parallel_tool_calls": false, "supported_reasoning_levels": [], "shell_type": "shell_command", "visibility": "list", "supported_in_api": true, "priority": 106, "availability_nux": null, "upgrade": null, "support_verbosity": false, "default_verbosity": null, "supports_reasoning_summaries": false, "supports_reasoning_summary_parameter": false, "default_reasoning_summary": "none", "prefer_websockets": false, "web_search_tool_type": "text", "supports_search_tool": false, "truncation_policy": {"mode": "tokens", "limit": 10000}, "supports_image_detail_original": false, "max_context_window": 1000000, "auto_compact_token_limit": null, "effective_context_window_percent": 95, "experimental_supported_tools": [], "base_instructions": "You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence.", "model_messages": {"instructions_template": "You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence."}, "use_responses_lite": false}, {"slug": "hy4-preview", "display_name": "Hy4 preview", "description": "腾讯混元", "context_window": 1000000, "input_modalities": ["text"], "default_reasoning_level": "high", "apply_patch_tool_type": null, "supports_parallel_tool_calls": false, "supported_reasoning_levels": [{"effort": "none", "description": "关闭推理"}, {"effort": "high", "description": "增强推理"}], "shell_type": "shell_command", "visibility": "list", "supported_in_api": true, "priority": 107, "availability_nux": null, "upgrade": null, "support_verbosity": false, "default_verbosity": null, "supports_reasoning_summaries": true, "supports_reasoning_summary_parameter": false, "default_reasoning_summary": "none", "prefer_websockets": false, "web_search_tool_type": "text", "supports_search_tool": false, "truncation_policy": {"mode": "tokens", "limit": 10000}, "supports_image_detail_original": false, "max_context_window": 1000000, "auto_compact_token_limit": null, "effective_context_window_percent": 95, "experimental_supported_tools": [], "base_instructions": "You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence.", "model_messages": {"instructions_template": "You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence."}, "use_responses_lite": false}]}
'@
function Get-RunningCodexClients {
  $sessionId = (Get-Process -Id $PID).SessionId
  return @(
    Get-Process -Name "codex", "chatgpt" -ErrorAction SilentlyContinue |
      Where-Object { $_.SessionId -eq $sessionId }
  )
}

function Get-OwnProcessIds {
  $ids = @()
  $current = $PID
  while ($current -and ($ids -notcontains $current)) {
    $ids += $current
    $process = Get-CimInstance Win32_Process -Filter "ProcessId = $current" -ErrorAction Stop
    if ($process) {
      $current = $process.ParentProcessId
    } else {
      $current = 0
    }
  }
  return $ids
}

function Test-ProcessExited($Process) {
  try {
    return $Process.HasExited
  } catch {
    return $false
  }
}

function Stop-RunningClients {
  $result = @{ ChatGPT = $false; Codex = $false; Left = $false }
  try {
    $clients = @(Get-RunningCodexClients)
    $result.ChatGPT = @($clients | Where-Object { $_.ProcessName -ieq "chatgpt" }).Count -gt 0
    $result.Codex = @($clients | Where-Object { $_.ProcessName -ieq "codex" }).Count -gt 0
    if ($clients.Count -eq 0) {
      return $result
    }

    $ownIds = @(Get-OwnProcessIds)
    $targets = @($clients | Where-Object { $ownIds -notcontains $_.Id })
    if ($targets.Count -lt $clients.Count) {
      $result.Left = $true
    }
    if ($targets.Count -gt 0) {
      $targets | Stop-Process -Force -ErrorAction SilentlyContinue
      for ($attempt = 0; $attempt -le 10; $attempt++) {
        if ($attempt -gt 0) {
          Start-Sleep -Milliseconds 500
        }
        $remaining = @($targets | Where-Object { -not (Test-ProcessExited $_) })
        if ($remaining.Count -eq 0) {
          break
        }
      }
      if ($remaining.Count -gt 0) {
        $result.Left = $true
      }
    }
  } catch {
    $result.Left = $true
  }
  return $result
}

function Report-RunningClients($Result) {
  if ($Result.ChatGPT -and $Result.Codex) {
    $clients = "ChatGPT 软件和 Codex"
  } elseif ($Result.ChatGPT) {
    $clients = "ChatGPT 软件"
  } elseif ($Result.Codex) {
    $clients = "Codex"
  } elseif ($Result.Left) {
    $clients = "ChatGPT 软件和 Codex"
  } else {
    Say "当前未检测到 ChatGPT/Codex CLI 运行，请启动软件后进行测试。"
    return
  }

  if ($Result.Left) {
    Say "未能自动关闭 ${clients}，请重启电脑后，重新打开并新建对话测试，如有问题请联系网站客服。"
    return
  }
  Say "已自动关闭 ${clients}，请重新打开并新建对话测试，如有问题请联系网站客服。"
}
# Windows PowerShell 5.1 compatible. Keep behavior in sync with core.js via parity tests.
function New-OrdinalMap {
  return ,(New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::Ordinal))
}

function ConvertTo-CanonicalValue($Value) {
  if ($null -eq $Value) { return $null }
  if ($Value -is [Array]) {
    $items=New-Object 'System.Collections.Generic.List[object]'
    foreach ($item in $Value) { $items.Add((ConvertTo-CanonicalValue $item)) }
    return ,$items.ToArray()
  }
  if ($Value -is [pscustomobject]) {
    $result=[ordered]@{}
    foreach ($name in ($Value.PSObject.Properties.Name | Sort-Object -CaseSensitive)) { $result[$name]=ConvertTo-CanonicalValue $Value.$name }
    return $result
  }
  return $Value
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
    } catch { throw 'TOML 字符串格式无效。' }
  }
  throw '模型目录、默认模型等目标字段须使用单行 TOML 字符串。'
}

function Get-TomlKeyParts([string]$Raw) {
  $parts = New-Object 'System.Collections.Generic.List[string]'
  $pos = 0
  $pattern = '\s*("(?:[^"\\]|\\.)*"|''[^'']*''|[A-Za-z0-9_-]+)\s*'
  while ($pos -lt $Raw.Length) {
    $match = [regex]::Match($Raw.Substring($pos), '^' + $pattern)
    if (-not $match.Success) { throw '无法识别 TOML 字段或配置段。' }
    $key = $match.Groups[1].Value
    if ($key.StartsWith('"') -or $key.StartsWith("'")) { $key = Get-TomlString $key }
    $parts.Add($key)
    $pos += $match.Length
    if ($pos -eq $Raw.Length) { break }
    if ($Raw[$pos] -cne '.') { throw 'TOML 字段路径无效。' }
    $pos += 1
  }
  if (-not $parts.Count) { throw '空 TOML 字段。' }
  return ,$parts.ToArray()
}

function Get-TomlStatements([string]$Text) {
  $records = New-Object 'System.Collections.Generic.List[object]'
  $depth = New-Object 'System.Collections.Generic.Stack[char]'
  $clean = New-Object System.Text.StringBuilder
  $start = 0; $quote = ''; $triple = $false; $escaped = $false; $comment = $false
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
      } elseif ($ch -ceq "`n" -and -not $triple) { throw 'TOML 字符串未闭合。' }
      continue
    }
    if ($ch -ceq '#') { $comment = $true; [void]$clean.Append(' '); continue }
    if ($ch -ceq '"' -or $ch -ceq "'") {
      $quote = $ch; $triple = $i + 2 -lt $Text.Length -and $Text.Substring($i, 3) -ceq ($ch * 3)
      [void]$clean.Append($ch)
      if ($triple) { [void]$clean.Append($ch * 2); $i += 2 }
      continue
    }
    if ($ch -ceq '[' -or $ch -ceq '{') { $depth.Push([char]$ch) }
    if ($ch -ceq ']' -or $ch -ceq '}') {
      $expected = if ($ch -ceq ']') { '[' } else { '{' }
      if (-not $depth.Count -or [string]$depth.Pop() -cne $expected) { throw 'TOML 括号不匹配。' }
    }
    [void]$clean.Append($ch)
    if ($ch -ceq "`n" -and -not $depth.Count) {
      $records.Add(@{Start=$start; End=$i+1; Code=$clean.ToString()}); $start=$i+1; [void]$clean.Clear()
    }
  }
  if ($quote -or $depth.Count) { throw 'TOML 字符串或括号未闭合。' }
  if ($start -lt $Text.Length) { $records.Add(@{Start=$start; End=$Text.Length; Code=$clean.ToString()}) }
  return ,$records.ToArray()
}

function Get-ConfigInfo([string]$Text) {
  $info = @{Values=(New-OrdinalMap); Edits=(New-OrdinalMap); FirstHeader=$Text.Length; Desktop=$null; DesktopInline=$false; DesktopDotted=$false}
  $scope = @()
  foreach ($rec in (Get-TomlStatements $Text)) {
    $code = $rec.Code.Trim([char[]]@(' ', "`r", "`n", "`t", [char]0xFEFF))
    if (-not $code) { continue }
    if ($code.StartsWith('[')) {
      $header = [regex]::Match($code, '^(\[\[?)([\s\S]*?)(\]\]?)$')
      if (-not $header.Success -or $header.Groups[1].Length -ne $header.Groups[3].Length) { throw 'TOML 配置段无效。' }
      $scope = Get-TomlKeyParts $header.Groups[2].Value.Trim()
      $info.FirstHeader = [Math]::Min($info.FirstHeader, $rec.Start)
      if ($scope.Count -eq 1 -and $scope[0] -ceq 'desktop') {
        if ($header.Groups[1].Value -ceq '[[' -or $null -ne $info.Desktop) { throw 'desktop 配置段重复或格式无效。' }
        $info.Desktop = $rec
      }
      continue
    }
    $q=''; $esc=$false
    for ($eq=0; $eq -lt $rec.Code.Length; $eq++) {
      $ch = [string]$rec.Code[$eq]
      if ($q) {
        if ($esc) { $esc=$false } elseif ($ch -ceq '\' -and $q -ceq '"') { $esc=$true } elseif ($ch -ceq $q) { $q='' }
      } elseif ($ch -ceq '"' -or $ch -ceq "'") { $q=$ch } elseif ($ch -ceq '=') { break }
    }
    if ($eq -eq $rec.Code.Length) { throw 'TOML 配置行无效。' }
    $parts = Get-TomlKeyParts $rec.Code.Substring(0,$eq).Trim().TrimStart([char]0xFEFF)
    $path = @($scope) + @($parts); $key = $path -join '.'
    if (-not $scope.Count -and $parts[0] -ceq 'desktop') {
      $info.DesktopInline = $parts.Count -eq 1
      $info.DesktopDotted = $parts.Count -gt 1 -or $info.DesktopDotted
    }
    if ($path.Count -gt 1 -and $path[0] -ceq 'profiles' -and $path[-1] -ceq 'model_catalog_json') { throw 'profile 中另有 model_catalog_json；请先统一目录配置再导入。' }
    if (($path.Count -eq 1 -and @('model_catalog_json','model','review_model','profile','model_provider') -ccontains $key) -or ($path.Count -eq 2 -and $key -ceq 'desktop.enabled-reasoning-efforts')) {
      if ($info.Edits.ContainsKey($key)) { throw '目标 TOML 字段重复。' }
      $vstart = $eq + 1
      while ($vstart -lt $rec.Code.Length -and [char]::IsWhiteSpace($rec.Code[$vstart])) { $vstart += 1 }
      $vend = $rec.Code.TrimEnd().Length
      $info.Edits[$key] = @{Start=$rec.Start+$vstart; End=$rec.Start+$vend}
      $info.Values[$key] = $rec.Code.Substring($vstart,$vend-$vstart)
    }
  }
  if ($info.DesktopInline) { throw 'desktop 使用内联表；请改为 [desktop] 配置段后导入。' }
  return $info
}

function Get-TomlStringArray([string]$Raw) {
  $body = $Raw.Trim(); $items = New-Object 'System.Collections.Generic.List[string]'
  if (-not $body.StartsWith('[') -or -not $body.EndsWith(']')) { throw '桌面推理档位必须是字符串数组。' }
  $body = $body.Substring(1,$body.Length-2)
  $pos=0
  while ($pos -lt $body.Length -and $body.Substring($pos).Trim()) {
    $match = [regex]::Match($body.Substring($pos),'^\s*("(?:[^"\\]|\\.)*"|''[^'']*'')\s*(,|$)')
    if (-not $match.Success) { throw '桌面推理档位必须是字符串数组。' }
    $items.Add((Get-TomlString $match.Groups[1].Value)); $pos += $match.Length
  }
  return ,$items.ToArray()
}

function Set-ModelConfig([string]$Text, $Info, [string]$CatalogPath, [string[]]$Efforts) {
  $newline = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
  $changes = New-Object 'System.Collections.Generic.List[object]'
  $rootLines = New-Object 'System.Collections.Generic.List[string]'
  $values = @{
    'model_catalog_json'= (ConvertTo-Json -InputObject $CatalogPath -Compress)
    'desktop.enabled-reasoning-efforts'= (ConvertTo-Json -InputObject @($Efforts) -Compress)
  }
  foreach ($key in @('model_catalog_json','desktop.enabled-reasoning-efforts')) {
    if ($Info.Edits.ContainsKey($key)) { $changes.Add(@{Start=$Info.Edits[$key].Start; End=$Info.Edits[$key].End; Value=$values[$key]}); continue }
    if ($key -ceq 'model_catalog_json') { $rootLines.Add('model_catalog_json = ' + $values[$key]); continue }
    $line = 'enabled-reasoning-efforts = ' + $values[$key] + $newline
    if ($null -ne $Info.Desktop) {
      $prefix = if ($Text[$Info.Desktop.End-1] -ceq "`n") { '' } else { $newline }
      $changes.Add(@{Start=$Info.Desktop.End; End=$Info.Desktop.End; Value=$prefix+$line})
    } elseif ($Info.DesktopDotted) { $rootLines.Add('desktop.'+$line.Trim()) }
    else {
      $prefix = if ($Text -and -not $Text.EndsWith("`n")) { $newline } else { '' }
      $changes.Add(@{Start=$Text.Length; End=$Text.Length; Value=$prefix+$newline+'[desktop]'+$newline+$line})
    }
  }
  if ($rootLines.Count) {
    $at = $Info.FirstHeader
    $prefix = if ($at -and $Text[$at-1] -cne "`n") { $newline } else { '' }
    $changes.Add(@{Start=$at; End=$at; Value=$prefix+($rootLines -join $newline)+$newline})
  }
  for ($index=0; $index -lt $changes.Count; $index++) { $changes[$index].Order=$index }
  foreach ($change in ($changes | Sort-Object @{Expression='Start';Descending=$true},@{Expression='End';Descending=$true},@{Expression='Order';Descending=$false})) {
    $Text = $Text.Substring(0,$change.Start) + $change.Value + $Text.Substring($change.End)
  }
  $null = Get-ConfigInfo $Text
  return $Text
}

function Test-ModelCatalog($Catalog) {
  if ($null -eq $Catalog -or $Catalog.models -isnot [Array] -or -not $Catalog.models.Count) { throw '模型目录必须包含非空 models 数组。' }
  $seen = New-OrdinalMap
  foreach ($model in $Catalog.models) {
    if ($null -eq $model -or $model.slug -isnot [string] -or -not $model.slug -or $seen.ContainsKey($model.slug)) { throw '模型目录中有空 ID 或重复 ID。' }
    $seen[$model.slug]=$true
    if ($model.display_name -isnot [string] -or $model.supported_reasoning_levels -isnot [Array] -or -not $model.shell_type -or -not $model.visibility -or $model.supported_in_api -isnot [bool] -or $null -eq $model.priority -or $model.support_verbosity -isnot [bool] -or $null -eq $model.truncation_policy -or $model.experimental_supported_tools -isnot [Array]) { throw '模型目录缺少 Codex 必需元数据。' }
    if ($model.model_messages.instructions_template -isnot [string] -and $model.base_instructions -isnot [string]) { throw '模型目录缺少模型指令。' }
  }
}

function Merge-ModelCatalog($Existing, $App, $Domestic, $Managed, $Info) {
  Test-ModelCatalog $App; Test-ModelCatalog $Domestic
  if ($null -ne $Existing) { Test-ModelCatalog $Existing }
  if ($Managed -isnot [Array]) { throw '已管理模型记录格式无效。' }
  foreach ($id in $Managed) {
    if ($id -isnot [string] -or -not $id) { throw '已管理模型记录格式无效。' }
    if ($id -match '^gpt-') { throw '管理记录包含 GPT，停止导入以保留 GPT。' }
  }
  $byId=New-OrdinalMap; $owned=New-OrdinalMap; $order=New-Object 'System.Collections.Generic.List[string]'
  foreach ($id in (@($Managed) + @($Domestic.models | ForEach-Object {$_.slug}))) { $owned[$id]=$true }
  $initial = @(); if ($null -ne $Existing) { $initial=@($Existing.models) }
  foreach ($model in (@($initial) + @($App.models))) {
    if (-not $byId.ContainsKey($model.slug) -and -not $owned.ContainsKey($model.slug)) { $byId[$model.slug]=$model; $order.Add($model.slug) }
  }
  foreach ($model in $Domestic.models) { $byId[$model.slug]=$model; $order.Add($model.slug) }
  $source = if ($null -ne $Existing) { $Existing } else { $App }
  $result = ConvertFrom-Json -InputObject (ConvertTo-Json -InputObject $source -Depth 100)
  $result.models = @($order | ForEach-Object {$byId[$_]})
  if (-not @($result.models | Where-Object {$_.slug -match '^gpt-'}).Count) { throw '未取得 GPT 完整目录，停止导入。' }
  foreach ($key in @('model','review_model')) {
    if ($Info.Values.ContainsKey($key) -and -not $byId.ContainsKey((Get-TomlString $Info.Values[$key]))) { throw '原默认模型或复核模型不在完整目录中，停止导入。' }
  }
  $levels = New-OrdinalMap
  $efforts = @()
  if ($Info.Values.ContainsKey('desktop.enabled-reasoning-efforts')) { $efforts = Get-TomlStringArray $Info.Values['desktop.enabled-reasoning-efforts'] }
  else { $efforts=@($result.models | Where-Object {$_.slug -match '^gpt-'} | ForEach-Object {$_.supported_reasoning_levels} | ForEach-Object {$_.effort}) }
  $efforts += @($Domestic.models | ForEach-Object {$_.supported_reasoning_levels} | ForEach-Object {$_.effort})
  $effortOrder = @('none','minimal','low','medium','high','xhigh','ultra','max')
  foreach ($level in $efforts) {
    if ($effortOrder -cnotcontains $level) { throw '桌面档位存在未知值，停止导入。' }
    $levels[$level]=$true
  }
  Test-ModelCatalog $result
  return @{Catalog=$result; Efforts=@($effortOrder | Where-Object {$levels.ContainsKey($_)}); Managed=@($Domestic.models | ForEach-Object {$_.slug})}
}

function Invoke-ModelImport([string]$TargetHome, [string]$Backend, $Domestic) {
  $configPath = Join-Path $TargetHome 'config.toml'
  $catalogPath = Join-Path $TargetHome 'usegoodai-models.json'
  $managedPath = Join-Path $TargetHome 'usegoodai-models.managed.json'
  if (-not (Test-PrivatePath $TargetHome)) { $null=[IO.Directory]::CreateDirectory($TargetHome) }
  $original = if (Test-PrivatePath $configPath) { Read-PrivateText $configPath } else { $null }
  $info = Get-ConfigInfo ([string]$original); $existing=$null; $managed=@()
  if ($info.Values.ContainsKey('model_catalog_json')) {
    $source = Get-TomlString $info.Values['model_catalog_json']
    if ($source.StartsWith('~/') -or $source.StartsWith('~\')) { $source=Join-Path $HOME $source.Substring(2) }
    if (-not [IO.Path]::IsPathRooted($source)) { $source=Join-Path $TargetHome $source }
    if (Test-PrivatePath $source) { $existing=ConvertFrom-Json -InputObject (Read-PrivateText $source) }
  }
  if (Test-PrivatePath $managedPath) {
    $rawManaged=Read-PrivateText $managedPath
    if (-not $rawManaged.TrimStart().StartsWith('[')) { throw '已管理模型记录格式无效。' }
    $managed=@(ConvertFrom-Json -InputObject $rawManaged)
  }
  $app = ConvertFrom-Json -InputObject (Invoke-CodexExport $Backend @('debug','models','--bundled') $TargetHome)
  if ($null -eq $existing) {
    try { $candidate=ConvertFrom-Json -InputObject (Invoke-CodexExport $Backend @('debug','models') $TargetHome); Test-ModelCatalog $candidate; $existing=$candidate } catch { }
  }
  $merged = Merge-ModelCatalog $existing $app $Domestic $managed $info
  $config = Set-ModelConfig ([string]$original) $info $catalogPath $merged.Efforts
  $files = @(
    @{Path=$catalogPath; Text=(ConvertTo-Json -InputObject $merged.Catalog -Depth 100)+"`n"},
    @{Path=$managedPath; Text=(ConvertTo-Json -InputObject @($merged.Managed) -Depth 100)+"`n"},
    @{Path=$configPath; Text=$config}
  )
  Write-ModelTransaction $files $Backend $TargetHome $original
  return $merged.Managed.Count
}

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

try { Start-ModelInstaller $CodexHomePath $CodexPath }
catch {
  $message = $_.Exception.Message
  if ($message -cnotmatch '^[\u3400-\u9fff]') { $message = '文件格式或系统操作失败。' }
  Write-Host ('导入失败：' + $message + ' 软件未关闭。') -ForegroundColor Red
  throw '国产模型导入未完成。'
}
