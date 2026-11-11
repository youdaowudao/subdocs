package main

import (
	"fmt"
	"syscall"
	"unsafe"

	"golang.org/x/sys/windows"
)

var (
	user32                       = syscall.NewLazyDLL("user32.dll")
	procFindWindowW              = user32.NewProc("FindWindowW")
	procGetWindowThreadProcessID = user32.NewProc("GetWindowThreadProcessId")
	procEnumWindows              = user32.NewProc("EnumWindows")
	procIsWindowVisible          = user32.NewProc("IsWindowVisible")
)

func windowsVersion() string {
	v := windows.RtlGetVersion()
	return fmt.Sprintf("Windows %d.%d.%d", v.MajorVersion, v.MinorVersion, v.BuildNumber)
}

// existingInstance finds a running assistant by the hidden message window
// Wails creates for its single-instance lock (id + "-sic" / id + "-siw").
// A later launch hands its arguments to that process and exits, so this
// tells whether the running one has any visible window.
func existingInstance(id string) (pid uint32, visible bool, running bool) {
	class, _ := syscall.UTF16PtrFromString(id + "-sic")
	title, _ := syscall.UTF16PtrFromString(id + "-siw")
	hwnd, _, _ := procFindWindowW.Call(uintptr(unsafe.Pointer(class)), uintptr(unsafe.Pointer(title)))
	if hwnd == 0 {
		return 0, false, false
	}
	_, _, _ = procGetWindowThreadProcessID.Call(hwnd, uintptr(unsafe.Pointer(&pid)))
	callback := syscall.NewCallback(func(window, _ uintptr) uintptr {
		var owner uint32
		_, _, _ = procGetWindowThreadProcessID.Call(window, uintptr(unsafe.Pointer(&owner)))
		if owner == pid {
			if shown, _, _ := procIsWindowVisible.Call(window); shown != 0 {
				visible = true
				return 0
			}
		}
		return 1
	})
	_, _, _ = procEnumWindows.Call(callback, 0)
	return pid, visible, true
}
