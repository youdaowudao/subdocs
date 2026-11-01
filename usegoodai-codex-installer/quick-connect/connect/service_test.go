package connect

import (
	"context"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"
	"time"
)

func newTestService(t *testing.T, status int, body string, stop StopResult) (*Service, *int) {
	t.Helper()
	stops := 0
	usage := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(status)
		_, _ = w.Write([]byte(body))
	}))
	t.Cleanup(usage.Close)
	return &Service{
		CodexHome: filepath.Join(t.TempDir(), ".codex"),
		BaseURL:   usage.URL,
		Client:    NewHTTPClient(),
		Now:       func() time.Time { return fixedTime },
		StopClients: func() StopResult {
			stops++
			return stop
		},
	}, &stops
}

func TestConnectMessages(t *testing.T) {
	running := StopResult{Codex: true}
	stuck := StopResult{Codex: true, Left: true}
	cases := []struct {
		name    string
		status  int
		body    string
		stop    StopResult
		key     string
		tone    string
		message string
		written bool
	}{
		{"success, Codex closed", 200, `{"isValid":true,"remaining":12.345}`, running, fixtureKey, ToneSuccess,
			"已连接 UseGoodAI ✓ 余额 $12.35。Codex 已关闭，重新打开即可，新建任务，发送“测试”。", true},
		{"success, Codex not running", 200, `{"isValid":true,"remaining":7}`, StopResult{}, " " + fixtureKey + "\n", ToneSuccess,
			"已连接 UseGoodAI ✓ 余额 $7.00。打开 Codex，新建任务，发送“测试”。", true},
		{"success without balance", 200, `{"isValid":true,"planName":"Pro"}`, StopResult{}, fixtureKey, ToneSuccess,
			"已连接 UseGoodAI ✓。打开 Codex，新建任务，发送“测试”。", true},
		{"zero balance", 200, `{"isValid":true,"remaining":0}`, StopResult{}, fixtureKey, ToneWarning, MessageNoBalance, true},
		{"zero balance, Codex closed", 200, `{"isValid":true,"remaining":0}`, running, fixtureKey, ToneWarning, MessageNoBalance + MessageClosed, true},
		{"zero balance, Codex stuck", 200, `{"isValid":true,"remaining":-1}`, stuck, fixtureKey, ToneWarning, MessageNoBalance + MessageNotClosed, true},
		{"Codex could not be closed", 200, `{"isValid":true,"remaining":3}`, stuck, fixtureKey, ToneWarning, MessageCloseFailed, true},
		{"rejected 401", 401, `{}`, running, fixtureKey, ToneError, MessageRejected, false},
		{"rejected 403", 403, `{}`, running, fixtureKey, ToneError, MessageRejected, false},
		{"disabled", 200, `{"isValid":false}`, running, fixtureKey, ToneError, MessageDisabled, false},
		{"server error", 503, `{}`, running, fixtureKey, ToneError, MessageUnreachable, false},
		{"bad format", 200, `{"isValid":true}`, running, "pk-abc", ToneError, MessageBadFormat, false},
		{"empty", 200, `{"isValid":true}`, running, "  ", ToneError, MessageEmptyKey, false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			service, stops := newTestService(t, c.status, c.body, c.stop)
			result := service.Connect(context.Background(), c.key)
			if result.Tone != c.tone || result.Message != c.message {
				t.Fatalf("got %s %q\nwant %s %q", result.Tone, result.Message, c.tone, c.message)
			}
			if c.written {
				if *stops != 1 || result.Status.State != StateUseGoodAI || result.Status.Key != MaskKey(fixtureKey) {
					t.Fatalf("after writing: stops %d, status %+v", *stops, result.Status)
				}
			} else {
				if *stops != 0 || result.Status.State != StateNone {
					t.Fatalf("nothing may change: stops %d, status %+v", *stops, result.Status)
				}
				assertOnlyFiles(t, service.CodexHome)
			}
		})
	}
}

func TestConnectKeepsOldConfigWhenWriteFails(t *testing.T) {
	service, stops := newTestService(t, 200, `{"isValid":true,"remaining":1}`, StopResult{Codex: true})
	writeFile(t, filepath.Join(service.CodexHome, "config.toml"), "official config")
	renameFile = func(string, string) error { return &osPathError }
	defer func() { renameFile = defaultRename }()
	result := service.Connect(context.Background(), fixtureKey)
	if result.Tone != ToneError || result.Message != "写入 Codex 配置失败：拒绝访问。原配置没有改动，可以重试。" {
		t.Fatalf("got %q", result.Message)
	}
	if *stops != 0 || readFile(t, filepath.Join(service.CodexHome, "config.toml")) != "official config" {
		t.Fatal("a failed write must keep the config and leave Codex running")
	}
}

func TestParseLinkMessages(t *testing.T) {
	service, _ := newTestService(t, 200, `{}`, StopResult{})
	for link, want := range map[string]string{
		"usegoodai://import?v=1&app=codex":                                          MessageLinkIncomplete,
		"usegoodai://import?v=2&app=codex&key=" + fixtureKey:                        MessageLinkUnsupported,
		"usegoodai://import?v=1&app=gemini&key=" + fixtureKey:                       MessageLinkUnsupported,
		"usegoodai://import?v=1&app=codex&key=" + fixtureKey + "&base_url=http://x": MessageLinkIncomplete,
	} {
		result := service.ParseLink(link)
		if result.OK || result.Result.Message != want || result.Result.Tone != ToneError {
			t.Fatalf("%s: %+v", link, result)
		}
	}
	ok := service.ParseLink("usegoodai://import/?v=1&app=codex&key=" + fixtureKey + "&name=%E5%B7%A5%E4%BD%9C")
	if !ok.OK || ok.Key != fixtureKey || ok.Name != "工作" {
		t.Fatalf("%+v", ok)
	}
}

func TestRestoreMessages(t *testing.T) {
	service, stops := newTestService(t, 200, `{"isValid":true,"remaining":1}`, StopResult{ChatGPT: true})
	if result := service.Connect(context.Background(), fixtureKey); result.Tone != ToneSuccess {
		t.Fatal(result.Message)
	}
	result := service.Restore()
	if result.Tone != ToneSuccess || result.Message != MessageRestored || result.Status.State != StateNone || *stops != 2 {
		t.Fatalf("%+v stops %d", result, *stops)
	}

	stuck, _ := newTestService(t, 200, `{}`, StopResult{Codex: true, Left: true})
	if result := stuck.Restore(); result.Tone != ToneWarning || result.Message != MessageRestoredOpen {
		t.Fatalf("%+v", result)
	}

	broken, brokenStops := newTestService(t, 200, `{}`, StopResult{})
	writeFile(t, filepath.Join(broken.CodexHome, "config.toml"), "model = \"x\"\n")
	writeFile(t, filepath.Join(broken.CodexHome, "auth.json"), "{}")
	renameFile = func(string, string) error { return &osPathError }
	result = broken.Restore()
	renameFile = defaultRename
	if result.Tone != ToneError || result.Message != "恢复官方登录失败：拒绝访问。原配置没有改动，可以重试。" || *brokenStops != 0 {
		t.Fatalf("%+v", result)
	}
}

func TestFormatUSD(t *testing.T) {
	for amount, want := range map[float64]string{0: "$0.00", 2: "$2.00", 12.345: "$12.35", 0.004: "$0.00", 1234.5: "$1234.50"} {
		if got := FormatUSD(amount); got != want {
			t.Errorf("FormatUSD(%v) = %q, want %q", amount, got, want)
		}
	}
}
