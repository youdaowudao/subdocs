//go:build windows

package connect

import (
	"context"
	"os"
	"os/exec"
	"strings"
	"testing"
	"time"

	"golang.org/x/sys/windows"
)

func TestClaudeNativeRegistration(t *testing.T) {
	output, provided := os.LookupEnv("CLAUDE_TEST_REGISTERED_FAMILIES")
	if !provided {
		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()
		data, err := exec.CommandContext(ctx, "powershell.exe", "-NoProfile", "-NonInteractive", "-Command", `$ErrorActionPreference='Stop'; @('Claude','AnthropicPBC.Claude') | ForEach-Object { Get-AppxPackage -Name $_ } | ForEach-Object { $_.PackageFamilyName }`).CombinedOutput()
		if err != nil {
			t.Fatalf("registration reference query: %v (context: %v): %s", err, ctx.Err(), data)
		}
		output = string(data)
	}
	for _, family := range claudePackageFamilies {
		want := false
		for _, actual := range strings.Fields(output) {
			want = want || strings.EqualFold(family, actual)
		}
		start := time.Now()
		got, err := registeredClaudePackage(family)
		t.Logf("%s registered=%t lookup=%s", family, got, time.Since(start))
		if err != nil || got != want {
			t.Fatalf("registration %s: got %t, want %t, error %v", family, got, want, err)
		}
	}
}

func TestClaudeNativeProcessWithoutPackage(t *testing.T) {
	// This test executable has no MSIX identity, just like a standalone CLI.
	if desktop, err := claudeDesktopProcess(windows.CurrentProcess()); err != nil || desktop {
		t.Fatalf("unpackaged process: desktop=%t, err=%v", desktop, err)
	}
}
