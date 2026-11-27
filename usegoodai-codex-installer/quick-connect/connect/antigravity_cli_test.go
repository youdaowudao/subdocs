package connect

import (
	"context"
	"encoding/json"
	"encoding/pem"
	"fmt"
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

func TestAntigravityCLI(t *testing.T) {
	cli := os.Getenv("AGY_TEST_CLI")
	if cli == "" {
		t.Skip("only with the official native CLI")
	}
	evidence := os.Getenv("AGY_TEST_EVIDENCE")
	if evidence == "" {
		t.Fatal("missing evidence directory")
	}
	if err := os.MkdirAll(evidence, 0700); err != nil {
		t.Fatal(err)
	}
	const key = "sk-actions-cli-fake"
	const reply = "UseGoodAI native CLI test passed"
	var mu sync.Mutex
	var records []string
	var native bool
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		valid := r.Header.Get("Authorization") == "Bearer "+key
		mu.Lock()
		records = append(records, fmt.Sprintf("%s %s bearer=%t", r.Method, r.URL.Path, valid))
		mu.Unlock()
		if !valid {
			w.WriteHeader(401)
			return
		}
		if r.Method == "GET" && r.URL.Path == "/v1beta/models" {
			_ = json.NewEncoder(w).Encode(map[string]any{"models": []map[string]string{{"name": "models/gemini-3.8-flash"}, {"name": "models/gemini-4-hydrogen"}}})
			return
		}
		if r.Method != "POST" || !strings.HasPrefix(r.URL.Path, "/v1beta/models/") || !strings.HasSuffix(r.URL.Path, ":streamGenerateContent") {
			w.WriteHeader(404)
			return
		}
		var data map[string]json.RawMessage
		if json.NewDecoder(r.Body).Decode(&data) != nil || data["contents"] == nil || data["tools"] == nil {
			w.WriteHeader(400)
			return
		}
		mu.Lock()
		native = true
		mu.Unlock()
		w.Header().Set("Content-Type", "text/event-stream")
		fmt.Fprintf(w, "data: {\"candidates\":[{\"index\":0,\"content\":{\"role\":\"model\",\"parts\":[{\"text\":%q}]},\"finishReason\":\"STOP\"}],\"usageMetadata\":{\"promptTokenCount\":12,\"candidatesTokenCount\":8,\"totalTokenCount\":20}}\n\n", reply)
	}))
	defer server.Close()
	defer func() {
		mu.Lock()
		defer mu.Unlock()
		_ = os.WriteFile(filepath.Join(evidence, "cli-requests.txt"), []byte(strings.Join(records, "\n")+"\n"), 0600)
	}()
	root := t.TempDir()
	ca := filepath.Join(root, "mock-ca.pem")
	if err := os.WriteFile(ca, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: server.Certificate().Raw}), 0600); err != nil {
		t.Fatal(err)
	}
	home := filepath.Join(root, "home")
	if err := os.MkdirAll(home, 0700); err != nil {
		t.Fatal(err)
	}
	// Deliberately exclude inherited gateway variables: the actual candidate
	// configuration must supply these, not the test process.
	var env []string
	for _, entry := range os.Environ() {
		name, _, _ := strings.Cut(entry, "=")
		if !strings.HasPrefix(strings.ToUpper(name), "AGY_LLM_GATEWAY_") {
			env = append(env, entry)
		}
	}
	env = append(env, "HOME="+home, "XDG_CONFIG_HOME="+filepath.Join(home, ".config"), "AGY_LLM_GATEWAY_CA_CERT="+ca, "CURL_CA_BUNDLE="+ca)
	args := []string{"--print-timeout", "60s", "-p", "Reply with the test confirmation."}
	var cmd *exec.Cmd
	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Second)
	defer cancel()
	if runtime.GOOS == "windows" {
		a := NewAntigravity(server.URL)
		a.Dir = filepath.Join(root, "profile")
		a.Client = server.Client()
		before, err := a.Store.Read()
		if err != nil {
			t.Fatal(err)
		}
		defer func() {
			if restored := a.Restore(); restored.Tone == ToneError {
				t.Error(restored.Message)
			}
			after, err := a.Store.Read()
			if err != nil {
				t.Error(err)
				return
			}
			for _, name := range antigravityVariables {
				if before[name] != after[name] {
					t.Errorf("not restored: %s", name)
				}
			}
		}()
		if r := a.Connect(ctx, key, "CLI test", ""); r.Tone != ToneSuccess || !r.Antigravity.CLIDetected {
			t.Fatal(r.Message)
		}
		stored, err := a.Store.Read()
		if err != nil {
			t.Fatal(err)
		}
		for _, name := range antigravityVariables {
			env = append(env, name+"="+stored[name].Value)
		}
		env = append(env, "USERPROFILE="+home)
		cmd = exec.CommandContext(ctx, cli, args...)
	} else {
		source, err := os.ReadFile(os.Getenv("AGY_TEST_SCRIPT"))
		if err != nil {
			t.Fatal(err)
		}
		old := `BASE_URL="https://api.usegoodai.com"`
		if strings.Count(string(source), old) != 1 {
			t.Fatal("missing fixed endpoint")
		}
		script := strings.Replace(string(source), old, `BASE_URL="`+server.URL+`"`, 1)
		bin := filepath.Join(home, ".local", "bin")
		if err := os.MkdirAll(bin, 0700); err != nil {
			t.Fatal(err)
		}
		if err := os.Symlink(cli, filepath.Join(bin, "agy")); err != nil {
			t.Fatal(err)
		}
		shell := "/bin/bash"
		if runtime.GOOS == "darwin" {
			shell = "/bin/zsh"
		}
		env = append(env, "SHELL="+shell, "ZDOTDIR="+home, "PATH="+bin+string(os.PathListSeparator)+os.Getenv("PATH"))
		setup := exec.CommandContext(ctx, "/bin/bash", "-s", "--", "cli")
		setup.Stdin = strings.NewReader(script)
		setup.Env = append(append([]string{}, env...), "USEGOODAI_KEY="+key)
		output, err := setup.CombinedOutput()
		_ = os.WriteFile(filepath.Join(evidence, "cli-setup.txt"), output, 0600)
		if err != nil {
			t.Fatalf("actual command: %v %s", err, output)
		}
		defer func() {
			restore := exec.Command("/bin/bash", "-s", "--", "cli-restore")
			restore.Stdin = strings.NewReader(script)
			restore.Env = env
			if out, err := restore.CombinedOutput(); err != nil {
				t.Errorf("restore: %v %s", err, out)
			}
		}()
		// Open a new normal interactive shell, and use the original agy command.
		launch := `agy --print-timeout 60s -p "Reply with the test confirmation."`
		if runtime.GOOS == "darwin" {
			cmd = exec.CommandContext(ctx, shell, "-i", "-c", launch)
		} else {
			cmd = exec.CommandContext(ctx, shell, "--noprofile", "--rcfile", filepath.Join(home, ".bashrc"), "-i", "-c", launch)
		}
	}
	cmd.Env = env
	cmd.Dir = root
	output, err := cmd.CombinedOutput()
	_ = os.WriteFile(filepath.Join(evidence, "cli-output.txt"), output, 0600)
	if err != nil || !strings.Contains(string(output), reply) {
		t.Fatalf("official CLI conversation: %v %s", err, output)
	}
	mu.Lock()
	verified := native
	mu.Unlock()
	if !verified {
		t.Fatal("no Gemini-native stream with tools and correct Bearer key")
	}
	t.Log("official CLI received the mock response via native Gemini, using the actual candidate configuration")
}
