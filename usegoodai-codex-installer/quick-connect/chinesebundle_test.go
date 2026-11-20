package main

import (
	"bytes"
	"os"
	"testing"
)

func TestChineseBundleIsThePublishedPayload(t *testing.T) {
	data, err := chineseBundle.ReadFile("chinesetool/chinese.ps1")
	if err != nil {
		t.Fatal(err)
	}
	for _, path := range []string{"../install/chinese.ps1", "../../docs/public/install/chinese.ps1"} {
		expected, err := os.ReadFile(path)
		if err != nil || !bytes.Equal(data, expected) {
			t.Fatal("bundled Chinese script differs from published bytes", path, err)
		}
	}
	wrapper, err := chineseBundle.ReadFile("chinesetool/run.ps1")
	if err != nil || !bytes.HasPrefix(wrapper, []byte{0xef, 0xbb, 0xbf}) {
		t.Fatal("PowerShell 5.1 wrapper needs UTF-8 BOM", err)
	}
}
