package main

import (
	"context"
	"crypto/sha256"
	"debug/pe"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"time"

	"usegoodai-quick-connect/connect"
)

const (
	assistantReleaseFile = "usegoodai-quick-connect-windows-x64.json"
	assistantProgramFile = "usegoodai-quick-connect-windows-x64.exe"
	assistantActiveFile  = "active.json"
	maxAssistantSize     = 25 << 20
)

var (
	assistantUpdateDownloadURL = docsURL + "/download/"
	assistantVersionPattern    = regexp.MustCompile(`^(0|[1-9][0-9]{0,5})\.(0|[1-9][0-9]{0,5})\.(0|[1-9][0-9]{0,5})$`)
	assistantDigestPattern     = regexp.MustCompile(`^[a-f0-9]{64}$`)
)

type assistantRelease struct {
	Version string `json:"version"`
	SHA256  string `json:"sha256"`
	Size    int64  `json:"size"`
}

func (release assistantRelease) valid() bool {
	return assistantVersionPattern.MatchString(release.Version) &&
		assistantDigestPattern.MatchString(release.SHA256) && release.Size > 0 && release.Size <= maxAssistantSize
}

func (release assistantRelease) newerThan(current string) bool {
	if !release.valid() || !assistantVersionPattern.MatchString(current) {
		return false
	}
	parts, installed := strings.Split(release.Version, "."), strings.Split(current, ".")
	return slices.CompareFunc(parts, installed, func(left, right string) int {
		a, _ := strconv.Atoi(left)
		b, _ := strconv.Atoi(right)
		return a - b
	}) > 0
}

func (release assistantRelease) file(directory string) string {
	return filepath.Join(directory, release.Version+"-"+release.SHA256+".exe")
}

func readAssistantRelease(reader io.Reader) (assistantRelease, error) {
	var release assistantRelease
	data, err := io.ReadAll(io.LimitReader(reader, 4097))
	if err != nil || len(data) > 4096 || json.Unmarshal(data, &release) != nil || !release.valid() {
		return assistantRelease{}, errors.New("助手版本信息无效")
	}
	return release, nil
}

type assistantUpdater struct {
	client   *http.Client
	download string
}

func newAssistantUpdater() assistantUpdater {
	client := connect.NewHTTPClient()
	client.Timeout = 2 * time.Minute
	return assistantUpdater{client: client, download: assistantUpdateDownloadURL}
}

func (updater assistantUpdater) check(ctx context.Context, current string) (assistantRelease, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	body, err := updater.open(ctx, assistantReleaseFile)
	if err != nil {
		return assistantRelease{}, err
	}
	defer body.Close()
	release, err := readAssistantRelease(body)
	if err != nil || !release.newerThan(current) {
		return assistantRelease{}, err
	}
	return release, nil
}

func (updater assistantUpdater) open(ctx context.Context, name string) (io.ReadCloser, error) {
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, updater.download+name, nil)
	if err != nil {
		return nil, err
	}
	response, err := updater.client.Do(request)
	if err != nil {
		return nil, err
	}
	if response.StatusCode != http.StatusOK {
		response.Body.Close()
		return nil, fmt.Errorf("下载站返回 HTTP %d", response.StatusCode)
	}
	return response.Body, nil
}

func (updater assistantUpdater) stage(ctx context.Context, release assistantRelease, current, directory string) error {
	if !release.newerThan(current) || directory == "" {
		return errors.New("没有可安装的助手更新")
	}
	target := release.file(directory)
	if verifyAssistantProgram(target, release) == nil {
		return nil
	}
	body, err := updater.open(ctx, assistantProgramFile+"?version="+release.Version)
	if err != nil {
		return err
	}
	defer body.Close()
	if err := os.MkdirAll(directory, 0o700); err != nil {
		return err
	}
	candidate, err := os.CreateTemp(directory, "assistant-*.part")
	if err != nil {
		return err
	}
	defer os.Remove(candidate.Name())
	_, writeErr := io.Copy(candidate, io.LimitReader(body, release.Size+1))
	closeErr := candidate.Close()
	if err := errors.Join(writeErr, closeErr); err != nil {
		return err
	}
	if err := verifyAssistantProgram(candidate.Name(), release); err != nil {
		return err
	}
	return os.Rename(candidate.Name(), target)
}

func verifyAssistantProgram(path string, release assistantRelease) error {
	file, err := os.Open(path)
	if err != nil {
		return err
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil || !info.Mode().IsRegular() || info.Size() != release.Size {
		return errors.New("下载的助手文件大小不正确")
	}
	digest := sha256.New()
	count, err := io.Copy(digest, io.LimitReader(file, release.Size+1))
	if err != nil || count != release.Size || hex.EncodeToString(digest.Sum(nil)) != release.SHA256 {
		return errors.New("下载的助手文件未通过 SHA-256 校验")
	}
	program, err := pe.NewFile(file)
	if err != nil {
		return errors.New("下载的文件不是 Windows 助手程序")
	}
	header, ok := program.OptionalHeader.(*pe.OptionalHeader64)
	if !ok || program.Machine != pe.IMAGE_FILE_MACHINE_AMD64 || header.Subsystem != 2 {
		return errors.New("下载的文件不适用于此 Windows 助手")
	}
	return nil
}

func readActiveAssistant(directory, current string) string {
	if directory == "" {
		return ""
	}
	file, err := os.Open(filepath.Join(directory, assistantActiveFile))
	if err != nil {
		return ""
	}
	defer file.Close()
	release, err := readAssistantRelease(file)
	if err != nil || !release.newerThan(current) {
		return ""
	}
	path := release.file(directory)
	if verifyAssistantProgram(path, release) != nil {
		return ""
	}
	return path
}

// Record the new program only after its window has opened. The old download
// remains a usable launcher even if the first start of the new program fails.
func activateAssistant(directory, exe, version string) error {
	if directory == "" || !strings.EqualFold(filepath.Dir(exe), directory) {
		return nil
	}
	prefix := version + "-"
	base := filepath.Base(exe)
	if !strings.HasPrefix(base, prefix) || !strings.HasSuffix(base, ".exe") {
		return nil
	}
	info, err := os.Stat(exe)
	if err != nil {
		return err
	}
	release := assistantRelease{
		Version: version, Size: info.Size(),
		SHA256: strings.TrimSuffix(strings.TrimPrefix(base, prefix), ".exe"),
	}
	if !release.valid() {
		return errors.New("助手更新文件名无效")
	}
	if err := verifyAssistantProgram(exe, release); err != nil {
		return err
	}
	file, err := os.CreateTemp(directory, "assistant-active-*.part")
	if err != nil {
		return err
	}
	defer os.Remove(file.Name())
	writeErr := json.NewEncoder(file).Encode(release)
	if err := errors.Join(writeErr, file.Close()); err != nil {
		return err
	}
	return os.Rename(file.Name(), filepath.Join(directory, assistantActiveFile))
}
