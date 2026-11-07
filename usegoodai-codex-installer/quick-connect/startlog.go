package main

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime/debug"
	"sync"
	"time"
)

// startupLog records how each launch went, so a window that never appears
// leaves something to read. It records events only: never the command
// line, which can carry an import link with a key.
type startupLog struct {
	mu   sync.Mutex
	path string
	file *os.File
}

const (
	startupLogName    = "startup.log"
	startupLogOldName = "startup.old.log"
	startupLogLimit   = 256 * 1024
)

// openStartupLog appends to startup.log in directory, keeping one older
// file once it grows past the limit. A crash report of the Go runtime is
// written to the same file. It never fails: without a file it logs nothing.
func openStartupLog(directory string) *startupLog {
	log := &startupLog{}
	if directory == "" || os.MkdirAll(directory, 0o700) != nil {
		return log
	}
	log.path = filepath.Join(directory, startupLogName)
	if info, err := os.Stat(log.path); err == nil && info.Size() > startupLogLimit {
		_ = os.Rename(log.path, filepath.Join(directory, startupLogOldName))
	}
	file, err := os.OpenFile(log.path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o600)
	if err != nil {
		log.path = ""
		return log
	}
	log.file = file
	_ = debug.SetCrashOutput(file, debug.CrashOptions{})
	return log
}

func (l *startupLog) printf(format string, arguments ...any) {
	if l == nil || l.file == nil {
		return
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	_, _ = fmt.Fprintf(l.file, "%s pid=%d %s\n", time.Now().Format(time.RFC3339), os.Getpid(), fmt.Sprintf(format, arguments...))
}
