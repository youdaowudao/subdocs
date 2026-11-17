package connect

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"io"
	"strings"
)

// RunClaudeCommand is the Windows helper's pipe protocol. Keys are received
// through stdin and are never included in the response or process arguments.
func RunClaudeCommand(input io.Reader, output io.Writer, service *Service) int {
	var request struct {
		Key string `json:"key"`
	}
	result := Result{Tone: ToneError, Message: "没有收到完整的接入请求，请重新运行命令。"}
	reader := bufio.NewReader(io.LimitReader(input, 4096))
	// .NET Framework's redirected StandardInput may begin with a UTF-8 BOM.
	if prefix, _ := reader.Peek(3); bytes.Equal(prefix, []byte{0xef, 0xbb, 0xbf}) {
		_, _ = reader.Discard(3)
	}
	if err := json.NewDecoder(reader).Decode(&request); err == nil {
		result = service.ConnectClaude(context.Background(), request.Key, "")
	}
	if result.Message == MessageClaudeNotInstalled {
		result.Message = "没检测到 Claude 桌面版。先从 https://claude.com/download 安装，再重新运行接入命令。"
	}
	result.Message = strings.NewReplacer(
		"再点一次「一键连接 Claude」", "重新运行接入命令",
		"再点「一键连接 Claude」", "重新运行接入命令",
		"稍后再点一次", "稍后重新运行接入命令",
	).Replace(result.Message)
	response := struct {
		Version string `json:"version"`
		Tone    string `json:"tone"`
		Message string `json:"message"`
	}{Version, result.Tone, result.Message}
	if json.NewEncoder(output).Encode(response) != nil {
		return 1
	}
	if result.Tone == ToneError {
		return 1
	}
	if result.Tone == ToneWarning {
		return 2
	}
	return 0
}
