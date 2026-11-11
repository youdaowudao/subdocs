package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
)

func TestStartLogRedactsAndFlushesBeforeClose(t *testing.T) {
	l, err := openStartLog(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	l.line("error", `failed sk-fake-secret usegoodai://import?key=sk-other&name=private`)
	_, _ = l.Write([]byte(`fatal: SK-OTHER_SECRET`))
	data, err := os.ReadFile(l.path) // Must survive os.Exit without Close.
	if err != nil {
		t.Fatal(err)
	}
	for _, secret := range []string{"sk-fake-secret", "sk-other", "private", "SK-OTHER_SECRET", "usegoodai://"} {
		if strings.Contains(string(data), secret) {
			t.Fatalf("log leaked %q", secret)
		}
	}
	if !strings.Contains(string(data), "fatal:") {
		t.Fatal("missing native log")
	}
}

func TestStartLogBoundAndConcurrentWrites(t *testing.T) {
	l, err := openStartLog(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	var wg sync.WaitGroup
	for range 8 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for range 10 {
				l.line("stage", "alive")
			}
		}()
	}
	wg.Wait()
	l.line("error", strings.Repeat("x", maxStartLogBytes))
	l.line("stage", "past-limit")
	l.Close()
	l.Close()
	l.line("stage", "after-close")
	data, err := os.ReadFile(l.path)
	if err != nil {
		t.Fatal(err)
	}
	if len(data) > maxStartLogBytes || strings.Contains(string(data), "past-limit") {
		t.Fatal("unbounded log")
	}
	if strings.Count(string(data), "stage alive") != 80 {
		t.Fatal("lost concurrent events")
	}
}

func TestStartLogRetentionAndWriteFailure(t *testing.T) {
	dir := t.TempDir()
	for i := range 25 {
		if err := os.WriteFile(filepath.Join(dir, fmt.Sprintf("startup-%03d.log", i)), nil, 0600); err != nil {
			t.Fatal(err)
		}
	}
	other := filepath.Join(dir, "keep.txt")
	if err := os.WriteFile(other, []byte("keep"), 0600); err != nil {
		t.Fatal(err)
	}
	l, err := openStartLog(dir)
	if err != nil {
		t.Fatal(err)
	}
	l.Close()
	entries, _ := filepath.Glob(filepath.Join(dir, "startup-*.log"))
	if len(entries) != 20 {
		t.Fatalf("got %d logs", len(entries))
	}
	if _, err := os.Stat(other); err != nil {
		t.Fatal("removed unrelated file")
	}
	if _, err := openStartLog(other); err == nil {
		t.Fatal("accepted a file as directory")
	}
	var absent *startLog
	absent.line("stage", "unused")
	absent.Close()
}
