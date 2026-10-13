package config

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
)

// Config holds runtime configuration paths for goto.
type Config struct {
	DataDir    string
	DataFile   string
	MarkerFile string
	HelperFile string
}

// New resolves the goto configuration paths based on environment variables.
// It follows the XDG Base Directory specification ($XDG_DATA_HOME/goto),
// falling back to $HOME/.local/share/goto.
func New() (*Config, error) {
	dataDir := os.Getenv("XDG_DATA_HOME")
	if dataDir != "" {
		dataDir = filepath.Join(dataDir, "goto")
	} else {
		home, err := os.UserHomeDir()
		if err != nil || home == "" {
			home = os.Getenv("HOME")
			if home == "" {
				return nil, errors.New("could not find user home directory")
			}
		}
		dataDir = filepath.Join(home, ".local", "share", "goto")
	}

	return NewWithDir(dataDir), nil
}

// NewWithDir initializes a Config with a specific base data directory.
func NewWithDir(dataDir string) *Config {
	return &Config{
		DataDir:    dataDir,
		DataFile:   filepath.Join(dataDir, "data.json"),
		MarkerFile: filepath.Join(dataDir, ".goto"),
		HelperFile: filepath.Join(dataDir, "funcgoto"),
	}
}

// EnsureDataDir creates the data directory if it does not already exist.
func (c *Config) EnsureDataDir() error {
	if err := os.MkdirAll(c.DataDir, 0755); err != nil {
		return fmt.Errorf("failed to create data directory %s: %w", c.DataDir, err)
	}
	return nil
}
