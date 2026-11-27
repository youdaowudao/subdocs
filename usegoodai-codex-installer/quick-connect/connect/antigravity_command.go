package connect

import (
	"bufio"
	"context"
	"flag"
	"fmt"
	"io"
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
		line, _ := reader.ReadString('\n')
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
		fmt.Fprintf(out, "Antigravity：%s %s\n", status.State, status.Key)
		return 0
	case "version":
		if runtime.GOOS == "darwin" {
			fmt.Fprintln(out, MacVersion)
		} else {
			fmt.Fprintln(out, Version)
		}
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
