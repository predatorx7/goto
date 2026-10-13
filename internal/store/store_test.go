package store

import (
	"os"
	"path/filepath"
	"testing"
)

func TestStoreOperations(t *testing.T) {
	tempDir := t.TempDir()
	dataFile := filepath.Join(tempDir, "data.json")

	s := NewStore(dataFile)
	if err := s.Load(); err != nil {
		t.Fatalf("unexpected load error on empty file: %v", err)
	}

	if s.Count() != 0 {
		t.Fatalf("expected 0 entries, got %d", s.Count())
	}

	// Set entry
	if err := s.Set("docs", "/home/user/docs"); err != nil {
		t.Fatalf("failed to set entry: %v", err)
	}

	if !s.Has("docs") {
		t.Errorf("expected store to have 'docs'")
	}

	path, ok := s.Get("docs")
	if !ok || path != "/home/user/docs" {
		t.Errorf("expected /home/user/docs, got %s (ok=%v)", path, ok)
	}

	// Persist another entry
	if err := s.Set("proj", "/home/user/projects"); err != nil {
		t.Fatalf("failed to set second entry: %v", err)
	}

	if s.Count() != 2 {
		t.Errorf("expected 2 entries, got %d", s.Count())
	}

	// Reload in a fresh store to verify file persistence
	s2 := NewStore(dataFile)
	if err := s2.Load(); err != nil {
		t.Fatalf("failed to reload store: %v", err)
	}
	if s2.Count() != 2 {
		t.Errorf("expected 2 reloaded entries, got %d", s2.Count())
	}

	list := s2.List()
	if len(list) != 2 {
		t.Fatalf("expected list of len 2, got %d", len(list))
	}
	if list[0].Key != "docs" || list[1].Key != "proj" {
		t.Errorf("expected sorted keys [docs, proj], got [%s, %s]", list[0].Key, list[1].Key)
	}

	// Rename
	if err := s.Rename("docs", "documents"); err != nil {
		t.Fatalf("failed to rename: %v", err)
	}
	if s.Has("docs") {
		t.Errorf("old key 'docs' should no longer exist")
	}
	if !s.Has("documents") {
		t.Errorf("new key 'documents' should exist")
	}

	// Delete
	deleted, err := s.Delete("documents")
	if err != nil || !deleted {
		t.Fatalf("failed to delete 'documents': %v (deleted=%v)", err, deleted)
	}
	if s.Has("documents") {
		t.Errorf("expected 'documents' to be deleted")
	}

	// DeleteAll
	if err := s.DeleteAll(); err != nil {
		t.Fatalf("failed to delete all: %v", err)
	}
	if s.Count() != 0 {
		t.Errorf("expected 0 entries after DeleteAll, got %d", s.Count())
	}
}

func TestStoreCorruptedFile(t *testing.T) {
	tempDir := t.TempDir()
	dataFile := filepath.Join(tempDir, "data.json")

	if err := os.WriteFile(dataFile, []byte("NOT_VALID_JSON{{{"), 0644); err != nil {
		t.Fatalf("failed to write invalid json: %v", err)
	}

	s := NewStore(dataFile)
	if err := s.Load(); err == nil {
		t.Errorf("expected error loading corrupted JSON, got nil")
	}
}
