package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"usegoodai-quick-connect/connect"
)

// Independently inspect real current-user registrations. A temporary
// LOCALAPPDATA is no longer evidence that a desktop application is absent.
func registeredClaudeFamilies(t *testing.T) []string {
	t.Helper()
	output, provided := os.LookupEnv("CLAUDE_TEST_REGISTERED_FAMILIES")
	if !provided {
		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()
		// Get-AppxPackage -Name accepts one name, so query each exact name.
		command := exec.CommandContext(ctx, "powershell.exe", "-NoProfile", "-NonInteractive", "-Command", `$ErrorActionPreference='Stop'; @('Claude','AnthropicPBC.Claude') | ForEach-Object { Get-AppxPackage -Name $_ } | ForEach-Object { $_.PackageFamilyName } | Sort-Object -Unique`)
		data, err := command.CombinedOutput()
		if err != nil {
			t.Fatal(fmt.Errorf("read current-user Claude registrations: %w (context: %v): %s", err, ctx.Err(), data))
		}
		output = string(data)
	}
	var families []string
	for _, family := range strings.Fields(output) {
		if strings.EqualFold(family, "Claude_pzs8sxrjxfjjc") || strings.EqualFold(family, "AnthropicPBC.Claude_fnn82j28hfe8t") {
			families = append(families, family)
		}
	}
	return families
}

// Exercise the real GUI-subsystem release exe without opening its window.
// Native PS 5.1 and PS 7 both download and invoke it through redirected pipes.
func TestClaudePowerShellCommand(t *testing.T) {
	program := os.Getenv("QUICK_CONNECT_EXE")
	if program == "" {
		t.Skip("set QUICK_CONNECT_EXE to test the release program")
	}
	if len(registeredClaudeFamilies(t)) != 0 {
		t.Skip("requires a Windows user with no registered Claude desktop app")
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
			var scriptRequests, programRequests atomic.Int64
			var server *httptest.Server
			server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if r.URL.Path == "/helper.exe" {
					programRequests.Add(1)
					w.Header().Set("Content-Type", "application/octet-stream")
					_, _ = w.Write(data)
					return
				}
				scriptRequests.Add(1)
				w.Header().Set("Content-Type", "text/plain; charset=utf-8")
				_, _ = w.Write([]byte(strings.ReplaceAll(string(source), "https://docs.usegoodai.com/download/usegoodai-quick-connect-windows-x64.exe", server.URL+"/helper.exe")))
			}))
			defer server.Close()
			directory := filepath.Join(t.TempDir(), "中文 用户 空格")
			if err := os.MkdirAll(directory, 0o700); err != nil {
				t.Fatal(err)
			}
			ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
			defer cancel()
			child := exec.CommandContext(ctx, command, "-NoProfile", "-NonInteractive", "-Command", "[Console]::Error.WriteLine('test: PowerShell entered'); [Console]::OutputEncoding = New-Object Text.UTF8Encoding($false); irm $env:TEST_CLAUDE_URL | iex; exit $LASTEXITCODE")
			const key = "sk-test-windows-command-no-real-key"
			child.Env = append(os.Environ(), "LOCALAPPDATA="+directory, "APPDATA="+directory, "USERPROFILE="+directory,
				"TEMP="+directory, "TMP="+directory, "USEGOODAI_KEY="+key, "TEST_CLAUDE_URL="+server.URL+"/claude.ps1",
				"HTTPS_PROXY=http://127.0.0.1:1", "NO_PROXY=127.0.0.1,localhost")
			output, err := child.CombinedOutput()
			t.Logf("script requests=%d, program requests=%d, output bytes=%d, context=%v, exit=%v", scriptRequests.Load(), programRequests.Load(), len(output), ctx.Err(), err)
			if exit, ok := err.(*exec.ExitError); !ok || exit.ExitCode() != 1 {
				t.Fatalf("expected missing Desktop exit 1, got %v: %s", err, output)
			}
			if !bytes.Contains(output, []byte("没检测到 Claude 桌面版")) || bytes.Contains(output, []byte(key)) {
				t.Fatalf("unexpected response: %s", output)
			}
			leftovers, _ := filepath.Glob(filepath.Join(directory, "usegoodai-claude-*"))
			_, guardError := os.Stat(filepath.Join(directory, "UseGoodAI", "QuickConnect", "logs"))
			_, cliError := os.Stat(filepath.Join(directory, ".claude", "settings.json"))
			if len(leftovers) != 0 || !os.IsNotExist(guardError) || !os.IsNotExist(cliError) {
				t.Fatalf("command left downloads, started window guard or touched CLI: %v %v %v", leftovers, guardError, cliError)
			}
		})
	}
}

func TestClaudeReleasePipeProtocol(t *testing.T) {
	program := os.Getenv("QUICK_CONNECT_EXE")
	if program == "" {
		t.Skip("set QUICK_CONNECT_EXE to test the release program")
	}
	if len(registeredClaudeFamilies(t)) != 0 {
		t.Skip("requires a Windows user with no registered Claude desktop app")
	}
	directory := t.TempDir()
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	child := exec.CommandContext(ctx, program, "--claude-connect")
	child.Env = append(os.Environ(), "LOCALAPPDATA="+directory, "APPDATA="+directory, "USERPROFILE="+directory,
		"HTTPS_PROXY=http://127.0.0.1:1", "NO_PROXY=127.0.0.1,localhost")
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
