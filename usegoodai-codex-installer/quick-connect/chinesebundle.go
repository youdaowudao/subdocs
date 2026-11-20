package main

import (
	"embed"

	"usegoodai-quick-connect/connect"
)

//go:embed all:chinesetool
var chineseBundle embed.FS

func bundledChineseScript(cacheDir, logDir string) *connect.BundledChineseScript {
	script, err := chineseBundle.ReadFile("chinesetool/chinese.ps1")
	if err != nil {
		return nil
	}
	wrapper, err := chineseBundle.ReadFile("chinesetool/run.ps1")
	if err != nil {
		return nil
	}
	return &connect.BundledChineseScript{Script: script, Wrapper: wrapper, CacheDir: cacheDir, LogDir: logDir}
}
