package connect

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// The image tool (usegoodai-imagines-tool) is its own project. The assistant
// carries one of its released programs and runs "install" with the key on
// standard input, exactly as a customer would type it. These names mirror the
// files that program writes; the assistant only reads them.
const (
	imageToolDirectory = "usegoodai-imagines-tool"
	imageManagedBy     = "usegoodai-imagines-tool"
	imageManifestName  = "install-manifest.json"
	imageKeyName       = "api-key"
	imageKeySourceName = "key-source"
	imageKeyFromAuth   = "auth-json"
	// ImageModelPrefix marks the models the image tool calls.
	ImageModelPrefix = "gpt-image"
)

// Image card states.
const (
	ImageNone      = "none"      // not installed
	ImageReady     = "ready"     // installed with a key
	ImageNoKey     = "nokey"     // installed, key missing
	ImageOutdated  = "outdated"  // installed, older than the bundled program
	ImageUnmanaged = "unmanaged" // files present that the tool cannot vouch for
)

// ImageStatus is what the image card shows. Key is masked.
type ImageStatus struct {
	State   string `json:"state"`
	Version string `json:"version,omitempty"`
	Bundled string `json:"bundled,omitempty"`
	Key     string `json:"key,omitempty"`
	Name    string `json:"name,omitempty"`
	Shared  bool   `json:"shared,omitempty"`
}

// ImageCodexHome is where the image tool installs: CODEX_HOME when set, as
// the tool itself decides, else ~/.codex.
func ImageCodexHome() (string, error) {
	if configured := strings.TrimSpace(os.Getenv("CODEX_HOME")); configured != "" {
		return filepath.Clean(configured), nil
	}
	return CodexHome()
}

// ReadImageStatus inspects the installed image tool under codexHome.
// bundled is the version the assistant carries ("" when it carries none).
func ReadImageStatus(codexHome, bundled string) (ImageStatus, string) {
	status := ImageStatus{State: ImageNone, Bundled: bundled}
	if codexHome == "" {
		return status, ""
	}
	toolDir := filepath.Join(codexHome, "tools", imageToolDirectory)
	data, err := os.ReadFile(filepath.Join(toolDir, imageManifestName))
	if errors.Is(err, os.ErrNotExist) {
		return status, ""
	}
	var manifest struct {
		ManagedBy string `json:"managed_by"`
		Version   string `json:"version"`
	}
	if err != nil || json.Unmarshal(data, &manifest) != nil || manifest.ManagedBy != imageManagedBy {
		status.State = ImageUnmanaged
		return status, ""
	}
	status.Version = strings.TrimPrefix(strings.TrimSpace(manifest.Version), "V")

	key := ""
	source, _ := os.ReadFile(filepath.Join(toolDir, imageKeySourceName))
	if strings.TrimSpace(string(source)) == imageKeyFromAuth {
		var auth struct {
			Key string `json:"OPENAI_API_KEY"`
		}
		authData, _ := os.ReadFile(filepath.Join(codexHome, "auth.json"))
		if json.Unmarshal(authData, &auth) == nil {
			key = strings.TrimSpace(auth.Key)
		}
		status.Shared = key != ""
	} else {
		keyData, _ := os.ReadFile(filepath.Join(toolDir, imageKeyName))
		key = strings.TrimSpace(string(keyData))
	}

	switch {
	case key == "":
		status.State = ImageNoKey
	case bundled != "" && versionLess(status.Version, bundled):
		status.State = ImageOutdated
	default:
		status.State = ImageReady
	}
	if key != "" {
		status.Key = MaskKey(key)
	}
	return status, key
}

// versionLess compares dotted numbers such as 0.8.1 and 0.8.2.
func versionLess(a, b string) bool {
	as, bs := strings.Split(strings.TrimPrefix(a, "V"), "."), strings.Split(strings.TrimPrefix(b, "V"), ".")
	for i := 0; i < len(as) || i < len(bs); i++ {
		var x, y int
		if i < len(as) {
			x, _ = strconv.Atoi(as[i])
		}
		if i < len(bs) {
			y, _ = strconv.Atoi(bs[i])
		}
		if x != y {
			return x < y
		}
	}
	return false
}

// ImageInstaller runs the bundled image tool's "install" with key.
type ImageInstaller interface {
	// Version is the bundled program's version, "" when none is bundled.
	Version() string
	Install(ctx context.Context, codexHome, key string) error
}

// Messages for the image tool.
const (
	MessageImageEmpty       = "现在导入的是生图工具的 Key。到 UseGoodAI 网站「API 密钥」页或首页「快速开始」，选一个画图分组的密钥，点「一键导入」；也可以复制密钥粘贴到上面。"
	MessageImageNotBundled  = "这个版本的助手没有内置生图工具，请下载新版助手。"
	MessageImageRejected    = "密钥无效，请回网站重新复制完整的密钥。生图工具没有改动。"
	MessageImageDisabled    = "这个密钥已停用、过期或额度用完，请在网站换一个可用的密钥。生图工具没有改动。"
	MessageImageNoModel     = "这个密钥的分组不能画图（查不到 gpt-image 模型）。请到网站选画图分组的密钥，再点「一键导入」。生图工具没有改动。"
	MessageImageTimeout     = "网络超时：UseGoodAI 服务器 10 秒内没有回应。生图工具没有改动。网络慢或开了代理时，稍后再试一次。"
	MessageImageOffline     = "连不上 UseGoodAI 服务器：网络不通，或被代理、防火墙拦截。生图工具没有改动。检查网络后再试一次。"
	MessageImageServerError = "UseGoodAI 服务器暂时出错（%s），无法确认密钥。生图工具没有改动。稍后再试一次，仍不行请进 QQ 群联系客服。"
	MessageImageNoBalance   = "生图工具已装好，但余额为 $0，充值后才能画图；新人进群领 2 元。"
	MessageImageInstalled   = "生图工具 V%s 已装好 ✓ 重新打开 Codex 或新建任务，说“画一张白底红苹果”试试。"
)

// ImageStatus reads the image card.
func (s *Service) ImageStatus() ImageStatus {
	version := ""
	if s.Image != nil {
		version = s.Image.Version()
	}
	status, key := ReadImageStatus(s.ImageHome, version)
	if key != "" && !status.Shared {
		status.Name = lookupName(s.NamesFile, key)
	}
	return status
}

// InstallImage checks that key exists, is usable and may call a gpt-image
// model, then installs the bundled image tool with it. Codex is untouched.
func (s *Service) InstallImage(ctx context.Context, raw, name string) Result {
	s.mu.Lock()
	defer s.mu.Unlock()

	key, ok := NormalizeKey(raw)
	if !ok {
		if key == "" {
			result := s.result(ToneError, MessageImageEmpty)
			result.Action = ActionOpenSite
			return result
		}
		return s.result(ToneError, MessageBadFormat)
	}
	if s.Image == nil || s.Image.Version() == "" {
		return s.result(ToneError, MessageImageNotBundled)
	}
	check := CheckKey(ctx, s.Client, s.BaseURL, key)
	switch check.State {
	case KeyRejected:
		return s.result(ToneError, MessageImageRejected)
	case KeyDisabled:
		return s.result(ToneError, MessageImageDisabled)
	case KeyTimeout:
		return s.result(ToneError, MessageImageTimeout)
	case KeyOffline:
		return s.result(ToneError, MessageImageOffline)
	case KeyServerError:
		return s.result(ToneError, fmt.Sprintf(MessageImageServerError, serverProblem(check.StatusCode)))
	}
	models, code := CheckImageModels(ctx, s.Client, s.BaseURL, key)
	switch models {
	case ModelsNoImage:
		return s.result(ToneError, MessageImageNoModel)
	case ModelsRejected:
		return s.result(ToneError, MessageImageRejected)
	case ModelsTimeout:
		return s.result(ToneError, MessageImageTimeout)
	case ModelsOffline:
		return s.result(ToneError, MessageImageOffline)
	case ModelsServerError:
		return s.result(ToneError, fmt.Sprintf(MessageImageServerError, serverProblem(code)))
	}
	if s.ImageHome == "" {
		return s.result(ToneError, "安装生图工具失败：找不到当前用户的文件夹。")
	}
	if err := s.Image.Install(ctx, s.ImageHome, key); err != nil {
		return s.result(ToneError, "安装生图工具失败："+strings.TrimRight(err.Error(), "。.")+"。原有文件没有改动，可以重试。")
	}
	if name != "" {
		_ = rememberName(s.NamesFile, key, name)
	}
	if check.State == KeyNoBalance {
		return s.result(ToneWarning, MessageImageNoBalance)
	}
	return s.result(ToneSuccess, fmt.Sprintf(MessageImageInstalled, s.Image.Version()))
}
