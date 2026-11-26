package connect

import (
	"bufio"
	"context"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"runtime"
	"strings"
)

// The command reads the Key from stdin (not process arguments or shell history).
func RunAntigravityCommand(args []string, in io.Reader, out io.Writer, a *Antigravity) int {
	action := "connect"
	if len(args) > 0 {
		action = args[0]
		args = args[1:]
	}
	reader := bufio.NewReader(in)
	if action == "menu" {
		fmt.Fprintln(out, "Antigravity App：1. 接入/换 Key  2. 打开  3. 恢复官方登录\n请输入数字：")
		line, _ := reader.ReadString('\n')
		switch strings.TrimSpace(line) {
		case "1":
			action = "connect"
		case "2":
			action = "open"
		case "3":
			action = "restore"
		default:
			return 0
		}
	}
	flags := flag.NewFlagSet(action, flag.ContinueOnError)
	flags.SetOutput(out)
	app := flags.String("app", "", "官方 Antigravity App 或可执行文件的路径")
	if err := flags.Parse(args); err != nil || flags.NArg() != 0 {
		return 2
	}
	var result AntigravityResult
	switch action {
	case "connect":
		fmt.Fprintln(out, "请输入 Gemini 分组 API Key：")
		restore := func() {}
		if runtime.GOOS != "windows" {
			if f, ok := in.(*os.File); ok {
				if info, err := f.Stat(); err == nil && info.Mode()&os.ModeCharDevice != 0 {
					cmd := exec.Command("stty", "-echo")
					cmd.Stdin = f
					if cmd.Run() == nil {
						restore = func() { cmd := exec.Command("stty", "echo"); cmd.Stdin = f; _ = cmd.Run(); fmt.Fprintln(out) }
					}
				}
			}
		}
		line, _ := reader.ReadString('\n')
		restore()
		result = a.Connect(context.Background(), strings.TrimSpace(line), "", *app)
		fmt.Fprintln(out, result.Message)
		if result.Tone == ToneError {
			return 1
		}
		if runtime.GOOS != "windows" {
			result = a.Open(*app)
			fmt.Fprintln(out, result.Message)
			if result.Tone == ToneError {
				return 1
			}
		}
		return 0
	case "open":
		result = a.Open(*app)
	case "restore":
		result = a.Restore()
	case "status":
		status := a.Status()
		fmt.Fprintf(out, "Antigravity：%s %s，%d 个模型\n", status.State, status.Key, status.Models)
		return 0
	case "version":
		fmt.Fprintln(out, AntigravityLinuxVersion)
		return 0
	default:
		fmt.Fprintln(out, "用法：connect [--app 路径]、open [--app 路径]、restore、status、version")
		return 2
	}
	fmt.Fprintln(out, result.Message)
	if result.Tone == ToneError {
		return 1
	}
	return 0
}
