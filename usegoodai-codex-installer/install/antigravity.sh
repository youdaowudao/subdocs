#!/usr/bin/env bash
# UseGoodAI Antigravity App 接入命令，macOS / Linux；不安装二进制、不需要 sudo。
set -euo pipefail
VERSION="1.0.3"
BASE_URL="https://api.usegoodai.com"
system="$(uname -s)"
case "$system" in
  Linux) profile_dir="${XDG_CONFIG_HOME:-$HOME/.config}/UseGoodAI/Antigravity" ;;
  Darwin) profile_dir="$HOME/Library/Application Support/UseGoodAI/Antigravity" ;;
  *) printf '此命令只用于 Linux 和 Mac。\n' >&2; exit 1 ;;
esac
profile="$profile_dir/connection.json"
action=connect
if [[ ${1:-} != --* && -n ${1:-} ]]; then action="$1"; shift; fi
explicit=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) [[ $# -ge 2 ]] || { echo '--app 后面需要软件路径'; exit 2; }; explicit="$2"; shift 2 ;;
    *) echo '用法：connect [--app 路径]、open [--app 路径]、restore、status、version'; exit 2 ;;
  esac
done
case "$action" in
  version) echo "$VERSION"; exit ;;
  restore)
    if [[ -f "$profile" ]]; then rm -- "$profile"; fi
    echo '已撤销本助手的接入配置。完全退出 Antigravity 后，从官方入口重新打开。'; exit ;;
  connect|open|status) ;;
  *) echo '用法：connect [--app 路径]、open [--app 路径]、restore、status、version'; exit 2 ;;
esac

# JSON: Linux uses existing Python 3; Mac uses built-in JXA, no new tool installation.
json_tool() {
  local mode="$1"
  if [[ "$system" = Darwin ]]; then
    /usr/bin/osascript -l JavaScript -e '
ObjC.import("Foundation");
function run(argv) {
  var text=ObjC.unwrap($.NSString.alloc.initWithDataEncoding($.NSFileHandle.fileHandleWithStandardInput.readDataToEndOfFile,$.NSUTF8StringEncoding));
  function ids(list) {
    var seen={}, out=[];
    list.forEach(function(v) {
      var id=String(v).trim().replace(/^models\//,"");
      if(!/^gemini-[a-z0-9][a-z0-9.-]*$/.test(id)||/image|embedding|audio|tts|live|robotics/.test(id)||seen[id])return;
      seen[id]=true;out.push(id);
    });
    var order=["gemini-3.8-flash","gemini-4-hydrogen","gemini-4-carbon","gemini-3.1-pro-preview"];
    for(var i=0;i<order.length;i++){var x=out.indexOf(order[i]);if(x>=0){out.splice(x,1);out.unshift(order[i]);break;}}
    if(!out.length)throw Error("没有可用 Gemini 编程模型");
    return out;
  }
  if(argv[0]==="save") {
    var a=text.split("\n");return JSON.stringify({key:a[0],models:a[1].split(","),appPath:a[2]},null,2);
  }
  var p=JSON.parse(text);
  if(argv[0]==="models"){
    if(p.nextPageToken||!Array.isArray(p.models))throw Error("模型列表不完整");
    return ids(p.models.filter(function(x){return !x.supportedGenerationMethods||!x.supportedGenerationMethods.length||x.supportedGenerationMethods.indexOf("generateContent")>=0||x.supportedGenerationMethods.indexOf("streamGenerateContent")>=0;}).map(function(x){return x.name;})).join(",");
  }
  if(!/^sk-[A-Za-z0-9_-]+$/.test(p.key)||!Array.isArray(p.models))throw Error("配置无效");
  return p.key+"\n"+ids(p.models).join(",")+"\n"+(p.appPath||"");
}' "$mode"
  else
    if ! command -v python3 >/dev/null 2>&1; then
      echo '本机需要已有 Python 3 来读取 Gemini 原生 JSON 模型列表；未安装任何依赖。' >&2
      return 1
    fi
    python3 -c '
import json, re, sys
def ids(values):
    out = []
    for value in values:
        model = str(value).strip()
        if model.startswith("models/"): model = model[7:]
        if (re.fullmatch(r"gemini-[a-z0-9][a-z0-9.-]*", model)
                and not re.search(r"image|embedding|audio|tts|live|robotics", model)
                and model not in out):
            out.append(model)
    if not out:
        raise ValueError("没有可用 Gemini 编程模型")
    for preferred in ["gemini-3.8-flash", "gemini-4-hydrogen", "gemini-4-carbon", "gemini-3.1-pro-preview"]:
        if preferred in out:
            out.remove(preferred); out.insert(0, preferred); break
    return out
try:
    mode = sys.argv[1]
    if mode == "save":
        key, models, app = sys.stdin.read().splitlines()[:3]
        print(json.dumps({"key": key, "models": models.split(","), "appPath": app}, ensure_ascii=False, indent=2))
    else:
        data = json.load(sys.stdin)
        if mode == "models":
            if data.get("nextPageToken") or not isinstance(data.get("models"), list):
                raise ValueError("模型列表不完整")
            print(",".join(ids(x.get("name", "") for x in data["models"]
                if not x.get("supportedGenerationMethods") or
                {"generateContent", "streamGenerateContent"}.intersection(x["supportedGenerationMethods"]))))
        else:
            key = data["key"]
            if not re.fullmatch(r"sk-[A-Za-z0-9_-]+", key):
                raise ValueError("配置无效")
            print(key); print(",".join(ids(data["models"]))); print(data.get("appPath", ""))
except (ValueError, TypeError, KeyError):
    sys.exit(1)
' "$mode"
  fi
}

resolve_app() {
  local p="$1"
  [[ -n "$p" && "$p" != *$'\n'* ]] || return 1
  case "$p" in '~/'*) p="$HOME/${p:2}" ;; esac
  p="${p%/}"
  if [[ "$system" = Darwin && "$p" = *.app ]]; then
    if [[ -x "$p/Contents/MacOS/Antigravity" ]]; then p="$p/Contents/MacOS/Antigravity"
    else p="$p/Contents/MacOS/antigravity"; fi
  elif [[ "$system" = Linux ]]; then
    # The official Linux App is an archive; accept its extracted folder or executable.
    if [[ -d "$p" ]]; then p="$p/antigravity"; fi
    p="$(readlink -f -- "$p" 2>/dev/null)" || return 1
    # Do not confuse the standalone IDE / CLI with the official Electron App.
    [[ -f "${p%/*}/resources/app.asar" && -f "${p%/*}/resources/bin/language_server" ]] || return 1
  fi
  case "${p##*/}" in antigravity|Antigravity) ;; *) return 1 ;; esac
  [[ -f "$p" && -x "$p" ]] || return 1
  local parent
  parent="$(cd "$(dirname "$p")" && pwd -P)" || return 1
  if [[ "$system" = Darwin && ! -f "$parent/../Resources/app.asar" ]]; then return 1; fi
  printf '%s/%s\n' "$parent" "${p##*/}"
}

find_app() {
  local p found root variant download_dir=""
  if [[ -n "$explicit" ]]; then resolve_app "$explicit"; return; fi
  if [[ -n "${app_path:-}" ]]; then resolve_app "$app_path" && return; fi
  if [[ "$system" = Darwin ]]; then
    for p in "$HOME/Applications/Antigravity.app" '/Applications/Antigravity.app'; do
      found="$(resolve_app "$p")" && { printf '%s\n' "$found"; return; }
    done
  else
    if command -v xdg-user-dir >/dev/null 2>&1; then
      download_dir="$(xdg-user-dir DOWNLOAD 2>/dev/null || true)"
    fi
    # Direct checks only: never recursively search the user's files.
    for root in "$HOME" "$download_dir" "$HOME/Downloads" "$HOME/下载" "$HOME/Applications" /opt; do
      [[ -n "$root" ]] || continue
      for variant in Antigravity-x64 Antigravity-arm64; do
        found="$(resolve_app "$root/$variant")" && { printf '%s\n' "$found"; return; }
      done
    done
  fi
  p="$(command -v antigravity 2>/dev/null || true)"
  [[ -z "$p" ]] || { found="$(resolve_app "$p")" && { printf '%s\n' "$found"; return; }; }
  return 1
}

load_profile() {
  local data
  [[ -f "$profile" ]] || return 1
  data="$(json_tool read < "$profile")" || return 1
  { IFS= read -r key; IFS= read -r models; IFS= read -r app_path || true; } <<< "$data"
  [[ -n "$key" && -n "$models" ]]
}

if [[ "$action" = status ]]; then
  if load_profile; then echo "已配置 UseGoodAI（${models//,/, }）"; else echo '尚未接入 UseGoodAI'; fi
  exit
fi
key=""; models=""; app_path=""
if [[ -f "$profile" ]]; then
  if ! load_profile; then echo '现有 Antigravity 接入配置无法读取，未改动。' >&2; exit 1; fi
elif [[ "$action" = open ]]; then
  echo '还没有接入配置，请先运行接入命令。' >&2; exit 1
fi

if ! resolved="$(find_app)"; then
  if [[ -n "$explicit" ]]; then
    echo '未找到指定的官方 Antigravity App，请检查 --app 路径。' >&2; exit 1
  fi
  if ! { exec 3</dev/tty; } 2>/dev/null; then
    echo '未找到 Antigravity App，请安装官方 App 后用 --app 指定其程序路径。' >&2; exit 1
  fi
  if [[ "$system" = Linux ]]; then
    printf 'Linux 官方 Antigravity App 为解压版，没有固定安装地址。\n未在常用目录找到 App，请输入你解压后的文件夹路径（也可输入里面的 antigravity 程序路径）：' >&2
  else
    printf '未在「应用程序」中找到 Antigravity.app，请输入 App 的完整路径：' >&2
  fi
  IFS= read -r -u 3 explicit || exit 1
  resolved="$(find_app)" || { echo '该路径未找到官方 Antigravity App，请检查解压后的文件夹或程序路径，配置没有改动。' >&2; exit 1; }
fi
app_path="$resolved"

if [[ "$action" = connect ]]; then
  if [[ -n "${USEGOODAI_KEY:-}" ]]; then
    key="$USEGOODAI_KEY"; unset USEGOODAI_KEY
  else
    if ! { exec 3</dev/tty; } 2>/dev/null; then echo '请在终端运行接入命令并输入 Key。' >&2; exit 1; fi
    printf '请输入 Gemini 分组 API Key：' >&2
    IFS= read -r -u 3 key || exit 1
  fi
  [[ "$key" =~ ^sk-[A-Za-z0-9_-]+$ ]] || { echo '请粘贴完整的 UseGoodAI 密钥，配置没有改动。' >&2; exit 1; }
  response="$(mktemp "${TMPDIR:-/tmp}/usegoodai-antigravity.XXXXXX")"
  staged=""
  cleanup() { [[ -z "${response:-}" ]] || rm -f -- "$response"; [[ -z "${staged:-}" ]] || rm -f -- "$staged"; }
  trap cleanup EXIT
  # Credential goes through stdin to curl; never a command-line argument.
  if ! http_code="$(printf 'Authorization: Bearer %s\n' "$key" | curl -q -sS --max-time 10 -H @- -H 'Accept: application/json' -o "$response" -w '%{http_code}' "$BASE_URL/v1beta/models")"; then
    echo '无法连接 UseGoodAI 查询 Gemini 模型，配置没有改动。' >&2; exit 1
  fi
  if [[ "$http_code" != 200 ]]; then
    echo "Gemini 分组密钥或模型查询未通过（HTTP $http_code），配置没有改动。" >&2; exit 1
  fi
  models="$(json_tool models < "$response")" || { echo '当前密钥没有可用的 Gemini 编程模型，或模型列表返回异常。配置没有改动。' >&2; exit 1; }
  umask 077
  mkdir -p "$profile_dir"
  staged="$(mktemp "$profile_dir/.connection.json.XXXXXX")"
  printf '%s\n%s\n%s\n' "$key" "$models" "$app_path" | json_tool save > "$staged"
  chmod 600 "$staged"
  mv -f -- "$staged" "$profile"; staged=""
  echo '已保存 UseGoodAI 接入配置。'
fi

if command -v pgrep >/dev/null 2>&1 && { pgrep -u "$(id -u)" -x Antigravity >/dev/null 2>&1 || pgrep -u "$(id -u)" -x antigravity >/dev/null 2>&1; }; then
  echo '请先彻底退出正在运行的 Antigravity，再运行打开命令。'
  exit 0
fi
(
  export AGY_LLM_GATEWAY_URL="$BASE_URL"
  export AGY_LLM_GATEWAY_API_KEY="$key"
  export AGY_LLM_GATEWAY_WIRE_PROTOCOL=genai
  export AGY_LLM_GATEWAY_MODELS="$models"
  cd "$(dirname "$app_path")"
  exec nohup "$app_path" </dev/null >/dev/null 2>&1
) &
echo '已请求打开官方 Antigravity App，新建对话，发送“测试”。'
