package main

import (
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/wailsapp/go-webview2/webviewloader"
	"golang.org/x/sys/windows"
	"usegoodai-quick-connect/connect"
)

func (l *startLog) Print(string)     {}
func (l *startLog) Trace(string)     {}
func (l *startLog) Info(string)      {}
func (l *startLog) Debug(string)     {}
func (l *startLog) Warning(m string) { l.line("warning", m) }
func (l *startLog) Error(m string) {
	// Wails 2.16.0 logs browser-process-exited (kind 0) immediately before
	// displaying its generic popup and os.Exit. Preserve that fatal policy,
	// using our copy/open-log controls instead of the generic popup.
	if strings.HasSuffix(m, "WebVie2wProcess failed with kind 0") {
		l.fail("WebView2 界面进程已退出（browser process exited，kind 0）")
		os.Exit(1)
	}
	l.report(m)
}
func (l *startLog) Fatal(m string) { l.fail(m); os.Exit(1) }
func (l *startLog) fail(m string) {
	r := l.report(m)
	if !r.terminal {
		showFailureReport(r)
	}
}

func (l *startLog) environment(software bool) {
	v := windows.RtlGetVersion()
	l.line("start", "assistant="+connect.Version)
	l.line("system", fmt.Sprintf("Windows %d.%d build %d", v.MajorVersion, v.MinorVersion, v.BuildNumber))
	version, err := webviewloader.GetAvailableCoreWebView2BrowserVersionString("")
	if err != nil {
		l.line("webview-runtime-error", err.Error())
	} else {
		l.line("webview-runtime", version)
	}
	if software {
		l.line("graphics", "software; separate webview profile")
	} else {
		l.line("graphics", "system default; separate webview profile (comparison only)")
	}
}

func softwareWebview(args []string) bool {
	for _, arg := range args {
		if strings.EqualFold(arg, "--system-gpu") {
			return false
		}
	}
	return true
}

// A GUI-subsystem executable may have no standard handles until it attaches
// to its parent's existing terminal. Never allocate a new console on double-click.
func terminalOutput() io.Writer {
	if h, err := windows.GetStdHandle(windows.STD_ERROR_HANDLE); err == nil && h != 0 && h != windows.InvalidHandle {
		kind, e := windows.GetFileType(h)
		if e == nil && (kind == windows.FILE_TYPE_PIPE || kind == windows.FILE_TYPE_DISK) {
			if os.Stderr == nil || os.Stderr.Fd() != uintptr(h) {
				os.Stderr = os.NewFile(uintptr(h), "stderr")
			}
			return os.Stderr
		}
		var mode uint32
		if windows.GetConsoleMode(h, &mode) == nil {
			if os.Stderr == nil || os.Stderr.Fd() != uintptr(h) {
				os.Stderr = os.NewFile(uintptr(h), "stderr")
			}
			return os.Stderr
		}
	}
	attach := windows.NewLazySystemDLL("kernel32.dll").NewProc("AttachConsole")
	attach.Call(uintptr(uint32(0xffffffff)))
	h, err := windows.GetStdHandle(windows.STD_ERROR_HANDLE)
	if err != nil || h == 0 || h == windows.InvalidHandle {
		return nil
	}
	var mode uint32
	if windows.GetConsoleMode(h, &mode) != nil {
		return nil
	}
	if os.Stderr == nil || os.Stderr.Fd() != uintptr(h) {
		os.Stderr = os.NewFile(uintptr(h), "stderr")
	}
	return os.Stderr
}
