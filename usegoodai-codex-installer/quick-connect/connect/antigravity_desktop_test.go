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
	if shell := os.Getenv("AGY_TEST_SCRIPT"); shell != "" {
		// Exercise the actual Shell entry point, with just its fixed URL
		// substituted in a disposable test copy. Never let production keys
		// or a user-supplied endpoint enter the shipped script.
		source, err := os.ReadFile(shell)
		if err != nil {
			t.Fatal(err)
		}
		if strings.Count(string(source), "BASE_URL=\"https://api.usegoodai.com\"") != 1 {
			t.Fatal("missing fixed endpoint")
		}
		testScript := filepath.Join(t.TempDir(), "antigravity.sh")
		testContents := strings.Replace(string(source), "BASE_URL=\"https://api.usegoodai.com\"", "BASE_URL=\""+gateway.URL+"\"", 1)
		if err = os.WriteFile(testScript, []byte(testContents), 0700); err != nil {
			t.Fatal(err)
		}
		profile := t.TempDir()
		env := append(os.Environ(), "USEGOODAI_KEY="+fake, "CURL_CA_BUNDLE="+ca, "XDG_CONFIG_HOME="+profile, "HOME="+profile)
		// Test the same default command the customer runs, not the explicit
		// --app escape hatch. Expose the actual installed App at the normal
		// location inside the isolated test home, without copying binaries.
		appDirectory := filepath.Dir(app)
		defaultPath := filepath.Join(profile, "Downloads", filepath.Base(appDirectory))
		if runtime.GOOS == "darwin" {
			appDirectory = app
			defaultPath = filepath.Join(profile, "Applications", "Antigravity.app")
		}
		if err := os.MkdirAll(filepath.Dir(defaultPath), 0700); err != nil {
			t.Fatal(err)
		}
		if err := os.Symlink(appDirectory, defaultPath); err != nil {
			t.Fatal(err)
		}
		run := exec.Command("/bin/bash", testScript)
		run.Env = env
		output, err := run.CombinedOutput()
		_ = os.WriteFile(filepath.Join(evidence, "shell.txt"), output, 0600)
		if err != nil {
			t.Fatalf("actual Shell entry failed: %v; %s", err, output)
		}
		configPath := filepath.Join(profile, "UseGoodAI", "Antigravity", "connection.json")
		if runtime.GOOS == "darwin" {
			configPath = filepath.Join(profile, "Library", "Application Support", "UseGoodAI", "Antigravity", "connection.json")
		}
		data, err := os.ReadFile(configPath)
		if err != nil {
			t.Fatal(err)
		}
		var profileData antigravityProfile
		if json.Unmarshal(data, &profileData) != nil || profileData.Key != fake || len(profileData.Models) != 2 {
			t.Fatal("Shell profile wrong")
		}
		defer func() {
			restore := exec.Command("/bin/bash", testScript, "restore")
			restore.Env = env
			if out, err := restore.CombinedOutput(); err != nil {
				t.Errorf("shell restore: %v %s", err, out)
			}
			if _, err := os.Stat(configPath); !os.IsNotExist(err) {
				t.Error("shell restore retained profile")
			}
		}()
		t.Log("actual Shell command queried native model list, saved user profile, and launched official App")
	} else {
		result := a.Connect(context.Background(), fake, "Actions fixture", app)
		if result.Tone != ToneSuccess || result.Antigravity.Models != 2 {
			t.Fatal(result.Message)
		}
		if result = a.Open(app); result.Tone != ToneSuccess {
			t.Fatal(result.Message)
		}
		t.Log("native official desktop process started, with fake-key Gemini gateway")
	}

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
	pid := ""
	if child != nil && child.Process != nil {
		pid = fmt.Sprint(child.Process.Pid)
	}
	cmd.Env = append(os.Environ(), "AGY_TEST_EVIDENCE="+evidence, "AGY_TEST_PID="+pid)
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
