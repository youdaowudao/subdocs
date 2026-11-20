//go:build windows

package connect

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"syscall"
	"unicode/utf16"
	"unsafe"

	"golang.org/x/sys/windows"
)

// A visible console needs its own standard handles. os/exec installs the
// GUI parent's redirected handles, so use CreateProcess without that flag.
func runChinesePowerShell(shell string, args, env []string, directory string) (uint32, error) {
	if shell == "" {
		shell = filepath.Join(os.Getenv("SystemRoot"), "System32", "WindowsPowerShell", "v1.0", "powershell.exe")
	}
	resolved, err := exec.LookPath(shell)
	if err != nil {
		return 0, err
	}
	application, err := windows.UTF16PtrFromString(resolved)
	if err != nil {
		return 0, err
	}
	words := append([]string{resolved}, args...)
	for i := range words {
		words[i] = syscall.EscapeArg(words[i])
	}
	command, err := windows.UTF16PtrFromString(strings.Join(words, " "))
	if err != nil {
		return 0, err
	}
	cwd, err := windows.UTF16PtrFromString(directory)
	if err != nil {
		return 0, err
	}
	sort.Slice(env, func(i, j int) bool { return strings.ToUpper(env[i]) < strings.ToUpper(env[j]) })
	block := utf16.Encode([]rune(strings.Join(env, "\x00") + "\x00\x00"))
	startup := windows.StartupInfo{Cb: uint32(unsafe.Sizeof(windows.StartupInfo{}))}
	var process windows.ProcessInformation
	const flags = windows.CREATE_NEW_CONSOLE | windows.CREATE_UNICODE_ENVIRONMENT
	if err := windows.CreateProcess(application, command, nil, nil, false, flags, &block[0], cwd, &startup, &process); err != nil {
		return 0, err
	}
	defer windows.CloseHandle(process.Process)
	windows.CloseHandle(process.Thread)
	if _, err := windows.WaitForSingleObject(process.Process, windows.INFINITE); err != nil {
		return 0, err
	}
	var code uint32
	if err := windows.GetExitCodeProcess(process.Process, &code); err != nil {
		return 0, fmt.Errorf("无法读取 PowerShell 结果：%w", err)
	}
	return code, nil
}
