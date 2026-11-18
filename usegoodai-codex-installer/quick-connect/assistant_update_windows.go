package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"syscall"

	"golang.org/x/sys/windows"

	"usegoodai-quick-connect/connect"
)

const assistantRestartArgument = "--restart-after-assistant-update"

func assistantUpdateDirectory() string {
	base := webviewDataPath()
	if base == "" {
		return ""
	}
	return filepath.Join(base, "updates")
}

func startUpdatedAssistant(path string) error {
	// The child waits on a handle to this exact process, even if Windows
	// reuses its process ID. No running executable is replaced or deleted.
	parent, err := windows.OpenProcess(windows.SYNCHRONIZE, true, uint32(os.Getpid()))
	if err != nil {
		return err
	}
	defer windows.CloseHandle(parent)
	command := exec.Command(path, assistantRestartArgument, strconv.FormatUint(uint64(parent), 10))
	command.SysProcAttr = &syscall.SysProcAttr{AdditionalInheritedHandles: []syscall.Handle{syscall.Handle(parent)}}
	command.Env = slices.DeleteFunc(command.Environ(), func(entry string) bool {
		name, _, _ := strings.Cut(entry, "=")
		return strings.EqualFold(name, windowEnv) || strings.EqualFold(name, profileEnv)
	})
	if err := command.Start(); err != nil {
		return err
	}
	return command.Process.Release()
}

func runAfterAssistantUpdate(value string) int {
	handle, err := strconv.ParseUint(value, 10, strconv.IntSize)
	if err != nil || handle == 0 {
		return 1
	}
	parent := windows.Handle(handle)
	result, err := windows.WaitForSingleObject(parent, 30_000)
	windows.CloseHandle(parent)
	if err != nil || result != windows.WAIT_OBJECT_0 {
		showMessage(connect.ProductName, "旧助手未按时退出。请关闭助手，再打开原来的快捷方式重试。", mbOK|mbIconWarning)
		return exitShown
	}
	os.Args = os.Args[:1]
	return runGuard()
}

func launchActiveAssistant() bool {
	path := readActiveAssistant(assistantUpdateDirectory(), connect.Version)
	if path == "" {
		return false
	}
	return exec.Command(path, os.Args[1:]...).Run() == nil
}

func recordActiveAssistant(record *startRecord, path string) {
	if err := activateAssistant(assistantUpdateDirectory(), path, connect.Version); err != nil {
		record.stage("助手更新记录保存失败", err.Error())
	}
}
