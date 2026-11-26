//go:build !windows

package connect

func registeredClaudePackage(string) (bool, error) { return false, nil }
