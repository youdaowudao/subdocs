package connect

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// The relay's part of config.toml: the root model selection and its
// provider table. install/codex.ps1 and install/codex.sh write the same
// lines, LF line ends and no newline after the last line.
const (
	configRoot = `model_provider = "OpenAI"
model = "` + CodexModel + `"`
	configProvider = `[model_providers.OpenAI]
name = "OpenAI"
base_url = "` + BaseURL + `"
wire_api = "responses"
requires_openai_auth = true`
)

// What an import removes from the old config.toml. install/codex.ps1 and
// install/codex.sh use the same patterns; they ignore case, like the restore.
var (
	// Root keys: the model selection, which is written anew; the keys
	// earlier versions wrote (full access, sandbox, reasoning effort, the
	// review model); the domestic model list, which an import resets as it
	// always did; profile, which would override the model selection; the
	// login settings that would keep Codex from using the key in auth.json
	// (ChatGPT-only login, the system keyring); and providers written as
	// dotted keys or an inline table.
	importRootKey = regexp.MustCompile(`(?i)^[\t ]*(?:(?:` + importNames + `|"` + importNames + `"|'` + importNames + `')[\t ]*=|` + providersKey + `[\t ]*[.=])`)
	// Table headers, with keys written the TOML way: bare, "quoted" with
	// escapes or 'literal', joined by dots. A ] inside quotes, as in
	// [projects."C:\[work]"], does not end the header.
	importHeader = regexp.MustCompile(`^[\t ]*\[\[?[\t ]*` + tomlKey + `(?:[\t ]*\.[\t ]*` + tomlKey + `)*[\t ]*\]\]?[\t ]*(?:#.*)?$`)
	// Tables: every provider whatever its name, with its sub-tables. The
	// user's [windows] table stays: the Codex App writes it when its sandbox
	// is set up, and without it Codex rejects every command it cannot sandbox.
	importTable = regexp.MustCompile(`(?i)^[\t ]*\[[\t ]*` + providersKey + `(?:[\t ]*\.[\t ]*` + tomlKey + `)*[\t ]*\][\t ]*(?:#.*)?$`)
)

// Root keys an import removes, written bare, "quoted" or 'literal'.
const importNames = `(?:model_provider|model|review_model|model_reasoning_effort|disable_response_storage|approval_policy|sandbox_mode|network_access|windows_wsl_setup_acknowledged|model_catalog_json|profile|forced_login_method|cli_auth_credentials_store)`

// providersKey is the model_providers key, bare or quoted.
const providersKey = `(?:model_providers|"model_providers"|'model_providers')`

// tomlKey matches one part of a TOML key.
const tomlKey = `(?:[A-Za-z0-9_-]+|"(?:[^"\\]|\\.)*"|'[^']*')`

// ConfigContent returns the config.toml an import writes when there is none.
func ConfigContent() string { return configRoot + "\n\n" + configProvider }

// ConfigFor is the config.toml written over old. It holds the root model
// selection, then the user's other root keys, then [model_providers.OpenAI]
// as the first table, then the user's other tables. What importRootKey and
// importTable match is removed; everything else stays as it was. The old
// file's line ends are kept; WriteCodexFiles keeps the old file as a backup.
func ConfigFor(old string) string {
	old = strings.TrimPrefix(old, "\ufeff")
	newline := "\n"
	if strings.Contains(old, "\r\n") {
		newline = "\r\n"
	}
	var root, tables []string
	inRoot := true
	skipTable := false
	multiline := ""
	depth := 0
	skipValue := false
	// The walk follows CleanConfig in restore.go, but finds headers with
	// importHeader and tracks strings and brackets with scanLine.
	for _, line := range lineBreak.Split(old, -1) {
		if skipValue {
			// The rest of a removed key's value, up to the end of its
			// multi-line string, array or inline table.
			multiline, depth = scanLine(line, multiline, depth)
			skipValue = multiline != "" || depth > 0
			continue
		}
		inString := multiline != ""
		multiline, depth = scanLine(line, multiline, 0)
		if inString {
			if skipTable {
				continue
			}
		} else {
			if importHeader.MatchString(line) {
				inRoot = false
				skipTable = importTable.MatchString(line)
			}
			if skipTable {
				continue
			}
			if inRoot && importRootKey.MatchString(line) {
				skipValue = multiline != "" || depth > 0
				continue
			}
		}
		if inRoot {
			root = append(root, line)
		} else {
			tables = append(tables, line)
		}
	}

	head := append(strings.Split(configRoot, "\n"), trimBlankLines(root)...)
	parts := []string{strings.Join(head, newline), strings.ReplaceAll(configProvider, "\n", newline)}
	if tables = trimBlankLines(tables); len(tables) > 0 {
		parts = append(parts, strings.Join(tables, newline))
	}
	return strings.Join(parts, newline+newline)
}

// scanLine returns the delimiter of the TOML multi-line string (three double
// or three single quotes) still open at the end of line, given the one open
// at its start, and depth plus the brackets of arrays and inline tables the
// line opens minus those it closes. Comments and one-line strings are
// skipped, so quotes and brackets in them count for nothing. The restore
// keeps using updateMultiline. Update-MultilineState in install/codex.ps1
// and update_multiline in install/codex.sh do the same.
func scanLine(line, open string, depth int) (string, int) {
	for i := 0; i < len(line); {
		switch {
		case open == `"""` && line[i] == '\\':
			i += 2
		case open != "" && strings.HasPrefix(line[i:], open):
			// Up to two more quotes belong to the string: """a""""" is a"".
			i += 3
			for extra := 0; extra < 2 && i < len(line) && line[i] == open[0]; extra++ {
				i++
			}
			open = ""
		case open != "":
			i++
		case line[i] == '#':
			return "", depth
		case line[i] == '[' || line[i] == '{':
			depth++
			i++
		case line[i] == ']' || line[i] == '}':
			depth--
			i++
		case strings.HasPrefix(line[i:], `"""`) || strings.HasPrefix(line[i:], `'''`):
			open = line[i : i+3]
			i += 3
		case line[i] == '"' || line[i] == '\'':
			quote := line[i]
			for i++; i < len(line) && line[i] != quote; i++ {
				if quote == '"' && line[i] == '\\' {
					i++
				}
			}
			i++
		default:
			i++
		}
	}
	return open, depth
}

// trimBlankLines drops the lines at the start and end of lines that hold
// nothing but spaces and tabs, the only whitespace TOML knows.
func trimBlankLines(lines []string) []string {
	for len(lines) > 0 && strings.Trim(lines[0], " \t") == "" {
		lines = lines[1:]
	}
	for len(lines) > 0 && strings.Trim(lines[len(lines)-1], " \t") == "" {
		lines = lines[:len(lines)-1]
	}
	return lines
}

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

	old, err := os.ReadFile(configPath)
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return err
	}
	content := ConfigFor(string(old))
	configTemp, err := writeTemporary(codexHome, ".config.toml.tmp.", []byte(content))
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
