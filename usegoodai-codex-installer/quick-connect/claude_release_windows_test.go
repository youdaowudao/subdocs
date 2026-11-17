package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha1"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"io"
	"math/big"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"usegoodai-quick-connect/connect"
)

// The unmodified release program still uses the production URL. In this test
// its HTTPS traffic goes to a local CONNECT proxy and a temporary test CA in
// this disposable runner's LocalMachine root store. Cleanup removes that CA.
// No real key, model request, account or upstream service is involved.
func claudeReleaseProxy(t *testing.T) string {
	t.Helper()
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now()
	serial, _ := rand.Int(rand.Reader, new(big.Int).Lsh(big.NewInt(1), 120))
	root := &x509.Certificate{SerialNumber: serial, Subject: pkix.Name{CommonName: "UseGoodAI disposable command test"}, NotBefore: now.Add(-time.Hour), NotAfter: now.Add(time.Hour), IsCA: true, BasicConstraintsValid: true, KeyUsage: x509.KeyUsageCertSign | x509.KeyUsageDigitalSignature}
	der, err := x509.CreateCertificate(rand.Reader, root, root, &key.PublicKey, key)
	if err != nil {
		t.Fatal(err)
	}
	root, err = x509.ParseCertificate(der)
	if err != nil {
		t.Fatal(err)
	}
	leaf := &x509.Certificate{SerialNumber: big.NewInt(2), DNSNames: []string{"api.usegoodai.com"}, NotBefore: root.NotBefore, NotAfter: root.NotAfter, KeyUsage: x509.KeyUsageDigitalSignature | x509.KeyUsageKeyEncipherment, ExtKeyUsage: []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth}}
	leafDER, err := x509.CreateCertificate(rand.Reader, leaf, root, &key.PublicKey, key)
	if err != nil {
		t.Fatal(err)
	}
	certificate, err := tls.X509KeyPair(pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: leafDER}), pem.EncodeToMemory(&pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(key)}))
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(t.TempDir(), "command-root.cer")
	if err := os.WriteFile(path, der, 0o600); err != nil {
		t.Fatal(err)
	}
	thumbprint := fmt.Sprintf("%X", sha1.Sum(der))
	certificateAction := func(script string) error {
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer cancel()
		command := exec.CommandContext(ctx, "powershell.exe", "-NoProfile", "-NonInteractive", "-Command", "$ErrorActionPreference='Stop'; "+script)
		command.WaitDelay = 5 * time.Second
		command.Env = append(os.Environ(), "TEST_ROOT_CERT="+path, "TEST_ROOT_THUMB="+thumbprint)
		output, err := command.CombinedOutput()
		if err != nil {
			return fmt.Errorf("%w: %s", err, output)
		}
		return nil
	}
	// CurrentUser Root can open an interactive Windows trust dialog. The
	// disposable hosted runner permits its machine store without that dialog.
	storeOpen := "$store=New-Object Security.Cryptography.X509Certificates.X509Store('Root','LocalMachine'); $store.Open('ReadWrite'); "
	if err := certificateAction(storeOpen + "try { $cert=New-Object Security.Cryptography.X509Certificates.X509Certificate2($env:TEST_ROOT_CERT); $store.Add($cert) } finally { $store.Close() }"); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if err := certificateAction(storeOpen + "try { foreach ($cert in $store.Certificates.Find('FindByThumbprint',$env:TEST_ROOT_THUMB,$false)) { $store.Remove($cert) } } finally { $store.Close() }"); err != nil {
			t.Error(err)
		}
	})
	backend := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if r.Header.Get("Authorization") != "Bearer sk-native-claude-command-fixture" {
			w.WriteHeader(401)
			return
		}
		switch r.URL.Path {
		case "/v1/usage":
			_, _ = io.WriteString(w, `{"isValid":true,"remaining":3}`)
		case "/v1/models":
			_, _ = io.WriteString(w, `{"data":[{"id":"claude-opus-5-5"},{"id":"claude-sonnet-5-5"}]}`)
		default:
			w.WriteHeader(404)
		}
	}))
	backend.TLS = &tls.Config{Certificates: []tls.Certificate{certificate}}
	backend.StartTLS()
	t.Cleanup(backend.Close)
	proxy := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "CONNECT" || r.Host != "api.usegoodai.com:443" {
			http.Error(w, "unexpected destination", 403)
			return
		}
		upstream, err := net.Dial("tcp", backend.Listener.Addr().String())
		if err != nil {
			http.Error(w, "local backend unavailable", 502)
			return
		}
		client, buffered, err := w.(http.Hijacker).Hijack()
		if err != nil {
			upstream.Close()
			return
		}
		_, _ = buffered.WriteString("HTTP/1.1 200 Connection Established\r\n\r\n")
		_ = buffered.Flush()
		go func() { _, _ = io.Copy(upstream, client); upstream.Close() }()
		_, _ = io.Copy(client, upstream)
		client.Close()
	}))
	t.Cleanup(proxy.Close)
	return proxy.URL
}

func TestClaudeReleaseWritesBothConfigurations(t *testing.T) {
	program := os.Getenv("QUICK_CONNECT_EXE")
	if program == "" {
		t.Skip("set QUICK_CONNECT_EXE to test the release program")
	}
	proxy := claudeReleaseProxy(t)
	for _, cli := range []bool{false, true} {
		t.Run(fmt.Sprintf("CLI=%t", cli), func(t *testing.T) {
			directory := filepath.Join(t.TempDir(), "中文 用户 空格")
			packageDir := filepath.Join(directory, "Packages", "Claude_pzs8sxrjxfjjc")
			if err := os.MkdirAll(packageDir, 0o700); err != nil {
				t.Fatal(err)
			}
			settings := filepath.Join(directory, ".claude", "settings.json")
			if cli {
				if err := os.MkdirAll(filepath.Join(directory, ".local", "bin"), 0o700); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(filepath.Join(directory, ".local", "bin", "claude.exe"), []byte("fixture; never executed"), 0o600); err != nil {
					t.Fatal(err)
				}
				if err := os.MkdirAll(filepath.Dir(settings), 0o700); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(settings, []byte(`{"permissions":{"allow":["Read"]},"env":{"KEEP":"yes"}}`), 0o600); err != nil {
					t.Fatal(err)
				}
			}
			ctx, cancel := context.WithTimeout(context.Background(), 40*time.Second)
			defer cancel()
			child := exec.CommandContext(ctx, program, "--claude-connect")
			child.Env = append(os.Environ(), "LOCALAPPDATA="+directory, "APPDATA="+directory, "USERPROFILE="+directory, "HTTPS_PROXY="+proxy, "NO_PROXY=127.0.0.1,localhost")
			child.Stdin = strings.NewReader(`{"key":"sk-native-claude-command-fixture"}`)
			output, err := child.CombinedOutput()
			if err != nil {
				t.Fatalf("release command: %v: %s", err, output)
			}
			var reply struct{ Version, Tone, Message string }
			if err := json.Unmarshal(output, &reply); err != nil || reply.Version != connect.Version || reply.Tone != "success" {
				t.Fatalf("reply %v: %s", err, output)
			}
			if bytes.Contains(output, []byte("sk-native-claude-command-fixture")) {
				t.Fatal("key leaked to output")
			}
			profile, err := os.ReadFile(filepath.Join(directory, "Claude-3p", "configLibrary", connect.ClaudeProfileID+".json"))
			if err != nil || !bytes.Contains(profile, []byte(`"https://api.usegoodai.com"`)) || !bytes.Contains(profile, []byte("claude-opus-5-5")) {
				t.Fatalf("Desktop configuration: %v: %s", err, profile)
			}
			data, err := os.ReadFile(settings)
			if cli {
				if err != nil || !bytes.Contains(data, []byte("ANTHROPIC_AUTH_TOKEN")) || !bytes.Contains(data, []byte(`"KEEP": "yes"`)) || !bytes.Contains(data, []byte("permissions")) {
					t.Fatalf("CLI configuration: %v: %s", err, data)
				}
				backups, _ := filepath.Glob(settings + ".bak.*")
				if len(backups) != 1 {
					t.Fatalf("backups: %v", backups)
				}
			} else if !os.IsNotExist(err) || strings.Contains(reply.Message, "CLI") {
				t.Fatalf("absent CLI touched: %v: %s", err, output)
			}
		})
	}
}
