package connect

import (
	"context"
	"encoding/json"
	"io"
)

// RunClaudeCommand is the Windows helper's pipe protocol. Keys are received
// through stdin and are never included in the response or process arguments.
func RunClaudeCommand(input io.Reader, output io.Writer, service *Service) int {
	var request struct {
		Key string `json:"key"`
	}
	result := Result{Tone: ToneError, Message: "没有收到完整的接入请求，请重新运行命令。"}
	if err := json.NewDecoder(io.LimitReader(input, 4096)).Decode(&request); err == nil {
		result = service.ConnectClaude(context.Background(), request.Key, "")
	}
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
