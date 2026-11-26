//go:build windows

package connect

import (
	"fmt"
	"syscall"
	"unsafe"

	"golang.org/x/sys/windows"
)

var (
	appModelDLL             = windows.NewLazySystemDLL("kernel32.dll")
	getPackagesByFamily     = appModelDLL.NewProc("GetPackagesByPackageFamily")
	getProcessPackageFamily = appModelDLL.NewProc("GetPackageFamilyName")
)

// GetPackagesByPackageFamily queries packages registered for the current user.
// We need only the count, not the full names or the version/architecture.
// The sizing call returns ERROR_INSUFFICIENT_BUFFER when packages are found.
func registeredClaudePackage(family string) (bool, error) {
	if err := getPackagesByFamily.Find(); err != nil {
		return false, fmt.Errorf("无法读取 Windows 应用安装信息：%w", err)
	}
	name, err := windows.UTF16PtrFromString(family)
	if err != nil {
		return false, err
	}
	var count, length uint32
	r, _, _ := getPackagesByFamily.Call(uintptr(unsafe.Pointer(name)), uintptr(unsafe.Pointer(&count)), 0, uintptr(unsafe.Pointer(&length)), 0)
	// The LONG return value is the Windows error code, not GetLastError.
	switch syscall.Errno(r) {
	case windows.ERROR_SUCCESS:
		return count > 0, nil
	case windows.ERROR_INSUFFICIENT_BUFFER:
		if count > 0 {
			return true, nil
		}
	}
	return false, fmt.Errorf("无法读取 Windows 应用安装信息：%w", syscall.Errno(r))
}

// Query the package identity on the already-open process handle, rather
// than relying on its installation drive or on the spelling of its path.
func claudeDesktopProcess(handle windows.Handle) (bool, error) {
	if err := getProcessPackageFamily.Find(); err != nil {
		return false, err
	}
	// The package family name is at most 64 characters (plus NUL).
	var name [65]uint16
	length := uint32(len(name))
	r, _, _ := getProcessPackageFamily.Call(uintptr(handle), uintptr(unsafe.Pointer(&length)), uintptr(unsafe.Pointer(&name[0])))
	switch syscall.Errno(r) {
	case windows.ERROR_SUCCESS:
		return isClaudeDesktopFamily(windows.UTF16ToString(name[:])), nil
	case windows.APPMODEL_ERROR_NO_PACKAGE:
		return false, nil // an unpackaged Claude Code CLI, for example
	default:
		return false, syscall.Errno(r)
	}
}
