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
// file once it grows past the limit. It never fails: without a file it logs
// nothing. Windows cannot rename the file while another running helper
// still has it open; the old file is then kept until a later launch.
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
	return log
}

// captureCrashes writes the Go runtime's crash report to the same file, for
// a crash the window can no longer show.
func (l *startupLog) captureCrashes() {
	if l != nil && l.file != nil {
		_ = debug.SetCrashOutput(l.file, debug.CrashOptions{})
	}
}

func (l *startupLog) printf(format string, arguments ...any) {
	if l == nil || l.file == nil {
		return
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	_, _ = fmt.Fprintf(l.file, "%s pid=%d %s\n", time.Now().Format(time.RFC3339), os.Getpid(), fmt.Sprintf(format, arguments...))
}
