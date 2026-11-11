package main

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime/debug"
	"strings"
	"sync"
	"time"
)

// 启动记录：部分 Windows 11 电脑双击后助手一闪就退出，原因一直抓不到。
// 每次启动在 %LOCALAPPDATA%\UseGoodAI\QuickConnect\logs\启动记录.txt
// 写几行：走到了哪一步、是否已有实例在运行；Go 崩溃的报错也追加到这里。
// 打开后看最后一行即可：
//   - 没有这个文件：程序没能启动，多半被 Windows（智能应用控制、杀毒软件）拦下。
//   - 停在某一步：就是在那一步退出的。
//   - 有“已有实例”：之前打开的助手还在运行，本次把参数交给它后退出。
// 不记录启动参数（导入链接里带着 Key）。

const startRecordName = "启动记录.txt"

type startRecord struct {
	mu   sync.Mutex
	file *os.File
	path string
}

// openStartRecord starts a new record, or appends when another instance is
// running so the record of the instance that got stuck stays readable.
func openStartRecord(directory string, appendOnly bool) *startRecord {
	if directory == "" || os.MkdirAll(directory, 0o755) != nil {
		return &startRecord{}
	}
	path := filepath.Join(directory, startRecordName)
	flags := os.O_CREATE | os.O_WRONLY | os.O_TRUNC
	if appendOnly {
		flags = os.O_CREATE | os.O_WRONLY | os.O_APPEND
	}
	file, err := os.OpenFile(path, flags, 0o644)
	if err != nil {
		return &startRecord{}
	}
	if !appendOnly {
		_, _ = file.WriteString("\xef\xbb\xbf") // Notepad reads the Chinese text as UTF-8
	}
	return &startRecord{file: file, path: path}
}

func (r *startRecord) stage(name, detail string) {
	if r == nil || r.file == nil {
		return
	}
	line := time.Now().Format("2006-01-02 15:04:05") + "  " + name
	if detail = strings.Join(strings.Fields(detail), " "); detail != "" {
		line += "  " + detail
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	_, _ = r.file.WriteString(line + "\r\n")
}

// Write receives the standard log package output (Wails reports some
// failures there) as one record line each.
func (r *startRecord) Write(data []byte) (int, error) {
	r.stage("日志", string(data))
	return len(data), nil
}

// crashOutput makes Go write a crash, in any goroutine, to the record too.
func (r *startRecord) crashOutput() {
	if r != nil && r.file != nil {
		_ = debug.SetCrashOutput(r.file, debug.CrashOptions{})
	}
}

func (r *startRecord) close() {
	if r != nil && r.file != nil {
		_ = r.file.Close()
	}
}

// recordLogger is the Wails logger: only errors are kept, in the record.
type recordLogger struct{ record *startRecord }

func (l recordLogger) Print(string)   {}
func (l recordLogger) Trace(string)   {}
func (l recordLogger) Debug(string)   {}
func (l recordLogger) Info(string)    {}
func (l recordLogger) Warning(string) {}
func (l recordLogger) Error(message string) {
	l.record.stage("错误", message)
}
func (l recordLogger) Fatal(message string) {
	l.record.stage("致命错误", message)
	os.Exit(1)
}

func yesNo(value bool) string {
	if value {
		return "是"
	}
	return "否"
}

func startSummary(version, system string, pid int, withLink bool) string {
	return fmt.Sprintf("版本 %s，%s，进程 %d，带导入链接：%s", version, system, pid, yesNo(withLink))
}
