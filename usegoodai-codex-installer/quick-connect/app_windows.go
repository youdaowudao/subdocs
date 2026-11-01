package main

import (
	"context"
	"os"
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

	mu          sync.Mutex
	pendingLink string
	pageReady   bool
}

func newApp(service *connect.Service, launchLink string) *App {
	return &App{service: service, pendingLink: launchLink}
}

func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
	if exe, err := os.Executable(); err == nil {
		_ = connect.RegisterProtocol(exe)
	}
}

// secondInstance receives the arguments of a later launch, normally a link
// opened from the website, and brings this window to the front.
func (a *App) secondInstance(data options.SecondInstanceData) {
	if a.ctx == nil {
		return
	}
	runtime.WindowUnminimise(a.ctx)
	runtime.WindowShow(a.ctx)
	runtime.WindowSetAlwaysOnTop(a.ctx, true)
	runtime.WindowSetAlwaysOnTop(a.ctx, false)
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
		runtime.EventsEmit(a.ctx, "import-link", link)
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

func (a *App) Connect(key string) connect.Result { return a.service.Connect(a.ctx, key) }

func (a *App) Restore() connect.Result { return a.service.Restore() }

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

func (a *App) CopyGroupNumber() bool {
	return runtime.ClipboardSetText(a.ctx, connect.QQGroupNumber) == nil
}

func (a *App) JoinGroup() { runtime.BrowserOpenURL(a.ctx, connect.QQGroupURL) }

func (a *App) OpenSite() { runtime.BrowserOpenURL(a.ctx, connect.OfficialSite) }
