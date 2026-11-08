package connect

import (
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"testing"

	"github.com/BurntSushi/toml"
)

// relayHead and relayProvider are the lines every import writes, LF.
const (
	relayHead     = "model_provider = \"OpenAI\"\nmodel = \"gpt-6.1-sol\""
	relayProvider = "[model_providers.OpenAI]\nname = \"OpenAI\"\nbase_url = \"https://api.usegoodai.com\"\nwire_api = \"responses\"\nrequires_openai_auth = true"
)

// importCases are run through the helper (ConfigFor), install/codex.ps1 and
// install/codex.sh; all three must write want byte for byte.
// otherSpaces names the one case whose input is not valid TOML.
const otherSpaces = "lines of other spaces"

var importCases = []struct{ name, old, want string }{
	{"new user", "", relayHead + "\n\n" + relayProvider},
	{
		// The shape of a real config.toml after earlier versions and the
		// Codex App wrote to it.
		"config written by earlier versions and the App",
		`model_provider = "OpenAI"
model = "gpt-6.1-sol"
review_model = "gpt-6.1-sol"
model_reasoning_effort = "xhigh"
disable_response_storage = true
approval_policy = "never"
sandbox_mode = "danger-full-access"
network_access = "enabled"
windows_wsl_setup_acknowledged = true
model_catalog_json = 'C:\Users\me\.codex\usegoodai-models.json'
personality = "pragmatic"

[model_providers.OpenAI]
name = "OpenAI"
base_url = "https://api.usegoodai.com"
wire_api = "responses"
requires_openai_auth = true

[model_providers.local]
name = "local"
base_url = "http://127.0.0.1:11434/v1"

[features]
goals = true
image_generation = true

[windows]
sandbox = "elevated"

[mcp_servers.playwright]
command = "npx"
args = ["@playwright/mcp@latest"]

[notice]
hide_full_access_warning = true

[plugins."github@openai-curated"]
enabled = true

[projects.'C:\Users\me\work']
trust_level = "trusted"

[tui]
notifications = true

[desktop]
enabled-reasoning-efforts = ["low", "medium", "high"]
`,
		relayHead + "\npersonality = \"pragmatic\"\n\n" + relayProvider + `

[features]
goals = true
image_generation = true

[windows]
sandbox = "elevated"

[mcp_servers.playwright]
command = "npx"
args = ["@playwright/mcp@latest"]

[notice]
hide_full_access_warning = true

[plugins."github@openai-curated"]
enabled = true

[projects.'C:\Users\me\work']
trust_level = "trusted"

[tui]
notifications = true

[desktop]
enabled-reasoning-efforts = ["low", "medium", "high"]`,
	},
	{
		"windows line ends kept",
		"personality = \"x\"\r\napproval_policy = \"never\"\r\n\r\n[windows]\r\nsandbox = \"elevated\"\r\n\r\n[mcp_servers.a]\r\ncommand = \"a\"\r\n",
		strings.ReplaceAll(relayHead+"\npersonality = \"x\"\n\n"+relayProvider+"\n\n[windows]\nsandbox = \"elevated\"\n\n[mcp_servers.a]\ncommand = \"a\"", "\n", "\r\n"),
	},
	{"byte order mark dropped", "\ufeffmodel = \"x\"\n[tui]\nx = 1\n", relayHead + "\n\n" + relayProvider + "\n\n[tui]\nx = 1"},
	{
		// Table headers and removed keys inside multi-line strings are text.
		"multi-line strings",
		"developer_instructions = \"\"\"\n[windows]\nmodel = \"y\"\n\"\"\"\nprofile = '''\n[tui]\n'''\n\n[model_providers.local]\nnote = \"\"\"\n[tui]\n\"\"\"\n[tui]\nx = 1\n",
		relayHead + "\ndeveloper_instructions = \"\"\"\n[windows]\nmodel = \"y\"\n\"\"\"\n\n" + relayProvider + "\n\n[tui]\nx = 1",
	},
	{
		// Quotes in comments and one-line strings open no multi-line string;
		// \""" in a basic multi-line string does not close it; a closing
		// """ may carry two more quotes.
		"quotes in comments and strings",
		`# 例子：developer_instructions = """
model = "old"
note = "has ''' and \" inside"
path = 'C:\dir"""'
dev = """
say \"""
model = "inside string"
"""
tail = """a"""""
review_model = "old"

[model_providers.OpenAI] # """
base_url = "https://old"
[mcp_servers.x]
command = "y" # '''
args = ["""a""", '''b''', "c"]
[model_providers.local]
base_url = "z"
`,
		relayHead + `
# 例子：developer_instructions = """
note = "has ''' and \" inside"
path = 'C:\dir"""'
dev = """
say \"""
model = "inside string"
"""
tail = """a"""""

` + relayProvider + `

[mcp_servers.x]
command = "y" # '''
args = ["""a""", '''b''', "c"]`,
	},
	{
		// Only spaces and tabs are blank, so a line of other spaces stays.
		// Such a file is not valid TOML; the three writers must still agree.
		otherSpaces,
		"x = 1\n\u3000\n\n[tui]\n\u00a0\n",
		relayHead + "\nx = 1\n\u3000\n\n" + relayProvider + "\n\n[tui]\n\u00a0",
	},
	{
		"dotted keys, inline tables, profile and login settings",
		"profile = \"work\"\nforced_login_method = \"chatgpt\"\nCLI_auth_credentials_store = \"keyring\"\nmodel_providers.local.name = \"local\"\nmodel_providers = { a = { name = \"a\" } }\nwindows.sandbox = \"elevated\"\nmodel_verbosity = \"low\"\nwindowsx = 1\n\n[profiles.work]\nmodel = \"w\"\n",
		relayHead + "\nwindows.sandbox = \"elevated\"\nmodel_verbosity = \"low\"\nwindowsx = 1\n\n" + relayProvider + "\n\n[profiles.work]\nmodel = \"w\"",
	},
	{
		"table spellings",
		"[ model_providers . \"my-relay\" ] # mine\nbase_url = \"x\"\n[model_providers.OpenAI.http_headers]\nx = \"y\"\n[model_providers]\n[Windows]\nsandbox = \"x\"\n[windows.extra]\nx = 1\n[windowsx]\nx = 1\n[model_providers_extra]\nx = 1\n",
		relayHead + "\n\n" + relayProvider + "\n\n[Windows]\nsandbox = \"x\"\n[windows.extra]\nx = 1\n[windowsx]\nx = 1\n[model_providers_extra]\nx = 1",
	},
	{
		// A removed key's array or inline table may run over several lines;
		// brackets in strings and comments do not count. A kept array stays.
		"removed values over several lines",
		`model_providers.custom.auth.args = [
  "--token", # ]
  """x
]""",
  { a = "}" },
]
model_catalog_json = [
  'a]',
]
keep = [
  1,
]
`,
		relayHead + "\nkeep = [\n  1,\n]\n\n" + relayProvider,
	},
	{
		// Removed keys and model_providers may be written "quoted" or
		// 'literal'; other quoted keys stay.
		"quoted key names",
		`"model" = "old"
'review_model' = "x"
"Profile" = "p"
"model_providers".x.base_url = "y"
"keep" = 1

["model_providers".old]
base_url = "z"
[ 'model_providers' ]
[tui]
x = 1
`,
		relayHead + "\n\"keep\" = 1\n\n" + relayProvider + "\n\n[tui]\nx = 1",
	},
	{
		// A ] inside a quoted key does not end the header; a nested array
		// line such as [1, 2] is no header.
		"brackets in quoted table names",
		`[model_providers.old]
base_url = "x"
pairs = [
  [1, 2]
]
[projects."C:\\work\\[a]"]
trust_level = "trusted"
[projects.'/home/me/[b] c'] # mine
trust_level = "trusted"
[model_providers."a]b"]
x = 1
[tui]
x = 1
`,
		relayHead + "\n\n" + relayProvider + `

[projects."C:\\work\\[a]"]
trust_level = "trusted"
[projects.'/home/me/[b] c'] # mine
trust_level = "trusted"
[tui]
x = 1`,
	},
	{
		// Comments stay where they are; one above the first table ends the
		// first part.
		"comments stay in place",
		"# my settings\npersonality = \"x\"\n\n# servers\n[mcp_servers.a]\ncommand = \"a\"\n",
		relayHead + "\n# my settings\npersonality = \"x\"\n\n# servers\n\n" + relayProvider + "\n\n[mcp_servers.a]\ncommand = \"a\"",
	},
	{
		"config written by 1.1.3",
		relayHead + "\nreview_model = \"gpt-6.1-sol\"\nmodel_reasoning_effort = \"high\"\ndisable_response_storage = true\napproval_policy = \"never\"\nsandbox_mode = \"danger-full-access\"\nnetwork_access = \"enabled\"\nwindows_wsl_setup_acknowledged = true\n\n" + relayProvider + "\n\n[features]\ngoals = true\nimage_generation = true\n\n[windows]\nsandbox = \"unelevated\"",
		relayHead + "\n\n" + relayProvider + "\n\n[features]\ngoals = true\nimage_generation = true\n\n[windows]\nsandbox = \"unelevated\"",
	},
}

func TestConfigForImport(t *testing.T) {
	for _, c := range importCases {
		t.Run(c.name, func(t *testing.T) {
			got := ConfigFor(c.old)
			if got != c.want {
				t.Fatalf("got:\n%q\nwant:\n%q", got, c.want)
			}
			if again := ConfigFor(got); again != got {
				t.Fatalf("a second import changes the file:\n%q", again)
			}
			if c.name == otherSpaces {
				return
			}
			var parsed struct {
				ModelProvider  string                    `toml:"model_provider"`
				Model          string                    `toml:"model"`
				Profile        *string                   `toml:"profile"`
				ModelProviders map[string]map[string]any `toml:"model_providers"`
			}
			if _, err := toml.Decode(got, &parsed); err != nil {
				t.Fatalf("not valid TOML: %v", err)
			}
			if parsed.ModelProvider != "OpenAI" || parsed.Model != CodexModel || parsed.Profile != nil ||
				len(parsed.ModelProviders) != 1 || parsed.ModelProviders["OpenAI"]["base_url"] != BaseURL {
				t.Fatalf("parsed %+v", parsed)
			}
		})
	}
}

func TestWriterKeepsOldLineEndsAndBacksUp(t *testing.T) {
	codexHome := filepath.Join(t.TempDir(), ".codex")
	old := importCases[2].old
	writeFile(t, filepath.Join(codexHome, "config.toml"), old)
	if err := WriteCodexFiles(codexHome, fixtureKey, fixedTime); err != nil {
		t.Fatal(err)
	}
	if got := readFile(t, filepath.Join(codexHome, "config.toml")); got != importCases[2].want {
		t.Fatalf("config.toml:\n%q", got)
	}
	backups := listBackups(t, codexHome, "config.toml.bak.")
	if len(backups) != 1 || readFile(t, filepath.Join(codexHome, backups[0])) != old {
		t.Fatalf("backups %v", backups)
	}
}

// writeImportCases puts each case's old file in a new folder as NN.toml.
func writeImportCases(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	for i, c := range importCases {
		if err := os.WriteFile(filepath.Join(dir, caseFile(i)), []byte(c.old), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	return dir
}

func caseFile(i int) string { return strconv.Itoa(10+i) + ".toml" }

func checkImportOutputs(t *testing.T, dir, suffix, who string) {
	t.Helper()
	for i, c := range importCases {
		got, err := os.ReadFile(filepath.Join(dir, caseFile(i)+suffix))
		if err != nil {
			t.Fatalf("%s %s: %v", who, c.name, err)
		}
		if string(got) != c.want {
			t.Errorf("%s %s:\n%q\nwant:\n%q", who, c.name, got, c.want)
		}
	}
}

// Get-CodexConfig and the functions it uses are taken out of codex.ps1 and
// run on every case, reading each file the way Write-CodexFiles does.
func TestPowerShellInstallerConfigMatchesHelper(t *testing.T) {
	pwsh := powerShell(t)
	dir := writeImportCases(t)
	script := `$ErrorActionPreference = 'Stop'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($env:USEGOODAI_TEST_SCRIPT, [ref]$null, [ref]$null)
foreach ($name in 'CodexBaseUrl', 'CodexModel') {
  $found = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq ('$' + $name) }, $false)
  . ([scriptblock]::Create($found.Extent.Text))
}
foreach ($name in 'Write-Utf8NoBom', 'Update-MultilineState', 'Remove-BlankEnds', 'Get-CodexConfig') {
  $found = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true)
  . ([scriptblock]::Create($found.Extent.Text))
}
foreach ($file in Get-ChildItem -LiteralPath $env:USEGOODAI_TEST_CASES -Filter '*.toml') {
  $old = [System.IO.File]::ReadAllText($file.FullName)
  Write-Utf8NoBom -Path ($file.FullName + '.ps1-out') -Content (Get-CodexConfig $old)
}`
	home := t.TempDir()
	command := exec.Command(pwsh, "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script)
	command.Env = append(os.Environ(),
		"HOME="+home, "USERPROFILE="+home, "USEGOODAI_TEST_SCRIPT="+installScript(t, "codex.ps1"), "USEGOODAI_TEST_CASES="+dir,
		"POWERSHELL_TELEMETRY_OPTOUT=1", "POWERSHELL_UPDATECHECK=Off", "DOTNET_CLI_TELEMETRY_OPTOUT=1",
		"XDG_CACHE_HOME="+filepath.Join(home, ".cache"), "XDG_CONFIG_HOME="+filepath.Join(home, ".config"),
		"XDG_DATA_HOME="+filepath.Join(home, ".local", "share"))
	if output, err := command.CombinedOutput(); err != nil {
		t.Fatalf("PowerShell: %v\n%s", err, output)
	}
	checkImportOutputs(t, dir, ".ps1-out", "codex.ps1")
}

// codex_config and the constants it reads are taken out of codex.sh and run
// with the system's awk (mawk or gawk on Linux, BSD awk on macOS).
func TestShellInstallerConfigMatchesHelper(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("codex.sh runs on macOS and Linux")
	}
	bash, err := exec.LookPath("bash")
	if err != nil {
		t.Skip("no bash")
	}
	source, err := os.ReadFile(installScript(t, "codex.sh"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(source)
	start := strings.Index(text, "\ncodex_config() {\n")
	if start < 0 {
		t.Fatal("codex_config not found in codex.sh")
	}
	end := strings.Index(text[start:], "\n}\n")
	constants := regexp.MustCompile(`(?m)^CODEX_(?:BASE_URL|MODEL)=.*$`).FindAllString(text, -1)
	if end < 0 || len(constants) != 2 {
		t.Fatal("codex.sh layout changed")
	}
	script := "set -euo pipefail\n" + strings.Join(constants, "\n") + text[start:start+end+3] +
		"for file in \"$1\"/*.toml; do codex_config \"$file\" > \"$file.sh-out\"; done\n"
	dir := writeImportCases(t)
	if output, err := exec.Command(bash, "-c", script, "bash", dir).CombinedOutput(); err != nil {
		t.Fatalf("bash: %v\n%s", err, output)
	}
	checkImportOutputs(t, dir, ".sh-out", "codex.sh")
}
