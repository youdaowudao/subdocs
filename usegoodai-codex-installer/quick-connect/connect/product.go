// Package connect holds everything the quick-connect assistant does besides
// drawing its window: link parsing, key checks and the Codex files it writes.
// It has no GUI dependency, so the whole flow is tested on Linux.
package connect

const (
	ProductName = "UseGoodAI中转快速接入助手"
	Version     = "1.1.6"

	// BaseURL is the only address the assistant ever writes or calls. Import
	// links never carry an address.
	BaseURL      = "https://api.usegoodai.com"
	OfficialSite = "https://api.usegoodai.com"
	CodexModel   = "gpt-6.1-sol"

	QQGroupNumber = "1020015031"
	QQGroupName   = "好用AI客服通知群"
	QQGroupURL    = "https://qm.qq.com/q/o80PFAbey4"

	ProtocolScheme = "usegoodai"

	// Official download pages offered when the app is not installed.
	ChatGPTDownloadURL = "https://chatgpt.com/download/"
	ClaudeDownloadURL  = "https://claude.com/download"
)
