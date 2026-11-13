package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"syscall"
	"time"

	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/logger"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"
	"github.com/wailsapp/wails/v2/pkg/options/windows"

	"usegoodai-quick-connect/connect"
)

// singleInstanceID keeps one window per user; later launches hand their
// link to it.
const singleInstanceID = "usegoodai-quick-connect-5c0f2a7e"

func main() {
	// 双击或导入链接先进入启动守护（guard.go），由它启动带窗口变量的窗口进程。
	eventName := os.Getenv(windowEnv)
	if eventName == "" {
		os.Exit(runGuard())
	}
	runWindow(eventName)
}

// runWindow is the window process the guard started.
func runWindow(eventName string) {
	// The guard started the record; append to it.
	record := openStartRecord(filepath.Join(webviewDataPath(), "logs"), true)
	defer record.close()
	record.crashOutput()
	log.SetOutput(record)
	log.SetFlags(0)
	if record.file != nil {
		// go-webview2 prints its errors with fmt.Printf before exiting; a
		// window program has no console, so without this they are lost.
		os.Stdout = record.file
		os.Stderr = record.file
	}
	profile := os.Getenv(profileEnv)
	if profile == "" {
		profile = webviewDataPath()
	}
	record.stage("窗口进程", fmt.Sprintf("进程 %d，WebView2 数据目录 %s", os.Getpid(), filepath.Base(profile)))
	launchLink := connect.FindImportLink(os.Args[1:])

	// A link opened while the window exists starts a second process that only
	// forwards the link. Let the running window take the foreground.
	allowAnyForegroundWindow()

	codexHome, _ := connect.CodexHome()
	imageHome, _ := connect.ImageCodexHome()
	service := &connect.Service{
		CodexHome:   codexHome,
		BaseURL:     connect.BaseURL,
		Client:      connect.NewHTTPClient(),
		Now:         time.Now,
		StopClients: connect.StopClients,
		NamesFile:   connect.NamesFile(),
		ImageHome:   imageHome,
	}
	// A nil *BundledImageTool must not become a non-nil interface.
	if tool := bundledImageTool(filepath.Join(webviewDataPath(), "image-tool")); tool != nil {
		service.Image = tool
	}
	service.ModelsHome = imageHome // the script also follows CODEX_HOME
	if script := bundledModelsScript(filepath.Join(webviewDataPath(), "models-tool")); script != nil {
		service.Models = script
	}
	localAppData, _ := os.UserCacheDir()    // %LOCALAPPDATA%
	roamingAppData, _ := os.UserConfigDir() // %APPDATA%
	userHome, _ := os.UserHomeDir()
	service.Claude = connect.ClaudeDesktop{LocalAppData: localAppData}
	service.ClaudeCLI = connect.ClaudeCode{Home: userHome, AppData: roamingAppData}
	service.StopClaude = connect.StopClaudeDesktop
	app := newApp(service, launchLink)

	record.stage("创建窗口", "")
	err := wails.Run(&options.App{
		Title:            connect.ProductName,
		Width:            420,
		Height:           690,
		DisableResize:    true,
		BackgroundColour: &options.RGBA{R: 244, G: 247, B: 250, A: 255},
		AssetServer:      &assetserver.Options{Assets: frontendFiles()},
		OnStartup: func(ctx context.Context) {
			record.stage("窗口已建立", "")
			app.startup(ctx)
		},
		OnDomReady: func(context.Context) {
			record.stage("页面就绪", "")
			signalReady(eventName)
		},
		OnShutdown:         func(context.Context) { record.stage("正常关闭", "") },
		Bind:               []interface{}{app},
		Logger:             recordLogger{record: record},
		LogLevel:           logger.ERROR,
		LogLevelProduction: logger.ERROR,
		SingleInstanceLock: &options.SingleInstanceLock{
			UniqueId:               singleInstanceID,
			OnSecondInstanceLaunch: app.secondInstance,
		},
		Windows: &windows.Options{
			Theme:               windows.Light,
			WebviewUserDataPath: profile,
			// 稳妥优先，所有电脑一律：页面用 CPU 绘制，不用显卡（显卡驱动出错时 WebView2 会崩溃）；
			// 关掉 WebView2 的渲染进程代码完整性检查：360、火绒、电脑管家等安全软件会往 WebView2
			// 里注入未签名的 DLL，开着检查时 WebView2 进程会被自己结束。页面只显示本程序自带的内容。
			WebviewGpuIsDisabled:                true,
			WebviewDisableRendererCodeIntegrity: true,
			Messages:                            chineseMessages(),
		},
	})
	if err != nil {
		record.stage("启动失败", err.Error())
		message := err.Error()
		if record.path != "" {
			message += "\n\n启动记录：" + record.path
		}
		showMessage(connect.ProductName, message, mbOK|mbIconWarning)
		// The user has been told; the guard stops without a second dialog.
		os.Exit(exitShown)
	}
}

func webviewDataPath() string {
	base, err := os.UserCacheDir() // %LOCALAPPDATA%
	if err != nil {
		return ""
	}
	return filepath.Join(base, "UseGoodAI", "QuickConnect")
}

func allowAnyForegroundWindow() {
	const asfwAny = ^uintptr(0)
	_, _, _ = syscall.NewLazyDLL("user32.dll").NewProc("AllowSetForegroundWindow").Call(asfwAny)
}

// chineseMessages are shown by Wails before the window exists, for example
// when the WebView2 runtime is missing. The build uses the "browser"
// strategy: a message box, then the official download page.
func chineseMessages() *windows.Messages {
	const download = "https://developer.microsoft.com/zh-cn/microsoft-edge/webview2/"
	return &windows.Messages{
		InstallationRequired: "需要先安装 Microsoft Edge WebView2 运行库。点“确定”打开下载页面：" + download,
		UpdateRequired:       "需要更新 Microsoft Edge WebView2 运行库。点“确定”打开下载页面：" + download,
		MissingRequirements:  connect.ProductName,
		Webview2NotInstalled: "没有安装 Microsoft Edge WebView2 运行库。",
		Error:                connect.ProductName,
		FailedToInstall:      "请安装 WebView2 运行库后，再打开" + connect.ProductName + "。",
		DownloadPage:         "需要先安装 Microsoft Edge WebView2 运行库。点“确定”打开下载页面（" + download + "），安装后再打开助手。最低版本：",
		PressOKToInstall:     "点“确定”安装。",
		ContactAdmin:         "需要 Microsoft Edge WebView2 运行库，请联系电脑管理员安装。",
		InvalidFixedWebview2: "WebView2 运行库不可用，请重新安装：" + download,
		WebView2ProcessCrash: "WebView2 出错，请关闭后重新打开助手。",
	}
}
