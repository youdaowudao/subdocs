package main

import (
	"slices"
	"testing"

	"github.com/wailsapp/wails/v2/pkg/options"
)

func TestKeepsAllLinksReceivedBeforeTheWindowIsReady(t *testing.T) {
	const launch = "usegoodai://import?v=2&app=image&key=sk-image-fixture"
	const second = "usegoodai://import?v=2&app=codex&key=sk-codex-fixture"
	app := newApp(nil, launch)
	app.secondInstance(options.SecondInstanceData{Args: []string{second}})
	app.secondInstance(options.SecondInstanceData{Args: []string{launch}})
	if got := app.TakeLaunchLinks(); !slices.Equal(got, []string{launch, second, launch}) {
		t.Fatal("links received before startup must drain in order")
	}
	if len(app.TakeLaunchLinks()) != 0 {
		t.Fatal("the startup links were returned twice")
	}
}
