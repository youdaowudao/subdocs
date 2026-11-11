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

// existingInstance finds a running assistant by what Wails creates for its
// single-instance lock: a hidden message window named "wails-app-" + id +
// "-sic"/"-siw", and a mutex named "wails-app-" + id + "sim". A later launch
// hands its arguments to that process and exits, so this also tells whether
// the running one has any visible window. pid is 0 when only the lock is
// found.
func existingInstance(id string) (pid uint32, visible bool, running bool) {
	id = "wails-app-" + id
	class, _ := syscall.UTF16PtrFromString(id + "-sic")
	title, _ := syscall.UTF16PtrFromString(id + "-siw")
	hwnd, _, _ := procFindWindowW.Call(uintptr(unsafe.Pointer(class)), uintptr(unsafe.Pointer(title)))
	if hwnd == 0 {
		name, _ := syscall.UTF16PtrFromString(id + "sim")
		const synchronize = 0x00100000
		lock, err := windows.OpenMutex(synchronize, false, name)
		if err != nil {
			return 0, false, false
		}
		_ = windows.CloseHandle(lock)
		return 0, false, true
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
