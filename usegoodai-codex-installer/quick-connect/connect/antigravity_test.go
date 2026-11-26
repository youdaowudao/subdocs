package connect

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"reflect"
	"strings"
	"testing"
	"time"
)

type agTestEnv struct {
	values map[string]antigravityEnvValue
	fail   bool
}

func (e *agTestEnv) Read() (map[string]antigravityEnvValue, error) {
	v := map[string]antigravityEnvValue{}
	for k, x := range e.values {
		v[k] = x
	}
	return v, nil
}
func (e *agTestEnv) Write(v map[string]antigravityEnvValue) error {
	if e.fail {
		return errors.New("test failure")
	}
	for k, x := range v {
		if x.Present {
			e.values[k] = x
		} else {
			delete(e.values, k)
		}
	}
	return nil
}
func TestAntigravityConnectAndRestore(t *testing.T) {
	var requests int
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests++
		if r.Method != "GET" || r.URL.Path != "/v1beta/models" {
			t.Error("not native model list")
			w.WriteHeader(404)
			return
		}
		if r.Header.Get("Authorization") == "Bearer sk-invalid" {
			w.WriteHeader(401)
			return
		}
		if !strings.HasPrefix(r.Header.Get("Authorization"), "Bearer sk-ag-") {
			t.Error("key missing")
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"models":[{"name":"models/gemini-4-hydrogen","supportedGenerationMethods":["generateContent"]},{"name":"models/gemini-3.8-flash"},{"name":"models/gemini-3.8-flash"},{"name":"models/gemini-3-pro-image"},{"name":"models/gpt-test"},{"name":"models/gemini-embedding"}]}`))
	}))
	defer srv.Close()
	store := &agTestEnv{values: map[string]antigravityEnvValue{"AGY_LLM_GATEWAY_URL": {Value: "https://previous.example", Type: 2, Present: true}, "UNRELATED": {Value: "untouched", Present: true}}}
	a := &Antigravity{Dir: t.TempDir(), BaseURL: srv.URL, Client: srv.Client(), Store: store, Now: time.Now}
	ctx := context.Background()
	if r := a.Connect(ctx, "sk-invalid", "", ""); r.Tone != ToneError {
		t.Fatal(r.Message)
	}
	if _, err := os.Stat(a.profilePath()); !os.IsNotExist(err) {
		t.Fatal("invalid key changed profile")
	}
	if r := a.Connect(ctx, "sk-ag-first", "测试", ""); r.Tone != ToneSuccess || r.Antigravity.Models != 2 || r.Antigravity.Name != "测试" || strings.Contains(r.Message, "sk-ag-first") {
		t.Fatalf("bad result %+v", r)
	}
	if store.values["AGY_LLM_GATEWAY_MODELS"].Value != "gemini-3.8-flash,gemini-4-hydrogen" || store.values["AGY_LLM_GATEWAY_WIRE_PROTOCOL"].Value != "genai" {
		t.Fatal("wrong native config")
	}
	if r := a.Connect(ctx, "sk-ag-second", "second", ""); r.Tone != ToneSuccess {
		t.Fatal(r.Message)
	}
	old, _ := os.ReadFile(a.profilePath())
	store.fail = true
	if r := a.Connect(ctx, "sk-ag-third", "", ""); r.Tone != ToneError {
		t.Fatal("failed write accepted")
	}
	now, _ := os.ReadFile(a.profilePath())
	if string(now) != string(old) {
		t.Fatal("failed connection replaced profile")
	}
	store.fail = false
	store.values["AGY_LLM_GATEWAY_MODELS"] = antigravityEnvValue{Value: "external-edit", Type: 1, Present: true}
	if r := a.Restore(); r.Tone != ToneSuccess {
		t.Fatal(r.Message)
	}
	if v := store.values["AGY_LLM_GATEWAY_URL"]; v.Value != "https://previous.example" || v.Type != 2 {
		t.Fatal("original env not restored")
	}
	if store.values["AGY_LLM_GATEWAY_MODELS"].Value != "external-edit" || store.values["UNRELATED"].Value != "untouched" {
		t.Fatal("unrelated or later edits lost")
	}
	if _, ok := store.values["AGY_LLM_GATEWAY_API_KEY"]; ok {
		t.Fatal("assistant key retained")
	}
	if requests != 4 {
		t.Fatalf("queries %d", requests)
	}
}
func TestAntigravityNativeModelsFiltering(t *testing.T) {
	got := AntigravityModels([]string{"gemini-4-hydrogen", "models/gemini-3.8-flash", "gemini-foo,bar", "gemini-tts", "gemini-3.8-flash", "claude", "gemini-image"})
	if !reflect.DeepEqual(got, []string{"gemini-3.8-flash", "gemini-4-hydrogen"}) {
		t.Fatal(got)
	}
	for _, raw := range []string{"v=1&app=antigravity", "v=2&app=antigravity&base_url=http://evil.example"} {
		if _, e := ParseImportLink("usegoodai://import?" + raw + "&key=sk-unit-test"); e == LinkOK {
			t.Fatal("accepted invalid link")
		}
	}
	link, e := ParseImportLink("usegoodai://import?v=2&app=antigravity&key=sk-unit-test&name=test")
	if e != LinkOK || link.App != LinkAppAntigravity || link.NeedsTarget {
		t.Fatal(link, e)
	}
}
func TestAntigravityProfileWithoutStore(t *testing.T) {
	s := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{"models": []map[string]string{{"name": "models/gemini-3.8-flash"}}})
	}))
	defer s.Close()
	a := &Antigravity{Dir: t.TempDir(), BaseURL: s.URL, Client: s.Client(), Now: time.Now}
	if r := a.Connect(context.Background(), "sk-local-test", "", ""); r.Tone != ToneSuccess {
		t.Fatal(r.Message)
	}
	p, e := a.read()
	if e != nil || p.Key != "sk-local-test" || p.Models[0] != "gemini-3.8-flash" {
		t.Fatal("profile error")
	}
	if r := a.Restore(); r.Tone != ToneSuccess || r.Antigravity.State != StateNone {
		t.Fatal(r)
	}
}
