package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
	"unicode/utf8"
)

// 启动守护（1.1.14）：多台 Windows 11 电脑双击助手后一闪就退出，或者根本不出现。
// 两个已确认会无声退出的原因：
//   - WebView2 创建失败时，go-webview2 把错误打印到图形程序没有的标准输出，随即
//     os.Exit(1)，不弹任何提示（数据目录损坏或被残留进程占用、显卡驱动、安全软件拦截都会这样）；
//   - 之前打开的助手卡在后台（窗口没出来或不响应）时，之后每次双击都把参数交给它后立即退出。
// 窗口进程一律用 CPU 绘制页面、关闭 WebView2 渲染进程代码完整性检查（见 main_windows.go）。
// 另外双击后先由不带窗口的守护进程把关，再启动真正的窗口进程：
//   1. 卡住的旧助手（启动 20 秒还没有窗口，或 3 秒不响应）先结束；
//   2. 启动窗口进程，等它的“页面就绪”信号；
//   3. 60 秒没就绪或异常退出：换新的 WebView2 数据目录再试一次，成功后记住；
//   4. 仍然打不开：弹窗写明原因，可以改用命令窗口连接 Codex。

const (
	// windowEnv carries the ready event's name; only the window process has it.
	windowEnv = "USEGOODAI_QC_WINDOW"
	// profileEnv is the WebView2 data folder the window process uses.
	profileEnv = "USEGOODAI_QC_PROFILE"
	// safeStartFile names the data folder a retry succeeded with.
	safeStartFile = "safe-start.txt"

	// A starting assistant may take this long to show its window.
	instanceGrace = 20 * time.Second
	// A window that is not ready by then is treated as stuck.
	readyTimeout = 60 * time.Second
	// exitShown is the window process's exit code after it told the user why.
	exitShown = 3

	fallbackCommand = "irm https://docs.usegoodai.com/install/codex.ps1 | iex"
	docsURL         = "https://docs.usegoodai.com"
)

// instanceState describes an assistant window process already running.
type instanceState struct {
	running    bool
	pid        uint32
	visible    bool
	responding bool
	age        time.Duration
}

type instanceAction int

const (
	instanceNone instanceAction = iota // none running, or none we can name
	instanceUse                        // healthy: the new launch hands its link to it
	instanceWait                       // still starting: look again shortly
	instanceEnd                        // stuck: end it, then start normally
)

func judgeInstance(state instanceState) instanceAction {
	switch {
	case !state.running || state.pid == 0:
		return instanceNone
	case state.visible && state.responding:
		return instanceUse
	case state.age < instanceGrace:
		return instanceWait
	default:
		return instanceEnd
	}
}

// stuckReason says why a running assistant is treated as stuck.
func stuckReason(state instanceState) string {
	if !state.responding {
		return "不响应"
	}
	return fmt.Sprintf("运行 %d 秒仍没有窗口", int(state.age/time.Second))
}

// windowOutcome is how one start of the window process ended.
type windowOutcome struct {
	ready    bool
	exited   bool
	code     uint32
	timedOut bool
}

type nextStep int

const (
	stepDone   nextStep = iota // the window is up, or the link went to a running one
	stepRetry                  // fresh WebView2 data folder, once more
	stepGiveUp                 // explain and offer the command window
	stepQuiet                  // the window process already showed why
)

func judgeOutcome(attempt int, outcome windowOutcome) nextStep {
	switch {
	case outcome.ready:
		return stepDone
	case outcome.exited && outcome.code == 0:
		return stepDone
	case outcome.exited && outcome.code == exitShown:
		return stepQuiet
	case attempt == 1:
		return stepRetry
	default:
		return stepGiveUp
	}
}

func outcomeReason(outcome windowOutcome) string {
	if outcome.timedOut {
		return fmt.Sprintf("%d 秒内窗口没有打开", int(readyTimeout/time.Second))
	}
	return fmt.Sprintf("窗口程序意外退出（代码 %d）", int32(outcome.code))
}

// savedProfile is the WebView2 data folder a successful retry chose, else base.
func savedProfile(base string) (folder, name string) {
	data, err := os.ReadFile(filepath.Join(base, safeStartFile))
	name = strings.TrimSpace(strings.TrimPrefix(string(data), "\xef\xbb\xbf"))
	if err != nil || !strings.HasPrefix(name, "WebView2-") || strings.ContainsAny(name, `\/:.`) {
		return base, ""
	}
	return filepath.Join(base, name), name
}

func freshProfile(base string, now time.Time) (folder, name string) {
	name = "WebView2-" + now.Format("20060102-150405")
	return filepath.Join(base, name), name
}

func rememberProfile(base, name string) {
	_ = os.WriteFile(filepath.Join(base, safeStartFile), []byte(name+"\r\n"), 0o644)
}

// problemWords mark record lines that explain a failure.
var problemWords = []string{"WebView2", "错误", "致命", "panic", "fatal", "启动失败", "Exception"}

// recordProblem is the last record line, after offset, that explains a
// failure, without its time stamp.
func recordProblem(path string, offset int64) string {
	data, err := os.ReadFile(path)
	if err != nil || offset > int64(len(data)) {
		return ""
	}
	lines := strings.Split(strings.ReplaceAll(string(data[offset:]), "\r\n", "\n"), "\n")
	for index := len(lines) - 1; index >= 0; index-- {
		line := strings.TrimSpace(strings.TrimPrefix(lines[index], "\xef\xbb\xbf"))
		for _, word := range problemWords {
			if !strings.Contains(line, word) {
				continue
			}
			if len(line) > 21 && line[4] == '-' && line[19] == ' ' {
				line = strings.TrimSpace(line[19:])
			}
			return shorten(line, 160)
		}
	}
	return ""
}

func shorten(text string, limit int) string {
	if utf8.RuneCountInString(text) <= limit {
		return text
	}
	return string([]rune(text)[:limit]) + "…"
}

// fallbackPlan is what the last dialog offers.
type fallbackPlan struct {
	claude bool   // the link was for Claude: open the tutorial site
	key    string // passed to the command window as USEGOODAI_KEY
}

func fallbackMessage(product, reason, problem, recordPath string, plan fallbackPlan) string {
	text := product + " 的窗口没能打开：" + reason + "。"
	if problem != "" {
		text += "\n\n" + problem
	}
	switch {
	case plan.claude:
		text += "\n\n点「确定」打开教程网站，按教程接入 Claude。"
	case plan.key != "":
		text += "\n\n点「确定」改用命令窗口连接 Codex，网站带来的 Key 会自动填好。"
	default:
		text += "\n\n点「确定」改用命令窗口连接 Codex，按提示粘贴 Key 即可。"
	}
	if recordPath != "" {
		text += "\n\n启动记录：" + recordPath
	}
	return text
}
