//go:build !windows

package connect

func newAntigravityEnvStore() antigravityEnvStore { return nil }
func antigravityWindowsDefaultPaths() []string    { return nil }
func antigravityWindowsRegisteredPaths() []string { return nil }
