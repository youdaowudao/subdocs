package connect

import (
	"bytes"
	"encoding/json"
	"path/filepath"
	"strings"
	"testing"
)

func TestClaudeCommand(t *testing.T) {
	for _, installed := range []bool{false, true} {
		name := "Desktop only"
		if installed {
			name = "Desktop and CLI"
		}
		t.Run(name, func(t *testing.T) {
			service, _ := newClaudeService(t, `{"isValid":true,"remaining":3}`, claudeModelsAnswer)
			if installed {
				writeFile(t, filepath.Join(service.ClaudeCLI.AppData, "npm", "claude.cmd"), "@echo off")
				writeFile(t, service.ClaudeCLI.settingsPath(), `{"env":{"KEEP":"yes"},"permissions":{"allow":["Read"]}}`)
			}
			var output bytes.Buffer
			request, _ := json.Marshal(map[string]string{"key": fixtureKey})
			if code := RunClaudeCommand(bytes.NewReader(request), &output, service); code != 0 {
				t.Fatalf("exit %d: %s", code, output.String())
			}
			if ReadClaudeStatus(service.Claude).State != ClaudeUseGoodAI {
				t.Fatal("Desktop not connected")
			}
			if installed {
				if !service.ClaudeCLI.ConnectedWith(fixtureKey) {
					t.Fatal("CLI not connected")
				}
				settings := readJSON(t, service.ClaudeCLI.settingsPath())
				if settings["permissions"] == nil || settings["env"].(map[string]any)["KEEP"] != "yes" {
					t.Fatal("CLI settings lost")
				}
			} else {
				if fileExists(service.ClaudeCLI.settingsPath()) || strings.Contains(output.String(), "CLI") {
					t.Fatal("absent CLI mentioned or configured")
				}
			}
			if strings.Contains(output.String(), fixtureKey) {
				t.Fatal("key in output")
			}
		})
	}
}

func TestClaudeCommandCLIFailureKeepsDesktopAndRetries(t *testing.T) {
	service, _ := newClaudeService(t, `{"isValid":true}`, claudeModelsAnswer)
	writeFile(t, filepath.Join(service.ClaudeCLI.Home, ".local", "bin", "claude.exe"), "MZ")
	writeFile(t, service.ClaudeCLI.settingsPath(), "{broken")
	request, _ := json.Marshal(map[string]string{"key": fixtureKey})
	var output bytes.Buffer
	if code := RunClaudeCommand(bytes.NewReader(request), &output, service); code != 2 {
		t.Fatalf("exit %d: %s", code, output.String())
	}
	if ReadClaudeStatus(service.Claude).State != ClaudeUseGoodAI || readFile(t, service.ClaudeCLI.settingsPath()) != "{broken" {
		t.Fatal("partial failure lost original files")
	}
	if !strings.Contains(output.String(), "CLI 接入失败") {
		t.Fatal(output.String())
	}
	writeFile(t, service.ClaudeCLI.settingsPath(), `{}`)
	output.Reset()
	if code := RunClaudeCommand(bytes.NewReader(request), &output, service); code != 0 || !service.ClaudeCLI.ConnectedWith(fixtureKey) {
		t.Fatalf("retry %d: %s", code, output.String())
	}
}

func TestClaudeCommandRefusals(t *testing.T) {
	for _, request := range []string{"", "{", `{"key":"bad"}`, `{"key":"sk-wrong"}`} {
		t.Run(request, func(t *testing.T) {
			service, _ := newClaudeService(t, `{"isValid":true}`, claudeModelsAnswer)
			writeFile(t, filepath.Join(service.ClaudeCLI.Home, ".local", "bin", "claude.exe"), "MZ")
			var output bytes.Buffer
			if code := RunClaudeCommand(strings.NewReader(request), &output, service); code != 1 {
				t.Fatalf("exit %d: %s", code, output.String())
			}
			if fileExists(service.Claude.profilePath()) || fileExists(service.ClaudeCLI.settingsPath()) {
				t.Fatal("failure wrote configuration")
			}
		})
	}
	service, _ := newClaudeService(t, `{"isValid":true}`, claudeModelsAnswer)
	// Leave the old directory in place, but simulate an unregistered app.
	service.Claude = claudeAt(service.Claude.LocalAppData)
	var output bytes.Buffer
	if code := RunClaudeCommand(strings.NewReader(`{"key":"`+fixtureKey+`"}`), &output, service); code != 1 || !strings.Contains(output.String(), "没检测到 Claude 桌面版") {
		t.Fatalf("missing Desktop %d: %s", code, output.String())
	}
}

func TestClaudeCommandPowerShellBOM(t *testing.T) {
	service, _ := newClaudeService(t, `{"isValid":true}`, claudeModelsAnswer)
	request := "\xef\xbb\xbf" + `{"key":"` + fixtureKey + `"}` + "\r\n"
	var output bytes.Buffer
	if code := RunClaudeCommand(strings.NewReader(request), &output, service); code != 0 {
		t.Fatalf("PowerShell BOM request exit %d: %s", code, output.String())
	}
	if ReadClaudeStatus(service.Claude).State != ClaudeUseGoodAI {
		t.Fatal("Desktop not connected")
	}
}
