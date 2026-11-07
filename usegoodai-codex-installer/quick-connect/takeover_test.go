package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestNextTakeoverStep(t *testing.T) {
	cases := []struct {
		answered bool
		reply    uintptr
		want     takeoverStep
	}{
		{false, 0, endUnresponsive},
		{false, replyBusy, endUnresponsive},
		{true, replyBusy, keepRunningWindow},
		{true, replyQuitting, waitForClose},
		{true, 0, closeOlderHelper},
		{true, 7, closeOlderHelper},
	}
	for _, c := range cases {
		if got := nextTakeoverStep(c.answered, c.reply); got != c.want {
			t.Errorf("nextTakeoverStep(%v, %#x) = %v, want %v", c.answered, c.reply, got, c.want)
		}
	}
}

func TestActivityIsBusyOnlyWhileAnOperationRuns(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	work := &activity{now: func() time.Time { return now }}
	if work.busy() {
		t.Fatal("idle window reported busy")
	}
	endFirst := work.begin()
	endSecond := work.begin()
	if !work.busy() {
		t.Fatal("running operation not reported")
	}
	endFirst()
	endFirst() // ending twice must not end the other operation
	if !work.busy() {
		t.Fatal("second operation lost")
	}
	endSecond()
	if work.busy() {
		t.Fatal("finished operations still busy")
	}

	end := work.begin()
	now = now.Add(staleOperation - time.Second)
	if !work.busy() {
		t.Fatal("operation within its time not busy")
	}
	now = now.Add(2 * time.Second)
	if work.busy() {
		t.Fatal("a hung operation keeps blocking new windows")
	}
	end()
}

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
