package main

import (
	"os"
	"time"

	"usegoodai-quick-connect/connect"
)

// This entry runs before the window guard: neither WebView2 nor a window is
// needed. PowerShell supplies private stdin/stdout pipes, even for the GUI exe.
func runClaudeCommand(input, output *os.File) int {
	local, _ := os.UserCacheDir()
	roaming, _ := os.UserConfigDir()
	home, _ := os.UserHomeDir()
	service := &connect.Service{
		BaseURL: connect.BaseURL, Client: connect.NewHTTPClient(), Now: time.Now,
		Claude:     connect.ClaudeDesktop{LocalAppData: local},
		ClaudeCLI:  connect.ClaudeCode{Home: home, AppData: roaming},
		StopClaude: connect.StopClaudeDesktop,
	}
	return connect.RunClaudeCommand(input, output, service)
}
