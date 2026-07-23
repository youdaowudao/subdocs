#!/usr/bin/env bash
set -euo pipefail

CODEX_BASE_URL="https://api.usegoodai.com"
CODEX_MODEL="gpt-5.6-sol"
CODEX_HOME="$HOME/.codex"
CONFIG_FILE="$CODEX_HOME/config.toml"
AUTH_FILE="$CODEX_HOME/auth.json"

if ! { exec 3</dev/tty; } 2>/dev/null; then
  exec 3<&0
fi

say() {
  printf '%s\n' "$*"
}

read_input() {
  local var_name="$1"
  local prompt="$2"
  read -r -u 3 -p "$prompt" "$var_name"
}

detect_running_clients() {
  ps -axo comm= 2>/dev/null | awk '
    {
      name = $0
      sub(/^.*\//, "", name)
      lower = tolower(name)
      if (lower == "codex" || lower == "codex.exe" || lower == "chatgpt" || lower == "chatgpt.exe") {
        print name
      }
    }
  ' | sort -fu
}

report_running_clients() {
  local running_clients
  running_clients="$(detect_running_clients)"
  if [ -z "$running_clients" ]; then
    return
  fi

  while IFS= read -r process_name; do
    case "$(printf '%s' "$process_name" | tr '[:upper:]' '[:lower:]')" in
      codex|codex.exe)
        say "当前检测到 Codex CLI 正在运行。"
        ;;
      chatgpt|chatgpt.exe)
        say "当前检测到 ChatGPT 正在运行。"
        ;;
    esac
  done <<EOF
$running_clients
EOF
  say "请彻底退出并结束以上进程，然后重新打开。"
}

backup_if_exists() {
  local path="$1"
  local private_backup="${2:-false}"
  if [ -f "$path" ]; then
    local stamp backup suffix
    stamp="$(date +%Y%m%d%H%M%S)"
    backup="$path.bak.$stamp"
    suffix=1
    while [ -e "$backup" ]; do
      backup="$path.bak.$stamp.$suffix"
      suffix=$((suffix + 1))
    done
    cp "$path" "$backup"
    if [ "$private_backup" = "true" ]; then
      chmod 600 "$backup" 2>/dev/null || true
    fi
    say "已备份：$backup"
  fi
}

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

show_write_plan() {
  if [ -f "$CONFIG_FILE" ] || [ -f "$AUTH_FILE" ]; then
    say "检测到已有配置，将先备份再覆盖："
    [ -f "$CONFIG_FILE" ] && say "  - $CONFIG_FILE"
    [ -f "$AUTH_FILE" ] && say "  - $AUTH_FILE"
    return
  fi

  say "未发现旧配置，将创建："
  say "  - $CONFIG_FILE"
  say "  - $AUTH_FILE"
}

read_validated_api_key() {
  local var_name="$1"
  local entered_key
  while true; do
    read_input entered_key "请输入 UseGoodAI API Key: "
    if [ -z "$entered_key" ]; then
      say "API Key 不能为空，请重新输入。"
      continue
    fi
    case "$entered_key" in
      sk-*)
        printf -v "$var_name" '%s' "$entered_key"
        return
        ;;
      *)
        say "API Key 格式错误，必须以 sk- 开头，请重新输入。"
        ;;
    esac
  done
}

write_codex_files() {
  local api_key="$1"
  local escaped_key
  local config_temp=""
  local auth_temp=""

  escaped_key="$(json_escape "$api_key")"
  mkdir -p "$CODEX_HOME"
  umask 077
  config_temp="$(mktemp "$CODEX_HOME/.config.toml.tmp.XXXXXX")"
  auth_temp="$(mktemp "$CODEX_HOME/.auth.json.tmp.XXXXXX")"

  trap 'rm -f "${config_temp:-}" "${auth_temp:-}"' RETURN

  cat > "$config_temp" <<EOF
model_provider = "OpenAI"
model = "$CODEX_MODEL"
review_model = "$CODEX_MODEL"
model_reasoning_effort = "high"
disable_response_storage = true
network_access = "enabled"
windows_wsl_setup_acknowledged = true

[model_providers.OpenAI]
name = "OpenAI"
base_url = "$CODEX_BASE_URL"
wire_api = "responses"
requires_openai_auth = false
http_headers = { "x-openai-actor-authorization" = "local-image-extension" }

[features]
goals = true
image_generation = true
EOF
  printf '{\n  "OPENAI_API_KEY": "%s"\n}\n' "$escaped_key" > "$auth_temp"

  backup_if_exists "$CONFIG_FILE"
  backup_if_exists "$AUTH_FILE" true
  mv -f "$config_temp" "$CONFIG_FILE"
  mv -f "$auth_temp" "$AUTH_FILE"
  chmod 600 "$AUTH_FILE" 2>/dev/null || true
  trap - RETURN
}

main() {
  if [ "$(id -u)" -eq 0 ]; then
    say "请不要用 sudo 运行。脚本只应该写入当前用户的 $CODEX_HOME。"
    exit 1
  fi

  say "UseGoodAI Codex 一键配置"
  say ""
  say "接口地址：$CODEX_BASE_URL"
  say "默认模型：$CODEX_MODEL"
  say ""
  say "脚本不会安装软件；新配置不会写入沙盒或审批字段。"
  say ""

  show_write_plan
  say ""

  local api_key
  read_validated_api_key api_key

  write_codex_files "$api_key"

  say ""
  say "Codex 配置已写入。"
  report_running_clients
  say "Codex App / ChatGPT：重新打开后新建任务发送：测试"
  say "Codex CLI：启动新的 Codex 会话后发送：测试"
}

main "$@"
