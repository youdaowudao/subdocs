package main

import (
	"encoding/binary"
	"fmt"
	"path/filepath"
	"runtime"
	"syscall"
	"time"
	"unsafe"

	"golang.org/x/sys/windows"
	"usegoodai-quick-connect/connect"
)

var errorUser32 = windows.NewLazySystemDLL("user32.dll")

// The Windows SDK declares TASKDIALOGCONFIG and TASKDIALOG_BUTTON under
// pshpack1.h. Encode their x64 layouts explicitly, without Go's padding.
func showFailureReport(r failureReport) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	content := r.brief + "\n\n点“复制错误信息”，再粘贴到 QQ 发给维护者。"
	if r.saveErr != nil {
		content += "\n\n备用日志未能保存；仍可复制本提示。"
	}
	labels := []string{connect.ProductName, "助手遇到错误", content, "复制错误信息", "打开日志文件夹", "关闭"}
	text := make([]*uint16, len(labels))
	for i, label := range labels {
		text[i], _ = syscall.UTF16PtrFromString(label)
	}
	buttons := make([]byte, 36)
	for i, id := range []uint32{1001, 1002, 1003} {
		binary.LittleEndian.PutUint32(buttons[i*12:], id)
		binary.LittleEndian.PutUint64(buttons[i*12+4:], uint64(uintptr(unsafe.Pointer(text[i+3]))))
	}
	callback := syscall.NewCallback(func(hwnd uintptr, notification uint32, button, unused, data uintptr) uintptr {
		if notification != 2 {
			return 0
		}
		switch button {
		case 1001:
			status := "错误信息已复制。切换到 QQ 按 Ctrl+V 粘贴。"
			if err := copyErrorText(hwnd, r.copyText); err != nil {
				status = "复制失败，请再次点击“复制错误信息”，或打开日志文件夹。"
			}
			value, _ := syscall.UTF16PtrFromString(r.brief + "\n\n" + status)
			// Task Dialog buttons are nested controls; GetDlgItem on the
			// top-level window does not reliably find them. Update the
			// documented content element so both success and failure are visible.
			errorUser32.NewProc("SendMessageW").Call(hwnd, 1024+108, 0, uintptr(unsafe.Pointer(value)))
			return 1 // S_FALSE: keep the dialog open after copying.
		case 1002:
			if r.saveErr == nil && r.path != "" {
				folder, _ := syscall.UTF16PtrFromString(filepath.Dir(r.path))
				verb, _ := syscall.UTF16PtrFromString("open")
				result, _, _ := windows.NewLazySystemDLL("shell32.dll").NewProc("ShellExecuteW").Call(hwnd, uintptr(unsafe.Pointer(verb)), uintptr(unsafe.Pointer(folder)), 0, 0, 1)
				if result <= 32 {
					showError("无法打开日志文件夹。错误信息仍可通过“复制错误信息”按钮复制。")
				}
			} else {
				showError("备用日志未能保存。请点“复制错误信息”后粘贴到 QQ。")
			}
			return 1
		}
		return 0
	})
	config := make([]byte, 160)
	put32 := func(offset int, value uint32) { binary.LittleEndian.PutUint32(config[offset:], value) }
	putPtr := func(offset int, value uintptr) { binary.LittleEndian.PutUint64(config[offset:], uint64(value)) }
	put32(0, 160)
	put32(20, 8) // TDF_ALLOW_DIALOG_CANCELLATION
	putPtr(28, uintptr(unsafe.Pointer(text[0])))
	putPtr(36, 0xfffe) // TD_ERROR_ICON
	putPtr(44, uintptr(unsafe.Pointer(text[1])))
	putPtr(52, uintptr(unsafe.Pointer(text[2])))
	put32(60, 3)
	putPtr(64, uintptr(unsafe.Pointer(&buttons[0])))
	put32(72, 1003)
	putPtr(140, callback)
	proc := windows.NewLazySystemDLL("comctl32.dll").NewProc("TaskDialogIndirect")
	if err := proc.Find(); err != nil {
		showError(content + "\n\n按 Ctrl+C 可复制本提示。")
		return
	}
	var selected int32
	hr, _, _ := proc.Call(uintptr(unsafe.Pointer(&config[0])), uintptr(unsafe.Pointer(&selected)), 0, 0)
	runtime.KeepAlive(text)
	runtime.KeepAlive(buttons)
	runtime.KeepAlive(config)
	if int32(hr) < 0 {
		showError(content + "\n\n按 Ctrl+C 可复制本提示。")
	}
}

func copyErrorText(hwnd uintptr, text string) error {
	open := errorUser32.NewProc("OpenClipboard")
	var result uintptr
	deadline := time.Now().Add(time.Second)
	for {
		result, _, _ = open.Call(hwnd)
		if result != 0 {
			break
		}
		if time.Now().After(deadline) {
			return fmt.Errorf("剪贴板被占用")
		}
		time.Sleep(20 * time.Millisecond)
	}
	defer errorUser32.NewProc("CloseClipboard").Call()
	if result, _, _ = errorUser32.NewProc("EmptyClipboard").Call(); result == 0 {
		return fmt.Errorf("无法清空剪贴板")
	}
	data, err := syscall.UTF16FromString(text)
	if err != nil {
		return err
	}
	kernel := windows.NewLazySystemDLL("kernel32.dll")
	handle, _, _ := kernel.NewProc("GlobalAlloc").Call(2, uintptr(len(data)*2)) // GMEM_MOVEABLE
	if handle == 0 {
		return fmt.Errorf("无法分配剪贴板内容")
	}
	owned := true
	defer func() {
		if owned {
			kernel.NewProc("GlobalFree").Call(handle)
		}
	}()
	address, _, _ := kernel.NewProc("GlobalLock").Call(handle)
	if address == 0 {
		return fmt.Errorf("无法写入剪贴板")
	}
	copy(unsafe.Slice((*uint16)(unsafe.Pointer(address)), len(data)), data)
	kernel.NewProc("GlobalUnlock").Call(handle)
	result, _, _ = errorUser32.NewProc("SetClipboardData").Call(13, handle) // CF_UNICODETEXT
	if result == 0 {
		return fmt.Errorf("无法设置剪贴板")
	}
	owned = false // Clipboard owns the allocated memory after success.
	return nil
}
