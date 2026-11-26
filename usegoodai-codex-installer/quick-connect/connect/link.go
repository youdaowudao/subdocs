package connect

import (
	"net/url"
	"strconv"
	"strings"
	"unicode"
)

// LinkProblem tells why an import link was not accepted.
type LinkProblem int

const (
	LinkOK LinkProblem = iota
	// LinkIncomplete covers missing, malformed or unrecognised parameters.
	LinkIncomplete
	// LinkUnsupported is a newer link version or another app.
	LinkUnsupported
)

// ImportLink is a parsed usegoodai://import link. App is the tool it is for
// (see linkApps); Name is only for display.
type ImportLink struct {
	App         string
	Key         string
	Name        string
	NeedsTarget bool // v1 used app=codex for both Codex and image keys
}

const (
	LinkAppCodex       = "codex"
	LinkAppClaude      = "claude"
	LinkAppImage       = "image"
	LinkAppAntigravity = "antigravity"
)

const maxLinkLength = 4096

// The contract with the website. Any other parameter, an address in
// particular, makes the link unrecognised.
var linkParameters = map[string]bool{"v": true, "app": true, "key": true, "name": true}

// ParseImportLink accepts legacy v1 links and v2 links with explicit targets.
func ParseImportLink(raw string) (ImportLink, LinkProblem) {
	raw = strings.TrimSpace(raw)
	if raw == "" || len(raw) > maxLinkLength {
		return ImportLink{}, LinkIncomplete
	}
	link, err := url.Parse(raw)
	if err != nil || !strings.EqualFold(link.Scheme, ProtocolScheme) || link.User != nil ||
		!strings.EqualFold(link.Host, "import") || (link.Path != "" && link.Path != "/") {
		return ImportLink{}, LinkIncomplete
	}
	values, err := url.ParseQuery(link.RawQuery)
	if err != nil {
		return ImportLink{}, LinkIncomplete
	}
	for _, list := range values {
		if len(list) != 1 {
			return ImportLink{}, LinkIncomplete
		}
	}

	version, err := strconv.Atoi(values.Get("v"))
	if err != nil || version < 1 {
		return ImportLink{}, LinkIncomplete
	}
	if version > 2 {
		return ImportLink{}, LinkUnsupported
	}
	app := values.Get("app")
	switch {
	case app == "":
		return ImportLink{}, LinkIncomplete
	case (app == LinkAppImage || app == LinkAppAntigravity) && version == 1:
		return ImportLink{}, LinkUnsupported
	case app != LinkAppCodex && app != LinkAppClaude && app != LinkAppImage && app != LinkAppAntigravity:
		return ImportLink{}, LinkUnsupported
	}
	for name := range values {
		if !linkParameters[name] {
			return ImportLink{}, LinkIncomplete
		}
	}
	key, ok := NormalizeKey(values.Get("key"))
	if !ok {
		return ImportLink{}, LinkIncomplete
	}
	return ImportLink{
		App: app, Key: key, Name: displayName(values.Get("name")),
		NeedsTarget: version == 1 && app == LinkAppCodex,
	}, LinkOK
}

// FindImportLink returns the first command-line argument that is an import
// link, as passed by the browser through "%1".
func FindImportLink(arguments []string) string {
	for _, argument := range arguments {
		trimmed := strings.TrimSpace(argument)
		if len(trimmed) > len(ProtocolScheme) && strings.EqualFold(trimmed[:len(ProtocolScheme)+1], ProtocolScheme+":") {
			return trimmed
		}
	}
	return ""
}

func displayName(raw string) string {
	cleaned := strings.Map(func(r rune) rune {
		if unicode.IsControl(r) || r == unicode.ReplacementChar {
			return -1
		}
		return r
	}, raw)
	runes := []rune(strings.TrimSpace(cleaned))
	if len(runes) > 32 {
		runes = append(runes[:32], '…')
	}
	return string(runes)
}
