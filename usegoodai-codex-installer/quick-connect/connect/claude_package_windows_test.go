//go:build windows

package connect

import (
	"context"
	"os/exec"
	"strings"
	"testing"
	"time"

	"golang.org/x/sys/windows"
)

func TestClaudeNativeRegistration(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	output, err := exec.CommandContext(ctx, "powershell.exe", "-NoProfile", "-NonInteractive", "-Command", `$ErrorActionPreference='Stop'; @('Claude','AnthropicPBC.Claude') | ForEach-Object { Get-AppxPackage -Name $_ } | ForEach-Object { $_.PackageFamilyName }`).Output()
	if err != nil {
		t.Fatal(err)
	}
	for _, family := range claudePackageFamilies {
		want := false
		for _, actual := range strings.Fields(string(output)) {
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
