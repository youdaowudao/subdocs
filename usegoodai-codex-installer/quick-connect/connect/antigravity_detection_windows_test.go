//go:build windows

package connect

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"golang.org/x/sys/windows/registry"
)

func TestAntigravityWindowsRegisteredCustomDirectory(t *testing.T) {
	bin, marker := fixtureAntigravityApp(t, filepath.Join(t.TempDir(), "中文 App"))
	entry := `Software\Microsoft\Windows\CurrentVersion\Uninstall\UseGoodAI-Antigravity-Test-` + time.Now().Format("20060102150405.000000000")
	key, _, err := registry.CreateKey(registry.CURRENT_USER, entry, registry.SET_VALUE|registry.WOW64_64KEY)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = registry.DeleteKey(registry.CURRENT_USER, entry) })
	if err := key.SetStringValue("DisplayName", "Antigravity"); err != nil {
		key.Close()
		t.Fatal(err)
	}
	if err := key.SetStringValue("InstallLocation", filepath.Dir(bin)); err != nil {
		key.Close()
		t.Fatal(err)
	}
	if err := key.SetStringValue("DisplayIcon", `"`+bin+`",0`); err != nil {
		key.Close()
		t.Fatal(err)
	}
	key.Close()
	var found bool
	for _, candidate := range antigravityWindowsRegisteredPaths() {
		if strings.EqualFold(candidate, bin) {
			found = true
			break
		}
	}
	if !found {
		t.Fatal("custom location in the installer registry was not discovered")
	}
	if got := firstAntigravityApp([]string{bin}); got == "" {
		t.Fatal("registered App rejected")
	}
	if err := os.Remove(marker); err != nil {
		t.Fatal(err)
	}
	if got := firstAntigravityApp([]string{bin}); got != "" {
		t.Fatal("stale registry location should not count as installed")
	}
}

func TestAntigravityRegistryIconPath(t *testing.T) {
	path := `C:\Program Files\Antigravity\Antigravity.exe`
	if got := antigravityRegistryExe(`"` + path + `",0`); got != path {
		t.Fatalf("quoted icon: %q", got)
	}
	if got := antigravityRegistryExe(`C:\Other\IDE.exe`); got != "" {
		t.Fatalf("wrong exe: %q", got)
	}
}
