package main

import (
	"context"
	"os"
	"sync"
	"time"

	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/runtime"

	"usegoodai-quick-connect/connect"
)

// App is the bridge the page calls through window.go.main.App. The page
// never passes an address: links it may open are fixed here.
type App struct {
	ctx     context.Context
	service *connect.Service
	work    activity // operations a later launch must not cut off

	mu          sync.Mutex
	pendingLink string
	pageReady   bool
}

func newApp(service *connect.Service, launchLink string) *App {
	return &App{service: service, pendingLink: launchLink}
}

func (a *App) startup(ctx context.Context) {
	a.mu.Lock()
	a.ctx = ctx
	a.mu.Unlock()
	if exe, err := os.Executable(); err == nil {
		_ = connect.RegisterProtocol(exe)
	}
}

// context is the window's context once it started, read from the thread
// that answers later launches.
func (a *App) context() context.Context {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.ctx
}

// takeover answers a later launch of this helper: an idle window closes so
// the new one takes over; a busy one comes to the front and stays.
func (a *App) takeover() uintptr {
	if a.work.busy() {
		go a.showBusy()
		return replyBusy
	}
	go a.quitForTakeover()
	return replyQuitting
}

func (a *App) quitForTakeover() {
	if ctx := a.context(); ctx != nil {
		go runtime.Quit(ctx)
	}
	// A stuck page must not keep the new window waiting.
	time.Sleep(3 * time.Second)
	os.Exit(0)
}

func (a *App) showBusy() {
	ctx := a.context()
	if ctx == nil {
		return
	}
	bringToFront(ctx)
	_, _ = runtime.MessageDialog(ctx, runtime.MessageDialogOptions{
		Type:    runtime.InfoDialog,
		Title:   connect.ProductName,
		Message: "助手正在处理上一步，请等它完成后再打开，或再点一次网站上的导入。",
	})
}

// launched receives the arguments an older helper (1.1.3 and earlier)
// hands over when it is opened while this window runs.
func (a *App) launched(args []string) {
	a.secondInstance(options.SecondInstanceData{Args: args})
}

func bringToFront(ctx context.Context) {
	runtime.WindowUnminimise(ctx)
	runtime.WindowShow(ctx)
	runtime.WindowSetAlwaysOnTop(ctx, true)
	runtime.WindowSetAlwaysOnTop(ctx, false)
}

// secondInstance receives the arguments of a later launch, normally a link
// opened from the website, and brings this window to the front.
func (a *App) secondInstance(data options.SecondInstanceData) {
	ctx := a.context()
	if ctx == nil {
		return
	}
	bringToFront(ctx)
	link := connect.FindImportLink(data.Args)
	if link == "" {
		return
	}
	a.mu.Lock()
	ready := a.pageReady
	if !ready {
		a.pendingLink = link
	}
	a.mu.Unlock()
	if ready {
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

// TakeLaunchLink returns the link this window was started with, once, and
// marks the page ready for links from later launches.
func (a *App) TakeLaunchLink() string {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.pageReady = true
	link := a.pendingLink
	a.pendingLink = ""
	return link
}

func (a *App) Status() connect.Status { return a.service.Status() }

func (a *App) ParseLink(raw string) connect.LinkResult { return a.service.ParseLink(raw) }

// Connect is the button: a pasted key has no name.
func (a *App) Connect(key string) connect.Result {
	defer a.work.begin()()
	return a.service.Connect(a.ctx, key, "")
}

// Import connects a key from an import link and remembers its name.
func (a *App) Import(key, name string) connect.Result {
	defer a.work.begin()()
	return a.service.Connect(a.ctx, key, name)
}

func (a *App) Restore() connect.Result {
	defer a.work.begin()()
	return a.service.Restore()
}

func (a *App) ImageStatus() connect.ImageStatus { return a.service.ImageStatus() }

func (a *App) ModelsStatus() connect.ModelsStatus { return a.service.ModelsStatus() }

// ImportModels runs the domestic model import after the window asked for
// confirmation; RemoveModels takes the imported models out again.
func (a *App) ImportModels() connect.Result {
	defer a.work.begin()()
	return a.service.ImportModels(a.ctx, false)
}

func (a *App) RemoveModels() connect.Result {
	defer a.work.begin()()
	return a.service.ImportModels(a.ctx, true)
}

// InstallImage is the button in image mode: a pasted key has no name.
func (a *App) InstallImage(key string) connect.Result {
	defer a.work.begin()()
	return a.service.InstallImage(a.ctx, key, "")
}

// UpdateImage reinstalls the image tool with the key it already holds.
func (a *App) UpdateImage() connect.Result {
	defer a.work.begin()()
	return a.service.UpdateImage(a.ctx)
}

// ImportImage installs the image tool with a key from an import link that
// arrived while the window was in image mode.
func (a *App) ImportImage(key, name string) connect.Result {
	defer a.work.begin()()
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

// connectClaude connects Claude Desktop, then, when the Claude Code CLI is
// installed and not yet on this key, asks whether to connect it too.
func (a *App) connectClaude(key, name string) connect.Result {
	defer a.work.begin()()
	result := a.service.ConnectClaude(a.ctx, key, name)
	if !result.OfferCLI {
		return result
	}
	result.OfferCLI = false
	answer, err := runtime.MessageDialog(a.ctx, runtime.MessageDialogOptions{
		Type:    runtime.QuestionDialog,
		Title:   "检测到 Claude Code CLI",
		Message: "检测到 Claude Code CLI，是否同时接入 UseGoodAI？\n\n会把同一个密钥写入 Claude Code CLI 的设置（用户文件夹下的 .claude\\settings.json），其它设置保留。",
	})
	if err != nil || (answer != "Yes" && answer != "是") {
		return result
	}
	cli := a.service.ConnectClaudeCode(key)
	cli.Message = result.Message + "\n" + cli.Message
	if result.Tone != connect.ToneSuccess && cli.Tone == connect.ToneSuccess {
		cli.Tone = result.Tone
	}
	return cli
}

func (a *App) RestoreClaude() connect.Result {
	defer a.work.begin()()
	return a.service.RestoreClaude()
}

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
