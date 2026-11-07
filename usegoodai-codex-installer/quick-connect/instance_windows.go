package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"syscall"
	"time"
	"unsafe"

	"github.com/wailsapp/wails/v2/pkg/options"
	"golang.org/x/sys/windows"

	"usegoodai-quick-connect/connect"
)

// One helper window per user, and the newest launch wins (see takeover.go).
//
// The running helper owns a hidden window with the class and title Wails 2
// used for its single-instance lock in 1.1.3 and earlier, so old and new
// helpers find each other. The window runs on its own thread: it answers a
// later launch even while the page is stuck.
var (
	launchWindowClass = "wails-app-" + singleInstanceID + "-sic"
	launchWindowTitle = "wails-app-" + singleInstanceID + "-siw"
	// An older helper looks for the window only while this name exists.
	legacyMutexName = "wails-app-" + singleInstanceID + "sim"
	// Owned by the running helper for its whole life; abandoned when it dies.
	ownerMutexName = "usegoodai-quick-connect-owner-" + singleInstanceID
)

const (
	copyDataLaunch   = 1542 // Wails: a later launch hands over its arguments
	copyDataTakeover = 1543 // a later launch asks to take over

	wmClose          = 0x0010
	wmCopyData       = 0x004A
	smtoBlock        = 0x0001
	smtoAbortIfHung  = 0x0002
	msgfltAllow      = 1
	answerTimeout    = 2 * time.Second
	closeTimeout     = 5 * time.Second
	claimDeadline    = 15 * time.Second
	instancePIDName  = "instance.pid"
	webviewSettleGap = time.Second
)

var (
	user32                          = windows.NewLazySystemDLL("user32.dll")
	kernel32                        = windows.NewLazySystemDLL("kernel32.dll")
	procRegisterClassExW            = user32.NewProc("RegisterClassExW")
	procCreateWindowExW             = user32.NewProc("CreateWindowExW")
	procDefWindowProcW              = user32.NewProc("DefWindowProcW")
	procGetMessageW                 = user32.NewProc("GetMessageW")
	procTranslateMessage            = user32.NewProc("TranslateMessage")
	procDispatchMessageW            = user32.NewProc("DispatchMessageW")
	procFindWindowW                 = user32.NewProc("FindWindowW")
	procSendMessageTimeoutW         = user32.NewProc("SendMessageTimeoutW")
	procGetWindowThreadProcessID    = user32.NewProc("GetWindowThreadProcessId")
	procEnumWindows                 = user32.NewProc("EnumWindows")
	procIsWindowVisible             = user32.NewProc("IsWindowVisible")
	procPostMessageW                = user32.NewProc("PostMessageW")
	procChangeWindowMessageFilterEx = user32.NewProc("ChangeWindowMessageFilterEx")
	procGetModuleHandleW            = kernel32.NewProc("GetModuleHandleW")
)

type wndClassEx struct {
	size       uint32
	style      uint32
	wndProc    uintptr
	clsExtra   int32
	wndExtra   int32
	instance   uintptr
	icon       uintptr
	cursor     uintptr
	background uintptr
	menuName   *uint16
	className  *uint16
	iconSm     uintptr
}

type copyData struct {
	data uintptr
	size uint32
	ptr  uintptr
}

type winMsg struct {
	hwnd    uintptr
	message uint32
	wParam  uintptr
	lParam  uintptr
	time    uint32
	x, y    int32
	private uint32
}

// launchHandler is the running window's side.
type launchHandler interface {
	takeover() uintptr      // a later launch of this helper asks to take over
	launched(args []string) // an older helper handed over its arguments
}

var errStuckHelper = errors.New("另一个助手窗口一直没有响应，也无法结束（可能是以管理员身份运行的）。请在任务管理器里结束「" + connect.ProductName + "」，或重启电脑后再打开。")

// claimInstance makes this launch the only running helper. It returns
// false when the running window is busy and stays; this launch then ends.
func claimInstance(log *startupLog) (bool, error) {
	if handle, err := createMutex(legacyMutexName); handle == 0 {
		log.printf("无法创建兼容锁：%v", err)
	}
	owner, err := createMutex(ownerMutexName)
	if owner == 0 {
		log.printf("无法创建单窗口锁，直接打开：%v", err)
		return true, nil
	}
	tookOver := false
	deadline := time.Now().Add(claimDeadline)
	giveUp := deadline.Add(claimDeadline)
	for {
		if time.Now().After(giveUp) {
			return false, errStuckHelper
		}
		if hwnd := findLaunchWindow(); hwnd != 0 {
			keep, err := takeOverFrom(hwnd, log)
			if err != nil || !keep {
				return false, err
			}
			tookOver = true
		} else if ownMutex(owner) {
			if tookOver {
				// The old window's WebView2 processes share the data folder.
				time.Sleep(webviewSettleGap)
			}
			writeInstancePID()
			return true, nil
		} else if time.Now().After(deadline) {
			// Owned by a helper without a window: stuck starting or closing.
			pid := recordedInstancePID()
			if pid == 0 || pid == uint32(os.Getpid()) || !helperImage(pid) {
				return false, errStuckHelper
			}
			log.printf("结束没有窗口的旧助手 pid=%d", pid)
			if err := endProcess(pid); err != nil {
				log.printf("无法结束旧助手 pid=%d：%v", pid, err)
				return false, errStuckHelper
			}
			tookOver = true
		}
		time.Sleep(200 * time.Millisecond)
	}
}

func takeOverFrom(hwnd uintptr, log *startupLog) (bool, error) {
	pid := windowProcess(hwnd)
	if pid == 0 || pid == uint32(os.Getpid()) {
		return true, nil
	}
	reply, answered := askToTakeOver(hwnd)
	switch nextTakeoverStep(answered, reply) {
	case keepRunningWindow:
		log.printf("运行中的助手 pid=%d 正在操作，本次打开结束", pid)
		return false, nil
	case waitForClose:
		log.printf("运行中的助手 pid=%d 空闲，由本次打开接管", pid)
		if waitForExit(pid, closeTimeout) {
			return true, nil
		}
		log.printf("旧助手 pid=%d 没有按时关闭，结束它", pid)
	case closeOlderHelper:
		log.printf("运行中的是旧版助手 pid=%d，关闭它的窗口", pid)
		closeVisibleWindows(pid)
		if waitForExit(pid, closeTimeout) {
			return true, nil
		}
		log.printf("旧版助手 pid=%d 没有按时关闭，结束它", pid)
	case endUnresponsive:
		log.printf("运行中的助手 pid=%d 没有响应，结束它", pid)
	}
	if err := endProcess(pid); err != nil {
		log.printf("无法结束旧助手 pid=%d：%v", pid, err)
		return false, errStuckHelper
	}
	return true, nil
}

// listenForLaunches creates the hidden window later launches talk to, on a
// thread of its own.
func listenForLaunches(handler launchHandler) error {
	ready := make(chan error, 1)
	go func() {
		runtime.LockOSThread() // the window belongs to this thread for good
		hwnd, err := createLaunchWindow(handler)
		if err == nil {
			// A launch without administrator rights may still reach this window.
			_, _, _ = procChangeWindowMessageFilterEx.Call(hwnd, wmCopyData, msgfltAllow, 0)
		}
		ready <- err
		if err != nil {
			return
		}
		var message winMsg
		for {
			result, _, _ := procGetMessageW.Call(uintptr(unsafe.Pointer(&message)), 0, 0, 0)
			if int32(result) <= 0 {
				return
			}
			_, _, _ = procTranslateMessage.Call(uintptr(unsafe.Pointer(&message)))
			_, _, _ = procDispatchMessageW.Call(uintptr(unsafe.Pointer(&message)))
		}
	}()
	return <-ready
}

func createLaunchWindow(handler launchHandler) (uintptr, error) {
	className, _ := windows.UTF16PtrFromString(launchWindowClass)
	title, _ := windows.UTF16PtrFromString(launchWindowTitle)
	module, _, _ := procGetModuleHandleW.Call(0)
	callback := syscall.NewCallback(func(hwnd, message, wParam, lParam uintptr) uintptr {
		if message == wmCopyData && lParam != 0 {
			return handleCopyData(handler, *(**copyData)(unsafe.Pointer(&lParam)))
		}
		result, _, _ := procDefWindowProcW.Call(hwnd, message, wParam, lParam)
		return result
	})
	class := wndClassEx{wndProc: callback, instance: module, className: className}
	class.size = uint32(unsafe.Sizeof(class))
	if atom, _, err := procRegisterClassExW.Call(uintptr(unsafe.Pointer(&class))); atom == 0 {
		return 0, fmt.Errorf("RegisterClassEx：%w", err)
	}
	hwnd, _, err := procCreateWindowExW.Call(0, uintptr(unsafe.Pointer(className)), uintptr(unsafe.Pointer(title)),
		0, 0, 0, 0, 0, 0, 0, module, 0)
	if hwnd == 0 {
		return 0, fmt.Errorf("CreateWindowEx：%w", err)
	}
	return hwnd, nil
}

func handleCopyData(handler launchHandler, data *copyData) uintptr {
	switch data.data {
	case copyDataTakeover:
		return handler.takeover()
	case copyDataLaunch:
		// The data is only valid during this call: decode it before returning.
		var launch options.SecondInstanceData
		if text := copyDataText(data); text != "" && json.Unmarshal([]byte(text), &launch) == nil {
			go handler.launched(launch.Args)
		}
	}
	return 0
}

func copyDataText(data *copyData) string {
	if data.ptr == 0 || data.size < 2 {
		return ""
	}
	units := unsafe.Slice(*(**uint16)(unsafe.Pointer(&data.ptr)), data.size/2)
	return windows.UTF16ToString(units)
}

func askToTakeOver(hwnd uintptr) (uintptr, bool) {
	payload, _ := windows.UTF16FromString(connect.Version)
	data := copyData{data: copyDataTakeover, size: uint32(len(payload) * 2), ptr: uintptr(unsafe.Pointer(&payload[0]))}
	var reply uintptr
	sent, _, _ := procSendMessageTimeoutW.Call(hwnd, wmCopyData, 0, uintptr(unsafe.Pointer(&data)),
		smtoBlock|smtoAbortIfHung, uintptr(answerTimeout/time.Millisecond), uintptr(unsafe.Pointer(&reply)))
	runtime.KeepAlive(payload)
	runtime.KeepAlive(&data)
	return reply, sent != 0
}

func findLaunchWindow() uintptr {
	className, _ := windows.UTF16PtrFromString(launchWindowClass)
	title, _ := windows.UTF16PtrFromString(launchWindowTitle)
	hwnd, _, _ := procFindWindowW.Call(uintptr(unsafe.Pointer(className)), uintptr(unsafe.Pointer(title)))
	return hwnd
}

func windowProcess(hwnd uintptr) uint32 {
	var pid uint32
	_, _, _ = procGetWindowThreadProcessID.Call(hwnd, uintptr(unsafe.Pointer(&pid)))
	return pid
}

// closeVisibleWindows asks the visible windows of pid to close, as the
// close button would.
func closeVisibleWindows(pid uint32) {
	callback := syscall.NewCallback(func(hwnd, _ uintptr) uintptr {
		if windowProcess(hwnd) == pid {
			if visible, _, _ := procIsWindowVisible.Call(hwnd); visible != 0 {
				_, _, _ = procPostMessageW.Call(hwnd, wmClose, 0, 0)
			}
		}
		return 1
	})
	_, _, _ = procEnumWindows.Call(callback, 0)
}

func createMutex(name string) (windows.Handle, error) {
	handle, err := windows.CreateMutex(nil, false, windows.StringToUTF16Ptr(name))
	if handle != 0 && errors.Is(err, windows.ERROR_ALREADY_EXISTS) {
		err = nil
	}
	return handle, err
}

// ownMutex takes the owner mutex on a thread that is kept for the life of
// the process, because Windows ties a mutex to the thread that took it.
func ownMutex(owner windows.Handle) bool {
	result := make(chan bool)
	go func() {
		runtime.LockOSThread()
		event, _ := windows.WaitForSingleObject(owner, 0)
		owned := event == windows.WAIT_OBJECT_0 || event == windows.WAIT_ABANDONED
		result <- owned
		if owned {
			select {}
		}
		runtime.UnlockOSThread()
	}()
	return <-result
}

func waitForExit(pid uint32, timeout time.Duration) bool {
	process, err := windows.OpenProcess(windows.SYNCHRONIZE, false, pid)
	if err != nil {
		return errors.Is(err, windows.ERROR_INVALID_PARAMETER) // already gone
	}
	defer windows.CloseHandle(process)
	event, _ := windows.WaitForSingleObject(process, uint32(timeout/time.Millisecond))
	return event == windows.WAIT_OBJECT_0
}

func endProcess(pid uint32) error {
	process, err := windows.OpenProcess(windows.PROCESS_TERMINATE|windows.SYNCHRONIZE, false, pid)
	if err != nil {
		if errors.Is(err, windows.ERROR_INVALID_PARAMETER) {
			return nil
		}
		return err
	}
	defer windows.CloseHandle(process)
	if err := windows.TerminateProcess(process, 1); err != nil {
		if event, _ := windows.WaitForSingleObject(process, 0); event == windows.WAIT_OBJECT_0 {
			return nil
		}
		return err
	}
	if event, _ := windows.WaitForSingleObject(process, uint32(closeTimeout/time.Millisecond)); event != windows.WAIT_OBJECT_0 {
		return errors.New("进程没有结束")
	}
	return nil
}

// helperImage reports whether pid runs a program named like this helper,
// so a reused process number never ends some other program.
func helperImage(pid uint32) bool {
	process, err := windows.OpenProcess(windows.PROCESS_QUERY_LIMITED_INFORMATION, false, pid)
	if err != nil {
		return false
	}
	defer windows.CloseHandle(process)
	buffer := make([]uint16, windows.MAX_LONG_PATH)
	size := uint32(len(buffer))
	if windows.QueryFullProcessImageName(process, 0, &buffer[0], &size) != nil {
		return false
	}
	name := strings.ToLower(filepath.Base(windows.UTF16ToString(buffer[:size])))
	return strings.Contains(name, "usegoodai")
}

func instancePIDPath() string {
	directory := webviewDataPath()
	if directory == "" {
		return ""
	}
	return filepath.Join(directory, instancePIDName)
}

func writeInstancePID() {
	if path := instancePIDPath(); path != "" && os.MkdirAll(filepath.Dir(path), 0o700) == nil {
		_ = os.WriteFile(path, []byte(strconv.Itoa(os.Getpid())), 0o600)
	}
}

func recordedInstancePID() uint32 {
	path := instancePIDPath()
	if path == "" {
		return 0
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return 0
	}
	pid, err := strconv.ParseUint(strings.TrimSpace(string(data)), 10, 32)
	if err != nil {
		return 0
	}
	return uint32(pid)
}
