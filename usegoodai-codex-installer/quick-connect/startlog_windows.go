package main

import (
	"fmt"
	"os"
	"strings"

	"github.com/wailsapp/go-webview2/webviewloader"
	"golang.org/x/sys/windows"

	"usegoodai-quick-connect/connect"
)

// Verbose Wails logs can contain complete bridge calls. Keep errors only.
func (l *startLog) Print(string)     {}
func (l *startLog) Trace(string)     {}
func (l *startLog) Info(string)      {}
func (l *startLog) Debug(string)     {}
func (l *startLog) Warning(m string) { l.line("warning", m) }
func (l *startLog) Error(m string)   { l.line("error", m) }
func (l *startLog) Fatal(m string) {
	l.line("fatal", m)
	showError("助手启动或运行失败。\n\n启动日志：" + l.path)
	os.Exit(1)
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

// The flag is for native comparison tests; customers need no system changes.
func softwareWebview(args []string) bool {
	for _, arg := range args {
		if strings.EqualFold(arg, "--system-gpu") {
			return false
		}
	}
	return true
}
