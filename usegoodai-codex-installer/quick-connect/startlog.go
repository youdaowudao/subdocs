package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"
)

// Never log bridge arguments, clipboard contents, environment variables or
// configuration file contents. Keep diagnostics separate from configuration.
const maxStartLogBytes = 256 * 1024

var diagnosticSecrets = regexp.MustCompile(`(?i)sk-[a-z0-9_-]+|usegoodai://[^\s"'<>]+`)

type startLog struct {
	mu   sync.Mutex
	file *os.File
	size int
	path string
}

func openStartLog(directory string) (*startLog, error) {
	if err := os.MkdirAll(directory, 0700); err != nil {
		return nil, err
	}
	entries, _ := filepath.Glob(filepath.Join(directory, "startup-*.log"))
	sort.Strings(entries)
	for len(entries) >= 20 {
		_ = os.Remove(entries[0]) // Open logs may be locked by another instance.
		entries = entries[1:]
	}
	path := filepath.Join(directory, fmt.Sprintf("startup-%s-%d.log", time.Now().UTC().Format("20060102-150405.000000000"), os.Getpid()))
	file, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return nil, err
	}
	return &startLog{file: file, path: path}, nil
}

func (l *startLog) Write(data []byte) (int, error) {
	l.line("native", string(data))
	return len(data), nil
}

func (l *startLog) line(level, message string) {
	if l == nil {
		return
	}
	message = diagnosticSecrets.ReplaceAllString(message, "[已隐藏]")
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.file == nil || l.size >= maxStartLogBytes {
		return
	}
	entry := fmt.Sprintf("%s %s %s\n", time.Now().UTC().Format(time.RFC3339Nano), level, strings.TrimSpace(message))
	if len(entry) > maxStartLogBytes-l.size {
		// Keep this ASCII so truncating it cannot split a UTF-8 character.
		entry = "[log limit reached]\n"
		if remaining := maxStartLogBytes - l.size; len(entry) > remaining {
			entry = entry[:remaining]
		}
		_, _ = io.WriteString(l.file, entry)
		l.size = maxStartLogBytes
		_ = l.file.Sync()
		return
	}
	n, _ := io.WriteString(l.file, entry)
	l.size += n
	_ = l.file.Sync() // WebView2/Wails os.Exit does not run deferred calls.
}

func (l *startLog) Close() {
	if l == nil {
		return
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.file != nil {
		_ = l.file.Close()
		l.file = nil
	}
}
