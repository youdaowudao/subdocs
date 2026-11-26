package connect

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

const messageAntigravityNotInstalled = "没有找到 Antigravity App，请先从 https://antigravity.google/download 安装官方桌面版，或使用 --app 指定其程序路径"

func resolveAntigravityPath(explicit string) (string, error) {
	var paths []string
	if explicit != "" {
		paths = []string{explicit}
	} else {
		userDir, _ := os.UserHomeDir()
		cache, _ := os.UserCacheDir()
		switch runtime.GOOS {
		case "darwin":
			paths = []string{filepath.Join(userDir, "Applications", "Antigravity.app"), "/Applications/Antigravity.app"}
		case "windows":
			paths = []string{filepath.Join(cache, "Programs", "Antigravity", "Antigravity.exe"), filepath.Join(os.Getenv("ProgramFiles"), "Antigravity", "Antigravity.exe"), filepath.Join(os.Getenv("ProgramFiles(x86)"), "Antigravity", "Antigravity.exe")}
		default:
			paths = []string{filepath.Join(userDir, "Antigravity-x64", "antigravity"), filepath.Join(userDir, "Downloads", "Antigravity-x64", "antigravity"), filepath.Join(userDir, "Applications", "Antigravity-x64", "antigravity"), "/opt/Antigravity-x64/antigravity"}
		}
		if p, err := exec.LookPath("antigravity"); err == nil {
			paths = append(paths, p)
		}
	}
	for _, p := range paths {
		if p == "" {
			continue
		}
		if runtime.GOOS == "darwin" && strings.EqualFold(filepath.Ext(p), ".app") {
			for _, name := range []string{"Antigravity", "antigravity"} {
				binary := filepath.Join(p, "Contents", "MacOS", name)
				if info, err := os.Stat(binary); err == nil && !info.IsDir() {
					p = binary
					break
				}
			}
		}
		abs, err := filepath.Abs(p)
		if err != nil {
			continue
		}
		if name := strings.ToLower(filepath.Base(abs)); name != "antigravity" && name != "antigravity.exe" {
			continue
		}
		if info, err := os.Stat(abs); err == nil && !info.IsDir() && (runtime.GOOS == "windows" || info.Mode()&0111 != 0) {
			return abs, nil
		}
	}
	return "", errors.New(messageAntigravityNotInstalled)
}
func launchAntigravity(path string, env []string) error {
	cmd := exec.Command(path)
	cmd.Env = env
	cmd.Dir = filepath.Dir(path)
	if err := cmd.Start(); err != nil {
		return err
	}
	return cmd.Process.Release()
}
