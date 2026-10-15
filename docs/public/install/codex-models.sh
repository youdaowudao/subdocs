#!/usr/bin/env bash
set -euo pipefail

say() { printf '%s\n' "$*"; }

list_running_clients() {
  ps -axo pid=,ppid=,uid=,stat=,comm= 2>/dev/null | awk -v uid="$(id -u)" -v self="$$" '
    {
      parent[$1] = $2
      if ($3 != uid || $4 ~ /^Z/) {
        next
      }
      name = $0
      sub(/^[ \t]*[0-9]+[ \t]+[0-9]+[ \t]+[0-9]+[ \t]+[^ \t]+[ \t]+/, "", name)
      sub(/^.*\//, "", name)
      lower = tolower(name)
      if (lower == "codex" || lower == "codex.exe") {
        client[$1] = "codex"
      } else if (lower == "chatgpt" || lower == "chatgpt.exe") {
        client[$1] = "chatgpt"
      }
    }
    END {
      for (pid = self; (pid in parent) && !(pid in own); pid = parent[pid]) {
        own[pid] = 1
      }
      for (pid in client) {
        print pid, client[pid], ((pid in own) ? "skip" : "stop")
      }
    }
  '
}

client_is_alive() {
  local state
  state="$(ps -o stat= -p "$1" 2>/dev/null | tr -d '[:space:]')" || true
  [ -n "$state" ] && [ "${state#Z}" = "$state" ]
}

wait_for_clients_exit() {
  local attempts="$1"
  local pid alive
  while true; do
    alive=""
    for pid in $pending_pids; do
      if client_is_alive "$pid"; then
        alive="$alive $pid"
      fi
    done
    pending_pids="$alive"
    if [ -z "$pending_pids" ]; then
      return 0
    fi
    if [ "$attempts" -le 0 ]; then
      return 1
    fi
    sleep 0.5
    attempts=$((attempts - 1))
  done
}

stop_running_clients() {
  local pid kind action
  local pending_pids=""
  chatgpt_running=false
  codex_running=false
  clients_left=false

  while read -r pid kind action; do
    case "$kind" in
      chatgpt)
        chatgpt_running=true
        ;;
      codex)
        codex_running=true
        ;;
      *)
        continue
        ;;
    esac
    if [ "$action" = "stop" ]; then
      pending_pids="$pending_pids $pid"
    else
      clients_left=true
    fi
  done <<EOF
$(list_running_clients || true)
EOF

  if [ -z "$pending_pids" ]; then
    return
  fi

  kill -TERM $pending_pids 2>/dev/null || true
  if wait_for_clients_exit 10; then
    return
  fi
  kill -KILL $pending_pids 2>/dev/null || true
  if wait_for_clients_exit 4; then
    return
  fi
  clients_left=true
}

report_running_clients() {
  local clients
  if [ "$chatgpt_running" = true ] && [ "$codex_running" = true ]; then
    clients="ChatGPT 软件和 Codex"
  elif [ "$chatgpt_running" = true ]; then
    clients="ChatGPT 软件"
  elif [ "$codex_running" = true ]; then
    clients="Codex"
  else
    say "当前未检测到 ChatGPT/Codex CLI 运行，请启动软件后进行测试。"
    return
  fi

  if [ "$clients_left" = true ]; then
    say "未能自动关闭 ${clients}，请重启电脑后，重新打开并新建对话测试，如有问题请联系网站客服。"
  else
    say "已自动关闭 ${clients}，请重新打开并新建对话测试，如有问题请联系网站客服。"
  fi
}

target_codex_home="${CODEX_HOME:-$HOME/.codex}"
app_backend=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --codex-home|--codex-path)
      [ "$#" -ge 2 ] || { say "参数缺少路径。" >&2; exit 1; }
      if [ "$1" = --codex-home ]; then target_codex_home="$2"; else app_backend="$2"; fi
      shift 2 ;;
    --help)
      say '用法：bash codex-models.sh [--codex-home 配置目录] [--codex-path App自带后端路径]'
      exit 0 ;;
    *) say "未知参数。" >&2; exit 1 ;;
  esac
done
[ "$(uname -s)" = Darwin ] || { say "这个脚本用于 macOS；Windows 请运行 codex-models.ps1。" >&2; exit 1; }
say '成功导入后会自动关闭 ChatGPT/Codex，运行中的任务会中断。'
if [ -z "$app_backend" ]; then
  for app_root in /Applications/Codex.app /Applications/ChatGPT.app "$HOME/Applications/Codex.app" "$HOME/Applications/ChatGPT.app"; do
    if [ -f "$app_root/Contents/Info.plist" ]; then
      bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_root/Contents/Info.plist" 2>/dev/null || true)"
      [ "$bundle_id" = com.openai.codex ] || continue
      for candidate in "$app_root/Contents/Resources/codex" "$app_root/Contents/Resources/bin/codex"; do
        if [ -f "$candidate" ] && [ -x "$candidate" ]; then app_backend="$candidate"; break; fi
      done
    fi
    [ -z "$app_backend" ] || break
  done
fi
[ -n "$app_backend" ] && [ -f "$app_backend" ] && [ -x "$app_backend" ] || {
  say '未找到桌面 App 自带的 Codex 后端；用 --codex-path 指定 Contents/Resources 中的 codex。' >&2
  exit 1
}

if /usr/bin/osascript -l JavaScript - "$target_codex_home" "$app_backend" <<'USEGOODAI_JXA'
var DOMESTIC_CATALOG = {"models":[{"slug":"qwen3.8-max","display_name":"Qwen3.8 Max","description":"千问 Max","context_window":1000000,"input_modalities":["text","image"],"default_reasoning_level":"xhigh","apply_patch_tool_type":null,"supports_parallel_tool_calls":true,"supported_reasoning_levels":[{"effort":"low","description":"轻度推理"},{"effort":"medium","description":"中度推理"},{"effort":"xhigh","description":"深度推理"}],"shell_type":"shell_command","visibility":"list","supported_in_api":true,"priority":100,"availability_nux":null,"upgrade":null,"support_verbosity":false,"default_verbosity":null,"supports_reasoning_summaries":true,"supports_reasoning_summary_parameter":false,"default_reasoning_summary":"none","prefer_websockets":false,"web_search_tool_type":"text","supports_search_tool":false,"truncation_policy":{"mode":"tokens","limit":10000},"supports_image_detail_original":false,"max_context_window":1000000,"auto_compact_token_limit":null,"effective_context_window_percent":95,"experimental_supported_tools":[],"base_instructions":"You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence.","model_messages":{"instructions_template":"You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence."},"use_responses_lite":false},{"slug":"qwen3.8-flash","display_name":"Qwen3.8 Flash","description":"千问 Flash","context_window":1000000,"input_modalities":["text","image"],"default_reasoning_level":"xhigh","apply_patch_tool_type":null,"supports_parallel_tool_calls":true,"supported_reasoning_levels":[{"effort":"low","description":"轻度推理"},{"effort":"medium","description":"中度推理"},{"effort":"xhigh","description":"深度推理"}],"shell_type":"shell_command","visibility":"list","supported_in_api":true,"priority":101,"availability_nux":null,"upgrade":null,"support_verbosity":false,"default_verbosity":null,"supports_reasoning_summaries":true,"supports_reasoning_summary_parameter":false,"default_reasoning_summary":"none","prefer_websockets":false,"web_search_tool_type":"text","supports_search_tool":false,"truncation_policy":{"mode":"tokens","limit":10000},"supports_image_detail_original":false,"max_context_window":1000000,"auto_compact_token_limit":null,"effective_context_window_percent":95,"experimental_supported_tools":[],"base_instructions":"You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence.","model_messages":{"instructions_template":"You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence."},"use_responses_lite":false},{"slug":"glm-5.3-flash","display_name":"GLM-5.3 Flash","description":"智谱多模态 Flash","context_window":1000000,"input_modalities":["text","image"],"default_reasoning_level":"max","apply_patch_tool_type":null,"supports_parallel_tool_calls":false,"supported_reasoning_levels":[{"effort":"low","description":"轻度推理"},{"effort":"high","description":"增强推理"},{"effort":"max","description":"最大推理"}],"shell_type":"shell_command","visibility":"list","supported_in_api":true,"priority":102,"availability_nux":null,"upgrade":null,"support_verbosity":false,"default_verbosity":null,"supports_reasoning_summaries":true,"supports_reasoning_summary_parameter":false,"default_reasoning_summary":"none","prefer_websockets":false,"web_search_tool_type":"text","supports_search_tool":false,"truncation_policy":{"mode":"tokens","limit":10000},"supports_image_detail_original":false,"max_context_window":1000000,"auto_compact_token_limit":null,"effective_context_window_percent":95,"experimental_supported_tools":[],"base_instructions":"You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence.","model_messages":{"instructions_template":"You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence."},"use_responses_lite":false},{"slug":"deepseek-flash","display_name":"DeepSeek V4.1 Flash","description":"DeepSeek Flash","context_window":1048576,"input_modalities":["text","image"],"default_reasoning_level":"high","apply_patch_tool_type":"freeform","supports_parallel_tool_calls":true,"supported_reasoning_levels":[{"effort":"low","description":"轻度推理"},{"effort":"high","description":"增强推理"},{"effort":"max","description":"最大推理"}],"shell_type":"shell_command","visibility":"list","supported_in_api":true,"priority":103,"availability_nux":null,"upgrade":null,"support_verbosity":true,"default_verbosity":"low","supports_reasoning_summaries":true,"supports_reasoning_summary_parameter":false,"default_reasoning_summary":"none","prefer_websockets":false,"web_search_tool_type":"text","supports_search_tool":false,"truncation_policy":{"mode":"tokens","limit":10000},"supports_image_detail_original":true,"max_context_window":1048576,"auto_compact_token_limit":null,"effective_context_window_percent":95,"experimental_supported_tools":[],"base_instructions":"You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence.","model_messages":{"instructions_template":"You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence."},"use_responses_lite":false},{"slug":"glm-5.3","display_name":"GLM-5.3","description":"智谱文本模型","context_window":1000000,"input_modalities":["text"],"default_reasoning_level":"max","apply_patch_tool_type":null,"supports_parallel_tool_calls":false,"supported_reasoning_levels":[{"effort":"low","description":"轻度推理"},{"effort":"high","description":"增强推理"},{"effort":"max","description":"最大推理"}],"shell_type":"shell_command","visibility":"list","supported_in_api":true,"priority":104,"availability_nux":null,"upgrade":null,"support_verbosity":false,"default_verbosity":null,"supports_reasoning_summaries":true,"supports_reasoning_summary_parameter":false,"default_reasoning_summary":"none","prefer_websockets":false,"web_search_tool_type":"text","supports_search_tool":false,"truncation_policy":{"mode":"tokens","limit":10000},"supports_image_detail_original":false,"max_context_window":1000000,"auto_compact_token_limit":null,"effective_context_window_percent":95,"experimental_supported_tools":[],"base_instructions":"You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence.","model_messages":{"instructions_template":"You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence."},"use_responses_lite":false},{"slug":"kimi-k3","display_name":"Kimi K3","description":"月之暗面多模态模型","context_window":1000000,"input_modalities":["text","image"],"default_reasoning_level":"max","apply_patch_tool_type":null,"supports_parallel_tool_calls":false,"supported_reasoning_levels":[{"effort":"low","description":"轻度推理"},{"effort":"high","description":"增强推理"},{"effort":"max","description":"最大推理"}],"shell_type":"shell_command","visibility":"list","supported_in_api":true,"priority":105,"availability_nux":null,"upgrade":null,"support_verbosity":false,"default_verbosity":null,"supports_reasoning_summaries":true,"supports_reasoning_summary_parameter":false,"default_reasoning_summary":"none","prefer_websockets":false,"web_search_tool_type":"text","supports_search_tool":false,"truncation_policy":{"mode":"tokens","limit":10000},"supports_image_detail_original":false,"max_context_window":1000000,"auto_compact_token_limit":null,"effective_context_window_percent":95,"experimental_supported_tools":[],"base_instructions":"You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence.","model_messages":{"instructions_template":"You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence."},"use_responses_lite":false},{"slug":"minimax-m3","display_name":"MiniMax M3","description":"MiniMax 多模态模型","context_window":1000000,"input_modalities":["text","image"],"default_reasoning_level":null,"apply_patch_tool_type":null,"supports_parallel_tool_calls":false,"supported_reasoning_levels":[],"shell_type":"shell_command","visibility":"list","supported_in_api":true,"priority":106,"availability_nux":null,"upgrade":null,"support_verbosity":false,"default_verbosity":null,"supports_reasoning_summaries":false,"supports_reasoning_summary_parameter":false,"default_reasoning_summary":"none","prefer_websockets":false,"web_search_tool_type":"text","supports_search_tool":false,"truncation_policy":{"mode":"tokens","limit":10000},"supports_image_detail_original":false,"max_context_window":1000000,"auto_compact_token_limit":null,"effective_context_window_percent":95,"experimental_supported_tools":[],"base_instructions":"You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence.","model_messages":{"instructions_template":"You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence."},"use_responses_lite":false},{"slug":"hy4-preview","display_name":"Hy4 preview","description":"腾讯混元","context_window":1000000,"input_modalities":["text"],"default_reasoning_level":"high","apply_patch_tool_type":null,"supports_parallel_tool_calls":false,"supported_reasoning_levels":[{"effort":"none","description":"关闭推理"},{"effort":"high","description":"增强推理"}],"shell_type":"shell_command","visibility":"list","supported_in_api":true,"priority":107,"availability_nux":null,"upgrade":null,"support_verbosity":false,"default_verbosity":null,"supports_reasoning_summaries":true,"supports_reasoning_summary_parameter":false,"default_reasoning_summary":"none","prefer_websockets":false,"web_search_tool_type":"text","supports_search_tool":false,"truncation_policy":{"mode":"tokens","limit":10000},"supports_image_detail_original":false,"max_context_window":1000000,"auto_compact_token_limit":null,"effective_context_window_percent":95,"experimental_supported_tools":[],"base_instructions":"You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence.","model_messages":{"instructions_template":"You are a coding assistant running in Codex. Follow the user's instructions and the repository's AGENTS.md. Inspect relevant files before editing, use the available tools to complete the task, preserve unrelated changes, and verify changes with appropriate checks. Give concise, accurate progress updates and a final report. Do not claim to have run checks or completed actions without evidence."},"use_responses_lite":false}]};
/* Pure ES5: used by macOS JXA and the isolated test runner. */
var DomesticModels = (function () {
    'use strict';
    var effortOrder = ['none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'ultra', 'max'];
    function fail(message) { throw new Error(message); }
    function own(obj, key) { return Object.prototype.hasOwnProperty.call(obj, key); }
    function dict() { return Object.create(null); }
    function canonical(value) {
        if (Array.isArray(value)) { return value.map(canonical); }
        if (value && typeof value === 'object') {
            var result = dict(); Object.keys(value).sort().forEach(function (key) { result[key] = canonical(value[key]); }); return result;
        }
        return value;
    }
    function stringValue(raw) {
        raw = raw.trim();
        if (/^'[^'\r\n]*'$/.test(raw)) { return raw.slice(1, -1); }
        if (/^"(?:[^"\\\r\n]|\\.)*"$/.test(raw)) {
            try {
                return JSON.parse(raw.replace(/\\(?:U[0-9a-fA-F]{8}|e|[\s\S])/g, function (token) {
                    if (token === '\\e') { return '\\u001b'; }
                    if (token.charAt(1) !== 'U' || token.length !== 10) { return token; }
                    var n = parseInt(token.slice(2), 16);
                    if (n > 0x10ffff || (n >= 0xd800 && n <= 0xdfff)) { fail('TOML 路径转义无效。'); }
                    var value = n <= 0xffff ? String.fromCharCode(n) : String.fromCharCode(0xd800 + ((n - 0x10000) >> 10), 0xdc00 + ((n - 0x10000) & 1023));
                    return JSON.stringify(value).slice(1, -1);
                }));
            } catch (e) { fail('TOML 字符串格式无效。'); }
        }
        fail('模型目录、默认模型等目标字段须使用单行 TOML 字符串。');
    }
    function keyParts(raw) {
        var parts = [], pos = 0, m, re = /\s*("(?:[^"\\]|\\.)*"|'[^']*'|[A-Za-z0-9_-]+)\s*/g;
        while (pos < raw.length) {
            re.lastIndex = pos; m = re.exec(raw);
            if (!m || m.index !== pos) { fail('无法识别 TOML 字段或配置段。'); }
            parts.push(/^["']/.test(m[1]) ? stringValue(m[1]) : m[1]);
            pos = re.lastIndex;
            if (pos === raw.length) { break; }
            if (raw.charAt(pos++) !== '.') { fail('TOML 字段路径无效。'); }
        }
        if (!parts.length) { fail('空 TOML 字段。'); }
        return parts;
    }
    function statements(text) {
        var records = [], start = 0, depth = [], quote = '', triple = false, escaped = false, comment = false, clean = '', i, ch, run;
        for (i = 0; i < text.length; i++) {
            ch = text.charAt(i);
            if (comment) {
                if (ch !== '\n') { clean += ' '; continue; }
                comment = false;
            }
            if (quote) {
                clean += ch;
                if (escaped) { escaped = false; continue; }
                if (quote === '"' && ch === '\\') { escaped = true; continue; }
                if (ch === quote) {
                    if (!triple) { quote = ''; }
                    else if (text.substr(i, 3) === quote + quote + quote) {
                        run = 3;
                        while (run < 5 && text.charAt(i + run) === quote) { run++; }
                        clean += text.substr(i + 1, run - 1); i += run - 1; quote = ''; triple = false;
                    }
                } else if (ch === '\n' && !triple) { fail('TOML 字符串未闭合。'); }
                continue;
            }
            if (ch === '#') { comment = true; clean += ' '; continue; }
            if (ch === '"' || ch === "'") {
                quote = ch; triple = text.substr(i, 3) === ch + ch + ch;
                clean += ch;
                if (triple) { clean += ch + ch; i += 2; }
                continue;
            }
            if (ch === '[' || ch === '{') { depth.push(ch); }
            if (ch === ']' || ch === '}') {
                if (depth.pop() !== (ch === ']' ? '[' : '{')) { fail('TOML 括号不匹配。'); }
            }
            clean += ch;
            if (ch === '\n' && !depth.length) { records.push({start: start, end: i + 1, code: clean}); start = i + 1; clean = ''; }
        }
        if (quote || depth.length) { fail('TOML 字符串或括号未闭合。'); }
        if (start < text.length) { records.push({start: start, end: text.length, code: clean}); }
        return records;
    }
    function configInfo(text) {
        var result = {values: dict(), edits: dict(), firstHeader: text.length, desktop: null, desktopInline: false, desktopDotted: false}, scope = [], records = statements(text);
        records.forEach(function (rec) {
            var code = rec.code.trim(), header, eq, parts, path, key, vstart, vend;
            if (!code) { return; }
            if (code.charAt(0) === '[') {
                header = /^(\[\[?)([\s\S]*?)(\]\]?)$/.exec(code);
                if (!header || header[1].length !== header[3].length) { fail('TOML 配置段无效。'); }
                scope = keyParts(header[2].trim());
                result.firstHeader = Math.min(result.firstHeader, rec.start);
                if (scope.join('.') === 'desktop' && scope.length === 1) {
                    if (header[1] === '[[' || result.desktop) { fail('desktop 配置段重复或格式无效。'); }
                    result.desktop = rec;
                }
                return;
            }
            /* '=' inside a quoted key is allowed. */
            var q = '', esc = false;
            for (eq = 0; eq < rec.code.length; eq++) {
                var c = rec.code.charAt(eq);
                if (q) { if (esc) { esc = false; } else if (c === '\\' && q === '"') { esc = true; } else if (c === q) { q = ''; } }
                else if (c === '"' || c === "'") { q = c; }
                else if (c === '=') { break; }
            }
            if (eq === rec.code.length) { fail('TOML 配置行无效。'); }
            parts = keyParts(rec.code.slice(0, eq).trim()); path = scope.concat(parts); key = path.join('.');
            if (!scope.length && parts[0] === 'desktop') {
                result.desktopInline = parts.length === 1;
                result.desktopDotted = parts.length > 1 || result.desktopDotted;
            }
            if (path.length > 1 && path[0] === 'profiles' && path[path.length - 1] === 'model_catalog_json') { fail('profile 中另有 model_catalog_json；请先统一目录配置再导入。'); }
            if ((path.length === 1 && ['model_catalog_json', 'model', 'review_model', 'profile', 'model_provider'].indexOf(key) >= 0) || (path.length === 2 && key === 'desktop.enabled-reasoning-efforts')) {
                if (own(result.edits, key)) { fail('目标 TOML 字段重复。'); }
                vstart = eq + 1;
                while (/\s/.test(rec.code.charAt(vstart)) && vstart < rec.code.length) { vstart++; }
                vend = rec.code.replace(/\s+$/, '').length;
                result.edits[key] = {start: rec.start + vstart, end: rec.start + vend};
                result.values[key] = rec.code.slice(vstart, vend);
            }
        });
        if (result.desktopInline) { fail('desktop 使用内联表；请改为 [desktop] 配置段后导入。'); }
        return result;
    }
    function stringArray(raw) {
        var body = raw.trim(), result = [], parts;
        if (body.charAt(0) !== '[' || body.slice(-1) !== ']') { fail('桌面推理档位必须是字符串数组。'); }
        body = body.slice(1, -1);
        parts = statements('x=[' + body + ']')[0]; // check balanced quotes before splitting
        var re = /\s*("(?:[^"\\]|\\.)*"|'[^']*')\s*(,|$)/g, pos = 0, m;
        while (pos < body.length && body.slice(pos).trim()) {
            re.lastIndex = pos; m = re.exec(body);
            if (!m || m.index !== pos) { fail('桌面推理档位必须是字符串数组。'); }
            result.push(stringValue(m[1])); pos = re.lastIndex;
        }
        return result;
    }
    function patchConfig(text, info, catalogPath, efforts) {
        var newline = text.indexOf('\r\n') >= 0 ? '\r\n' : '\n', changes = [], rootLines = [];
        function set(key, value) {
            if (own(info.edits, key)) { changes.push({start: info.edits[key].start, end: info.edits[key].end, value: value}); return true; }
            return false;
        }
        if (!set('model_catalog_json', JSON.stringify(catalogPath))) { rootLines.push('model_catalog_json = ' + JSON.stringify(catalogPath)); }
        if (!set('desktop.enabled-reasoning-efforts', JSON.stringify(efforts))) {
            var line = 'enabled-reasoning-efforts = ' + JSON.stringify(efforts) + newline;
            if (info.desktop) { changes.push({start: info.desktop.end, end: info.desktop.end, value: (text.charAt(info.desktop.end - 1) === '\n' ? '' : newline) + line}); }
            else if (info.desktopDotted) { rootLines.push('desktop.' + line.trim()); }
            else { changes.push({start: text.length, end: text.length, value: (text && text.slice(-1) !== '\n' ? newline : '') + newline + '[desktop]' + newline + line}); }
        }
        if (rootLines.length) {
            var at = info.firstHeader;
            changes.push({start: at, end: at, value: (at && text.charAt(at - 1) !== '\n' ? newline : '') + rootLines.join(newline) + newline});
        }
        changes.forEach(function (change, index) { change.order = index; });
        changes.sort(function (a, b) { return b.start - a.start || b.end - a.end || a.order - b.order; });
        changes.forEach(function (change) { text = text.slice(0, change.start) + change.value + text.slice(change.end); });
        configInfo(text);
        return text;
    }
    function validateCatalog(catalog) {
        if (!catalog || !Array.isArray(catalog.models) || !catalog.models.length) { fail('模型目录必须包含非空 models 数组。'); }
        var seen = dict();
        catalog.models.forEach(function (model) {
            if (!model || typeof model.slug !== 'string' || !model.slug || own(seen, model.slug)) { fail('模型目录中有空 ID 或重复 ID。'); }
            seen[model.slug] = true;
            if (typeof model.display_name !== 'string' || !Array.isArray(model.supported_reasoning_levels) || !model.shell_type || !model.visibility || typeof model.supported_in_api !== 'boolean' || typeof model.priority !== 'number' || typeof model.support_verbosity !== 'boolean' || !model.truncation_policy || !Array.isArray(model.experimental_supported_tools)) { fail('模型目录缺少 Codex 必需元数据。'); }
            if (!(model.model_messages && typeof model.model_messages.instructions_template === 'string') && typeof model.base_instructions !== 'string') { fail('模型目录缺少模型指令。'); }
        });
        return catalog;
    }
    function merge(existing, app, domestic, managed, info) {
        validateCatalog(app); validateCatalog(domestic);
        if (existing) { validateCatalog(existing); }
        if (!Array.isArray(managed) || managed.some(function (x) { return typeof x !== 'string' || !x; })) { fail('已管理模型记录格式无效。'); }
        if (managed.some(function (x) { return /^gpt-/i.test(x); })) { fail('管理记录包含 GPT，停止导入以保留 GPT。'); }
        var byId = dict(), order = [], owned = dict(), result, levels = [], gotGPT = false;
        managed.concat(domestic.models.map(function (x) { return x.slug; })).forEach(function (id) { owned[id] = true; });
        function add(models) { models.forEach(function (model) { if (!own(byId, model.slug) && !own(owned, model.slug)) { byId[model.slug] = model; order.push(model.slug); } }); }
        add(existing ? existing.models : []); add(app.models);
        domestic.models.forEach(function (model) { byId[model.slug] = model; order.push(model.slug); });
        result = JSON.parse(JSON.stringify(existing || app)); result.models = order.map(function (id) { return byId[id]; });
        result.models.forEach(function (model) { if (/^gpt-/i.test(model.slug)) { gotGPT = true; } });
        if (!gotGPT) { fail('未取得 GPT 完整目录，停止导入。'); }
        ['model', 'review_model'].forEach(function (key) {
            if (own(info.values, key) && !own(byId, stringValue(info.values[key]))) { fail('原默认模型或复核模型不在完整目录中，停止导入。'); }
        });
        if (own(info.values, 'desktop.enabled-reasoning-efforts')) { levels = stringArray(info.values['desktop.enabled-reasoning-efforts']); }
        else { result.models.forEach(function (m) { if (/^gpt-/i.test(m.slug)) { m.supported_reasoning_levels.forEach(function (r) { levels.push(r.effort); }); } }); }
        domestic.models.forEach(function (m) { m.supported_reasoning_levels.forEach(function (r) { levels.push(r.effort); }); });
        var unique = dict(); levels.forEach(function (level) { if (effortOrder.indexOf(level) < 0) { fail('桌面档位存在未知值，停止导入。'); } unique[level] = true; });
        return {catalog: validateCatalog(result), efforts: effortOrder.filter(function (level) { return own(unique, level); }), managed: domestic.models.map(function (m) { return m.slug; })};
    }
    function transaction(io, files, backend, home, original) {
        var stamp = io.stamp(), stage = io.join(home, '.usegoodai-models-' + stamp), snapshots = [], committed = [];
        files.forEach(function (file) {
            if (io.exists(file.path) && !io.isFile(file.path)) { fail('目标文件不是普通文件，停止导入。'); }
            snapshots.push(io.exists(file.path) ? io.read(file.path) : null);
        });
        if (snapshots[2] !== original) { fail('配置在导入过程中被修改，请重新运行。'); }
        io.mkdir(stage);
        try {
            files.forEach(function (file, index) { io.write(io.join(stage, 'file-' + index), file.text); });
            var stagedCatalog = io.join(stage, 'file-0'), info = configInfo(files[2].text);
            var levels = stringArray(info.values['desktop.enabled-reasoning-efforts']);
            io.write(io.join(stage, 'config.toml'), 'model_catalog_json = ' + JSON.stringify(stagedCatalog) + '\n[desktop]\nenabled-reasoning-efforts = ' + JSON.stringify(levels) + '\n');
            var expected = JSON.stringify(parseJSON(files[0].text).models.map(function (m) { return m.slug; }).sort());
            function verifyAt(target) {
                var validated = validateCatalog(parseJSON(io.exportAt(backend, ['debug', 'models'], target)));
                if (JSON.stringify(validated.models.map(function (m) { return m.slug; }).sort()) !== expected) { fail('App 未读取新模型目录，停止导入。'); }
                return JSON.stringify(canonical(validated.models));
            }
            var normalized = verifyAt(stage);
            files.forEach(function (file, index) {
                var now = io.exists(file.path) ? io.read(file.path) : null;
                if (now !== snapshots[index]) { fail('配置在导入过程中被修改，请重新运行。'); }
            });
            files.forEach(function (file, index) { if (snapshots[index] !== null) { io.backup(file.path, file.path + '.bak.' + stamp); } });
            files.forEach(function (file, index) { committed.push(index); io.write(file.path, file.text); });
            /* Use the original home so relative paths and active profile precedence remain real. */
            if (verifyAt(home) !== normalized) { fail('App 生效的模型元数据与本次导入不一致，停止导入。'); }
        } catch (error) {
            var restoreFailed = false;
            committed.reverse().forEach(function (index) { try { if (snapshots[index] === null) { io.remove(files[index].path); } else { io.write(files[index].path, snapshots[index]); } } catch (ignored) { restoreFailed = true; } });
            if (restoreFailed) { fail('写入失败且恢复未完成，请使用同目录的 .bak 备份恢复；软件未关闭。'); }
            throw error;
        } finally {
            try { io.remove(stage); } catch (ignored) { /* A leftover private stage does not invalidate a successful import. */ }
        }
    }
    function parseJSON(text) { return JSON.parse(text.replace(/^\uFEFF/, '')); }
    function importModels(io, home, executable, domestic) {
        var configPath = io.join(home, 'config.toml'), catalogPath = io.join(home, 'usegoodai-models.json'), managedPath = io.join(home, 'usegoodai-models.managed.json');
        if (!io.exists(configPath)) { fail('没有找到 config.toml；请先运行原 GPT 接入脚本。'); }
        var original = io.read(configPath), info = configInfo(original), existing = null, source, managed = [];
        if (own(info.values, 'model_catalog_json')) {
            source = io.resolve(home, stringValue(info.values.model_catalog_json));
            if (io.exists(source)) { existing = parseJSON(io.read(source)); }
        }
        if (io.exists(managedPath)) { managed = parseJSON(io.read(managedPath)); }
        var app = parseJSON(io.exportCatalog(executable, true));
        if (!existing) {
            try { existing = validateCatalog(parseJSON(io.exportCatalog(executable, false))); }
            catch (ignored) { /* Missing custom file or unavailable refresh: bundled catalog remains complete. */ }
        }
        var merged = merge(existing, app, domestic, managed, info);
        var config = patchConfig(original, info, catalogPath, merged.efforts);
        var files = [{path: catalogPath, text: JSON.stringify(merged.catalog, null, 2) + '\n'}, {path: managedPath, text: JSON.stringify(merged.managed, null, 2) + '\n'}, {path: configPath, text: config}];
        /* Host stages all files, validates with the selected App backend, then commits with rollback. */
        io.transaction(files, executable, catalogPath, original);
        return merged.managed.length;
    }
    return {statements: statements, configInfo: configInfo, stringValue: stringValue, stringArray: stringArray, patchConfig: patchConfig, validateCatalog: validateCatalog, merge: merge, transaction: transaction, importModels: importModels};
}());
if (typeof module !== 'undefined') { module.exports = DomesticModels; }

/* macOS built-in JavaScript for Automation; no Node installation required. */
ObjC.import('Foundation');
function run(argv) {
    'use strict';
    var fm = $.NSFileManager.defaultManager, utf8 = $.NSUTF8StringEncoding;
    function nativeError(message) { throw new Error(message); }
    function attrs(path) { var error = Ref(); return fm.attributesOfItemAtPathError($(path), error); }
    function exists(path) { return !attrs(path).isNil(); }
    function isFile(path) { var value = attrs(path); return !value.isNil() && ObjC.unwrap(value.objectForKey($.NSFileType)) === ObjC.unwrap($.NSFileTypeRegular); }
    function read(path) {
        if (!isFile(path)) { nativeError('文件不存在或不是普通文件。'); }
        var error = Ref(), value = $.NSString.stringWithContentsOfFileEncodingError($(path), utf8, error);
        if (value.isNil()) { nativeError('无法按 UTF-8 读取文件。'); }
        return ObjC.unwrap(value);
    }
    function permissions(path) {
        var error = Ref();
        if (!fm.setAttributesOfItemAtPathError($.NSDictionary.dictionaryWithObjectForKey($(384), $.NSFilePosixPermissions), $(path), error)) { nativeError('无法设置文件权限。'); }
    }
    function write(path, text) {
        var error = Ref();
        if (!$(text).writeToFileAtomicallyEncodingError($(path), true, utf8, error)) { nativeError('无法写入文件。'); }
        permissions(path);
    }
    function remove(path) {
        if (exists(path) && !fm.removeItemAtPathError($(path), Ref())) { nativeError('无法清理暂存文件。'); }
    }
    function execute(executable, args, env) {
        var task = $.NSTask.alloc.init, outputPath = join(env.CODEX_HOME, '.usegoodai-export-' + ObjC.unwrap($.NSUUID.UUID.UUIDString));
        write(outputPath, '');
        var output = $.NSFileHandle.fileHandleForWritingAtPath($(outputPath));
        if (output.isNil()) { nativeError('无法打开校验输出文件。'); }
        task.executableURL = $.NSURL.fileURLWithPath($(executable)); task.arguments = $(args);
        task.standardOutput = output; task.standardError = $.NSFileHandle.fileHandleWithNullDevice;
        task.currentDirectoryURL = $.NSURL.fileURLWithPath($(env.CODEX_HOME));
        var environment = $.NSProcessInfo.processInfo.environment.mutableCopy;
        environment.setObjectForKey($(env.CODEX_HOME), $('CODEX_HOME'));
        task.environment = environment;
        try {
            if (!task.launchAndReturnError(Ref())) { nativeError('无法启动 App 自带的 Codex 后端。'); }
            var deadline = Date.now() + 30000;
            while (task.running && Date.now() < deadline) { $.NSThread.sleepForTimeInterval(0.05); }
            if (task.running) {
                task.terminate;
                $.NSThread.sleepForTimeInterval(0.2);
                if (task.running) {
                    var killer = $.NSTask.alloc.init;
                    killer.executableURL = $.NSURL.fileURLWithPath($('/bin/kill'));
                    killer.arguments = $(['-KILL', String(task.processIdentifier)]);
                    if (!killer.launchAndReturnError(Ref())) { nativeError('无法结束超时的校验后端。'); }
                    killer.waitUntilExit;
                }
                task.waitUntilExit;
                nativeError('App 后端校验超时，原配置未更改。');
            }
            task.waitUntilExit;
            if (task.terminationStatus !== 0) { nativeError('App 后端校验失败，原配置未更改。'); }
            return read(outputPath);
        } finally { output.closeFile; remove(outputPath); }
    }
    var homeValue = $(argv[0]).stringByExpandingTildeInPath.stringByStandardizingPath, executable = argv[1];
    if (!homeValue.isAbsolutePath) { homeValue = fm.currentDirectoryPath.stringByAppendingPathComponent(homeValue).stringByStandardizingPath; }
    var home = ObjC.unwrap(homeValue);
    function resolve(base, path) {
        var value = $(path).stringByExpandingTildeInPath;
        if (!value.isAbsolutePath) { value = $(base).stringByAppendingPathComponent(value); }
        return ObjC.unwrap(value.stringByStandardizingPath);
    }
    function join(a, b) { return ObjC.unwrap($(a).stringByAppendingPathComponent($(b))); }
    var io = {
        join: join, resolve: resolve, read: read, write: write, isFile: isFile, remove: remove,
        exists: exists,
        stamp: function () { return new Date().toISOString().replace(/[^0-9]/g, '') + '.' + ObjC.unwrap($.NSUUID.UUID.UUIDString); },
        mkdir: function (path) {
            if (!fm.createDirectoryAtPathWithIntermediateDirectoriesAttributesError($(path), false, $.NSDictionary.dictionaryWithObjectForKey($(448), $.NSFilePosixPermissions), Ref())) { nativeError('无法创建暂存目录。'); }
        },
        backup: function (from, to) {
            if (!fm.copyItemAtPathToPathError($(from), $(to), Ref())) { nativeError('备份失败，停止导入。'); }
            permissions(to);
        },
        exportAt: function (backend, args, target) { return execute(backend, args, {CODEX_HOME: target}); },
        exportCatalog: function (backend, bundled) { return execute(backend, bundled ? ['debug', 'models', '--bundled'] : ['debug', 'models'], {CODEX_HOME: home}); },
        transaction: function (files, backend, catalogPath, original) {
            DomesticModels.transaction(io, files, backend, home, original);
        }
    };
    try {
        var count = DomesticModels.importModels(io, home, executable, DOMESTIC_CATALOG);
        return '已导入 ' + count + ' 个国产模型，原 GPT 和其他模型已保留。';
    } catch (error) {
        /* Never echo external process stderr, original TOML, or JSON (may contain credentials). */
        throw new Error('导入失败：' + (/^[\u3400-\u9fff]/.test(error.message) ? error.message : '文件格式或系统操作失败，软件未关闭。'));
    }
}

USEGOODAI_JXA
then
  stop_running_clients
  report_running_clients
  say '重新打开 App，新建任务后选择模型；API Key 分组由你在中转站切换。'
else
  say '导入未完成，软件未关闭。' >&2
  exit 1
fi
