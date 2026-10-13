package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestNewWithDir(t *testing.T) {
	tempDir := t.TempDir()
	cfg := NewWithDir(tempDir)

	if cfg.DataDir != tempDir {
		t.Errorf("expected DataDir %q, got %q", tempDir, cfg.DataDir)
	}
	expectedDataFile := filepath.Join(tempDir, "data.json")
	if cfg.DataFile != expectedDataFile {
		t.Errorf("expected DataFile %q, got %q", expectedDataFile, cfg.DataFile)
	}
	expectedMarker := filepath.Join(tempDir, ".goto")
	if cfg.MarkerFile != expectedMarker {
		t.Errorf("expected MarkerFile %q, got %q", expectedMarker, cfg.MarkerFile)
	}
	expectedHelper := filepath.Join(tempDir, "funcgoto")
	if cfg.HelperFile != expectedHelper {
		t.Errorf("expected HelperFile %q, got %q", expectedHelper, cfg.HelperFile)
	}

	if err := cfg.EnsureDataDir(); err != nil {
		t.Fatalf("EnsureDataDir failed: %v", err)
	}

	fi, err := os.Stat(cfg.DataDir)
	if err != nil {
		t.Fatalf("failed to stat data dir: %v", err)
	}
	if !fi.IsDir() {
		t.Errorf("expected %s to be a directory", cfg.DataDir)
	}
}

func TestNewXDG(t *testing.T) {
	tempDir := t.TempDir()
	t.Setenv("XDG_DATA_HOME", tempDir)

	cfg, err := New()
	if err != nil {
		t.Fatalf("New() failed: %v", err)
	}

	expectedDir := filepath.Join(tempDir, "goto")
	if cfg.DataDir != expectedDir {
		t.Errorf("expected DataDir %q, got %q", expectedDir, cfg.DataDir)
	}
}
