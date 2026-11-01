package connect

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"
)

// Result tones: green, amber and red in the window.
const (
	ToneSuccess = "success"
	ToneWarning = "warning"
	ToneError   = "error"
)

// Messages shown in the result bar.
const (
	MessageEmptyKey        = "请先粘贴 UseGoodAI 的密钥（sk- 开头）。"
	MessageBadFormat       = "这不是 UseGoodAI 的密钥（应以 sk- 开头），请重新复制。"
	MessageRejected        = "密钥无效，请回网站重新复制完整的密钥。Codex 配置没有改动。"
	MessageDisabled        = "这个密钥已停用、过期或额度用完，请在网站换一个可用的密钥。Codex 配置没有改动。"
	MessageUnreachable     = "连不上 UseGoodAI 服务器，Codex 配置没有改动。检查网络后再点一次。"
	MessageLinkIncomplete  = "导入链接不完整，请回网站重新点「一键导入」。"
	MessageLinkUnsupported = "当前助手不支持这个导入，请下载新版助手。"
	MessageNoBalance       = "已连接，但余额为 $0。充值后即可使用；新人进群领 2 元。"
	MessageCloseFailed     = "配置已写好，但没能自动关闭 Codex，请手动退出后重新打开。"
	MessageNotClosed       = "没能自动关闭 Codex，请手动退出后重新打开。"
	MessageClosed          = "Codex 已关闭，重新打开即可。"
	MessageRestored        = "已恢复官方登录，重新打开 Codex 后用官方账号登录。"
	MessageRestoredOpen    = "已恢复官方登录，但没能自动关闭 Codex，请手动退出后重新打开，用官方账号登录。"
)

// Result is what one action shows: the bar and the refreshed Codex card.
type Result struct {
	Tone    string `json:"tone"`
	Message string `json:"message"`
	Status  Status `json:"status"`
}

// Service runs one action at a time; a link that arrives during a
// connection waits for it.
type Service struct {
	CodexHome   string
	BaseURL     string
	Client      *http.Client
	Now         func() time.Time
	StopClients func() StopResult

	mu sync.Mutex
}

// Status reads the current Codex configuration.
func (s *Service) Status() Status { return ReadStatus(s.CodexHome) }

// Connect checks the key, writes the Codex files and closes Codex. Nothing is
// written unless the server confirms the key.
func (s *Service) Connect(ctx context.Context, raw string) Result {
	s.mu.Lock()
	defer s.mu.Unlock()

	key, ok := NormalizeKey(raw)
	if !ok {
		if key == "" {
			return s.result(ToneError, MessageEmptyKey)
		}
		return s.result(ToneError, MessageBadFormat)
	}
	check := CheckKey(ctx, s.Client, s.BaseURL, key)
	switch check.State {
	case KeyRejected:
		return s.result(ToneError, MessageRejected)
	case KeyDisabled:
		return s.result(ToneError, MessageDisabled)
	case KeyUnreachable:
		return s.result(ToneError, MessageUnreachable)
	}
	if s.CodexHome == "" {
		return s.result(ToneError, writeFailed(errors.New("找不到当前用户的文件夹")))
	}
	if err := WriteCodexFiles(s.CodexHome, key, s.Now()); err != nil {
		return s.result(ToneError, writeFailed(err))
	}
	stopped := s.StopClients()

	if check.State == KeyNoBalance {
		message := MessageNoBalance
		if stopped.Left {
			message += MessageNotClosed
		} else if stopped.Closed() {
			message += MessageClosed
		}
		return s.result(ToneWarning, message)
	}
	if stopped.Left {
		return s.result(ToneWarning, MessageCloseFailed)
	}
	message := "已连接 UseGoodAI ✓"
	if check.HasRemaining {
		message += " 余额 " + FormatUSD(check.Remaining)
	}
	if stopped.Closed() {
		message += "。Codex 已关闭，重新打开即可，新建任务，发送“测试”。"
	} else {
		message += "。打开 Codex，新建任务，发送“测试”。"
	}
	return s.result(ToneSuccess, message)
}

// LinkResult is a parsed link, or the message to show when it is rejected.
type LinkResult struct {
	OK     bool   `json:"ok"`
	Key    string `json:"key"`
	Name   string `json:"name"`
	Result Result `json:"result"`
}

// ParseLink checks an import link before the window starts the connection.
func (s *Service) ParseLink(raw string) LinkResult {
	link, problem := ParseImportLink(raw)
	switch problem {
	case LinkOK:
		return LinkResult{OK: true, Key: link.Key, Name: link.Name}
	case LinkUnsupported:
		return LinkResult{Result: s.result(ToneError, MessageLinkUnsupported)}
	default:
		return LinkResult{Result: s.result(ToneError, MessageLinkIncomplete)}
	}
}

// Restore switches Codex back to the official login and closes it.
func (s *Service) Restore() Result {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.CodexHome != "" {
		if err := RestoreOfficial(s.CodexHome, s.Now()); err != nil {
			return s.result(ToneError, "恢复官方登录失败："+reason(err)+"。原配置没有改动，可以重试。")
		}
	}
	if s.StopClients().Left {
		return s.result(ToneWarning, MessageRestoredOpen)
	}
	return s.result(ToneSuccess, MessageRestored)
}

func (s *Service) result(tone, message string) Result {
	return Result{Tone: tone, Message: message, Status: s.Status()}
}

// FormatUSD shows dollars with two decimals, as the website does.
func FormatUSD(amount float64) string {
	return fmt.Sprintf("$%.2f", amount)
}

func writeFailed(err error) string {
	return "写入 Codex 配置失败：" + reason(err) + "。原配置没有改动，可以重试。"
}

// reason keeps the system's own wording (localised on Windows) without the
// Go operation prefix or the full path.
func reason(err error) string {
	var pathError *fs.PathError
	var linkError *os.LinkError
	if errors.As(err, &pathError) {
		err = pathError.Err
	} else if errors.As(err, &linkError) {
		err = linkError.Err
	}
	return strings.TrimRight(strings.TrimSpace(err.Error()), "。.")
}
