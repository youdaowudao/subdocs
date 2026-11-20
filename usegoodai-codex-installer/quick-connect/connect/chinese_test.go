package connect

import (
	"bytes"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

func TestChineseRunPreservesScriptAndKeepsSeparateUTF8Records(t *testing.T) {
	root := t.TempDir()
	original := []byte("# 原脚本原始字节\n")
	b := &BundledChineseScript{Script: original, Wrapper: []byte("wrapper"), CacheDir: filepath.Join(root, "中文 空格"), LogDir: filepath.Join(root, "记录")}
	var seen []string
	b.launch = func(_ string, args, env []string, directory string) (uint32, error) {
		if !slices.Contains(args, "-File") || slices.Contains(args, "-NonInteractive") || directory != b.CacheDir {
			t.Fatal("visible wrapper arguments", args, directory)
		}
		var logPath string
		for _, entry := range env {
			if strings.HasPrefix(entry, "USEGOODAI_CHINESE_LOG=") {
				logPath = strings.TrimPrefix(entry, "USEGOODAI_CHINESE_LOG=")
			}
		}
		bom, err := os.ReadFile(logPath)
		if err != nil || !bytes.Equal(bom, []byte{0xef, 0xbb, 0xbf}) {
			t.Fatal("PowerShell 5.1 transcript must start with a UTF-8 BOM", err)
		}
		seen = append(seen, logPath)
		return 0, nil
	}
	for i := 0; i < 2; i++ {
		if _, err := b.Run(); err != nil {
			t.Fatal(err)
		}
	}
	if len(seen) != 2 || seen[0] == seen[1] {
		t.Fatal("a later operation must not overwrite its predecessor", seen)
	}
	data, err := os.ReadFile(filepath.Join(b.CacheDir, "chinese.ps1"))
	if err != nil || !bytes.Equal(data, original) {
		t.Fatal("published payload changed", err)
	}
}

func TestChineseCannotRunWithoutARecord(t *testing.T) {
	root := t.TempDir()
	blocked := filepath.Join(root, "not-a-directory")
	if err := os.WriteFile(blocked, []byte("keep"), 0o600); err != nil {
		t.Fatal(err)
	}
	b := &BundledChineseScript{Script: []byte("script"), Wrapper: []byte("wrapper"), CacheDir: filepath.Join(root, "tool"), LogDir: blocked}
	b.launch = func(string, []string, []string, string) (uint32, error) {
		t.Fatal("must not execute an operation that cannot be recorded")
		return 0, nil
	}
	if _, err := b.Run(); err == nil || !strings.Contains(err.Error(), "记录") {
		t.Fatal(err)
	}
}

func TestChineseRejectsFailedOrClosedConsole(t *testing.T) {
	for _, launchError := range []error{nil, errors.New("launch failed")} {
		root := t.TempDir()
		b := &BundledChineseScript{Script: []byte("script"), Wrapper: []byte("wrapper"), CacheDir: filepath.Join(root, "tool"), LogDir: filepath.Join(root, "logs")}
		b.launch = func(string, []string, []string, string) (uint32, error) { return 1, launchError }
		path, err := b.Run()
		if err == nil || path == "" {
			t.Fatal("failed operation reported success or lost its log", path, err)
		}
	}
}
