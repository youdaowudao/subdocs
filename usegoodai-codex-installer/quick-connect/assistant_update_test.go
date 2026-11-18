package main

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func TestAssistantUpdateKeepsCurrentLauncherUntilVerifiedWindowIsReady(t *testing.T) {
	program, err := os.ReadFile(filepath.Join("..", "..", "docs", "public", "download", assistantProgramFile))
	if err != nil {
		t.Fatal(err)
	}
	release := assistantRelease{Version: "1.10.0", Size: int64(len(program)), SHA256: fmt.Sprintf("%x", sha256.Sum256(program))}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "" {
			t.Error("the update request must not carry credentials")
		}
		switch r.URL.Path {
		case "/" + assistantReleaseFile:
			_ = json.NewEncoder(w).Encode(release)
		case "/" + assistantProgramFile:
			_, _ = w.Write(program)
		default:
			http.NotFound(w, r)
		}
	}))
	defer server.Close()
	updater := newAssistantUpdater()
	updater.download = server.URL + "/"
	ctx := context.Background()
	current := "1.9.0"
	next, err := updater.check(ctx, current)
	if err != nil || next != release {
		t.Fatalf("check: got %+v, %v", next, err)
	}
	for _, installed := range []string{release.Version, "1.10.1"} {
		if next, err := updater.check(ctx, installed); err != nil || next.Version != "" {
			t.Fatalf("offered a reinstall or downgrade: %+v, %v", next, err)
		}
	}

	directory := t.TempDir()
	corrupt := release
	corrupt.SHA256 = fmt.Sprintf("%064d", 1)
	if err := updater.stage(ctx, corrupt, current, directory); err == nil {
		t.Fatal("a bad checksum was accepted")
	}
	files, err := os.ReadDir(directory)
	if err != nil || len(files) != 0 {
		t.Fatalf("failed download left files: %v, %v", files, err)
	}
	if err := updater.stage(ctx, release, current, directory); err != nil {
		t.Fatal(err)
	}
	if path := readActiveAssistant(directory, current); path != "" {
		t.Fatalf("program is active before opening its first window: %s", path)
	}
	programPath := release.file(directory)
	if err := activateAssistant(directory, programPath, release.Version); err != nil {
		t.Fatal(err)
	}
	if path := readActiveAssistant(directory, current); path != programPath {
		t.Fatalf("old launcher did not pick up the new program: %q", path)
	}
	if err := os.WriteFile(programPath, []byte("damaged"), 0o700); err != nil {
		t.Fatal(err)
	}
	if path := readActiveAssistant(directory, current); path != "" {
		t.Fatalf("old launcher accepted a damaged cached program: %q", path)
	}
}

func TestAssistantUpdateDoesNotFollowDownloadRedirect(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/"+assistantReleaseFile {
			t.Error("followed a redirect")
		}
		http.Redirect(w, r, "/different-origin", http.StatusFound)
	}))
	defer server.Close()
	updater := newAssistantUpdater()
	updater.download = server.URL + "/"
	if _, err := updater.check(context.Background(), "1.1.20"); err == nil {
		t.Fatal("expected a redirect error")
	}
}
