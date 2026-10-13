package store

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"sync"
)

// Entry represents a single key-to-path mapping.
type Entry struct {
	Key  string
	Path string
}

// Store handles persistence and retrieval of shortcuts.
type Store struct {
	mu       sync.RWMutex
	filePath string
	data     map[string]string
}

// NewStore initializes a Store pointing to the given data.json file path.
func NewStore(filePath string) *Store {
	return &Store{
		filePath: filePath,
		data:     make(map[string]string),
	}
}

// Load reads and parses data.json from disk. If the file does not exist or is empty,
// an empty store is initialized.
func (s *Store) Load() error {
	s.mu.Lock()
	defer s.mu.Unlock()

	dataBytes, err := os.ReadFile(s.filePath)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			s.data = make(map[string]string)
			return nil
		}
		return fmt.Errorf("failed to read data file %s: %w", s.filePath, err)
	}

	if len(dataBytes) == 0 {
		s.data = make(map[string]string)
		return nil
	}

	var parsed map[string]string
	if err := json.Unmarshal(dataBytes, &parsed); err != nil {
		return fmt.Errorf("failed to parse JSON from %s: %w", s.filePath, err)
	}

	if parsed == nil {
		parsed = make(map[string]string)
	}
	s.data = parsed
	return nil
}

// Save atomically writes the current store data to disk.
func (s *Store) Save() error {
	s.mu.RLock()
	defer s.mu.RUnlock()

	dir := filepath.Dir(s.filePath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create directory %s: %w", dir, err)
	}

	dataBytes, err := json.MarshalIndent(s.data, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to serialize shortcuts: %w", err)
	}
	dataBytes = append(dataBytes, '\n')

	// Write to temporary file in the same directory for atomic rename
	tmpFile, err := os.CreateTemp(dir, ".data.json.tmp.*")
	if err != nil {
		return fmt.Errorf("failed to create temp file: %w", err)
	}
	tmpName := tmpFile.Name()

	cleanUp := true
	defer func() {
		if cleanUp {
			_ = os.Remove(tmpName)
		}
	}()

	if _, err := tmpFile.Write(dataBytes); err != nil {
		_ = tmpFile.Close()
		return fmt.Errorf("failed to write to temp file: %w", err)
	}

	if err := tmpFile.Sync(); err != nil {
		_ = tmpFile.Close()
		return fmt.Errorf("failed to sync temp file: %w", err)
	}

	if err := tmpFile.Close(); err != nil {
		return fmt.Errorf("failed to close temp file: %w", err)
	}

	if err := os.Rename(tmpName, s.filePath); err != nil {
		return fmt.Errorf("failed to atomic rename %s to %s: %w", tmpName, s.filePath, err)
	}

	cleanUp = false
	return nil
}

// Get retrieves the path for a given key.
func (s *Store) Get(key string) (string, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	path, ok := s.data[key]
	return path, ok
}

// Has checks if a key exists in the store.
func (s *Store) Has(key string) bool {
	s.mu.RLock()
	defer s.mu.RUnlock()

	_, ok := s.data[key]
	return ok
}

// Set stores a key-path pair and persists it to disk.
func (s *Store) Set(key, path string) error {
	s.mu.Lock()
	s.data[key] = path
	s.mu.Unlock()

	return s.Save()
}

// Delete removes a key and persists changes to disk.
func (s *Store) Delete(key string) (bool, error) {
	s.mu.Lock()
	if _, ok := s.data[key]; !ok {
		s.mu.Unlock()
		return false, nil
	}
	delete(s.data, key)
	s.mu.Unlock()

	return true, s.Save()
}

// DeleteAll clears all entries from the store and persists changes.
func (s *Store) DeleteAll() error {
	s.mu.Lock()
	s.data = make(map[string]string)
	s.mu.Unlock()

	return s.Save()
}

// Rename updates an old key name to a new key name and persists changes.
func (s *Store) Rename(oldKey, newKey string) error {
	s.mu.Lock()
	path, ok := s.data[oldKey]
	if !ok {
		s.mu.Unlock()
		return fmt.Errorf("key %q not found", oldKey)
	}
	delete(s.data, oldKey)
	s.data[newKey] = path
	s.mu.Unlock()

	return s.Save()
}

// List returns all entries sorted alphabetically by key.
func (s *Store) List() []Entry {
	s.mu.RLock()
	defer s.mu.RUnlock()

	entries := make([]Entry, 0, len(s.data))
	for k, v := range s.data {
		entries = append(entries, Entry{Key: k, Path: v})
	}

	sort.Slice(entries, func(i, j int) bool {
		return entries[i].Key < entries[j].Key
	})

	return entries
}

// Count returns the number of saved records.
func (s *Store) Count() int {
	s.mu.RLock()
	defer s.mu.RUnlock()

	return len(s.data)
}
