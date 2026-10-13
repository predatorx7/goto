package app

import (
	"bytes"
	"os"
	"strings"
	"testing"

	"github.com/predatorx7/goto/internal/config"
	"github.com/predatorx7/goto/internal/store"
	"github.com/predatorx7/goto/internal/ui"
	"github.com/predatorx7/goto/internal/version"
)

func setupTestApp(t *testing.T, inContent string) (*App, *config.Config, *store.Store, *bytes.Buffer, *bytes.Buffer) {
	tempDir := t.TempDir()
	cfg := config.NewWithDir(tempDir)
	st := store.NewStore(cfg.DataFile)
	out := &bytes.Buffer{}
	errOut := &bytes.Buffer{}
	in := strings.NewReader(inContent)
	u := ui.NewCustom(out, errOut, in, false)

	application := NewCustom(cfg, st, u, tempDir)
	return application, cfg, st, out, errOut
}

func TestAppSetAndGet(t *testing.T) {
	app, _, _, out, errOut := setupTestApp(t, "")

	// 1. Set key pointing to existing temp dir
	targetDir := t.TempDir()
	code := app.Run([]string{"set", "myproj", targetDir})
	if code != 0 {
		t.Fatalf("expected code 0, got %d. stderr: %s", code, errOut.String())
	}
	if !strings.Contains(out.String(), `Saving "`+targetDir+`" with key "myproj"`) {
		t.Errorf("unexpected output: %s", out.String())
	}

	// 2. Get key
	out.Reset()
	code = app.Run([]string{"get", "myproj"})
	if code != 0 {
		t.Fatalf("expected code 0, got %d. stderr: %s", code, errOut.String())
	}
	expected := "myproj -> " + targetDir
	if !strings.Contains(out.String(), expected) {
		t.Errorf("expected %q, got %q", expected, out.String())
	}

	// 3. Get non-existent key
	errOut.Reset()
	code = app.Run([]string{"get", "unknown_key"})
	if code != 1 {
		t.Fatalf("expected code 1, got %d", code)
	}
	if !strings.Contains(errOut.String(), "Found no path with 'unknown_key' key") {
		t.Errorf("unexpected stderr: %s", errOut.String())
	}
}

func TestAppKeyValidation(t *testing.T) {
	app, _, _, _, errOut := setupTestApp(t, "")

	// Invalid characters (hyphen)
	code := app.Run([]string{"set", "invalid-key"})
	if code != 1 {
		t.Fatalf("expected code 1 for invalid key, got %d", code)
	}
	if !strings.Contains(errOut.String(), "has invalid format") {
		t.Errorf("expected invalid format message, got %s", errOut.String())
	}

	// Reserved key name
	errOut.Reset()
	code = app.Run([]string{"set", "list"})
	if code != 1 {
		t.Fatalf("expected code 1 for reserved key, got %d", code)
	}
	if !strings.Contains(errOut.String(), "must not be the name or alias of any goto command") {
		t.Errorf("expected reserved key message, got %s", errOut.String())
	}
}

func TestAppSetNonExistentDirectory(t *testing.T) {
	app, _, _, _, errOut := setupTestApp(t, "")

	code := app.Run([]string{"set", "ghost", "/path/that/definitely/does/not/exist/9999"})
	if code != 1 {
		t.Fatalf("expected code 1 for missing dir, got %d", code)
	}
	if !strings.Contains(errOut.String(), "not found. It either does not exist or is not a directory") {
		t.Errorf("unexpected stderr: %s", errOut.String())
	}
}

func TestAppSetOverwritePrompt(t *testing.T) {
	target1 := t.TempDir()
	target2 := t.TempDir()

	// Case 1: user confirms overwrite
	app, _, st, _, _ := setupTestApp(t, "y\n")
	app.Run([]string{"set", "work", target1})
	code := app.Run([]string{"set", "work", target2})
	if code != 0 {
		t.Fatalf("expected code 0, got %d", code)
	}
	p, _ := st.Get("work")
	if p != target2 {
		t.Errorf("expected updated path %s, got %s", target2, p)
	}

	// Case 2: user declines overwrite
	app2, _, st2, _, _ := setupTestApp(t, "n\n")
	app2.Run([]string{"set", "work", target1})
	code = app2.Run([]string{"set", "work", target2})
	if code != 0 {
		t.Fatalf("expected code 0, got %d", code)
	}
	p, _ = st2.Get("work")
	if p != target1 {
		t.Errorf("expected path to remain %s, got %s", target1, p)
	}

	// Case 3: force flag skips prompt
	app3, _, st3, _, _ := setupTestApp(t, "")
	app3.Run([]string{"set", "work", target1})
	code = app3.Run([]string{"set", "--force", "work", target2})
	if code != 0 {
		t.Fatalf("expected code 0, got %d", code)
	}
	p, _ = st3.Get("work")
	if p != target2 {
		t.Errorf("expected path to be force-updated to %s, got %s", target2, p)
	}
}

func TestAppList(t *testing.T) {
	app, _, _, out, _ := setupTestApp(t, "")

	// Empty list
	app.Run([]string{"list"})
	if !strings.Contains(out.String(), "No saved records") {
		t.Errorf("expected 'No saved records', got %s", out.String())
	}

	// Add entries
	dir1 := t.TempDir()
	dir2 := t.TempDir()
	app.Run([]string{"set", "beta", dir1})
	app.Run([]string{"set", "alpha", dir2})

	out.Reset()
	app.Run([]string{"list"})
	lines := strings.Split(strings.TrimSpace(out.String()), "\n")
	if len(lines) != 2 {
		t.Fatalf("expected 2 lines, got %d (%v)", len(lines), lines)
	}
	if !strings.HasPrefix(lines[0], "alpha: ") || !strings.HasPrefix(lines[1], "beta: ") {
		t.Errorf("expected sorted list, got %v", lines)
	}

	// Keys-only
	out.Reset()
	app.Run([]string{"list", "--keys-only"})
	keysOutput := strings.TrimSpace(out.String())
	if keysOutput != "alpha\nbeta" {
		t.Errorf("expected 'alpha\\nbeta', got %q", keysOutput)
	}
}

func TestAppRemove(t *testing.T) {
	app, _, st, _, _ := setupTestApp(t, "")
	dir := t.TempDir()
	app.Run([]string{"set", "k1", dir})
	app.Run([]string{"set", "k2", dir})

	// Remove k1
	code := app.Run([]string{"remove", "k1"})
	if code != 0 {
		t.Fatalf("expected code 0, got %d", code)
	}
	if st.Has("k1") {
		t.Errorf("k1 should have been deleted")
	}
	if !st.Has("k2") {
		t.Errorf("k2 should still exist")
	}

	// Remove all
	code = app.Run([]string{"remove", "--all"})
	if code != 0 {
		t.Fatalf("expected code 0, got %d", code)
	}
	if st.Count() != 0 {
		t.Errorf("expected store to be empty, got count %d", st.Count())
	}
}

func TestAppRename(t *testing.T) {
	app, _, st, out, errOut := setupTestApp(t, "")
	dir := t.TempDir()
	app.Run([]string{"set", "old_name", dir})

	// Missing args
	code := app.Run([]string{"rename", "old_name"})
	if code != 1 {
		t.Fatalf("expected code 1, got %d", code)
	}

	// Same name
	errOut.Reset()
	code = app.Run([]string{"rename", "old_name", "old_name"})
	if code != 1 {
		t.Fatalf("expected code 1, got %d", code)
	}
	if !strings.Contains(errOut.String(), "Old & new key names must not be same") {
		t.Errorf("unexpected error: %s", errOut.String())
	}

	// Successful rename
	out.Reset()
	code = app.Run([]string{"rename", "old_name", "new_name"})
	if code != 0 {
		t.Fatalf("expected code 0, got %d", code)
	}
	if st.Has("old_name") {
		t.Errorf("old_name should be removed")
	}
	p, ok := st.Get("new_name")
	if !ok || p != dir {
		t.Errorf("expected new_name -> %s, got %s (ok=%v)", dir, p, ok)
	}
}

func TestAppGo(t *testing.T) {
	app, cfg, _, _, errOut := setupTestApp(t, "")
	dir := t.TempDir()
	app.Run([]string{"set", "jump", dir})

	// Navigation to jump
	code := app.Run([]string{"jump"})
	if code != 0 {
		t.Fatalf("expected code 0, got %d. stderr: %s", code, errOut.String())
	}

	// Verify marker file contains target dir
	markerBytes, err := os.ReadFile(cfg.MarkerFile)
	if err != nil {
		t.Fatalf("failed to read marker file: %v", err)
	}
	if string(markerBytes) != dir {
		t.Errorf("expected marker to contain %s, got %s", dir, string(markerBytes))
	}

	// Navigation to non-existent key
	errOut.Reset()
	code = app.Run([]string{"nonexistent"})
	if code != 1 {
		t.Fatalf("expected code 1, got %d", code)
	}
	if !strings.Contains(errOut.String(), "Key 'nonexistent' not assigned to any path") {
		t.Errorf("unexpected stderr: %s", errOut.String())
	}
}

func TestAppHelpAndVersion(t *testing.T) {
	app, _, _, out, _ := setupTestApp(t, "")

	code := app.Run([]string{"--version"})
	if code != 0 {
		t.Fatalf("expected code 0, got %d", code)
	}
	if !strings.Contains(out.String(), "Goto v"+version.String()) {
		t.Errorf("unexpected version text: %s", out.String())
	}

	out.Reset()
	code = app.Run([]string{"--help"})
	if code != 0 {
		t.Fatalf("expected code 0, got %d", code)
	}
	if !strings.Contains(out.String(), "Available commands:") {
		t.Errorf("unexpected help text: %s", out.String())
	}
}
