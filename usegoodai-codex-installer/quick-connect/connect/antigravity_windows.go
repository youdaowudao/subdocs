//go:build windows

package connect

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"unsafe"

	"golang.org/x/sys/windows/registry"
)

func antigravityWindowsDefaultPaths() []string {
	var paths []string
	if dir, err := os.UserCacheDir(); err == nil && dir != "" {
		paths = append(paths, filepath.Join(dir, "Programs", "Antigravity", "Antigravity.exe"))
	}
	for _, name := range []string{"ProgramFiles", "ProgramFiles(x86)", "ProgramW6432"} {
		if dir := os.Getenv(name); dir != "" {
			paths = append(paths, filepath.Join(dir, "Antigravity", "Antigravity.exe"))
		}
	}
	return paths
}

func antigravityRegistryString(key registry.Key, name string) string {
	value, kind, err := key.GetStringValue(name)
	if err != nil {
		return ""
	}
	if kind == registry.EXPAND_SZ {
		if expanded, err := registry.ExpandString(value); err == nil {
			value = expanded
		}
	}
	return strings.TrimSpace(value)
}

func antigravityRegistryExe(value string) string {
	// DisplayIcon may be quoted and end with a resource index (",0").
	end := strings.LastIndex(strings.ToLower(value), ".exe")
	if end < 0 {
		return ""
	}
	path := strings.Trim(strings.TrimSpace(value[:end+4]), `"`)
	if !filepath.IsAbs(path) || !strings.EqualFold(filepath.Base(path), "Antigravity.exe") {
		return ""
	}
	return path
}

func antigravityWindowsRegisteredPaths() []string {
	var paths []string
	const uninstall = `Software\Microsoft\Windows\CurrentVersion\Uninstall`
	const appPaths = `Software\Microsoft\Windows\CurrentVersion\App Paths\Antigravity.exe`
	for _, root := range []registry.Key{registry.CURRENT_USER, registry.LOCAL_MACHINE} {
		for _, view := range []uint32{registry.WOW64_64KEY, registry.WOW64_32KEY} {
			if key, err := registry.OpenKey(root, appPaths, registry.QUERY_VALUE|view); err == nil {
				paths = append(paths, antigravityRegistryExe(antigravityRegistryString(key, "")))
				key.Close()
			}
			parent, err := registry.OpenKey(root, uninstall, registry.ENUMERATE_SUB_KEYS|view)
			if err != nil {
				continue
			}
			names, err := parent.ReadSubKeyNames(-1)
			parent.Close()
			if err != nil {
				continue
			}
			for _, name := range names {
				entry, err := registry.OpenKey(root, uninstall+`\`+name, registry.QUERY_VALUE|view)
				if err != nil {
					continue
				}
				display := strings.ToLower(antigravityRegistryString(entry, "DisplayName"))
				if display == "antigravity" || display == "google antigravity" || display == "antigravity app" || display == "google antigravity app" {
					if dir := strings.Trim(antigravityRegistryString(entry, "InstallLocation"), `"`); filepath.IsAbs(dir) {
						paths = append(paths, filepath.Join(dir, "Antigravity.exe"))
					}
					paths = append(paths, antigravityRegistryExe(antigravityRegistryString(entry, "DisplayIcon")))
				}
				entry.Close()
			}
		}
	}
	return paths
}

type windowsAntigravityEnv struct{}

func newAntigravityEnvStore() antigravityEnvStore { return windowsAntigravityEnv{} }
func (windowsAntigravityEnv) Read() (map[string]antigravityEnvValue, error) {
	values := map[string]antigravityEnvValue{}
	key, err := registry.OpenKey(registry.CURRENT_USER, "Environment", registry.QUERY_VALUE)
	if errors.Is(err, registry.ErrNotExist) {
		return values, nil
	}
	if err != nil {
		return nil, err
	}
	defer key.Close()
	for _, name := range antigravityVariables {
		v, kind, err := key.GetStringValue(name)
		if errors.Is(err, registry.ErrNotExist) {
			continue
		}
		if err != nil {
			return nil, err
		}
		values[name] = antigravityEnvValue{Value: v, Type: kind, Present: true}
	}
	return values, nil
}
func (w windowsAntigravityEnv) Write(values map[string]antigravityEnvValue) error {
	previous, err := w.Read()
	if err != nil {
		return err
	}
	key, _, err := registry.CreateKey(registry.CURRENT_USER, "Environment", registry.SET_VALUE)
	if err != nil {
		return err
	}
	defer key.Close()
	set := func(name string, v antigravityEnvValue) error {
		if !v.Present {
			err := key.DeleteValue(name)
			if errors.Is(err, registry.ErrNotExist) {
				return nil
			}
			return err
		}
		if v.Type == registry.EXPAND_SZ {
			return key.SetExpandStringValue(name, v.Value)
		}
		return key.SetStringValue(name, v.Value)
	}
	for i, name := range antigravityVariables {
		if err := set(name, values[name]); err != nil {
			for _, done := range antigravityVariables[:i] {
				_ = set(done, previous[done])
			}
			return err
		}
	}
	// Explorer refreshes the current user's environment for future processes.
	text, _ := syscall.UTF16PtrFromString("Environment")
	var result uintptr
	_, _, _ = syscall.NewLazyDLL("user32.dll").NewProc("SendMessageTimeoutW").Call(0xffff, 0x001a, 0, uintptr(unsafe.Pointer(text)), 0x0002, 1000, uintptr(unsafe.Pointer(&result)))
	return nil
}
