package main

import (
	"context"
	"sync"

	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/runtime"

	"usegoodai-quick-connect/connect"
)

// App is the bridge the page calls through window.go.main.App. The page
// never passes an address: links it may open are fixed here.
type App struct {
	ctx     context.Context
	service *connect.Service

	mu              sync.Mutex
	pendingLinks    []string
	pageReady       bool
	assistantUpdate assistantRelease
}

func newApp(service *connect.Service, launchLink string) *App {
	app := &App{service: service}
	if launchLink != "" {
		app.pendingLinks = append(app.pendingLinks, launchLink)
	}
	return app
}

func (a *App) startup(ctx context.Context) {
	a.mu.Lock()
	a.ctx = ctx
	a.mu.Unlock()
}

// secondInstance receives the arguments of a later launch, normally a link
// opened from the website, and brings this window to the front.
func (a *App) secondInstance(data options.SecondInstanceData) {
	link := connect.FindImportLink(data.Args)
	a.mu.Lock()
	ctx := a.ctx
	ready := a.pageReady
	if link != "" && !ready {
		a.pendingLinks = append(a.pendingLinks, link)
	}
	a.mu.Unlock()
	if ctx == nil {
		return
	}
	runtime.WindowUnminimise(ctx)
	runtime.WindowShow(ctx)
	runtime.WindowSetAlwaysOnTop(ctx, true)
	runtime.WindowSetAlwaysOnTop(ctx, false)
	if link != "" && ready {
		runtime.EventsEmit(ctx, "import-link", link)
	}
}

// Info is static product information for the page.
type Info struct {
	Name    string `json:"name"`
	Version string `json:"version"`
	QQ      string `json:"qq"`
	QQName  string `json:"qqName"`
}

func (a *App) Info() Info {
	return Info{Name: connect.ProductName, Version: connect.Version, QQ: connect.QQGroupNumber, QQName: connect.QQGroupName}
}

// TakeLaunchLinks returns any links queued before the page subscribed.
func (a *App) TakeLaunchLinks() []string {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.pageReady = true
	links := a.pendingLinks
	a.pendingLinks = nil
	return links
}

func (a *App) Status() connect.Status { return a.service.Status() }

func (a *App) ParseLink(raw string) connect.LinkResult { return a.service.ParseLink(raw) }

// Connect is the button: a pasted key has no name.
func (a *App) Connect(key string) connect.Result { return a.service.Connect(a.ctx, key, "") }

// Import connects a key from an import link and remembers its name.
func (a *App) Import(key, name string) connect.Result { return a.service.Connect(a.ctx, key, name) }

func (a *App) Restore() connect.Result { return a.service.Restore() }

func (a *App) ImageStatus() connect.ImageStatus { return a.service.ImageStatus() }

func (a *App) ModelsStatus() connect.ModelsStatus { return a.service.ModelsStatus() }

// ImportModels runs the domestic model import after the window asked for
// confirmation; RemoveModels takes the imported models out again.
func (a *App) ImportModels() connect.Result { return a.service.ImportModels(a.ctx, false) }

func (a *App) RemoveModels() connect.Result { return a.service.ImportModels(a.ctx, true) }

func (a *App) RunChinese() connect.Result { return a.service.RunChinese() }

// InstallImage is the button in image mode: a pasted key has no name.
func (a *App) InstallImage(key string) connect.Result {
	return a.service.InstallImage(a.ctx, key, "")
}

// UpdateImage reinstalls the image tool with the key it already holds.
func (a *App) UpdateImage() connect.Result { return a.service.UpdateImage(a.ctx) }

// ImportImage installs the image tool with a key from a website import.
func (a *App) ImportImage(key, name string) connect.Result {
	return a.service.InstallImage(a.ctx, key, name)
}

// ClipboardKey returns the clipboard text when it is a UseGoodAI key.
func (a *App) ClipboardKey() string {
	text, err := runtime.ClipboardGetText(a.ctx)
	if err != nil {
		return ""
	}
	if key, ok := connect.NormalizeKey(text); ok {
		return key
	}
	return ""
}

func (a *App) ClaudeStatus() connect.ClaudeStatus { return a.service.ClaudeStatus() }

// ConnectClaude is the button on the Claude page: a pasted key has no name.
func (a *App) ConnectClaude(key string) connect.Result { return a.connectClaude(key, "") }

// ImportClaude connects Claude Desktop with a key from an app=claude link.
func (a *App) ImportClaude(key, name string) connect.Result { return a.connectClaude(key, name) }

// connectClaude uses the same automatic Desktop/CLI flow as the command.
func (a *App) connectClaude(key, name string) connect.Result {
	return a.service.ConnectClaude(a.ctx, key, name)
}

func (a *App) RestoreClaude() connect.Result { return a.service.RestoreClaude() }

// OpenDownload opens the official download page of "codex" (ChatGPT, which
// carries Codex) or "claude". Addresses are fixed here.
func (a *App) OpenDownload(app string) {
	switch app {
	case "codex":
		runtime.BrowserOpenURL(a.ctx, connect.ChatGPTDownloadURL)
	case "claude":
		runtime.BrowserOpenURL(a.ctx, connect.ClaudeDownloadURL)
	}
}

func (a *App) CopyGroupNumber() bool {
	return runtime.ClipboardSetText(a.ctx, connect.QQGroupNumber) == nil
}

func (a *App) JoinGroup() { runtime.BrowserOpenURL(a.ctx, connect.QQGroupURL) }

func (a *App) OpenSite() { runtime.BrowserOpenURL(a.ctx, connect.OfficialSite) }

func (a *App) OpenAPIKeys() { runtime.BrowserOpenURL(a.ctx, connect.OfficialSite+"/keys") }

func (a *App) CheckAssistantUpdate() string {
	if assistantUpdateDirectory() == "" {
		return ""
	}
	release, err := newAssistantUpdater().check(a.ctx, connect.Version)
	if err != nil || release.Version == "" {
		return ""
	}
	a.mu.Lock()
	a.assistantUpdate = release
	a.mu.Unlock()
	return release.Version
}

func (a *App) DownloadAssistantUpdate() string {
	a.mu.Lock()
	release := a.assistantUpdate
	a.mu.Unlock()
	if err := newAssistantUpdater().stage(a.ctx, release, connect.Version, assistantUpdateDirectory()); err != nil {
		return "更新未完成：" + err.Error()
	}
	return ""
}

func (a *App) RestartAssistantUpdate() string {
	a.mu.Lock()
	release := a.assistantUpdate
	a.mu.Unlock()
	directory := assistantUpdateDirectory()
	if directory == "" || !release.newerThan(connect.Version) {
		return "没有已下载的新版助手。"
	}
	path := release.file(directory)
	if err := verifyAssistantProgram(path, release); err != nil {
		return "无法打开新版助手：" + err.Error()
	}
	if err := startUpdatedAssistant(path); err != nil {
		return "无法打开新版助手：" + err.Error()
	}
	runtime.Quit(a.ctx)
	return ""
}
