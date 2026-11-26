//go:build windows

package connect

import (
	"errors"
	"syscall"
	"unsafe"

	"golang.org/x/sys/windows/registry"
)

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
