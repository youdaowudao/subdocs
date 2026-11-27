package connect

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"sync"
	"time"
)

// Official Antigravity App Enterprise Gateway mode, using Gemini native REST.
const AntigravityDownloadURL = "https://antigravity.google/download"

var antigravityVariables = []string{"AGY_LLM_GATEWAY_URL", "AGY_LLM_GATEWAY_API_KEY", "AGY_LLM_GATEWAY_WIRE_PROTOCOL", "AGY_LLM_GATEWAY_MODELS"}
var antigravityModelID = regexp.MustCompile(`^gemini-[a-z0-9][a-z0-9.-]*$`)

// Only models appropriate for a text/coding conversation. Don't synthesize IDs.
func AntigravityModels(ids []string) []string {
	seen := map[string]bool{}
	var models []string
	for _, id := range ids {
		id = strings.TrimPrefix(strings.TrimSpace(id), "models/")
		if !antigravityModelID.MatchString(id) || seen[id] {
			continue
		}
		excluded := false
		for _, part := range []string{"image", "embedding", "audio", "tts", "live", "robotics"} {
			if strings.Contains(id, part) {
				excluded = true
				break
			}
		}
		if excluded {
			continue
		}
		seen[id] = true
		models = append(models, id)
	}
	// Use a verified default when available; preserve provider order for the rest.
	for _, preferred := range []string{"gemini-3.8-flash", "gemini-4-hydrogen", "gemini-4-carbon", "gemini-3.1-pro-preview"} {
		for i, model := range models {
			if model == preferred {
				copy(models[1:i+1], models[:i])
				models[0] = preferred
				return models
			}
		}
	}
	return models
}

func ListAntigravityModels(ctx context.Context, client *http.Client, base, key string) ([]string, error) {
	ctx, cancel := context.WithTimeout(ctx, usageTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, strings.TrimRight(base, "/")+"/v1beta/models", nil)
	if err != nil {
		return nil, errors.New("无法创建模型查询请求")
	}
	req.Header.Set("Authorization", "Bearer "+key)
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", "UseGoodAI-Quick-Connect/"+Version)
	res, err := client.Do(req)
	if err != nil {
		return nil, errors.New("无法连接 UseGoodAI 查询 Gemini 模型，请检查网络后重试")
	}
	defer res.Body.Close()
	if res.StatusCode != 200 {
		switch res.StatusCode {
		case 401, 403:
			return nil, fmt.Errorf("密钥或分组未获授权（HTTP %d），请检查 Gemini 分组密钥及余额", res.StatusCode)
		case 429:
			return nil, errors.New("模型查询暂时受限，请稍后重试")
		}
		return nil, fmt.Errorf("Gemini 模型查询失败（HTTP %d），请稍后重试", res.StatusCode)
	}
	var response struct {
		Models []struct {
			Name    string   `json:"name"`
			Methods []string `json:"supportedGenerationMethods"`
		} `json:"models"`
		Next string `json:"nextPageToken"`
	}
	if err := json.NewDecoder(io.LimitReader(res.Body, maxModelsAnswer)).Decode(&response); err != nil {
		return nil, errors.New("Gemini 模型列表返回格式异常")
	}
	// Current UseGoodAI returns the complete group list. Refuse a partial list
	// instead of silently discarding a page if the gateway behavior changes.
	if response.Next != "" {
		return nil, errors.New("Gemini 模型列表不完整，请联系客服")
	}
	var ids []string
	for _, model := range response.Models {
		if len(model.Methods) > 0 {
			ok := false
			for _, m := range model.Methods {
				if m == "generateContent" || m == "streamGenerateContent" {
					ok = true
				}
			}
			if !ok {
				continue
			}
		}
		ids = append(ids, model.Name)
	}
	models := AntigravityModels(ids)
	if len(models) == 0 {
		return nil, errors.New("当前密钥没有可用的 Gemini 编程模型，请选择 Gemini 分组")
	}
	return models, nil
}

type antigravityEnvValue struct {
	Value   string `json:"value"`
	Type    uint32 `json:"type"`
	Present bool   `json:"present"`
}
type antigravityEnvStore interface {
	Read() (map[string]antigravityEnvValue, error)
	Write(map[string]antigravityEnvValue) error
}
type antigravityProfile struct {
	Key      string                         `json:"key"`
	Name     string                         `json:"name,omitempty"`
	Models   []string                       `json:"models"`
	AppPath  string                         `json:"appPath,omitempty"`
	Applied  map[string]antigravityEnvValue `json:"applied,omitempty"`
	Previous map[string]antigravityEnvValue `json:"previous,omitempty"`
}

type AntigravityStatus struct {
	State       string `json:"state"`
	Key         string `json:"key,omitempty"`
	Name        string `json:"name,omitempty"`
	Models      int    `json:"models"`
	AppDetected bool   `json:"appDetected"`
	CLIDetected bool   `json:"cliDetected"`
}
type AntigravityResult struct {
	Tone        string            `json:"tone"`
	Message     string            `json:"message"`
	Antigravity AntigravityStatus `json:"antigravity"`
	Action      string            `json:"action,omitempty"`
}

// Antigravity stores only the private user-level profile. Windows additionally
// updates its four current-user variables, never machine variables. Other
// systems launch the official App with the four variables scoped to that process.
type Antigravity struct {
	Dir, BaseURL string
	Client       *http.Client
	Store        antigravityEnvStore
	Now          func() time.Time
	mu           sync.Mutex
	launch       func(string, []string) error
}

func NewAntigravity(base string) *Antigravity {
	dir, err := os.UserConfigDir()
	if err != nil {
		dir = ""
	} else {
		dir = filepath.Join(dir, "UseGoodAI", "Antigravity")
	}
	return &Antigravity{Dir: dir, BaseURL: base, Client: NewHTTPClient(), Store: newAntigravityEnvStore(), Now: time.Now}
}
func (a *Antigravity) profilePath() string { return filepath.Join(a.Dir, "connection.json") }
func (a *Antigravity) read() (antigravityProfile, error) {
	var p antigravityProfile
	if a.Dir == "" {
		return p, errors.New("找不到当前用户配置目录")
	}
	data, err := os.ReadFile(a.profilePath())
	if err != nil {
		return p, err
	}
	if err = json.Unmarshal(data, &p); err != nil {
		return p, errors.New("原有 Antigravity 接入配置损坏")
	}
	if k, ok := NormalizeKey(p.Key); !ok || k != p.Key || len(AntigravityModels(p.Models)) != len(p.Models) || len(p.Models) == 0 {
		return p, errors.New("原有 Antigravity 接入配置无效")
	}
	return p, nil
}
func (a *Antigravity) values(p antigravityProfile) map[string]antigravityEnvValue {
	out := map[string]antigravityEnvValue{}
	for i, v := range []string{a.BaseURL, p.Key, "genai", strings.Join(p.Models, ",")} {
		out[antigravityVariables[i]] = antigravityEnvValue{Value: v, Type: 1, Present: true}
	}
	return out
}
func (a *Antigravity) Status() (status AntigravityStatus) {
	p, err := a.read()
	defer func() {
		status.CLIDetected = detectAntigravityCLI()
		if p.AppPath != "" {
			if _, err := resolveAntigravityPath(p.AppPath); err == nil {
				status.AppDetected = true
				return
			}
		}
		_, detectErr := resolveAntigravityPath("")
		status.AppDetected = detectErr == nil
	}()
	if err != nil {
		if os.IsNotExist(err) {
			return AntigravityStatus{State: StateNone}
		}
		return AntigravityStatus{State: StateOther}
	}
	if a.Store != nil {
		current, err := a.Store.Read()
		if err != nil {
			return AntigravityStatus{State: StateOther}
		}
		for _, name := range antigravityVariables {
			if current[name] != p.Applied[name] {
				return AntigravityStatus{State: StateOther}
			}
		}
	}
	return AntigravityStatus{State: StateUseGoodAI, Key: MaskKey(p.Key), Name: displayName(p.Name), Models: len(p.Models)}
}
func (a *Antigravity) result(tone, message string) AntigravityResult {
	return AntigravityResult{Tone: tone, Message: message, Antigravity: a.Status()}
}
func (a *Antigravity) Connect(ctx context.Context, raw, name, appPath string) AntigravityResult {
	a.mu.Lock()
	defer a.mu.Unlock()
	key, ok := NormalizeKey(raw)
	if !ok {
		r := a.result(ToneError, "请粘贴 Gemini 分组的完整 UseGoodAI API Key。配置没有改动。")
		if key == "" {
			r.Action = ActionOpenSite
		}
		return r
	}
	if a.Dir == "" {
		return a.result(ToneError, "找不到当前用户配置目录。配置没有改动。")
	}
	old, err := a.read()
	if err != nil && !os.IsNotExist(err) {
		return a.result(ToneError, "原有接入配置无法读取，请先检查配置文件。配置没有改动。")
	}
	models, err := ListAntigravityModels(ctx, a.Client, a.BaseURL, key)
	if err != nil {
		return a.result(ToneError, err.Error()+"。Antigravity 配置没有改动。")
	}
	if appPath == "" && old.AppPath != "" {
		// A previously selected location may have moved. Try the ordinary
		// locations again rather than requiring the user to reset the profile.
		appPath, _ = resolveAntigravityPath(old.AppPath)
	}
	if appPath != "" || (runtime.GOOS == "darwin" && a.Store == nil) {
		appPath, err = resolveAntigravityPath(appPath)
		if err != nil {
			return a.result(ToneError, err.Error()+"。配置没有改动。")
		}
	}
	p := antigravityProfile{Key: key, Name: displayName(name), Models: models, AppPath: appPath}
	if p.Name == "" && p.Key == old.Key {
		p.Name = old.Name
	}
	var current map[string]antigravityEnvValue
	if a.Store != nil {
		current, err = a.Store.Read()
		if err != nil {
			return a.result(ToneError, "无法读取当前用户环境变量。配置没有改动。")
		}
		p.Previous = map[string]antigravityEnvValue{}
		p.Applied = a.values(p)
		for _, n := range antigravityVariables {
			p.Previous[n] = current[n]
			if old.Applied != nil && current[n] == old.Applied[n] {
				p.Previous[n] = old.Previous[n]
			}
		}
		if err = a.Store.Write(p.Applied); err != nil {
			return a.result(ToneError, "无法更新当前用户的 Antigravity 环境变量，请重试。")
		}
	}
	data, err := json.MarshalIndent(p, "", "  ")
	if err == nil {
		err = writeFileGroup([]fileChange{{path: a.profilePath(), data: append(data, '\n')}}, a.Now())
	}
	if err != nil {
		if a.Store != nil {
			if a.Store.Write(current) != nil {
				return a.result(ToneError, "配置保存失败，环境变量回退失败，请检查当前用户环境变量。")
			}
		}
		return a.result(ToneError, "无法保存 Antigravity 接入配置，请重试。")
	}
	// A model directory is not a live verification of the upstream models.
	result := a.result(ToneSuccess, "已保存 UseGoodAI 接入配置。")
	if a.Store != nil {
		if result.Antigravity.AppDetected || !result.Antigravity.CLIDetected {
			result.Message += "App 请彻底退出后重新打开，新建对话发送“测试”。"
		}
		if result.Antigravity.CLIDetected {
			result.Message += "CLI 请关闭并重新打开终端，运行 agy。"
		}
	} else {
		result.Message += "请先彻底退出 Antigravity，再通过助手的打开入口启动。"
	}
	return result
}
func (a *Antigravity) Restore() AntigravityResult {
	a.mu.Lock()
	defer a.mu.Unlock()
	p, err := a.read()
	if os.IsNotExist(err) {
		return a.result(ToneSuccess, "没有需要恢复的 UseGoodAI Antigravity 配置。")
	}
	if err != nil {
		return a.result(ToneError, "无法读取原有配置，未改动。")
	}
	var current map[string]antigravityEnvValue
	if a.Store != nil {
		current, err = a.Store.Read()
		if err != nil {
			return a.result(ToneError, "无法读取环境变量，未恢复。")
		}
		target := map[string]antigravityEnvValue{}
		for _, n := range antigravityVariables {
			target[n] = current[n]
			if current[n] == p.Applied[n] {
				target[n] = p.Previous[n]
			}
		}
		if err = a.Store.Write(target); err != nil {
			return a.result(ToneError, "恢复环境变量失败，请重试。")
		}
	}
	if err = os.Remove(a.profilePath()); err != nil {
		if a.Store != nil {
			_ = a.Store.Write(current)
		}
		return a.result(ToneError, "恢复配置失败，请重试。")
	}
	if a.Store != nil {
		return a.result(ToneSuccess, "已撤销本助手写入的接入配置。彻底退出 App 或关闭终端后重新打开即可。")
	}
	return a.result(ToneSuccess, "已撤销本助手写入的接入配置。彻底退出 Antigravity 后，用原来的软件入口打开即可。")
}
func (a *Antigravity) Open(appPath string) AntigravityResult {
	a.mu.Lock()
	defer a.mu.Unlock()
	p, err := a.read()
	if err != nil {
		return a.result(ToneError, "尚未保存接入配置，请先连接 Antigravity。")
	}
	if appPath == "" {
		appPath, _ = resolveAntigravityPath(p.AppPath)
	}
	appPath, err = resolveAntigravityPath(appPath)
	if err != nil {
		return a.result(ToneError, err.Error())
	}
	env := os.Environ()
	values := a.values(p)
	var launchEnv []string
	for _, entry := range env {
		name, _, _ := strings.Cut(entry, "=")
		if _, own := values[strings.ToUpper(name)]; !own {
			launchEnv = append(launchEnv, entry)
		}
	}
	for _, name := range antigravityVariables {
		launchEnv = append(launchEnv, name+"="+values[name].Value)
	}
	launch := a.launch
	if launch == nil {
		launch = launchAntigravity
	}
	if err = launch(appPath, launchEnv); err != nil {
		return a.result(ToneError, "没能打开 Antigravity。请确认官方 App 已安装并完全退出后重试。")
	}
	return a.result(ToneSuccess, "已请求打开 Antigravity。新建对话发送“测试”；若已有窗口未退出，请彻底退出后再打开。")
}
