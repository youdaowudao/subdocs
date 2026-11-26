//go:build linux

package main

import (
	"os"
	"usegoodai-quick-connect/connect"
)

var serviceBaseURL = connect.BaseURL

func main() {
	os.Exit(connect.RunAntigravityCommand(os.Args[1:], os.Stdin, os.Stdout, connect.NewAntigravity(serviceBaseURL)))
}
