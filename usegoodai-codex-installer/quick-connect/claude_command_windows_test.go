package main

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"usegoodai-quick-connect/connect"
)

// Exercise the real GUI-subsystem release exe without opening its window.
// Native PS 5.1 and PS 7 both download and invoke it through redirected pipes.
func TestClaudePowerShellCommand(t *testing.T) {
	program := os.Getenv("QUICK_CONNECT_EXE")
	if program == "" {
		t.Skip("set QUICK_CONNECT_EXE to test the release program")
	}
	data, err := os.ReadFile(program)
	if err != nil {
		t.Fatal(err)
	}
	source, err := os.ReadFile(filepath.Join("..", "install", "claude.ps1"))
	if err != nil {
		t.Fatal(err)
	}
	for _, shell := range []string{"powershell.exe", "pwsh.exe"} {
		t.Run(shell, func(t *testing.T) {
			command, err := exec.LookPath(shell)
			if err != nil {
				t.Skip("shell unavailable")
			}
			var server *httptest.Server
			server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if r.URL.Path == "/helper.exe" {
					w.Header().Set("Content-Type", "application/octet-stream")
					_, _ = w.Write(data)
					return
				}
				w.Header().Set("Content-Type", "text/plain; charset=utf-8")
				_, _ = w.Write([]byte(strings.ReplaceAll(string(source), "https://docs.usegoodai.com/download/usegoodai-quick-connect-windows-x64.exe", server.URL+"/helper.exe")))
			}))
			defer server.Close()
			directory := filepath.Join(t.TempDir(), "中文 用户 空格")
			if err := os.MkdirAll(directory, 0o700); err != nil {
				t.Fatal(err)
			}
			ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
			defer cancel()
			child := exec.CommandContext(ctx, command, "-NoProfile", "-NonInteractive", "-Command", "[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false); irm $env:TEST_CLAUDE_URL | iex; exit $LASTEXITCODE")
			const key = "sk-test-windows-command-no-real-key"
			child.Env = append(os.Environ(), "LOCALAPPDATA="+directory, "APPDATA="+directory, "USERPROFILE="+directory,
				"TEMP="+directory, "TMP="+directory, "USEGOODAI_KEY="+key, "TEST_CLAUDE_URL="+server.URL+"/claude.ps1")
			output, err := child.CombinedOutput()
			if exit, ok := err.(*exec.ExitError); !ok || exit.ExitCode() != 1 {
				t.Fatalf("expected missing Desktop exit 1, got %v: %s", err, output)
			}
			if !bytes.Contains(output, []byte("没检测到 Claude 桌面版")) || bytes.Contains(output, []byte(key)) {
				t.Fatalf("unexpected response: %s", output)
			}
			entries, err := os.ReadDir(directory)
			if err != nil || len(entries) != 0 {
				t.Fatalf("command left files or started window guard: %v %v", entries, err)
			}
		})
	}
}

func TestClaudeReleasePipeProtocol(t *testing.T) {
	program := os.Getenv("QUICK_CONNECT_EXE")
	if program == "" {
		t.Skip("set QUICK_CONNECT_EXE to test the release program")
	}
	directory := t.TempDir()
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	child := exec.CommandContext(ctx, program, "--claude-connect")
	child.Env = append(os.Environ(), "LOCALAPPDATA="+directory, "APPDATA="+directory, "USERPROFILE="+directory)
	child.Stdin = strings.NewReader(`{"key":"sk-fake-command-key"}`)
	output, err := child.Output()
	if exit, ok := err.(*exec.ExitError); !ok || exit.ExitCode() != 1 {
		t.Fatalf("exit %v: %s", err, output)
	}
	var reply struct{ Version, Tone, Message string }
	if err := json.Unmarshal(output, &reply); err != nil || reply.Version != connect.Version || reply.Tone != "error" {
		t.Fatalf("invalid reply %v: %s", err, output)
	}
	if !strings.Contains(reply.Message, "没检测到 Claude 桌面版") {
		t.Fatal(reply.Message)
	}
}
