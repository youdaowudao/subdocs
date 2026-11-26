package connect

import (
	"context"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"testing"
	"time"
)

func TestAntigravityDesktop(t *testing.T) {
	app := os.Getenv("AGY_TEST_APP")
	if app == "" {
		t.Skip("only on the explicit real desktop workflow")
	}
	evidence := os.Getenv("AGY_TEST_EVIDENCE")
	if evidence == "" {
		t.Fatal("missing evidence directory")
	}
	if err := os.MkdirAll(evidence, 0700); err != nil {
		t.Fatal(err)
	}
	var lock sync.Mutex
	var requests []string
	conversation := make(chan struct{}, 1)
	const fake = "sk-actions-antigravity-fake"
	gateway := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		passed := r.Header.Get("Authorization") == "Bearer "+fake
		lock.Lock()
		requests = append(requests, fmt.Sprintf("%s %s bearer=%t agent=%s", r.Method, r.URL.Path, passed, r.UserAgent()))
		lock.Unlock()
		if !passed {
			w.WriteHeader(401)
			return
		}
		if r.Method == "GET" && r.URL.Path == "/v1beta/models" {
			_ = json.NewEncoder(w).Encode(map[string]any{"models": []map[string]any{{"name": "models/gemini-3.8-flash"}, {"name": "models/gemini-4-hydrogen"}}})
			return
		}
		if strings.HasPrefix(r.URL.Path, "/v1beta:") {
			w.Write([]byte("{}"))
			return
		}
		if r.Method != "POST" || !strings.HasSuffix(r.URL.Path, ":streamGenerateContent") {
			w.WriteHeader(404)
			return
		}
		var body map[string]json.RawMessage
		if json.NewDecoder(r.Body).Decode(&body) != nil || body["contents"] == nil {
			w.WriteHeader(400)
			return
		}
		w.Header().Set("Content-Type", "text/event-stream")
		fmt.Fprint(w, "data: {\"candidates\":[{\"index\":0,\"content\":{\"role\":\"model\",\"parts\":[{\"text\":\"UseGoodAI native desktop test passed\"}]},\"finishReason\":\"STOP\"}],\"usageMetadata\":{\"promptTokenCount\":12,\"candidatesTokenCount\":8,\"totalTokenCount\":20}}\n\n")
		if f, ok := w.(http.Flusher); ok {
			f.Flush()
		}
		if body["tools"] != nil {
			select {
			case conversation <- struct{}{}:
			default:
			}
		}
	}))
	defer gateway.Close()
	defer func() {
		lock.Lock()
		defer lock.Unlock()
		_ = os.WriteFile(filepath.Join(evidence, "requests.txt"), []byte(strings.Join(requests, "\n")+"\n"), 0600)
	}()
	ca := filepath.Join(t.TempDir(), "mock-ca.pem")
	if err := os.WriteFile(ca, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: gateway.Certificate().Raw}), 0600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("AGY_LLM_GATEWAY_CA_CERT", ca)
	a := NewAntigravity(gateway.URL)
	a.Dir = t.TempDir()
	a.Client = gateway.Client()
	var child *exec.Cmd
	cdpPort := ""
	if runtime.GOOS == "windows" && os.Getenv("AGY_TEST_CDP_SCRIPT") != "" {
		listener, err := net.Listen("tcp", "127.0.0.1:0")
		if err != nil {
			t.Fatal(err)
		}
		cdpPort = fmt.Sprint(listener.Addr().(*net.TCPAddr).Port)
		listener.Close()
	}
	a.launch = func(path string, env []string) error {
		args := []string{}
		if cdpPort != "" {
			args = append(args, "--remote-debugging-port="+cdpPort, "--remote-debugging-address=127.0.0.1")
		}
		child = exec.Command(path, args...)
		child.Env = env
		child.Dir = filepath.Dir(path)
		log, err := os.Create(filepath.Join(evidence, "app-output.txt"))
		if err != nil {
			return err
		}
		defer log.Close()
		child.Stdout = log
		child.Stderr = log
		return child.Start()
	}
	defer func() {
		if child != nil && child.Process != nil {
			_ = child.Process.Kill()
			_ = child.Wait()
		}
		if restored := a.Restore(); restored.Tone == ToneError {
			t.Error(restored.Message)
		}
	}()
	result := a.Connect(context.Background(), fake, "Actions fixture", app)
	if result.Tone != ToneSuccess || result.Antigravity.Models != 2 {
		t.Fatal(result.Message)
	}
	if result = a.Open(app); result.Tone != ToneSuccess {
		t.Fatal(result.Message)
	}
	t.Log("native official desktop process started, with fake-key Gemini gateway")
	// The UI command operates the actual window and sends one test message.
	// Never treat a process-only launch as a successful desktop conversation.
	script := os.Getenv("AGY_TEST_INTERACT")
	if script == "" {
		t.Fatal("missing GUI interaction script")
	}
	var cmd *exec.Cmd
	if runtime.GOOS == "windows" {
		cmd = exec.Command("powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script)
	} else {
		cmd = exec.Command("/bin/bash", script)
	}
	cmd.Env = append(os.Environ(), "AGY_TEST_EVIDENCE="+evidence, "AGY_TEST_PID="+fmt.Sprint(child.Process.Pid))
	output, err := cmd.CombinedOutput()
	_ = os.WriteFile(filepath.Join(evidence, "interaction.txt"), output, 0600)
	if err != nil {
		t.Logf("GUI interaction did not complete: %v; %s", err, output)
	}
	if cdpPort != "" && err != nil {
		t.Log("Native foreground is blocked; attempting interaction with the actual rendered Electron window via local CDP.")
		debug := exec.Command("node", os.Getenv("AGY_TEST_CDP_SCRIPT"))
		debug.Env = append(os.Environ(), "AGY_TEST_CDP_PORT="+cdpPort, "AGY_TEST_EVIDENCE="+evidence)
		debugOut, debugErr := debug.CombinedOutput()
		_ = os.WriteFile(filepath.Join(evidence, "interaction-cdp.txt"), debugOut, 0600)
		if debugErr != nil {
			t.Logf("Renderer interaction failed: %v; %s", debugErr, debugOut)
		} else {
			t.Log(string(debugOut))
		}
	}
	select {
	case <-conversation:
		t.Log("actual GUI conversation reached Gemini native mock with correct key and tools")
	case <-time.After(30 * time.Second):
		t.Fatal("no native GUI conversation request reached the fixture")
	}
}
