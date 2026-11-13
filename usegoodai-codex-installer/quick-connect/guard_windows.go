package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"time"
	"unsafe"

	"golang.org/x/sys/windows"

	"usegoodai-quick-connect/connect"
)

// 启动守护的 Windows 部分，规则见 guard.go。

var (
	procSendMessageTimeoutW = user32.NewProc("SendMessageTimeoutW")
	procMessageBoxW         = user32.NewProc("MessageBoxW")
)

// runGuard is what a double-click or an import link runs. It returns the
// process exit code.
func runGuard() int {
	base := webviewDataPath()
	state := inspectInstance(singleInstanceID)
	record := openStartRecord(filepath.Join(base, "logs"), state.running)
	defer record.close()
	record.crashOutput()
	launchLink := connect.FindImportLink(os.Args[1:])
	record.stage("启动", startSummary(connect.Version, windowsVersion(), os.Getpid(), launchLink != ""))
	// The window process starts from here; let it take the foreground the
	// user's double-click gave this process.
	allowAnyForegroundWindow()

	if !settleInstance(record, state) {
		return exitShown
	}

	profile, name := savedProfile(base)
	for attempt := 1; attempt <= 2; attempt++ {
		if attempt == 2 {
			profile, name = freshProfile(base, time.Now())
			record.stage("换新数据目录再试", name)
		}
		outcome, err := startWindow(profile, attempt)
		if err != nil {
			record.stage("启动窗口进程失败", err.Error())
			outcome = windowOutcome{exited: true, code: 1}
		}
		switch judgeOutcome(attempt, outcome) {
		case stepDone:
			if attempt == 2 && outcome.ready {
				rememberProfile(base, name)
				record.stage("已记住", "以后用 "+name)
			}
			return 0
		case stepQuiet:
			return exitShown
		case stepRetry:
			record.stage("窗口没有打开", outcomeReason(outcome))
		case stepGiveUp:
			reason := outcomeReason(outcome)
			record.stage("窗口没有打开", reason+"；提示改用命令窗口")
			offerFallback(record.path, launchLink)
			return 1
		}
	}
	return 1
}

// settleInstance deals with an assistant already running: a healthy one
// receives the link, a stuck one is ended. False means the user was told
// why nothing more can be done.
func settleInstance(record *startRecord, state instanceState) bool {
	for deadline := time.Now().Add(instanceGrace); ; {
		action := judgeInstance(state)
		if action == instanceWait && time.Now().Before(deadline) {
			time.Sleep(500 * time.Millisecond)
			state = inspectInstance(singleInstanceID)
			continue
		}
		switch action {
		case instanceUse:
			record.stage("已有实例", fmt.Sprintf("进程 %d，窗口可见；本次把参数交给它", state.pid))
		case instanceWait, instanceEnd:
			reason := stuckReason(state)
			if err := endProcess(state.pid); err != nil {
				record.stage("卡住的助手无法结束", fmt.Sprintf("进程 %d，%s：%v", state.pid, reason, err))
				showMessage(connect.ProductName, "之前打开的助手卡住了（"+reason+"），无法自动结束。\n\n"+
					"请打开任务管理器，结束「"+connect.ProductName+"」后再打开。", mbIconWarning)
				return false
			}
			record.stage("已结束卡住的助手", fmt.Sprintf("进程 %d，%s", state.pid, reason))
		}
		return true
	}
}

// inspectInstance looks at the window process that holds the single-instance
// lock, if any.
func inspectInstance(id string) instanceState {
	messageWindow, pid, visible, running := existingInstance(id)
	state := instanceState{running: running, pid: pid, visible: visible}
	if pid == 0 {
		return state
	}
	// Wails's own second launch sends to this window and waits for it: a hung
	// one would hang every later launch too.
	const wmNull, smtoAbortIfHung, smtoBlock = 0, 0x0002, 0x0001
	var result uintptr
	sent, _, _ := procSendMessageTimeoutW.Call(messageWindow, wmNull, 0, 0, smtoAbortIfHung|smtoBlock, 3000,
		uintptr(unsafe.Pointer(&result)))
	state.responding = sent != 0
	state.age = processAge(pid)
	return state
}

// processAge is how long pid has run; unknown counts as long.
func processAge(pid uint32) time.Duration {
	handle, err := windows.OpenProcess(windows.PROCESS_QUERY_LIMITED_INFORMATION, false, pid)
	if err != nil {
		return time.Hour
	}
	defer windows.CloseHandle(handle)
	var created, exited, kernel, user windows.Filetime
	if windows.GetProcessTimes(handle, &created, &exited, &kernel, &user) != nil {
		return time.Hour
	}
	return time.Since(time.Unix(0, created.Nanoseconds()))
}

func endProcess(pid uint32) error {
	handle, err := windows.OpenProcess(windows.PROCESS_TERMINATE|windows.SYNCHRONIZE, false, pid)
	if err != nil {
		return err
	}
	defer windows.CloseHandle(handle)
	if err := windows.TerminateProcess(handle, 1); err != nil {
		return err
	}
	if event, _ := windows.WaitForSingleObject(handle, 5000); event != windows.WAIT_OBJECT_0 {
		return fmt.Errorf("5 秒后仍在运行")
	}
	return nil
}

// startWindow runs this program again as the window process and waits for
// its page, its exit, or the timeout.
func startWindow(profile string, attempt int) (windowOutcome, error) {
	self, err := os.Executable()
	if err != nil {
		return windowOutcome{}, err
	}
	eventName := fmt.Sprintf(`Local\UseGoodAI-QuickConnect-ready-%d-%d`, os.Getpid(), attempt)
	name, _ := windows.UTF16PtrFromString(eventName)
	ready, err := windows.CreateEvent(nil, 1, 0, name)
	if err != nil {
		return windowOutcome{}, err
	}
	defer windows.CloseHandle(ready)
	isSet := func() bool {
		event, _ := windows.WaitForSingleObject(ready, 0)
		return event == windows.WAIT_OBJECT_0
	}

	command := exec.Command(self, os.Args[1:]...)
	command.Env = append(os.Environ(), windowEnv+"="+eventName, profileEnv+"="+profile)
	if err := command.Start(); err != nil {
		return windowOutcome{}, err
	}
	exited := make(chan uint32, 1)
	go func() {
		_ = command.Wait()
		exited <- uint32(command.ProcessState.ExitCode())
	}()
	timeout := time.NewTimer(readyTimeout)
	defer timeout.Stop()
	tick := time.NewTicker(100 * time.Millisecond)
	defer tick.Stop()
	for {
		select {
		case code := <-exited:
			return windowOutcome{ready: isSet(), exited: true, code: code}, nil
		case <-tick.C:
			if isSet() {
				return windowOutcome{ready: true}, nil
			}
		case <-timeout.C:
			if isSet() {
				return windowOutcome{ready: true}, nil
			}
			_ = command.Process.Kill()
			<-exited
			return windowOutcome{timedOut: true}, nil
		}
	}
}

// signalReady tells the guard the page is up.
func signalReady(eventName string) {
	if eventName == "" {
		return
	}
	name, err := windows.UTF16PtrFromString(eventName)
	if err != nil {
		return
	}
	const eventModifyState = 0x0002
	event, err := windows.OpenEvent(eventModifyState, false, name)
	if err != nil {
		return
	}
	_ = windows.SetEvent(event)
	_ = windows.CloseHandle(event)
}

const (
	mbOK          = 0x00
	mbOKCancel    = 0x01
	mbIconWarning = 0x30
	idOK          = 1
)

func showMessage(title, text string, flags uintptr) uintptr {
	textPointer, _ := syscall.UTF16PtrFromString(text)
	titlePointer, _ := syscall.UTF16PtrFromString(title)
	const mbSetForeground, mbTopmost = 0x00010000, 0x00040000
	answer, _, _ := procMessageBoxW.Call(0, uintptr(unsafe.Pointer(textPointer)), uintptr(unsafe.Pointer(titlePointer)),
		flags|mbSetForeground|mbTopmost)
	return answer
}

// offerFallback explains the failure and, on OK, opens the command-window
// installer (or the tutorial site for a Claude link).
func offerFallback(recordPath, launchLink string) {
	var plan fallbackPlan
	if link, linkProblem := connect.ParseImportLink(launchLink); linkProblem == connect.LinkOK {
		plan = fallbackPlan{claude: link.App == connect.LinkAppClaude, key: link.Key}
	}
	message := fallbackMessage(connect.ProductName, recordPath, plan)
	if showMessage(connect.ProductName, message, mbOKCancel|mbIconWarning) != idOK {
		return
	}
	if plan.claude {
		_ = exec.Command(filepath.Join(os.Getenv("SystemRoot"), "System32", "rundll32.exe"), "url.dll,FileProtocolHandler", docsURL).Start()
		return
	}
	powershell := filepath.Join(os.Getenv("SystemRoot"), "System32", "WindowsPowerShell", "v1.0", "powershell.exe")
	command := exec.Command(powershell, "-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", fallbackCommand)
	const createNewConsole = 0x00000010
	command.SysProcAttr = &syscall.SysProcAttr{CreationFlags: createNewConsole}
	command.Env = os.Environ()
	if plan.key != "" {
		command.Env = append(command.Env, "USEGOODAI_KEY="+plan.key)
	}
	_ = command.Start()
}
