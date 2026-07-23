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
  local codex_running=false
  local chatgpt_running=false
  running_clients="$(detect_running_clients)"

  while IFS= read -r process_name; do
    case "$(printf '%s' "$process_name" | tr '[:upper:]' '[:lower:]')" in
      codex|codex.exe)
        codex_running=true
        ;;
      chatgpt|chatgpt.exe)
        chatgpt_running=true
        ;;
    esac
  done <<EOF
$running_clients
EOF

  if [ "$chatgpt_running" = true ] && [ "$codex_running" = true ]; then
    say "当前检测到 ChatGPT 软件和 Codex CLI 正在运行，请完全退出并结束任务后，重新打开测试连接，如有问题请联系网站客服。"
  elif [ "$chatgpt_running" = true ]; then
    say "当前检测到 ChatGPT 软件正在运行，请完全退出并结束任务后，重新打开测试连接，如有问题请联系网站客服。"
  elif [ "$codex_running" = true ]; then
    say "当前检测到 Codex CLI 正在运行，请完全退出并结束任务后，重新打开测试连接，如有问题请联系网站客服。"
  else
    say "当前未检测到 ChatGPT/Codex CLI 运行，请启动软件后进行测试。"
  fi
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
  fi
}

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

show_write_plan() {
  if [ -f "$CONFIG_FILE" ] || [ -f "$AUTH_FILE" ]; then
    say ""
    say "检测到已有旧配置，将会在备份后再覆盖。"
  fi
}

read_validated_api_key() {
  local var_name="$1"
  local entered_key
  while true; do
    read_input entered_key "请粘贴从 UseGoodAI 中转站复制过来的 API Key，然后回车确认："
    if [ -z "$entered_key" ]; then
      say ""
      say "API Key 不能为空，请重新输入。"
      say ""
      continue
    fi
    case "$entered_key" in
      sk-*)
        printf -v "$var_name" '%s' "$entered_key"
        return
        ;;
      *)
        say ""
        say "API Key 格式错误，必须以 sk- 开头，请重新输入。"
        say ""
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

  say "欢迎使用 UseGoodAI 中转站 Codex 一键配置脚本。"
  say ""
  say "本脚本不会安装、修改任何软件，只会配置用户目录下 .codex 文件夹中的 config.toml 和 auth.json 文件。"

  show_write_plan
  say ""

  local api_key
  read_validated_api_key api_key

  write_codex_files "$api_key"

  say ""
  say "配置已经完成，可以关闭终端了。"
  say ""
  report_running_clients
  say ""
  say "感谢您对 UseGoodAI 中转站的支持，使用过程中如有问题请联系网站客服。"
}

main "$@"
