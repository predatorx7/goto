package version

import (
	"fmt"
	"runtime/debug"
)

var (
	// Version is the semantic version of goto.
	// It can be overridden at build time using:
	//   -ldflags "-X github.com/predatorx7/goto/internal/version.Version=vX.Y.Z"
	Version = "0.3.0"

	// GitCommit is the git commit hash injected at compile time.
	GitCommit = ""

	// BuildDate is the timestamp injected at compile time.
	BuildDate = ""
)

// String returns the resolved version string.
// If not explicitly set via ldflags, it attempts to resolve from Go build info (for `go install`).
func String() string {
	if Version != "" && Version != "dev" {
		return Version
	}
	if bi, ok := debug.ReadBuildInfo(); ok && bi.Main.Version != "" && bi.Main.Version != "(devel)" {
		return bi.Main.Version
	}
	return "0.3.0"
}

// Full returns the complete version, copyright, and author information.
func Full() string {
	commitInfo := ""
	if GitCommit != "" {
		commitInfo = fmt.Sprintf(" (%s)", GitCommit)
	}
	return fmt.Sprintf(`Goto v%s%s

Copyright (c) 2020-2026, Syed Mushaheed. All rights reserved.
Licensed with BSD 3-Clause License.

Written by Mushaheed Syed <smushaheed@gmail.com>`, String(), commitInfo)
}
