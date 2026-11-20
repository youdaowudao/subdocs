//go:build !windows

package connect

import "fmt"

func runChinesePowerShell(string, []string, []string, string) (uint32, error) {
	return 0, fmt.Errorf("窗口中文化入口只用于 Windows")
}
