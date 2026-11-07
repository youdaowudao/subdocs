package connect

import (
	"context"
	"fmt"
	"time"
)

// ClaudeStopResult tells whether Claude Desktop was running and whether it
// could be closed.
type ClaudeStopResult struct {
	Found bool
	Left  bool
}

const claudeRequestTimeout = 20 * time.Second

const messageClaudeGroupRetry = "也可能是当前分组暂时没有可用模型，可到网站切换其他 Claude 分组后重新导入。"

// Messages for Claude Desktop and the Claude Code CLI.
const (
	MessageClaudeEmpty             = "还没有输入密钥。到 UseGoodAI 网站的「API 密钥」页选一个密钥，点「一键导入 Claude」；或复制密钥粘贴到上面，再点「一键连接 Claude」。"
	MessageClaudeNotInstalled      = "没检测到 Claude 桌面版。先点上面的「官网下载」安装（打不开官网就进 QQ 群在群文件下载），装好后再点「一键连接 Claude」。"
	MessageClaudeRejected          = "密钥无效，请回网站重新复制完整的密钥。Claude 配置没有改动。"
	MessageClaudeDisabled          = "这个密钥已停用、过期或额度用完，请在网站换一个可用的密钥。Claude 配置没有改动。"
	MessageClaudeTimeout           = "检查密钥超时：20 秒内未完成检查。Claude 配置没有改动。" + messageClaudeGroupRetry
	MessageClaudeOffline           = "检查密钥时无法连接 UseGoodAI 服务器。Claude 配置没有改动。" + messageClaudeGroupRetry
	MessageClaudeServerError       = "UseGoodAI 服务器暂时出错（%s），无法确认密钥。Claude 配置没有改动。" + messageClaudeGroupRetry + "仍不行请进 QQ 群联系客服。"
	MessageClaudeModelsTimeout     = "密钥检查已通过，但获取 Claude 模型列表超时：20 秒内未完成查询。Claude 配置没有改动。" + messageClaudeGroupRetry
	MessageClaudeModelsOffline     = "密钥检查已通过，但获取 Claude 模型列表时无法连接 UseGoodAI 服务器。Claude 配置没有改动。" + messageClaudeGroupRetry
	MessageClaudeModelsServerError = "密钥检查已通过，但获取 Claude 模型列表失败（%s）。Claude 配置没有改动。" + messageClaudeGroupRetry + "仍不行请进 QQ 群联系客服。"
	MessageClaudeNoModel           = "当前分组暂时没有可用的 Claude 模型。Claude 配置没有改动。请到网站切换其他 Claude 分组后重新导入。"
	MessageClaudeNeedBalance       = "密钥没问题，但账户余额为 $0：余额为 0 时服务器不让查询这个密钥能用哪些 Claude 模型。充值后再点「一键连接 Claude」，新人进群领 2 元。Claude 配置没有改动。"
	MessageClaudeNoBalance         = "已连接 UseGoodAI，写入了 %d 个 Claude 模型，但余额为 $0，充值后才能用；新人进群领 2 元。"
	MessageClaudeClosed            = "Claude 已关闭，重新打开即可，新建对话，发送“测试”。"
	MessageClaudeNotClosed         = "没能自动关闭 Claude，请从右下角托盘彻底退出后重新打开，新建对话，发送“测试”。"
	MessageClaudeOpen              = "打开 Claude，新建对话，发送“测试”。"
	MessageClaudeRestored          = "已恢复官方登录，重新打开 Claude 后用官方账号登录。"
	MessageClaudeRestoredOpen      = "已恢复官方登录，但没能自动关闭 Claude，请从右下角托盘彻底退出后重新打开，用官方账号登录。"
	MessageClaudeCodeRestored      = "Claude Code CLI 也已取消 UseGoodAI 连接，新开终端运行 claude 后用官方账号登录。"
	MessageClaudeCodeConnected     = "Claude Code CLI 也已接入 ✓ 新开一个终端运行 claude 即可。"
	MessageClaudeCodeFailed        = "Claude Code CLI 接入失败：%s。Claude 桌面版不受影响，可以再点一次「一键连接 Claude」。"
)

// ClaudeStatus reads the Claude card.
func (s *Service) ClaudeStatus() ClaudeStatus {
	status, key := readClaudeStatus(s.Claude)
	if key != "" {
		status.Name = lookupName(s.NamesFile, key)
	}
	return status
}

// ConnectClaude checks the key, takes the Claude models its group may use,
// writes Claude Desktop's third-party profile and closes Claude Desktop.
// Nothing is written unless the server confirms the key and lists at least
// one Claude model. OfferCLI asks the window whether to connect the Claude
// Code CLI too.
func (s *Service) ConnectClaude(ctx context.Context, raw, name string) Result {
	s.mu.Lock()
	defer s.mu.Unlock()

	key, ok := NormalizeKey(raw)
	if !ok {
		if key == "" {
			result := s.result(ToneError, MessageClaudeEmpty)
			result.Action = ActionOpenSite
			return result
		}
		return s.result(ToneError, MessageBadFormat)
	}
	if !s.Claude.Installed() {
		return s.result(ToneError, MessageClaudeNotInstalled)
	}
	// Both the client and each request's context must allow the longer wait.
	client := *s.Client
	client.Timeout = claudeRequestTimeout
	check := checkKey(ctx, &client, s.BaseURL, key, claudeRequestTimeout)
	switch check.State {
	case KeyRejected:
		return s.result(ToneError, MessageClaudeRejected)
	case KeyDisabled:
		return s.result(ToneError, MessageClaudeDisabled)
	case KeyTimeout:
		return s.result(ToneError, MessageClaudeTimeout)
	case KeyOffline:
		return s.result(ToneError, MessageClaudeOffline)
	case KeyServerError:
		return s.result(ToneError, fmt.Sprintf(MessageClaudeServerError, serverProblem(check.StatusCode)))
	case KeyClockWrong, KeyUntrusted:
		return s.result(ToneError, certificateMessage(check.State, s.Now(), "Claude 配置没有改动。"))
	}
	ids, state, code := listModels(ctx, &client, s.BaseURL, key, claudeRequestTimeout)
	switch state {
	case ModelsNoBalance:
		return s.result(ToneError, MessageClaudeNeedBalance)
	case ModelsRejected:
		if check.State == KeyNoBalance {
			return s.result(ToneError, MessageClaudeNeedBalance)
		}
		return s.result(ToneError, MessageClaudeRejected)
	case ModelsTimeout:
		return s.result(ToneError, MessageClaudeModelsTimeout)
	case ModelsOffline:
		return s.result(ToneError, MessageClaudeModelsOffline)
	case ModelsServerError:
		return s.result(ToneError, fmt.Sprintf(MessageClaudeModelsServerError, serverProblem(code)))
	}
	models := ClaudeDesktopModels(ids)
	if len(models) == 0 {
		return s.result(ToneError, MessageClaudeNoModel)
	}
	// Claude is closed first, like Codex: the app saves its config files
	// when it exits, which could undo what is written below.
	stopped := ClaudeStopResult{}
	if s.StopClaude != nil {
		stopped = s.StopClaude()
	}
	if err := WriteClaudeDesktop(s.Claude, key, models, s.Now()); err != nil {
		return s.result(ToneError, "写入 Claude 配置失败："+reason(err)+"。原配置没有改动，可以重试。")
	}
	if name != "" {
		_ = rememberName(s.NamesFile, key, name)
	}

	tone := ToneSuccess
	message := "已连接 UseGoodAI ✓"
	if check.HasRemaining {
		message += " 余额 " + FormatUSD(check.Remaining)
	}
	message += fmt.Sprintf("，写入了 %d 个 Claude 模型。", len(models))
	if check.State == KeyNoBalance {
		tone, message = ToneWarning, fmt.Sprintf(MessageClaudeNoBalance, len(models))
	}
	switch {
	case stopped.Left:
		tone = ToneWarning
		message += MessageClaudeNotClosed
	case stopped.Found:
		message += MessageClaudeClosed
	default:
		message += MessageClaudeOpen
	}
	result := s.result(tone, message)
	result.OfferCLI = s.ClaudeCLI.Installed() && !s.ClaudeCLI.ConnectedWith(key)
	return result
}

// ConnectClaudeCode writes the key into the Claude Code CLI's settings. The
// window calls it only after ConnectClaude succeeded with the same key and
// the user agreed, so the key is not checked again.
func (s *Service) ConnectClaudeCode(raw string) Result {
	s.mu.Lock()
	defer s.mu.Unlock()
	key, ok := NormalizeKey(raw)
	if !ok {
		return s.result(ToneError, MessageBadFormat)
	}
	if err := WriteClaudeCode(s.ClaudeCLI, key, s.Now()); err != nil {
		return s.result(ToneError, fmt.Sprintf(MessageClaudeCodeFailed, reason(err)))
	}
	return s.result(ToneSuccess, MessageClaudeCodeConnected)
}

// RestoreClaude switches Claude Desktop back to the official login and
// closes it.
func (s *Service) RestoreClaude() Result {
	s.mu.Lock()
	defer s.mu.Unlock()
	left := s.StopClaude != nil && s.StopClaude().Left
	if err := RestoreClaudeDesktop(s.Claude, s.Now()); err != nil {
		return s.result(ToneError, "恢复官方登录失败："+reason(err)+"。原配置没有改动，可以重试。")
	}
	tone, message := ToneSuccess, MessageClaudeRestored
	if left {
		tone, message = ToneWarning, MessageClaudeRestoredOpen
	}
	cli, err := RestoreClaudeCode(s.ClaudeCLI, s.Now())
	switch {
	case err != nil:
		tone = ToneWarning
		message += "\nClaude Code CLI 没能恢复：" + reason(err) + "。"
	case cli:
		message += "\n" + MessageClaudeCodeRestored
	}
	return s.result(tone, message)
}
