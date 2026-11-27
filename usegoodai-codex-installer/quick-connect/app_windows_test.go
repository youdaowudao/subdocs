package main

import (
	"slices"
	"testing"

	"github.com/wailsapp/wails/v2/pkg/options"
	"usegoodai-quick-connect/connect"
)

func TestKeepsAllLinksReceivedBeforeTheWindowIsReady(t *testing.T) {
	const launch = "usegoodai://import?v=2&app=image&key=sk-image-fixture"
	const second = "usegoodai://import?v=2&app=codex&key=sk-codex-fixture"
	const antigravity = "usegoodai://import?v=2&app=antigravity&key=sk-antigravity-fixture"
	// Production always supplies a service; Antigravity reuses its base URL.
	app := newApp(&connect.Service{BaseURL: connect.BaseURL}, launch)
	app.secondInstance(options.SecondInstanceData{Args: []string{second}})
	app.secondInstance(options.SecondInstanceData{Args: []string{antigravity}})
	app.secondInstance(options.SecondInstanceData{Args: []string{launch}})
	if got := app.TakeLaunchLinks(); !slices.Equal(got, []string{launch, second, antigravity, launch}) {
		t.Fatal("links received before startup must drain in order")
	}
	if len(app.TakeLaunchLinks()) != 0 {
		t.Fatal("the startup links were returned twice")
	}
}
