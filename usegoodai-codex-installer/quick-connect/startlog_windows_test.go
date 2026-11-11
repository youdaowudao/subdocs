package main

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestSoftwareWebview(t *testing.T) {
	if !softwareWebview(nil) || !softwareWebview([]string{"usegoodai://import?key=sk-fake"}) {
		t.Fatal("candidate must default to software rendering")
	}
	if softwareWebview([]string{"--system-gpu"}) {
		t.Fatal("comparison option not applied")
	}
}

// Run only from the native UI driver. It exercises the production dialog code
// with a simulated failure and isolated data, without adding a fault flag to
// the delivered EXE or using a real key.
func TestNativeErrorDialog(t *testing.T) {
	if os.Getenv("USEGOODAI_ERROR_UI_TEST") != "1" {
		t.Skip("native dialog driver only")
	}
	root := os.Getenv("USEGOODAI_ERROR_UI_ROOT")
	l := newStartLog(filepath.Join(root, "UseGoodAI", "QuickConnect", "logs"), nil)
	l.environment(true)
	l.line("stage", "before-wails")
	l.fail("窗口初始化失败（模拟错误 0x80004005，sk-ui-fake-secret）")
}

func TestNativeTerminalDetection(t *testing.T) {
	if os.Getenv("USEGOODAI_TERMINAL_TEST_CHILD") == "1" {
		writer := terminalOutput()
		if writer == nil {
			t.Fatal("redirected terminal not detected")
		}
		l := newStartLog(os.Getenv("USEGOODAI_TERMINAL_TEST_DIR"), writer)
		l.line("stage", "before-wails")
		if !l.report("模拟错误 0x80004005 sk-terminal-fake").terminal {
			t.Fatal("terminal report failed")
		}
		return
	}
	dir := filepath.Join(t.TempDir(), "no-log")
	cmd := exec.Command(os.Args[0], "-test.run=^TestNativeTerminalDetection$")
	cmd.Env = append(os.Environ(), "USEGOODAI_TERMINAL_TEST_CHILD=1", "USEGOODAI_TERMINAL_TEST_DIR="+dir)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		t.Fatalf("%v: %s", err, stderr.String())
	}
	if !strings.Contains(stderr.String(), "0x80004005") || strings.Contains(stderr.String(), "sk-terminal") {
		t.Fatal("bad native terminal report")
	}
	if _, err := os.Stat(dir); !os.IsNotExist(err) {
		t.Fatal("native terminal reporting created a log")
	}
}
