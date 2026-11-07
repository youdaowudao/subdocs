package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestStartupLogRotatesAndNeverFails(t *testing.T) {
	directory := filepath.Join(t.TempDir(), "UseGoodAI", "QuickConnect")
	log := openStartupLog(directory)
	log.printf("启动 %s", "1.1.4")
	if err := log.file.Close(); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(directory, startupLogName))
	if err != nil || !strings.Contains(string(data), "启动 1.1.4") || !strings.Contains(string(data), "pid=") {
		t.Fatalf("log not written: %v %q", err, data)
	}

	big := strings.Repeat("x", startupLogLimit+1)
	if err := os.WriteFile(filepath.Join(directory, startupLogName), []byte(big), 0o600); err != nil {
		t.Fatal(err)
	}
	log = openStartupLog(directory)
	log.printf("第二次")
	_ = log.file.Close()
	if old, err := os.ReadFile(filepath.Join(directory, startupLogOldName)); err != nil || len(old) != len(big) {
		t.Fatalf("old log not kept: %v %d", err, len(old))
	}
	if fresh, _ := os.ReadFile(filepath.Join(directory, startupLogName)); !strings.Contains(string(fresh), "第二次") || len(fresh) > 200 {
		t.Fatalf("new log not started: %q", fresh)
	}

	var missing *startupLog
	missing.printf("没有日志也不出错")
	openStartupLog("").printf("没有目录也不出错")
}
