package main

import "testing"

func TestSoftwareWebview(t *testing.T) {
	if !softwareWebview(nil) || !softwareWebview([]string{"usegoodai://import?key=sk-fake"}) {
		t.Fatal("candidate must default to software rendering")
	}
	if softwareWebview([]string{"--system-gpu"}) {
		t.Fatal("comparison option not applied")
	}
}
