package main

import (
	"bytes"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
)

func TestStartLogNormalLaunchCreatesNoFile(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "logs")
	l := newStartLog(dir, nil)
	l.line("start", "assistant=1.1.9")
	l.line("stage", "frontend-ready")
	_, _ = l.Write([]byte("[WebView2] Environment created successfully\n"))
	l.Close()
	if _, err := os.Stat(dir); !os.IsNotExist(err) {
		t.Fatal("normal launch created diagnostic files")
	}
}

func TestStartLogTerminalIsBriefAndDoesNotCreateLog(t *testing.T) {
	var terminal bytes.Buffer
	dir := filepath.Join(t.TempDir(), "logs")
	l := newStartLog(dir, &terminal)
	l.line("stage", "before-wails")
	r := l.report("创建窗口失败\n0x80004005 sk-fake-secret usegoodai://import?key=sk-hidden")
	l.report("another detail")
	if !r.terminal || r.path != "" || strings.Count(terminal.String(), "\n") != 1 {
		t.Fatal("terminal output was not one brief report")
	}
	if !strings.Contains(terminal.String(), "0x80004005") || strings.Contains(terminal.String(), "sk-fake") || strings.Contains(terminal.String(), "usegoodai://") {
		t.Fatal("wrong terminal report")
	}
	if _, err := os.Stat(dir); !os.IsNotExist(err) {
		t.Fatal("terminal path wrote a log")
	}
}

func TestStartLogFallbackIsFixedRedactedAndReplaced(t *testing.T) {
	dir := t.TempDir()
	l := newStartLog(dir, nil)
	l.line("stage", "before-wails")
	r := l.report("first sk-fake-secret usegoodai://import?key=sk-other&name=private")
	if r.terminal || r.saveErr != nil || r.path != filepath.Join(dir, "latest-error.log") {
		t.Fatalf("wrong fallback: %+v", r)
	}
	data, err := os.ReadFile(r.path)
	if err != nil {
		t.Fatal(err)
	}
	for _, secret := range []string{"sk-fake-secret", "sk-other", "private", "usegoodai://"} {
		if strings.Contains(string(data), secret) || strings.Contains(r.copyText, secret) {
			t.Fatalf("leaked %s", secret)
		}
	}
	next := newStartLog(dir, nil).report("second failure")
	if next.saveErr != nil {
		t.Fatal(next.saveErr)
	}
	data, _ = os.ReadFile(r.path)
	if strings.Contains(string(data), "first") || !strings.Contains(string(data), "second failure") {
		t.Fatal("latest error not replaced")
	}
	entries, _ := os.ReadDir(dir)
	if len(entries) != 1 {
		t.Fatalf("left %d files", len(entries))
	}
}

type failedTerminal struct{}

func (failedTerminal) Write([]byte) (int, error) { return 0, errors.New("terminal closed") }

func TestStartLogFailureToWriteDoesNotLoseBriefError(t *testing.T) {
	dir := t.TempDir()
	l := newStartLog(dir, failedTerminal{})
	r := l.report("terminal disappeared")
	if r.saveErr != nil || r.terminal {
		t.Fatal("no fallback after terminal write failure")
	}
	blocker := filepath.Join(dir, "file")
	os.WriteFile(blocker, nil, 0600)
	r = newStartLog(blocker, nil).report("0x80070005")
	if r.saveErr == nil || !strings.Contains(r.copyText, "0x80070005") {
		t.Fatal("error unavailable when log cannot be saved")
	}
}

func TestStartLogBufferIsBoundedAndConcurrent(t *testing.T) {
	l := newStartLog(t.TempDir(), nil)
	var wg sync.WaitGroup
	for range 8 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for range 30 {
				l.line("stage", strings.Repeat("x", 1000))
			}
		}()
	}
	wg.Wait()
	l.line("stage", "frontend-ready")
	if l.size > maxStartLogBytes {
		t.Fatal("unbounded diagnostics")
	}
	r := l.report("recent failure")
	data, _ := os.ReadFile(r.path)
	if len(data) > maxStartLogBytes+2048 || !strings.Contains(string(data), "recent failure") {
		t.Fatal("wrong bounded error detail")
	}
	var absent *startLog
	absent.line("stage", "unused")
	absent.Close()
}
