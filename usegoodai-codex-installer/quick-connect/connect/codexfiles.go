package connect

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// configContent is byte for byte what install/codex.ps1 writes: LF line ends
// and no newline after the last line, because the script uses a here-string.
const configContent = `model_provider = "OpenAI"
model = "` + CodexModel + `"
review_model = "` + CodexModel + `"
model_reasoning_effort = "high"
disable_response_storage = true
approval_policy = "never"
sandbox_mode = "danger-full-access"
network_access = "enabled"
windows_wsl_setup_acknowledged = true

[model_providers.OpenAI]
name = "OpenAI"
base_url = "` + BaseURL + `"
wire_api = "responses"
requires_openai_auth = true

[features]
goals = true
image_generation = true`

// ConfigContent returns the config.toml the installer writes.
func ConfigContent() string { return configContent }

// AuthContent returns the auth.json the installer writes for key.
func AuthContent(key string) string {
	escaped := strings.NewReplacer(`\`, `\\`, `"`, `\"`).Replace(key)
	return "{\n  \"OPENAI_API_KEY\": \"" + escaped + "\"\n}\n"
}

// CodexHome is %USERPROFILE%\.codex, the same folder install/codex.ps1 uses.
func CodexHome() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".codex"), nil
}

// renameFile is replaced in tests to make a step fail.
var renameFile = os.Rename

// WriteCodexFiles writes config.toml and auth.json as install/codex.ps1 does:
// both files go to temporary files first, existing files get a
// .bak.yyyyMMddHHmmss copy, then the temporary files replace them. If the
// second replacement fails, the first file is put back from its backup, so
// the previous configuration stays usable.
func WriteCodexFiles(codexHome, key string, now time.Time) error {
	if err := os.MkdirAll(codexHome, 0o700); err != nil {
		return err
	}
	configPath := filepath.Join(codexHome, "config.toml")
	authPath := filepath.Join(codexHome, "auth.json")

	configTemp, err := writeTemporary(codexHome, ".config.toml.tmp.", []byte(ConfigContent()))
	if err != nil {
		return err
	}
	defer os.Remove(configTemp)
	authTemp, err := writeTemporary(codexHome, ".auth.json.tmp.", []byte(AuthContent(key)))
	if err != nil {
		return err
	}
	defer os.Remove(authTemp)

	configBackup, err := backupIfExists(configPath, now)
	if err != nil {
		return err
	}
	if _, err := backupIfExists(authPath, now); err != nil {
		return err
	}
	if err := renameFile(configTemp, configPath); err != nil {
		return err
	}
	if err := renameFile(authTemp, authPath); err != nil {
		putBack(configPath, configBackup)
		return err
	}
	return nil
}

// RestoreOfficial follows install/codex-restore.ps1: back up both files,
// remove the root model selection and every [model_providers.*] table from
// config.toml, and empty auth.json. Other settings stay.
func RestoreOfficial(codexHome string, now time.Time) error {
	// Only a folder or file that is really missing counts as nothing to
	// restore; any other error is reported, so the window never claims a
	// restore that did not happen.
	info, err := os.Stat(codexHome)
	if errors.Is(err, fs.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	if !info.IsDir() {
		return nil
	}
	configPath := filepath.Join(codexHome, "config.toml")
	authPath := filepath.Join(codexHome, "auth.json")
	configExists, err := regularFile(configPath)
	if err != nil {
		return err
	}
	authExists, err := regularFile(authPath)
	if err != nil {
		return err
	}

	var configTemp string
	if configExists {
		content, err := os.ReadFile(configPath)
		if err != nil {
			return err
		}
		configTemp, err = writeTemporary(codexHome, ".config.toml.restore.", []byte(CleanConfig(string(content))))
		if err != nil {
			return err
		}
		defer os.Remove(configTemp)
	}
	var authTemp string
	if authExists {
		authTemp, err = writeTemporary(codexHome, ".auth.json.restore.", nil)
		if err != nil {
			return err
		}
		defer os.Remove(authTemp)
	}

	var configBackup string
	if configTemp != "" {
		var err error
		if configBackup, err = backupIfExists(configPath, now); err != nil {
			return err
		}
	}
	if authTemp != "" {
		if _, err := backupIfExists(authPath, now); err != nil {
			return err
		}
	}
	if configTemp != "" {
		if err := renameFile(configTemp, configPath); err != nil {
			return err
		}
	}
	if authTemp != "" {
		if err := renameFile(authTemp, authPath); err != nil {
			if configTemp != "" {
				putBack(configPath, configBackup)
			}
			return err
		}
	}
	return nil
}

// regularFile reports whether path is a regular file; a missing path is
// false without an error, other inspection failures are returned.
func regularFile(path string) (bool, error) {
	info, err := os.Stat(path)
	if errors.Is(err, fs.ErrNotExist) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return info.Mode().IsRegular(), nil
}

func writeTemporary(directory, prefix string, data []byte) (string, error) {
	random := make([]byte, 16)
	if _, err := rand.Read(random); err != nil {
		return "", err
	}
	path := filepath.Join(directory, prefix+hex.EncodeToString(random))
	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	if err != nil {
		return "", err
	}
	_, writeErr := file.Write(data)
	closeErr := file.Close()
	if err := errors.Join(writeErr, closeErr); err != nil {
		os.Remove(path)
		return "", err
	}
	return path, nil
}

// backupIfExists copies path to path.bak.yyyyMMddHHmmss, adding .1, .2 ...
// when that name is taken, like Backup-IfExists in the scripts. It returns
// "" when there is nothing to back up.
func backupIfExists(path string, now time.Time) (string, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, fs.ErrNotExist) {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	stamp := path + ".bak." + now.Format("20060102150405")
	for suffix := 0; ; suffix++ {
		backup := stamp
		if suffix > 0 {
			backup = stamp + "." + strconv.Itoa(suffix)
		}
		file, err := os.OpenFile(backup, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
		if errors.Is(err, fs.ErrExist) {
			continue
		}
		if err != nil {
			return "", err
		}
		_, writeErr := file.Write(data)
		closeErr := file.Close()
		if err := errors.Join(writeErr, closeErr); err != nil {
			os.Remove(backup)
			return "", err
		}
		return backup, nil
	}
}

// putBack restores path from backup, or removes it when there was no
// original. It runs only after a failure, so its own errors are not reported.
func putBack(path, backup string) {
	if backup == "" {
		_ = os.Remove(path)
		return
	}
	data, err := os.ReadFile(backup)
	if err != nil {
		return
	}
	temporary, err := writeTemporary(filepath.Dir(path), ".rollback.", data)
	if err != nil {
		return
	}
	if os.Rename(temporary, path) != nil {
		_ = os.Remove(temporary)
	}
}
