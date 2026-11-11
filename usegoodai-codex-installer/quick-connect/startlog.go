package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"sync"
	"time"

	"usegoodai-quick-connect/connect"
)

// Successful launches keep diagnostics in memory. Only a caught error without
// a working terminal creates the fixed fallback file, never next to the EXE.
const maxStartLogBytes = 64 * 1024

var nativeStackLine = regexp.MustCompile(`^\d+: `)
var diagnosticSecrets = regexp.MustCompile(`(?i)sk-[a-z0-9_-]+|usegoodai://[^\s"'<>]+`)

type failureReport struct {
	brief, copyText, path string
	saveErr               error
	terminal              bool
}

type startLog struct {
	mu       sync.Mutex
	lines    []string
	size     int
	path     string
	stage    string
	terminal io.Writer
	reported bool
	popup    func(failureReport)
}

func newStartLog(directory string, terminal io.Writer) *startLog {
	path := ""
	if directory != "" {
		path = filepath.Join(directory, "latest-error.log")
	}
	return &startLog{path: path, terminal: terminal}
}

func scrubDiagnostic(message string) string {
	return diagnosticSecrets.ReplaceAllString(message, "[已隐藏]")
}

func (l *startLog) line(level, message string) {
	if l == nil {
		return
	}
	message = scrubDiagnostic(message)
	if len(message) > maxStartLogBytes/2 {
		message = "[message too long]"
	}
	entry := fmt.Sprintf("%s %s %s\n", time.Now().UTC().Format(time.RFC3339Nano), level, strings.TrimSpace(message))
	l.mu.Lock()
	defer l.mu.Unlock()
	if level == "stage" {
		l.stage = message
	}
	l.lines = append(l.lines, entry)
	l.size += len(entry)
	for l.size > maxStartLogBytes && len(l.lines) > 1 {
		l.size -= len(l.lines[0])
		l.lines = l.lines[1:]
	}
}

func (l *startLog) report(message string) failureReport {
	message = scrubDiagnostic(message)
	l.line("error", message)
	short := strings.Join(strings.Fields(message), " ")
	chars := []rune(short)
	if len(chars) > 180 {
		short = string(chars[:180]) + "…"
	}
	l.mu.Lock()
	stage := l.stage
	stages := map[string]string{"before-wails": "窗口初始化", "startup": "加载界面", "dom-ready": "读取本机配置", "frontend-ready": "运行中", "close-requested": "关闭窗口", "shutdown": "退出", "main-returned": "退出"}
	stage = stages[stage]
	if stage == "" {
		stage = "启动"
	}
	brief := fmt.Sprintf("UseGoodAI 助手 %s 出错（%s）：%s", connect.Version, stage, short)
	var context []string
	for _, entry := range l.lines {
		if strings.Contains(entry, " start ") || strings.Contains(entry, " system ") || strings.Contains(entry, " webview-runtime ") {
			context = append(context, strings.TrimSpace(entry))
		}
	}
	copyText := brief + "\n" + strings.Join(context, "\n")
	details := "UseGoodAI 助手最近一次已捕获错误\n" + copyText + "\n\n" + strings.Join(l.lines, "")
	terminal, reported := l.terminal, l.reported
	l.mu.Unlock()
	r := failureReport{brief: brief, copyText: copyText}
	if terminal != nil {
		if reported {
			r.terminal = true
			return r
		}
		if _, err := fmt.Fprintln(terminal, brief); err == nil {
			l.mu.Lock()
			l.reported = true
			l.mu.Unlock()
			r.terminal = true
			return r
		}
	}
	r.path = l.path
	r.saveErr = saveErrorReport(l.path, details)
	return r
}

func saveErrorReport(path, details string) error {
	if path == "" {
		return fmt.Errorf("应用数据目录不可用")
	}
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0700); err != nil {
		return err
	}
	f, err := os.CreateTemp(dir, ".error-*.tmp")
	if err != nil {
		return err
	}
	name := f.Name()
	defer os.Remove(name)
	if _, err = io.WriteString(f, "\ufeff"+details); err != nil {
		f.Close()
		return err
	}
	if err = f.Sync(); err != nil {
		f.Close()
		return err
	}
	if err = f.Close(); err != nil {
		return err
	}
	return os.Rename(name, path)
}

func (l *startLog) Write(data []byte) (int, error) {
	message := strings.TrimSpace(string(data))
	l.line("native", message)
	// The pinned WebView2 wrapper writes this informational message and stack
	// frames through log.Print. Do not turn those into repeated user errors.
	if strings.Contains(message, "Environment created successfully") || nativeStackLine.MatchString(message) {
		return len(data), nil
	}
	r := l.report(message)
	// Standard-library log.Fatal exits without returning to main. Present its
	// error before it exits, using the same native dialog as our own failures.
	var pcs [16]uintptr
	n := runtime.Callers(2, pcs[:])
	frames := runtime.CallersFrames(pcs[:n])
	for {
		frame, more := frames.Next()
		if strings.HasPrefix(frame.Function, "log.Fatal") || strings.Contains(frame.Function, ").Fatal") {
			if !r.terminal && l.popup != nil {
				l.popup(r)
			}
			break
		}
		if !more {
			break
		}
	}
	return len(data), nil
}

func (l *startLog) Close() {} // There is no open file during normal operation.
