package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestJudgeInstance(t *testing.T) {
	for _, item := range []struct {
		name  string
		state instanceState
		want  instanceAction
	}{
		{"nothing running", instanceState{}, instanceNone},
		{"only the lock, no process to name", instanceState{running: true}, instanceNone},
		{"healthy window", instanceState{running: true, pid: 7, visible: true, responding: true, age: time.Hour}, instanceUse},
		{"still starting", instanceState{running: true, pid: 7, responding: true, age: 3 * time.Second}, instanceWait},
		{"starting and busy", instanceState{running: true, pid: 7, age: 3 * time.Second}, instanceWait},
		{"no window after the grace period", instanceState{running: true, pid: 7, responding: true, age: time.Minute}, instanceEnd},
		{"visible but hung", instanceState{running: true, pid: 7, visible: true, age: time.Minute}, instanceEnd},
	} {
		if got := judgeInstance(item.state); got != item.want {
			t.Errorf("%s: got %d, want %d", item.name, got, item.want)
		}
	}
	if reason := stuckReason(instanceState{responding: true, age: 95 * time.Second}); reason != "运行 95 秒仍没有窗口" {
		t.Errorf("reason = %q", reason)
	}
	if reason := stuckReason(instanceState{}); reason != "不响应" {
		t.Errorf("reason = %q", reason)
	}
}

func TestJudgeOutcome(t *testing.T) {
	for _, item := range []struct {
		name    string
		attempt int
		outcome windowOutcome
		want    nextStep
	}{
		{"window ready", 1, windowOutcome{ready: true}, stepDone},
		{"link handed to a running window", 1, windowOutcome{exited: true}, stepDone},
		{"window already explained", 1, windowOutcome{exited: true, code: exitShown}, stepQuiet},
		{"silent exit retries", 1, windowOutcome{exited: true, code: 1}, stepRetry},
		{"WebView2 crash dialog retries", 1, windowOutcome{exited: true, code: 0xFFFFFFFF}, stepRetry},
		{"no window in time retries", 1, windowOutcome{timedOut: true}, stepRetry},
		{"second failure gives up", 2, windowOutcome{exited: true, code: 2}, stepGiveUp},
		{"second timeout gives up", 2, windowOutcome{timedOut: true}, stepGiveUp},
		{"second attempt ready", 2, windowOutcome{ready: true}, stepDone},
	} {
		if got := judgeOutcome(item.attempt, item.outcome); got != item.want {
			t.Errorf("%s: got %d, want %d", item.name, got, item.want)
		}
	}
	if reason := outcomeReason(windowOutcome{timedOut: true}); reason != "60 秒内窗口没有打开" {
		t.Errorf("reason = %q", reason)
	}
	if reason := outcomeReason(windowOutcome{exited: true, code: 0xFFFFFFFF}); reason != "窗口程序意外退出（代码 -1）" {
		t.Errorf("reason = %q", reason)
	}
}

func TestProfileIsRememberedOnlyWhenValid(t *testing.T) {
	base := t.TempDir()
	if folder, name := savedProfile(base); folder != base || name != "" {
		t.Fatalf("no saved profile: got %q %q", folder, name)
	}
	folder, name := freshProfile(base, time.Date(2026, 11, 13, 14, 5, 9, 0, time.UTC))
	if name != "WebView2-20261113-140509" || folder != filepath.Join(base, name) {
		t.Fatalf("fresh profile %q %q", folder, name)
	}
	rememberProfile(base, name)
	if got, gotName := savedProfile(base); got != folder || gotName != name {
		t.Fatalf("saved profile %q %q", got, gotName)
	}
	for _, bad := range []string{"..", `WebView2-1\..\..`, "WebView2-../x", "other", ""} {
		if err := os.WriteFile(filepath.Join(base, safeStartFile), []byte(bad), 0o644); err != nil {
			t.Fatal(err)
		}
		if got, _ := savedProfile(base); got != base {
			t.Errorf("%q escaped to %q", bad, got)
		}
	}
}

func TestFallbackMessage(t *testing.T) {
	text := fallbackMessage("助手", `C:\r.txt`, fallbackPlan{key: "sk-x"})
	for _, want := range []string{"助手 的窗口打不开", "WebView2 组件出错", "已经自动重试过一次", "命令窗口连接 Codex", "Key 会自动填好", `出错记录：C:\r.txt`} {
		if !strings.Contains(text, want) {
			t.Errorf("missing %q in\n%s", want, text)
		}
	}
	if strings.Contains(text, "sk-x") {
		t.Fatal("the key must not appear in the dialog")
	}
	if text := fallbackMessage("助手", "", fallbackPlan{}); !strings.Contains(text, "按提示粘贴 Key") || strings.Contains(text, "出错记录") {
		t.Errorf("plain fallback:\n%s", text)
	}
	if text := fallbackMessage("助手", "", fallbackPlan{claude: true}); !strings.Contains(text, "教程网站") || strings.Contains(text, "Codex") {
		t.Errorf("Claude fallback:\n%s", text)
	}
}
