package main

import (
	"sync"
	"time"
)

// A later launch of the helper takes over from the running window: the
// newest window is the one the user just opened, and after an update it is
// also the newest version. The running window refuses only while it is in
// the middle of an operation, so a configuration is never cut off half way.

// Answers the running window gives to a later launch. An older helper
// (1.1.3 and earlier) answers 0 because it does not know the request.
const (
	replyBusy     uintptr = 0x55470001
	replyQuitting uintptr = 0x55470002
)

// staleOperation is how long an operation counts as running. Every
// operation has its own shorter timeouts, so one running longer has hung
// and must not keep a new window from opening.
const staleOperation = 5 * time.Minute

type takeoverStep int

const (
	keepRunningWindow takeoverStep = iota // it is busy: it comes to the front and this launch ends
	waitForClose                          // it is idle and closes itself
	closeOlderHelper                      // an older helper: close its window
	endUnresponsive                       // no answer in time: end its process
)

func nextTakeoverStep(answered bool, reply uintptr) takeoverStep {
	switch {
	case !answered:
		return endUnresponsive
	case reply == replyBusy:
		return keepRunningWindow
	case reply == replyQuitting:
		return waitForClose
	default:
		return closeOlderHelper
	}
}

// activity counts the operations the window is running.
type activity struct {
	mu      sync.Mutex
	running int
	since   time.Time
	now     func() time.Time
}

func (a *activity) clock() time.Time {
	if a.now != nil {
		return a.now()
	}
	return time.Now()
}

// begin marks an operation as running; call the returned function when it
// ends.
func (a *activity) begin() func() {
	a.mu.Lock()
	if a.running == 0 {
		a.since = a.clock()
	}
	a.running++
	a.mu.Unlock()
	var once sync.Once
	return func() {
		once.Do(func() {
			a.mu.Lock()
			a.running--
			a.mu.Unlock()
		})
	}
}

func (a *activity) busy() bool {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.running > 0 && a.clock().Sub(a.since) < staleOperation
}
