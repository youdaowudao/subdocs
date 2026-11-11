package main

import (
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func readRecord(t *testing.T, directory string) string {
	t.Helper()
	data, err := os.ReadFile(filepath.Join(directory, startRecordName))
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}

func TestStartRecordKeepsAShortLineForEveryStage(t *testing.T) {
	directory := filepath.Join(t.TempDir(), "logs")
	record := openStartRecord(directory, false)
	record.stage("启动", startSummary("1.1.12", "Windows 10.0.26200", 42, true))
	record.stage("创建窗口", "")
	recordLogger{record: record}.Error("WebView2 创建失败\n  第二行")
	log.New(record, "", 0).Print("Wails 内部日志")
	record.close()

	text := readRecord(t, directory)
	if !strings.HasPrefix(text, "\xef\xbb\xbf") {
		t.Fatal("record is not marked UTF-8 for Notepad")
	}
	lines := strings.Split(strings.TrimSpace(strings.TrimPrefix(text, "\xef\xbb\xbf")), "\r\n")
	if len(lines) != 4 {
		t.Fatalf("want 4 lines, got %d:\n%s", len(lines), text)
	}
	for index, want := range []string{
		"启动  版本 1.1.12，Windows 10.0.26200，进程 42，带导入链接：是",
		"创建窗口",
		"错误  WebView2 创建失败 第二行",
		"日志  Wails 内部日志",
	} {
		if !strings.HasSuffix(lines[index], want) {
			t.Errorf("line %d = %q, want suffix %q", index, lines[index], want)
		}
	}
}

// A later launch while one is running appends, so the record of the stuck
// instance stays; a new launch on its own starts the record over.
func TestStartRecordAppendsOnlyWhenAnotherInstanceRuns(t *testing.T) {
	directory := t.TempDir()
	first := openStartRecord(directory, false)
	first.stage("启动", "第一次")
	first.stage("创建窗口", "")
	first.close()

	second := openStartRecord(directory, true)
	second.stage("已有实例", "进程 7，窗口看不到；本次把参数交给它后退出")
	second.close()
	if text := readRecord(t, directory); !strings.Contains(text, "第一次") || !strings.Contains(text, "已有实例") {
		t.Fatalf("appending lost the first instance:\n%s", text)
	}

	fresh := openStartRecord(directory, false)
	fresh.stage("启动", "第三次")
	fresh.close()
	if text := readRecord(t, directory); strings.Contains(text, "第一次") || !strings.Contains(text, "第三次") {
		t.Fatalf("a new launch did not start over:\n%s", text)
	}
}

func TestStartRecordWithoutFolderDoesNothing(t *testing.T) {
	record := openStartRecord("", false)
	record.stage("启动", "x")
	record.crashOutput()
	record.close()
	var missing *startRecord
	missing.stage("启动", "x")
}

// TestStartRecordKeepsGoCrashes runs a child that crashes after
// crashOutput, the way an unrecovered panic in any goroutine ends the
// assistant, and checks the crash lands in the record.
func TestStartRecordKeepsGoCrashes(t *testing.T) {
	if directory := os.Getenv("START_RECORD_CRASH_DIR"); directory != "" {
		record := openStartRecord(directory, false)
		record.crashOutput()
		record.stage("窗口已建立", "")
		done := make(chan struct{})
		go func() {
			defer close(done)
			panic("测试用崩溃")
		}()
		<-done
		return
	}
	directory := t.TempDir()
	child := exec.Command(os.Args[0], "-test.run=^TestStartRecordKeepsGoCrashes$")
	child.Env = append(os.Environ(), "START_RECORD_CRASH_DIR="+directory)
	if err := child.Run(); err == nil {
		t.Fatal("the crashing child exited normally")
	}
	text := readRecord(t, directory)
	if !strings.Contains(text, "窗口已建立") || !strings.Contains(text, "panic: 测试用崩溃") {
		t.Fatalf("crash missing from the record:\n%s", text)
	}
}
