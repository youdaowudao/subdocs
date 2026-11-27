package connect

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

const messageAntigravityNotInstalled = "未在常用位置检测到官方 Antigravity App。已安装时可用 --app 指定程序路径；尚未安装时请到 https://antigravity.google/download 下载"

func resolveAntigravityPath(explicit string) (string, error) {
	var paths []string
	if explicit != "" {
		paths = []string{explicit}
	} else {
		userDir, _ := os.UserHomeDir()
		switch runtime.GOOS {
		case "darwin":
			paths = []string{filepath.Join(userDir, "Applications", "Antigravity.app"), "/Applications/Antigravity.app"}
		case "windows":
			paths = antigravityWindowsDefaultPaths()
		default:
			paths = []string{filepath.Join(userDir, "Antigravity-x64", "antigravity"), filepath.Join(userDir, "Downloads", "Antigravity-x64", "antigravity"), filepath.Join(userDir, "Applications", "Antigravity-x64", "antigravity"), "/opt/Antigravity-x64/antigravity"}
		}
		if p, err := exec.LookPath("antigravity"); err == nil {
			paths = append(paths, p)
		}
	}
	if path := firstAntigravityApp(paths); path != "" {
		return path, nil
	}
	if explicit == "" && runtime.GOOS == "windows" {
		// The official installer can register a custom install location. Do not
		// search the filesystem recursively or trust a stale registry entry.
		if path := firstAntigravityApp(antigravityWindowsRegisteredPaths()); path != "" {
			return path, nil
		}
	}
	return "", errors.New(messageAntigravityNotInstalled)
}

func firstAntigravityApp(paths []string) string {
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
		abs, err = filepath.EvalSymlinks(abs)
		if err != nil {
			continue
		}
		if name := strings.ToLower(filepath.Base(abs)); name != "antigravity" && name != "antigravity.exe" {
			continue
		}
		info, err := os.Stat(abs)
		if err != nil || !info.Mode().IsRegular() || (runtime.GOOS != "windows" && info.Mode()&0111 == 0) {
			continue
		}
		// The standalone App is Electron-packaged, whereas a same-named IDE
		// or CLI is not sufficient evidence of an installed App.
		resources := filepath.Join(filepath.Dir(abs), "resources")
		if runtime.GOOS == "darwin" {
			resources = filepath.Join(filepath.Dir(filepath.Dir(abs)), "Resources")
		}
		if marker, err := os.Stat(filepath.Join(resources, "app.asar")); err == nil && marker.Mode().IsRegular() {
			return abs
		}
	}
	return ""
}

// The official CLI installer uses agy (not the App executable name).
// Only check its standard installation location and the current PATH.
func detectAntigravityCLI() bool {
	var paths []string
	if runtime.GOOS == "windows" {
		if dir, err := os.UserCacheDir(); err == nil && dir != "" {
			paths = append(paths, filepath.Join(dir, "agy", "bin", "agy.exe"))
		}
	} else if home, err := os.UserHomeDir(); err == nil && home != "" {
		paths = append(paths, filepath.Join(home, ".local", "bin", "agy"))
	}
	if path, err := exec.LookPath("agy"); err == nil {
		paths = append(paths, path)
	}
	for _, path := range paths {
		if info, err := os.Stat(path); err == nil && info.Mode().IsRegular() && (runtime.GOOS == "windows" || info.Mode()&0111 != 0) {
			return true
		}
	}
	return false
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
