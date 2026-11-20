package connect

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type ChineseRunner interface {
	Run() (logPath string, err error)
}

// BundledChineseScript carries the published script without modifying it.
// The wrapper owns only the visible console, transcript and close countdown.
type BundledChineseScript struct {
	Script, Wrapper  []byte
	CacheDir, LogDir string
	PowerShell       string
	launch           func(string, []string, []string, string) (uint32, error)
}

func (b *BundledChineseScript) unpack() (string, string, error) {
	if b == nil || len(b.Script) == 0 || len(b.Wrapper) == 0 {
		return "", "", fmt.Errorf("助手没有内置中文化工具")
	}
	if err := os.MkdirAll(b.CacheDir, 0o700); err != nil {
		return "", "", fmt.Errorf("无法准备中文化目录：%s", reason(err))
	}
	for _, file := range []struct {
		name string
		data []byte
	}{{"chinese.ps1", b.Script}, {"run.ps1", b.Wrapper}} {
		path := filepath.Join(b.CacheDir, file.name)
		if existing, err := os.ReadFile(path); err == nil && bytes.Equal(existing, file.data) {
			continue
		}
		temporary, err := os.CreateTemp(b.CacheDir, ".chinese-*")
		if err != nil {
			return "", "", fmt.Errorf("无法准备中文化文件：%s", reason(err))
		}
		name := temporary.Name()
		_, writeErr := temporary.Write(file.data)
		closeErr := temporary.Close()
		if writeErr == nil {
			writeErr = closeErr
		}
		if writeErr == nil {
			writeErr = os.Rename(name, path)
		}
		if writeErr != nil {
			_ = os.Remove(name)
			return "", "", fmt.Errorf("无法准备中文化文件：%s", reason(writeErr))
		}
	}
	return filepath.Join(b.CacheDir, "chinese.ps1"), filepath.Join(b.CacheDir, "run.ps1"), nil
}

func (b *BundledChineseScript) Run() (string, error) {
	script, wrapper, err := b.unpack()
	if err != nil {
		return "", err
	}
	if err := os.MkdirAll(b.LogDir, 0o700); err != nil {
		return "", fmt.Errorf("无法创建中文化记录目录：%s", reason(err))
	}
	log, err := os.CreateTemp(b.LogDir, "中文化_"+time.Now().Format("20060102-150405")+"_*.txt")
	if err != nil {
		return "", fmt.Errorf("无法创建中文化记录：%s", reason(err))
	}
	path := log.Name()
	// Windows PowerShell 5.1 appends transcripts as ASCII without a BOM.
	_, writeErr := log.Write([]byte{0xef, 0xbb, 0xbf})
	closeErr := log.Close()
	if writeErr != nil || closeErr != nil {
		return path, fmt.Errorf("无法写入中文化记录")
	}
	env := make([]string, 0, len(os.Environ())+2)
	for _, entry := range os.Environ() {
		key, _, _ := strings.Cut(entry, "=")
		if !strings.EqualFold(key, "USEGOODAI_CHINESE_SCRIPT") && !strings.EqualFold(key, "USEGOODAI_CHINESE_LOG") {
			env = append(env, entry)
		}
	}
	env = append(env, "USEGOODAI_CHINESE_SCRIPT="+script, "USEGOODAI_CHINESE_LOG="+path)
	launch := b.launch
	if launch == nil {
		launch = runChinesePowerShell
	}
	code, err := launch(b.PowerShell, []string{"-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", wrapper}, env, b.CacheDir)
	if err != nil {
		_ = appendChineseFailure(path, "无法打开 PowerShell。请确认系统 Windows PowerShell 可用。")
		return path, fmt.Errorf("无法打开 PowerShell，运行记录：%s", path)
	}
	if code != 0 {
		return path, fmt.Errorf("中文化未完成或操作窗口已提前关闭。运行记录：%s", path)
	}
	return path, nil
}

func appendChineseFailure(path, message string) error {
	file, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	defer file.Close()
	_, err = fmt.Fprintln(file, "[失败] "+message)
	return err
}

func (s *Service) RunChinese() Result {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.Chinese == nil {
		return s.result(ToneError, "这个版本的助手没有内置中文化工具。")
	}
	path, err := s.Chinese.Run()
	if err != nil {
		return s.result(ToneError, err.Error())
	}
	return s.result(ToneSuccess, "中文设置已完成，请自己重新打开 ChatGPT。运行记录："+path)
}
